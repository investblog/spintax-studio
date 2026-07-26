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
  SynEdit, SynEditWrappedView, SynEditMarkup, SynEditMarkupBracket,
  SpxEngineThread, SpxSynHighlighter, SpxBracketMarkup, SpxDiagMarkup, SpxPreviewPane,
  SpxFiles, SpxDemo;

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
  fileMenu: TMenuItem;
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

  Self.Menu := bar;
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

  FPreview.SetContent(Res.Preview);
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
  { The worker is a thread, not an owned component, so nothing would free it on a path that
    reaches the destructor without OnClose. No such path exists today -- this is the form
    owning what it created rather than trusting one event to fire. }
  StopEngine;
  inherited Destroy;
end;

end.
