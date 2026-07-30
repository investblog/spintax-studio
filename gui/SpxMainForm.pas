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
  { FIRST, and deliberately: a unit later in this list wins a name clash, and Windows brings
    its own TRect and TBitmap. Named after the LCL it would have quietly replaced TBitmap with
    a record and TRect with the one StdCtrls' own event type does not use -- both of which the
    compiler reported, neither of which reads like the cause. It is here only for
    CB_SETDROPPEDWIDTH. }
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Menus, Dialogs, ImgList,
  Buttons,
  Clipbrd, Graphics, LCLType, LCLIntf,
  SynEdit, SynEditTypes, SynEditWrappedView, SynEditMarkup, SynEditMarkupBracket,
  SpxStudio, SpxTokens, SpxEngineThread, SpxSynHighlighter, SpxBracketMarkup, SpxDiagMarkup,
  SpxToolRail, SpxGroupPane, SpxGroups, SpxIcons, SpxFlags, SpxSegmented,
  SpxSettings, SpxTheme, SpxEditorFont,
  SpxPreviewPane, SpxVarsPane, SpxVariantsPane, SpxDedupe, SpxFiles, SpxDemo, SpxUi,
  SpxStrIds, SpxStrings;

type
  TSpxMainForm = class(TForm)
  private
    FTop: TPanel;
    FLocale: TComboBox;
    FSeeded: TCheckBox;
    FSeedEdit: TEdit;
    { Icon buttons, not captioned ones: the strip is finite and these two are the actions a
      person repeats. The caption they used to carry is their tooltip now, so a translation
      still has somewhere to land. }
    FReroll: TSpeedButton;
    FCopy: TSpeedButton;
    { The preview's own controls, in the WINDOW's strip rather than in a strip of the pane's
      own: two panes side by side should start on the same line, and a header inside one of
      them puts its content a row lower than the other. Anchored right, so they stay in the
      corner when the window is resized. }
    { One switch with two positions, rather than two radios that happen to be linked: a view
      mode IS one setting. It measures its own captions, so no language can clip them. }
    FModes: TSpxSegmented;
    { 16px icons for the top strip -- the rail's list is 24 and a list draws at its own size. }
    FSmallIcons: TImageList;
    FPartial: TLabel;
    FSplit: TSplitter;
    FSlideSplit: TSplitter;
    { The tools' strip. It is the window's, not the editor's pane's: a user who moves it to
      the right expects it at the window's edge, the way every side bar behaves. }
    FRail: TSpxToolRail;
    { The interface's language is the USER'S setting: a language of its own, or the
      document's if the user asks for that. Tying it to the document was a surprise every
      time the locale box was touched, so the tie is a choice and the default is the
      machine's language. }
    FLangChosen: TSpxLang;
    FLangFollow: Boolean;
    { What the last launch left behind, and what this one will leave. Held whole rather than
      as loose fields so that saving is one capture and not seven places to forget. }
    FPrefs: TSpxPrefs;
    { Guards the save while the window is still being assembled: every Apply below moves a
      control and would otherwise write the file once per control, with half the state. }
    FLoading: Boolean;
    { A double click on the splitter was seen and is waiting for the drag it started to end. }
    FSplitEven: Boolean;
    { What the last font choice was made from, so typing does not re-probe eight families. }
    FFontSample: string;
    FFontManual: string;
    FFontChosen: string;
    { The room each clamp last saw. A clamp must act when the WINDOW changed size and stay out
      of the way otherwise -- Resize fires for every layout ripple, including the ones a
      splitter drag causes, and re-applying a target then fights the drag pixel by pixel. }
    FSlideRoom: Integer;
    FPaneRoom: Integer;
    { How the two panes divide the body, as a FRACTION rather than as pixels. The window is
      resized far more often than the splitter is dragged, and a pixel width means the editor
      keeps its size while the preview absorbs every change -- which is not what "the two
      panes are meant to be comparable" says. Updated when the splitter is let go. }
    FPaneFraction: Double;
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
    { The jump's own afterglow. One-shot: a jump sets it, this clears it. }
    FFlashTimer: TTimer;
    FLeft: TPanel;
    { Search lives in the LEFT half of the top strip -- the half over the editor, because the
      template is what is searched. It used to be a row of its own above the editor, which
      cost the editor a line every time it opened while the strip above sat half empty
      holding controls that belong to the output. }
    FFindText: TEdit;
    FFindCount: TLabel;
    FFindCase: TCheckBox;
    { Icon buttons like the strip's other two. They give up being focusable, which is the one
      thing a TButton had over them here -- and it costs nothing, because every action on this
      bar is on the field's own keyboard: Enter for the next match, Shift+Enter for the one
      before, Escape to close. }
    FFindPrev: TSpeedButton;
    FFindNext: TSpeedButton;
    FFindClose: TSpeedButton;
    { Visible only when the bar is NOT, in the place the field takes when it is. }
    FFindOpen: TSpeedButton;
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
    { Kept, not created and forgotten: a theme has to reach its colours. }
    FBracket: TSpxBracketMarkup;
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
    { What the last render reported, kept as NUMBERS. The status bar and the fragment caption
      are sentences built from them, and a sentence cannot be retranslated -- so the numbers
      are what is remembered and the sentence is rebuilt whenever the language changes. }
    FHaveResult: Boolean;
    FResErrors, FResWarnings, FResNotes, FResElapsed: Integer;
    FPartialShown, FPartialEmpty: Boolean;
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
    procedure VarFindRef(const AName: string);
    procedure FlashJumpLine;
    procedure FlashFaded(Sender: TObject);
    procedure VarSpell(ANames: TStringList);
    function DefValueEdited(ADirIndex: Integer; const AValue: string): Boolean;
    procedure VarDefine(const AName, AValue: string);
    procedure OpenGroupPane;
    procedure RuntimeChanged(Sender: TObject);
    procedure SelectionChanged(Sender: TObject; Changes: TSynStatusChanges);
    procedure PreviewFollowSelection;
    procedure WrapSelection(const L, R: string);
    function CurrentSelection(WithText: Boolean): TSpxSelection;
    procedure WrapBracesClicked(Sender: TObject);
    procedure WrapBracketsClicked(Sender: TObject);
    { AFlash lights the landed row for a moment. Off for stepping through search matches: that
      step REPEATS, and the timer re-arms, so holding F3 would leave a row permanently washed --
      the wash would stop meaning "just arrived" and start meaning "selected". A match is
      already shown by its selection anyway; a panel row has nothing else to show. }
    procedure JumpToPos(Line, Column, EndLine, EndColumn: Integer; AFlash: Boolean = True);
    procedure ShowRows(const ARows: TSpxPanelRows);
    procedure JumpTo(Row: TSpxPanelRow);
    function LineOf(N: Integer): string;
    procedure BuildUi;
    procedure BuildFindBar;
    procedure LayoutTopStrip;
    procedure TopStripResized(Sender: TObject);
    procedure LocaleDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure SizeLocaleList;
    procedure BuildMenu;
    procedure EnsureFlags;
    procedure EnsureSmallIcons;
    procedure ShowFindBar;
    procedure HideFindBar;
    procedure FindTextChanged(Sender: TObject);
    procedure FindNextClicked(Sender: TObject);
    procedure FindPrevClicked(Sender: TObject);
    procedure FindCloseClicked(Sender: TObject);
    procedure FindOpenClicked(Sender: TObject);
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
    { The settings file, in the two directions. ApplyPrefs moves the window to match what was
      loaded; SavePrefs reads the window back and writes it. }
    procedure ApplyPrefs;
    procedure SavePrefs;
    procedure ApplyTheme;
    { The family AND the size, to every editor in the window at once. Recomputed rather than
      remembered because the family depends on the DOCUMENT: a template that gains a line of
      Japanese needs a font that can draw it. }
    procedure ApplyEditorFont;
    procedure UpdateEditorFont(const AText: string);
    function ChosenFamily: string;
    function ChosenFamilyFor(const AText: string): string;
    procedure ZoomEditor(ASteps: Integer);
    procedure ZoomInClicked(Sender: TObject);
    procedure ZoomOutClicked(Sender: TObject);
    procedure ZoomResetClicked(Sender: TObject);
    procedure ThemeLightClicked(Sender: TObject);
    procedure ThemeDarkClicked(Sender: TObject);
    procedure EditorMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    procedure GutterPart(AEditor: TSynEdit; const AClass: string; AVisible: Boolean);
    procedure SplitEvenly(Sender: TObject);
    procedure SplitMoved(Sender: TObject);
    procedure SplitEvenNow(Sender: TObject);
    procedure SlideResized(Sender: TObject);
    procedure ClampSlide;
    procedure ClampPanes;
    procedure ShowPanel(APage: Integer; AWanted: Boolean);
    procedure MenuDiagClicked(Sender: TObject);
    procedure MenuVarsClicked(Sender: TObject);
    procedure MenuSetClicked(Sender: TObject);
    procedure GroupPaneClosed(Sender: TObject);
    procedure FontAutoClicked(Sender: TObject);
    procedure FontPicked(Sender: TObject);
    procedure ModePageClicked(Sender: TObject);
    procedure ModeSourceClicked(Sender: TObject);
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
    { The two sentences built from a result rather than from the caption table. }
    procedure ShowStatus;
    procedure ShowPartial;
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
    { The first moment the locale combo has a window to be told how wide to drop. }
    procedure DoShow; override;
    { A window made narrower must take the room from the panel, not from the panes.

      AND THIS FIRES FOR EVERY LAYOUT RIPPLE ANYWHERE IN THE FORM, not only when the window
      changes size: any child's ChangeBounds walks up to the form and DoAllAutoSize calls
      CallAllOnResize (control.inc:3102-3125). The FLastResizeWidth/Height comparison inside
      TControl.Resize gates only DoOnResize, so anything written after `inherited Resize` in
      an override runs every time. A splitter drag is such a ripple -- which is why both
      clamps below act only when the ROOM changed and would otherwise put every dragged width
      straight back. An earlier version of this comment claimed the opposite and cost two
      frozen splitters. }
    procedure Resize; override;
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

  { TSplitter publishes no OnDblClick and TControl keeps it protected; a descendant is the
    standard way in, and adds no fields, so the cast is safe. }
  TSplitterReach = class(TSplitter)
  public
    property OnDblClick;
  end;

const
  DEBOUNCE_MS = 200;   // long enough to skip a burst of typing, short enough to feel live
  { What the two panes and everything under them are never squeezed below, and what ONE pane
    is never squeezed below. Two panes worth reading rather than two slivers. }
  SPX_BODY_MIN = 320;
  SPX_PANE_MIN = 140;


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
  { THE FILE IS READ BEFORE ANY CAPTION EXISTS, for the reason the comment above gives: a
    caption is read once, when its control is made. A language restored after BuildUi would
    need every control re-read; a language restored here costs nothing. }
  FLoading := True;
  FPaneFraction := 0.48;
  FPrefs := SpxLoadPrefs;
  FLangFollow := FPrefs.LangFollow;
  if FPrefs.Lang <> '' then FLangChosen := SpxLangFor(FPrefs.Lang)
  else FLangChosen := SpxSystemLang;
  SpxSetUiLang(FLangChosen);
  FPath := '';
  FEol := SPX_DEFAULT_EOL;
  FTrailingEol := True;
  BuildUi;
  UpdateCaption;
  FNextId := 0;
  FLastShown := -1;
  { The rest of the file: things that need the controls to exist. }
  ApplyPrefs;
  FLoading := False;
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
  { Wide enough to be worth opening, never wide enough to swallow the editor. The bounds are
    the settings file's, so a width edited by hand cannot leave the panel unusable either. }
  FSlide.Constraints.MinWidth := Px(Self, SPX_SLIDE_MIN);
  FSlide.Constraints.MaxWidth := Px(Self, SPX_SLIDE_MAX);
  FSlide.Visible := False;
  FSlide.OnApply := @GroupApplied;
  FSlide.OnClose := @GroupPaneClosed;

  { A VARIANT CAN BE LONGER THAN ANY DEFAULT. The panel is the one part of this window whose
    useful width depends on the document rather than on the layout, so it is the user's to
    set -- and remembered, because setting it once per session would be worse than not being
    able to set it at all. Hidden with the panel: a drag handle for something invisible is a
    handle that resizes nothing. }
  FSlideSplit := TSplitter.Create(Self);
  FSlideSplit.Parent := FOuter;
  FSlideSplit.Align := alLeft;
  FSlideSplit.Left := FSlide.Width + 1;
  FSlideSplit.Visible := False;
  FSlideSplit.OnMoved := @SlideResized;

  FBody := TPanel.Create(Self);
  FBody.Parent := FOuter;
  FBody.Align := alClient;
  FBody.BevelOuter := bvNone;
  { THE PANES KEEP A FLOOR, and it has to live HERE rather than as a maximum on the slide-out.
    LCL bounds a splitter drag by the NEIGHBOUR's constraints, not by the dragged control's
    (customsplitter.inc:361-364): with nothing set, the floor for everything right of the
    panel is the splitter's own MinSize of 30 px. Measured before this line existed: a window
    780 px wide with a stored panel width of 900 opened with a body 0 px wide -- no editor, no
    preview, no bottom block, no status bar, and the splitter off-screen so the mouse could not
    undo it. }
  FBody.Constraints.MinWidth := Px(Self, SPX_BODY_MIN);

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
  { The list is drawn by hand for ONE reason: a two-letter tag is not a thing most people can
    read. `bs` and `sr` and `hr` are three different answers to "which plural rules", and the
    codes alone make that a guess. So the DROPPED list carries the language's own name beside
    the tag while the closed box keeps the tag only -- the strip has no room for a name, and
    the person who is choosing needs it, not the person who has chosen.

    NOT a flag, which was the other proposal and is the wrong symbol here: flags already mean
    the INTERFACE's language in this window's menu, this is the DOCUMENT's, and the two are
    deliberately separate settings (that is why "follow the document" exists and is off). A
    flag is also a country, and `en` is not one. }
  FLocale.Style := csOwnerDrawFixed;
  FLocale.OnDrawItem := @LocaleDrawItem;
  { Every locale visible at once. The default is eight against ten items, which is a scrollbar
    for the sake of two lines. }
  FLocale.DropDownCount := FLocale.Items.Count;

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

  EnsureSmallIcons;
  { The slide-out's close button draws from the same list the strip does. }
  FSlide.SetIcons(FSmallIcons);

  FReroll := TSpeedButton.Create(Self);
  FReroll.Parent := FTop;
  FReroll.Flat := True;
  FReroll.Images := FSmallIcons;
  FReroll.ImageIndex := SPX_ICON_REROLL;
  FReroll.Hint := Tr(sReroll);
  FReroll.ShowHint := True;
  FReroll.SetBounds(Px(Self, 228), Px(Self, 6), Px(Self, 30), Px(Self, 26));
  FReroll.OnClick := @RerollClicked;

  FCopy := TSpeedButton.Create(Self);
  FCopy.Parent := FTop;
  FCopy.Flat := True;
  FCopy.Images := FSmallIcons;
  FCopy.ImageIndex := SPX_ICON_COPY;
  FCopy.Hint := Tr(sCopy);
  FCopy.ShowHint := True;
  FCopy.SetBounds(Px(Self, 314), Px(Self, 6), Px(Self, 30), Px(Self, 26));

  FPartial := TLabel.Create(Self);
  FPartial.Parent := FTop;
  FPartial.AutoSize := True;
  FPartial.Visible := False;

  FModes := TSpxSegmented.Create(Self);
  FModes.Parent := FTop;
  FModes.Color := FTop.Color;
  FModes.Images := FSmallIcons;
  FModes.Add(Tr(sViewPage), SPX_ICON_PAGE);
  FModes.Add(Tr(sViewSource), SPX_ICON_SOURCE);
  FModes.OnChange := @PreviewModeChanged;
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
  { THE TAB STRIP IS GONE. It cost 28 px -- measured, 3.6% of the window -- and said two
    things: which panel is current, and how to reach the others by keyboard. The rail's lit
    tool says the first now and the View menu says the second, so the strip was a duplicate of
    both. The pages stay: this is still a TPageControl, just without its tabs drawn. }
  FBottom.ShowTabs := False;
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
  FVars.OnFindRef := @VarFindRef;
  FVars.OnDefine := @VarDefine;
  FVars.OnSpell := @VarSpell;
  FVars.OnSetDefValue := @DefValueEdited;
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

  { THE FLOOR HAS TO BE A CONSTRAINT, not only a clamp. LCL bounds a splitter drag by the
    NEIGHBOUR's Constraints (customsplitter.inc:361-364), so a pane with none has nothing to
    be read and the drag stops only at the splitter's own MinSize. Measured before this line:
    dragging hard right left the preview at 30 px and hard left left the editor at ONE, and
    it stuck until the window was resized. The clamp keeps the proportion; this keeps the
    promise. }
  FLeft.Constraints.MinWidth := Px(Self, SPX_PANE_MIN);

  FEditor := TSynEdit.Create(Self);
  FEditor.Parent := FLeft;
  FEditor.Align := alClient;
  { Fixed pitch, because a template is markup -- but only the FAMILY is ours. The size
    stays the system's, so a desktop configured for larger text gets a larger editor. }
  { The family and size are set properly by ApplyEditorFont once the settings are read; this
    is only so the control is never briefly proportional while the window is being built. }
  SpxApplyMonoFont(FEditor.Font);
  FEditor.OnMouseWheel := @EditorMouseWheel;
  FEditor.Gutter.Visible := True;
  { THE GUTTER IS 55 PX WIDE OUT OF THE BOX AND 36 OF THEM SERVE FEATURES THIS APP DOES NOT
    HAVE. Measured, part by part: marks 24 (bookmarks and breakpoints -- there are none, which
    is also why Ctrl+0 was free to take), line numbers 15, changes 4, separator 2, code folding
    10 (a spintax template has nothing to fold, and the highlighter reports no fold ranges).
    The marks column is what shows as a pale band beside a dark editor: its background is
    clBtnFace, a SYSTEM colour, so it stays light whatever the theme does.

    Numbers and the change stripe stay. The rest is 36 px given back to the text. }
  GutterPart(FEditor, 'TSynGutterMarks', False);
  GutterPart(FEditor, 'TSynGutterCodeFolding', False);
  GutterPart(FEditor, 'TSynGutterSeparator', False);
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
  FBracket := TSpxBracketMarkup.Create(FEditor);
  TSynEditMarkupManager(TSynEditReach(FEditor).MarkupMgr).AddMarkUp(FBracket);

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
  { Double-click divides the two panes evenly -- what a person tries on a splitter, and the
    only way back to the middle once it has been dragged. TSplitter does not publish
    OnDblClick (extctrls.pp:437-469) and TControl declares it protected, so it is reached
    through a descendant, the same way this file already reaches SynEdit's markup manager.

    The click only RAISES A FLAG; the work happens in OnMoved. See SplitMoved. }
  TSplitterReach(FSplit).OnDblClick := @SplitEvenly;
  FSplit.OnMoved := @SplitMoved;
  { A GESTURE HAS TO SAY SO SOMEWHERE, and the place it says it is where the gesture lives.
    Nothing about a drag handle suggests it can also be double-clicked; the menu item below
    names the action, and this teaches the shortcut to the hand that is already on it. }
  FSplit.Hint := Tr(sSplitEvenHint);
  FSplit.ShowHint := True;

  { Two views of the same output -- the page and the HTML it is -- with the switch and the
    size guard owned by the pane itself (SpxPreviewPane, ADR 0004). }
  FPreview := TSpxPreviewPane.Create(Self);
  FPreview.Parent := FBody;
  FPreview.Align := alClient;
  FPreview.Constraints.MinWidth := Px(Self, SPX_PANE_MIN);

  FDebounce := TTimer.Create(Self);
  FDebounce.Enabled := False;
  FDebounce.Interval := DEBOUNCE_MS;
  FDebounce.OnTimer := @DebounceFired;

  FCaretTimer := TTimer.Create(Self);
  FCaretTimer.Enabled := False;
  FCaretTimer.Interval := 120;
  FCaretTimer.OnTimer := @CaretSettled;

  { LONG ENOUGH TO BE SEEN, short enough not to become a state. 900 ms is about three times
    the eye's saccade-plus-fixation to a new place on the screen, and well under the point
    where a coloured row starts reading as "this line is selected". }
  FFlashTimer := TTimer.Create(Self);
  FFlashTimer.Enabled := False;
  FFlashTimer.Interval := 900;
  FFlashTimer.OnTimer := @FlashFaded;

  { THE MENU IS BUILT LAST, because its View section is a REPORT: which side the rail is on,
    which panel is open, which preview mode. Built earlier -- it used to sit right after the
    rail -- it read FBottom before FBottom existed, so all three panel ticks came out unset,
    which by this menu's own rule means "the block is collapsed" on a window whose block is
    open. It corrected itself on the first click of anything, which is exactly why no test
    that clicks first could see it. Caught by review, on the running app. }
  BuildMenu;
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

  { THE ONE THING THAT MAKES SEARCH FINDABLE. It had a shortcut and nothing to click, which
    means it existed only for people who already knew it existed -- and this is a Store
    product, where the second kind of user is most of them. It sits at the strip's left
    because that half belongs to the template, and it stands aside when the bar opens: the
    field starts exactly where the icon was, so nothing shifts. }
  FFindOpen := TSpeedButton.Create(Self);
  FFindOpen.Parent := FTop;
  FFindOpen.Flat := True;
  FFindOpen.Images := FSmallIcons;
  FFindOpen.ImageIndex := SPX_ICON_SEARCH;
  FFindOpen.Hint := Tr(sMenuFind);
  FFindOpen.ShowHint := True;
  FFindOpen.OnClick := @FindOpenClicked;

  { Icons rather than the characters `<` and `>` on plain buttons, which is what these were:
    two pieces of ASCII between an icon field and an icon close. }
  FFindPrev := TSpeedButton.Create(Self);
  FFindPrev.Parent := FTop;
  FFindPrev.Flat := True;
  FFindPrev.Images := FSmallIcons;
  FFindPrev.ImageIndex := SPX_ICON_PREV;
  FFindPrev.Hint := Tr(sMenuFindPrev);
  FFindPrev.ShowHint := True;
  FFindPrev.Visible := False;
  FFindPrev.OnClick := @FindPrevClicked;

  FFindNext := TSpeedButton.Create(Self);
  FFindNext.Parent := FTop;
  FFindNext.Flat := True;
  FFindNext.Images := FSmallIcons;
  FFindNext.ImageIndex := SPX_ICON_NEXT;
  FFindNext.Hint := Tr(sMenuFindNext);
  FFindNext.ShowHint := True;
  FFindNext.Visible := False;
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

  { The sprite's ✕, not the CHARACTER ✕ on a push button, which is what this was. The group
    pane's close is the same glyph from the same strip, so the two places a person dismisses
    something now look like each other. }
  FFindClose := TSpeedButton.Create(Self);
  FFindClose.Parent := FTop;
  FFindClose.Flat := True;
  FFindClose.Images := FSmallIcons;
  FFindClose.ImageIndex := SPX_ICON_CLOSE;
  FFindClose.Hint := Tr(sClose);
  FFindClose.ShowHint := True;
  FFindClose.Visible := False;
  FFindClose.OnClick := @FindCloseClicked;
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

{ The language's own name for a locale tag, or '' when the tag is not one this build has a
  name for. The round trip is the guard: SpxLangFor falls back to English for anything it does
  not know (by design -- a half-translated window is worse than an English one), so asking it
  about `pl` would answer "English" with a straight face. Comparing the code back catches
  exactly that, and an unnamed tag is then simply shown bare. }
function SpxLocaleName(const ACode: string): string;
var lang: TSpxLang;
begin
  Result := '';
  lang := SpxLangFor(ACode);
  { A plain compare rather than the engine's normalisation, because the tags being named are
    the combo's own -- bare two-letter codes this window put there. A regional tag would simply
    go unnamed and be shown bare, which is the same thing an unknown one does. }
  if SameText(SpxLangCode(lang), ACode) then Result := SpxLangName(lang);
end;

procedure TSpxMainForm.LocaleDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var cb: TComboBox; code, name_: string; y, x: Integer;
begin
  cb := TComboBox(Control);
  if (Index < 0) or (Index >= cb.Items.Count) then Exit;
  code := cb.Items[Index];
  { LCL has already set the brush and the font colour for this row's state -- selected rows
    arrive with the highlight colours -- so filling is all the background needs. }
  cb.Canvas.FillRect(ARect);
  y := ARect.Top + (ARect.Bottom - ARect.Top - cb.Canvas.TextHeight('Ag')) div 2;
  x := ARect.Left + Px(Self, 3);
  cb.Canvas.TextOut(x, y, code);
  { The closed box is the SAME item drawn in a 70px hole: the name goes to the list only, and
    odComboBoxEdit is how the two calls are told apart. }
  if odComboBoxEdit in State then Exit;
  name_ := SpxLocaleName(code);
  if name_ = '' then Exit;
  { A fixed column so the names line up under one another rather than following the width of a
    tag; the tags are all two letters, so this is a column and not a coincidence. }
  Inc(x, cb.Canvas.TextWidth('nn') + Px(Self, 10));
  { Secondary, because the TAG is what the setting stores and the name is the gloss -- except
    on the highlighted row, where grey on the selection colour is what unreadable looks like. }
  if not (odSelected in State) then cb.Canvas.Font.Color := clGrayText;
  cb.Canvas.TextOut(x, y, name_);
end;

{ The dropped list is as wide as its widest line, which the box itself is not: 70px holds a
  tag and nothing else. Windows sizes the list to the CONTROL unless told otherwise, so the
  names would arrive clipped -- CB_SETDROPPEDWIDTH is the telling.

  Measured on a bitmap rather than on the combo, for the reason the label trap records: a
  control's Canvas outside a paint is not a measurement surface, and TComboBox does not offer
  one at all. }
procedure TSpxMainForm.SizeLocaleList;
{$IFDEF WINDOWS}
var bmp: TBitmap; i, w, wide: Integer; name_: string;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  if (FLocale = nil) or not FLocale.HandleAllocated then Exit;
  bmp := TBitmap.Create;
  try
    bmp.Canvas.Font.Assign(FLocale.Font);
    wide := 0;
    for i := 0 to FLocale.Items.Count - 1 do
    begin
      name_ := SpxLocaleName(FLocale.Items[i]);
      if name_ = '' then Continue;
      w := bmp.Canvas.TextWidth('nn') + Px(Self, 10) + bmp.Canvas.TextWidth(name_);
      if w > wide then wide := w;
    end;
    { The padding the rows are drawn with, on both sides, plus room to breathe -- and nothing
      for a scrollbar, because with DropDownCount at the item count there is not one.

      Measured with the ten locales this ships with: the longest line is Belarusian, and the
      first attempt left it 4 px from the edge. That is not clipping but it reads as if it
      were, and the slack costs nothing on a list nobody is short of room for. }
    if wide > 0 then
      SendMessage(FLocale.Handle, CB_SETDROPPEDWIDTH,
                  wide + Px(Self, 3) * 2 + Px(Self, 14), 0);
  finally
    bmp.Free;
  end;
  {$ENDIF}
end;

procedure TSpxMainForm.LayoutTopStrip;
var right_, leftEnd, x, y, fieldW, fixed, editorEnd: Integer;

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
  if (FTop = nil) or (FModes = nil) or (FLocale = nil) or (FCopy = nil) or
     (FFindText = nil) then Exit;

  { ── the output's half, from the right edge inwards ── }
  editorEnd := 0;
  right_ := FTop.ClientWidth - Px(Self, 12);
  { The switch asks for what its own captions need; everything else is a fixed slot. }
  PlaceRight(FModes, FModes.MeasureWidth, Px(Self, 26), Px(Self, 6));
  if FPartial.Visible then PlaceRight(FPartial, FPartial.Width, Px(Self, 16), Px(Self, 11));
  PlaceRight(FCopy, Px(Self, 30), Px(Self, 26), Px(Self, 6));
  PlaceRight(FReroll, Px(Self, 30), Px(Self, 26), Px(Self, 6));
  { Skipped rather than placed off-screen, so the controls to its left close the gap -- the
    same way the fragment caption already comes and goes. }
  if FSeedEdit.Visible then PlaceRight(FSeedEdit, Px(Self, 70), Px(Self, 24), Px(Self, 7));
  PlaceRight(FSeeded, Px(Self, 55), Px(Self, 22), Px(Self, 9));
  PlaceRight(FLocale, Px(Self, 70), Px(Self, 24), Px(Self, 7));
  leftEnd := right_;

  { THE SLIDE-OUT STARTS WHERE THE EDITOR DOES. It is a sibling of the body rather than a
    child of it -- that is what keeps it and the rail off each other's edge -- so nothing
    aligns it with the panes on its own, and it used to begin a whole top strip higher. The
    inset is read from the strip rather than repeated as a number, so the second row the
    search bar takes moves it too. }
  if FSlide <> nil then FSlide.BorderSpacing.Top := FTop.Height;
  { And its drag handle with it: a splitter that starts a strip higher than the thing it
    resizes is a line drawn through the top of the window. }
  if FSlideSplit <> nil then FSlideSplit.BorderSpacing.Top := FTop.Height;

  { ── the template's half, from the left edge outwards ── }

  { THE BAR BELONGS TO THE EDITOR, so it ends where the editor does. leftEnd alone is where the
    OUTPUT's controls begin, which on a window whose preview has been widened is far to the
    right of the pane being searched -- and the close button then sat over the preview, looking
    like it belonged to it. FLeft and FTop are both children of FBody, so this is one
    coordinate space and no conversion is needed.

    A floor under it: if the editor has been dragged down to a sliver there is no honest place
    for the bar, and overflowing is better than a row of controls one pixel wide. }
  { The sum of everything on the bar except the field, in the order it is placed below:
    gap, prev, gap, next, gap, case box, gap, counter, gap, close. It has to be READ from that
    block -- it is what tells the editor's edge how narrow the bar can honestly get. }
  fixed := Px(Self, 8 + 30 + 4 + 30 + 8 + 90 + 8 + 110 + 8 + 30);
  if (FLeft <> nil) and (FLeft.Width > 0) then
  begin
    editorEnd := FLeft.Left + FLeft.Width;
    { The floor is the bar's OWN minimum -- its left inset, the narrowest usable field and the
      fixed parts -- rather than a round number, so the two agree by construction. An editor
      dragged narrower than this cannot hold the bar at all, and the bar overflows rather than
      shrinking below the point where the field stops being a field. Measured at a 30% editor:
      it takes the second row and still ends 114 px into the preview, which is the honest
      answer -- the alternative is hiding the match counter or the case box, and losing a
      control is worse than losing an edge. }
    if editorEnd < Px(Self, 8) + Px(Self, 90) + fixed then
      editorEnd := Px(Self, 8) + Px(Self, 90) + fixed;
    if editorEnd < leftEnd then leftEnd := editorEnd;
  end;

  { The magnifier stands where the field will: same left edge, so opening the bar does not
    move anything, it replaces it. }
  if FFindOpen <> nil then
  begin
    FFindOpen.Visible := not FFindText.Visible;
    if FFindOpen.Visible then
      FFindOpen.SetBounds(Px(Self, 8), Px(Self, 6), Px(Self, 30), Px(Self, 26));
  end;

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
    better than controls drawn on top of one another.

    `fixed` is computed above, where the editor's edge needs it to know how narrow the bar can
    honestly get. }
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
    { A row of its own, so the output's controls are no longer in the way -- but the editor's
      edge still is, and for the same reason: this bar searches the left pane. }
    fieldW := FTop.ClientWidth - Px(Self, 8);
    if (editorEnd > 0) and (editorEnd < fieldW) then fieldW := editorEnd;
    fieldW := fieldW - x - fixed;
    if fieldW < Px(Self, 90) then fieldW := Px(Self, 90);
    FTop.Height := Px(Self, 70);
  end;

  FFindText.SetBounds(x, y + Px(Self, 7), fieldW, Px(Self, 24));
  Inc(x, fieldW + Px(Self, 8));
  { ONE WIDTH FOR ALL FOUR, and the same 30 the strip's other icon buttons use. They were 34,
    34 and 28 -- the widths the push buttons had when they carried `<`, `>` and `x` -- so
    turning them into icons left four buttons of three sizes in a row of ten pixels. }
  FFindPrev.SetBounds(x, y + Px(Self, 6), Px(Self, 30), Px(Self, 26));
  Inc(x, Px(Self, 34));
  FFindNext.SetBounds(x, y + Px(Self, 6), Px(Self, 30), Px(Self, 26));
  Inc(x, Px(Self, 38));
  FFindCase.SetBounds(x, y + Px(Self, 9), Px(Self, 90), Px(Self, 20));
  Inc(x, Px(Self, 98));
  { 110px, and the captions are written to fit it: widening this by twenty pixels is enough
    to push a 1100px window -- the default size -- into the two-row strip, which is a worse
    trade than a compact '12/57'. }
  FFindCount.SetBounds(x, y + Px(Self, 11), Px(Self, 110), Px(Self, 16));
  Inc(x, Px(Self, 118));
  FFindClose.SetBounds(x, y + Px(Self, 6), Px(Self, 30), Px(Self, 26));
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
  { AND LAY THE STRIP OUT, which this did not do and which broke two things at once.
    FFindOpen's visibility is decided in LayoutTopStrip -- it is the inverse of the field's --
    so without this the magnifier stayed hidden after the first Escape and came back only when
    something unrelated re-laid the strip: a window resize, a splitter drag, a language
    switch. The one control that makes search findable disappeared the first time search was
    closed.

    The second thing is older than this bar's icons: closed from the TWO-ROW state, the strip
    kept its 70 px and the editor went on paying for an empty second row until the next
    resize. Same missing call, same line fixes it. }
  LayoutTopStrip;
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
            FMatches[idx].EndLine, FMatches[idx].EndCol, False);
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

procedure TSpxMainForm.FindOpenClicked(Sender: TObject);
begin
  { The same door the menu item and Ctrl+F use, so the box arrives holding the selection and
    focused, exactly as it does from the keyboard. }
  ShowFindBar;
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
  { GROUP 1: the three panels are one choice, and the lit one is the panel on screen. Group 2
    for the slide-out because it is a different question -- a latch of its own, not a fourth
    panel. }
  FRail.AddTool(SPX_ICON_DIAG, Tr(sTabDiagnostics), @RailDiagClicked, 1);
  FRail.AddTool(SPX_ICON_VARS, Tr(sTabVariables), @RailVarsClicked, 1);
  FRail.AddTool(SPX_ICON_SET, Tr(sTabVariants), @RailSetClicked, 1);
  { The one tool that is not access but WORKSPACE: a group's variants are a list, one short
    line each, which is exactly what fits beside the editor. }
  FRail.AddTool(SPX_ICON_GROUP, Tr(sTabGroup), @RailGroupClicked, 2);
  { The window opens with the diagnostics showing, so the tool that says so is lit. }
  FRail.SetDown(0, True);
end;

procedure TSpxMainForm.RailGroupClicked(Sender: TObject);
begin
  if FSlide.Visible then
  begin
    { The same exit as the panel's own X, and for the reason that exit exists: hiding a
      control that holds the focus leaves ActiveControl NIL -- LCL's CMVisibleChanged calls
      DefocusControl -- so the caret would simply vanish from the editor. }
    GroupPaneClosed(Sender);
    Exit;
  end;
  OpenGroupPane;
end;

{ The panel, OPENED rather than toggled. Ctrl+clicking a variable needs to arrive at an open
  group editor whether or not it happened to be open already, and the rail's handler is a
  toggle -- calling it from there would have closed the panel half the time. }
procedure TSpxMainForm.OpenGroupPane;
begin
  { Before it is shown, not after: a panel that appears too wide and then snaps is worse than
    one that appears the right size. }
  { Showing the panel changes what the body has, so both clamps must run whatever they last
    saw. }
  FSlideRoom := -1;
  FPaneRoom := -1;
  ClampSlide;
  FSlide.Visible := True;
  FSlideSplit.Visible := True;
  { The panel has just taken its share; the panes divide what is actually left. }
  ClampPanes;
  { The latch, for the route that does not set it itself. Clicking the rail's tool makes LCL
    flip Down before it calls this; opening from the View menu does not, and an unlit tool
    over an open pane is not just wrong-looking -- the next click on it flips Down to True,
    this handler sees the pane already open and closes it. So the user presses an unlit
    "group editor" and the group editor vanishes. Measured by review, pixel for pixel. }
  FRail.SetDown(3, True);
  { It opens on whatever the caret is already in, rather than staying blank until the next
    keypress. }
  FSlide.ShowGroupAt(FEditor.Text, CaretOffset);
  FSlide.Retranslate;
  { AND IT TAKES THE FOCUS. The rail's tool is a TSpeedButton, which is a TGraphicControl and
    cannot hold focus, so opening the panel used to leave the keyboard in the editor -- which
    made the panel's own Escape unreachable until the user clicked into the list. Caught by
    review: the probe that "verified" Escape posted the key into the memo itself, measuring
    the handler rather than the route to it. }
  FSlide.FocusList;
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

{ THE BOTTOM BLOCK, and the only place that decides its fate. AWanted is the tool's own state
  after LCL flipped it: lit means "show me this panel", out means "I clicked the one that was
  already lit", which is the collapse. The splitter goes with the block -- a splitter with
  nothing under it is a handle that resizes nothing. }
procedure TSpxMainForm.ShowPanel(APage: Integer; AWanted: Boolean);
begin
  if (FBottom = nil) or (FDiagSplit = nil) then Exit;
  { The same hazard the group pane was fixed for, in the same window: hiding a control that
    holds the focus leaves ActiveControl NIL -- CMVisibleChanged calls DefocusControl -- and
    the caret disappears from the editor. Collapsing the block while the diagnostics list or
    the variants grid had it would do exactly that. }
  if (not AWanted) and (Screen.ActiveControl <> nil) and
     FBottom.ContainsControl(Screen.ActiveControl) and FEditor.CanSetFocus then
    FEditor.SetFocus;
  FBottom.Visible := AWanted;
  FDiagSplit.Visible := AWanted;
  if AWanted and (FBottom.PageCount > APage) then FBottom.PageIndex := APage;
  { The menu's ticks are the same state seen from the other side. }
  BuildMenu;
  SavePrefs;
end;

procedure TSpxMainForm.RailDiagClicked(Sender: TObject);
begin
  ShowPanel(0, FRail.IsDown(0));
end;

procedure TSpxMainForm.RailVarsClicked(Sender: TObject);
begin
  ShowPanel(1, FRail.IsDown(1));
end;

procedure TSpxMainForm.RailSetClicked(Sender: TObject);
begin
  ShowPanel(2, FRail.IsDown(2));
end;

{ One handler for fourteen items: which language it was is the item's Tag, set when the menu
  was built. Fourteen near-identical methods would be fourteen places to forget one. }
procedure TSpxMainForm.LangPicked(Sender: TObject);
begin
  if not (Sender is TMenuItem) then Exit;
  FLangFollow := False;
  FLangChosen := TSpxLang(TMenuItem(Sender).Tag);
  { A CHOICE, so it is written down. Until one is made the stored code stays empty, which is
    what "follow the desktop" is spelled as. }
  FPrefs.Lang := SpxLangCode(FLangChosen);
  FPrefs.LangFollow := False;
  ApplyLangMode;
end;

procedure TSpxMainForm.LangFollowClicked(Sender: TObject);
begin
  FLangFollow := True;
  FPrefs.LangFollow := True;
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
  SavePrefs;
end;

procedure TSpxMainForm.RailLeftClicked(Sender: TObject);
begin
  FRail.Side := spxRailLeft;
  SavePrefs;
  BuildMenu;   { the tick moves with it }
end;

procedure TSpxMainForm.RailRightClicked(Sender: TObject);
begin
  FRail.Side := spxRailRight;
  SavePrefs;
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
  fileMenu, editMenu, viewMenu, langMenu, fontMenu, sideItem: TMenuItem;
  lang: TSpxLang;
  fi: Integer;
  keepHeight: Integer;
begin
  { THE WINDOW MUST NOT CHANGE SIZE BECAUSE A MENU WAS REPLACED. Detaching one makes Windows
    hand its row back to the client area and LCL grows the form to match; re-attaching does not
    undo it, so the first rebuild after startup made the window 20 px taller -- measured, once
    and then stable. It is not the panels that caused it: a single language switch does the
    same, and did before any of this. }
  keepHeight := Height;

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
  { The zoom, in a menu as well as on the wheel -- the project's rule: a hotkey nobody can
    find is a hotkey nobody uses. Ctrl+= rather than Ctrl++ because that is the key a person
    presses; Ctrl+- and Ctrl+0 are the pair everyone else uses for the same three actions.

    Ctrl+0 IS TAKEN, from SynEdit's ecGotoMarker0 (syneditkeycmds.pp:1143) -- the third such
    decision in this menu and recorded like the other two. It costs nothing here: this app
    exposes no bookmarks at all, in any menu, so the command it displaces is unreachable
    anyway. If bookmarks ever become a feature, this is the line to revisit -- and note that
    Ctrl+Shift+0 still SETS marker 0, so the pair would then be half-broken rather than
    absent. }
  Item(editMenu, '-', 0, [], nil);
  Item(editMenu, Tr(sZoomIn), 187, [ssCtrl], @ZoomInClicked);       { VK_OEM_PLUS }
  Item(editMenu, Tr(sZoomOut), 189, [ssCtrl], @ZoomOutClicked);     { VK_OEM_MINUS }
  Item(editMenu, Tr(sZoomReset), Ord('0'), [ssCtrl], @ZoomResetClicked);
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
  { GROUP INDEX 1, and it is not decoration. Radio items in one menu with the SAME GroupIndex
    are ONE choice: TMenuItem.TurnSiblingsOff (menuitem.inc:1724-1736) unchecks every sibling
    that shares it, and every item defaults to 0. Adding the preview's two modes below cost
    this pair its tick until they were told apart -- caught by a probe that read the menu back
    rather than by looking at it. }
  sideItem := Item(viewMenu, Tr(sRailLeft), 0, [], @RailLeftClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 1;
  sideItem.Checked := (FRail = nil) or (FRail.Side = spxRailLeft);
  sideItem := Item(viewMenu, Tr(sRailRight), 0, [], @RailRightClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 1;
  sideItem.Checked := (FRail <> nil) and (FRail.Side = spxRailRight);
  { The rail's own buttons are TSpeedButtons, and a speed button is a TGraphicControl: no
    handle, so no tab stop and nothing for a screen reader to name. Nothing on the rail can be
    reached from the keyboard at all -- and since the tab strip went, the items below are the
    only route to the three panels as well as to this one. }
  Item(viewMenu, '-', 0, [], nil);
  Item(viewMenu, Tr(sTabGroup), 0, [], @RailGroupClicked);
  { THE THREE PANELS. The tab strip used to be their keyboard route and their names; with it
    gone this is both. A fourth state is expressible and real -- none of them ticked means the
    block is collapsed -- which is why these are radio items in a group of their own rather
    than a checkbox each. }
  Item(viewMenu, '-', 0, [], nil);
  sideItem := Item(viewMenu, Tr(sTabDiagnostics), 0, [], @MenuDiagClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 3;
  sideItem.Checked := (FBottom <> nil) and FBottom.Visible and (FBottom.PageIndex = 0);
  sideItem := Item(viewMenu, Tr(sTabVariables), 0, [], @MenuVarsClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 3;
  sideItem.Checked := (FBottom <> nil) and FBottom.Visible and (FBottom.PageIndex = 1);
  sideItem := Item(viewMenu, Tr(sTabVariants), 0, [], @MenuSetClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 3;
  sideItem.Checked := (FBottom <> nil) and FBottom.Visible and (FBottom.PageIndex = 2);

  { The same action the splitter's double click performs, named and reachable without knowing
    the gesture exists. The icon rides ON the item rather than through the menu's image list:
    that list is the flags, indexed by language, so an index into it here would draw a flag. }
  Item(viewMenu, '-', 0, [], nil);
  sideItem := Item(viewMenu, Tr(sSplitEven), 0, [], @SplitEvenNow);
  if (FSmallIcons <> nil) and (SPX_ICON_EVEN < FSmallIcons.Count) then
    FSmallIcons.GetBitmap(SPX_ICON_EVEN, sideItem.Bitmap);

  { THE EDITOR'S FONT, and only the editor's -- the chrome keeps the desktop's. Auto is not
    "the first installed" but "the first that can draw THIS document", so the entry that is
    ticked under Auto is worth showing: a person whose template gained a line of Japanese sees
    the family change and knows why. Only families this machine actually has are offered;
    naming one it does not have would be a menu item that silently does nothing. }
  Item(viewMenu, '-', 0, [], nil);
  fontMenu := TMenuItem.Create(Self);
  { THE SUBMENU'S OWN CAPTION CARRIES THE FAMILY ACTUALLY IN USE, and it has to: a named
    family that cannot draw the document falls back, so the ticked entry alone would say
    Consolas while the screen showed MS Gothic. One level up, the truth.

    READ OFF THE EDITOR rather than computed here, and this is not a shortcut -- it is the fix
    for a real fault. Asking ChosenFamily made this a SECOND caller of the chooser's memo, and
    the memo was also what UpdateEditorFont compared against to decide whether to apply: build
    the menu between a paste and the render it triggers and the memo already held the new
    answer, so the render found "no change" and applied nothing. The caption then named a font
    the editors were not using, permanently. A field cannot be both a note of the last
    computation and a record of what is on screen; the control itself is the second, always.

    It costs nothing, too. ChosenFamily materialises the whole document through DocText --
    measured at 100 ms of SpxNormalizeEol alone on a 1.4 MB template -- and a rail click, a
    theme switch and a language change all rebuild this menu. }
  fontMenu.Caption := Tr(sEditorFont) + ' — ' + FEditor.Font.Name;
  viewMenu.Add(fontMenu);
  { The same way the even-panes item carries its glyph: on the item, not through the menu's
    image list -- that list is the flags, indexed by language. }
  if (FSmallIcons <> nil) and (SPX_ICON_FONT < FSmallIcons.Count) then
    FSmallIcons.GetBitmap(SPX_ICON_FONT, fontMenu.Bitmap);
  sideItem := Item(fontMenu, Tr(sFontAuto), 0, [], @FontAutoClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 5;
  sideItem.Checked := FPrefs.FontFamily = '';
  Item(fontMenu, '-', 0, [], nil);
  { The same predicate the chooser uses, and it has to be: a family the menu offers and the
    chooser refuses would be a tick that does nothing, and one the chooser can use but the menu
    hides is a font the user cannot ask for. Not Screen.Fonts -- SpxFontInstalled says why. }
  for fi := Low(SPX_EDITOR_FONTS) to High(SPX_EDITOR_FONTS) do
    if SpxFontInstalled(SPX_EDITOR_FONTS[fi]) then
    begin
      sideItem := Item(fontMenu, SPX_EDITOR_FONTS[fi], 0, [], @FontPicked);
      sideItem.RadioItem := True;
      sideItem.GroupIndex := 5;
      sideItem.Checked := FPrefs.FontFamily = SPX_EDITOR_FONTS[fi];
    end;

  { The editor's colours. Only the editor and the source view are themed -- the preview shows
    the user's HTML as it will be published, and the window's chrome is drawn by Windows,
    which has no dark mode to offer LCL. }
  Item(viewMenu, '-', 0, [], nil);
  sideItem := Item(viewMenu, Tr(sThemeLight), 0, [], @ThemeLightClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 4;
  sideItem.Checked := FPrefs.Theme = spxThemeLight;
  sideItem := Item(viewMenu, Tr(sThemeDark), 0, [], @ThemeDarkClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 4;
  sideItem.Checked := FPrefs.Theme = spxThemeDark;

  { The preview's mode, for the same reason the group editor is here. The two radio buttons
    this replaced were real BUTTON windows, which Windows' own accessibility proxy narrates;
    a custom-drawn control is not, and the win32 widgetset ships no accessibility layer to
    make up for it. The switch takes the keyboard once focused -- measured, a posted WM_KEYDOWN
    moves it -- but a menu item is what makes the setting REACHABLE without knowing it is
    there. }
  Item(viewMenu, '-', 0, [], nil);
  sideItem := Item(viewMenu, Tr(sViewPage), 0, [], @ModePageClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 2;      { a different choice from the rail's side -- see above }
  sideItem.Checked := (FModes = nil) or (FModes.ItemIndex = 0);
  sideItem := Item(viewMenu, Tr(sViewSource), 0, [], @ModeSourceClicked);
  sideItem.RadioItem := True;
  sideItem.GroupIndex := 2;
  sideItem.Checked := (FModes <> nil) and (FModes.ItemIndex = 1);

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
  if Height <> keepHeight then Height := keepHeight;
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

procedure TSpxMainForm.Resize;
begin
  inherited Resize;
  if FSlide <> nil then ClampSlide;
  ClampPanes;
end;

procedure TSpxMainForm.AutoAdjustLayout(AMode: TLayoutAdjustmentPolicy;
  const AFromPPI, AToPPI, AOldFormWidth, ANewFormWidth: Integer);
begin
  inherited AutoAdjustLayout(AMode, AFromPPI, AToPPI, AOldFormWidth, ANewFormWidth);
  EnsureFlags;
  EnsureSmallIcons;
  if FRail <> nil then FRail.Rescale;
  { The switch's width is its captions', and a caption's width is the display's. }
  LayoutTopStrip;
  { The dropped list is measured in pixels, so it is measured again on a display that counts
    them differently. }
  SizeLocaleList;
end;

procedure TSpxMainForm.DoShow;
begin
  inherited DoShow;
  { Here rather than in BuildUi: CB_SETDROPPEDWIDTH goes to a window that does not exist until
    the form is shown, and forcing the handle early to send it sooner would only move the
    window's creation into the middle of its own construction. }
  SizeLocaleList;
end;

{ The top strip's icons: 16px inside a 26px button at 100%, the same proportion the rail uses
  at 24-in-36. Refilled rather than rebuilt when the scaling changes, because the buttons and
  the switch hold a reference to the list (SpxUi.SpxImagesFrom says why at more length). }
procedure TSpxMainForm.EnsureSmallIcons;
var size_, len: Integer; p: Pointer;
begin
  size_ := SpxIconPickSize(Px(Self, 16));
  if (FSmallIcons <> nil) and (FSmallIcons.Width = size_) then Exit;
  p := SpxIconStrip(size_, len);
  FSmallIcons := SpxImagesFrom(Self, FSmallIcons, p, len, size_, size_, SPX_ICON_COUNT);
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
procedure TSpxMainForm.JumpToPos(Line, Column, EndLine, EndColumn: Integer;
  AFlash: Boolean = True);
var col: Integer;
begin
  if Line <= 0 then Exit;
  { ARMED BEFORE THE CARET MOVES, and the order is the whole fix. SynEdit's special-line
    markup updates the line it lights from DoCaretChanged -> InvalidateLineHighlight, and that
    routine EARLY-EXITS while `HasLineHighlight` is false (syneditmarkupspecialline.pp:228) --
    which is exactly the state between two flashes. So with the colour set afterwards, the
    caret change was ignored, FHighlightedLine still pointed at the PREVIOUS jump's line, and
    the wash landed there instead: the user saw it left behind on every line they had visited.
    Arming first means the caret moves while the highlight is live, so the markup invalidates
    the old row and adopts the new one itself. }
  if AFlash then FlashJumpLine;
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

{ A definition row has a place but no span -- the engine reports where the directive starts, and
  its own column convention puts that at the line's beginning, indentation included. The jump
  moves on to the keyword: landing in the margin makes the eye hunt for the `#set` that the row
  was clicked to reach. }
procedure TSpxMainForm.VarJump(Line, Column: Integer);
begin
  JumpToPos(Line, SpxFirstNonBlankColumn(LineOf(Line), Column), 0, 0);
end;

(* CTRL+CLICK: STOP SUPPLYING THIS PER SESSION AND WRITE IT INTO THE DOCUMENT.

  A session value is a stopgap -- it dies with the window, it is not in git, and no other engine
  in the family can see it. A `#set` is the real answer, and it is the only one that silences
  variable.undefined for good. So this writes the definition, carries the value the user already
  typed into it, and opens the group editor on it so the next thing they do is add options.

  THE SHAPE IS A ONE-OPTION GROUP, `{value}`, and it was chosen by measurement rather than
  taste. `{value|}` -- two options, the second empty -- renders NOTHING half the time, which
  would make the variable look broken the moment it was defined. A bare `value` with no braces
  renders correctly but gives the group editor nothing to edit. `{value}` is clean to the
  validator, renders exactly the value, and is a group the editor can extend. An empty `{}` is
  clean too, which is what an undefined variable with no session value gets.

  AT THE TOP OF THE DOCUMENT, though it need not be: measured, a `#set` BELOW its use still
  takes effect (`X %brand% Y` then the directive renders `X Vulkan Y`). The top is where the
  family keeps its prelude, and a definition the author cannot find is a definition they will
  write twice.

  Through InsertTextAtCaret, so the insertion is ONE undo step and the caret and the syntax
  highlighting stay consistent -- SynEdit's own edit API is the only way to get that. *)
procedure TSpxMainForm.VarDefine(const AName, AValue: string);
var line_: string; col: Integer;
begin
  if (FEditor = nil) or (AName = '') then Exit;
  line_ := '#set %' + AName + '% = {' + AValue + '}';
  { The caret lands INSIDE the braces, because that is what the group editor opens on -- it
    reads the group at the caret, and a caret on the closing brace is outside the group. }
  col := Length('#set %' + AName + '% = {') + 1;

  FEditor.BeginUpdate;
  try
    FEditor.LogicalCaretXY := Point(1, 1);
    FEditor.InsertTextAtCaret(line_ + LineEnding);
  finally
    FEditor.EndUpdate;
  end;
  FEditor.LogicalCaretXY := Point(col, 1);

  { The render is what moves the variable out of the session group and into the definitions
    one; asking for it directly rather than waiting for the debounce means the panel agrees
    with the document by the time the user looks at it. }
  RequestRender;
  OpenGroupPane;
end;

(* A JUMP HAS TO SAY WHERE IT LANDED.

   Before this, a jump from the variables panel moved the caret and nothing else: JumpToPos is
   given no end position by VarJump or VarFindRef -- the engine reports a directive's start but
   not its extent, and a reference has no span at all -- so nothing was selected and the only
   evidence was a caret somewhere in a wall of text. Diagnostics rows fared better by accident:
   TSpDiag carries End* , so those jumps select their span.

   SynEdit's OWN current-line highlight does the work, the same one the Lazarus IDE uses for the
   caret's line. It is not a markup we add: giving `LineHighlightColor` a background switches it
   on (`HasLineHighlight` is exactly "a colour was set"), and clearing it switches it off. That
   buys the full ROW WIDTH, which a TSynEditMarkup cannot give -- a markup colours text, and a
   wash that stopped at the last character would not read as a row at all.

   It follows the caret while it is lit, which is the right side to err on: move the caret in
   that second and the wash comes along, still saying "you are here".

   No fade. A fade over 900 ms of a wash this faint is not perceptible -- the eye catches the
   ONSET -- and interpolating a colour per tick is arithmetic to get wrong for nothing. *)
procedure TSpxMainForm.FlashJumpLine;
begin
  if FEditor = nil then Exit;
  FEditor.LineHighlightColor.Background := SpxPalette(FPrefs.Theme).Flash;
  { Restarted, not stacked: a second jump inside the window re-arms the same timer rather than
    leaving the first one to cut the second one short. }
  FFlashTimer.Enabled := False;
  FFlashTimer.Enabled := True;
end;

procedure TSpxMainForm.FlashFaded(Sender: TObject);
begin
  FFlashTimer.Enabled := False;
  if FEditor = nil then Exit;
  FEditor.LineHighlightColor.Background := clNone;
  { AND REPAINT THE WHOLE EDITOR, rather than trusting the markup to know which row it lit.
    Clearing the colour invalidates FHighlightedLine's row -- but that number is only as
    current as the last caret change that happened WHILE the highlight was live, and there is
    no way from here to be sure it is. One full repaint, 900 ms after a jump, on a control
    that repaints on every keystroke anyway: the cost is nothing and it cannot leave a row
    washed. }
  FEditor.Invalidate;
end;

(* A DEFINITION'S VALUE, REWRITTEN WHERE IT SITS -- the first edit this panel makes to the
   document rather than to the session.

   editor-core decides WHETHER and WHERE: SpxSetDirectiveValue splices the smallest region that
   can carry the change, reads the result back through the engine, and refuses an edit whose
   document would say something other than what was asked -- a value carrying `/#` opens a
   comment that eats the rest of the file, one carrying a line break ends the directive early,
   and a directive with a comment inside it cannot be rewritten by span at all. None of that
   judgement belongs here.

   THE WINDOW ONLY APPLIES IT, and applies the SPAN rather than the new document, which is the
   whole reason this waited for the overload: assigning a new `Text` into SynEdit throws the undo
   history away and moves the caret. Through TextBetweenPoints inside one undo block, Ctrl+Z puts
   the value back in a single step -- the same road the group editor's write-back takes.

   IN EDITOR COORDINATES, not DocText's. DocText normalises to the FILE's EOL, for the engine and
   for saving; the offsets that come back must be the ones OffsetToPoint walks, and it walks
   FEditor.Lines adding LineEnding. The directive INDEX is the same in either text -- normalising
   rewrites terminators, not the order or the number of directives. *)
function TSpxMainForm.DefValueEdited(ADirIndex: Integer; const AValue: string): Boolean;
var newDoc: string; a, b: Integer;
begin
  Result := False;
  if FEditor = nil then Exit;
  Result := SpxSetDirectiveValue(FEditor.Text, ADirIndex, AValue, newDoc, a, b);
  if not Result then
  begin
    { The panel puts the row back; this says why, in the one place the window talks to the user
      without a dialog. The next render overwrites it with the verdict, which is the right
      lifetime for a message about an edit that did not happen. }
    FStatus.SimpleText := Tr(sDefValueRefused);
    Exit;
  end;
  FEditor.BeginUndoBlock;
  try
    FEditor.TextBetweenPoints[OffsetToPoint(a), OffsetToPoint(b)] := AValue;
  finally
    FEditor.EndUndoBlock;
  end;
  { The document moved, so everything derived from it has to: the preview, the verdict and the
    panel's own rows. }
  RequestRender;
end;

{ THE NAMES AS THE DOCUMENT SPELLS THEM, in one pass for all of them.

  The panel can only be told folded names -- the engine keys macros lower-cased -- so it hands
  over the list it has and this fills in the first spelling found for each. One scan, not one
  per row: the panel asks only when it rebuilds, and a rebuild is rare, but a scan per row on a
  document with thirty runtime variables would be thirty walks of the file.

  The scanner again, for the same reason the jump uses it: `%name%` inside a comment is not a
  reference, and the spelling shown must be one the user can actually find. }
procedure TSpxMainForm.VarSpell(ANames: TStringList);
var
  state: TSpxScanState;
  toks: TSpxTokenList;
  i, line, k, at: Integer;
  text_, raw, key: string;
begin
  if (FEditor = nil) or (ANames = nil) or (ANames.Count = 0) then Exit;
  state := Default(TSpxScanState);
  toks := TSpxTokenList.Create;
  try
    for line := 0 to FEditor.Lines.Count - 1 do
    begin
      text_ := FEditor.Lines[line];
      toks.Clear;
      SpxScanLine(text_, state, toks);
      for i := 0 to toks.Count - 1 do
        if toks[i].Kind = sptVariable then
        begin
          k := toks[i].Length;
          if k < 2 then Continue;
          raw := Copy(text_, toks[i].Start + 1, k - 2);
          key := LowerCase(raw);
          at := ANames.IndexOfName(key);
          { Only names the panel asked about, and only the FIRST occurrence of each: a document
            may spell one variable two ways, and the panel needs a single answer. Empty is the
            marker for "not found yet". }
          if (at >= 0) and (ANames.ValueFromIndex[at] = '') then
            ANames.ValueFromIndex[at] := raw;
        end;
    end;
  finally
    toks.Free;
  end;
end;

{ THE FIRST PLACE THE DOCUMENT USES A SESSION VARIABLE.

  A session row cannot carry a position: it comes from `SpExtract`, whose contract is names,
  deduplicated, WITHOUT positions -- so the model says Line = 0 for all of them and the panel
  has nothing to jump with. It asks by name instead, and this answers.

  THE SCANNER RATHER THAN A SEARCH, and that is the whole point. `Pos('%' + name + '%')` would
  find the name inside a comment, inside an `#include` target, and inside a `#set` that
  DEFINES it -- three places where the document does not reference the variable at all. The
  highlighter's own scanner already tells them apart (`sptVariable` versus `sptComment`), it is
  the same answer the user can see painted on the line, and it is tested. Reusing it also
  means a jump can never disagree with the colour under the caret.

  Case-insensitively, because the engine matches names that way: `%CasinoName%` and
  `%casinoname%` are one variable, and the panel shows the folded name the model gave it. }
procedure TSpxMainForm.VarFindRef(const AName: string);
var
  state: TSpxScanState;
  toks: TSpxTokenList;
  i, line, k: Integer;
  text_, want: string;
begin
  if (FEditor = nil) or (AName = '') then Exit;
  want := LowerCase(AName);
  state := Default(TSpxScanState);
  { A fresh line's state must start where the previous one ended -- a comment opened three
    lines up is still open -- so the whole document is walked in order rather than only the
    lines that might match. }
  toks := TSpxTokenList.Create;
  try
    for line := 0 to FEditor.Lines.Count - 1 do
    begin
      text_ := FEditor.Lines[line];
      toks.Clear;
      SpxScanLine(text_, state, toks);
      for i := 0 to toks.Count - 1 do
        if toks[i].Kind = sptVariable then
        begin
          { The token spans `%name%`; the name is what is between the markers. }
          k := toks[i].Length;
          if k < 2 then Continue;
          if LowerCase(Copy(text_, toks[i].Start + 1, k - 2)) = want then
          begin
            { Lines are 1-based for the editor, and the token's Start already is. }
            JumpToPos(line + 1, toks[i].Start, 0, 0);
            Exit;
          end;
        end;
    end;
  finally
    toks.Free;
  end;
  { Nothing found. It can happen honestly -- the panel keeps a value while the user is
    mid-edit, so a name can outlive its last reference by a debounce -- and a jump to nowhere
    is better left undone than guessed at. }
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
  { The two icon buttons say their name in a tooltip now, which is the only part of them a
    language changes. }
  FReroll.Hint := Tr(sReroll);
  FCopy.Hint := Tr(sCopy);
  FModes.SetCaption(0, Tr(sViewPage));
  FModes.SetCaption(1, Tr(sViewSource));
  FFindCase.Caption := Tr(sFindCase);
  { THE FIND BAR'S FOUR BUTTONS CARRY NO CAPTION AT ALL NOW -- they are icons, so the tooltip
    is the only text on them and the only thing a language can change. Missing them left the
    bar in the language it was built in while the rest of the window switched, which is
    exactly the silent half-translation this routine exists to prevent.

    And `FFindClose.Caption := Tr(sFindClose)` is GONE from here, which is not tidying: it was
    a leftover from when the close was a TButton, sFindClose is the literal 'x' in every table,
    and TSpeedButton draws its caption. Measured on the real 28x26 button -- 48 ink pixels with
    the glyph centred before, 72 spread over twice the columns after -- so one language switch
    put a stray letter beside the ✕ and shoved the glyph off-centre for the rest of the
    session. sFindClose stays in the table (a positional array does not lose an entry cheaply)
    and is now unread, like sLangEnglish beside it. }
  FFindOpen.Hint := Tr(sMenuFind);
  FFindPrev.Hint := Tr(sMenuFindPrev);
  FFindNext.Hint := Tr(sMenuFindNext);
  FFindClose.Hint := Tr(sClose);
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
  { AND THE TWO SENTENCES THE LAST RENDER LEFT BEHIND. The status bar and the fragment
    caption are written from the result rather than from a caption table, so they used to sit
    in the language of the render that produced them -- reported from a screenshot, an English
    window whose status bar still said "gültig · 23 ms" after a switch from German.

    They are rebuilt from the numbers, NOT by re-rendering. Asking for a render here was the
    first fix and it was worse than the bug: the seed tick is off by default, so every render
    draws a fresh variant, and a person who changed the interface language would be shown
    different text than the one they were reading. Measured -- three switches, three different
    previews. }
  ShowStatus;
  ShowPartial;
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
  { The window outlives the worker: closing the main form neither hides nor frees it, and the
    queue goes on draining after StopEngine has freed FEngine -- a shape this file has already
    been bitten by once, in StopEngine itself. Every caller here is a menu item or a keystroke
    that stays live in that window. }
  if FEngine = nil then Exit;
  Inc(FNextId);
  job.Id := FNextId;
  { DocText, not FEditor.Text: SynEdit joins its lines with the PLATFORM's ending, so on
    Windows the engine was handed a CRLF copy of a file that is LF on disk -- and the two do
    not render the same. A directive line ending in CRLF leaves its LF behind, one blank line
    per directive: measured on a real 116 KB template with a hundred and fifty `#set`s, one
    blank line as the file is, thirty-five once normalised to CRLF, and the source view then
    opens on a screenful of nothing. The preview must show what the FILE produces. }
  job.Text := DocText;
  { The family is the document's business, so this is where it is reconsidered. }
  UpdateEditorFont(job.Text);
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
  FPreview.SourceMode := FModes.ItemIndex = 1;
  { The menu's tick belongs to the switch, wherever the switch was moved from. }
  BuildMenu;
  SavePrefs;
end;

{ A DOUBLE CLICK ARRIVES IN THE MIDDLE OF A DRAG, so this only remembers that it happened.
  TControl.WMLButtonDBLCLK sends a mouse DOWN before it calls DblClick (control.inc:2591-2604)
  and the splitter's MouseDown starts a move (customsplitter.inc:609-621); the mouse-up that
  ends that move computes its offset as "where the pointer is now, less how far the splitter
  has travelled" (customsplitter.inc:576-587), so anything this handler set is measured as
  travel and subtracted straight back out.

  QUEUEING IT WAS NOT ENOUGH, and the reason is worth the line: TApplication.Idle drains the
  async queue BEFORE it waits for the next message (application.inc:470-487), so a queued call
  runs tens of milliseconds after the click and still long before a human lets go of the
  button. It only appeared to work because a probe that fires four messages back to back never
  lets the loop idle between them -- the burst hid the very gap the bug lives in. }
procedure TSpxMainForm.SplitEvenly(Sender: TObject);
begin
  FSplitEven := True;
end;

{ SplitMoved is where the division actually happens: OnMoved fires at the END of
  StopSplitterMove -- after FSplitDragging is cleared and after the revert described above
  (customsplitter.inc:583-588) -- so a width set there is the last word, with no assumption
  about timing at all. It runs on every drag, hence the flag. }

{ Show or hide one of SynEdit's gutter parts BY CLASS NAME. The gutter is a list whose order
  and membership are SynEdit's business, so a part is found rather than indexed -- and a name
  it does not have is not an error, only a part this build of SynEdit does not ship. }
procedure TSpxMainForm.GutterPart(AEditor: TSynEdit; const AClass: string; AVisible: Boolean);
var i: Integer;
begin
  for i := 0 to AEditor.Gutter.Parts.Count - 1 do
    if AEditor.Gutter.Parts[i].ClassName = AClass then
      AEditor.Gutter.Parts[i].Visible := AVisible;
end;

{ OnMoved fires at the END of StopSplitterMove -- after FSplitDragging is cleared and after
  the revert described above (customsplitter.inc:583-588) -- so a width set here is the last
  word, with no assumption about timing at all. It runs on every drag, hence the flag. }
{ The panel, brought back inside the window. A width that fitted when it was stored -- or when
  the window was bigger -- must not be applied as it stands: LCL gives an alLeft control the
  width it asks for and lets the alClient neighbour have what is left, which can be nothing.
  Called where the panel appears and whenever the window changes size, because those are the
  two moments the answer can change. }
procedure TSpxMainForm.ClampSlide;
var room, want: Integer;
begin
  if (FSlide = nil) or (FOuter = nil) or (FSlideSplit = nil) then Exit;
  { ONLY WHEN THE ROOM CHANGED, and this guard is the whole difference between a resizable
    panel and a frozen one. Without it: drag the handle, LCL sets the panel's width, that
    ripples into Resize, this runs and puts the width straight back -- so the cursor promised a
    drag and nothing moved. Measured, and measured again with a different stored width to be
    sure it was this and not the splitter: the panel snapped back to whatever was in the
    settings file. A drag does not change the room; only the window does. }
  if FOuter.ClientWidth = FSlideRoom then Exit;
  FSlideRoom := FOuter.ClientWidth;
  room := FOuter.ClientWidth - Px(Self, SPX_BODY_MIN) - FSlideSplit.Width;
  { A window too narrow for both still gets a usable panel: the panes are what give way --
    they can be scrolled, a list of variants cannot. }
  if room < Px(Self, SPX_SLIDE_MIN) then room := Px(Self, SPX_SLIDE_MIN);
  { THE TARGET IS THE WIDTH THE USER CHOSE, capped by what fits -- not merely "shrink if too
    wide". Only shrinking loses the choice for the rest of the session: this runs on every
    resize, including the small ones the window gets while it is still being built, so a panel
    squeezed once would never grow back even after the window did. Measured: with 900 stored
    it opened at 200 in a window with room for all of it. }
  want := Px(Self, FPrefs.SlideWidth);
  if want > room then want := room;
  if FSlide.Width <> want then FSlide.Width := want;
end;

{ THE EDITOR DOES NOT KEEP ITS WIDTH WHILE THE PREVIEW STARVES. FLeft is alLeft with a width
  of its own, so LCL never shrinks it when the body does -- it simply lets the alClient
  neighbour have what is left, which can be nothing. Measured: with the slide-out at 900 in a
  1300 px window the body was 351 and the editor still 528, so the preview had a negative
  width, which is to say none at all. }
procedure TSpxMainForm.ClampPanes;
var room, want: Integer;
begin
  if (FLeft = nil) or (FBody = nil) or (FSplit = nil) then Exit;
  { The same guard, and for the same reason: dragging the splitter between the panes changes
    FLeft's width, which ripples into Resize, and re-applying the fraction here would undo the
    drag exactly as it undid the slide-out's. }
  if FBody.ClientWidth = FPaneRoom then Exit;
  FPaneRoom := FBody.ClientWidth;
  room := FBody.ClientWidth - FSplit.Width - Px(Self, SPX_PANE_MIN);
  if room < Px(Self, SPX_PANE_MIN) then room := Px(Self, SPX_PANE_MIN);
  { THE TARGET IS THE FRACTION, capped by what fits -- not "shrink if too wide". Shrinking
    only was tried and was wrong for the same reason it was wrong for the slide-out: this runs
    on every resize, including the tiny ones a window gets while it is still being built, so
    the editor was squeezed to its minimum once and never grew back. Measured: 140 px of
    editor beside 691 of preview in a window with room for both. }
  want := Round((FBody.ClientWidth - FSplit.Width) * FPaneFraction);
  if want > room then want := room;
  if want < Px(Self, SPX_PANE_MIN) then want := Px(Self, SPX_PANE_MIN);
  if FLeft.Width <> want then
  begin
    FLeft.Width := want;
    { THE STRIP IS LAID OUT AGAIN BECAUSE THE EDITOR JUST MOVED, and the find bar ends where
      the editor does. Ordering is the whole point: LayoutTopStrip runs from FTop.OnResize,
      which fires while the form is resizing -- BEFORE this re-proportions the panes -- so on
      its own it reads the width the editor had a moment ago. Measured with the bar open,
      1600 -> 1200 wide: the editor ended at 552 and the close button at 744, a hundred and
      ninety pixels into the preview. Shrinking only looked correct by accident, because the
      two-row fallback changes FTop.Height and that fires OnResize a second time.

      This cannot loop: it changes the strip's HEIGHT at most, and the guard above compares
      the body's WIDTH. }
    LayoutTopStrip;
  end;
end;

{ The panel's new width, kept. OnMoved rather than OnChangeBounds: it fires once when the
  drag ends, not on every pixel of it. }
procedure TSpxMainForm.SlideResized(Sender: TObject);
begin
  if FLoading or (FSlide = nil) then Exit;
  { WRITTEN IN 96-DPI UNITS, because that is what ApplyPrefs scales back up. Storing the
    measured width would grow the panel by half on every launch on a 150% display -- Px would
    be scaling a number that had already been scaled. }
  FPrefs.SlideWidth := Un96(Self, FSlide.Width);
  SavePrefs;
end;

{ Half the body each, less the splitter between them. Not half the WINDOW: the rail and the
  slide-out have already taken their share, and the two panes divide what is left of the body
  they share. Called by the menu item directly -- there is no drag in progress there -- and by
  SplitMoved when a double click asked for it. }
procedure TSpxMainForm.SplitEvenNow(Sender: TObject);
var body: Integer;
begin
  if (FLeft = nil) or (FBody = nil) or (FSplit = nil) then Exit;
  body := FBody.ClientWidth - FSplit.Width;
  if body <= 0 then Exit;
  FLeft.Width := body div 2;
  FPaneFraction := FLeft.Width / body;
  { The panes moved without a drag -- the even-panes icon or the splitter's double click --
    and the bar's right edge follows the editor either way. }
  LayoutTopStrip;
end;

procedure TSpxMainForm.SplitMoved(Sender: TObject);
var body: Integer;
begin
  if (FLeft = nil) or (FBody = nil) or (FSplit = nil) then Exit;
  if FSplitEven then
  begin
    FSplitEven := False;
    SplitEvenNow(Sender);
    Exit;
  end;
  { However it was dragged, this is now the division to keep through a resize. }
  body := FBody.ClientWidth - FSplit.Width;
  if body > 0 then FPaneFraction := FLeft.Width / body;
  { AND THE FIND BAR, which now ends where the editor does. Nothing else would tell it: the
    strip is alTop and its WIDTH does not change when the splitter moves, so its OnResize --
    the only thing that lays the strip out -- never fires for this. Measured: without this the
    bar kept the bounds it had before the drag, which is the same wrong place the user
    reported, just arrived at differently.

    At the END of the drag rather than during it, like FPaneFraction above: LayoutTopStrip can
    change the strip's HEIGHT (the two-row fallback), which resizes the body, which would feed
    back into a live drag. }
  LayoutTopStrip;
end;

{ ── THE SETTINGS FILE ─────────────────────────────────────────────────────────────────── }

{ The window, moved to match what was loaded. The language is already applied (the constructor
  does it before any caption exists); everything else needs the controls, so it happens here. }
procedure TSpxMainForm.ApplyPrefs;
begin
  if FPrefs.RailRight then FRail.Side := spxRailRight else FRail.Side := spxRailLeft;
  FSlide.Width := Px(Self, FPrefs.SlideWidth);
  FModes.ItemIndex := Ord(FPrefs.PreviewSource);
  { SetItemIndex only fires OnChange when the value MOVES, so the preview is told directly
    rather than relying on that. }
  FPreview.SourceMode := FPrefs.PreviewSource;
  if FPrefs.Panel >= 0 then
  begin
    FRail.SetDown(FPrefs.Panel, True);
    ShowPanel(FPrefs.Panel, True);
  end
  else
  begin
    FRail.SetDown(0, False);
    ShowPanel(0, False);
  end;
  ApplyTheme;
  ApplyEditorFont;
  { Follow mode was RESTORED by the constructor and has not been RESOLVED: it means "take the
    language from the document", and only this asks the locale box what the document says.
    Without it the window came back in the language stored last time WITH follow ticked and
    the locale box on something else -- the one combination follow mode exists to prevent. }
  if FLangFollow then ApplyLangMode;
  BuildMenu;
end;

{ The window, read back and written down. Called from every place that changes one of these,
  and doing nothing while the window is still being built. }
procedure TSpxMainForm.SavePrefs;
begin
  if FLoading then Exit;
  { LANG IS NOT CAPTURED HERE, and that is the whole point of it. An empty code means "the
    language of the desktop", and FLangChosen is seeded from the desktop whether or not anyone
    ever chose anything -- so writing it back on every unrelated save would turn the first
    click on a theme into a permanent language choice nobody made. Only LangPicked and
    LangFollowClicked, which ARE choices, write those two. }
  FPrefs.RailRight := (FRail <> nil) and (FRail.Side = spxRailRight);
  FPrefs.PreviewSource := (FModes <> nil) and (FModes.ItemIndex = 1);
  if (FBottom <> nil) and FBottom.Visible then FPrefs.Panel := FBottom.PageIndex
  else FPrefs.Panel := -1;
  SpxSavePrefs(FPrefs);
end;

{ ── THE EDITOR'S LOOK ──────────────────────────────────────────────────────────────────── }

procedure TSpxMainForm.ApplyTheme;
var pal: TSpxPalette; i: Integer;
begin
  pal := SpxPalette(FPrefs.Theme);
  FHighlighter.ApplyPalette(pal);
  FEditor.Color := pal.Back;
  FEditor.Font.Color := pal.Text;
  FEditor.Gutter.Color := pal.Gutter;
  { EVERY PART, not just the numbers. A part left alone keeps its system colour and stays
    light on a dark page -- which is exactly how the marks column announced itself. The ones
    this app hides cannot show it, but a part turned on later would, and this is the line that
    would have to be remembered. }
  for i := 0 to FEditor.Gutter.Parts.Count - 1 do
  begin
    FEditor.Gutter.Parts[i].MarkupInfo.Background := pal.Gutter;
    FEditor.Gutter.Parts[i].MarkupInfo.Foreground := pal.GutterText;
  end;
  FEditor.SelectedColor.Background := pal.Sel;
  FEditor.SelectedColor.Foreground := pal.SelText;
  { The matching-bracket overlay is invisible on a dark page with its default (a frame in the
    text colour), so the theme gives it one -- and ASSIGNS IT EITHER WAY. Skipping the light
    table because its values are clNone was the bug: clNone is a real value meaning "no colour
    of my own", which is exactly what the light theme wants, and skipping it left the pair
    painted dark grey on a white page for the rest of the session. Only a restart cleared it,
    which is why a two-process probe could not see it. }
  FBracket.MarkupInfo.Background := pal.BracketBack;
  FBracket.MarkupInfo.Foreground := pal.BracketText;
  FPreview.ApplyTheme(pal);
  if FSlide <> nil then FSlide.ApplyTheme(pal);
  FEditor.Invalidate;
end;

{ Which family to draw this document in: the one the user named if the machine can honour it,
  otherwise the first in the cascade that can actually draw what is on screen. Cached against
  the SAMPLE rather than against the text, so typing does not re-probe eight families -- the
  sample of a Latin document does not change when a Latin word is added to it. }
function TSpxMainForm.ChosenFamily: string;
begin
  Result := ChosenFamilyFor(DocText);
end;

{ The same question against a copy of the document the caller already has. RequestRender has
  one; going through DocText there would materialise the whole template a second time on every
  keystroke burst, which for a megabyte is not free. }
function TSpxMainForm.ChosenFamilyFor(const AText: string): string;
var sample: string;
begin
  sample := SpxFontSample(AText);
  if (sample <> FFontSample) or (FPrefs.FontFamily <> FFontManual) then
  begin
    FFontSample := sample;
    FFontManual := FPrefs.FontFamily;
    FFontChosen := SpxChooseEditorFont(FPrefs.FontFamily, sample, SPX_EDITOR_FONTS,
                                       @SpxFontCanDraw);
  end;
  Result := FFontChosen;
end;

{ EVERY EDITOR AT ONCE, and only the editors: the chrome keeps the desktop's font. The three
  are the template, the source view and the group editor's list -- a fourth would join here. }
{ Called on every render with the text that is about to be rendered: a template that gains a
  line of Japanese needs a family that can draw it, and nothing else in the window would notice.
  Costs a scan of the document and, only when the SAMPLE changed, eight probes -- adding a
  Latin word to a Latin document changes neither. }
procedure TSpxMainForm.UpdateEditorFont(const AText: string);
var want: string;
begin
  want := ChosenFamilyFor(AText);
  { AGAINST THE EDITOR, not against the memo the line above just refreshed -- see the menu's
    caption for what reading the memo here cost. An empty answer means no installed family can
    draw this document, and then the editors keep what they have: applying '' would change
    nothing and asking again on every keystroke would only re-probe eight families for it. }
  if (want <> '') and (want <> FEditor.Font.Name) then
  begin
    ApplyEditorFont;
    { The View menu names the family in use, so it has to be rebuilt when the family moves --
      otherwise it goes on naming the one the document outgrew. Only on a real change: a
      document does not change script on most keystrokes. }
    BuildMenu;
  end;
end;

procedure TSpxMainForm.ApplyEditorFont;
var pt: Integer; family: string;
begin
  pt := SpxClampEditorSize(FPrefs.FontSize);
  family := ChosenFamily;
  SpxApplyEditorFont(FEditor.Font, family, pt);
  FPreview.ApplyEditorFont(family, pt);
  if FSlide <> nil then FSlide.ApplyEditorFont(family, pt);
end;

{ Zoom is the SYSTEM size plus a number of steps, so a person who runs a large desktop font
  starts large. The step is clamped where it is stored (SpxSettings) and the resulting point
  size again where it is computed (SpxUi) -- a settings file edited by hand cannot make the
  editor unusable. }
procedure TSpxMainForm.ZoomEditor(ASteps: Integer);
var want: Integer;
begin
  { POINTS NOW, not steps from the desktop's caption size -- so a notch of the wheel is one
    point and the number in the settings file is the number on screen. }
  want := SpxClampEditorSize(FPrefs.FontSize + ASteps);
  if want = FPrefs.FontSize then Exit;
  FPrefs.FontSize := want;
  ApplyEditorFont;
  SavePrefs;
end;

procedure TSpxMainForm.ZoomInClicked(Sender: TObject);
begin
  ZoomEditor(1);
end;

procedure TSpxMainForm.ZoomOutClicked(Sender: TObject);
begin
  ZoomEditor(-1);
end;

{ Back to the EDITOR's default, not to the desktop's caption size: that is the whole point of
  the editor having a font policy of its own. }
procedure TSpxMainForm.ZoomResetClicked(Sender: TObject);
begin
  FPrefs.FontSize := SPX_EDITOR_SIZE;
  ApplyEditorFont;
  SavePrefs;
end;

{ Ctrl+wheel, which is what every editor does and what a hand reaches for before it looks for
  a menu. Handled := True keeps the wheel from ALSO scrolling the document. }
procedure TSpxMainForm.EditorMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if not (ssCtrl in Shift) then Exit;
  if WheelDelta > 0 then ZoomEditor(1) else ZoomEditor(-1);
  Handled := True;
end;

procedure TSpxMainForm.ThemeLightClicked(Sender: TObject);
begin
  FPrefs.Theme := spxThemeLight;
  ApplyTheme;
  BuildMenu;
  SavePrefs;
end;

procedure TSpxMainForm.ThemeDarkClicked(Sender: TObject);
begin
  FPrefs.Theme := spxThemeDark;
  ApplyTheme;
  BuildMenu;
  SavePrefs;
end;

{ The menu's way to the same three panels. It always OPENS -- a menu item that closed the
  panel it names would be a surprise; the rail's tool is where collapsing lives. }
procedure TSpxMainForm.MenuDiagClicked(Sender: TObject);
begin
  FRail.SetDown(0, True);
  ShowPanel(0, True);
end;

procedure TSpxMainForm.MenuVarsClicked(Sender: TObject);
begin
  FRail.SetDown(1, True);
  ShowPanel(1, True);
end;

procedure TSpxMainForm.MenuSetClicked(Sender: TObject);
begin
  FRail.SetDown(2, True);
  ShowPanel(2, True);
end;

{ The panel's own close button, and Escape from inside it. The rail's tool still toggles --
  this is the second way out, which a slide-out needs and did not have. }
procedure TSpxMainForm.GroupPaneClosed(Sender: TObject);
begin
  FSlide.Visible := False;
  FSlideSplit.Visible := False;
  { And closing it gives the room back. }
  FPaneRoom := -1;
  ClampPanes;
  { The rail's tool is a latch now, and it can be put out from here -- by the panel's X or by
    Escape -- as well as by clicking it. }
  FRail.SetDown(3, False);
  { Back to the document: a panel that closes and leaves the focus nowhere means the next
    keystroke goes to whatever LCL picks. }
  { CanSetFocus, not CanFocus: the pair CanFocus/SetFocus is what LCL's own header warns
    against (wincontrol.inc:3719-3727) -- CanFocus stops at the form and never asks whether
    the form itself can take it. The rest of this file already uses CanSetFocus. }
  if FEditor.CanSetFocus then FEditor.SetFocus;
end;

{ Auto: the cascade decides, per document. }
procedure TSpxMainForm.FontAutoClicked(Sender: TObject);
begin
  FPrefs.FontFamily := '';
  ApplyEditorFont;
  BuildMenu;
  SavePrefs;
end;

{ A family the user named. It still goes through the chooser, which will fall back if this
  machine stops being able to honour it -- an editor drawing boxes is worse than one drawing
  the second choice. }
procedure TSpxMainForm.FontPicked(Sender: TObject);
begin
  if not (Sender is TMenuItem) then Exit;
  FPrefs.FontFamily := TMenuItem(Sender).Caption;
  ApplyEditorFont;
  BuildMenu;
  SavePrefs;
end;

procedure TSpxMainForm.ModePageClicked(Sender: TObject);
begin
  FModes.ItemIndex := 0;
end;

procedure TSpxMainForm.ModeSourceClicked(Sender: TObject);
begin
  FModes.ItemIndex := 1;
end;

{ A selection CAN render to nothing -- a directive-only line, or one that opens a comment --
  and the two empty panes look identical, so the pane says which of them this is. The test
  for "nothing" is editor-core's (SpxIsBlankOutput), because "blank" is more than ASCII
  space: the engine's own line model counts U+2028 and U+2029 too. }
procedure TSpxMainForm.SayPartial(const AHtml: string; APartial: Boolean);
begin
  FPartialShown := APartial;
  { WHICH of the two sentences, not the sentence itself: a language switch rebuilds it from
    this, the same way the status bar is rebuilt from its numbers. }
  FPartialEmpty := APartial and SpxIsBlankOutput(AHtml);
  ShowPartial;
end;

procedure TSpxMainForm.ShowPartial;
begin
  if FPartial = nil then Exit;
  FPartial.Visible := FPartialShown;
  if not FPartialShown then Exit;
  if FPartialEmpty then
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
  FVars.SetIncludes(Res.Includes, Res.HaveSet);
  FErrorMarkup.SetMarks(Res.Marks);
  FWarnMarkup.SetMarks(Res.Marks);
  FEditor.Invalidate;

  FHaveResult := True;
  FResErrors := Res.Errors;
  FResWarnings := Res.Warnings;
  FResNotes := Res.Notes;
  FResElapsed := Res.Elapsed;
  ShowStatus;
end;

{ The verdict, in the language of the moment. Called by the render that produced the numbers
  and again by a language switch -- which must NOT re-render to get this sentence: the seed
  tick is off by default, so every render draws a fresh variant and a person who changed the
  interface language would be handed different text than the one they were reading. Measured:
  three switches, three different previews. The numbers are the only thing worth keeping. }
procedure TSpxMainForm.ShowStatus;
var s: string;
begin
  if FStatus = nil then Exit;
  if not FHaveResult then
  begin
    FStatus.SimpleText := Tr(sStatusReady);
    Exit;
  end;
  if FResErrors > 0 then s := Format(Tr(sStatusErrors), [FResErrors])
  else if FResWarnings > 0 then s := Format(Tr(sStatusWithWarnings), [FResWarnings])
  else s := Tr(sStatusValid);
  if FResNotes > 0 then s := s + Format(Tr(sStatusNotes), [FResNotes]);
  FStatus.SimpleText := Format(Tr(sStatusElapsed), [s, FResElapsed]);
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
