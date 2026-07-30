{**
 * SpxStudio -- editor-core (spec §5, layer 2): a GUI- and network-free orchestration
 * seam over `unit Spintax`, the layer both the GUI and the LLM loop hang off.
 *
 * What lives here is the Studio-side CONTEXT -- locale, runtime variable values, the
 * template set, the RNG mode -- and the handful of calls that turn it into engine calls.
 * What does NOT live here is a second implementation of anything the engine already does:
 * no rescanning, no re-deriving of verdicts, and no include expansion. `#include` is
 * resolved BY THE ENGINE through a resolver this layer hands it (ADR 0003, engine ADR
 * 0004); all Studio owns is the lookup.
 *
 * Three engine facts are enforced in one place rather than remembered at every call site,
 * because each has already cost this family a debugging session (spec §7):
 *   - the host must set the UTF-8 codepage before the first engine call;
 *   - `Default(TSpContext)` leaves PostProcess FALSE, where every shipping engine defaults
 *     it true -- so every render from here sets it explicitly;
 *   - the RNG is a seam: a seeded generator for a stable preview and for reproducible
 *     export, no generator at all when the caller wants a fresh draw.
 *
 * NOT THREAD-SAFE against concurrent calls, by design. The engine builds a lazy global on
 * its first post-process, so two first renders on two threads race; this layer keeps no
 * state of its own so a single dedicated worker can own every call (spec §5).
 *}
unit SpxStudio;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  Classes, Generics.Collections, Spintax;

type
  { A preview draws fresh unless the user pins a seed; a batch always seeds, because an
    exported variant that cannot be regenerated is not reproducible (spec §4.6). }
  TSpxRngMode = (spxRandom, spxSeeded);

  (* Which language the product SPEAKS. It lives here, in the GUI-free layer, because the
     diagnostics panel's wording is built here -- on the worker thread, next to the codes it
     explains -- and a language enum is not a window. The window's own string table
     (SpxStrings) uses this same type, so there is one language in the product rather than
     two that agree by convention.

     THE LIST IS THE SITE'S, not a guess: spintax.net ships in en, ru, es, fr, de, it, pt,
     nl, tr (plus ar, zh, ja, ko, which wait for right-to-left layout and a width model that
     is not seven pixels per code point). To those are added the locales this product already
     supports for PLURAL rules and has been tested on -- uk, be, sr, hr, bs -- so an author
     writing Ukrainian or Croatian templates can have the window in that language too.

     Every one of them is Latin or Cyrillic script, which is what makes this one wave rather
     than three: the layout and the length budgets hold as they are.

     English is the base; anything without a translation falls back to it rather than to a
     half-translated window. *)
  TSpxLang = (spxLangEn, spxLangRu, spxLangUk, spxLangBe, spxLangSr, spxLangHr, spxLangBs,
              spxLangDe, spxLangFr, spxLangEs, spxLangIt, spxLangPt, spxLangNl, spxLangTr);

  { The workspace's template set: slug -> text, built by the HOST from a folder listing and
    handed in whole (ADR 0003). editor-core does no I/O, so M0 is testable without a
    filesystem and the folder rules live in the loader.

    Lookup is EXACT. TDictionary compares strings case-sensitively, which is what the engine
    does since v0.2.2 and what every engine in the family does -- `#include "Intro"` does not
    find `intro`. Do not "fix" that with a case-insensitive comparer: on NTFS the filesystem
    would happily open the wrong file and the preview would then disagree with every other
    engine about the same document. }
  TSpxTemplateSet = TStrMap;

  { The lookup half of the engine's seam (engine ADR 0004). The engine owns the semantics --
    the child is parsed and rendered on its own, inherits the runtime context but not the
    parent's #set/#def, an unknown target or a cycle or a depth overflow resolves to the
    empty string -- and this owns nothing but the map it was handed. }
  TSpxSetResolver = class(TSpIncludeResolver)
  private
    FTemplates: TSpxTemplateSet;   // caller owns
  public
    constructor Create(ATemplates: TSpxTemplateSet);
    function Resolve(const Ref: string; out Text: string): Boolean; override;
  end;

  { Everything an engine call needs that is not the template text. The variable map and the
    template set are the CALLER's -- this layer never frees them -- matching `TSpContext.Vars`
    and `TSpContext.IncludeResolver`, which the engine documents the same way.

    Templates = nil leaves every `#include` in the output verbatim, which is the engine's
    no-resolver behaviour and the reference's. MaxIncludeDepth is left at the engine's family
    default (20); Studio has no reason to want a different cap. }
  TSpxContext = record
    Locale: string;
    Vars: TStrMap;
    Templates: TSpxTemplateSet;
    RngMode: TSpxRngMode;
    Seed: LongWord;
  end;

  { One generated variant and the seed that produced it. The seed travels with the text
    because export has to be able to regenerate a single row later (spec §4.6): the same
    seed, engine tag and context reproduce it exactly. }
  TSpxVariant = record
    Seed: LongWord;
    Text: string;
  end;
  TSpxVariantList = TList<TSpxVariant>;

  { What the variables panel draws (spec §4.4). A macro is `#set` or `#def` and comes with
    the value and the position the ENGINE reported for its directive; a runtime variable is
    a `%name%` the document references and nothing defines, so its value is whatever the
    user has typed into the panel and its position is 0/0 -- there is no definition to jump
    to. }
  TSpxVarKind = (spxVarSet, spxVarDef, spxVarRuntime);

  TSpxVarInfo = record
    Name: string;          // lower-cased, the way the engine keys macros
    Kind: TSpxVarKind;
    Value: string;
    Line, Column: Integer;
    { Which occurrence this row is, in `SpExtractDirectives` order -- the index the edit
      functions take. -1 for a runtime variable, which has no directive to edit: its value
      lives in the session, not in the document. Carried here so a panel row never has to
      re-derive it by matching names, which duplicates would make ambiguous anyway. }
    DirIndex: Integer;
  end;
  { Flattened for the trip across a thread boundary, where a TList would need an owner on
    both ends of a queue that throws jobs away. }
  TSpxVarInfos = array of TSpxVarInfo;

  { A name and a value, the shape the panel hands session values back in. }
  TSpxVarPair = record
    Name: string;
    Value: string;
    (* LITERAL means the author typed text, not a template. The engine renders a
       host-supplied value exactly as it renders a `#set` one -- measured: `{a|b}` picks a
       variant, `%other%` expands -- which is the family's contract and the right default,
       because a production host passes its values raw and the preview has to agree with it.
       But an author pasting a price list with a brace in it means the brace, so this says
       which of the two it is. The neutralising is SpxValueForEngine's job, not the panel's. *)
    Literal: Boolean;
  end;
  TSpxVarPairs = array of TSpxVarPair;

  { One `#include` OCCURRENCE, so "jump to the directive" has somewhere to go and two
    includes of one target stay two rows. Known is measured against the template set, with
    the engine's exact comparison. }
  TSpxIncludeInfo = record
    Target: string;
    Known: Boolean;
    Line, Column: Integer;
    DirIndex: Integer;     // the occurrence, as in TSpxVarInfo
  end;

  { The panel's own shape for them, as TSpxVarInfos is for variables: the worker copies the
    model's list into one of these because the model is freed on the engine thread and the
    result crosses to the UI thread. }
  TSpxIncludeInfos = array of TSpxIncludeInfo;

  TSpxModel = class
  public
    Vars: TList<TSpxVarInfo>;
    Includes: TList<TSpxIncludeInfo>;
    constructor Create;
    destructor Destroy; override;
  end;

  { Diagnostics for ONE file, in that file's own coordinates. Slug is '' for the open
    document. Mixing coordinate spaces is the one thing this must never do: a position from
    a fragment means nothing in the editor's buffer. }
  TSpxFileReport = class
  public
    Slug: string;
    Diags: TSpDiagList;
    constructor Create(const ASlug: string; ADiags: TSpDiagList);
    destructor Destroy; override;
  end;

  { Studio's OWN findings, kept apart from engine diagnostics so the panel can say which is
    which (spec §4.3). They carry a file and a position for the same reason engine
    diagnostics do -- a note the user cannot jump to is a note they cannot act on.

    Position 0/0 means "unknown", the engine's own convention: the raw-sentinel note has one,
    because locating it would mean re-deriving the engine's editor-coordinate walk, and this
    layer does not re-derive what the engine owns. }
  TSpxNoteKind = (spxNoteCycle, spxNoteTooDeep, spxNoteCaseMismatch, spxNoteUnknownTarget,
                  spxNoteRawSentinel);

  TSpxNote = record
    Kind: TSpxNoteKind;
    Slug: string;      // the file the note was found in; '' = the open document
    Target: string;    // the include target it is about, where there is one
    Hint: string;      // the near-miss slug for a case mismatch
    Line, Column: Integer;
  end;
  TSpxNoteList = TList<TSpxNote>;

  { One diagnostic reduced to what an editor can draw: a span and whether it is fatal.
    Everything else -- the code, the file, the panel row -- stays in TSpxReport; this is the
    squiggle layer and nothing more. }
  TSpxDiagMark = record
    Line, Col: Integer;
    EndLine, EndCol: Integer;
    IsError: Boolean;
    Code: string;
  end;
  TSpxDiagMarks = array of TSpxDiagMark;

  { How a caller hands over one line's text. The seam exists so the code-point-to-byte work
    can be tested without a window: the editor supplies its own lines, the suite supplies a
    fixture, and the rule they share lives here. }
  TSpxLineFetch = function(ALine: Integer): string of object;

  { One line of the diagnostics panel. A row is a squiggle's opposite number: the squiggle
    can only show findings that HAVE a place in the open document, and this shows every
    finding there is -- in an included file, or with no position at all (spec §4.3).

    Source is kept because the panel must be able to say whose finding it is. An engine
    diagnostic is the family's verdict, identical in every implementation; a Studio note is
    this program's own observation and carries no weight elsewhere. Blurring them would let
    a note look like a parity failure. }
  TSpxRowSource = (spxRowEngine, spxRowStudio);

  TSpxPanelRow = record
    Slug: string;          // the file, '' = the open document
    Source: TSpxRowSource;
    Severity: string;      // 'error' | 'warning' | 'note'
    Code: string;          // the engine's code, or Studio's own note code
    Text: string;          // what the panel shows a human
    Line, Column: Integer; // 0 = unlocated: the row exists, the jump does not
    EndLine, EndColumn: Integer;
  end;
  TSpxPanelRows = array of TSpxPanelRow;

  { What the diagnostics panel and the repair loop consume (spec §4.3, §5).

    Errors/Warnings are counted over the WHOLE include closure, because an export degrades
    on a broken fragment just as surely as on a broken document. Probes are M renders used
    for the health flags, on fixed seeds so the same document always reports the same
    numbers. }
  TSpxReport = class
  public
    Files: TObjectList<TSpxFileReport>;
    Errors, Warnings: Integer;
    Probes, EmptyProbes, DistinctProbes: Integer;
    FullwidthFallback: Boolean;
    Notes: TSpxNoteList;
    constructor Create;
    destructor Destroy; override;
    function IsValid: Boolean;
  end;

{ Call once at start-up, before any engine call.

  Under FPC a `string` holds UTF-8 BYTES, and the RTL decodes literals, files and OS
  strings through DefaultSystemCodePage. Leave it at the machine's ANSI codepage and
  Cyrillic turns into '?' BEFORE the engine ever sees it -- the engine cannot fix that
  for its host, because the setting is a global of the host process. It cost the engine a
  whole debugging session (spec §7), which is why it is the first thing in this layer
  rather than a note in a README.

  A UTF-16 compiler needs nothing here: there `string` is code units and no codepage is
  consulted. }
procedure SpxInitHost;

{ A context that draws fresh every render -- the preview's default (spec §4.2). Templates
  may be nil: then `#include` stays in the output verbatim. }
function SpxContext(const Locale: string; Vars: TStrMap;
  Templates: TSpxTemplateSet = nil): TSpxContext;

{ A context pinned to a seed: the same template renders the same text every time, which is
  what makes a preview stable while an edit is compared against it, and what lets an
  exported row be regenerated. }
function SpxSeededContext(const Locale: string; Vars: TStrMap; Seed: LongWord;
  Templates: TSpxTemplateSet = nil): TSpxContext;

{ One rendered example. PostProcess is always on: the right pane is WYSIWYG against the
  engines that ship the text, and a preview without the cosmetic stage lies about spacing
  and capitalization. }
function SpxRenderSample(const Tmpl: string; const Ctx: TSpxContext): string;

{ A selection rendered in the document's scope (spec §4.2): the document's `#set`/`#def`
  lines, in source order, prepended to the fragment. The directives come from the engine's
  own list, so a `#set` that only LOOKS like one -- inside a `/# ... #/` comment, or
  malformed -- is not in scope here either.

  Two more divergences, both measured, both inherent to rendering a fragment AS a template:
    * post-process capitalises the first word of what it is given, so a mid-sentence
      selection comes back with a capital where the document has none -- selecting `world`
      out of `hello, world` renders `World`;
    * a selection taken from INSIDE a comment renders as live text, and a commented-out
      `#include` inside one actually resolves. The fragment is a template now; the comment
      that hid it is not in it.

  Not byte-identical to the same slice of a full render (fresh draw, `#def` rolled again).
  It is a true preview of what the fragment produces, not a promise of the same bytes. A
  selection taken from the MIDDLE of a line is rendered at a line start, so a line-anchored
  construct inside it (`#include`, `#set`) behaves as it would at the start of a line, not
  as it does where it sits -- the fragment is rendered "as if it were the template", which
  is the definition, not an accident. }
function SpxRenderFragment(const Doc, Fragment: string; const Ctx: TSpxContext): string;

{ The variables and includes panel model (spec §4.4). Macros and include occurrences come
  from `SpExtractDirectives` -- values and positions included -- and the runtime variables
  are what the document references and nothing defines. Caller frees. }
function SpxExtractModel(const Tmpl: string; const Ctx: TSpxContext): TSpxModel;

{ The session's values, filtered to the names that are STILL runtime variables -- referenced
  by the document and defined by nothing in it.

  A panel keeps what the user typed across renders, and that store has to be pruned or it
  accumulates ghosts: a value for a name the document has since DEFINED would go on being
  sent as a runtime variable, silently suppressing the `variable.undefined` warning for a
  macro that no longer needs it; a value for a name no longer referenced at all would travel
  with every job forever.

  Names come back in the model's spelling -- lower-cased, the way the engine keys them --
  because that is what the next render will match against, and the session may hold `BRAND`
  where the document says `%brand%`. The comparison is ASCII-case-insensitive for the same
  reason. }
function SpxKeepRuntime(const Vars: TSpxVarInfos;
  const Session: TSpxVarPairs): TSpxVarPairs;

{ ── what the editor's selection means (spec §4.2) ────────────────────────── }

type
  { A position the editor understands: a 1-based line and a BYTE column, which is what
    SynEdit's logical coordinates are. Deliberately not TPoint, and deliberately not
    TSynSelectionMode below: editor-core knows nothing about the LCL, and that is exactly
    what lets the console suite reach the two rules in this section. The form adapts
    SynEdit -> here -> SynEdit and does nothing else with them. }
  TSpxPos = record
    Line, Col: Integer;
  end;

  TSpxRange = record
    A, B: TSpxPos;
  end;

  { Column and line selections are named because they are REFUSED for wrapping: SelText
    round-trips them shape-wise, so an opener lands on the first row and a closer on the
    last, swallowing text nobody selected (measured). }
  TSpxSelKind = (spxSelNone, spxSelNormal, spxSelColumn, spxSelLine);

  TSpxSelection = record
    Kind: TSpxSelKind;
    Range: TSpxRange;
    Text: string;
  end;

  { What a jump left behind. A jump selects a span to SHOW it, which is not the user asking
    to preview that span. }
  TSpxJumpState = record
    Valid: Boolean;
    Range: TSpxRange;
  end;

function SpxPos(Line, Col: Integer): TSpxPos;
function SpxRange(const A, B: TSpxPos): TSpxRange;

{ The fragment to preview -- '' meaning "the whole document" -- and what the jump state
  becomes.

  Pure, and meant to be called at BOTH moments that matter: when the selection changes, and
  when a render is assembled. Twice, because the state alone cannot tell "the jump's
  selection is still untouched" from "the user has just selected exactly that range by
  hand", and only the selection-change call sees the difference between them. In that call
  the fragment is ignored and only the new state is kept, which is why a caller may leave
  Sel.Text empty there rather than pay for a copy of the selected text on every drag. }
function SpxPreviewFragment(const Sel: TSpxSelection; const Jump: TSpxJumpState;
  out NewJump: TSpxJumpState): string;

type
  { What the preview is being asked to show, as a comparable value: whether it narrows to a
    fragment and, if so, to which span. }
  TSpxPreviewAsk = record
    Narrowed: Boolean;
    Range: TSpxRange;
  end;

{ The same rule SpxPreviewFragment applies, expressed WITHOUT the selected text -- so a
  caller can ask "would this change the preview?" before deciding to render at all.

  It exists because of what a jump costs. Moving to a search hit or a diagnostic selects the
  span, the selection event fires, and the render is restarted -- to produce exactly the same
  preview, since a jump's own selection deliberately does not narrow. On a 116 KB template
  that is 320 ms of work and a visible flicker for every press of Enter in the find bar. }
function SpxPreviewAsk(const Sel: TSpxSelection; const Jump: TSpxJumpState): TSpxPreviewAsk;

{ Whether two asks would produce the same preview, and therefore whether a render can be
  skipped. }
function SpxPreviewSame(const A, B: TSpxPreviewAsk): Boolean;

{ Whether this selection can be wrapped, and the range the wrapped text will occupy
  afterwards -- so the caller can restore the block, without which the preview un-narrows on
  every wrap and a second wrap is a silent no-op.

  The opener shifts the end only when the end is on the SAME line as the start; the closer
  always does. }
function SpxWrapRange(const Sel: TSpxSelection; LeftLen, RightLen: Integer;
  out NewRange: TSpxRange): Boolean;

{ ── what the page view may be handed (ADR 0004, revised) ─────────────────── }

{ Whether output would show as an empty pane. Not `Trim(S) = ''`: the RTL trims bytes up to
  #32, so a fragment whose whole output is a non-breaking space or one of the separators the
  engine's own line model counts -- U+2028, U+2029 -- would be called non-empty and announced
  as "показан фрагмент" over a pane with nothing in it, which is the confusion the caption
  exists to prevent.

  An entity is NOT blank here: output of `&nbsp;` is output, the source view has it, and
  saying "nothing came out" would be false. }
function SpxIsBlankOutput(const S: string): Boolean;

{ Whether the output already opens the document itself -- `<html` or `<body` as its first
  token, after any leading whitespace, and the tag has to END there (`<htmlfoo` is not one).

  Those two shapes and no others, because those two carry attributes the renderer applies to
  the whole page: bgcolor, the link colours, a background image. IPro reads them off whichever
  `<body>` it meets FIRST, so a wrapper in front does not merely nest -- it replaces them with
  its own, empty set. Measured: `<body bgcolor="#101010" link="#ff0000">` keeps both bare and
  loses both wrapped, and a `background="bg.png"` goes the same way. }
function SpxOpensDocument(const AHtml: string): Boolean;

{ The engine's output, in a form the page view can actually display: inside a minimal
  document unless it already is one.

  IPro's parser wants a document, and does three things to a bare string that a preview must
  not do (all measured against the real parser, by asking it what tree it built; the tree
  agrees with the pixels -- every input measured as a black panel builds no BODY node, and
  every input measured white builds one):

  - A string with no element in it builds nothing, and the panel is then painted BLACK. That
    covers prose, '', a space, `&nbsp;`, and a comment on its own. Since a template is prose
    with markup around it, selecting a paragraph to preview hands the renderer exactly that,
    and the pane went black. Which is what it did.
  - A string that DOES start with text and then has a tag loses the text: `lead<p>tail</p>`
    renders as `tail`. Wrapped, both survive. That is the worse failure of the two -- a black
    rectangle gets reported, a quietly missing first paragraph does not.
  - An unterminated `<!` makes the parser loop FOREVER (`<p>x</p> <!oops` never returns;
    killed at 8 s), and it runs on the UI thread. The wrapper's own `>` ends that scan.

  So everything that is not already a document gets wrapped -- and output that IS one is left
  exactly as it was, because the wrapper would cost it its `<body>` attributes and its head
  (SpxOpensDocument). That line is where it is for a reason: past the first token none of the
  three failures above can happen, since a document that opens with `<html`/`<body` has no
  text in front of its first tag and always builds a body. The one exception it inherits is
  the parser's `<!` loop, which a document can still walk into -- IPro's defect, unchanged by
  this either way.

  Not byte-transparent for what it wraps, in two corner cases, both of which beat a black
  pane: output ending in a bare `<` swallows the wrapper's closing tag and shows it, and prose
  containing a literal `</body>` is cut there. The SOURCE view shows the engine's output raw
  either way, which is where "what markup came out" is answered (ADR 0004). }
function SpxPageDocument(const AHtml: string): string;

{ ── finding text in the template ─────────────────────────────────────────── }

type
  { One occurrence, in the EDITOR's coordinates: 1-based lines, 1-based code-point columns,
    the end exclusive -- the same model TSpDiag uses, so a match can be jumped to and
    selected by the machinery that already exists for diagnostics. }
  TSpxMatch = record
    Line, Col: Integer;
    EndLine, EndCol: Integer;
  end;
  TSpxMatches = array of TSpxMatch;

{ Every occurrence of Needle in Text, in document order.

  Case folding, when it is asked for, goes through the ENGINE's own table
  (SpUpperCodePoint) and is applied per code point DURING the comparison -- never by folding
  the two strings first. Folding first would be simpler and wrong: a few characters change
  length when folded, so every position after one of them would be reported at the wrong
  offset, and the editor would select the wrong span.

  An empty needle matches nothing, which is what a search box holds most of the time. }
function SpxFindAll(const Text, Needle: string; MatchCase: Boolean): TSpxMatches;

{ Which match to show for "next" / "previous", given where the caret is. Returns an index
  into Matches, or -1 when there are none. Wraps around the ends: a search that stops at the
  bottom of the file makes the user scroll back by hand, which is what the wrap is for.

  FORWARD IS AT-OR-AFTER, not strictly after. Opening a document parks the caret at 1:1, so
  a strict comparison made the first press of Enter land on the SECOND occurrence whenever
  the first one was at the very top -- and the first was then reachable only by wrapping the
  whole file. Callers that step repeatedly keep their own index rather than asking again from
  the match they are standing on, so at-or-after cannot leave them stuck. }
{ The fast case fold, exposed for one reason only: the suite checks it against the
  engine's own table across the ranges it claims. Hand-rolled arithmetic about letters
  is allowed here only because that check exists. }
function SpxTestFastUpper(CP: LongWord): LongWord;

function SpxStepMatch(const Matches: TSpxMatches; Line, Col: Integer;
  Backwards: Boolean): Integer;

{ ── editing a directive where it sits (spec §4.4) ────────────────────────── }

{ The byte offset of a 1-based (Line, code-point Column) in Doc, over the EDITOR's line
  model -- LF, CR and CRLF each end a line -- which is the model `TSpDiag` and
  `TSpDirective` positions use. NOT the five terminators directives themselves split on:
  two directives separated by U+2028 are two directives on ONE line, and their columns
  continue across it. Clamps to Length(Doc) + 1. }
function SpxDocOffset(const Doc: string; Line, Column: Integer): Integer;

{ The edits the variables panel needs, each rewriting the SMALLEST region that can carry the
  change and leaving every other byte of the document alone. Index selects an occurrence in
  `SpExtractDirectives` order.

  Why not one "re-spell this directive" call, which is what the backlog sketched: the engine
  reports a macro's name LOWER-CASED and its value TRIMMED, and the span it gives covers the
  indentation, the keyword's own spelling and the spacing around `=`. Re-emitting the line
  from those three fields would quietly rewrite `<TAB>#set  %Brand%=x   ` as
  `#set %brand% = x` -- a formatting change nobody asked for, in a file the user keeps in
  git. Splicing one region cannot do that.

  Each returns False and leaves NewDoc = Doc when the edit cannot be made byte-safely:
    * the index is out of range;
    * the occurrence's span does not equal the text the renderer consumed. That is ANY
      comment inside the directive, not only one that swallowed the line's terminator: the
      engine cuts Text from comment-stripped source while the span maps back to the source,
      so `#set %x% = A /# c #/ B` differs in the two and rewriting the span would delete the
      comment. Such a row is read-only in the panel;
    * the change does not fit the kind: an `#include` has no value, and `#set` cannot become
      `#include` by swapping four characters;
    * the RESULT would not say what was asked. The written text is not trusted: a value
      carrying `/#` opens a comment that eats the rest of the file, one carrying a line break
      ends the directive early, an empty or spaced name is no directive at all. Every edit is
      read back with `SpExtractDirectives` and refused unless the engine agrees. }
function SpxSetDirectiveValue(const Doc: string; Index: Integer; const Value: string;
  out NewDoc: string): Boolean; overload;

{ The same edit, ALSO reporting the region it replaced -- and that is what lets a host apply it
  through its own editor API instead of assigning a whole new document. The difference is not
  cosmetic: SynEdit given a new `Text` throws the undo history away and moves the caret, which
  is exactly why editing a definition in its row waited for this.

  SpanA is the first byte replaced and SpanB the first byte KEPT after it -- the half-open pair
  `Splice` takes, and the one the group editor's write-back already speaks (SpxGroups'
  BodyStart/Stop). On a refusal both come back 0 along with NewDoc = Doc.

  The caller must apply the SPAN, not diff the two documents: a diff is a second opinion about
  what changed, and the day an edit touches two places it would be a wrong one. }
function SpxSetDirectiveValue(const Doc: string; Index: Integer; const Value: string;
  out NewDoc: string; out SpanA, SpanB: Integer): Boolean; overload;
(* THIS RENAMES THE DEFINITION AND NOTHING ELSE -- so do NOT wire it to a panel cell as a
  "rename". Measured 2026-07-30: `#set %brand% = {Акме|Вулкан}` with two `%brand%` references
  goes from a clean document to `variable.undefined`, and the render prints `%brand%` literally
  instead of the value. The references keep the old name because nothing here touches them.

  A rename a user would accept has to carry the references with it, and the engine reports
  reference names WITHOUT positions (`SpExtract`) -- so it needs the highlighter's scanner, the
  way the jump and the name-spelling already do. That is a refactoring feature, not a cell edit,
  and it is not planned (docs/TODO.md). This function stays because it is correct at what it
  says it does and the suite pins it. *)
function SpxSetDirectiveName(const Doc: string; Index: Integer; const Name: string;
  out NewDoc: string): Boolean;
{ Both of these are correct and tested, and neither is wired to anything: swapping `#set` for
  `#def` is four characters in the editor and dropping a definition is one line, so a panel
  path for them would only add a second way to write the file. Kept for a caller that has a
  reason the panel does not. }
function SpxSetDirectiveKind(const Doc: string; Index: Integer; const Kind: string;
  out NewDoc: string): Boolean;

{ Removes the occurrence, and the line with it when nothing else was on that line. A head or
  tail comment IS something else, so those lines stay. }
function SpxDeleteDirective(const Doc: string; Index: Integer; out NewDoc: string): Boolean;

type
  { A memo for per-file validation, owned by the CALLER.

    Why it exists: the closure walk validates every file in the set on every render, while
    only the open document has changed. `SpValidate` is quadratic in the number of
    `#set`/`#def` definitions -- measured on the v0.3.2 engine at 17.6 / 253 / 3982 ms for
    400 / 1600 / 6400 definitions -- so a folder of fragments makes a keystroke pay for all
    of them.

    Why it is not inside editor-core's functions: this layer stays stateless so one worker
    can own every engine call (spec §5), and deciding what may be reused is the caller's,
    because the caller is what knows the user touched one file. So the cache is an object
    the caller creates, hands in, and frees.

    The KEY is everything the answer depends on -- locale, the known-include list, the known
    variable list, the slug, the text -- because a hit that ignores any of them serves a
    verdict computed under different rules. Lengths are baked into the key so that no
    concatenation of two fields can collide with another.

    Entries live one ROUND: whatever a round does not touch is dropped when it ends. That
    bounds the cache to the current closure and evicts the previous keystroke's document
    instead of keeping a copy of every text the user has ever typed. Two consequences worth
    knowing rather than discovering: alternating between two documents that share no
    fragments hits nothing, because each round evicts the other's entries (harmless while
    one document is open, worth revisiting if tabs arrive); and the round is a CONVENTION --
    SpxHealthReport pairs BeginRound with EndRound, and calling Validate outside one simply
    keeps everything it was given.

    NOT thread-safe, like everything else here: one worker owns the engine and owns this. }
  TSpxValidationCache = class
  private
    { Dictionaries, NOT sorted string lists. TStringList decides identity through
      DoCompareText, which with CaseSensitive uses AnsiCompareStr -- the OS collation on
      Windows -- and that calls distinct code points equal: U+082D and U+0B60 compare 0,
      along with ~900 other pairs in the 3-byte range alone. A cache keyed that way serves
      one document's verdict for another's, silently, and differently on machines with
      different collation tables. Measured, and gated by `cache/a-hit-is-byte-exact`.
      A dictionary compares bytes and hashes the key once instead of collating a whole
      document per probe. }
    FEntries: TDictionary<string, TSpDiagList>;   // the lists are owned here
    FUsed: TDictionary<string, Boolean>;          // keys touched in the current round
    FHits, FMisses: Integer;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure BeginRound;
    procedure EndRound;
    { The file's diagnostics, computed only on a miss. The caller OWNS the returned list --
      the report it goes into frees it -- so a hit hands back a copy, never the entry. }
    function Validate(const Slug, Text, Locale: string;
      KnownIncludes, KnownVars: TStringList): TSpDiagList;
    property Hits: Integer read FHits;
    property Misses: Integer read FMisses;
    property Count: Integer read GetCount;
  end;

{ Diagnostics for the document AND every file it includes, each validated separately in its
  own coordinates (spec §4.3), plus Probes health renders. Caller frees.

  `knownVariables` is the runtime context's names, for every file: a file's own `#set`/`#def`
  are visible to the validator already, and the parent's are NOT visible to a child at render
  time, so passing them down would silence a warning that is true (ADR 0003).

  DocSlug is the document's own slug when it is a member of the set -- which it is whenever
  the host built the set from the folder the document lives in. Without it the walk would
  reach the document again through its own slug and validate the same text twice, counting
  one broken bracket as two errors.

  LIMIT, and it cannot be closed here: the closure is found by scanning SOURCE for `#include`
  lines, while the engine resolves over the RENDERED text. An include that only appears after
  a macro expands (`#set %inc% = #include "frag"`, then `%inc%`) is resolved by the engine and
  never validated by this walk. Closing it would mean rendering first and re-parsing the
  output, which buys a corner at the price of the whole design.

  No caching STATE here: this layer stays stateless so one worker can own every engine call
  (spec §5). Deciding what may be reused is the caller's, which is the layer that knows what
  the user touched -- so it hands in a TSpxValidationCache it owns, or nothing at all and
  every file is validated afresh. The report is identical either way; that is what the suite
  checks. }
function SpxHealthReport(const Doc: string; const Ctx: TSpxContext;
  Probes: Integer; const DocSlug: string = '';
  Cache: TSpxValidationCache = nil): TSpxReport;

{ The OPEN DOCUMENT's diagnostics as spans the editor can underline (spec §4.1).

  Three rules, all of them the spec's:
    * only the document's own file. A fragment's Line/Column are coordinates in ANOTHER
      buffer, and drawing them here would underline whatever text happens to sit there;
    * `Line = 0` means the engine could not locate the finding, honestly. It stays in the
      panel and gets no squiggle -- Studio does not invent a place;
    * `End* = 0` means no span was cheap to compute, so the mark is one character wide at
      the start rather than a guess at the extent. }
function SpxDocumentMarks(Report: TSpxReport): TSpxDiagMarks;

{ THE ONE CONVERSION between the engine's columns and the editor's.

  The engine counts a column in CODE POINTS, and says why in its own header: the number then
  means the same character under FPC's UTF-8 and under a UTF-16 compiler, and the shared
  corpus is full of Cyrillic, where a byte column would point into the middle of a letter.
  SynEdit's logical coordinates are BYTES. Handing one to the other lands the caret in the
  wrong place on every line that has a non-ASCII character before the finding -- measured in
  the running app, where a jump to a `{` in code-point column 35 arrived thirteen characters
  early.

  Walked with the engine's own SpCodePointAt, so both sides agree on what a character is.
  1-based in and out; a column past the end clamps to just after the last byte, which is
  where an editor puts a caret at the end of a line. }
(* The session value as the ENGINE must receive it. A literal one goes through the engine's
  own SpNeutralize, which marks its structural characters with the private-use sentinels the
  parser skips and the renderer removes -- measured: `{дёшево|дорого}` handed over neutralised
  renders as those eight characters and no choice, and the sentinels do not reach the output.

  The value the AUTHOR sees is never this one: neutralising is not reversible by stripping
  (SpStripSentinels takes the marked characters with it, leaving `a|b` out of `{a|b}`), so the
  panel keeps what was typed and this is produced on the way past. *)
function SpxValueForEngine(const Pair: TSpxVarPair): string;

{ THE KEYWORD, not the line's edge. A directive's reported Column is where its CONSUMED text
  begins, and the indentation is part of that: `  #set %a% = 1` reports column 1, not 3. So a
  jump straight to it lands in the margin and the eye has to find the `#set` itself -- which is
  the one thing the row was clicked to reach.

  Only blanks are skipped, and only forward, because only blanks can be there: a comment is NOT
  consumed, so `/# c #/#set %a% = 1` already reports 8, the `#` itself. A column past the end,
  or one with nothing but blanks after it, comes back unchanged rather than out of range.

  Code points in and out, like every column in this unit. }
function SpxFirstNonBlankColumn(const Line: string; CodePointCol: Integer): Integer;

function SpxByteColumn(const Line: string; CodePointCol: Integer): Integer;

{ The longest line in Text, in bytes, counting the editor's three line endings.

  Not a curiosity: SynEdit's word-wrap plugin costs roughly the SQUARE of a line's length,
  measured on this machine at 156 ms for one 100 KB line and 14.5 seconds for one of 1 MB --
  while the same megabyte in short lines takes 94 ms and the HTML highlighter over it takes
  32. Rendered output has no obligation to contain a single line break, so the view asks this
  before deciding whether to wrap at all. }
function SpxLongestLine(const Text: string): Integer;

{ The other direction: a byte column back to a code-point one. The editor's LOGICAL caret is
  a byte offset, and every position this unit speaks in is a code point, so a caret handed
  back to core has to come through here. (Its PHYSICAL column is a third thing again -- a tab
  is one code point and up to eight physical columns, a combining mark is one code point and
  none -- and is never the right number to convert.) }
function SpxCodePointColumn(const Line: string; ByteCol: Integer): Integer;

{ The same marks with their columns in bytes, for an editor whose logical coordinates are
  byte offsets. EndCol is converted against the END line's text -- the one detail here worth
  gating, because converting it against the start line works for every single-line span and
  fails only on the multi-line ones, which is the definition of a bug that ships. }
function SpxMarksToBytes(const Marks: TSpxDiagMarks; GetLine: TSpxLineFetch): TSpxDiagMarks;

{ The whole report as panel lines (spec §4.3): every engine diagnostic and every Studio note,
  in the order a reader wants them -- the open document first, then each included file in the
  order the closure walk reached it, and inside a file by position with the unlocated ones
  last, because a row you can jump to is worth more than one you cannot.

  Nothing is dropped and nothing is invented: a finding with no position keeps Line = 0 and
  the caller must not offer a jump for it. }
function SpxPanelRows(Report: TSpxReport; Lang: TSpxLang): TSpxPanelRows;

{ A human's reading of an engine diagnostic code. The engine deliberately ships codes and
  severities only -- those are the family's parity contract, and a message would be one more
  thing four implementations must agree on -- so the wording is the host's business.

  An unknown code returns ITSELF rather than a guess or an empty string: a new engine
  release must show up in the panel as its code, not as a blank line.

  The language is a PARAMETER rather than a global the window sets, because these rows are
  built on the engine worker while the window is doing something else, and a diagnostic
  whose wording depends on when it was rendered is the kind of bug that only shows up in a
  screenshot. }
function SpxDiagText(const Code: string; Lang: TSpxLang): string;

{ The language for a document locale, by the engine's own normalisation -- so `RU`, `ru-RU`
  and `ru` are one language here as they are everywhere else in the family. }
{ The engine's own code for a language ('en', 'ru', …) -- the inverse of SpxLangFor, and the
  form in which a language is written down: an enum's ORDINAL must never reach a settings file,
  because inserting a language would then silently rename everyone's. }
function SpxLangCode(ALang: TSpxLang): string;

function SpxLangFor(const Locale: string): TSpxLang;

{ The same for Studio's own notes, which carry their subject rather than a code. }
function SpxNoteText(const Note: TSpxNote; Lang: TSpxLang): string;

{ Count variants with reproducible seeds: `seed_i = SeedBase + i`, recorded on each variant.
  TMulberry32Rng mixes its seed internally (add-constant, then xorshift-multiply), so
  consecutive seeds give uncorrelated streams and the derivation needs nothing cleverer
  (spec §4.6).

  Ctx.RngMode is deliberately IGNORED here: a batch is always seeded, or the set it produces
  cannot be regenerated. Count <= 0 yields an empty list. The caller frees the list. }
function SpxRenderBatch(const Tmpl: string; const Ctx: TSpxContext;
  Count: Integer; SeedBase: LongWord): TSpxVariantList;

implementation

uses
  SysUtils;   // implementation-only: Trim, Format-free helpers below

procedure SpxInitHost;
begin
  {$IFDEF FPC}
  DefaultSystemCodePage := CP_UTF8;
  {$ENDIF}
end;

constructor TSpxSetResolver.Create(ATemplates: TSpxTemplateSet);
begin
  inherited Create;
  FTemplates := ATemplates;
end;

{ False is the reference's `null`: no such template. The engine turns that into the empty
  string, leniently, and never into an error -- an unknown target is already reported by
  SpValidate against the set's slugs (spec §4.3), which is where a user should hear about it. }
function TSpxSetResolver.Resolve(const Ref: string; out Text: string): Boolean;
begin
  Text := '';
  Result := (FTemplates <> nil) and FTemplates.TryGetValue(Ref, Text);
end;

function SpxContext(const Locale: string; Vars: TStrMap;
  Templates: TSpxTemplateSet = nil): TSpxContext;
begin
  Result.Locale := Locale;
  Result.Vars := Vars;
  Result.Templates := Templates;
  Result.RngMode := spxRandom;
  Result.Seed := 0;
end;

function SpxSeededContext(const Locale: string; Vars: TStrMap; Seed: LongWord;
  Templates: TSpxTemplateSet = nil): TSpxContext;
begin
  Result := SpxContext(Locale, Vars, Templates);
  Result.RngMode := spxSeeded;
  Result.Seed := Seed;
end;

{ The engine context for one call. Rng = nil is not an oversight: the engine then builds its
  own default generator, which is the analogue of the reference rendering with no seed. The
  resolver is nil exactly when there is no template set, which leaves `#include` verbatim --
  also the reference's behaviour with no resolver.

  MaxIncludeDepth stays 0, which selects the engine's SP_DEFAULT_INCLUDE_DEPTH, the family's
  20. A different cap would make this preview disagree with the engines that ship the text. }
function EngineContext(const Ctx: TSpxContext; Rng: TSpRng;
  Resolver: TSpIncludeResolver): TSpContext;
begin
  Result := Default(TSpContext);
  Result.Locale := Ctx.Locale;
  Result.Vars := Ctx.Vars;
  Result.PostProcess := True;   // never left to the record's zeroed default (spec §7)
  Result.Rng := Rng;
  Result.IncludeResolver := Resolver;
end;

{ One render with the seed the caller asked for, or with none. Whatever this creates, it
  frees: the engine takes ownership of neither the RNG nor the resolver. }
function RenderWith(const Tmpl: string; const Ctx: TSpxContext;
  Seeded: Boolean; Seed: LongWord): string;
var rng: TSpRng; resolver: TSpxSetResolver;
begin
  if Seeded then rng := TMulberry32Rng.Create(Seed) else rng := nil;
  if Ctx.Templates <> nil then resolver := TSpxSetResolver.Create(Ctx.Templates)
  else resolver := nil;
  try
    Result := SpRender(Tmpl, EngineContext(Ctx, rng, resolver));
  finally
    resolver.Free;
    rng.Free;
  end;
end;

function SpxRenderSample(const Tmpl: string; const Ctx: TSpxContext): string;
begin
  Result := RenderWith(Tmpl, Ctx, Ctx.RngMode = spxSeeded, Ctx.Seed);
end;

{ The derivation, in its own guarded region. LongWord arithmetic wraps at the top of the
  range, which is the intended behaviour -- the seed is an identifier for regenerating a row,
  not a counter -- but a build with overflow checks on raises on it instead, and the comment
  saying "wraps" was not enough: the checked twin of the suite proved it the day a test
  finally started a batch at $FFFFFFFE. Lifted around this one line, restored to whatever the
  build had. }
{$IFOPT Q+}{$DEFINE SPX_Q_WAS_ON}{$Q-}{$ENDIF}
{$IFOPT R+}{$DEFINE SPX_R_WAS_ON}{$R-}{$ENDIF}

function SeedAt(SeedBase: LongWord; I: Integer): LongWord;
begin
  Result := SeedBase + LongWord(I);
end;

{$IFDEF SPX_R_WAS_ON}{$R+}{$UNDEF SPX_R_WAS_ON}{$ENDIF}
{$IFDEF SPX_Q_WAS_ON}{$Q+}{$UNDEF SPX_Q_WAS_ON}{$ENDIF}

function SpxRenderBatch(const Tmpl: string; const Ctx: TSpxContext;
  Count: Integer; SeedBase: LongWord): TSpxVariantList;
var i: Integer; v: TSpxVariant;
begin
  Result := TSpxVariantList.Create;
  for i := 0 to Count - 1 do
  begin
    v.Seed := SeedAt(SeedBase, i);
    v.Text := RenderWith(Tmpl, Ctx, True, v.Seed);
    Result.Add(v);
  end;
end;

function SpxDocumentMarks(Report: TSpxReport): TSpxDiagMarks;
var i, j, n: Integer; d: TSpDiag; m: TSpxDiagMark;
begin
  Result := nil;
  n := 0;
  for i := 0 to Report.Files.Count - 1 do
  begin
    if Report.Files[i].Slug <> '' then Continue;
    for j := 0 to Report.Files[i].Diags.Count - 1 do
    begin
      d := Report.Files[i].Diags[j];
      if d.Line <= 0 then Continue;             { unlocated: panel only }
      m.Line := d.Line;
      m.Col := d.Column;
      m.IsError := d.Severity = 'error';
      m.Code := d.Code;
      if (d.EndLine > 0) and ((d.EndLine > d.Line) or (d.EndColumn > d.Column)) then
      begin
        m.EndLine := d.EndLine;
        m.EndCol := d.EndColumn;
      end
      else
      begin
        m.EndLine := d.Line;
        m.EndCol := d.Column + 1;               { one character, not a guessed extent }
      end;
      if n = Length(Result) then
        SetLength(Result, 8 + n * 2);
      Result[n] := m;
      Inc(n);
    end;
  end;
  SetLength(Result, n);
end;

function SpxFirstNonBlankColumn(const Line: string; CodePointCol: Integer): Integer;
var b: Integer;
begin
  Result := CodePointCol;
  if Result < 1 then Exit;
  while True do
  begin
    b := SpxByteColumn(Line, Result);
    if (b < 1) or (b > Length(Line)) then Exit(CodePointCol);
    if (Line[b] <> ' ') and (Line[b] <> #9) then Exit;
    Inc(Result);
  end;
end;

function SpxCodePointColumn(const Line: string; ByteCol: Integer): Integer;
var i, cpLen: Integer;
begin
  Result := 1;
  if ByteCol <= 1 then Exit;
  i := 1;
  while (i < ByteCol) and (i <= Length(Line)) do
  begin
    SpCodePointAt(Line, i, cpLen);
    Inc(i, cpLen);
    Inc(Result);
  end;
end;

function SpxByteColumn(const Line: string; CodePointCol: Integer): Integer;
var i, cp, cpLen: Integer;
begin
  if CodePointCol <= 1 then Exit(1);
  i := 1;
  cp := 1;
  while (i <= Length(Line)) and (cp < CodePointCol) do
  begin
    SpCodePointAt(Line, i, cpLen);
    if cpLen < 1 then cpLen := 1;   { malformed byte: step over it rather than spin }
    Inc(i, cpLen);
    Inc(cp);
  end;
  Result := i;
end;

function SpxValueForEngine(const Pair: TSpxVarPair): string;
begin
  if Pair.Literal then Result := SpNeutralize(Pair.Value) else Result := Pair.Value;
end;

function SpxLongestLine(const Text: string): Integer;
var i, run: Integer;
begin
  Result := 0;
  run := 0;
  i := 1;
  while i <= Length(Text) do
  begin
    if (Text[i] = #13) or (Text[i] = #10) then
    begin
      if run > Result then Result := run;
      run := 0;
      { CRLF is one ending, not two empty lines. }
      if (Text[i] = #13) and (i < Length(Text)) and (Text[i + 1] = #10) then Inc(i);
    end
    else
      Inc(run);
    Inc(i);
  end;
  if run > Result then Result := run;
end;

function SpxMarksToBytes(const Marks: TSpxDiagMarks; GetLine: TSpxLineFetch): TSpxDiagMarks;
var i: Integer;
begin
  Result := nil;   { -Sew: SetLength on an untouched managed result is a warning here }
  SetLength(Result, Length(Marks));
  for i := 0 to High(Marks) do
  begin
    Result[i] := Marks[i];
    Result[i].Col := SpxByteColumn(GetLine(Marks[i].Line), Marks[i].Col);
    Result[i].EndCol := SpxByteColumn(GetLine(Marks[i].EndLine), Marks[i].EndCol);
  end;
end;

{ The ISO code of each language, in the enum's own order -- the one place the two lists are
  tied together, so a language added to one and forgotten in the other is a compile error
  rather than a locale that silently resolves to English. }
const
  SPX_LANG_CODE: array[TSpxLang] of string =
    ('en', 'ru', 'uk', 'be', 'sr', 'hr', 'bs',
     'de', 'fr', 'es', 'it', 'pt', 'nl', 'tr');

function SpxLangCode(ALang: TSpxLang): string;
begin
  Result := SPX_LANG_CODE[ALang];
end;

function SpxLangFor(const Locale: string): TSpxLang;
var code: string; i: TSpxLang;
begin
  { The engine's own normalisation, so `RU`, `ru-RU` and `ru` are one language here as they
    are everywhere else in the family. An unknown code falls back to the base rather than to
    a half-translated window. }
  code := NormalizeBaseLang(Locale);
  Result := spxLangEn;
  for i := Low(TSpxLang) to High(TSpxLang) do
    if SPX_LANG_CODE[i] = code then Exit(i);
end;

function SpxDiagText(const Code: string; Lang: TSpxLang): string;
begin
  { The engine's seventeen codes as of v0.3.3, each read from the site that emits it rather
    than guessed from its name. The wording states the FINDING and stops there -- the panel
    reports a verdict four implementations agree on, it does not teach style.

    Paired language by language rather than as two tables, so a code cannot gain a sentence
    in one language and keep the bare code in the other: the pair is on the screen together
    and the suite reads both. }
  if Lang = spxLangRu then
  begin
    if Code = 'bracket.unclosed' then Result := 'скобка открыта и не закрыта'
    else if Code = 'bracket.mismatched' then Result := 'скобка закрыта скобкой другого вида'
    else if Code = 'bracket.unexpected-closing' then Result := 'закрывающая скобка без открывающей'
    else if Code = 'set.malformed' then Result := 'строка #set написана не по правилу'
    else if Code = 'def.malformed' then Result := 'строка #def написана не по правилу'
    else if Code = 'def.include-in-value' then Result := '#include внутри значения определения'
    else if Code = 'definition.duplicate-name' then Result := 'это имя уже определено выше'
    else if Code = 'include.unknown-target' then Result := 'такой цели нет в наборе'
    else if Code = 'variable.undefined' then Result := 'переменная нигде не определена'
    else if Code = 'variable.self-reference' then Result := 'определение ссылается само на себя'
    else if Code = 'variable.circular-reference' then Result := 'определения ссылаются по кругу'
    else if Code = 'plural.arity' then Result := 'форм не столько, сколько требует локаль'
    else if Code = 'plural.count-macro' then
      Result := 'счётчик берёт значение из #set, а оно перекатывается при каждой ссылке'
    else if Code = 'plural.nested-brackets' then Result := 'скобки внутри форм множественного числа'
    else if Code = 'permutation.unknown-key' then Result := 'неизвестный ключ в настройке перестановки'
    else if Code = 'permutation.minsize-not-integer' then Result := 'minsize не целое число'
    else if Code = 'permutation.maxsize-not-integer' then Result := 'maxsize не целое число'
    else Result := Code;
  end
  else
  begin
    if Code = 'bracket.unclosed' then Result := 'a bracket is opened and never closed'
    else if Code = 'bracket.mismatched' then Result := 'closed by a bracket of another kind'
    else if Code = 'bracket.unexpected-closing' then Result := 'a closing bracket with nothing open'
    else if Code = 'set.malformed' then Result := 'this #set line does not follow the rule'
    else if Code = 'def.malformed' then Result := 'this #def line does not follow the rule'
    else if Code = 'def.include-in-value' then Result := '#include inside a definition value'
    else if Code = 'definition.duplicate-name' then Result := 'this name is already defined above'
    else if Code = 'include.unknown-target' then Result := 'no such target in the set'
    else if Code = 'variable.undefined' then Result := 'this variable is defined nowhere'
    else if Code = 'variable.self-reference' then Result := 'the definition refers to itself'
    else if Code = 'variable.circular-reference' then Result := 'the definitions refer in a circle'
    else if Code = 'plural.arity' then Result := 'not as many forms as the locale asks for'
    else if Code = 'plural.count-macro' then
      Result := 'the count comes from #set, and that rerolls on every reference'
    else if Code = 'plural.nested-brackets' then Result := 'brackets inside the plural forms'
    else if Code = 'permutation.unknown-key' then Result := 'unknown key in the permutation config'
    else if Code = 'permutation.minsize-not-integer' then Result := 'minsize is not a whole number'
    else if Code = 'permutation.maxsize-not-integer' then Result := 'maxsize is not a whole number'
    else Result := Code;
  end;
end;

function SpxNoteText(const Note: TSpxNote; Lang: TSpxLang): string;
begin
  if Lang = spxLangRu then
    case Note.Kind of
      spxNoteCycle:
        Result := 'вставка "' + Note.Target + '" уже разворачивается выше — движок подставит пустоту';
      spxNoteTooDeep:
        Result := 'вставки вложены глубже предела — дальше движок подставит пустоту';
      spxNoteCaseMismatch:
        Result := 'цели "' + Note.Target + '" нет, а в наборе есть "' + Note.Hint +
                  '": цели сравниваются точно';
      spxNoteUnknownTarget:
        Result := 'цели "' + Note.Target + '" нет в наборе';
      spxNoteRawSentinel:
        Result := 'в тексте есть служебный символ U+E000–U+E005: движок удалит его перед разбором';
    else
      Result := '';
    end
  else
    case Note.Kind of
      spxNoteCycle:
        Result := 'the include "' + Note.Target +
                  '" is already being expanded above — the engine puts nothing here';
      spxNoteTooDeep:
        Result := 'includes nested past the limit — from here the engine puts nothing';
      spxNoteCaseMismatch:
        Result := 'no target "' + Note.Target + '", though the set has "' + Note.Hint +
                  '": targets are compared exactly';
      spxNoteUnknownTarget:
        Result := 'no target "' + Note.Target + '" in the set';
      spxNoteRawSentinel:
        Result := 'the text holds a private-use character U+E000–U+E005: the engine deletes ' +
                  'it before parsing';
    else
      Result := '';
    end;
end;

{ Studio's notes have no engine code, and inventing one that LOOKS like an engine code would
  be the one confusion this panel exists to prevent. The `note.` prefix says whose it is. }
function NoteCode(Kind: TSpxNoteKind): string;
begin
  case Kind of
    spxNoteCycle: Result := 'note.cycle';
    spxNoteTooDeep: Result := 'note.too-deep';
    spxNoteCaseMismatch: Result := 'note.case-mismatch';
    spxNoteUnknownTarget: Result := 'note.unknown-target';
    spxNoteRawSentinel: Result := 'note.raw-sentinel';
  else
    Result := 'note';
  end;
end;

function SpxPanelRows(Report: TSpxReport; Lang: TSpxLang): TSpxPanelRows;
var
  n: Integer;

  procedure Add(const Row: TSpxPanelRow);
  begin
    if n = Length(Result) then SetLength(Result, 8 + n * 2);
    Result[n] := Row;
    Inc(n);
  end;

  { One sortable number per row; an unlocated finding sorts last inside its file. }
  function Rank(const Row: TSpxPanelRow): Int64;
  begin
    if Row.Line <= 0 then Result := High(Int64)
    else Result := (Int64(Row.Line) shl 32) + Row.Column;
  end;

  { Insertion sort, and STABLE on purpose: two findings on the same character keep the order
    the engine reported them in. A file's findings are counted in dozens. }
  procedure SortFrom(First: Integer);
  var i, j: Integer; tmp: TSpxPanelRow;
  begin
    for i := First + 1 to n - 1 do
    begin
      tmp := Result[i];
      j := i - 1;
      while (j >= First) and (Rank(Result[j]) > Rank(tmp)) do
      begin
        Result[j + 1] := Result[j];
        Dec(j);
      end;
      Result[j + 1] := tmp;
    end;
  end;

  function NoteRow(const Note: TSpxNote): TSpxPanelRow;
  begin
    Result.Slug := Note.Slug;
    Result.Source := spxRowStudio;
    Result.Severity := 'note';
    Result.Code := NoteCode(Note.Kind);
    Result.Text := SpxNoteText(Note, Lang);
    Result.Line := Note.Line;
    Result.Column := Note.Column;
    Result.EndLine := 0;      { a note marks a place, not a span }
    Result.EndColumn := 0;
  end;

var
  i, j, first: Integer;
  row: TSpxPanelRow;
  d: TSpDiag;
  taken: array of Boolean;   // notes already placed, by index
begin
  Result := nil;
  n := 0;
  SetLength(taken, Report.Notes.Count);

  for i := 0 to Report.Files.Count - 1 do
  begin
    first := n;
    for j := 0 to Report.Files[i].Diags.Count - 1 do
    begin
      d := Report.Files[i].Diags[j];
      row.Slug := Report.Files[i].Slug;
      row.Source := spxRowEngine;
      row.Severity := d.Severity;
      row.Code := d.Code;
      row.Text := SpxDiagText(d.Code, Lang);
      row.Line := d.Line;
      row.Column := d.Column;
      row.EndLine := d.EndLine;
      row.EndColumn := d.EndColumn;
      Add(row);
    end;
    { Studio's notes about this same file, so one file reads as one block. Tracked by INDEX,
      not by slug: two file reports carrying one slug would otherwise emit each of that
      file's notes twice, and this function's contract is that nothing is dropped and
      nothing is invented. The walk cannot produce that shape today -- Visited guards it --
      which is exactly why the guard belongs in the function rather than in an assumption
      about the caller. Slug comparison is EXACT, as everywhere else. }
    for j := 0 to Report.Notes.Count - 1 do
      if (not taken[j]) and (Report.Notes[j].Slug = Report.Files[i].Slug) then
      begin
        taken[j] := True;
        Add(NoteRow(Report.Notes[j]));
      end;
    SortFrom(first);
  end;

  { Anything left over: a note about a file the walk produced no report for. Measured, the
    current walk never leaves one -- every AddNote site names a file ValidateFile has already
    filed -- so this is a backstop for a future note that is filed before its file, not a
    path in use. Dropping such a note would hide the very finding that explains the absence. }
  first := n;
  for j := 0 to Report.Notes.Count - 1 do
    if not taken[j] then Add(NoteRow(Report.Notes[j]));
  SortFrom(first);

  SetLength(Result, n);
end;

{ ── the fragment preview ─────────────────────────────────────────────────── }

function SpxRenderFragment(const Doc, Fragment: string; const Ctx: TSpxContext): string;
var dirs: TSpDirectiveList; i: Integer; prelude: string;
begin
  prelude := '';
  dirs := SpExtractDirectives(Doc);
  try
    for i := 0 to dirs.Count - 1 do
      if (dirs[i].Kind = 'set') or (dirs[i].Kind = 'def') then
        { Text is the line the RENDERER consumed, comments already gone, so re-emitting it
          costs no re-spelling of the grammar. }
        prelude := prelude + dirs[i].Text + #10;
  finally
    dirs.Free;
  end;
  Result := SpxRenderSample(prelude + Fragment, Ctx);
end;

{ ── the panel model ──────────────────────────────────────────────────────── }

constructor TSpxModel.Create;
begin
  inherited Create;
  Vars := TList<TSpxVarInfo>.Create;
  Includes := TList<TSpxIncludeInfo>.Create;
end;

destructor TSpxModel.Destroy;
begin
  Vars.Free;
  Includes.Free;
  inherited Destroy;
end;

function SpxExtractModel(const Tmpl: string; const Ctx: TSpxContext): TSpxModel;
var
  dirs: TSpDirectiveList;
  ex: TExtractResult;
  defined: TStringList;
  runtimeVals: TStrMap;
  pair: TPair<string, string>;
  i: Integer;
  v: TSpxVarInfo;
  incInfo: TSpxIncludeInfo;
begin
  Result := TSpxModel.Create;
  defined := nil;
  runtimeVals := nil;
  try
   try
    defined := TStringList.Create;
    { Macro names are ASCII by the engine's grammar, so the default (case-insensitive)
      compare would only ever fold names that are already equal -- but say what is meant.
      UseLocale for the same reason as everywhere else in this unit: CaseSensitive alone
      leaves the comparison to the OS collation (see SpxHealthReport). }
    defined.CaseSensitive := True;
    defined.UseLocale := False;
    runtimeVals := TStrMap.Create;
    { The engine keys macros lower-cased and matches runtime names case-insensitively, so
      the panel can show a value the user typed as BRAND against a %brand% reference. }
    if Assigned(Ctx.Vars) then
      for pair in Ctx.Vars do runtimeVals.AddOrSetValue(LowerCase(pair.Key), pair.Value);

    dirs := SpExtractDirectives(Tmpl);
    try
      for i := 0 to dirs.Count - 1 do
        if dirs[i].Kind = 'include' then
        begin
          { Known is False both for a real miss and for "there is no set at all"; the caller
            knows which, because it is the caller that did or did not supply Templates. }
          incInfo.Target := dirs[i].Name;
          incInfo.Known := (Ctx.Templates <> nil) and Ctx.Templates.ContainsKey(dirs[i].Name);
          incInfo.Line := dirs[i].Line;
          incInfo.Column := dirs[i].Column;
          incInfo.DirIndex := i;
          Result.Includes.Add(incInfo);
        end
        else
        begin
          v.Name := dirs[i].Name;
          if dirs[i].Kind = 'def' then v.Kind := spxVarDef else v.Kind := spxVarSet;
          v.Value := dirs[i].Value;
          v.Line := dirs[i].Line;
          v.Column := dirs[i].Column;
          v.DirIndex := i;
          Result.Vars.Add(v);
          { Duplicates are kept: two definitions of one name is what the engine calls
            definition.duplicate-name, and a panel that silently showed one row would hide
            the second half of the error. }
          if defined.IndexOf(v.Name) < 0 then defined.Add(v.Name);
        end;
    finally
      dirs.Free;
    end;

    { Everything referenced and not defined here is a runtime variable: the panel offers a
      value for it, and until one is given the validator warns (spec §4.3/§4.4). }
    ex := SpExtract(Tmpl);
    try
      for i := 0 to ex.Refs.Count - 1 do
        if defined.IndexOf(ex.Refs[i]) < 0 then
        begin
          v.Name := ex.Refs[i];
          v.Kind := spxVarRuntime;
          if not runtimeVals.TryGetValue(v.Name, v.Value) then v.Value := '';
          v.DirIndex := -1;   { nothing in the document to edit: this value is the session's }
          v.Line := 0;
          v.Column := 0;
          Result.Vars.Add(v);
        end;
    finally
      ex.Refs.Free; ex.Sets.Free; ex.Defs.Free; ex.Includes.Free;
    end;
   finally
    defined.Free;
    runtimeVals.Free;
   end;
  except
    { Result is the return value: if we leave by exception nobody else can free it. }
    Result.Free;
    raise;
  end;
end;

{ ── the health report ────────────────────────────────────────────────────── }

constructor TSpxFileReport.Create(const ASlug: string; ADiags: TSpDiagList);
begin
  inherited Create;
  Slug := ASlug;
  Diags := ADiags;
end;

destructor TSpxFileReport.Destroy;
begin
  Diags.Free;
  inherited Destroy;
end;

constructor TSpxReport.Create;
begin
  inherited Create;
  Files := TObjectList<TSpxFileReport>.Create(True);
  Notes := TSpxNoteList.Create;
end;

destructor TSpxReport.Destroy;
begin
  Files.Free;
  Notes.Free;
  inherited Destroy;
end;

function TSpxReport.IsValid: Boolean;
begin
  Result := Errors = 0;
end;

{ U+FF5B / U+FF5D -- the fullwidth braces the engine emits when a block is too malformed to
  render but must not throw. Their presence in a probe is the signal that something the
  validator may have called a mere warning is destroying output. Spelled per string width,
  like the engine's own literals. }
function FullwidthBrace(opening: Boolean): string;
begin
  {$IFDEF UNICODE}
  if opening then Result := #$FF5B else Result := #$FF5D;
  {$ELSE}
  if opening then Result := #$EF#$BD#$9B else Result := #$EF#$BD#$9D;
  {$ENDIF}
end;

{ Case folding through the ENGINE's Unicode tables, not SysUtils.LowerCase, which folds
  A..Z and stops. This runs on include targets, and targets are filenames: in a product
  written for Russian templates they will be Cyrillic, where an ASCII fold makes
  `Вступление` and `вступление` look like different words and the near-miss hint below
  would never fire -- exactly where it is needed most. }
function FoldCase(const s: string): string;
var i, cpLen: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(s) do
  begin
    Result := Result + SpUpperCodePoint(SpCodePointAt(s, i, cpLen));
    Inc(i, cpLen);
  end;
end;

{ Reserved sentinels in author markup. `SpRender` deletes U+E000..U+E005 before parsing
  while the editor-side calls read the source as written, so a document carrying raw ones
  makes the panel and the preview tell different stories (spec §7). No position: locating it
  would mean re-deriving the engine's editor-coordinate walk, and this layer does not
  re-derive what the engine owns. }
function HasRawSentinel(const s: string): Boolean;
var i, cpLen: Integer; cp: LongWord;
begin
  Result := False;
  i := 1;
  while i <= Length(s) do
  begin
    cp := SpCodePointAt(s, i, cpLen);
    if (cp >= $E000) and (cp <= $E005) then Exit(True);
    Inc(i, cpLen);
  end;
end;

procedure AddNote(Report: TSpxReport; Kind: TSpxNoteKind; const Slug, Target, Hint: string;
  Line, Column: Integer);
var n: TSpxNote;
begin
  n.Kind := Kind;
  n.Slug := Slug;
  n.Target := Target;
  n.Hint := Hint;
  n.Line := Line;
  n.Column := Column;
  Report.Notes.Add(n);
end;

function SpxKeepRuntime(const Vars: TSpxVarInfos;
  const Session: TSpxVarPairs): TSpxVarPairs;
var
  i, j, n: Integer;
  wanted: string;
begin
  Result := nil;
  SetLength(Result, Length(Session));
  n := 0;
  for i := 0 to High(Vars) do
  begin
    if Vars[i].Kind <> spxVarRuntime then Continue;
    for j := 0 to High(Session) do
    begin
      { ASCII folding is the right one: the engine scans references and directive names with
        an ASCII word rule, so a non-ASCII session name can never match a model name. }
      wanted := LowerCase(Session[j].Name);
      if wanted <> Vars[i].Name then Continue;
      Result[n].Name := Vars[i].Name;      { the model's spelling: what the render matches }
      Result[n].Value := Session[j].Value;
      { And how it is meant. A field added to the record and forgotten HERE is a flag the
        panel sets and the engine never sees -- which is exactly what happened. }
      Result[n].Literal := Session[j].Literal;
      Inc(n);
      Break;                               { one value per name; the first wins }
    end;
  end;
  SetLength(Result, n);
end;

{ ── what the editor's selection means ────────────────────────────────────── }

function SpxPos(Line, Col: Integer): TSpxPos;
begin
  Result.Line := Line;
  Result.Col := Col;
end;

function SpxRange(const A, B: TSpxPos): TSpxRange;
begin
  Result.A := A;
  Result.B := B;
end;

function SamePos(const A, B: TSpxPos): Boolean;
begin
  Result := (A.Line = B.Line) and (A.Col = B.Col);
end;

function SameRange(const A, B: TSpxRange): Boolean;
begin
  Result := SamePos(A.A, B.A) and SamePos(A.B, B.B);
end;

function SpxPreviewAsk(const Sel: TSpxSelection; const Jump: TSpxJumpState): TSpxPreviewAsk;
begin
  Result.Narrowed := False;
  Result.Range := Sel.Range;
  if Sel.Kind = spxSelNone then Exit;
  { A jump's own selection shows a finding; it does not ask for a preview of it. }
  if Jump.Valid and SameRange(Sel.Range, Jump.Range) then Exit;
  { An empty span selects nothing, whatever its kind says. }
  if SameRange(Sel.Range, SpxRange(Sel.Range.A, Sel.Range.A)) then Exit;
  Result.Narrowed := True;
end;

function SpxPreviewSame(const A, B: TSpxPreviewAsk): Boolean;
begin
  if A.Narrowed <> B.Narrowed then Exit(False);
  { The span only matters while it IS the preview -- two different jumps both show the whole
    document, and re-rendering between them is the waste this exists to stop. }
  if not A.Narrowed then Exit(True);
  Result := SameRange(A.Range, B.Range);
end;

function SpxPreviewFragment(const Sel: TSpxSelection; const Jump: TSpxJumpState;
  out NewJump: TSpxJumpState): string;
begin
  NewJump := Jump;
  { Nothing selected: whatever a jump left is gone with it, so selecting that same span by
    hand afterwards is the user's own selection and does narrow the preview. }
  if Sel.Kind = spxSelNone then
  begin
    NewJump.Valid := False;
    Exit('');
  end;
  { Still exactly what the jump selected: it was made to show a finding, not to preview it. }
  if Jump.Valid and SameRange(Sel.Range, Jump.Range) then Exit('');
  NewJump.Valid := False;
  Result := Sel.Text;
end;

function SpxWrapRange(const Sel: TSpxSelection; LeftLen, RightLen: Integer;
  out NewRange: TSpxRange): Boolean;
begin
  NewRange := Sel.Range;
  Result := False;
  if Sel.Kind <> spxSelNormal then Exit;
  if (LeftLen < 0) or (RightLen < 0) then Exit;
  if NewRange.B.Line = NewRange.A.Line then
    Inc(NewRange.B.Col, LeftLen + RightLen)
  else
    Inc(NewRange.B.Col, RightLen);
  Result := True;
end;

{ ── what the page view may be handed ─────────────────────────────────────── }

function SpxIsBlankOutput(const S: string): Boolean;
var i: Integer;
begin
  i := 1;
  while i <= Length(S) do
  begin
    if S[i] <= ' ' then
      Inc(i)
    { U+00A0, in UTF-8: C2 A0. }
    else if (S[i] = #$C2) and (i < Length(S)) and (S[i + 1] = #$A0) then
      Inc(i, 2)
    { U+2028 and U+2029: E2 80 A8 / E2 80 A9. }
    else if (S[i] = #$E2) and (i + 2 <= Length(S)) and (S[i + 1] = #$80) and
            ((S[i + 2] = #$A8) or (S[i + 2] = #$A9)) then
      Inc(i, 3)
    else
      Exit(False);
  end;
  Result := True;
end;

function SpxOpensDocument(const AHtml: string): Boolean;
var i: Integer;

  { The keyword, then a boundary -- so `<html>` and `<body bgcolor=…>` count and `<htmlfoo>`
    does not, which is the same place the renderer's own tokenizer ends a tag name. }
  function Opens(const Word_: string): Boolean;
  var k: Integer; c: Char;
  begin
    if i + Length(Word_) - 1 > Length(AHtml) then Exit(False);
    for k := 1 to Length(Word_) do
      if LowerCase(AHtml[i + k - 1]) <> Word_[k] then Exit(False);
    k := i + Length(Word_);
    if k > Length(AHtml) then Exit(True);
    c := AHtml[k];
    Result := (c = '>') or (c <= ' ');
  end;

begin
  i := 1;
  while (i <= Length(AHtml)) and (AHtml[i] <= ' ') do Inc(i);
  Result := Opens('<html') or Opens('<body');
end;

function SpxPageDocument(const AHtml: string): string;
begin
  if SpxOpensDocument(AHtml) then
    Result := AHtml
  else
    { The output goes in untouched: nothing is escaped, normalised or re-ordered, so what the
      renderer lays out is still what the engine produced. }
    Result := '<html><body>' + AHtml + '</body></html>';
end;

{ ── editing a directive where it sits ────────────────────────────────────── }

{ ── finding text in the template ─────────────────────────────────────────── }

{ Are these two code points the same for the search?

  Written to allocate NOTHING in the cases that happen millions of times: equal code points,
  and two ASCII ones. Only two DIFFERENT non-ASCII code points reach the engine's table,
  which returns strings. The first version folded both sides to strings on every comparison
  -- measured at 24-42 ms per keystroke on a 116 KB template, and the box is rescanned on
  every keystroke.

  What this deliberately does NOT do is fold across a boundary: the engine's table expands a
  few code points (sharp s -> SS), and a one-to-many fold cannot be compared one code point
  at a time. So `STRASSE` does not find `straße` here, while SpxDedupe's whole-string fold
  calls those equal. The disagreement is the price of positions that are always exactly the
  needle's length -- a search that reports a span of the wrong size selects the wrong text,
  which is worse than missing an unusual pair. }
{ Upper case for the two alphabets this app is actually written in, by arithmetic: ASCII, the
  Cyrillic block, and the `ё`-row above it. Anything else comes back unchanged and the caller
  falls through to the engine's table.

  It exists because the table is a binary search returning a STRING, and a case-insensitive
  scan asks for one at every position of the document: 20 ms per keystroke on a 116 KB
  template, 190 ms on a megabyte. Hand-rolled knowledge is only allowed here because the
  suite checks it against SpUpperCodePoint for every code point in the ranges it claims --
  if the engine's table and this ever disagree, a test says so rather than a user. }
function FastUpper(CP: LongWord): LongWord;
begin
  Result := CP;
  if (CP >= Ord('a')) and (CP <= Ord('z')) then Exit(CP - 32);          { ASCII }
  if (CP >= $430) and (CP <= $44F) then Exit(CP - 32);                  { а..я }
  if (CP >= $450) and (CP <= $45F) then Exit(CP - 80);                  { ё and its row }
end;

function SpxTestFastUpper(CP: LongWord): LongWord;
begin
  Result := FastUpper(CP);
end;

{ Whether FastUpper is the WHOLE answer for this code point -- ASCII and the Cyrillic block,
  where the engine's own uppercase is exactly the single code point the arithmetic gives
  (checked by the suite for every one of them). For those, two folded values that differ are
  two different letters and the table has nothing to add. }
function FastCovers(CP: LongWord): Boolean;
begin
  Result := (CP < 128) or ((CP >= $400) and (CP <= $45F));
end;

function SameCp(A, B: LongWord; MatchCase: Boolean): Boolean;
begin
  if A = B then Exit(True);
  if MatchCase then Exit(False);
  A := FastUpper(A);
  B := FastUpper(B);
  if A = B then Exit(True);
  { The early-out that matters: a scan compares mostly DIFFERENT letters, and without this
    every one of them paid for two binary searches in the engine's table -- 20 ms per
    keystroke on a 116 KB template, 190 ms on a megabyte, for an answer already known. }
  if FastCovers(A) and FastCovers(B) then Exit(False);
  { Everything the arithmetic does not cover -- accented Latin, Greek, the rest of Unicode --
    still goes through the engine, so the two never disagree about a character. }
  Result := SpUpperCodePoint(A) = SpUpperCodePoint(B);
end;

function SpxFindAll(const Text, Needle: string; MatchCase: Boolean): TSpxMatches;
var
  i, n, cpLen, line_, col: Integer;
  cp: LongWord;
  count_: Integer;

  { Does the needle sit at byte I? Returns its length in bytes, or 0. Compared code point by
    code point so that folding cannot move any offset. }
  function MatchAt(Start: Integer; out EndLine, EndCol: Integer): Integer;
  var
    ti, ni, tl, nl, el, ec: Integer;
    tcp, ncp: LongWord;
  begin
    Result := 0;
    ti := Start;
    ni := 1;
    el := line_;
    ec := col;
    while ni <= Length(Needle) do
    begin
      if ti > Length(Text) then Exit(0);
      tcp := SpCodePointAt(Text, ti, tl);
      ncp := SpCodePointAt(Needle, ni, nl);
      if not SameCp(tcp, ncp, MatchCase) then Exit(0);
      { The end position advances through the match, so a needle containing a line break
        reports the row it really ends on. CRLF is ONE line ending and both sides step over
        it together -- the first version left the LF to be counted again, and a two-line
        needle then reported a row past the end of a two-line document. }
      if (tcp = 10) or (tcp = 13) then
      begin
        if (tcp = 13) and (ti + tl <= Length(Text)) and (Text[ti + tl] = #10) and
           (ni + nl <= Length(Needle)) and (Needle[ni + nl] = #10) then
        begin
          Inc(ti);
          Inc(ni);
        end;
        Inc(el);
        ec := 1;
      end
      else
        Inc(ec);
      Inc(ti, tl);
      Inc(ni, nl);
    end;
    EndLine := el;
    EndCol := ec;
    Result := ti - Start;
  end;

begin
  Result := nil;
  count_ := 0;
  if (Text = '') or (Needle = '') then Exit;

  SetLength(Result, 16);
  line_ := 1;
  col := 1;
  i := 1;
  while i <= Length(Text) do
  begin
    n := MatchAt(i, Result[count_].EndLine, Result[count_].EndCol);
    if n > 0 then
    begin
      Result[count_].Line := line_;
      Result[count_].Col := col;
      Inc(count_);
      if count_ >= Length(Result) then SetLength(Result, count_ * 2);
    end;

    { Advance ONE code point, not one match: overlapping occurrences are occurrences.
      `аа` in `ааа` is two, and a reader stepping through expects both. }
    cp := SpCodePointAt(Text, i, cpLen);
    if cp = 13 then
    begin
      Inc(line_);
      col := 1;
      if (i + cpLen <= Length(Text)) and (Text[i + cpLen] = #10) then Inc(cpLen);
    end
    else if cp = 10 then
    begin
      Inc(line_);
      col := 1;
    end
    else
      Inc(col);
    Inc(i, cpLen);
  end;
  SetLength(Result, count_);
end;

function SpxStepMatch(const Matches: TSpxMatches; Line, Col: Integer;
  Backwards: Boolean): Integer;
var i: Integer;
begin
  if Length(Matches) = 0 then Exit(-1);
  if Backwards then
  begin
    for i := High(Matches) downto 0 do
      if (Matches[i].Line < Line) or
         ((Matches[i].Line = Line) and (Matches[i].Col < Col)) then Exit(i);
    { Nothing before the caret: round to the last one. }
    Exit(High(Matches));
  end;
  for i := 0 to High(Matches) do
    if (Matches[i].Line > Line) or
       ((Matches[i].Line = Line) and (Matches[i].Col >= Col)) then Exit(i);
  Result := 0;
end;

function SpxDocOffset(const Doc: string; Line, Column: Integer): Integer;
var i, j, ln: Integer;
begin
  if Line < 1 then Exit(1);
  i := 1;
  ln := 1;
  { The EDITOR's three terminators, not the directive splitter's five: a U+2028 between two
    directives does not start a new line for a position. }
  while (i <= Length(Doc)) and (ln < Line) do
  begin
    if Doc[i] = #13 then
    begin
      if (i < Length(Doc)) and (Doc[i + 1] = #10) then Inc(i);
      Inc(ln);
    end
    else if Doc[i] = #10 then Inc(ln);
    Inc(i);
  end;
  { Only this LINE's bytes go to the column walker. Handing it the rest of the document
    would let a column past the end of a short line walk into the following ones -- and
    count a CRLF as two columns while doing it, which is not even the editor's line model.
    Unreachable from the engine's own coordinates, which never overshoot, but this is public
    and a caret at the end of a line is an everyday coordinate. }
  j := i;
  while (j <= Length(Doc)) and (Doc[j] <> #10) and (Doc[j] <> #13) do Inc(j);
  Result := i + SpxByteColumn(Copy(Doc, i, j - i), Column) - 1;
  if Result > Length(Doc) + 1 then Result := Length(Doc) + 1;
end;

function AllBlank(const S: string): Boolean;
var i: Integer;
begin
  for i := 1 to Length(S) do
    if (S[i] <> ' ') and (S[i] <> #9) then Exit(False);
  Result := True;
end;

function IndexOfChar(const S: string; C: Char; From: Integer): Integer;
begin
  Result := From;
  if Result < 1 then Result := 1;
  while (Result <= Length(S)) and (S[Result] <> C) do Inc(Result);
  if Result > Length(S) then Result := 0;
end;

{ The directive's own start inside its span: the first byte that is not indentation. }
function HeadPos(const S: string): Integer;
begin
  Result := 1;
  while (Result <= Length(S)) and ((S[Result] = ' ') or (S[Result] = #9)) do Inc(Result);
end;

{ The NAME's own bytes -- between the percent signs, or inside the quotes for an include --
  as a half-open span [NA, NB) in S. }
function NameSpan(const S, Kind: string; out NA, NB: Integer): Boolean;
var open_, close_: Integer; mark: Char;
begin
  NA := 0; NB := 0;
  if Kind = 'include' then mark := '"' else mark := '%';
  open_ := IndexOfChar(S, mark, HeadPos(S));
  if open_ = 0 then Exit(False);
  close_ := IndexOfChar(S, mark, open_ + 1);
  if close_ = 0 then Exit(False);
  NA := open_ + 1;
  NB := close_;
  Result := True;
end;

{ The VALUE's own bytes as a half-open span: after the `=` that follows the name, blanks
  skipped, through the last non-blank. Trailing blanks are left where they are -- a tail
  comment sits behind them, and the span stops before it. }
function ValueSpan(const S: string; From: Integer; out VA, VB: Integer): Boolean;
var p, e: Integer;
begin
  VA := 0; VB := 0;
  p := IndexOfChar(S, '=', From);
  if p = 0 then Exit(False);
  Inc(p);
  while (p <= Length(S)) and ((S[p] = ' ') or (S[p] = #9)) do Inc(p);
  e := Length(S);
  while (e >= p) and ((S[e] = ' ') or (S[e] = #9)) do Dec(e);
  VA := p;
  VB := e + 1;
  Result := True;
end;

{ One occurrence resolved to a byte span, and False when rewriting it would not be safe. }
function DirectiveSpan(const Doc: string; Index: Integer; out D: TSpDirective;
  out A, B: Integer; out Covered: string): Boolean;
var dirs: TSpDirectiveList; found: Boolean;
begin
  Result := False;
  A := 0; B := 0; Covered := '';
  D := Default(TSpDirective);
  if Index < 0 then Exit;
  found := False;
  dirs := SpExtractDirectives(Doc);
  try
    if Index < dirs.Count then
    begin
      D := dirs[Index];
      found := True;
    end;
  finally
    dirs.Free;
  end;
  if not found then Exit;
  A := SpxDocOffset(Doc, D.Line, D.Column);
  B := SpxDocOffset(Doc, D.EndLine, D.EndColumn);
  if (A < 1) or (B < A) then Exit;
  Covered := Copy(Doc, A, B - A);
  { The span IS what the renderer consumed -- except when a comment sits inside the
    directive. Text is cut from comment-stripped source; the span maps back to the source and
    therefore carries the comment. That covers `#set %x% = A /# c #/ B` as much as the case
    where the comment swallowed the terminator, and rewriting either would delete a comment
    the author wrote. Refused, both. }
  Result := Covered = D.Text;
end;

function Splice(const Doc: string; A, B: Integer; const S: string): string;
begin
  Result := Copy(Doc, 1, A - 1) + S + Copy(Doc, B, MaxInt);
end;

{ Does the document we just produced still say what the caller asked for? Asked of the
  ENGINE, because the caller's string is an open door: `A /# oops` opens a comment nobody
  closes and the rest of the file stops being template at all; a line break in a value ends
  the directive early and leaves the remainder as body text; an empty or spaced name is no
  directive to the grammar. Every one of those used to splice happily and report success.

  Cheap enough: an edit is a user action, not a keystroke, and the panel re-derives from the
  document afterwards anyway. }
function DirectiveCount(const Doc: string): Integer;
var dirs: TSpDirectiveList;
begin
  dirs := SpExtractDirectives(Doc);
  try
    Result := dirs.Count;
  finally
    dirs.Free;
  end;
end;

function EditAccepted(const NewDoc: string; Index: Integer;
  const Kind, Name, Value: string): Boolean;
var dirs: TSpDirectiveList; d: TSpDirective; found: Boolean;
begin
  d := Default(TSpDirective);
  found := False;
  dirs := SpExtractDirectives(NewDoc);
  try
    if (Index >= 0) and (Index < dirs.Count) then
    begin
      d := dirs[Index];
      found := True;
    end;
  finally
    dirs.Free;
  end;
  Result := found and (d.Kind = Kind) and (d.Name = Name) and (d.Value = Value);
end;

function SpxSetDirectiveValue(const Doc: string; Index: Integer; const Value: string;
  out NewDoc: string; out SpanA, SpanB: Integer): Boolean;
var d: TSpDirective; a, b, na, nb, va, vb: Integer; covered: string;
begin
  NewDoc := Doc;
  SpanA := 0;
  SpanB := 0;
  Result := False;
  if not DirectiveSpan(Doc, Index, d, a, b, covered) then Exit;
  if d.Kind = 'include' then Exit;              { an include carries a target, not a value }
  if not NameSpan(covered, d.Kind, na, nb) then Exit;
  if not ValueSpan(covered, nb, va, vb) then Exit;
  NewDoc := Splice(Doc, a + va - 1, a + vb - 1, Value);
  { The engine trims a value as the renderer does, so that is what it will read back. }
  Result := EditAccepted(NewDoc, Index, d.Kind, d.Name, Trim(Value));
  if Result then
  begin
    SpanA := a + va - 1;
    SpanB := a + vb - 1;
  end
  else
    NewDoc := Doc;
end;

function SpxSetDirectiveValue(const Doc: string; Index: Integer; const Value: string;
  out NewDoc: string): Boolean;
var ignoreA, ignoreB: Integer;
begin
  Result := SpxSetDirectiveValue(Doc, Index, Value, NewDoc, ignoreA, ignoreB);
end;

function SpxSetDirectiveName(const Doc: string; Index: Integer; const Name: string;
  out NewDoc: string): Boolean;
var d: TSpDirective; a, b, na, nb: Integer; covered: string;
begin
  NewDoc := Doc;
  Result := False;
  if not DirectiveSpan(Doc, Index, d, a, b, covered) then Exit;
  if not NameSpan(covered, d.Kind, na, nb) then Exit;
  NewDoc := Splice(Doc, a + na - 1, a + nb - 1, Name);
  { A macro's name comes back lower-cased -- that is how the engine keys them -- while an
    include target is a host identifier and comes back verbatim. }
  if d.Kind = 'include' then
    Result := EditAccepted(NewDoc, Index, d.Kind, Name, d.Value)
  else
    Result := EditAccepted(NewDoc, Index, d.Kind, LowerCase(Name), d.Value);
  if not Result then NewDoc := Doc;
end;

function SpxSetDirectiveKind(const Doc: string; Index: Integer; const Kind: string;
  out NewDoc: string): Boolean;
var d: TSpDirective; a, b, h: Integer; covered: string;
begin
  NewDoc := Doc;
  Result := False;
  { `#set` and `#def` are the same shape and the same length, so one is the other with three
    bytes changed. `#include` is a different construct with a different payload, and turning
    a macro into one -- or back -- is not a substitution this function will pretend to make. }
  if (Kind <> 'set') and (Kind <> 'def') then Exit;
  if not DirectiveSpan(Doc, Index, d, a, b, covered) then Exit;
  if (d.Kind <> 'set') and (d.Kind <> 'def') then Exit;
  if d.Kind = Kind then Exit(True);             { already so; the document is untouched }
  h := HeadPos(covered);
  if h + 3 > Length(covered) then Exit;
  NewDoc := Splice(Doc, a + h, a + h + 3, Kind);
  Result := EditAccepted(NewDoc, Index, Kind, d.Name, d.Value);
  if not Result then NewDoc := Doc;
end;

function SpxDeleteDirective(const Doc: string; Index: Integer; out NewDoc: string): Boolean;
var d: TSpDirective; a, b, ls, le: Integer; covered: string;
begin
  NewDoc := Doc;
  Result := False;
  if not DirectiveSpan(Doc, Index, d, a, b, covered) then Exit;

  { Widen to the whole line when the directive was alone on it -- otherwise removing the
    span leaves an empty line where a definition used to be. A head or a tail comment counts
    as company, and then only the directive goes. }
  ls := a;
  while (ls > 1) and (Doc[ls - 1] <> #10) and (Doc[ls - 1] <> #13) do Dec(ls);
  le := b;
  while (le <= Length(Doc)) and (Doc[le] <> #10) and (Doc[le] <> #13) do Inc(le);

  if AllBlank(Copy(Doc, ls, a - ls)) and AllBlank(Copy(Doc, b, le - b)) then
  begin
    { Take the terminator too, or an empty line is left where a definition used to be --
      UNLESS the span already ends on one. An `#include`'s span is greedy to the end of its
      line (the family anchor ends `[ \t\n\r\f\x0B]*$`), so it carries its terminator
      already, and taking another would swallow the following BLANK line -- which deleting a
      `#set` in the same position does not do. Measured. }
    if (b > 1) and ((Doc[b - 1] = #10) or (Doc[b - 1] = #13)) then
      { the span brought its own terminator }
    else if (le <= Length(Doc)) and (Doc[le] = #13) then
    begin
      Inc(le);
      if (le <= Length(Doc)) and (Doc[le] = #10) then Inc(le);
    end
    else if (le <= Length(Doc)) and (Doc[le] = #10) then
      Inc(le);
    NewDoc := Splice(Doc, ls, le, '');
  end
  else
    NewDoc := Splice(Doc, a, b, '');
  { One occurrence gone, and only one: a deletion that broke the file would change the count
    by something else. }
  Result := DirectiveCount(NewDoc) = DirectiveCount(Doc) - 1;
  if not Result then NewDoc := Doc;
end;

{ ── the validation cache ─────────────────────────────────────────────────── }

{ A caller-owned copy. The report frees what it is given, so an entry can never be handed
  out directly -- one freed report would take the cache with it. }
function CopyDiags(Src: TSpDiagList): TSpDiagList;
var i: Integer;
begin
  Result := TSpDiagList.Create;
  for i := 0 to Src.Count - 1 do Result.Add(Src[i]);
end;

{ Length-prefixed, so no two different tuples can spell one key: without the lengths a slug
  ending in a digit and a text starting with one could meet in the middle. }
function KeyPart(const S: string): string;
begin
  Result := IntToStr(Length(S)) + ':' + S;
end;

function ListKey(L: TStringList): string;
begin
  if L = nil then Result := '' else Result := L.CommaText;
end;

constructor TSpxValidationCache.Create;
begin
  FEntries := TDictionary<string, TSpDiagList>.Create;
  FUsed := TDictionary<string, Boolean>.Create;
end;

destructor TSpxValidationCache.Destroy;
var pair: TPair<string, TSpDiagList>;
begin
  for pair in FEntries do pair.Value.Free;
  FEntries.Free;
  FUsed.Free;
  inherited Destroy;
end;

function TSpxValidationCache.GetCount: Integer;
begin
  Result := FEntries.Count;
end;

procedure TSpxValidationCache.BeginRound;
begin
  FUsed.Clear;
end;

procedure TSpxValidationCache.EndRound;
var
  pair: TPair<string, TSpDiagList>;
  stale: TList<string>;
  key: string;
begin
  { Collected first: a dictionary must not be modified while it is being enumerated. }
  stale := TList<string>.Create;
  try
    for pair in FEntries do
      if not FUsed.ContainsKey(pair.Key) then stale.Add(pair.Key);
    for key in stale do
    begin
      FEntries[key].Free;
      FEntries.Remove(key);
    end;
  finally
    stale.Free;
  end;
end;

function TSpxValidationCache.Validate(const Slug, Text, Locale: string;
  KnownIncludes, KnownVars: TStringList): TSpDiagList;
var
  key: string;
  hit, fresh: TSpDiagList;
begin
  key := KeyPart(Locale) + KeyPart(Slug) + KeyPart(ListKey(KnownIncludes)) +
         KeyPart(ListKey(KnownVars)) + KeyPart(Text);
  if FEntries.TryGetValue(key, hit) then
  begin
    Inc(FHits);
    FUsed.AddOrSetValue(key, True);
    Exit(CopyDiags(hit));
  end;
  Inc(FMisses);
  fresh := SpValidate(Text, Locale, KnownIncludes, KnownVars);
  FEntries.Add(key, fresh);
  FUsed.AddOrSetValue(key, True);
  Result := CopyDiags(fresh);
end;

{ Validate ONE file and file its diagnostics under its own slug. Coordinate spaces are never
  merged: a position from a fragment means nothing in the document's buffer. }
procedure ValidateFile(Report: TSpxReport; const Slug, Text, Locale: string;
  KnownIncludes, KnownVars: TStringList; Cache: TSpxValidationCache);
var diags: TSpDiagList; i: Integer;
begin
  if Cache <> nil then diags := Cache.Validate(Slug, Text, Locale, KnownIncludes, KnownVars)
  else diags := SpValidate(Text, Locale, KnownIncludes, KnownVars);
  try
    for i := 0 to diags.Count - 1 do
      if diags[i].Severity = 'error' then Inc(Report.Errors) else Inc(Report.Warnings);
    Report.Files.Add(TSpxFileReport.Create(Slug, diags));
    diags := nil;   // ownership moved into the file report
  finally
    diags.Free;     // only reached if the line above raised
  end;
  if HasRawSentinel(Text) then
    AddNote(Report, spxNoteRawSentinel, Slug, '', '', 0, 0);
end;

{ The include closure, walked the way the engine renders it: targets compared exactly, a
  cycle keyed on the ref string, the depth cap counting the include stack only. Each file is
  validated once however many times it is included; Path is what makes a cycle a cycle and a
  diamond merely a second visit. }
procedure WalkClosure(Report: TSpxReport; const Text, Slug: string; const Ctx: TSpxContext;
  Visited, Path, KnownIncludes, KnownVars: TStringList; Cache: TSpxValidationCache);
var
  dirs: TSpDirectiveList;
  i, j: Integer;
  target, childText, folded, hint: string;
begin
  ValidateFile(Report, Slug, Text, Ctx.Locale, KnownIncludes, KnownVars, Cache);
  if Ctx.Templates = nil then Exit;

  dirs := SpExtractDirectives(Text);
  try
    for i := 0 to dirs.Count - 1 do
    begin
      if dirs[i].Kind <> 'include' then Continue;
      target := dirs[i].Name;

      { Path IS the engine's include stack: a cycle is a target already on it, keyed on the
        ref string, and the depth cap counts this stack only. Both lists compare
        case-sensitively (set where they are created) because the engine compares targets
        exactly -- a case-insensitive IndexOf here would call `Intro` a cycle of `intro` and
        skip a real file that differs only in case. }
      if Path.IndexOf(target) >= 0 then
      begin
        { The engine unwinds this to the empty string and does not call it invalid -- so
          neither do we. But a fragment that silently renders as nothing deserves a word. }
        AddNote(Report, spxNoteCycle, Slug, target, '', dirs[i].Line, dirs[i].Column);
        Continue;
      end;
      if Path.Count >= SP_DEFAULT_INCLUDE_DEPTH then
      begin
        AddNote(Report, spxNoteTooDeep, Slug, target, '', dirs[i].Line, dirs[i].Column);
        Continue;
      end;

      if not Ctx.Templates.TryGetValue(target, childText) then
      begin
        { The engine reports include.unknown-target against the set's slugs -- but only when
          it was given a non-empty list, so an EMPTY set leaves the miss unsaid. And it can
          never know that the set holds the same name in another case, which on Windows is
          the likeliest reason for the miss. }
        folded := FoldCase(target);
        hint := '';
        for j := 0 to KnownIncludes.Count - 1 do
          if FoldCase(KnownIncludes[j]) = folded then
            { Several slugs can fold to one target (`frag` and `FRAG`). Take the smallest
              rather than whichever the map happened to enumerate first, so the note reads
              the same on every rebuild of the set. }
            if (hint = '') or (KnownIncludes[j] < hint) then hint := KnownIncludes[j];
        if hint <> '' then
          AddNote(Report, spxNoteCaseMismatch, Slug, target, hint,
                  dirs[i].Line, dirs[i].Column);
        if KnownIncludes.Count = 0 then
          AddNote(Report, spxNoteUnknownTarget, Slug, target, '',
                  dirs[i].Line, dirs[i].Column);
        Continue;
      end;

      { Visited is per-closure, not per-path: a file included from two places is one file to
        validate, while two ALIASES of one text are two slugs and neither is a cycle. }
      if Visited.IndexOf(target) >= 0 then Continue;
      Visited.Add(target);
      Path.Add(target);
      WalkClosure(Report, childText, target, Ctx, Visited, Path, KnownIncludes, KnownVars,
                  Cache);
      Path.Delete(Path.Count - 1);
    end;
  finally
    dirs.Free;
  end;
end;

function SpxHealthReport(const Doc: string; const Ctx: TSpxContext;
  Probes: Integer; const DocSlug: string = ''; Cache: TSpxValidationCache = nil): TSpxReport;
var
  knownIncludes, knownVars, visited, path, outputs: TStringList;
  pair: TPair<string, string>;
  i: Integer;
  probe, savedDoc: string;
begin
  Result := TSpxReport.Create;
  knownIncludes := nil; knownVars := nil; visited := nil; path := nil; outputs := nil;
  try
    knownIncludes := TStringList.Create;
    knownVars := TStringList.Create;
    visited := TStringList.Create;
    path := TStringList.Create;
    outputs := TStringList.Create;
    try
      { The engine compares include targets EXACTLY (v0.2.2). `visited` and `path` decide
        what counts as already-seen and as a cycle, so leaving them on TStringList's
        case-INSENSITIVE default would reintroduce, inside Studio, the very defect the
        engine fixed: `Intro` would read as a cycle of `intro`, and a real file differing
        only in case would never be validated. `knownIncludes` is only ever indexed here --
        SpValidate compares slugs with its own exact helper -- so its flag changes nothing
        today and is set so it cannot start to. }
      knownIncludes.CaseSensitive := True;
      visited.CaseSensitive := True;
      path.CaseSensitive := True;
      { CaseSensitive is NOT exactness. TStringList compares through DoCompareText, which
        with CaseSensitive picks AnsiCompareStr -- the OS collation on Windows -- and that
        returns 0 for distinct code points: U+082D and U+0B60 are one key to it, along with
        roughly nine hundred other pairs in the three-byte range. Two slugs differing only
        there would make `visited` skip a real fragment, exactly the drift this comment set
        out to prevent. UseLocale := False is the RTL's own switch to CompareStr, i.e. to
        bytes. Measured; gated by `closure/two-slugs-the-collation-calls-equal`. }
      knownIncludes.UseLocale := False;
      visited.UseLocale := False;
      path.UseLocale := False;

      if Ctx.Templates <> nil then
        for pair in Ctx.Templates do knownIncludes.Add(pair.Key);
      { Variable names are ASCII by the engine's grammar and it matches knownVariables
        case-insensitively, so an ASCII fold is the right one here. }
      if Assigned(Ctx.Vars) then
        for pair in Ctx.Vars do knownVars.Add(LowerCase(pair.Key));

      { The document is normally a member of its own folder's set, so the walk can reach it
        again through its own slug. Skip that ONLY when the set's copy is the same text as
        the buffer -- then it is genuinely the same file and validating it twice would count
        one broken bracket as two errors. When the buffer has unsaved edits the two differ,
        and the SAVED copy is what the engine will render for an `#include`, so it has to be
        validated on its own. Path stays EMPTY at document level either way, because the
        engine's include stack is empty there and the depth cap counts that stack. }
      if (DocSlug <> '') and (Ctx.Templates <> nil) and
         Ctx.Templates.TryGetValue(DocSlug, savedDoc) and (savedDoc = Doc) then
        visited.Add(DocSlug);

      { Both sets go in on every pass. knownVars carries the RUNTIME names only: a file's own
        macros are visible to the validator anyway, and the parent's are not visible to a
        child at render time (ADR 0003). }
      { One health report is one ROUND: whatever the walk does not reach is dropped when it
        ends, so the cache holds the current closure and not the history of every keystroke. }
      if Cache <> nil then Cache.BeginRound;
      try
        WalkClosure(Result, Doc, '', Ctx, visited, path, knownIncludes, knownVars, Cache);
      finally
        if Cache <> nil then Cache.EndRound;
      end;

      { Health probes on fixed seeds, so the same document always reports the same numbers --
        a status bar that flickers between runs teaches the user to ignore it. }
      outputs.CaseSensitive := True;   // 'AA' and 'aa' are two renders, not one
      outputs.UseLocale := False;      // ...and so are two renders differing by one code point
      outputs.Sorted := True;
      outputs.Duplicates := dupIgnore;
      for i := 1 to Probes do
      begin
        probe := RenderWith(Doc, Ctx, True, LongWord(i));
        Inc(Result.Probes);
        if Trim(probe) = '' then Inc(Result.EmptyProbes);
        if (Pos(FullwidthBrace(True), probe) > 0) or (Pos(FullwidthBrace(False), probe) > 0) then
          Result.FullwidthFallback := True;
        outputs.Add(probe);
      end;
      Result.DistinctProbes := outputs.Count;
    finally
      knownIncludes.Free;
      knownVars.Free;
      visited.Free;
      path.Free;
      outputs.Free;
    end;
  except
    { The report is the return value, so nothing else can free it if we leave by exception --
      and this layer is built for a cancelling worker (spec §5), where that is not exotic. }
    Result.Free;
    raise;
  end;
end;

end.
