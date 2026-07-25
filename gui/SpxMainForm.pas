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
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Clipbrd, Graphics,
  SynEdit, SpxEngineThread;

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
    FPreview: TMemo;
    FStatus: TStatusBar;
    FDebounce: TTimer;
    FEngine: TSpxEngineThread;
    FNextId: Int64;
    FLastShown: Int64;
    procedure BuildUi;
    procedure EditorChanged(Sender: TObject);
    procedure SettingChanged(Sender: TObject);
    procedure DebounceFired(Sender: TObject);
    procedure RerollClicked(Sender: TObject);
    procedure CopyClicked(Sender: TObject);
    procedure JobDone(const Res: TSpxJobResult);
    procedure RequestRender;
    procedure FormClosed(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  MainForm: TSpxMainForm;

implementation

const
  DEBOUNCE_MS = 200;   // long enough to skip a burst of typing, short enough to feel live

constructor TSpxMainForm.Create(AOwner: TComponent);
begin
  { CreateNew, not Create: there is no .lfm resource to load. }
  inherited CreateNew(AOwner);
  BuildUi;
  FNextId := 0;
  FLastShown := -1;
  FEngine := TSpxEngineThread.Create(@JobDone);
  RequestRender;
end;

procedure TSpxMainForm.BuildUi;
begin
  Caption := 'Spintax Studio';
  Width := 1100;
  Height := 700;
  Position := poScreenCenter;
  OnClose := @FormClosed;

  FTop := TPanel.Create(Self);
  FTop.Parent := Self;
  FTop.Align := alTop;
  FTop.Height := 38;
  FTop.BevelOuter := bvNone;

  FLocale := TComboBox.Create(Self);
  FLocale.Parent := FTop;
  FLocale.Style := csDropDownList;
  FLocale.Items.CommaText := 'ru,uk,be,en,de,fr,es,sr,hr,bs';
  FLocale.ItemIndex := 0;
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
  FEditor.Text :=
    '#set %бренд% = Акме' + LineEnding +
    LineEnding +
    '{Привет|Здравствуйте}, %бренд%! ' +
    '{Мы|Наша команда} {предлагаем|даём} [лучшее|решение|сегодня].';
  FEditor.OnChange := @EditorChanged;

  FSplit := TSplitter.Create(Self);
  FSplit.Parent := Self;
  FSplit.Align := alLeft;
  FSplit.Left := FEditor.Width + 1;

  FPreview := TMemo.Create(Self);
  FPreview.Parent := Self;
  FPreview.Align := alClient;
  FPreview.ReadOnly := True;
  FPreview.ScrollBars := ssAutoVertical;
  FPreview.WordWrap := True;
  FPreview.Font.Name := 'Segoe UI';
  FPreview.Font.Size := 11;
  FPreview.Color := clWindow;

  FDebounce := TTimer.Create(Self);
  FDebounce.Enabled := False;
  FDebounce.Interval := DEBOUNCE_MS;
  FDebounce.OnTimer := @DebounceFired;
end;

procedure TSpxMainForm.EditorChanged(Sender: TObject);
begin
  { Restart the window on every keystroke: the render that matters is the one after the
    user stops. }
  FDebounce.Enabled := False;
  FDebounce.Enabled := True;
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
  Clipboard.AsText := FPreview.Text;
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

  FPreview.Text := Res.Preview;

  if Res.Errors > 0 then s := Format('%d ошибок', [Res.Errors])
  else if Res.Warnings > 0 then s := Format('валидно, %d предупреждений', [Res.Warnings])
  else s := 'валидно';
  if Res.Notes > 0 then s := s + Format(' · %d заметок', [Res.Notes]);
  FStatus.SimpleText := Format('%s · %d мс', [s, Res.Elapsed]);
end;

procedure TSpxMainForm.FormClosed(Sender: TObject; var CloseAction: TCloseAction);
begin
  FEngine.Shutdown;
  FEngine.WaitFor;
  FreeAndNil(FEngine);
end;

end.
