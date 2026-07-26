{**
 * SpxDemo -- the template the editor opens with, and the one the suite scans.
 *
 * It is the walkthrough from spintax.net, kept here verbatim because it exercises nearly
 * the whole surface in one document: `#set` and `#def` macros, a value-driven conditional,
 * locale-aware plurals, permutations with and without size bounds, nested
 * enumerations, and ordinary HTML around all of it.
 *
 * One text, two jobs. The window opens on something that demonstrates the product rather
 * than a toy, and the tests get a realistic document to scan and validate -- so "the
 * tokenizer survives a real template" and "a real template validates clean" are checks
 * rather than hopes. If it ever stops validating clean, either the template or this
 * project's understanding of the language has drifted, and both are worth knowing.
 *}
unit SpxDemo;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

{ LF-terminated, like every other text this layer handles; the editor shows it with whatever
  the platform draws. }
function SpxDemoTemplate: string;

implementation

const
  LF = #10;

function SpxDemoTemplate: string;
begin
  Result :=
    '#set %OwnLang% = {our own template language|a markup language we built|our own template syntax}' + LF +
    '#set %Unique% = {genuinely unique|truly distinct|non-repeating}' + LF +
    '#set %Source% = {a single source you control|one master you own|a single source of truth}' + LF +
    '#set %Engine% = {engine|spintax engine|renderer}' + LF +
    '#set %N% = {hundreds|thousands|millions}' + LF +
    '#def %ai% = {yes|}' + LF +
    '#def %pages% = {1|3|48}' + LF +
    LF +
    '<p>Spintax {(spin syntax)|— "spin syntax" —} is %OwnLang% for {producing|generating} many ' +
    '%Unique% variations of a text from %Source%. You write one template that encodes every ' +
    'choice — [<sep=", ";lastsep=", and "> alternatives|orderings|conditions|variables] ' +
    '— and the %Engine% expands it into %N% of %Unique% variants. {Every variation is one you ' +
    'defined|You define every variation}, so the output stays {on-brand and correct|accurate ' +
    'and on-brand} rather than a probabilistic guess.</p>' + LF +
    '<p>The {modern|AI-era} workflow {pairs|combines} a {language model|large language model} ' +
    'with that template logic. {?ai?Have an AI draft the richly varied template once|Write one ' +
    'richly varied template by hand}; the %Engine% then renders {unlimited|endless} variants ' +
    '{locally|on your own hardware}, deterministically, and at near-zero cost.</p>' + LF +
    '<p>With spintax you {roll out|publish} %Unique% content across [<minsize=1;maxsize=3;sep=", ";lastsep=", or "> ' +
    '%pages% {plural %pages%: page|pages}|dozens of sites|many locales] — unique by construction, ' +
    'not spun gibberish.</p>' + LF +
    '<p>Modern spintax is far more than flat alternation. It adds [<minsize=3;maxsize=6;sep=", ";lastsep=", and "> ' +
    'permutations that pick and order a subset|scoped variables|value-driven conditionals|' +
    'locale-aware plural agreement|reusable includes|a post-processing pass for spacing and ' +
    'capitalisation].</p>' + LF +
    '<p>And it {runs wherever you do|works anywhere you deploy}: four {independent|standalone}, ' +
    'open-source implementations — for [<sep=", ";lastsep=", and "> ' +
    'JavaScript|PHP|Python|Object Pascal] — all held to one shared corpus so a template renders ' +
    'identically on every one.</p>';
end;

end.
