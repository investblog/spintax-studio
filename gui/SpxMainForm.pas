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
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Menus, Dialogs,
  Clipbrd, Graphics,
  SynEdit, SynEditTypes, SynEditWrappedView, SynEditMarkup, SynEditMarkupBracket,
  SpxStudio, SpxEngineThread, SpxSynHighlighter, SpxBracketMarkup, SpxDiagMarkup,
  SpxPreviewPane, SpxVarsPane, SpxFiles, SpxDemo;

type
  TSpxMainForm = class(TForm)
  private
    FTop: TPanel;
    FLocale: TComboBox;
    FSeeded: TCheckBox;
    FSeedEdit: TEdit;
    FReroll: TButton;
    FCopy: TButton;
    FSplit: TSplitter;
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
    FDiagSplit: TSplitter;
    FRows: TSpxPanelRows;
    FRowSig: string;
    FPendingRow: TSpxPanelRow;
    { What a jump left behind, so the preview does not narrow to it: going to look at an
      error must not replace the document's preview with a render of the broken span. The
      rule that reads this lives in editor-core, where it is gated. }
    FJump: TSpxJumpState;
    procedure DiagColumn(const ACaption: string; AWidth: Integer);
    procedure DiagClicked(Sender: TObject);
    procedure JumpDeferred(Data: PtrInt);
    procedure VarJump(Line, Column: Integer);
    procedure RuntimeChanged(Sender: TObject);
    procedure SelectionChanged(Sender: TObject; Changes: TSynStatusChanges);
    procedure WrapSelection(const L, R: string);
    function CurrentSelection(WithText: Boolean): TSpxSelection;
    procedure WrapBracesClicked(Sender: TObject);
    procedure WrapBracketsClicked(Sender: TObject);
    procedure JumpToPos(Line, Column, EndLine, EndColumn: Integer);
    procedure ShowRows(const ARows: TSpxPanelRows);
    procedure JumpTo(Row: TSpxPanelRow);
    function LineOf(N: Integer): string;
    procedure BuildUi;
    procedure BuildMenu;
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
    procedure DebounceFired(Sender: TObject);
    procedure RerollClicked(Sender: TObject);
    procedure CopyClicked(Sender: TObject);
    procedure JobDone(const Res: TSpxJobResult);
    procedure RequestRender;
    procedure StopEngine;
    procedure FormClosed(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
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
  FPath := '';
  FEol := SPX_DEFAULT_EOL;
  FTrailingEol := True;
  BuildUi;
  UpdateCaption;
  FNextId := 0;
  FLastShown := -1;
  FEngine := TSpxEngineThread.Create(@JobDone);
  { `spintax-studio path\to\file.spintax` -- what a double-click in Explorer sends once the
    extension is associated, and the only way to open a document without a dialog. }
  if (ParamCount >= 1) and FileExists(ParamStr(1)) then LoadDocument(ParamStr(1))
  else RequestRender;
end;

procedure TSpxMainForm.BuildUi;
var
  sheetDiag, sheetVars: TTabSheet;
begin
  Width := 1100;
  Height := 700;
  Position := poScreenCenter;
  OnClose := @FormClosed;
  OnCloseQuery := @FormAsked;
  BuildMenu;

  FTop := TPanel.Create(Self);
  FTop.Parent := Self;
  FTop.Align := alTop;
  FTop.Height := 38;
  FTop.BevelOuter := bvNone;

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
  FLocale.SetBounds(8, 7, 70, 24);
  FLocale.OnChange := @SettingChanged;

  FSeeded := TCheckBox.Create(Self);
  FSeeded.Parent := FTop;
  FSeeded.Caption := 'seed';
  FSeeded.SetBounds(90, 9, 55, 22);
  FSeeded.OnChange := @SettingChanged;

  FSeedEdit := TEdit.Create(Self);
  FSeedEdit.Parent := FTop;
  FSeedEdit.Text := '1';
  FSeedEdit.SetBounds(145, 7, 70, 24);
  FSeedEdit.OnChange := @SettingChanged;

  FReroll := TButton.Create(Self);
  FReroll.Parent := FTop;
  FReroll.Caption := 'Reroll';
  FReroll.SetBounds(228, 6, 80, 26);
  FReroll.OnClick := @RerollClicked;

  FCopy := TButton.Create(Self);
  FCopy.Parent := FTop;
  FCopy.Caption := 'Copy';
  FCopy.SetBounds(314, 6, 80, 26);
  FCopy.OnClick := @CopyClicked;

  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := True;
  FStatus.SimpleText := 'готов';

  { The bottom strip, created before the two panes so it owns that space and they divide
    what is left. Two tabs rather than two more panels: the window is already a two-pane
    editor, and every strip added to it is taken from the template. }
  FBottom := TPageControl.Create(Self);
  FBottom.Parent := Self;
  FBottom.Align := alBottom;
  FBottom.Height := 170;
  sheetDiag := FBottom.AddTabSheet;
  sheetDiag.Caption := 'Диагностика';
  sheetVars := FBottom.AddTabSheet;
  sheetVars.Caption := 'Переменные';

  { What a squiggle cannot show: a finding inside an included file, and one the engine could
    not place at all. }
  FDiag := TListView.Create(Self);
  FDiag.Parent := sheetDiag;
  FDiag.Align := alClient;
  FDiag.ViewStyle := vsReport;
  FDiag.ReadOnly := True;
  FDiag.RowSelect := True;
  FDiag.HideSelection := False;
  DiagColumn('Уровень', 110);
  DiagColumn('Файл', 130);
  DiagColumn('Место', 70);
  DiagColumn('Сообщение', 640);
  FDiag.OnClick := @DiagClicked;

  { The variables panel: what the document defines, and what this session supplies. }
  FVars := TSpxVarsPane.Create(Self);
  FVars.Parent := sheetVars;
  FVars.Align := alClient;
  FVars.OnJump := @VarJump;
  FVars.OnRuntimeChanged := @RuntimeChanged;

  FDiagSplit := TSplitter.Create(Self);
  FDiagSplit.Parent := Self;
  FDiagSplit.Align := alBottom;

  FEditor := TSynEdit.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := alLeft;
  FEditor.Width := 540;
  FEditor.Font.Name := 'Consolas';
  FEditor.Font.Size := 11;
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
  FSplit.Parent := Self;
  FSplit.Align := alLeft;
  FSplit.Left := FEditor.Width + 1;

  { Two views of the same output -- the page and the HTML it is -- with the switch and the
    size guard owned by the pane itself (SpxPreviewPane, ADR 0004). }
  FPreview := TSpxPreviewPane.Create(Self);
  FPreview.Parent := Self;
  FPreview.Align := alClient;

  FDebounce := TTimer.Create(Self);
  FDebounce.Enabled := False;
  FDebounce.Interval := DEBOUNCE_MS;
  FDebounce.OnTimer := @DebounceFired;
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
  fileMenu, editMenu: TMenuItem;
begin
  bar := TMainMenu.Create(Self);
  fileMenu := TMenuItem.Create(Self);
  fileMenu.Caption := 'Файл';
  bar.Items.Add(fileMenu);

  Item(fileMenu, 'Создать', Ord('N'), [ssCtrl], @NewClicked);
  Item(fileMenu, 'Открыть…', Ord('O'), [ssCtrl], @OpenClicked);
  Item(fileMenu, 'Сохранить', Ord('S'), [ssCtrl], @SaveClicked);
  Item(fileMenu, 'Сохранить как…', Ord('S'), [ssCtrl, ssShift], @SaveAsClicked);
  Item(fileMenu, '-', 0, [], nil);
  { The set is read when the document is opened or saved, not on every keystroke. A fragment
    changed by another program is therefore invisible until this is used -- which is why the
    command exists rather than a silent rescan the user cannot ask for. }
  Item(fileMenu, 'Перечитать набор', 0, [], @ReloadSetClicked);
  Item(fileMenu, '-', 0, [], nil);
  Item(fileMenu, 'Выход', 0, [], @ExitClicked);

  { Every key action gets a place in a menu, not only a shortcut: a hotkey nobody can find
    is a hotkey nobody uses. }
  editMenu := TMenuItem.Create(Self);
  editMenu.Caption := 'Правка';
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
  Item(editMenu, 'Обернуть выделение в {…}', Ord('G'), [ssCtrl, ssShift], @WrapBracesClicked);
  Item(editMenu, 'Обернуть выделение в […]', Ord('P'), [ssCtrl, ssShift], @WrapBracketsClicked);
  Item(editMenu, '-', 0, [], nil);
  Item(editMenu, 'Показать другой вариант', Ord('R'), [ssCtrl], @RerollClicked);
  Item(editMenu, 'Скопировать результат', Ord('C'), [ssCtrl, ssShift], @CopyClicked);

  Self.Menu := bar;
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
      if ARows[i].Source = spxRowStudio then level := 'заметка Studio'
      else if ARows[i].Severity = 'error' then level := 'ошибка'
      else if ARows[i].Severity = 'warning' then level := 'предупреждение'
      else level := ARows[i].Severity;

      if ARows[i].Slug = '' then name_ := 'документ' else name_ := ARows[i].Slug;
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
  FEditor.LogicalCaretXY := Point(col, Line);
  FJump.Valid := False;
  if (EndLine >= Line) and (EndColumn > 0) then
  begin
    FEditor.BlockBegin := Point(col, Line);
    FEditor.BlockEnd := Point(SpxByteColumn(LineOf(EndLine), EndColumn), EndLine);
    { Recorded AFTER the block is set, so the selection event that assignment fires sees the
      state still invalid and cannot clear what has not been written yet. }
    FJump.Range := CurrentSelection(False).Range;
    FJump.Valid := True;
  end;
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
procedure TSpxMainForm.SelectionChanged(Sender: TObject; Changes: TSynStatusChanges);
begin
  if not (scSelection in Changes) then Exit;
  { Loading a document reports scTextCleared -- which is a SET, not a flag, and carries
    scSelection inside it -- and that path has already asked for its own render. }
  if scTextCleared <= Changes then Exit;

  { The policy decides whether a jump's selection is still the jump's; here only the STATE
    it returns is kept. Without this call the flag outlives its meaning -- after the user
    moves away and later selects the same span by hand, that manual selection would still be
    treated as the jump's -- and this is the moment that sees the difference, which a single
    look at render time cannot. The selected TEXT is not fetched: dragging fires this
    continuously and copying a large selection each time would be paid for nothing. }
  SpxPreviewFragment(CurrentSelection(False), FJump, FJump);

  FDebounce.Enabled := False;
  FDebounce.Enabled := True;
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
  if FPath = '' then shown := 'Без имени' else shown := ExtractFileName(FPath);
  if FEditor.Modified then shown := shown + ' *';
  Caption := shown + ' — Spintax Studio';
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
      dlg.Title := 'Сохранить шаблон';
      dlg.Filter := 'Шаблоны spintax|*' + SPX_EXT + '|Все файлы|*.*';
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
  case MessageDlg('Сохранить изменения?', mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes: Result := SaveDocument(False);
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

procedure TSpxMainForm.NewClicked(Sender: TObject);
begin
  if not AskSave then Exit;
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
    dlg.Title := 'Открыть шаблон';
    dlg.Filter := 'Шаблоны spintax|*' + SPX_EXT + '|Все файлы|*.*';
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
end;

procedure TSpxMainForm.SettingChanged(Sender: TObject);
begin
  RequestRender;
end;

procedure TSpxMainForm.DebounceFired(Sender: TObject);
begin
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
  job.Text := FEditor.Text;
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
  job.Fragment := SpxPreviewFragment(CurrentSelection(True), FJump, FJump);
  FEngine.Post(job);
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

  FPreview.SetContent(Res.Preview, Res.Partial);
  ShowRows(Res.Rows);
  FVars.SetModel(Res.Vars);
  FErrorMarkup.SetMarks(Res.Marks);
  FWarnMarkup.SetMarks(Res.Marks);
  FEditor.Invalidate;

  if Res.Errors > 0 then s := Format('%d ошибок', [Res.Errors])
  else if Res.Warnings > 0 then s := Format('валидно, %d предупреждений', [Res.Warnings])
  else s := 'валидно';
  if Res.Notes > 0 then s := s + Format(' · %d заметок', [Res.Notes]);
  FStatus.SimpleText := Format('%s · %d мс', [s, Res.Elapsed]);
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
