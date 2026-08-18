(*
 * SpxPrompt -- the family's canonical LLM authoring prompt, ported.
 *
 * NOT A COPY, AND THE DIFFERENCE IS THE WHOLE POINT. The canonical prompt lives in
 * `spintax-js/packages/authoring-prompt` (`PROMPT_VERSION = '2'`), and that package exists
 * because a copy of the prompt had ALREADY drifted: the Telegram bot taught three constructs
 * of five and was silent on the two where this engine is differentiated. Free Pascal cannot
 * import a TypeScript package, so Studio carries a port -- and a port is only a copy with
 * extra steps unless something holds it to the original. That something is
 * `tests/fixtures/prompt-v2/`, taken from the real builder by
 * `scripts/dump-prompt-fixtures.mjs` and compared BYTE FOR BYTE by the suite (ADR 0011).
 *
 * The comparison can be exact because the prompt is DETERMINISTIC -- measured, two runs over
 * all sixteen cases byte-identical. The MODEL's answer to the prompt is not deterministic, and
 * that is a different question measured by a different instrument: the family's conformance
 * suite, which is statistical and reports 1.0 on claude-opus-5.
 *
 * NO GUI, NO NETWORK. This unit lives in src/ and builds text. Studio never calls a model: the
 * user carries the prompt to their own, brings the draft back, and the window validates it with
 * the real engine (ADR 0011 -- and the published listing has promised exactly that since
 * 2026-08-04).
 *
 * FOUR THINGS THE PORT MUST NOT GET WRONG, each read off the source rather than guessed:
 *
 * 1. ARITY COMES FROM THE ENGINE, and the two APIs do not take the same argument. JS
 *    `pluralArity(locale)` normalizes inside; Pascal `PluralArity(BaseLang)` does NOT, so the
 *    call here is `PluralArity(NormalizeBaseLang(...))`. Passing a raw tag silently answers 2
 *    where the truth is 3, which rewrites a whole paragraph of the prompt. The JS package used
 *    to keep its own copy of the table and says so in its header: the copy drifted twice.
 *
 * 2. THE TEACHING PROFILE IS NOT THE ARITY. Which language the prompt teaches IN is a separate
 *    question from how many plural forms it takes, and conflating them was a real defect
 *    upstream -- adding sr/hr/bs to the three-form family handed Croatian a Russian case block
 *    and Cyrillic examples. The profile is an explicit table here because it is an explicit
 *    table there.
 *
 * 3. EVERY JOIN IS LF. The builder joins with '\n'. `sLineBreak` on this platform is CRLF and
 *    would make every fixture unmatchable on the one platform Studio ships on -- a failure that
 *    reads as a bad port on a machine where the port is fine.
 *
 * 4. THE SEVERITY FILTER LIVES IN HERE. `SpxBuildRepairPrompt` reports only severity 'error',
 *    and the engine happily returns warnings alongside them. That is why the messages arrive as
 *    an array PARALLEL to the diagnostics rather than as a pre-filtered list: moving the filter
 *    to the caller would move it out of the gate, and `repair-en` exists precisely to catch a
 *    port that drops it -- its input carries a `variable.undefined` warning that must not reach
 *    the prompt.
 *
 * WHY THE MESSAGES COME FROM OUTSIDE AT ALL. `TSpDiag` has no `Message` field (Spintax.pas/TSpDiag)
 * -- this engine reports a code and a span and leaves the wording to its host, and Studio's host
 * wording is `SpxDiagText`, which is deliberately phrased differently and exists in fourteen
 * languages. The JS `Diagnostic` carries an English `message`. So the caller supplies the text
 * and this unit supplies everything around it; the suite passes the JS strings and gets a
 * byte-exact match, the window passes its own and gets a prompt in the reader's language.
 *
 * EVERY COMMENT HERE IS STAR-PAREN, NEVER A BRACE COMMENT. This unit is made of `{a|b}`, and a
 * brace inside a brace comment closes it at the first `}`. Star-paren does not nest either, so
 * a comment in this form cannot quote its own delimiters as an example -- which is why that
 * sentence is spelled out in words. Both halves have cost this project a build.
 *)
unit SpxPrompt;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Spintax;

type
  (* The grammatical case of a variable's VALUE. In an inflected language a variable is not a
     neutral hole: a host serving Russian declares one variable per case, which is the pattern
     real template sets converge on. The case is DECLARED and never inferred from the name --
     upstream measured a real set where `%CasinoGamesAcc%` held instrumental forms, so the
     naming convention lied and the declaration could not. *)
  TSpxVarCase = (vcNone, vcNominative, vcGenitive, vcDative,
                 vcAccusative, vcInstrumental, vcPrepositional);

  TSpxAllowedVar = record
    Name: string;
    Kase: TSpxVarCase;
    Note: string;
  end;
  TSpxAllowedVars = array of TSpxAllowedVar;

  TSpxVariation = (vlConservative, vlBalanced, vlAggressive);
  TSpxChannel = (chEmail, chSms, chPush, chLanding, chGeneric);

  TSpxBuiltPrompt = record
    SystemPrompt: string;
    UserPrompt: string;
    PromptVersion: string;
    Allowed: string;   (* the allowed names, LF-joined, in declaration order *)
  end;

  (* The worked examples the prompt teaches from. Exposed rather than buried in the text so the
     suite can put the exact strings the model is shown through the real engine, UNDER THE SAME
     LOCALE -- the family's own package does this and says why: a prompt that teaches invalid
     syntax poisons everything downstream of it, so it must be a test failure rather than a
     surprise in production. It also earns its keep the other way round: a fixture regenerated
     from a broken upstream would still match the port byte for byte, and only the engine would
     notice. *)
  TSpxExamples = record
    Def, SetEx, Permutation, Optional, Conditional, Plural: string;
  end;

const
  SPX_PROMPT_VERSION = '2';

function SpxAllowedVar(const AName: string; AKase: TSpxVarCase = vcNone;
  const ANote: string = ''): TSpxAllowedVar;

function SpxBuildAuthoringPrompt(const ABrief, ALocale: string;
  const AVars: TSpxAllowedVars; AChannel: TSpxChannel;
  ALevel: TSpxVariation): TSpxBuiltPrompt;

(* AMessages is parallel to ADiags -- one entry per diagnostic, INCLUDING the ones this
   function will drop. See note 4 in the unit header. *)
function SpxBuildRepairPrompt(const ATemplate, ALocale: string;
  ADiags: TSpDiagList; const AMessages: array of string;
  const AVars: TSpxAllowedVars): TSpxBuiltPrompt;

function SpxPromptExamples(const ALocale: string): TSpxExamples;

(* STUDIO'S OWN, NOT PART OF PROMPT_VERSION. The pane's "source text" mode: the reader
   pastes existing copy instead of writing a brief, and this composes the brief for them --
   host-side sugar AROUND the canonical builder, never a change to it (the port's byte gates
   do not know this function exists). English on purpose: the prompt's scaffold is English
   under every locale (ROLE/GOAL/RULES above), and the template's LANGUAGE is governed by
   ALocale in the builder, not by the brief's wrapper. '' for a blank source, so the
   "nothing to send" guards upstream keep working unchanged. *)
function SpxComposeFromTextBrief(const ASource: string): string;

(* ALSO STUDIO'S OWN. Pasted copy arrives from a browser or Word wearing markup -- inline
   styles, class soup, <span> nesting, Office's <o:p> -- and none of it is the reader's
   TEXT. Before the source-text mode composes a brief, this keeps only the tags the
   product itself speaks (its preview and its help pages: p, br, a with its href, b,
   strong, i, em, u, tt, code, ul, ol, li, h1..h6), drops every attribute except that
   href, swallows <script>/<style>/<head> WITH their contents, unwraps everything else,
   and decodes the common entities. THE GATE IS A RECOGNISED TAG, not the character `<`:
   plain text -- `a < b`, `R&amp;D` quoted literally, a stray `<j>` -- comes back
   byte-identical, because prose must never be "cleaned". *)
function SpxCleanSourceHtml(const ASource: string): string;

function SpxCleanModelTemplate(const ARaw: string): string;

function SpxChannelFromName(const S: string): TSpxChannel;
function SpxVariationFromName(const S: string): TSpxVariation;
function SpxVarCaseFromName(const S: string): TSpxVarCase;

implementation

const
  LF = #10;

type
  TSpxProfile = (tpDefault, tpEastSlavic, tpBcs);

function Join(const AParts: array of string; const ASep: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := Low(AParts) to High(AParts) do
  begin
    if i > Low(AParts) then Result := Result + ASep;
    Result := Result + AParts[i];
  end;
end;

(* `split('
')` AND NOTHING ELSE, which is not what a TStringList does.

   `TStringList.Text` splits on CR as well as LF, drops a trailing empty line, and joins back
   with the platform terminator. All three differ from the original, and the difference reaches
   the reader: `FEditor.Text` is CRLF-joined (SynEdit writes `sfleSystem`), so a repair prompt
   built through a TStringList ate every CR, and a document ending in a newline silently lost
   its last numbered row. No fixture had a CR or a trailing newline, so the byte gate could not
   see any of it -- the review did. *)
procedure SplitLF(const S: string; AOut: TStringList);
var
  i, start: Integer;
begin
  AOut.Clear;
  start := 1;
  for i := 1 to Length(S) do
    if S[i] = #10 then
    begin
      AOut.Add(Copy(S, start, i - start));
      start := i + 1;
    end;
  (* The tail after the last LF, EVEN WHEN EMPTY: 'a' + LF is two elements in JS and one in a
     TStringList, and the second is the line the reader is about to type on. *)
  AOut.Add(Copy(S, start, Length(S) - start + 1));
end;

(* Prefix every line -- INCLUDING an empty one -- with eight spaces, so a worked example reads
   as a block inside the prompt. *)
function Indent(const ABlock: string): string;
var
  l: TStringList;
  i: Integer;
begin
  l := TStringList.Create;
  try
    SplitLF(ABlock, l);
    Result := '';
    for i := 0 to l.Count - 1 do
    begin
      if i > 0 then Result := Result + LF;
      Result := Result + '        ' + l[i];
    end;
  finally
    l.Free;
  end;
end;

(* Base tag -> profile. Explicit, because every implicit rule tried upstream has been wrong:
   the tags that share a plural rule do NOT share a script, an alphabet, or a case system worth
   teaching the same way. *)
function ProfileOf(const ALocale: string): TSpxProfile;
var
  lang: string;
begin
  lang := NormalizeBaseLang(ALocale);
  if (lang = 'ru') or (lang = 'uk') or (lang = 'be') then Result := tpEastSlavic
  else if (lang = 'sr') or (lang = 'hr') or (lang = 'bs') then Result := tpBcs
  else Result := tpDefault;
end;

function ArityOf(const ALocale: string): Integer;
begin
  (* Note 1 in the header: the Pascal entry point takes an ALREADY normalized tag. *)
  Result := PluralArity(NormalizeBaseLang(ALocale));
end;

(* ── Blocks ──────────────────────────────────────────────────────────────── *)

const
  ROLE =
    'You are a copywriter who writes SPINTAX TEMPLATES.' + LF +
    'A spintax template is ONE piece of copy that a renderer expands into many different — but equally' + LF +
    'good — variants.';

  GOAL =
    'GOAL — readable template first, variety second.' + LF +
    'Write the final copy as if for a human, then add markup only where a word or clause could genuinely' + LF +
    'be said another way. EVERY variant the renderer can produce must read like a human wrote it. A' + LF +
    'template that can produce one awkward variant is a broken template, no matter how much variety it' + LF +
    'offers.';

  RULES =
    'HARD RULES' + LF +
    '1. Grammar-safety. Every option inside {…} must fit the surrounding sentence identically — same' + LF +
    '   part of speech, same agreement. Read each branch back into the FULL sentence before keeping it.' + LF +
    '2. Variables. Use only the names given in ALLOWED VARIABLES. Never invent one. If you need a value' + LF +
    '   that is not offered, rewrite the copy so it is not needed.' + LF +
    '3. Counts. Any number followed by a noun goes through {plural …}. You cannot pick bucket forms by' + LF +
    '   hand — the engine does it per locale.' + LF +
    '4. No syntax outside the list above. No markdown, no HTML.' + LF +
    '5. Do not spin proper nouns, brand names, prices, URLs, or legal wording. Vary the copy AROUND them.';

  OUTPUT_CONTRACT =
    'OUTPUT CONTRACT' + LF +
    'Return the template and NOTHING else — no explanation, no quotes, no code fences, no "Template:"' + LF +
    'prefix. Your entire reply is fed straight into the renderer.';

  SELF_CHECK =
    'SELF-CHECK — do this before you answer' + LF +
    '- Mentally render 5 variants. If any reads awkwardly or breaks agreement, fix that BRANCH; do not' + LF +
    '  rewrite the whole sentence.' + LF +
    '- Check every %var% against ALLOWED VARIABLES.' + LF +
    '- Check every [ … ] has a sep and really holds equal-weight items.' + LF +
    '- Check every count goes through {plural …}.';

(* The worked examples the prompt teaches from.
   Examples are written IN a language, so they follow the teaching PROFILE, never the arity --
   except the plural forms, which must satisfy the arity because every example is validated
   under the target locale. `sat|sata|sati` is used for a three-form language taught in English
   because all three buckets differ there and the shared corpus already pins it. *)
function ExamplesFor(const ALocale: string): TSpxExamples;
var
  russian: Boolean;
  threeForm: Boolean;
begin
  russian := ProfileOf(ALocale) = tpEastSlavic;
  threeForm := ArityOf(ALocale) = 3;

  Result.Def :=
    '#def %product% = {course|training}' + LF +
    '#set %offer% = our new %product%' + LF +
    'Get %offer% today — the %product% starts on Monday.';

  Result.SetEx :=
    '#set %greeting% = {Hi|Hello|Hey}' + LF +
    '%greeting% there. And later, %greeting% again — which may well read differently.';

  if russian then
    Result.Permutation := 'Мы [<minsize=2;maxsize=3;sep=", ";lastsep=" и ">перезвоним за час|подберём тариф|перенесём данные].'
  else
    Result.Permutation := 'We can [<minsize=2;maxsize=3;sep=", ";lastsep=" and ">reply within the hour|set up your account|migrate your data].';

  Result.Optional := 'Get our {|brand new }{course|training} today.';
  Result.Conditional := '{?discount?Save %discount% today|Get started in minutes}';

  if russian then
    Result.Plural := 'У вас %n% {plural %n%: товар|товара|товаров} в корзине.'
  else if threeForm then
    Result.Plural := 'The sale ends in %n% {plural %n%: sat|sata|sati}.'
  else
    Result.Plural := 'You have %n% {plural %n%: item|items} in your cart.';
end;

function SpxPromptExamples(const ALocale: string): TSpxExamples;
begin
  Result := ExamplesFor(ALocale);
end;

(* The permutation note is not pedantry: the default separator is a single SPACE, so a bare
   [clause|clause] joins into mush. Models get this wrong unless told explicitly. *)
function SyntaxBlock(const ALocale: string): string;
var
  ex: TSpxExamples;
  forms: Integer;
  pluralForm, andWord: string;
begin
  ex := ExamplesFor(ALocale);
  forms := ArityOf(ALocale);
  if forms = 3 then pluralForm := '{plural %n%: one|few|many}'
                else pluralForm := '{plural %n%: one|many}';
  (* The conjunction belongs to the example LANGUAGE, not the arity: keying this on arity is
     what once put a Cyrillic "и" inside an English sentence for Latin-script hr/bs. *)
  if ProfileOf(ALocale) = tpEastSlavic then andWord := 'и' else andWord := 'and';

  Result :=
    'SYNTAX — this is the COMPLETE list. Nothing else exists.' + LF +
    LF +
    '{a|b|c}' + LF +
    '    Pick exactly one. Rerolls at EVERY occurrence: two separate {Hi|Hello} may disagree.' + LF +
    '    An EMPTY branch makes a word optional — deliberate and useful:' + LF +
    Indent(ex.Optional) + LF +
    '    But a stray double pipe is an ACCIDENTAL empty branch: {a|b||c} silently renders nothing one' + LF +
    '    time in four. Re-read every {…} for a doubled "|".' + LF +
    LF +
    '#def %v% = value' + LF +
    '    Define once, reuse. The value is chosen ONCE per message, and every %v% in the copy is the' + LF +
    '    SAME. Use it for anything that must stay consistent across sentences (a product name, a' + LF +
    '    tone), and for any number you both print and agree grammatically.' + LF +
    '    A #def value may itself contain {a|b} AND other variables — variables nest:' + LF +
    Indent(ex.Def) + LF +
    '    Here %offer% contains %product%, so the two can never contradict each other. Inline {a|b}' + LF +
    '    would reroll and could say "course" in one sentence and "training" in the next.' + LF +
    LF +
    '#set %v% = value' + LF +
    '    A macro: the value is re-picked at EVERY use, so one name can read differently across the' + LF +
    '    copy. Use it when variety is the point, or for text you mention only once:' + LF +
    Indent(ex.SetEx) + LF +
    '    Choose between them by asking whether two mentions disagreeing would read as a mistake.' + LF +
    '    A product name, a price, a count: #def. A greeting repeated down the page: #set.' + LF +
    LF +
    '%name%' + LF +
    '    A variable, filled in by the host at render time. Use ONLY names from ALLOWED VARIABLES.' + LF +
    LF +
    '[<minsize=2;maxsize=3;sep=", ";lastsep=" ' + andWord + ' ">a|b|c]' + LF +
    '    Permutation: shuffles the items and joins them.' + LF +
    '    ALWAYS set sep when the items are clauses — the DEFAULT SEPARATOR IS A SINGLE SPACE, which' + LF +
    '    turns clauses into mush.' + LF +
    '    ALWAYS set lastsep for a human-readable list: "a, b ' + andWord + ' c"' + LF +
    '    instead of the robotic "a, b, c".' + LF +
    '    minsize/maxsize pick a SUBSET, so the list itself varies in length.' + LF +
    '    Use permutations only for items of EQUAL weight, where the order genuinely does not matter' + LF +
    '    (benefits, features, providers):' + LF +
    Indent(ex.Permutation) + LF +
    LF +
    '{?VAR?then|else}' + LF +
    '    Conditional. Emits "then" if VAR has a truthy value, otherwise "else".' + LF +
    '    Use it when the copy must adapt to data that may be missing:' + LF +
    Indent(ex.Conditional) + LF +
    LF +
    pluralForm + LF +
    '    Plural agreement by count. This target language takes EXACTLY ' + IntToStr(forms) + ' forms —' + LF +
    '    writing any other number of forms is a hard error, not a style choice. NEVER hand-roll counts' + LF +
    '    as {item|items}:' + LF +
    Indent(ex.Plural);
end;

(* Grammar is language-specific, and the Slavic cases are where a model quietly produces
   garbage: it will happily hand-roll bucket forms and get the boundaries wrong. The engine's
   locale-aware plural is the whole point -- the prompt has to push the model into it. *)
function GrammarBlock(const ALocale: string): string;
var
  lang: string;
begin
  lang := NormalizeBaseLang(ALocale);

  case ProfileOf(ALocale) of
    tpEastSlavic:
      Result :=
        'LANGUAGE: ' + lang + ' — agreement is strict and unforgiving. This is the hard part; slow down here.' + LF +
        '- Every option inside {…} must preserve GENDER, CASE and NUMBER agreement with the words around it.' + LF +
        '    WRONG: {хороший|отличная} курс     ← gender breaks in the second branch' + LF +
        '    RIGHT: {хороший|отличный} курс' + LF +
        '- If a branch changes the noun, any adjective, participle or preposition that governs it may have' + LF +
        '  to change too. In that case move them INSIDE the branch:' + LF +
        '    WRONG: в {городе|деревню}' + LF +
        '    RIGHT: {в городе|в деревню}' + LF +
        '- NEVER hand-roll count forms: {товар|товара|товаров} is WRONG. Write {plural %n%: товар|товара|товаров}' + LF +
        '  and let the engine choose the bucket for the actual number — you cannot do it correctly, it depends' + LF +
        '  on the count.';
    tpBcs:
      Result :=
        'LANGUAGE: ' + lang + ' — agreement is strict and unforgiving. This is the hard part; slow down here.' + LF +
        '- Every option inside {…} must preserve GENDER, CASE and NUMBER agreement with the words around it.' + LF +
        '    WRONG: {dobar|odlična} kurs      ← gender breaks in the second branch' + LF +
        '    RIGHT: {dobar|odličan} kurs' + LF +
        '- If a branch changes the noun, any adjective or preposition that governs it may have to change too.' + LF +
        '  In that case move them INSIDE the branch:' + LF +
        '    WRONG: u {gradu|selo}' + LF +
        '    RIGHT: {u gradu|u selo}' + LF +
        '- Counts take THREE buckets, same boundaries as Russian. NEVER hand-roll them:' + LF +
        '  {bonus|bonusa|bonusa} is WRONG. Write {plural %n%: bonus|bonusa|bonusa} and let the engine pick.' + LF +
        '- Write the WHOLE template in ONE script. Do not mix Latin and Cyrillic inside a template or, worse,' + LF +
        '  inside a single {…} — every branch must be the same script as the text around it.' + LF +
        '- The worked examples below are in ENGLISH, and only the plural forms are in yours. Write YOUR' + LF +
        '  language throughout, including the words inside a permutation''s sep/lastsep: the examples show' + LF +
        '  lastsep=" and ", and yours is "i" in Latin script or "и" in Cyrillic — never the English word.';
  else
    Result :=
      'LANGUAGE: ' + lang + LF +
      '- Every option inside {…} must agree with the surrounding sentence: same part of speech, same' + LF +
      '  number, same tense, and the article before it must still be correct ("a offer" is a broken branch).' + LF +
      '- Never hand-roll counts as {item|items} — use {plural %n%: item|items}.';
  end;
end;

(* How to present the allow-list, and the rule the model breaks most often. A variable is
   substituted VERBATIM -- the engine never inflects it, and neither can the model by gluing a
   suffix on the outside. *)
function VariableRulesBlock(const ALocale: string): string;
var
  universal, caseRules: string;
  profile: TSpxProfile;
begin
  universal :=
    'VARIABLES' + LF +
    'Use ONLY the names given in ALLOWED VARIABLES, exactly as written.' + LF +
    LF +
    'A variable is substituted VERBATIM. The engine does not inflect, pluralize or re-case it, and' + LF +
    'neither can you by bolting text onto the outside of it. Build the SENTENCE around the form the' + LF +
    'value already has.';

  profile := ProfileOf(ALocale);

  (* EVERY case language gets the case rules -- they are language-neutral, and a seven-case
     language handed only the English a/an rule is worse off than one handed them in the wrong
     prose. Gating this on east-slavic alone is what silently stripped them from sr/hr/bs
     upstream. Only the WORKED EXAMPLES below are language-specific. *)
  if profile in [tpEastSlavic, tpBcs] then
  begin
    caseRules := universal + LF + LF +
      'CASE IS PART OF THE VALUE, not a suggestion:' + LF +
      '- Variables that differ only by a suffix (%X%, %XGen%, %XDat%, %XLoc%, %XInstr%) are NOT synonyms.' + LF +
      '  They are the same word in different cases. Choose the one the sentence actually governs.' + LF +
      '- NEVER glue an ending onto a variable. A suffix bolted onto the outside of %X% renders as literal' + LF +
      '  text, not as an inflected word.' + LF +
      '- A preposition and the variable after it move TOGETHER. If you swap the preposition, you must swap' + LF +
      '  to the matching variable — or the sentence breaks.' + LF +
      '- If the case you need is NOT in the list, REWRITE THE SENTENCE so it needs a case that is. Never' + LF +
      '  approximate with the wrong one: a wrong case reads as broken copy, which is worse than plainer' + LF +
      '  copy.' + LF +
      '- A brand or proper name does not decline.';

    if profile <> tpEastSlavic then
      Exit(caseRules);

    Exit(caseRules + LF + LF +
      'Worked examples (Russian):' + LF +
      '      для %VisitorsGen%      (родительный — after "для")' + LF +
      '      к %VisitorsDat%        (дательный — after "к")' + LF +
      '      о %VisitorsLoc%        (предложный — after "о")' + LF +
      '      с %VisitorsInstr%      (творительный — after "с")' + LF +
      '- "%Visitors%ов" is not a genitive; it renders as the literal text "посетителиов".' + LF +
      '- Write "в %CasinoName%", never "%CasinoName%а".');
  end;

  Result := universal + LF + LF +
    '- Do not assume the shape of a value you have not seen. "a %product%" is a coin-flip between "a"' + LF +
    '  and "an"; write "our %product%" or restructure the sentence.' + LF +
    '- Do not pluralize or possessivize a variable by hand — if you need a count, use {plural …}.';
end;

function CaseName(AKase: TSpxVarCase): string;
begin
  case AKase of
    vcNominative:    Result := 'nominative';
    vcGenitive:      Result := 'genitive';
    vcDative:        Result := 'dative';
    vcAccusative:    Result := 'accusative';
    vcInstrumental:  Result := 'instrumental';
    vcPrepositional: Result := 'prepositional';
  else
    Result := '';
  end;
end;

(* The per-request allow-list. Deliberately NOT part of the system prompt: the rules above are
   stable and cacheable, while this list changes with every item a host processes. *)
function VariableListBlock(const AVars: TSpxAllowedVars): string;
var
  i: Integer;
  bits, c: string;
begin
  if Length(AVars) = 0 then
    Exit('ALLOWED VARIABLES: (none — do not use any %variable%)');

  Result := 'ALLOWED VARIABLES (the case is part of the value, not a suggestion):';
  for i := 0 to High(AVars) do
  begin
    c := CaseName(AVars[i].Kase);
    if (c <> '') and (AVars[i].Note <> '') then bits := c + '; ' + AVars[i].Note
    else if c <> '' then bits := c
    else bits := AVars[i].Note;

    Result := Result + LF + '  %' + AVars[i].Name + '%';
    if bits <> '' then Result := Result + ' — ' + bits;
  end;
end;

function LevelBlock(ALevel: TSpxVariation): string;
begin
  case ALevel of
    vlConservative:
      Result :=
        'VARIATION LEVEL: conservative' + LF +
        'Use {a|b} only, and only on words that carry no agreement risk (adverbs, interchangeable synonyms' + LF +
        'of the same gender/number). No permutations, no nesting. Prefer 2 options per choice.';
    vlAggressive:
      Result :=
        'VARIATION LEVEL: aggressive' + LF +
        'Use every construct, including [ … ] permutations and {…} nested inside branches. Push for real' + LF +
        'variety — but the grammar rules above still beat variety, every time. A broken variant is worse' + LF +
        'than a boring one.';
  else
    Result :=
      'VARIATION LEVEL: balanced' + LF +
      'Use {a|b}, %variables%, #set, {?…} and {plural …}. Use permutations only where the items are' + LF +
      'genuinely equal-weight. Aim for 2–3 options per choice and vary whole clauses, not just adjectives.';
  end;
end;

function ChannelBlock(AChannel: TSpxChannel): string;
begin
  case AChannel of
    chEmail:   Result := 'CHANNEL: email — 2–5 sentences, conversational, one clear call to action.';
    chSms:     Result := 'CHANNEL: SMS — under 160 characters TOTAL in every variant. Be terse. No permutations.';
    chPush:    Result := 'CHANNEL: push notification — one sentence, under 120 characters in every variant.';
    chLanding: Result := 'CHANNEL: landing copy — a headline plus one supporting sentence.';
  else
    Result := 'CHANNEL: generic short marketing copy.';
  end;
end;

(* ── Builders ────────────────────────────────────────────────────────────── *)

function NamesOf(const AVars: TSpxAllowedVars): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(AVars) do
  begin
    if i > 0 then Result := Result + LF;
    Result := Result + AVars[i].Name;
  end;
end;

function SpxAllowedVar(const AName: string; AKase: TSpxVarCase;
  const ANote: string): TSpxAllowedVar;
begin
  Result.Name := AName;
  Result.Kase := AKase;
  Result.Note := ANote;
end;

function SpxBuildAuthoringPrompt(const ABrief, ALocale: string;
  const AVars: TSpxAllowedVars; AChannel: TSpxChannel;
  ALevel: TSpxVariation): TSpxBuiltPrompt;
begin
  Result.SystemPrompt := Join([
    ROLE,
    GOAL,
    SyntaxBlock(ALocale),
    GrammarBlock(ALocale),
    VariableRulesBlock(ALocale),
    LevelBlock(ALevel),
    RULES,
    OUTPUT_CONTRACT,
    SELF_CHECK
  ], LF + LF);

  Result.UserPrompt := Join([
    ChannelBlock(AChannel),
    VariableListBlock(AVars),
    '',
    'BRIEF:',
    ABrief,
    '',
    'Write the spintax template now. Output only the template.'
  ], LF);

  Result.PromptVersion := SPX_PROMPT_VERSION;
  Result.Allowed := NamesOf(AVars);
end;

function SpxBuildRepairPrompt(const ATemplate, ALocale: string;
  ADiags: TSpDiagList; const AMessages: array of string;
  const AVars: TSpxAllowedVars): TSpxBuiltPrompt;
var
  lines: TStringList;
  numbered, list, n: string;
  i: Integer;
begin
  lines := TStringList.Create;
  try
    SplitLF(ATemplate, lines);
    numbered := '';
    for i := 0 to lines.Count - 1 do
    begin
      if i > 0 then numbered := numbered + LF;
      (* padStart(2, ' ') -- line 9 is ' 9 | ' and line 10 is '10 | '. A port that formats the
         number without the pad matches on a short template and diverges on a real one. *)
      n := IntToStr(i + 1);
      while Length(n) < 2 do n := ' ' + n;
      numbered := numbered + n + ' | ' + lines[i];
    end;
  finally
    lines.Free;
  end;

  (* Note 4: the filter is HERE, and AMessages is parallel to ADiags so it survives it. *)
  (* AMessages is parallel to ADiags by contract; a caller that gets it wrong would read past
     the end of an open array, which reads whatever is next on the stack rather than failing.
     Bounded here so a short list drops rows instead of inventing them. *)
  list := '';
  if ADiags <> nil then
    for i := 0 to ADiags.Count - 1 do
      if (i <= High(AMessages)) and (ADiags[i].Severity = 'error') then
      begin
        if list <> '' then list := list + LF;
        list := list + '- line ' + IntToStr(ADiags[i].Line) +
                       ', column ' + IntToStr(ADiags[i].Column) +
                       ' [' + ADiags[i].Code + ']: ' + AMessages[i];
      end;
  if list = '' then list := '- (none reported — return the template unchanged)';

  Result.SystemPrompt := Join([
    ROLE,
    'You are FIXING an invalid spintax template. Change as little as possible: repair the reported',
    'spans and leave everything else byte-for-byte identical. Do not rewrite the copy.',
    SyntaxBlock(ALocale),
    GrammarBlock(ALocale),
    VariableRulesBlock(ALocale),
    OUTPUT_CONTRACT
  ], LF + LF);

  Result.UserPrompt := Join([
    'This template failed validation.',
    '',
    VariableListBlock(AVars),
    '',
    'TEMPLATE (line-numbered):',
    numbered,
    '',
    'ERRORS:',
    list,
    '',
    'Return the corrected template. Output only the template.'
  ], LF);

  Result.PromptVersion := SPX_PROMPT_VERSION;
  Result.Allowed := NamesOf(AVars);
end;

(* The "source text" mode's brief -- see the interface note: Studio's own composition, outside
   the port and its byte gates. The instruction mirrors the one the owner tested by hand on a
   live model: keep the meaning, the facts and the sentence order; vary every sentence. The
   source is appended VERBATIM under a named heading, so the reader can recognise their own
   text in "Copy prompt" and nothing here re-wraps or trims inside it. *)
function SpxComposeFromTextBrief(const ASource: string): string;
begin
  if Trim(ASource) = '' then Exit('');
  Result :=
    'Convert the source text below into a spintax template.' + LF +
    'Keep its meaning, its facts and its sentence order. Give each sentence rich variation --' + LF +
    'synonyms, reorderings, varied openings -- and every variant must stay faithful to the source.' + LF +
    'SOURCE TEXT:' + LF +
    ASource;
end;

(* ── SpxCleanSourceHtml and its helpers -- see the interface note ────────────────────── *)

function HtmlNameStart(C: Char): Boolean;
begin
  Result := C in ['a'..'z', 'A'..'Z'];
end;

(* HTML's whitespace, form feed included -- the boundary set every helper below shares. *)
function HtmlWs(C: Char): Boolean;
begin
  Result := C in [' ', #9, #10, #12, #13];
end;

(* Where a tag NAME ends: whitespace, '/', '>' -- the tokenizer's delimiters, not some
   notion of "name characters". `<p.class>` is a tag named `p.class` (unknown, unwraps),
   never `<p>` wearing a suffix; Office's `<o:p>` and custom `x-y` parse whole the same
   way (Codex, third pass -- the first version stopped at a letters-digits set and read
   the suffix as attributes). *)
function HtmlNameEnd(C: Char): Boolean;
begin
  Result := HtmlWs(C) or (C = '/') or (C = '>');
end;

function LowerAscii(const S: string): string;
var
  i: Integer;
begin
  Result := S;
  for i := 1 to Length(Result) do
    if Result[i] in ['A'..'Z'] then Result[i] := Chr(Ord(Result[i]) + 32);
end;

function IsIn(const N: string; const AList: array of string): Boolean;
var
  i: Integer;
begin
  for i := Low(AList) to High(AList) do
    if N = AList[i] then Exit(True);
  Result := False;
end;

(* The tags the product itself speaks: its generated help pages and the preview it renders.
   Everything else is somebody's layout, not the reader's text. *)
function HtmlKept(const N: string): Boolean;
begin
  Result := IsIn(N, ['p', 'br', 'a', 'b', 'strong', 'i', 'em', 'u', 'tt', 'code',
                     'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6']);
end;

(* Containers whose CONTENT is not copy either. *)
function HtmlSwallowed(const N: string): Boolean;
begin
  Result := IsIn(N, ['script', 'style', 'head', 'title', 'noscript', 'svg']);
end;

(* Dropped block containers leave a line break behind, so two sibling <div>s do not glue
   into one word; a dropped table cell leaves a space for the same reason. *)
function HtmlBlockish(const N: string): Boolean;
begin
  Result := IsIn(N, ['div', 'section', 'article', 'header', 'footer', 'main', 'aside',
                     'nav', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'blockquote',
                     'pre', 'hr', 'form', 'figure', 'figcaption']);
end;

function HtmlCellish(const N: string): Boolean;
begin
  Result := IsIn(N, ['td', 'th']);
end;

(* The gate's list: a name that proves the paste IS markup. Deliberately wider than the
   kept list and narrower than "anything that parses" -- `<j>` in somebody's prose must
   not flip the gate. A colon in the name counts too (Office). *)
function HtmlKnown(const N: string): Boolean;
begin
  Result := HtmlKept(N) or HtmlSwallowed(N) or HtmlBlockish(N) or HtmlCellish(N) or
            IsIn(N, ['span', 'font', 'img', 'meta', 'link', 'body', 'html', 'iframe',
                     'video', 'audio', 'picture', 'source', 'input', 'button', 'select',
                     'option', 'label', 'small', 'big', 'sup', 'sub', 's', 'strike']) or
            (Pos(':', N) > 0);
end;

(* Parse one candidate tag at S[At] = '<'. True when a well-formed tag ends at AEnd ('>');
   AName is lowercased without the '/'. Quoted attribute values may carry '>' and are
   skipped as wholes. *)
function HtmlParseTag(const S: string; At: Integer;
  out AName: string; out AClose: Boolean; out ABody: string; out AEnd: Integer): Boolean;
var
  i, nameFrom: Integer;
  q: Char;
begin
  Result := False;
  i := At + 1;
  AClose := False;
  if (i <= Length(S)) and (S[i] = '/') then
  begin
    AClose := True;
    Inc(i);
  end;
  if (i > Length(S)) or not HtmlNameStart(S[i]) then Exit;
  nameFrom := i;
  while (i <= Length(S)) and not HtmlNameEnd(S[i]) do
  begin
    (* a second '<' inside a candidate name is prose, not a tag *)
    if S[i] = '<' then Exit;
    Inc(i);
  end;
  AName := LowerAscii(Copy(S, nameFrom, i - nameFrom));
  nameFrom := i;   (* the attributes begin here *)
  while i <= Length(S) do
  begin
    if S[i] = '>' then
    begin
      ABody := Copy(S, nameFrom, i - nameFrom);
      AEnd := i;
      Exit(True);
    end;
    if S[i] in ['"', ''''] then
    begin
      q := S[i];
      Inc(i);
      while (i <= Length(S)) and (S[i] <> q) do Inc(i);
      if i > Length(S) then Exit;   (* an unclosed quote: not a tag *)
    end;
    Inc(i);
  end;
end;

(* `href` out of a kept <a>'s attribute text: the one attribute that IS content. *)
function HtmlHrefOf(const ABody: string): string;
var
  low: string;
  at, i, j: Integer;
  q: Char;
begin
  Result := '';
  low := LowerAscii(ABody);
  (* The attribute NAMED href: whitespace (or an end of the string) on BOTH sides of the
     name, '=' next -- `data-href`, `_href` and `hreflang` each fail a boundary. And a
     candidate that fails RESUMES the search rather than giving up: `hreflang` standing
     before the real href must not hide it (both from Codex review, across two passes --
     the first fix checked one boundary and exited on the first miss). *)
  at := 0;
  repeat
    at := Pos('href', low, at + 1);
    if at = 0 then Exit;
    if ((at = 1) or HtmlWs(low[at - 1])) and
       ((at + 4 > Length(low)) or HtmlWs(low[at + 4]) or (low[at + 4] = '=')) then
    begin
      i := at + 4;
      while (i <= Length(ABody)) and HtmlWs(ABody[i]) do Inc(i);
      if (i <= Length(ABody)) and (ABody[i] = '=') then
      begin
        Inc(i);
        while (i <= Length(ABody)) and HtmlWs(ABody[i]) do Inc(i);
        if i > Length(ABody) then Exit;
        if ABody[i] in ['"', ''''] then
        begin
          q := ABody[i];
          j := i + 1;
          while (j <= Length(ABody)) and (ABody[j] <> q) do Inc(j);
          Result := Copy(ABody, i + 1, j - i - 1);
        end
        else
        begin
          j := i;
          while (j <= Length(ABody)) and not HtmlWs(ABody[j]) do Inc(j);
          Result := Copy(ABody, i, j - i);
        end;
        (* A value carrying a quote would smuggle an attribute past the whitelist the
           moment it is re-emitted inside double quotes (Codex: href='x" onclick="evil').
           No link is better than that link. *)
        if (Pos('"', Result) > 0) or (Pos('''', Result) > 0) then Result := '';
        Exit;
      end;
    end;
  until False;
end;

(* Whether S[At] = '<' LOOKS like a tag's start -- optional '/', then a name character.
   The gate uses it to tell "a < b" (plain prose, keep walking) from an unterminated tag
   whose quoted inside must not be read as markup (Codex, second pass). *)
function HtmlTagLikeAt(const S: string; At: Integer): Boolean;
var
  i: Integer;
begin
  i := At + 1;
  if (i <= Length(S)) and (S[i] = '/') then Inc(i);
  Result := (i <= Length(S)) and HtmlNameStart(S[i]);
end;

(* The '>' that ends a doctype or processing instruction: a quoted run may carry '>' and
   is skipped whole (Codex: <!DOCTYPE html SYSTEM "x>y">). 0 when none. *)
function HtmlGtAt(const S: string; At: Integer): Integer;
var
  q: Char;
begin
  Result := At;
  while Result <= Length(S) do
  begin
    if S[Result] = '>' then Exit;
    if S[Result] in ['"', ''''] then
    begin
      q := S[Result];
      Inc(Result);
      while (Result <= Length(S)) and (S[Result] <> q) do Inc(Result);
      if Result > Length(S) then Exit(0);
    end;
    Inc(Result);
  end;
  Result := 0;
end;

(* `<svg/>` has no contents to swallow (Codex). The trailing '/' counts only when what
   precedes it is a boundary -- whitespace, a closing quote, or nothing: in an UNQUOTED
   attribute value (`media=screen/`) the slash belongs to the value under HTML
   tokenization, and the element is not self-closed (Codex, third pass). *)
function HtmlSelfClosed(const ABody: string): Boolean;
var
  s: string;
begin
  s := TrimRight(ABody);
  Result := (s <> '') and (s[Length(s)] = '/') and
            ((Length(s) = 1) or HtmlWs(s[Length(s) - 1]) or
             (s[Length(s) - 1] in ['"', '''']));
end;

function Utf8OfCodepoint(Cp: Cardinal): string;
begin
  if Cp < $80 then Result := Chr(Cp)
  else if Cp < $800 then
    Result := Chr($C0 or (Cp shr 6)) + Chr($80 or (Cp and $3F))
  else if Cp < $10000 then
    Result := Chr($E0 or (Cp shr 12)) + Chr($80 or ((Cp shr 6) and $3F)) +
              Chr($80 or (Cp and $3F))
  else
    Result := Chr($F0 or (Cp shr 18)) + Chr($80 or ((Cp shr 12) and $3F)) +
              Chr($80 or ((Cp shr 6) and $3F)) + Chr($80 or (Cp and $3F));
end;

(* One entity at S[At] = '&' -> its text, or False and the caller emits '&' as-is. Only
   inside the cleaner: prose quoting `&amp;` literally is protected by the gate. *)
function HtmlEntityAt(const S: string; At: Integer; out AText: string; out AEnd: Integer): Boolean;
var
  i, from: Integer;
  name: string;
  cp: Cardinal;
begin
  Result := False;
  i := At + 1;
  from := i;
  while (i <= Length(S)) and (i - from < 12) and (S[i] <> ';') do Inc(i);
  if (i > Length(S)) or (S[i] <> ';') then Exit;
  name := LowerAscii(Copy(S, from, i - from));
  AEnd := i;
  if name = 'nbsp' then AText := ' '
  else if name = 'amp' then AText := '&'
  else if name = 'lt' then AText := '<'
  else if name = 'gt' then AText := '>'
  else if name = 'quot' then AText := '"'
  else if (name = 'apos') or (name = '#39') then AText := ''''
  (* the entities a paste actually carries: the dashes, the ellipsis, the quote pairs and
     the marks -- each spelled as its codepoint so the table cannot drift from UTF-8 *)
  else if name = 'mdash' then AText := Utf8OfCodepoint($2014)
  else if name = 'ndash' then AText := Utf8OfCodepoint($2013)
  else if name = 'hellip' then AText := Utf8OfCodepoint($2026)
  else if name = 'laquo' then AText := Utf8OfCodepoint($AB)
  else if name = 'raquo' then AText := Utf8OfCodepoint($BB)
  else if name = 'ldquo' then AText := Utf8OfCodepoint($201C)
  else if name = 'rdquo' then AText := Utf8OfCodepoint($201D)
  else if name = 'lsquo' then AText := Utf8OfCodepoint($2018)
  else if name = 'rsquo' then AText := Utf8OfCodepoint($2019)
  else if name = 'copy' then AText := Utf8OfCodepoint($A9)
  else if name = 'reg' then AText := Utf8OfCodepoint($AE)
  else if name = 'trade' then AText := Utf8OfCodepoint($2122)
  else if name = 'bull' then AText := Utf8OfCodepoint($2022)
  else if name = 'middot' then AText := Utf8OfCodepoint($B7)
  else if name = 'deg' then AText := Utf8OfCodepoint($B0)
  else if name = 'times' then AText := Utf8OfCodepoint($D7)
  else if name = 'sect' then AText := Utf8OfCodepoint($A7)
  else if name = 'euro' then AText := Utf8OfCodepoint($20AC)
  else if name = 'shy' then AText := ''   (* a soft hyphen is layout, not text *)
  else if (Length(name) > 1) and (name[1] = '#') then
  begin
    if (Length(name) > 2) and (name[2] = 'x') then
      cp := StrToDWordDef('$' + Copy(name, 3, MaxInt), 0)
    else
      cp := StrToDWordDef(Copy(name, 2, MaxInt), 0);
    (* A surrogate is not a character, and encoding one is invalid UTF-8 (Codex): the
       entity stays literal instead. *)
    if (cp = 0) or (cp > $10FFFF) or ((cp >= $D800) and (cp <= $DFFF)) then Exit;
    AText := Utf8OfCodepoint(cp);
  end
  else
    Exit;
  Result := True;
end;

function SpxCleanSourceHtml(const ASource: string): string;
var
  i, j, tagEnd, closeAt: Integer;
  name, body, ent, lowSrc: string;
  isClose, known: Boolean;
  lines: TStringList;
  s_: string;
  blanks: Integer;
begin
  (* PASS 1 -- THE GATE. Only a RECOGNISED tag turns the cleaner on: prose with a stray
     `<j>` or a literal `&amp;` is prose and comes back byte-identical. The gate WALKS the
     way pass 2 does -- past a whole comment, past a doctype, past a parsed tag's quoted
     attributes -- because a known tag in any of those places is somebody QUOTING markup,
     and a one-byte step read straight through them (found by Codex review). *)
  known := False;
  i := 1;
  while (i <= Length(ASource)) and not known do
  begin
    if ASource[i] = '<' then
    begin
      if Copy(ASource, i, 4) = '<!--' then
      begin
        closeAt := Pos('-->', ASource, i + 4);
        if closeAt = 0 then Break;
        i := closeAt + 3;
        Continue;
      end;
      if (i < Length(ASource)) and (ASource[i + 1] in ['!', '?']) then
      begin
        closeAt := HtmlGtAt(ASource, i);
        if closeAt = 0 then Break;
        i := closeAt + 1;
        Continue;
      end;
      if HtmlParseTag(ASource, i, name, isClose, body, tagEnd) then
      begin
        known := HtmlKnown(name);
        i := tagEnd + 1;
        Continue;
      end;
      (* Looks like a tag and never closes: everything after it is that tag's INSIDE --
         an unclosed quote, most likely -- and must not be read as markup. Erring this
         way keeps the promise that matters: prose comes back byte-identical. *)
      if HtmlTagLikeAt(ASource, i) then Break;
    end;
    Inc(i);
  end;
  if not known then Exit(ASource);
  (* Lowercased once: the close-tag search below runs per swallowed element, and a copy
     per element made the pass quadratic (Codex). *)
  lowSrc := LowerAscii(ASource);

  (* PASS 2 -- THE CLEANING. Linear; nothing emitted is re-read, so a decoded `&lt;`
     cannot become a tag. *)
  Result := '';
  i := 1;
  while i <= Length(ASource) do
  begin
    if ASource[i] = '<' then
    begin
      (* comments, doctypes and processing instructions vanish whole *)
      if Copy(ASource, i, 4) = '<!--' then
      begin
        closeAt := Pos('-->', ASource, i + 4);
        if closeAt = 0 then i := Length(ASource) + 1 else i := closeAt + 3;
        Continue;
      end;
      if (i < Length(ASource)) and (ASource[i + 1] in ['!', '?']) then
      begin
        closeAt := HtmlGtAt(ASource, i);
        if closeAt = 0 then i := Length(ASource) + 1 else i := closeAt + 1;
        Continue;
      end;
      if HtmlParseTag(ASource, i, name, isClose, body, tagEnd) then
      begin
        if HtmlSwallowed(name) and (not isClose) and (not HtmlSelfClosed(body)) then
        begin
          (* content and all: a <style> block is nobody's copy. The close matches by
             EXACT name -- `</styles>` is not `</style>`, and an end tag's name ends at
             whitespace, '/' or '>', not merely at this parser's name characters
             (`</style.foo>` extends it too; both from Codex review). *)
          closeAt := tagEnd;
          repeat
            closeAt := Pos('</' + name, lowSrc, closeAt + 1);
            j := closeAt + 2 + Length(name);
          until (closeAt = 0) or (j > Length(ASource)) or HtmlNameEnd(lowSrc[j]);
          if closeAt = 0 then i := Length(ASource) + 1
          else
          begin
            closeAt := Pos('>', ASource, closeAt);
            if closeAt = 0 then i := Length(ASource) + 1 else i := closeAt + 1;
          end;
          Continue;
        end;
        if HtmlKept(name) then
        begin
          (* normalised: the tag, no attributes -- except the one that is content *)
          if isClose then Result := Result + '</' + name + '>'
          else if (name = 'a') and (HtmlHrefOf(body) <> '') then
            Result := Result + '<a href="' + HtmlHrefOf(body) + '">'
          else
            Result := Result + '<' + name + '>';
        end
        else if HtmlBlockish(name) then Result := Result + LF
        else if HtmlCellish(name) then Result := Result + ' ';
        (* every other tag -- span, font, o:p, an unknown -- unwraps to its content *)
        i := tagEnd + 1;
        Continue;
      end;
      (* The gate stops at a tag-like '<' that never parses; the cleaner must own it the
         same way (Codex, third pass): the unterminated tag's tail is TEXT, handed over
         whole -- or a <style> gets read out of a quote that never closed. *)
      if HtmlTagLikeAt(ASource, i) then
      begin
        Result := Result + Copy(ASource, i, MaxInt);
        Break;
      end;
    end;
    if (ASource[i] = '&') and HtmlEntityAt(ASource, i, ent, tagEnd) then
    begin
      Result := Result + ent;
      i := tagEnd + 1;
      Continue;
    end;
    Result := Result + ASource[i];
    Inc(i);
  end;

  (* Layout whitespace is markup too, once the markup is gone: trim each line -- source
     indentation is the file's, not the copy's -- and let at most one blank line stand. *)
  lines := TStringList.Create;
  try
    SplitLF(Result, lines);
    Result := '';
    blanks := 0;
    for i := 0 to lines.Count - 1 do
    begin
      s_ := Trim(lines[i]);
      if Trim(s_) = '' then
      begin
        Inc(blanks);
        if (blanks > 1) or (Result = '') then Continue;
        s_ := '';
      end
      else
        blanks := 0;
      if Result <> '' then Result := Result + LF;
      Result := Result + s_;
    end;
    Result := Trim(Result);
  finally
    lines.Free;
  end;
end;

(* Strip what a model wraps its answer in despite being told not to. The output contract forbids
   fences and quotes; models emit them anyway. Contract in the prompt, tolerant parsing in the
   host -- never trust the contract alone.

   Hand-written because FPC has no regex here and the JS original is four expressions with the
   `u` and `i` flags. The Cyrillic prefix is the part a naive port gets wrong: `UpperCase` is
   ASCII-only in this dialect, so the fold is spelled out. *)
function SpxCleanModelTemplate(const ARaw: string): string;
const
  FENCE = '```';

  (* ONE UTF-8 DECODE, THEN A MEMBERSHIP TEST -- not a list of byte patterns.

     The first port of this hand-listed the byte sequences a reader thinks of (NBSP, U+2028,
     the BOM) and was six code points short of what the original accepts. `trim()` and `\s`
     under the `u` flag take the WHOLE Space_Separator category, and the expensive gap was not
     a stray edge space: the prefix scan below walks this function, so one unhandled space
     aborted the whole strip and left `Template : ...` in the reader's document. Decoding once
     and testing the code point cannot be short by one the way a list can. *)
  function CodePointAt(const S: string; P: Integer; out ALen: Integer): LongWord;
  var
    b: Byte;
  begin
    ALen := 0;
    Result := 0;
    if (P < 1) or (P > Length(S)) then Exit;
    b := Ord(S[P]);
    if b < $80 then begin ALen := 1; Exit(b); end;
    if (b and $E0) = $C0 then
    begin
      if P + 1 > Length(S) then begin ALen := 1; Exit(b); end;
      ALen := 2;
      Exit(((b and $1F) shl 6) or (Ord(S[P + 1]) and $3F));
    end;
    if (b and $F0) = $E0 then
    begin
      if P + 2 > Length(S) then begin ALen := 1; Exit(b); end;
      ALen := 3;
      Exit(((b and $0F) shl 12) or ((Ord(S[P + 1]) and $3F) shl 6) or
           (Ord(S[P + 2]) and $3F));
    end;
    if (b and $F8) = $F0 then
    begin
      if P + 3 > Length(S) then begin ALen := 1; Exit(b); end;
      ALen := 4;
      Exit(((b and $07) shl 18) or ((Ord(S[P + 1]) and $3F) shl 12) or
           ((Ord(S[P + 2]) and $3F) shl 6) or (Ord(S[P + 3]) and $3F));
    end;
    ALen := 1;
    Result := b;
  end;

  (* The start of a UTF-8 sequence at or before P, so the trailing scan can decode backwards. *)
  function StartOfCodePoint(const S: string; P: Integer): Integer;
  begin
    Result := P;
    while (Result > 1) and ((Ord(S[Result]) and $C0) = $80) do Dec(Result);
  end;

  (* JS WhiteSpace + LineTerminator, which is what both `trim()` and `\s` accept. *)
  function IsWhite(CP: LongWord): Boolean;
  begin
    Result := (CP = 9) or (CP = 10) or (CP = 11) or (CP = 12) or (CP = 13) or (CP = 32) or
              (CP = $A0) or (CP = $1680) or
              ((CP >= $2000) and (CP <= $200A)) or
              (CP = $2028) or (CP = $2029) or (CP = $202F) or (CP = $205F) or
              (CP = $3000) or (CP = $FEFF);
  end;

  (* `[a-z]` under the `i` and `u` flags. Case folding maps U+017F to `s` and U+212A to `k`,
     so V8 accepts either as a fence's language tag -- obscure, and exactly the sort of thing a
     port written as `C in ['a'..'z']` gets wrong without noticing. *)
  function IsFenceTagLetter(CP: LongWord): Boolean;
  begin
    Result := ((CP >= Ord('a')) and (CP <= Ord('z'))) or
              ((CP >= Ord('A')) and (CP <= Ord('Z'))) or
              (CP = $017F) or (CP = $212A);
  end;

  function IsSpace(const S: string; P: Integer): Integer;
  var
    len: Integer;
  begin
    Result := 0;
    if IsWhite(CodePointAt(S, P, len)) then Result := len;
  end;

  function TrimU(const S: string): string;
  var
    a, b, w, len: Integer;
  begin
    a := 1;
    repeat
      w := IsSpace(S, a);
      Inc(a, w);
    until w = 0;
    (* The trailing scan walks BACK to the start of the code point and then asks the same
       question the leading one asks. Written as two independent lists once, and the second
       list was missing U+FEFF -- which a fixture found. One predicate, two directions. *)
    b := Length(S);
    while b >= a do
    begin
      w := StartOfCodePoint(S, b);
      if not IsWhite(CodePointAt(S, w, len)) then Break;
      b := w - 1;
    end;
    Result := Copy(S, a, b - a + 1);
  end;

  (* Case-insensitive ASCII compare of a literal prefix. *)
  function StartsCI(const S, Prefix: string): Boolean;
  var
    i: Integer;
    a, b: Char;
  begin
    Result := False;
    if Length(S) < Length(Prefix) then Exit;
    for i := 1 to Length(Prefix) do
    begin
      a := S[i]; b := Prefix[i];
      if (a >= 'A') and (a <= 'Z') then Inc(a, 32);
      if (b >= 'A') and (b <= 'Z') then Inc(b, 32);
      if a <> b then Exit;
    end;
    Result := True;
  end;

  (* `шаблон` with either case on any letter. Cyrillic upper/lower differ by one byte in the
     UTF-8 ranges used here, so the fold is done on the decoded code point rather than on bytes:
     U+0410..U+042F fold to U+0430..U+044F, and U+0401 (Ё) to U+0451. *)
  function StartsCyrillic(const S, Prefix: string): Boolean;

    function FoldAt(const T: string; var P: Integer): Word;
    var
      cp: Word;
    begin
      Result := 0;
      if P > Length(T) then Exit;
      if Ord(T[P]) < $80 then
      begin
        Result := Ord(T[P]);
        Inc(P);
        Exit;
      end;
      if (P + 1 > Length(T)) then begin Inc(P); Exit(Ord(T[P - 1])); end;
      cp := ((Ord(T[P]) and $1F) shl 6) or (Ord(T[P + 1]) and $3F);
      Inc(P, 2);
      if (cp >= $0410) and (cp <= $042F) then cp := cp + 32
      else if cp = $0401 then cp := $0451;
      Result := cp;
    end;

  var
    ps, ss: Integer;
    a, b: Word;
  begin
    ps := 1; ss := 1;
    while ps <= Length(Prefix) do
    begin
      b := FoldAt(Prefix, ps);
      if ss > Length(S) then Exit(False);
      a := FoldAt(S, ss);
      if a <> b then Exit(False);
    end;
    Result := True;
  end;

var
  t: string;
  i, w, cpLen: Integer;
begin
  t := TrimU(ARaw);

  (* ^```[a-z]*\r?\n? *)
  if Copy(t, 1, 3) = FENCE then
  begin
    i := 4;
    while (i <= Length(t)) and IsFenceTagLetter(CodePointAt(t, i, cpLen)) do Inc(i, cpLen);
    if (i <= Length(t)) and (t[i] = #13) then Inc(i);
    if (i <= Length(t)) and (t[i] = #10) then Inc(i);
    t := Copy(t, i, Length(t));
  end;

  (* \r?\n?```$ *)
  if (Length(t) >= 3) and (Copy(t, Length(t) - 2, 3) = FENCE) then
  begin
    i := Length(t) - 3;
    if (i >= 1) and (t[i] = #10) then Dec(i);
    if (i >= 1) and (t[i] = #13) then Dec(i);
    t := Copy(t, 1, i);
  end;
  t := TrimU(t);

  (* ^(?:template|шаблон)\s*:\s* *)
  i := 0;
  if StartsCI(t, 'template') then i := 9
  else if StartsCyrillic(t, 'шаблон') then i := 13;   (* six two-byte letters, 1-based next *)
  if i > 0 then
  begin
    repeat
      w := IsSpace(t, i);
      Inc(i, w);
    until w = 0;
    if (i <= Length(t)) and (t[i] = ':') then
    begin
      Inc(i);
      repeat
        w := IsSpace(t, i);
        Inc(i, w);
      until w = 0;
      t := TrimU(Copy(t, i, Length(t)));
    end;
  end;

  (* paired quotes, straight or curly *)
  (* NO LENGTH GUARD, because the original has none: for a lone `"` both `startsWith` and
     `endsWith` are true and `slice(1, -1)` gives the empty string. A `>= 2` here kept it. *)
  if (Length(t) >= 1) and (t[1] = '"') and (t[Length(t)] = '"') then
    t := TrimU(Copy(t, 2, Length(t) - 2))
  else if (Length(t) >= 6) and (Copy(t, 1, 3) = #$E2#$80#$9C) and
          (Copy(t, Length(t) - 2, 3) = #$E2#$80#$9D) then
    t := TrimU(Copy(t, 4, Length(t) - 6));

  Result := t;
end;

function SpxChannelFromName(const S: string): TSpxChannel;
begin
  if S = 'email' then Result := chEmail
  else if S = 'sms' then Result := chSms
  else if S = 'push' then Result := chPush
  else if S = 'landing' then Result := chLanding
  else Result := chGeneric;
end;

function SpxVariationFromName(const S: string): TSpxVariation;
begin
  if S = 'conservative' then Result := vlConservative
  else if S = 'aggressive' then Result := vlAggressive
  else Result := vlBalanced;
end;

function SpxVarCaseFromName(const S: string): TSpxVarCase;
begin
  if S = 'nominative' then Result := vcNominative
  else if S = 'genitive' then Result := vcGenitive
  else if S = 'dative' then Result := vcDative
  else if S = 'accusative' then Result := vcAccusative
  else if S = 'instrumental' then Result := vcInstrumental
  else if S = 'prepositional' then Result := vcPrepositional
  else Result := vcNone;
end;

end.
