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

const { buildAuthoringPrompt, buildRepairPrompt, PROMPT_VERSION } =
  await importFrom('authoring-prompt');
const { validate } = await importFrom('core');

const briefsPath = join(JS, 'packages', 'authoring-prompt', 'conformance', 'briefs.json');
const { briefs } = JSON.parse(readFileSync(briefsPath, 'utf8'));

/* Always LF, never the platform's line ending: the builder joins with '\n' and the Pascal port
   must too. A CRLF here would make every fixture unmatchable on the one platform Studio ships
   on, which is the sort of failure that reads as a bad port. */
const write = (name, text) => writeFileSync(join(OUT, name), text, 'utf8');

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

write('VERSION', `${PROMPT_VERSION}\n`);
write('index.json', `${JSON.stringify({ promptVersion: PROMPT_VERSION, cases: index }, null, 1)}\n`);

console.log(`prompt fixtures: ${index.length} cases, promptVersion ${PROMPT_VERSION}`);
console.log(`written to ${OUT}`);
