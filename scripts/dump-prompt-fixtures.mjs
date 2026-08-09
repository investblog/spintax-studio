/**
 * Take the byte-exact fixtures the Pascal prompt port is held to.
 *
 * WHY THIS EXISTS. The canonical authoring prompt lives in the family's JS monorepo
 * (`spintax-js/packages/authoring-prompt`), and its own spec forbids a copy: the package
 * exists because a copy of the prompt had already drifted in the Telegram bot. Studio cannot
 * import a TypeScript package into Free Pascal, so it carries a PORT -- and a port with no
 * corpus is a copy with extra steps.
 *
 * So: this script asks the REAL builder for the prompts it produces, and commits them. The
 * suite then holds `src/SpxPrompt.pas` to those bytes. Same shape the whole family already
 * lives with -- independent implementations, one shared corpus (ADR 0011).
 *
 * The prompt is DETERMINISTIC (measured: two runs over the eight briefs were byte-identical),
 * which is why the gate can be exact instead of a threshold. That is a property of the PROMPT,
 * not of the model's answer to it -- the model's output is what the family's conformance suite
 * measures statistically, and that is a different question with a different instrument.
 *
 * NODE IS NOT PART OF THE BUILD. This script is run by a maintainer, by hand, when the
 * upstream prompt changes. `build.sh`, the git hooks and CI read the committed files and never
 * invoke node. That is the whole reason the fixtures are committed rather than generated.
 *
 * Usage, from the repository root:
 *
 *     node scripts/dump-prompt-fixtures.mjs
 *     SPINTAX_JS=../elsewhere/spintax-js node scripts/dump-prompt-fixtures.mjs
 *
 * Run it TWICE and diff the output before believing anything it produces. The instrument is
 * checked before the product -- this project has spent hours blaming a component for a probe's
 * own bug.
 */
import { mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const HERE = resolve(import.meta.dirname, '..');
const JS = resolve(HERE, process.env.SPINTAX_JS ?? '../spintax-js');
const OUT = join(HERE, 'tests', 'fixtures', 'prompt-v2');

const importFrom = (pkg) =>
  import(pathToFileURL(join(JS, 'packages', pkg, 'dist', 'index.js')).href);

const { buildAuthoringPrompt, buildRepairPrompt, cleanModelTemplate, PROMPT_VERSION } =
  await importFrom('authoring-prompt');
const { validate } = await importFrom('core');

const briefsPath = join(JS, 'packages', 'authoring-prompt', 'conformance', 'briefs.json');
const { briefs } = JSON.parse(readFileSync(briefsPath, 'utf8'));

/* Always LF, never the platform's line ending: the builder joins with '\n' and the Pascal port
   must too. A CRLF here would make every fixture unmatchable on the one platform Studio ships
   on, which is the sort of failure that reads as a bad port. */
const write = (name, text) => writeFileSync(join(OUT, name), text, 'utf8');

/* The INPUTS go out as files too, one per case, in a shape Pascal reads with a TStringList and
   a tab split. `index.json` stays for a human; the suite must not need a JSON parser to run a
   byte comparison, and a single packed line with its own escaping convention is a second format
   to get wrong. Each field here is written verbatim, so a brief with a comma or a note with a
   semicolon costs nothing. */
const asCase = (v) => (typeof v === 'string' ? { name: v } : v);
const writeInputs = (id, { brief, allowedVariables }) => {
  if (brief !== undefined) write(`${id}.brief.txt`, brief);
  write(
    `${id}.vars.tsv`,
    (allowedVariables ?? [])
      .map(asCase)
      .map((v) => `${v.name}\t${v.case ?? ''}\t${v.note ?? ''}`)
      .join('\n'),
  );
};

/* Two repair cases, chosen for what they EXERCISE rather than for coverage of the prose:

   - `en` has no allowed variables, so it pins the empty-list branch, and its diagnostics
     include a WARNING that must not appear in the prompt -- buildRepairPrompt keeps only
     `severity === 'error'`, and a port that forgets the filter passes every other check.
   - `ru` carries cased variables AND is eleven lines long, so the line-number gutter crosses
     from one digit to two. `String(i + 1).padStart(2, ' ')` renders line 9 as ' 9 | ' and line
     10 as '10 | '; a port that formats the number without the pad matches on a short template
     and diverges on a real one. */
const REPAIRS = [
  {
    id: 'repair-en',
    locale: 'en',
    allowedVariables: [],
    template: 'Hi {a|b there!\nYou have %n% {plural %n%: item|items|extra} left.',
  },
  {
    id: 'repair-ru',
    locale: 'ru',
    allowedVariables: [
      { name: 'City', case: 'nominative' },
      { name: 'CityGen', case: 'genitive', note: 'после «для»' },
      { name: 'Brand', note: 'не склоняется' },
    ],
    template: [
      '#def %tone% = {дружелюбный|тёплый}',
      '',
      'Здравствуйте!',
      'Мы открылись в %City%.',
      '',
      'Для %CityGen% это первый магазин %Brand%.',
      '',
      'В корзине %n% {plural %n%: товар|товара} — оформите заказ сегодня.',
      '',
      'Ждём вас {в городе|деревню}.',
      'До встречи, команда %Brand%',
    ].join('\n'),
  },

  /* HOW THE TEMPLATE IS SPLIT, which the two repair cases above cannot ask about because
     neither has a CR or a trailing newline -- and the shipped input has both. The editor joins
     its text with CRLF (SynEdit writes the platform terminator), so a port that reached for a
     TStringList ate every CR and lost the last row of any document ending in a newline. The
     original splits on '\n' and on nothing else.

     `repair-empty` is the degenerate end of the same rule: JS `''.split('\n')` is one empty
     element, so the gutter still prints ` 1 | `. */
  {
    id: 'repair-crlf',
    locale: 'en',
    allowedVariables: [],
    template: 'Hi {a|b there!\r\nSecond line.\r\nYou have %n% {plural %n%: item|items|extra} left.\r\n',
  },
  {
    id: 'repair-trailing-newline',
    locale: 'en',
    allowedVariables: [],
    template: 'Hi {a|b there!\n\n',
  },
  {
    id: 'repair-empty',
    locale: 'en',
    allowedVariables: [],
    template: '',
  },
];

/* OUR cases, on top of the family's eight.
 *
 * The briefs upstream exist to measure the PROMPT against a live model, so they are realistic
 * copy in the two languages that matter commercially -- `en` and `ru`. This corpus has a
 * different job: it measures a PORT against the builder, so what it needs is BRANCH coverage.
 * Measured against the eight briefs, three branches are never taken:
 *
 *   - the `bcs` teaching profile (sr/hr/bs) -- ALL THREE ship in this window, and the builder's
 *     own comment records that gating on 'east-slavic' alone is what once silently stripped the
 *     case rules from them. A branch no fixture takes is a branch the port may simply not have.
 *   - the `generic` channel, which is the DEFAULT and therefore the one Studio hits first.
 *   - a missing locale, which Studio can genuinely have: a new document has no declared
 *     language until someone sets one.
 *
 * `uk`, `bs` and `de` are here for the rule this project wrote down the hard way: a per-language
 * fact written where only two languages could be meant does not fail for a third -- it hands it
 * the second language's answer and passes. Two languages per profile, plus a non-English
 * `default`, is what makes "LANGUAGE: xx" provably derived rather than hardcoded. */
const PORT_CASES = [
  { id: 'port-hr-landing', locale: 'hr', channel: 'landing', variationLevel: 'balanced',
    brief: 'Kratki naslov i jedna rečenica za stranicu proizvoda.', allowedVariables: [] },
  { id: 'port-sr-generic', locale: 'sr', channel: 'generic', variationLevel: 'aggressive',
    brief: 'Кратак маркетиншки текст о новој услузи.',
    allowedVariables: [{ name: 'Grad', case: 'nominative' }] },
  { id: 'port-bs-sms', locale: 'bs', channel: 'sms', variationLevel: 'conservative',
    brief: 'Kratka SMS obavijest o isporuci.', allowedVariables: [] },
  { id: 'port-uk-email', locale: 'uk', channel: 'email', variationLevel: 'balanced',
    brief: 'Короткий лист про знижку на передплату.',
    allowedVariables: [{ name: 'Misto', case: 'nominative' }, { name: 'MistoGen', case: 'genitive' }] },
  { id: 'port-de-email', locale: 'de', channel: 'email', variationLevel: 'balanced',
    brief: 'Kurze Willkommens-E-Mail für ein Produktivitätswerkzeug.', allowedVariables: [] },
  { id: 'port-nolocale', channel: 'generic', variationLevel: 'balanced',
    brief: 'Short marketing copy with no declared language.', allowedVariables: [] },

  /* REGIONAL TAGS, and this is not a completeness gesture -- it is the one trap in the port
     that nothing else here measures. JS `pluralArity(locale)` normalizes inside; the Pascal
     entry point takes an ALREADY normalized tag. Measured on the pinned engine:

         PluralArity('ru')    = 3        PluralArity('ru-RU')      = 2
         PluralArity('hr')    = 3        PluralArity('sr-Latn-RS') = 2

     So a port that passes the raw tag hands a Russian document the two-form prompt, and every
     fixture above would still be green, because every locale above is already a base tag. A
     trap named in a comment and measured by nothing is a trap that ships.

     `en-US` is the control: it answers 2 either way. Without it, "regional tags differ" would
     be the lesson, and the actual lesson is "normalize before you ask". */
  { id: 'port-ru-RU-email', locale: 'ru-RU', channel: 'email', variationLevel: 'balanced',
    brief: 'Короткое письмо о продлении подписки.', allowedVariables: [] },
  { id: 'port-sr-Latn-RS', locale: 'sr-Latn-RS', channel: 'landing', variationLevel: 'balanced',
    brief: 'Naslov i jedna rečenica za stranicu.', allowedVariables: [] },
  { id: 'port-en-US-sms', locale: 'en-US', channel: 'sms', variationLevel: 'conservative',
    brief: 'Short delivery notice.', allowedVariables: [] },
];

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

const index = [];

for (const b of [...briefs, ...PORT_CASES]) {
  const p = buildAuthoringPrompt({
    brief: b.brief,
    locale: b.locale,
    channel: b.channel,
    variationLevel: b.variationLevel,
    allowedVariables: b.allowedVariables,
  });
  write(`${b.id}.system.txt`, p.systemPrompt);
  write(`${b.id}.user.txt`, p.userPrompt);
  writeInputs(b.id, b);
  index.push({
    id: b.id,
    kind: 'authoring',
    locale: b.locale ?? '',
    channel: b.channel ?? 'generic',
    variationLevel: b.variationLevel ?? 'balanced',
    allowedVariables: b.allowedVariables ?? [],
    brief: b.brief,
  });
}

for (const r of REPAIRS) {
  const diagnostics = validate(r.template, { locale: r.locale });
  const p = buildRepairPrompt(r.template, diagnostics, {
    locale: r.locale,
    allowedVariables: r.allowedVariables,
  });
  write(`${r.id}.system.txt`, p.systemPrompt);
  write(`${r.id}.user.txt`, p.userPrompt);
  write(`${r.id}.template.txt`, r.template);
  writeInputs(r.id, r);
  /* Severity and message travel with EVERY diagnostic, warnings included: the port filters
     them itself, and handing it a pre-filtered list would move that filter out of the gate. */
  write(
    `${r.id}.diags.tsv`,
    diagnostics.map((d) => `${d.severity}\t${d.code}\t${d.line}\t${d.column}\t${d.message}`)
      .join('\n'),
  );
  index.push({
    id: r.id,
    kind: 'repair',
    locale: r.locale,
    allowedVariables: r.allowedVariables,
    /* The diagnostics are recorded as the JS engine reported them so the port feeds its builder
       the SAME input. Studio asks its own engine for these at run time; the two agreeing is a
       separate question, and one the suite asks separately -- an engine disagreement must not
       show up here disguised as a prompt defect. */
    diagnostics: diagnostics.map((d) => ({
      severity: d.severity,
      code: d.code,
      line: d.line,
      column: d.column,
      message: d.message,
    })),
  });
}

/* `cleanModelTemplate` is not part of any built prompt, so nothing above covers it -- and it is
   the function most likely to be wrong in the port, because the original is four regular
   expressions with the `u` and `i` flags and Free Pascal has none of that. Every branch is
   pinned here by asking the REAL function, including the ones that must NOT fire: a lone quote,
   a fence in the middle of the text, a prefix that only looks like one.
   The Cyrillic prefix matters because `UpperCase` in this Pascal dialect is ASCII-only, so a
   naive port drops `Шаблон:` and keeps `шаблон:`. */
const CLEAN_CASES = [
  ['plain', 'Hi {a|b} there.'],
  ['fence-bare', '```\nHi {a|b} there.\n```'],
  ['fence-lang', '```spintax\nHi {a|b} there.\n```'],
  ['fence-crlf', '```text\r\nHi {a|b} there.\r\n```'],
  ['prefix-lower', 'template: Hi {a|b} there.'],
  ['prefix-upper', 'TEMPLATE:Hi {a|b} there.'],
  ['prefix-mixed', 'Template   :   Hi {a|b} there.'],
  ['prefix-cyr-lower', 'шаблон: Привет, {мир|свет}.'],
  ['prefix-cyr-upper', 'Шаблон : Привет, {мир|свет}.'],
  ['prefix-cyr-caps', 'ШАБЛОН:Привет, {мир|свет}.'],
  ['quotes-straight', '"Hi {a|b} there."'],
  ['quotes-curly', '“Hi {a|b} there.”'],
  ['quote-unpaired', '"Hi {a|b} there.'],
  ['fence-then-prefix', '```\nTemplate: Hi {a|b} there.\n```'],
  ['fence-inside', 'Use ``` in your copy, {a|b}.'],
  ['nbsp-edges', '  Hi {a|b} there. '],
  /* U+2028 and U+FEFF: JS trim() removes both, Pascal's Trim stops at #32. The hand-written
     TrimU in the port has to know that, and a case written with ordinary spaces would not
     ask. */
  ['unicode-space-edges', '  Hi {a|b} there.  '],
  ['bom-edges', '﻿Hi {a|b} there.﻿'],
  ['fence-only', '```\n```'],
  ['prefix-lookalike', 'Templates: Hi {a|b} there.'],
  ['blank', '   \n  '],
  ['multiline', '```\n#def %x% = {a|b}\n\n%x% and %x%\n```'],

  /* THE REST OF JS's WHITESPACE, which the first port did not have. `trim()` and `\s` under
     the `u` flag take the whole Space_Separator category, not the handful a reader thinks of.
     The expensive one is not a stray edge space -- it is the PREFIX scan, where a single
     unhandled space aborts the whole strip and `Template : ...` survives into the document. */
  ['sp-ideographic', '　Hi {a|b} there.　'],
  ['sp-thin', ' Hi {a|b} there. '],
  ['sp-enquad', ' Hi {a|b} '],
  ['sp-narrow-nbsp', ' Hi {a|b} '],
  ['sp-ogham', ' Hi {a|b} '],
  ['sp-medial', ' Hi {a|b} '],
  ['prefix-ideographic-gap', 'Template　: Hi {a|b}.'],

  /* A LONE QUOTE. The original has no length guard, so `"` is both the start and the end and
     slices to nothing; the first port guarded on length and kept it. */
  ['quote-only', '"'],

  /* `[a-z]` under `iu` matches these as well: case folding maps U+017F to `s` and U+212A to
     `k`, so V8 accepts either as a fence's language tag. Obscure, and the same root cause as
     the spaces above -- the `u` and `i` flags ported as plain ASCII. */
  ['fence-long-s', '```ſ\nHi {a|b}\n```'],
  ['fence-kelvin', '```K\nHi {a|b}\n```'],
];

for (const [id, raw] of CLEAN_CASES) {
  write(`clean-${id}.in.txt`, raw);
  write(`clean-${id}.out.txt`, cleanModelTemplate(raw));
}
write('clean.tsv', CLEAN_CASES.map(([id]) => id).join('\n'));

/* The case list the suite iterates. One line per case, no field here can contain a tab or a
   newline -- ids, locales, channels and levels are all short identifiers. */
write(
  'cases.tsv',
  index.map((c) => `${c.id}\t${c.kind}\t${c.locale}\t${c.channel ?? ''}\t${c.variationLevel ?? ''}`)
    .join('\n'),
);
write('VERSION', `${PROMPT_VERSION}\n`);
write('index.json', `${JSON.stringify({ promptVersion: PROMPT_VERSION, cases: index }, null, 1)}\n`);

console.log(`prompt fixtures: ${index.length} cases, promptVersion ${PROMPT_VERSION}`);
console.log(`written to ${OUT}`);
