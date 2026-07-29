{**
 * The DeepL skeleton (spec §3): a narrow strip of controls, the template on the left, what
 * it produces on the right. Nothing else -- the panels come with M2.
 *
 * The UI is built in CODE, not in an .lfm. This project is written and reviewed through
 * text, and a form file is a generated artefact that neither reads nor merges well; the
 * layout here is a dozen anchored controls, which is cheaper to read than the XML would be.
 * Reconsider when there is a form the designer would genuinely help with.
 *}
unit SpxMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Menus, Dialogs, ImgList,
  Clipbrd, Graphics, LCLType,
  SynEdit, SynEditTypes, SynEditWrappedView, SynEditMarkup, SynEditMarkupBracket,
  SpxStudio, SpxEngineThread, SpxSynHighlighter, SpxBracketMarkup, SpxDiagMarkup,
  SpxToolRail, SpxGroupPane, SpxGroups, SpxIcons, SpxFlags,
  SpxPreviewPane, SpxVarsPane, SpxVariantsPane, SpxDedupe, SpxFiles, SpxDemo, SpxUi,
  SpxStrIds, SpxStrings;

type
  TSpxMainForm = class(TForm)
  private
    FTop: TPanel;
    FLocale: TComboBox;
    FSeeded: TCheckBox;
    FSeedEdit: TEdit;
    FReroll: TButton;
    FCopy: TButton;
    { The preview's own controls, in the WINDOW's strip rather than in a strip of the pane's
      own: two panes side by side should start on the same line, and a header inside one of
      them puts its content a row lower than the other. Anchored right, so they stay in the
      corner when the window is resized. }
    FAsPage: TRadioButton;
    FAsSource: TRadioButton;
    FPartial: TLabel;
    FSplit: TSplitter;
    { The tools' strip. It is the window's, not the editor's pane's: a user who moves it to
      the right expects it at the window's edge, the way every side bar behaves. }
    FRail: TSpxToolRail;
    { The interface's language is the USER'S setting: a language of its own, or the
      document's if the user asks for that. Tying it to the document was a surprise every
      time the locale box was touched, so the tie is a choice and the default is the
      machine's language. }
    FLangChosen: TSpxLang;
    FLangFollow: Boolean;
    { The flags beside the language names. Owned by the FORM, not by the menu bar: the bar is
      freed and rebuilt on every language switch, and a list that went with it would be one
      more sprite decoded per switch. }
    FFlags: TImageList;
    { Everything that is not the rail. Two controls aligned to the same edge are ordered by
      LCL and not by us -- measured: created first, re-aligned, even moved to index 0, the
      rail still opened between the editor and the preview. A container settles it by
      construction: the rail takes its edge, this takes what is left, and there is no
      ordering question to lose. }
    FBody: TPanel;
    { One aligned control per level, always: FOuter holds the slide-out and the body, the
      form holds the rail and FOuter. Two siblings aligned to the same edge are ordered by
      LCL and not by us -- that cost an afternoon once already. }
    FOuter: TPanel;
    FSlide: TSpxGroupPane;
    { The caret moves in bursts; the group under it is looked up once the burst stops. }
    FCaretTimer: TTimer;
    FLeft: TPanel;
    { Search lives in the LEFT half of the top strip -- the half over the editor, because the
      template is what is searched. It used to be a row of its own above the editor, which
      cost the editor a line every time it opened while the strip above sat half empty
      holding controls that belong to the output. }
    FFindText: TEdit;
    FFindCount: TLabel;
    FFindCase: TCheckBox;
    FFindPrev: TButton;
    FFindNext: TButton;
    FFindClose: TButton;
    FMatches: TSpxMatches;
    { WHICH match is showing, remembered rather than derived from the caret. The caret's
      column is PHYSICAL -- a tab is one code point and up to eight of those columns, a
      combining mark is one and none -- so deriving the index from it stepped over matches on
      tab-indented lines and could return the same one twice on a line with combining marks.
      -1 means "not on one yet", and then the caret decides, converted properly. }
    FMatchIndex: Integer;
    { The document changed under an open find bar. The list is rebuilt on the next debounce
      tick rather than on the keystroke: a rescan is 8-13 ms on a 116 KB template and the
      user is typing. }
    FMatchesStale: Boolean;
    FEditor: TSynEdit;
    FHighlighter: TSpxSynHighlighter;
    FErrorMarkup: TSpxDiagMarkup;
    FWarnMarkup: TSpxDiagMarkup;
    FPreview: TSpxPreviewPane;
    FStatus: TStatusBar;
    FDebounce: TTimer;
    FEngine: TSpxEngineThread;
    FNextId: Int64;
    FLastShown: Int64;
    { The document on disk. FPath is '' until it has been saved once, and that is what makes
      the template set empty and every `#include` verbatim -- the engine's own behaviour
      without a resolver, not a placeholder. FEol and FTrailingEol are the file's own shape,
      kept so that saving an edit does not rewrite every line of somebody's git history. }
    FPath: string;
    FEol: string;
    FTrailingEol: Boolean;
    FReloadSet: Boolean;
    { The panel and the rows behind it. FRowSig is what the list currently shows, so a
      keystroke that changes nothing does not rebuild the list under the user's hand. }
    FBottom: TPageControl;
    FDiag: TListView;
    FVars: TSpxVarsPane;
    FSet: TSpxVariantsPane;
    FDiagSplit: TSplitter;
    FRows: TSpxPanelRows;
    FRowSig: string;
    FPendingRow: TSpxPanelRow;
    { What a jump left behind, so the preview does not narrow to it: going to look at an
      error must not replace the document's preview with a render of the broken span. The
      rule that reads this lives in editor-core, where it is gated. }
    FJump: TSpxJumpState;
    { What the preview was last ASKED for. A selection change that would produce the same
      preview does not restart the render: jumping between search hits or diagnostics
      selects spans that deliberately do not narrow, and re-rendering the whole document for
      each of them costs 320 ms and a flicker on a 116 KB template -- reported as the search
      "передёргивая" the preview. }
    FShownAsk: TSpxPreviewAsk;
    { Set while a jump is assigning the block. Setting BlockBegin and then BlockEnd fires the
      selection event TWICE, and at both moments the jump state is deliberately not written
      yet -- so the half-made selection looks like one the user made, and a render is
      scheduled before anything can say otherwise. The decision is taken once, at the end of
      the jump, when the state is true. }
    FJumping: Boolean;
    procedure DiagColumn(const ACaption: string; AWidth: Integer);
    procedure DiagClicked(Sender: TObject);
    procedure DiagResized(Sender: TObject);
    procedure JumpDeferred(Data: PtrInt);
    procedure VarJump(Line, Column: Integer);
    procedure RuntimeChanged(Sender: TObject);
    procedure SelectionChanged(Sender: TObject; Changes: TSynStatusChanges);
    procedure PreviewFollowSelection;
    procedure WrapSelection(const L, R: string);
    function CurrentSelection(WithText: Boolean): TSpxSelection;
    procedure WrapBracesClicked(Sender: TObject);
    procedure WrapBracketsClicked(Sender: TObject);
    procedure JumpToPos(Line, Column, EndLine, EndColumn: Integer);
    procedure ShowRows(const ARows: TSpxPanelRows);
    procedure JumpTo(Row: TSpxPanelRow);
    function LineOf(N: Integer): string;
    procedure BuildUi;
    procedure BuildFindBar;
    procedure LayoutTopStrip;
    procedure TopStripResized(Sender: TObject);
    procedure BuildMenu;
    procedure EnsureFlags;
    procedure ShowFindBar;
    procedure HideFindBar;
    procedure FindTextChanged(Sender: TObject);
    procedure FindNextClicked(Sender: TObject);
    procedure FindPrevClicked(Sender: TObject);
    procedure FindCloseClicked(Sender: TObject);
    procedure FindMenuClicked(Sender: TObject);
    procedure FindKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure StepToMatch(Backwards: Boolean);
    procedure RefreshMatches;
    procedure ShowMatchCount;
    procedure RailDiagClicked(Sender: TObject);
    procedure RailVarsClicked(Sender: TObject);
    procedure RailSetClicked(Sender: TObject);
    procedure LangPicked(Sender: TObject);
    procedure LangFollowClicked(Sender: TObject);
    procedure ApplyLangMode;
    procedure RailLeftClicked(Sender: TObject);
    procedure RailRightClicked(Sender: TObject);
    procedure BuildRail;
    procedure RailGroupClicked(Sender: TObject);
    procedure CaretSettled(Sender: TObject);
    procedure GroupApplied(BodyStart, Stop: Integer; const Body: string);
    { The caret's byte offset into FEditor.Text, and the way back. The two must agree, which
      is why both live here rather than being computed at their call sites. }
    function CaretOffset: Integer;
    function OffsetToPoint(AOffset: Integer): TPoint;
    procedure NewClicked(Sender: TObject);
    procedure OpenClicked(Sender: TObject);
    procedure SaveClicked(Sender: TObject);
    procedure SaveAsClicked(Sender: TObject);
    procedure ReloadSetClicked(Sender: TObject);
    procedure ExitClicked(Sender: TObject);
    procedure FormAsked(Sender: TObject; var CanClose: Boolean);
    function DocText: string;
    function SaveDocument(AsNew: Boolean): Boolean;
    procedure LoadDocument(const APath: string);
    function AskSave: Boolean;
    procedure UpdateCaption;
    procedure EditorChanged(Sender: TObject);
    procedure SettingChanged(Sender: TObject);
    procedure RetranslateUi;
    procedure DebounceFired(Sender: TObject);
    procedure RerollClicked(Sender: TObject);
    procedure CopyClicked(Sender: TObject);
    procedure PreviewModeChanged(Sender: TObject);
    procedure SayPartial(const AHtml: string; APartial: Boolean);
    procedure JobDone(const Res: TSpxJobResult);
    procedure RequestRender;
    { The batch: the panel asks, the form fills in what only it knows, the worker runs it one
      variant at a time and reports back here. }
    procedure StartBatch(Count: Integer; SeedBase: LongWord; const Opts: TSpxDedupeOpts);
    procedure CancelBatch(Sender: TObject);
    procedure StopBatchForDocument;
    procedure BatchProgress(const P: TSpxBatchProgress);
    procedure ShowVariant(const AText: string);
    procedure StopEngine;
    procedure FormClosed(Sender: TObject; var CloseAction: TCloseAction);
  public
    { A window is CONSTRUCTED at 96 dpi: LCL pins PixelsPerInch there and only applies the
      monitor's afterwards, then again on every WM_DPICHANGED. Both sprites are therefore
      picked for 100% wherever the app actually runs, and an image list draws at its own size
      -- so without this a 150% display showed 24px glyphs in 54px buttons for the life of
      the window. The app declares PM_V2 in its manifest, so the rescale really happens.

      It is THIS hook and not the child's DoAutoAdjustLayout because the form assigns its new
      PixelsPerInch after the children are adjusted; the inherited call below is what makes
      Px() answer for the display we have just arrived on. }
    procedure AutoAdjustLayout(AMode: TLayoutAdjustmentPolicy;
      const AFromPPI, AToPPI, AOldFormWidth, ANewFormWidth: Integer); override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { How many jobs this window has asked the engine for. Read-only, and out here because
      "did that action cause a render?" is otherwise unanswerable from outside -- which is
      exactly the question behind a preview that flickers when it should not. }
    property JobsPosted: Int64 read FNextId;
  end;

var
  MainForm: TSpxMainForm;

implementation

type
  { The markup manager is protected on TSynEditBase; a descendant declared here reaches it
    without patching SynEdit. }
  TSynEditReach = class(TSynEdit);

const
  DEBOUNCE_MS = 200;   // long enough to skip a burst of typing, short enough to feel live


constructor TSpxMainForm.Create(AOwner: TComponent);
begin
  { CreateNew, not Create: there is no .lfm resource to load. }
  inherited CreateNew(AOwner);
  { Decided BEFORE anything is built: every caption is read once, when its control is
    created, and changing it afterwards needs them all re-read (RetranslateUi).

    The MACHINE's language, not the document's. A desktop application opens in the language
    of the desktop; whether it then follows the template is the user's setting, and it is not
    the default -- an interface that changed language because the text did was a surprise
    every time the locale box was touched. }
  FLangFollow := False;
  FLangChosen := SpxSystemLang;
  SpxSetUiLang(FLangChosen);
  FPath := '';
  FEol := SPX_DEFAULT_EOL;
  FTrailingEol := True;
  BuildUi;
  UpdateCaption;
  FNextId := 0;
  FLastShown := -1;
  { The strip is laid out once, here, with every control it positions in existence. }
  LayoutTopStrip;
  FEngine := TSpxEngineThread.Create(@JobDone);
  { Only now: BuildUi has run, so the panel exists, and so does the thread. }
  FEngine.OnBatch := @BatchProgress;
  { `spintax-studio path\to\file.spintax` -- what a double-click in Explorer sends once the
    extension is associated, and the only way to open a document without a dialog. }
  if (ParamCount >= 1) and FileExists(ParamStr(1)) then LoadDocument(ParamStr(1))
  else RequestRender;
end;

procedure TSpxMainForm.BuildUi;
var
  sheetDiag, sheetVars, sheetSet: TTabSheet;
begin
  Width := 1100;
  Height := 700;
  { Below this the panes stop being panes: the bottom strip alone is 170 pixels, and an
    editor narrower than its own gutter plus a line of text is not an editor. }
  Constraints.MinWidth := Px(Self, 760);
  Constraints.MinHeight := Px(Self, 520);
  Position := poScreenCenter;
  OnClose := @FormClosed;
  OnCloseQuery := @FormAsked;

  { FIRST, both of them, and before anything that has to sit inside. The rail takes its edge
    of the window; the body takes what is left; everything else is built into the body. Two
    controls aligned to the same edge are ordered by LCL rather than by us -- measured, the
    rail opened between the editor and the preview whether it was created first, re-aligned,
    or moved to index 0 -- so the layout is arranged to have no such pair at all. }
  BuildRail;

  FOuter := TPanel.Create(Self);
  FOuter.Parent := Self;
  FOuter.Align := alClient;
  FOuter.BevelOuter := bvNone;

  { The group editor, hidden until its tool is pressed. It PUSHES rather than covers: the
    panel edits the template, and covering the text you are editing is the thing a dialog
    does wrong. }
  FSlide := TSpxGroupPane.Create(Self);
  FSlide.Parent := FOuter;
  FSlide.Align := alLeft;
  FSlide.Width := Px(Self, SPX_SLIDE_W);
  FSlide.Visible := False;
  FSlide.OnApply := @GroupApplied;

  FBody := TPanel.Create(Self);
  FBody.Parent := FOuter;
  FBody.Align := alClient;
  FBody.BevelOuter := bvNone;

  { The menu is built after the rail because its View section shows which side the rail is
    on. }
  BuildMenu;

  FTop := TPanel.Create(Self);
  FTop.Parent := FBody;
  FTop.Align := alTop;
  FTop.Height := Px(Self, 38);
  FTop.BevelOuter := bvNone;
  FTop.OnResize := @TopStripResized;

  FLocale := TComboBox.Create(Self);
  FLocale.Parent := FTop;
  FLocale.Style := csDropDownList;
  FLocale.Items.CommaText := 'ru,uk,be,en,de,fr,es,sr,hr,bs';
  { The locale belongs to the TEMPLATE, not to the UI, so it opens on the demo's language.
    On `ru` the demo is genuinely invalid: PluralArity('ru') is 3 and the demo's plural
    block carries two forms, which the engine reports as plural.arity at 11:120 -- and an
    app that opens on an error against its own sample teaches the user to distrust the
    verdict. }
  FLocale.ItemIndex := FLocale.Items.IndexOf('en');
  FLocale.SetBounds(Px(Self, 8), Px(Self, 7), Px(Self, 70), Px(Self, 24));
  FLocale.OnChange := @SettingChanged;

  FSeeded := TCheckBox.Create(Self);
  FSeeded.Parent := FTop;
  FSeeded.Caption := Tr(sSeed);
  FSeeded.SetBounds(Px(Self, 90), Px(Self, 9), Px(Self, 55), Px(Self, 22));
  FSeeded.OnChange := @SettingChanged;

  FSeedEdit := TEdit.Create(Self);
  FSeedEdit.Parent := FTop;
  { Hidden until the seed is PINNED. Unchecked, the number answers a question nobody asked
    and spends a field's worth of the strip right where the eye goes when reading the
    template. }
  FSeedEdit.Visible := False;
  FSeedEdit.Text := '1';
  FSeedEdit.SetBounds(Px(Self, 145), Px(Self, 7), Px(Self, 70), Px(Self, 24));
  FSeedEdit.OnChange := @SettingChanged;

  FReroll := TButton.Create(Self);
  FReroll.Parent := FTop;
  FReroll.Caption := Tr(sReroll);
  FReroll.SetBounds(Px(Self, 228), Px(Self, 6), Px(Self, 80), Px(Self, 26));
  FReroll.OnClick := @RerollClicked;

  FCopy := TButton.Create(Self);
  FCopy.Parent := FTop;
  FCopy.Caption := Tr(sCopy);
  FCopy.SetBounds(Px(Self, 314), Px(Self, 6), Px(Self, 80), Px(Self, 26));

  FPartial := TLabel.Create(Self);
  FPartial.Parent := FTop;
  FPartial.AutoSize := True;
  FPartial.Visible := False;

  FAsPage := TRadioButton.Create(Self);
  FAsPage.Parent := FTop;
  FAsPage.Caption := Tr(sViewPage);
  FAsPage.Checked := True;
  FAsPage.OnChange := @PreviewModeChanged;

  FAsSource := TRadioButton.Create(Self);
  FAsSource.Parent := FTop;
  FAsSource.Caption := Tr(sViewSource);
  FAsSource.OnChange := @PreviewModeChanged;
  FCopy.OnClick := @CopyClicked;

  { The three bottom-aligned strips are ordered by their Top, not by the order they are
    created in -- larger Top sits closer to the bottom edge -- so the order is stated
    instead of hoped for. Without it the status bar came out ABOVE the tab strip, and the
    splitter had no unambiguous neighbour to resize, which is why the bottom would not
    stretch. }
  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := FBody;
  FStatus.Top := 30000;
  FStatus.SimplePanel := True;
  FStatus.SimpleText := Tr(sStatusReady);

  { The bottom strip, created before the two panes so it owns that space and they divide
    what is left. Two tabs rather than two more panels: the window is already a two-pane
    editor, and every strip added to it is taken from the template. }
  FBottom := TPageControl.Create(Self);
  FBottom.Parent := FBody;
  FBottom.Top := 20000;
  FBottom.Align := alBottom;
  { Two grids and their headings need more than 170: at that height the definitions list had
    no room left at all. The splitter above takes it from here. }
  FBottom.Height := Px(Self, 240);
  sheetDiag := FBottom.AddTabSheet;
  sheetDiag.Caption := Tr(sTabDiagnostics);
  sheetVars := FBottom.AddTabSheet;
  sheetVars.Caption := Tr(sTabVariables);
  sheetSet := FBottom.AddTabSheet;
  sheetSet.Caption := Tr(sTabVariants);

  { What a squiggle cannot show: a finding inside an included file, and one the engine could
    not place at all. }
  FDiag := TListView.Create(Self);
  FDiag.Parent := sheetDiag;
  FDiag.Align := alClient;
  FDiag.ViewStyle := vsReport;
  FDiag.ReadOnly := True;
  FDiag.RowSelect := True;
  FDiag.HideSelection := False;
  { Px like everything else: these four were raw pixels, so at 150% the font grew and the
    columns did not -- the level and file columns ellipsised whatever the budget said. }
  DiagColumn(Tr(sColLevel), Px(Self, 130));
  DiagColumn(Tr(sColFile), Px(Self, 130));
  DiagColumn(Tr(sColAt), Px(Self, 70));
  DiagColumn(Tr(sColMessage), Px(Self, 640));
  FDiag.OnClick := @DiagClicked;
  FDiag.OnResize := @DiagResized;

  { The variables panel: what the document defines, and what this session supplies. }
  FVars := TSpxVarsPane.Create(Self);
  FVars.Parent := sheetVars;
  FVars.Align := alClient;
  FVars.OnJump := @VarJump;
  FVars.OnRuntimeChanged := @RuntimeChanged;

  { The batch and its export. The panel owns N, the seed and the dedup settings; the document,
    the locale and the session values are the form's, so it is the form that assembles the
    request -- the same split the render path already uses. }
  FSet := TSpxVariantsPane.Create(Self);
  FSet.Parent := sheetSet;
  FSet.Align := alClient;
  FSet.OnGenerate := @StartBatch;
  FSet.OnCancelBatch := @CancelBatch;
  FSet.OnShowVariant := @ShowVariant;
  { The worker's own event is NOT hooked here: BuildUi runs before the engine exists, and
    the first version of this line dereferenced nil at startup -- an access violation before
    the window ever appeared. It is set in the constructor, right after the thread. }

  FDiagSplit := TSplitter.Create(Self);
  FDiagSplit.Parent := FBody;
  FDiagSplit.Top := 10000;        { above the tab strip: see the note on FStatus }
  FDiagSplit.Align := alBottom;
  FDiagSplit.MinSize := Px(Self, 80);       { neither the panes nor the strip may be dragged to nothing }

  { The editor's SIDE, not the editor alone. The find bar goes above it, and both belong to
    the template rather than to the window -- a bar parented to the form would stretch across
    the preview as well. }
  FLeft := TPanel.Create(Self);
  FLeft.Parent := FBody;
  FLeft.Align := alLeft;
  FLeft.BevelOuter := bvNone;
  { A PROPORTION, not a pixel count. 540 was right for the window this was written at and
    for nobody else's screen; the two panes are meant to be comparable, and the user moves
    the splitter from there. }
  FLeft.Width := (ClientWidth * 48) div 100;

  BuildFindBar;

  FEditor := TSynEdit.Create(Self);
  FEditor.Parent := FLeft;
  FEditor.Align := alClient;
  { Fixed pitch, because a template is markup -- but only the FAMILY is ours. The size
    stays the system's, so a desktop configured for larger text gets a larger editor. }
  SpxApplyMonoFont(FEditor.Font);
  FEditor.Gutter.Visible := True;
  { The walkthrough from spintax.net: it opens on something that demonstrates the product
    -- macros, a conditional, plurals, permutations with config -- rather than a toy, and
    the suite scans and validates the same text (SpxDemo). }
  FHighlighter := TSpxSynHighlighter.Create(Self);
  FEditor.Highlighter := FHighlighter;
  FEditor.Text := SpxDemoTemplate;
  FEditor.OnChange := @EditorChanged;
  FEditor.OnStatusChange := @SelectionChanged;
  { The demo's paragraphs run past 500 characters, and a template pane that opens on
    one-eighth of a line teaches the user to scroll rather than to read. Wrapping is the
    editor's own plugin, so the buffer keeps its real lines and every position the engine
    reports still lands where it should. }
  TLazSynEditLineWrapPlugin.Create(FEditor);
  { ...but wrapping does not retract the horizontal scrollbar, and SynEdit's default is
    ssBoth: the bar sat at the foot of a view that has nowhere sideways to go, and dragging it
    slid the wrapped text off to the left until only the tail ends of the lines were visible,
    with blank pane beside them. Measured on the real form: WS_HSCROLL present with ssBoth,
    absent with this.

    It settles a second oddity for free -- the plain wheel is remapped to HORIZONTAL scrolling
    whenever the horizontal bar is visible and the vertical one is not (synedit.pp ~3470), so
    in a document shorter than a page the wheel scrolled sideways. No bar, no remap. }
  FEditor.ScrollBars := ssAutoVertical;
  { Dropping the bar removes the way IN; dropping eoScrollPastEol removes the STATE, and only
    that makes the artifact impossible rather than merely hard to reach -- a horizontal tilt
    wheel, a touchpad swipe and a drag-select out of the pane all still call SetLeftChar, and
    with no bar left there would be nothing to come back with.

    The travel was never the document's: it is MaxLeftChar = 1024, admitted unconditionally by
    the default eoScrollPastEol. Measured ceiling 969 columns for the demo AND for a
    13-character document alike; with the option gone, CurrentMaxLeftChar falls back to
    LengthOfLongestLine + 1, which the wrap plugin keeps at the wrap column -- measured
    ceiling 1, both documents, every route clamped.

    Its price is the caret, and it is the right price here: the caret can no longer be put
    BEYOND the end of a line, but it still reaches the position after the last character
    (measured: EOL+1 stands, EOL+50 snaps back to it), which is where every exclusive End
    position the app computes lands. Clicking past the end of a paragraph landing at the end
    of the paragraph is what a prose editor does anyway.

    And no 80-column rule -- a code editor's convention, drawn here as a line standing in the
    middle of wrapped prose. The switch is this OPTION, not RightEdge := 0: SetRightEdge has
    no zero case, so a zero would merely move the line to the start of the text. }
  FEditor.Options := FEditor.Options - [eoScrollPastEol] + [eoHideRightMargin];

  { Bracket matching by spintax rules. SynEdit's own markup counts parentheses and quotes
    as brackets and ignores block comments, so it is switched off and ours takes its place;
    the pairing rule itself is `SpxMatchBracket`, gated by the console suite. Reaching the
    markup manager needs the protected accessor, hence the local descendant. }
  FEditor.MarkupByClass[TSynEditMarkupBracket].Enabled := False;
  TSynEditMarkupManager(TSynEditReach(FEditor).MarkupMgr).AddMarkUp(
    TSpxBracketMarkup.Create(FEditor));

  { Squiggles: red under an error, amber under a warning, on the engine's own spans. One
    markup per severity, because a markup carries one attribute. }
  FErrorMarkup := TSpxDiagMarkup.Create(FEditor, True);
  FWarnMarkup := TSpxDiagMarkup.Create(FEditor, False);
  TSynEditMarkupManager(TSynEditReach(FEditor).MarkupMgr).AddMarkUp(FErrorMarkup);
  TSynEditMarkupManager(TSynEditReach(FEditor).MarkupMgr).AddMarkUp(FWarnMarkup);

  FSplit := TSplitter.Create(Self);
  FSplit.Parent := FBody;
  FSplit.Align := alLeft;
  FSplit.Left := FLeft.Width + 1;

  { Two views of the same output -- the page and the HTML it is -- with the switch and the
    size guard owned by the pane itself (SpxPreviewPane, ADR 0004). }
  FPreview := TSpxPreviewPane.Create(Self);
  FPreview.Parent := FBody;
  FPreview.Align := alClient;

  FDebounce := TTimer.Create(Self);
  FDebounce.Enabled := False;
  FDebounce.Interval := DEBOUNCE_MS;
  FDebounce.OnTimer := @DebounceFired;

  FCaretTimer := TTimer.Create(Self);
  FCaretTimer.Enabled := False;
  FCaretTimer.Interval := 120;
  FCaretTimer.OnTimer := @CaretSettled;

end;

{ The find bar. Hidden until asked for, because a template is read far more often than it is
  searched and a permanent row would cost the editor a line of text for nothing. }
procedure TSpxMainForm.BuildFindBar;
begin
  FFindText := TEdit.Create(Self);
  FFindText.Parent := FTop;
  FFindText.Visible := False;
  FFindText.OnChange := @FindTextChanged;
  FFindText.OnKeyDown := @FindKeyDown;

  FFindPrev := TButton.Create(Self);
  FFindPrev.Parent := FTop;
  FFindPrev.Visible := False;
  FFindPrev.Caption := '<';
  FFindPrev.OnClick := @FindPrevClicked;

  FFindNext := TButton.Create(Self);
  FFindNext.Parent := FTop;
  FFindNext.Visible := False;
  FFindNext.Caption := '>';
  FFindNext.OnClick := @FindNextClicked;

  FFindCase := TCheckBox.Create(Self);
  FFindCase.Parent := FTop;
  FFindCase.Visible := False;
  FFindCase.Caption := Tr(sFindCase);
  FFindCase.OnChange := @FindTextChanged;
  FFindCase.OnKeyDown := @FindKeyDown;

  { How many there are, and which one you are on. A search box without a count answers
    "is it there" and leaves "how many" and "where am I" unanswered.

    ANCHORED RIGHT, with the close button. The bar lives in a container that is 48% of the
    window and freely resized by the splitter, so absolute offsets put the counter under the
    close button as soon as the user favours the preview -- and it is the counter, the one
    thing here that carries information, that would be the first to disappear. }
  FFindCount := TLabel.Create(Self);
  { LayoutTopStrip hands it a width; a label that also sizes itself to its caption would
    discard that and drift towards the close button. }
  FFindCount.AutoSize := False;
  FFindCount.Parent := FTop;
  FFindCount.Visible := False;

  FFindClose := TButton.Create(Self);
  FFindClose.Parent := FTop;
  FFindClose.Visible := False;
  FFindClose.Caption := Tr(sFindClose);
  FFindClose.OnClick := @FindCloseClicked;
  FFindClose.OnKeyDown := @FindKeyDown;
  FFindPrev.OnKeyDown := @FindKeyDown;
  FFindNext.OnKeyDown := @FindKeyDown;
end;

{ THE TOP STRIP, laid out from both edges.

  Its two halves mean different things, which is the whole point of the arrangement: the LEFT
  belongs to the template -- searching it -- and the RIGHT to the output -- the language it
  renders in, the seed, another variant, copying the result, and which of the two views is
  shown. Before this, everything sat on the left and search had to open a row of its own,
  taking a line from the editor while the strip above it was half empty.

  Positions are computed rather than anchored because the right group is a chain: each
  control sits to the left of the one after it, and the caption widths differ per language.
  The find field takes whatever is left between the two groups, so the strip survives a
  narrow window instead of overlapping. }
procedure TSpxMainForm.TopStripResized(Sender: TObject);
begin
  LayoutTopStrip;
end;

procedure TSpxMainForm.LayoutTopStrip;
var right_, leftEnd, x, y, fieldW, fixed: Integer;

  procedure PlaceRight(C: TControl; W, H, Y: Integer);
  begin
    Dec(right_, W);
    C.SetBounds(right_, Y, W, H);
    Dec(right_, Px(Self, 8));
  end;

begin
  { A HALF-BUILT WINDOW IS A NORMAL STATE HERE: this runs during construction, from a resize
    that fires before the last control exists, and again at the end. Three startup crashes in
    this project have been exactly this shape -- a layout or an event hookup reaching for
    something not created yet -- so the guard names every group it touches rather than
    trusting the order things happen in. }
  if (FTop = nil) or (FAsSource = nil) or (FLocale = nil) or (FCopy = nil) or
     (FFindText = nil) then Exit;

  { ── the output's half, from the right edge inwards ── }
  right_ := FTop.ClientWidth - Px(Self, 12);
  PlaceRight(FAsSource, Px(Self, 90), Px(Self, 20), Px(Self, 9));
  PlaceRight(FAsPage, Px(Self, 90), Px(Self, 20), Px(Self, 9));
  if FPartial.Visible then PlaceRight(FPartial, FPartial.Width, Px(Self, 16), Px(Self, 11));
  PlaceRight(FCopy, Px(Self, 80), Px(Self, 26), Px(Self, 6));
  PlaceRight(FReroll, Px(Self, 80), Px(Self, 26), Px(Self, 6));
  { Skipped rather than placed off-screen, so the controls to its left close the gap -- the
    same way the fragment caption already comes and goes. }
  if FSeedEdit.Visible then PlaceRight(FSeedEdit, Px(Self, 70), Px(Self, 24), Px(Self, 7));
  PlaceRight(FSeeded, Px(Self, 55), Px(Self, 22), Px(Self, 9));
  PlaceRight(FLocale, Px(Self, 70), Px(Self, 24), Px(Self, 7));
  leftEnd := right_;

  { ── the template's half, from the left edge outwards, and only when searching ── }
  if not FFindText.Visible then
  begin
    FTop.Height := Px(Self, 38);
    Exit;
  end;

  { Everything except the field has a fixed width, so the field absorbs the difference. When
    even a usable field will not fit beside the output's half, search takes a SECOND ROW
    rather than overlapping it -- measured: at 820 wide the two groups ran through each
    other. The row costs the editor a line, which is exactly what this arrangement avoids at
    the widths a person actually works at (one row from about 1000 up), and it is still
    better than controls drawn on top of one another. }
  fixed := Px(Self, 8 + 34 + 4 + 34 + 8 + 90 + 8 + 110 + 8 + 28);
  x := Px(Self, 8);
  if leftEnd - x - fixed >= Px(Self, 140) then
  begin
    y := Px(Self, 0);
    fieldW := leftEnd - x - fixed;
    FTop.Height := Px(Self, 38);
  end
  else
  begin
    y := Px(Self, 32);
    fieldW := FTop.ClientWidth - x - fixed - Px(Self, 8);
    if fieldW < Px(Self, 90) then fieldW := Px(Self, 90);
    FTop.Height := Px(Self, 70);
  end;

  FFindText.SetBounds(x, y + Px(Self, 7), fieldW, Px(Self, 24));
  Inc(x, fieldW + Px(Self, 8));
  FFindPrev.SetBounds(x, y + Px(Self, 6), Px(Self, 34), Px(Self, 26));
  Inc(x, Px(Self, 38));
  FFindNext.SetBounds(x, y + Px(Self, 6), Px(Self, 34), Px(Self, 26));
  Inc(x, Px(Self, 42));
  FFindCase.SetBounds(x, y + Px(Self, 9), Px(Self, 90), Px(Self, 20));
  Inc(x, Px(Self, 98));
  { 110px, and the captions are written to fit it: widening this by twenty pixels is enough
    to push a 1100px window -- the default size -- into the two-row strip, which is a worse
    trade than a compact '12/57'. }
  FFindCount.SetBounds(x, y + Px(Self, 11), Px(Self, 110), Px(Self, 16));
  Inc(x, Px(Self, 118));
  FFindClose.SetBounds(x, y + Px(Self, 6), Px(Self, 28), Px(Self, 26));
end;

procedure TSpxMainForm.ShowFindBar;
begin
  { Opening on the selection is what every editor does and what the hand expects: select a
    macro, press Ctrl+F, and the box already holds it. }
  if (FEditor.SelAvail) and (Pos(LineEnding, FEditor.SelText) = 0) then
    FFindText.Text := FEditor.SelText;
  FFindText.Visible := True;
  FFindPrev.Visible := True;
  FFindNext.Visible := True;
  FFindCase.Visible := True;
  FFindCount.Visible := True;
  FFindClose.Visible := True;
  LayoutTopStrip;
  if FFindText.CanSetFocus then
  begin
    FFindText.SetFocus;
    FFindText.SelectAll;
  end;
  RefreshMatches;
end;

procedure TSpxMainForm.HideFindBar;
begin
  FFindText.Visible := False;
  FFindPrev.Visible := False;
  FFindNext.Visible := False;
  FFindCase.Visible := False;
  FFindCount.Visible := False;
  FFindClose.Visible := False;
  FMatches := nil;
  if FEditor.CanSetFocus then FEditor.SetFocus;
end;

{ The counter in words. One routine rather than a line at each site, because it is also what
  a language switch repaints -- and a caption that only three of four sites know how to write
  is how the strip ends up half-translated. }
procedure TSpxMainForm.ShowMatchCount;
begin
  if (FFindText = nil) or (FFindCount = nil) then Exit;
  if FFindText.Text = '' then FFindCount.Caption := ''
  else if Length(FMatches) = 0 then FFindCount.Caption := Tr(sFindNothing)
  else if FMatchIndex >= 0 then
    FFindCount.Caption := Format(Tr(sFindPosition), [FMatchIndex + 1, Length(FMatches)])
  else
    FFindCount.Caption := Format(Tr(sFindMatches), [Length(FMatches)]);
end;

procedure TSpxMainForm.RefreshMatches;
var n: Integer;
begin
  FMatches := SpxFindAll(FEditor.Text, FFindText.Text, FFindCase.Checked);
  FMatchesStale := False;
  FMatchIndex := -1;
  n := Length(FMatches);
  ShowMatchCount;
  FFindPrev.Enabled := n > 0;
  FFindNext.Enabled := n > 0;
end;

{ The caret moves to the match and the match is SELECTED, through the same jump the
  diagnostics panel uses -- so a search result and a diagnostic land the same way. }
procedure TSpxMainForm.StepToMatch(Backwards: Boolean);
var idx: Integer; pos_: TPoint;
begin
  { The document may have changed since the list was built. }
  if FMatchesStale then RefreshMatches;
  if Length(FMatches) = 0 then Exit;

  if FMatchIndex < 0 then
  begin
    { The first step starts from the caret -- its LOGICAL column, converted to a code point,
      because that is the only one of the editor's three column notions that means the same
      thing as a position in this list. }
    pos_ := FEditor.LogicalCaretXY;
    idx := SpxStepMatch(FMatches, pos_.Y,
                        SpxCodePointColumn(LineOf(pos_.Y), pos_.X), Backwards);
  end
  else if Backwards then
  begin
    idx := FMatchIndex - 1;
    if idx < 0 then idx := High(FMatches);
  end
  else
  begin
    idx := FMatchIndex + 1;
    if idx > High(FMatches) then idx := 0;
  end;
  if idx < 0 then Exit;
  FMatchIndex := idx;
  JumpToPos(FMatches[idx].Line, FMatches[idx].Col,
            FMatches[idx].EndLine, FMatches[idx].EndCol);
  ShowMatchCount;
  { The focus stays in the box, so a second Enter steps again rather than typing into the
    document. }
  if FFindText.CanSetFocus then FFindText.SetFocus;
end;

procedure TSpxMainForm.FindTextChanged(Sender: TObject);
begin
  RefreshMatches;
end;

procedure TSpxMainForm.FindNextClicked(Sender: TObject);
begin
  { F3 from the editor, with the bar never opened: open it rather than doing nothing. }
  if not FFindText.Visible then
  begin
    ShowFindBar;
    Exit;
  end;
  StepToMatch(False);
end;

procedure TSpxMainForm.FindPrevClicked(Sender: TObject);
begin
  { Shift+F3 with the bar closed opens it, like F3 -- the pair should not behave differently
    depending on which half of it you press. }
  if not FFindText.Visible then
  begin
    ShowFindBar;
    Exit;
  end;
  StepToMatch(True);
end;

procedure TSpxMainForm.FindCloseClicked(Sender: TObject);
begin
  HideFindBar;
end;

procedure TSpxMainForm.FindMenuClicked(Sender: TObject);
begin
  ShowFindBar;
end;

procedure TSpxMainForm.FindKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN:
      begin
        StepToMatch(ssShift in Shift);
        Key := 0;
      end;
    VK_ESCAPE:
      begin
        HideFindBar;
        Key := 0;
      end;
  end;
end;

{ The strip of tools. Three of them today, all of them ACCESS: they raise the panel where the
  data fits rather than trying to hold a table in forty-four pixels. The group editor, whose
  content is a list and therefore does fit, will live in the rail itself. }
procedure TSpxMainForm.BuildRail;
begin
  FRail := TSpxToolRail.Create(Self);
  FRail.Parent := Self;
  FRail.AddTool(SPX_ICON_DIAG, Tr(sTabDiagnostics), @RailDiagClicked);
  FRail.AddTool(SPX_ICON_VARS, Tr(sTabVariables), @RailVarsClicked);
  FRail.AddTool(SPX_ICON_SET, Tr(sTabVariants), @RailSetClicked);
  { The one tool that is not access but WORKSPACE: a group's variants are a list, one short
    line each, which is exactly what fits beside the editor. }
  FRail.AddTool(SPX_ICON_GROUP, Tr(sTabGroup), @RailGroupClicked);
end;

procedure TSpxMainForm.RailGroupClicked(Sender: TObject);
begin
  FSlide.Visible := not FSlide.Visible;
  if FSlide.Visible then
  begin
    { It opens on whatever the caret is already in, rather than staying blank until the next
      keypress. }
    FSlide.ShowGroupAt(FEditor.Text, CaretOffset);
    FSlide.Retranslate;
  end;
end;

{ The caret's position as a byte offset into FEditor.Text. LogicalCaretXY, not CaretXY: the
  first is a byte column and the second is a PHYSICAL one, and a tab or a Cyrillic character
  makes them differ -- the editor-core positions are bytes throughout. }
function TSpxMainForm.CaretOffset: Integer;
var i, n: Integer; p: TPoint;
begin
  p := FEditor.LogicalCaretXY;
  Result := 1;
  n := FEditor.Lines.Count;
  for i := 0 to p.Y - 2 do
  begin
    if i >= n then Break;
    Inc(Result, Length(FEditor.Lines[i]) + Length(LineEnding));
  end;
  Inc(Result, p.X - 1);
end;

function TSpxMainForm.OffsetToPoint(AOffset: Integer): TPoint;
var i, at_, len: Integer;
begin
  at_ := 1;
  for i := 0 to FEditor.Lines.Count - 1 do
  begin
    len := Length(FEditor.Lines[i]) + Length(LineEnding);
    if AOffset < at_ + len then
    begin
      Result := Point(AOffset - at_ + 1, i + 1);
      Exit;
    end;
    Inc(at_, len);
  end;
  Result := Point(1, FEditor.Lines.Count);
end;

procedure TSpxMainForm.CaretSettled(Sender: TObject);
begin
  FCaretTimer.Enabled := False;
  if FSlide.Visible then FSlide.ShowGroupAt(FEditor.Text, CaretOffset);
end;

{ The panel asked for a span to be replaced. It goes through the EDITOR rather than through
  the document text, so the change joins the undo history and the caret survives it. }
procedure TSpxMainForm.GroupApplied(BodyStart, Stop: Integer; const Body: string);
begin
  FEditor.BeginUndoBlock;
  try
    FEditor.TextBetweenPoints[OffsetToPoint(BodyStart), OffsetToPoint(Stop)] := Body;
  finally
    FEditor.EndUndoBlock;
  end;
  FSlide.ShowGroupAt(FEditor.Text, CaretOffset);
end;

procedure TSpxMainForm.RailDiagClicked(Sender: TObject);
begin
  if FBottom.PageCount >= 1 then FBottom.PageIndex := 0;
end;

procedure TSpxMainForm.RailVarsClicked(Sender: TObject);
begin
  if FBottom.PageCount >= 2 then FBottom.PageIndex := 1;
end;

procedure TSpxMainForm.RailSetClicked(Sender: TObject);
begin
  if FBottom.PageCount >= 3 then FBottom.PageIndex := 2;
end;

{ One handler for fourteen items: which language it was is the item's Tag, set when the menu
  was built. Fourteen near-identical methods would be fourteen places to forget one. }
procedure TSpxMainForm.LangPicked(Sender: TObject);
begin
  if not (Sender is TMenuItem) then Exit;
  FLangFollow := False;
  FLangChosen := TSpxLang(TMenuItem(Sender).Tag);
  ApplyLangMode;
end;

procedure TSpxMainForm.LangFollowClicked(Sender: TObject);
begin
  FLangFollow := True;
  ApplyLangMode;
end;

{ Resolve the setting and, if that changed anything, say everything again. Called both when
  the setting changes and when the DOCUMENT's locale does -- the second only matters in
  follow mode, which is the point of having the mode at all. }
procedure TSpxMainForm.ApplyLangMode;
var want: TSpxLang;
begin
  if FLangFollow then want := SpxLangFor(FLocale.Text) else want := FLangChosen;
  if want <> SpxUiLang then
  begin
    SpxSetUiLang(want);
    RetranslateUi;
  end
  else
    BuildMenu;   { the tick still has to move }
end;

procedure TSpxMainForm.RailLeftClicked(Sender: TObject);
begin
  FRail.Side := spxRailLeft;
  BuildMenu;   { the tick moves with it }
end;

procedure TSpxMainForm.RailRightClicked(Sender: TObject);
begin
  FRail.Side := spxRailRight;
  BuildMenu;
end;

procedure TSpxMainForm.BuildMenu;

  function Item(AParent: TMenuItem; const ACaption: string; AKey: Word;
    AShift: TShiftState; AHandler: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(Self);
    Result.Caption := ACaption;
    if AKey <> 0 then Result.ShortCut := ShortCut(AKey, AShift);
    Result.OnClick := AHandler;
    AParent.Add(Result);
  end;

var
  bar: TMainMenu;              { not `menu`: TForm already has a Menu property }
  fileMenu, editMenu, viewMenu, langMenu, sideItem: TMenuItem;
  lang: TSpxLang;
begin
  { Rebuilt when the language changes, so the previous one is released first -- it is owned
    by the form and would otherwise pile up one menu per switch. }
  if Self.Menu <> nil then
  begin
    bar := TMainMenu(Self.Menu);
    Self.Menu := nil;
    bar.Free;
  end;
  bar := TMainMenu.Create(Self);
  EnsureFlags;
  bar.Images := FFlags;
  fileMenu := TMenuItem.Create(Self);
  fileMenu.Caption := Tr(sMenuFile);
  bar.Items.Add(fileMenu);

  Item(fileMenu, Tr(sMenuNew), Ord('N'), [ssCtrl], @NewClicked);
  Item(fileMenu, Tr(sMenuOpen), Ord('O'), [ssCtrl], @OpenClicked);
  Item(fileMenu, Tr(sMenuSave), Ord('S'), [ssCtrl], @SaveClicked);
  Item(fileMenu, Tr(sMenuSaveAs), Ord('S'), [ssCtrl, ssShift], @SaveAsClicked);
  Item(fileMenu, '-', 0, [], nil);
  { The set is read when the document is opened or saved, not on every keystroke. A fragment
    changed by another program is therefore invisible until this is used -- which is why the
    command exists rather than a silent rescan the user cannot ask for. }
  Item(fileMenu, Tr(sMenuReloadSet), 0, [], @ReloadSetClicked);
  Item(fileMenu, '-', 0, [], nil);
  Item(fileMenu, Tr(sMenuExit), 0, [], @ExitClicked);

  { Every key action gets a place in a menu, not only a shortcut: a hotkey nobody can find
    is a hotkey nobody uses. }
  editMenu := TMenuItem.Create(Self);
  editMenu.Caption := Tr(sMenuEdit);
  bar.Items.Add(editMenu);
  { A menu shortcut is checked BEFORE the key reaches the control, so one that collides with
    an editor command takes that command away silently. SynEdit's own Ctrl+Shift table is
    Y, Z, N, C, L, B; the two decisions here are recorded rather than stumbled into:
      * NOT Ctrl+Shift+B for the brace wrap -- that is ecMatchBracket, jump to the matching
        bracket, and taking it away in an editor for a bracket-heavy language would be
        actively wrong. Ctrl+Shift+G instead;
      * Ctrl+Shift+C IS taken, from ecColumnSelect. Copying the result is the everyday act
        here and the combination is what a user expects for it, while column select remains
        on Alt+drag and Alt+Shift+arrows. }
  { Ctrl+F and F3 are what the hand reaches for, and both are in the menu because a hotkey
    nobody can find is a hotkey nobody uses. F3 works from the editor as well as from the
    box, so stepping does not require going back to the field. }
  Item(editMenu, Tr(sMenuFind), Ord('F'), [ssCtrl], @FindMenuClicked);
  Item(editMenu, Tr(sMenuFindNext), VK_F3, [], @FindNextClicked);
  Item(editMenu, Tr(sMenuFindPrev), VK_F3, [ssShift], @FindPrevClicked);
  Item(editMenu, '-', 0, [], nil);
  Item(editMenu, Tr(sMenuWrapBraces), Ord('G'), [ssCtrl, ssShift], @WrapBracesClicked);
  Item(editMenu, Tr(sMenuWrapBrackets), Ord('P'), [ssCtrl, ssShift], @WrapBracketsClicked);
  Item(editMenu, '-', 0, [], nil);
  Item(editMenu, Tr(sMenuReroll), Ord('R'), [ssCtrl], @RerollClicked);
  Item(editMenu, Tr(sMenuCopyResult), Ord('C'), [ssCtrl, ssShift], @CopyClicked);

  { Which edge the tools live on. A setting rather than a decision of ours: the rail belongs
    beside what it edits, and which side of the screen that is depends on the person. It sits
    in a menu until the app has somewhere to remember settings -- the layout asks the rail for
    its side either way, so persistence will be one line. }
  viewMenu := TMenuItem.Create(Self);
  viewMenu.Caption := Tr(sMenuView);
  bar.Items.Add(viewMenu);
  sideItem := Item(viewMenu, Tr(sRailLeft), 0, [], @RailLeftClicked);
  sideItem.RadioItem := True;
  sideItem.Checked := (FRail = nil) or (FRail.Side = spxRailLeft);
  sideItem := Item(viewMenu, Tr(sRailRight), 0, [], @RailRightClicked);
  sideItem.RadioItem := True;
  sideItem.Checked := (FRail <> nil) and (FRail.Side = spxRailRight);
  { The rail's own buttons are TSpeedButtons, and a speed button is a TGraphicControl: no
    handle, so no tab stop and nothing for a screen reader to name. The three panel tools are
    still reachable -- they raise pages of a TPageControl, whose tabs take the keyboard -- but
    the group editor had no other way in at all once the faces became icons. It has one here. }
  Item(viewMenu, '-', 0, [], nil);
  Item(viewMenu, Tr(sTabGroup), 0, [], @RailGroupClicked);

  { The interface's language, and whether it follows the document's. Three radio items in
    their own submenu rather than a checkbox, because "follow" is a third state and not the
    absence of the other two. }
  Item(viewMenu, '-', 0, [], nil);
  langMenu := TMenuItem.Create(Self);
  langMenu.Caption := Tr(sMenuLanguage);
  viewMenu.Add(langMenu);
  for lang := Low(TSpxLang) to High(TSpxLang) do
  begin
    sideItem := Item(langMenu, SpxLangName(lang), 0, [], @LangPicked);
    sideItem.Tag := Ord(lang);
    { The flag is the same index as the language, by the sprite's contract. It is a country
      standing in for a language and the two are not the same thing -- which is why the
      ENDONYM is the caption and the flag only helps the eye find it. }
    sideItem.ImageIndex := Ord(lang);
    sideItem.RadioItem := True;
    sideItem.Checked := (not FLangFollow) and (FLangChosen = lang);
  end;
  Item(langMenu, '-', 0, [], nil);
  sideItem := Item(langMenu, Tr(sLangFollow), 0, [], @LangFollowClicked);
  sideItem.RadioItem := True;
  sideItem.Checked := FLangFollow;

  Self.Menu := bar;
end;

{ The menu's flags, at the size this display wants. Called before the menu is built and again
  whenever the scaling changes: a form is constructed at 96 dpi and only told the monitor's
  afterwards, so the first size is the 100% one wherever it runs. The list object is REUSED --
  the menu items hold a reference to it. }
procedure TSpxMainForm.EnsureFlags;
var w, h, len: Integer; data: Pointer;
begin
  { A Windows menu draws its images 16 px wide at 100%; the strip is chosen for that, and the
    cells are wider than they are tall because a flag is. }
  SpxFlagPickSize(Px(Self, 16), w, h);
  if (FFlags <> nil) and (FFlags.Width = w) then Exit;
  data := SpxFlagStrip(w, len);
  FFlags := SpxImagesFrom(Self, FFlags, data, len, w, h, SPX_FLAG_COUNT);
end;

procedure TSpxMainForm.AutoAdjustLayout(AMode: TLayoutAdjustmentPolicy;
  const AFromPPI, AToPPI, AOldFormWidth, ANewFormWidth: Integer);
begin
  inherited AutoAdjustLayout(AMode, AFromPPI, AToPPI, AOldFormWidth, ANewFormWidth);
  EnsureFlags;
  if FRail <> nil then FRail.Rescale;
end;

procedure TSpxMainForm.DiagColumn(const ACaption: string; AWidth: Integer);
var col: TListColumn;
begin
  col := FDiag.Columns.Add;
  col.Caption := ACaption;
  col.Width := AWidth;
end;

procedure TSpxMainForm.ShowRows(const ARows: TSpxPanelRows);
var
  i: Integer;
  sig, place, level, name_: string;
  it: TListItem;
begin
  { Rebuilding the list on every debounce tick would take the selection out from under a
    user who is reading it, so the same findings leave it alone.

    The signature carries the TEXT and the whole span, not just the code and the start. An
    earlier version left the text out, reasoning that it follows from the code -- true for an
    engine diagnostic, false for a Studio note, whose code is fixed while its wording carries
    the target: `#include "Frag"` and `#include "Othr"` produce the same code at the same
    place with different words, and the panel went on naming the file the user had already
    stopped typing. The span is in for the same reason: a click selects it. }
  sig := '';
  for i := 0 to High(ARows) do
    sig := sig + ARows[i].Slug + '|' + ARows[i].Code + '|' + IntToStr(ARows[i].Line) + '|' +
           IntToStr(ARows[i].Column) + '|' + IntToStr(ARows[i].EndLine) + '|' +
           IntToStr(ARows[i].EndColumn) + '|' + ARows[i].Text + #10;
  if sig = FRowSig then Exit;
  FRowSig := sig;
  FRows := ARows;

  FDiag.Items.BeginUpdate;
  try
    FDiag.Items.Clear;
    for i := 0 to High(ARows) do
    begin
      if ARows[i].Source = spxRowStudio then level := Tr(sLevelNote)
      else if ARows[i].Severity = 'error' then level := Tr(sLevelError)
      else if ARows[i].Severity = 'warning' then level := Tr(sLevelWarning)
      else level := ARows[i].Severity;

      if ARows[i].Slug = '' then name_ := Tr(sDocument) else name_ := ARows[i].Slug;
      { No place means no jump, and the dash says so rather than showing a 0:0 that looks
        like a position. }
      if ARows[i].Line > 0 then place := Format('%d:%d', [ARows[i].Line, ARows[i].Column])
      else place := '—';

      it := FDiag.Items.Add;
      it.Caption := level;
      it.SubItems.Add(name_);
      it.SubItems.Add(place);
      it.SubItems.Add(ARows[i].Text);
    end;
  finally
    FDiag.Items.EndUpdate;
  end;
end;

{ The message column takes what the fixed ones leave, which is the only width that is right
  at more than one window size: narrower and the text a user reads is behind a horizontal
  scrollbar, wider and the list ends in a dead strip. }
procedure TSpxMainForm.DiagResized(Sender: TObject);
var used, i, last, room: Integer;
begin
  last := FDiag.Columns.Count - 1;
  if last < 1 then Exit;
  used := 0;
  for i := 0 to last - 1 do used := used + FDiag.Columns[i].Width;
  room := FDiag.ClientWidth - used - 4;   { a hair for the frame }
  if room < Px(Self, 160) then room := Px(Self, 160);
  FDiag.Columns[last].Width := room;
end;

procedure TSpxMainForm.DiagClicked(Sender: TObject);
begin
  if FDiag.Selected = nil then Exit;
  if (FDiag.Selected.Index < 0) or (FDiag.Selected.Index > High(FRows)) then Exit;
  { Deferred out of the click rather than run inside it. Everything the jump may do pumps the
    message loop -- the save prompt, a file dialog -- and while it pumps, a delivered result
    rebuilds this list, freeing the very TListItem whose click LCL is still processing. The
    row is copied into a field first, for the same reason JumpTo takes it by value. }
  FPendingRow := FRows[FDiag.Selected.Index];
  Application.QueueAsyncCall(@JumpDeferred, 0);
end;

procedure TSpxMainForm.JumpDeferred(Data: PtrInt);
begin
  JumpTo(FPendingRow);
end;

{ A row is a jump only when the engine gave it a place: `Line = 0` means it could not, and
  putting the caret somewhere plausible would be the invention this project keeps refusing.
  A finding in ANOTHER file opens that file -- through the same unsaved-changes guard as the
  menu, because it is the same act -- and that is possible only when the document has a
  folder, which is the same condition that gave it a set at all.

  BY VALUE, not `const`. A const record parameter is a REFERENCE into the caller's array,
  and everything below can pump the message loop: MessageDlg from AskSave, the file dialogs,
  LoadDocument. While that loop runs, the worker's Synchronize delivers a result, JobDone
  reaches ShowRows, and `FRows := ARows` releases the array this row lived in -- after which
  the reads below are reads of freed memory. The copy costs two string refcounts. }
procedure TSpxMainForm.JumpTo(Row: TSpxPanelRow);
var target: string;
begin
  if Row.Line <= 0 then Exit;
  if (Row.Slug <> '') and (Row.Slug <> SpxSlugOf(FPath)) then
  begin
    if FPath = '' then Exit;
    target := ExtractFilePath(FPath) + Row.Slug + SPX_EXT;
    if not FileExists(target) then Exit;
    if not AskSave then Exit;
    LoadDocument(target);
  end;
  JumpToPos(Row.Line, Row.Column, Row.EndLine, Row.EndColumn);
end;

{ The caret, and a selection when there is a span. Shared by the diagnostics panel and the
  variables panel, because "go where the engine said" is one act with one conversion in it:
  code points to bytes, since SynEdit's logical coordinates are byte offsets while the
  engine counts characters. }
procedure TSpxMainForm.JumpToPos(Line, Column, EndLine, EndColumn: Integer);
var col: Integer;
begin
  if Line <= 0 then Exit;
  col := SpxByteColumn(LineOf(Line), Column);
  FJumping := True;
  try
    FEditor.LogicalCaretXY := Point(col, Line);
    FJump.Valid := False;
    if (EndLine >= Line) and (EndColumn > 0) then
    begin
      FEditor.BlockBegin := Point(col, Line);
      FEditor.BlockEnd := Point(SpxByteColumn(LineOf(EndLine), EndColumn), EndLine);
      { Recorded AFTER the block is set, so the selection event that assignment fires sees
        the state still invalid and cannot clear what has not been written yet. }
      FJump.Range := CurrentSelection(False).Range;
      FJump.Valid := True;
    end;
  finally
    FJumping := False;
  end;
  { Once, with the state true. A jump that lands where the preview already is asks for
    nothing; a jump out of a fragment asks for the document back, and that one renders. }
  PreviewFollowSelection;
  FEditor.EnsureCursorPosVisible;
  FEditor.SetFocus;
end;

{ A definition row has a place but no span -- the engine reports where the directive starts,
  and its own column convention puts that at the line's beginning. }
procedure TSpxMainForm.VarJump(Line, Column: Integer);
begin
  JumpToPos(Line, Column, 0, 0);
end;

{ A selection is a setting like the locale or the seed: it changes what the preview shows.
  Through the debounce, because dragging a selection fires this continuously. }
{ What a selection change means for the preview, in one place: the jump path and the editor
  path must not disagree about it. }
procedure TSpxMainForm.PreviewFollowSelection;
var ask: TSpxPreviewAsk;
begin
  { What this selection would ask the preview for, computed BEFORE the state is updated so
    that both use the same input. }
  ask := SpxPreviewAsk(CurrentSelection(False), FJump);

  { The policy decides whether a jump's selection is still the jump's; here only the STATE
    it returns is kept. Without this call the flag outlives its meaning -- after the user
    moves away and later selects the same span by hand, that manual selection would still be
    treated as the jump's -- and this is the moment that sees the difference, which a single
    look at render time cannot. The selected TEXT is not fetched: dragging fires this
    continuously and copying a large selection each time would be paid for nothing. }
  SpxPreviewFragment(CurrentSelection(False), FJump, FJump);

  { Nothing about the preview would change, so nothing is re-rendered. This is the whole
    difference between stepping through search hits smoothly and re-rendering the document
    under the user on every press of Enter. }
  if SpxPreviewSame(ask, FShownAsk) then Exit;

  FDebounce.Enabled := False;
  FDebounce.Enabled := True;
end;

procedure TSpxMainForm.SelectionChanged(Sender: TObject; Changes: TSynStatusChanges);
begin
  { ONE handler, two jobs. SynEdit has a single OnStatusChange, and giving the group editor
    its own assignment silently took this one away -- the fragment preview stopped following
    the selection and nothing said so. Whatever is added here next goes in the same way. }
  if FSlide.Visible and (Changes * [scCaretX, scCaretY] <> []) then
  begin
    { Restarted on every move, so a run of arrow keys costs one lookup rather than twenty. }
    FCaretTimer.Enabled := False;
    FCaretTimer.Enabled := True;
  end;

  if not (scSelection in Changes) then Exit;
  { A jump is mid-assignment: its own event comes at the end, with the state written. }
  if FJumping then Exit;
  { Loading a document reports scTextCleared -- which is a SET, not a flag, and carries
    scSelection inside it -- and that path has already asked for its own render. }
  if scTextCleared <= Changes then Exit;
  PreviewFollowSelection;
end;

{ SynEdit's selection in editor-core's own terms. WithText is False on the paths that only
  need the shape: SelText copies the selected text, which on a large selection is a real
  cost to pay on every drag event. }
function TSpxMainForm.CurrentSelection(WithText: Boolean): TSpxSelection;
begin
  Result.Kind := spxSelNone;
  Result.Range := SpxRange(SpxPos(0, 0), SpxPos(0, 0));
  Result.Text := '';
  if not FEditor.SelAvail then Exit;
  case FEditor.SelectionMode of
    smColumn: Result.Kind := spxSelColumn;
    smLine: Result.Kind := spxSelLine;
  else
    Result.Kind := spxSelNormal;
  end;
  Result.Range := SpxRange(SpxPos(FEditor.BlockBegin.Y, FEditor.BlockBegin.X),
                           SpxPos(FEditor.BlockEnd.Y, FEditor.BlockEnd.X));
  if WithText then Result.Text := FEditor.SelText;
end;

{ Through SelText, which is SynEdit's own edit path: ONE undo step, verified. Building a new
  document string and assigning it would throw the undo history away.

  NORMAL selections only. In column mode SelText returns the rows joined and SetSelText pastes
  them back column-wise, so the opener lands on the first row and the closer on the last --
  wrapping three columns of `AB`/`CD`/`EF` produces a group that swallows the text on either
  side of them, which the user never selected. A line selection has the same shape one line
  down. Measured; refused rather than half-handled.

  And the block is restored afterwards, because SetSelText clears it: without this the
  preview un-narrows the moment you wrap, and a second wrap -- brackets around what you just
  put in braces -- is a silent no-op. }
procedure TSpxMainForm.WrapSelection(const L, R: string);
var after: TSpxRange;
begin
  { Whether this selection may be wrapped, and where the wrapped text will end up, is
    arithmetic -- so it lives in editor-core with checks on it. What stays here is the edit
    itself, because SelText IS SynEdit's edit API and that is what keeps undo to one step. }
  if not SpxWrapRange(CurrentSelection(False), Length(L), Length(R), after) then Exit;
  FEditor.SelText := L + FEditor.SelText + R;
  FEditor.BlockBegin := Point(after.A.Col, after.A.Line);
  FEditor.BlockEnd := Point(after.B.Col, after.B.Line);
end;

procedure TSpxMainForm.WrapBracesClicked(Sender: TObject);
begin
  WrapSelection('{', '}');
end;

procedure TSpxMainForm.WrapBracketsClicked(Sender: TObject);
begin
  WrapSelection('[', ']');
end;

procedure TSpxMainForm.RuntimeChanged(Sender: TObject);
begin
  { Through the debounce, not straight to a render: the grid reports every CHARACTER typed
    into a value, and a session value is part of the validation cache's key -- so each one
    would re-validate every file in the closure, which is the exact cost the cache exists to
    remove. }
  FDebounce.Enabled := False;
  FDebounce.Enabled := True;
end;

function TSpxMainForm.LineOf(N: Integer): string;
begin
  if (N >= 1) and (N <= FEditor.Lines.Count) then Result := FEditor.Lines[N - 1]
  else Result := '';
end;

procedure TSpxMainForm.UpdateCaption;
var shown: string;
begin
  if FPath = '' then shown := Tr(sUntitled) else shown := ExtractFileName(FPath);
  if FEditor.Modified then shown := shown + ' *';
  Caption := Format(Tr(sWindowTitle), [shown]);
end;

{ What goes into the file: the buffer with the document's OWN line ending restored, and
  without the terminator TStrings adds to a last line that never had one. Both halves matter
  for the same reason -- these files live in the user's git, and an editor that rewrites
  bytes nobody touched turns a one-word change into a whole-file diff. }
function TSpxMainForm.DocText: string;
var tail: Integer;
begin
  Result := SpxNormalizeEol(FEditor.Text, FEol);
  if FTrailingEol then Exit;
  tail := Length(Result) - Length(FEol) + 1;
  if (tail >= 1) and (Copy(Result, tail, Length(FEol)) = FEol) then
    Delete(Result, tail, Length(FEol));
end;

procedure TSpxMainForm.LoadDocument(const APath: string);
var s: string;
begin
  StopBatchForDocument;
  s := SpxReadTextFile(APath);
  FPath := APath;
  FEol := SpxDetectEol(s);
  FTrailingEol := SpxEndsWithEol(s);
  FEditor.Text := s;
  FEditor.Modified := False;
  FEditor.CaretXY := Point(1, 1);
  FReloadSet := True;
  UpdateCaption;
  RequestRender;
end;

function TSpxMainForm.SaveDocument(AsNew: Boolean): Boolean;
var dlg: TSaveDialog;
begin
  Result := False;
  if AsNew or (FPath = '') then
  begin
    dlg := TSaveDialog.Create(Self);
    try
      dlg.Title := Tr(sSaveTemplate);
      dlg.Filter := Format(Tr(sFileFilter), [SPX_EXT]);
      dlg.DefaultExt := Copy(SPX_EXT, 2, MaxInt);
      dlg.Options := dlg.Options + [ofOverwritePrompt];
      if FPath <> '' then dlg.FileName := FPath;
      if not dlg.Execute then Exit;
      FPath := dlg.FileName;
    finally
      dlg.Free;
    end;
  end;
  SpxWriteTextFile(FPath, DocText);
  FEditor.Modified := False;
  { Saved: the folder may now hold a file it did not before, and this document's own saved
    copy has just changed under whatever else includes it. }
  FReloadSet := True;
  UpdateCaption;
  RequestRender;
  Result := True;
end;

function TSpxMainForm.AskSave: Boolean;
begin
  Result := True;
  if not FEditor.Modified then Exit;
  case MessageDlg(Tr(sUnsavedTitle), Tr(sUnsavedQuestion), mtConfirmation,
                  [mbYes, mbNo, mbCancel], 0) of
    mrYes: Result := SaveDocument(False);
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

procedure TSpxMainForm.NewClicked(Sender: TObject);
begin
  if not AskSave then Exit;
  StopBatchForDocument;
  FPath := '';
  FEol := SPX_DEFAULT_EOL;
  FTrailingEol := True;
  FEditor.Text := '';
  FEditor.Modified := False;
  FReloadSet := True;
  UpdateCaption;
  RequestRender;
end;

procedure TSpxMainForm.OpenClicked(Sender: TObject);
var dlg: TOpenDialog;
begin
  if not AskSave then Exit;
  dlg := TOpenDialog.Create(Self);
  try
    dlg.Title := Tr(sOpenTemplate);
    dlg.Filter := Format(Tr(sFileFilter), [SPX_EXT]);
    dlg.Options := dlg.Options + [ofFileMustExist];
    if dlg.Execute then LoadDocument(dlg.FileName);
  finally
    dlg.Free;
  end;
end;

procedure TSpxMainForm.SaveClicked(Sender: TObject);
begin
  SaveDocument(False);
end;

procedure TSpxMainForm.SaveAsClicked(Sender: TObject);
begin
  SaveDocument(True);
end;

procedure TSpxMainForm.ReloadSetClicked(Sender: TObject);
begin
  StopBatchForDocument;
  FReloadSet := True;
  RequestRender;
end;

procedure TSpxMainForm.ExitClicked(Sender: TObject);
begin
  Close;
end;

procedure TSpxMainForm.FormAsked(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := AskSave;
end;

procedure TSpxMainForm.EditorChanged(Sender: TObject);
begin
  { Restart the window on every keystroke: the render that matters is the one after the
    user stops. }
  FDebounce.Enabled := False;
  FDebounce.Enabled := True;
  UpdateCaption;
  { The find list describes the text as it was. Marked rather than rebuilt here: this runs on
    every keystroke. }
  if (FFindText <> nil) and FFindText.Visible then FMatchesStale := True;
  { A generated set belongs to the text that produced it. Editing does not throw it away --
    its seeds still name those texts, and the author may be exporting it -- but it stops
    being a set of THIS document, and the panel says so. }
  if FSet <> nil then FSet.MarkStale;
end;

{ Every caption that was read at build time, read again. Kept as one list on purpose: a
  translation that stops following the language does so silently, and the only defence is
  having one place where the whole window is re-read. }
procedure TSpxMainForm.RetranslateUi;
begin
  { Same guard, and for the same reason, as LayoutTopStrip: three startup crashes in this
    project have been a handler firing while the window was still being built. The locale box
    is created before its OnChange is hooked, so this is not reachable today -- and that is
    exactly the kind of ordering that a later edit breaks silently. }
  if (FSeeded = nil) or (FBottom = nil) or (FDiag = nil) or (FVars = nil) or
     (FSet = nil) or (FPreview = nil) then Exit;
  FSeeded.Caption := Tr(sSeed);
  FReroll.Caption := Tr(sReroll);
  FCopy.Caption := Tr(sCopy);
  FAsPage.Caption := Tr(sViewPage);
  FAsSource.Caption := Tr(sViewSource);
  FFindCase.Caption := Tr(sFindCase);
  FFindClose.Caption := Tr(sFindClose);
  BuildMenu;
  if FBottom.PageCount >= 3 then
  begin
    FBottom.Pages[0].Caption := Tr(sTabDiagnostics);
    FBottom.Pages[1].Caption := Tr(sTabVariables);
    FBottom.Pages[2].Caption := Tr(sTabVariants);
  end;
  if FDiag.Columns.Count >= 4 then
  begin
    FDiag.Columns[0].Caption := Tr(sColLevel);
    FDiag.Columns[1].Caption := Tr(sColFile);
    FDiag.Columns[2].Caption := Tr(sColAt);
    FDiag.Columns[3].Caption := Tr(sColMessage);
  end;
  FVars.Retranslate;
  FSet.Retranslate;
  FPreview.Retranslate;
  { A rail button says its name in a hint and wears a letter until icons arrive; both are
    translated text. }
  if FRail <> nil then
  begin
    { The faces are icons, so a language changes the tooltip and nothing else. }
    FRail.SetTool(0, Tr(sTabDiagnostics));
    FRail.SetTool(1, Tr(sTabVariables));
    FRail.SetTool(2, Tr(sTabVariants));
    FRail.SetTool(3, Tr(sTabGroup));
  end;
  FSlide.Retranslate;
  { The rows carry their words from the worker, and their first two columns are written here
    -- so the level and the file name change language at once. The MESSAGE column does not:
    it was worded by the render that produced it, and it stays in the old language until the
    next one lands (SettingChanged asks for one immediately, so it is a render, not a
    session). The signature is cleared because it is what suppresses a rebuild. }
  FRowSig := '';
  ShowRows(FRows);
  { The counter is a sentence too ('matches: 12'), and it is only rewritten when the search
    runs. Nothing to recount -- the matches stand -- so just repaint the caption. }
  if (FFindText <> nil) and FFindText.Visible then ShowMatchCount;
  LayoutTopStrip;
  UpdateCaption;
end;

procedure TSpxMainForm.SettingChanged(Sender: TObject);
begin
  { The number belongs to the tick beside it. }
  if (FSeedEdit <> nil) and (FSeedEdit.Visible <> FSeeded.Checked) then
  begin
    FSeedEdit.Visible := FSeeded.Checked;
    LayoutTopStrip;
  end;
  { The document's locale changed. Whether the INTERFACE follows it is the user's setting,
    and by default it does not: an editor that changes language because the text did was a
    surprise every time this box was touched. }
  if FLangFollow then ApplyLangMode;
  RequestRender;
end;

procedure TSpxMainForm.DebounceFired(Sender: TObject);
begin
  { Same tick as the render: the counter follows the document without paying per keystroke. }
  if (FFindText <> nil) and FFindText.Visible and FMatchesStale then RefreshMatches;
  FDebounce.Enabled := False;
  RequestRender;
end;

procedure TSpxMainForm.RerollClicked(Sender: TObject);
begin
  { A reroll in seeded mode would return the same text, so it draws fresh instead -- the
    button means "show me another one". }
  FSeeded.Checked := False;
  RequestRender;
end;

procedure TSpxMainForm.CopyClicked(Sender: TObject);
begin
  { The output itself, whichever view is on screen: Copy means "give me what the engine
    produced", not "give me what this widget happens to show". }
  Clipboard.AsText := FPreview.Content;
end;

procedure TSpxMainForm.RequestRender;
var job: TSpxJob;
begin
  Inc(FNextId);
  job.Id := FNextId;
  { DocText, not FEditor.Text: SynEdit joins its lines with the PLATFORM's ending, so on
    Windows the engine was handed a CRLF copy of a file that is LF on disk -- and the two do
    not render the same. A directive line ending in CRLF leaves its LF behind, one blank line
    per directive: measured on a real 116 KB template with a hundred and fifty `#set`s, one
    blank line as the file is, thirty-five once normalised to CRLF, and the source view then
    opens on a screenful of nothing. The preview must show what the FILE produces. }
  job.Text := DocText;
  job.UiLang := SpxUiLang;
  job.Locale := FLocale.Text;
  job.Seeded := FSeeded.Checked;
  job.Seed := LongWord(StrToInt64Def(FSeedEdit.Text, 1));
  { The folder, not the set: the worker owns the map it builds from this. An unsaved
    document has neither, which leaves every `#include` verbatim -- what the engine does
    without a resolver, and what the other engines would do with a file that is not there.
    DocSlug keeps the closure walk from validating this same buffer a second time through
    its saved copy on disk. }
  if FPath = '' then
  begin
    job.SetFolder := '';
    job.DocSlug := '';
  end
  else
  begin
    job.SetFolder := ExtractFilePath(FPath);
    job.DocSlug := SpxSlugOf(FPath);
  end;
  job.ReloadSet := FReloadSet;
  FReloadSet := False;
  job.Vars := FVars.RuntimeValues;
  { A selection previews on its own -- in the document's scope, which is editor-core's job,
    not ours. WHICH selections count is also editor-core's, and gated there: none at all and
    the one a jump made to show a finding do not. Whether the fragment is worth rendering
    (whitespace is not) is the worker's, gated in its turn. }
  { Recorded before the call updates the state, so a later selection change compares like
    with like. }
  FShownAsk := SpxPreviewAsk(CurrentSelection(False), FJump);
  job.Fragment := SpxPreviewFragment(CurrentSelection(True), FJump, FJump);
  FEngine.Post(job);
end;

procedure TSpxMainForm.StartBatch(Count: Integer; SeedBase: LongWord;
  const Opts: TSpxDedupeOpts);
var req: TSpxBatchRequest;
begin
  Inc(FNextId);
  req := Default(TSpxBatchRequest);
  req.Id := FNextId;
  { The same document the preview renders, for the same reason -- an export whose line
    endings differ from the file's is an export of a different template. }
  req.Text := DocText;
  req.Locale := FLocale.Text;
  { The same context the preview renders in, minus the preview's own seed: a batch derives
    its seeds from the base the panel gives it. The set folder and the slug come along so
    `#include` resolves for a batch exactly as it does for a render -- an export that
    disagreed with the pane above it about a fragment would be worse than useless. }
  if FPath = '' then
  begin
    req.SetFolder := '';
    req.DocSlug := '';
  end
  else
  begin
    req.SetFolder := ExtractFilePath(FPath);
    req.DocSlug := SpxSlugOf(FPath);
  end;
  req.Vars := FVars.RuntimeValues;
  req.Count := Count;
  req.SeedBase := SeedBase;
  req.Opts := Opts;
  FEngine.StartBatch(req);
end;

procedure TSpxMainForm.PreviewModeChanged(Sender: TObject);
begin
  FPreview.SourceMode := FAsSource.Checked;
end;

{ A selection CAN render to nothing -- a directive-only line, or one that opens a comment --
  and the two empty panes look identical, so the pane says which of them this is. The test
  for "nothing" is editor-core's (SpxIsBlankOutput), because "blank" is more than ASCII
  space: the engine's own line model counts U+2028 and U+2029 too. }
procedure TSpxMainForm.SayPartial(const AHtml: string; APartial: Boolean);
begin
  FPartial.Visible := APartial;
  if not APartial then Exit;
  if SpxIsBlankOutput(AHtml) then
    FPartial.Caption := Tr(sFragmentEmpty)
  else
    FPartial.Caption := Tr(sFragmentShown);
  LayoutTopStrip;   { the caption changes width, so the whole chain shifts with it }
end;

procedure TSpxMainForm.CancelBatch(Sender: TObject);
begin
  FEngine.CancelBatch;
end;

{ A batch belongs to ONE state of the document and of the folder beside it. Replacing either
  half-way through would leave a set whose first rows resolved their `#include`s against the
  old fragments and the rest against the new -- one file, two documents, and seeds that no
  longer reproduce the early rows. So the run is stopped, and the panel says it was. }
procedure TSpxMainForm.StopBatchForDocument;
begin
  if (FEngine <> nil) and FEngine.BatchInProgress then FEngine.CancelBatch;
end;

procedure TSpxMainForm.BatchProgress(const P: TSpxBatchProgress);
begin
  FSet.BatchProgress(P);
end;

{ A row from the set, shown in the right pane. It is a finished text, not a template, so it
  goes to the pane as it is -- the preview's own render path would spin it again and show
  something else. }
procedure TSpxMainForm.ShowVariant(const AText: string);
begin
  FPreview.SetContent(AText);
  SayPartial(AText, False);
end;

procedure TSpxMainForm.JobDone(const Res: TSpxJobResult);
var s: string;
begin
  { One worker renders one job at a time and delivers in the order it ran them, so an OLDER
    answer cannot arrive after a newer one. This comparison is that invariant written down,
    not a policy -- if a second worker ever appears, it starts earning its keep.

    The policy question it resembles has a different answer, on purpose. When job 5 was
    already rendering as job 6 arrived, job 5's result IS delivered and IS shown, even though
    the editor has moved on: a preview that lags one edit behind is worth more than one that
    freezes for as long as the user keeps typing on a big document. What keeps that lag to a
    single render instead of a queue is the worker dropping SUPERSEDED jobs before running
    them (SpxEngineThread), which the suite checks. }
  if Res.Id < FLastShown then Exit;
  FLastShown := Res.Id;

  FPreview.SetContent(Res.Preview);
  SayPartial(Res.Preview, Res.Partial);
  ShowRows(Res.Rows);
  FVars.SetModel(Res.Vars);
  FErrorMarkup.SetMarks(Res.Marks);
  FWarnMarkup.SetMarks(Res.Marks);
  FEditor.Invalidate;

  if Res.Errors > 0 then s := Format(Tr(sStatusErrors), [Res.Errors])
  else if Res.Warnings > 0 then s := Format(Tr(sStatusWithWarnings), [Res.Warnings])
  else s := Tr(sStatusValid);
  if Res.Notes > 0 then s := s + Format(Tr(sStatusNotes), [Res.Notes]);
  FStatus.SimpleText := Format(Tr(sStatusElapsed), [s, Res.Elapsed]);
end;

{ Idempotent on purpose. Closing the MAIN form neither hides nor frees it -- LCL only calls
  Application.Terminate (customform.inc:2148-2175) -- so the window stays on screen while
  this runs, and the widgetset keeps draining the message queue without checking Terminated
  inside the drain. A second click on the X, which is exactly what a user does when the
  first close sits inside WaitFor for the length of an in-flight render, delivers a second
  WM_CLOSE into this handler. Unguarded it called Shutdown on a nil FEngine; the fault was
  then swallowed, because ShowException stays quiet once Terminated. Found by review. }
procedure TSpxMainForm.StopEngine;
begin
  if FEngine = nil then Exit;
  FEngine.Shutdown;
  FEngine.WaitFor;
  FreeAndNil(FEngine);
end;

procedure TSpxMainForm.FormClosed(Sender: TObject; var CloseAction: TCloseAction);
begin
  FDebounce.Enabled := False;
  StopEngine;
end;

destructor TSpxMainForm.Destroy;
begin
  { A jump queued from the panel and not yet run would fire into a freed form. }
  Application.RemoveAsyncCalls(Self);
  { The worker is a thread, not an owned component, so nothing would free it on a path that
    reaches the destructor without OnClose. No such path exists today -- this is the form
    owning what it created rather than trusting one event to fire. }
  StopEngine;
  inherited Destroy;
end;

end.
