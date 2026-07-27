(*
 * SpxVariantsPane -- the "Варианты / Экспорт" tab: generate a set, look at it, write it out
 * (spec §4.6).
 *
 * WIRING ONLY. Every decision this panel appears to make lives in editor-core and is gated
 * by the console suite: which variants are near-duplicates (SpxDedupe), what a seed is worth
 * (SpxRenderBatch's derivation), and what each file format does with a variant that has line
 * breaks in it (SpxExport). What is here is the arrangement of that on screen -- a form the
 * suite cannot reach, so it holds nothing that could be wrong about spintax.
 *
 * THE BATCH IS A LONG JOB, and the panel is built around that rather than around a call. It
 * asks the form to start one, receives a message per rendered variant, and can stop it: with
 * the default budget a batch is up to 3N renders, measured at 61 seconds for N = 200, and a
 * window that goes away for a minute with nothing to look at is a window that has crashed as
 * far as anyone can tell.
 *
 * A SET SURVIVES THE DOCUMENT CHANGING. Editing the template does not clear the list -- the
 * variants that are there were produced by the text as it was, and their seeds still name
 * them. The panel says the set is stale rather than deleting the author's work; what the
 * export writes is what the list holds.
 *)
unit SpxVariantsPane;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, ComCtrls, Grids, Spin, Dialogs,
  Graphics, FileUtil,
  Spintax, SpxStudio, SpxDedupe, SpxExport, SpxEngineThread;

type
  { What the panel needs from the form to start a batch. The form owns the document, the
    locale and the session values; the panel owns N, the seed and the dedup settings. }
  TSpxGenerateEvent = procedure(Count: Integer; SeedBase: LongWord;
    const Opts: TSpxDedupeOpts) of object;
  TSpxShowVariantEvent = procedure(const Text: string) of object;

  TSpxVariantsPane = class(TPanel)
  private
    FTop: TPanel;
    FCountLabel: TLabel;
    FCount: TSpinEdit;
    FSeedLabel: TLabel;
    FSeed: TSpinEdit;
    FRandomSeed: TCheckBox;
    FGo: TButton;
    FStop: TButton;
    FProgress: TLabel;

    FOpts: TPanel;
    FDedupe: TCheckBox;
    FShingleLabel: TLabel;
    FShingle: TSpinEdit;
    FThresholdLabel: TLabel;
    FThreshold: TTrackBar;
    FThresholdValue: TLabel;

    FGrid: TStringGrid;

    FBottom: TPanel;
    FToXlsx: TButton;
    FToTxt: TButton;
    FToFiles: TButton;
    FWithSeed: TCheckBox;
    FStatus: TLabel;

    FVariants: TSpxVariantList;
    FReport: TSpxBatchReport;
    FRunning: Boolean;
    FStale: Boolean;
    FStalePending: Boolean;
    FOnGenerate: TSpxGenerateEvent;
    FOnCancel: TNotifyEvent;
    FOnShowVariant: TSpxShowVariantEvent;

    procedure GoClicked(Sender: TObject);
    procedure StopClicked(Sender: TObject);
    procedure ThresholdChanged(Sender: TObject);
    procedure DedupeToggled(Sender: TObject);
    procedure RandomSeedToggled(Sender: TObject);
    procedure RowClicked(Sender: TObject);
    procedure ExportXlsx(Sender: TObject);
    procedure ExportTxt(Sender: TObject);
    procedure ExportFiles(Sender: TObject);
    procedure AddRow(const V: TSpxVariant);
    procedure UpdateButtons;
    procedure SayProgress;
    procedure SayReport(ACancelled: Boolean);
    function Options: TSpxDedupeOpts;
    procedure FitGrid;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { One step of a running batch, straight from the worker. }
    procedure BatchProgress(const P: TSpxBatchProgress);
    { The document changed under a set that is already generated. }
    procedure MarkStale;
    property OnGenerate: TSpxGenerateEvent read FOnGenerate write FOnGenerate;
    property OnCancelBatch: TNotifyEvent read FOnCancel write FOnCancel;
    property OnShowVariant: TSpxShowVariantEvent read FOnShowVariant write FOnShowVariant;
  end;

implementation

const
  { Grid columns. }
  COL_NO   = 0;
  COL_SEED = 1;
  COL_LEN  = 2;
  COL_TEXT = 3;

constructor TSpxVariantsPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FVariants := TSpxVariantList.Create;

  { ── what to generate ── }

  FTop := TPanel.Create(Self);
  FTop.Parent := Self;
  FTop.Align := alTop;
  FTop.Height := 32;
  FTop.BevelOuter := bvNone;

  FCountLabel := TLabel.Create(Self);
  FCountLabel.Parent := FTop;
  FCountLabel.SetBounds(8, 8, 60, 16);
  FCountLabel.Caption := 'Сколько';

  FCount := TSpinEdit.Create(Self);
  FCount.Parent := FTop;
  FCount.SetBounds(64, 4, 70, 24);
  FCount.MinValue := 1;
  FCount.MaxValue := 100000;
  FCount.Value := 20;

  FSeedLabel := TLabel.Create(Self);
  FSeedLabel.Parent := FTop;
  FSeedLabel.SetBounds(146, 8, 30, 16);
  FSeedLabel.Caption := 'сид';

  FSeed := TSpinEdit.Create(Self);
  FSeed.Parent := FTop;
  FSeed.SetBounds(172, 4, 90, 24);
  FSeed.MinValue := 0;
  FSeed.MaxValue := MaxInt;
  FSeed.Value := 1;

  { A recorded seed is what makes a set reproducible: even "random" writes the number it
    used, because a batch nobody can regenerate is a batch nobody can fix. }
  FRandomSeed := TCheckBox.Create(Self);
  FRandomSeed.Parent := FTop;
  FRandomSeed.SetBounds(270, 6, 90, 20);
  FRandomSeed.Caption := 'случайный';
  FRandomSeed.OnChange := @RandomSeedToggled;

  FGo := TButton.Create(Self);
  FGo.Parent := FTop;
  FGo.SetBounds(368, 4, 110, 24);
  FGo.Caption := 'Сгенерировать';
  FGo.OnClick := @GoClicked;

  FStop := TButton.Create(Self);
  FStop.Parent := FTop;
  FStop.SetBounds(484, 4, 80, 24);
  FStop.Caption := 'Стоп';
  FStop.Enabled := False;
  FStop.OnClick := @StopClicked;

  FProgress := TLabel.Create(Self);
  FProgress.Parent := FTop;
  FProgress.SetBounds(576, 8, 400, 16);
  FProgress.Caption := '';

  { ── how close is too close ── }

  FOpts := TPanel.Create(Self);
  FOpts.Parent := Self;
  FOpts.Align := alTop;
  FOpts.Top := 100;
  FOpts.Height := 30;
  FOpts.BevelOuter := bvNone;

  FDedupe := TCheckBox.Create(Self);
  FDedupe.Parent := FOpts;
  FDedupe.SetBounds(8, 5, 150, 20);
  FDedupe.Caption := 'Убирать похожие';
  FDedupe.Checked := True;
  FDedupe.OnChange := @DedupeToggled;

  FShingleLabel := TLabel.Create(Self);
  FShingleLabel.Parent := FOpts;
  FShingleLabel.SetBounds(164, 7, 50, 16);
  FShingleLabel.Caption := 'шингл';

  FShingle := TSpinEdit.Create(Self);
  FShingle.Parent := FOpts;
  FShingle.SetBounds(210, 3, 56, 24);
  FShingle.MinValue := 1;
  FShingle.MaxValue := 12;
  FShingle.Value := SpxDefaultDedupeOpts.ShingleSize;

  FThresholdLabel := TLabel.Create(Self);
  FThresholdLabel.Parent := FOpts;
  FThresholdLabel.SetBounds(276, 7, 60, 16);
  FThresholdLabel.Caption := 'порог';

  { A slider rather than a number field: the value is a judgement about how similar is too
    similar, and it is nudged rather than typed. }
  FThreshold := TTrackBar.Create(Self);
  FThreshold.Parent := FOpts;
  FThreshold.SetBounds(322, 2, 160, 26);
  FThreshold.Min := 5;
  FThreshold.Max := 100;
  FThreshold.Position := Round(SpxDefaultDedupeOpts.Threshold * 100);
  FThreshold.ShowSelRange := False;
  FThreshold.TickStyle := tsNone;
  FThreshold.OnChange := @ThresholdChanged;

  FThresholdValue := TLabel.Create(Self);
  FThresholdValue.Parent := FOpts;
  FThresholdValue.SetBounds(490, 7, 60, 16);

  { ── the set ── }

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.RowCount := 1;
  FGrid.FixedRows := 1;
  FGrid.FixedCols := 0;
  FGrid.ColCount := 4;
  FGrid.Cells[COL_NO, 0] := '#';
  FGrid.Cells[COL_SEED, 0] := 'сид';
  FGrid.Cells[COL_LEN, 0] := 'длина';
  FGrid.Cells[COL_TEXT, 0] := 'текст';
  FGrid.ColWidths[COL_NO] := 50;
  FGrid.ColWidths[COL_SEED] := 90;
  FGrid.ColWidths[COL_LEN] := 70;
  FGrid.ColWidths[COL_TEXT] := 600;
  FGrid.Options := FGrid.Options + [goRowSelect] - [goEditing, goRangeSelect];
  FGrid.OnClick := @RowClicked;

  { ── writing it out ── }

  FBottom := TPanel.Create(Self);
  FBottom.Parent := Self;
  FBottom.Align := alBottom;
  FBottom.Height := 34;
  FBottom.BevelOuter := bvNone;

  FToXlsx := TButton.Create(Self);
  FToXlsx.Parent := FBottom;
  FToXlsx.SetBounds(8, 5, 110, 24);
  FToXlsx.Caption := 'В .xlsx';
  FToXlsx.OnClick := @ExportXlsx;

  FToTxt := TButton.Create(Self);
  FToTxt.Parent := FBottom;
  FToTxt.SetBounds(124, 5, 110, 24);
  FToTxt.Caption := 'В .txt';
  FToTxt.OnClick := @ExportTxt;

  FToFiles := TButton.Create(Self);
  FToFiles.Parent := FBottom;
  FToFiles.SetBounds(240, 5, 150, 24);
  FToFiles.Caption := 'По файлу на текст';
  FToFiles.OnClick := @ExportFiles;

  FWithSeed := TCheckBox.Create(Self);
  FWithSeed.Parent := FBottom;
  FWithSeed.SetBounds(400, 7, 140, 20);
  FWithSeed.Caption := 'сид в .txt';

  FStatus := TLabel.Create(Self);
  FStatus.Parent := FBottom;
  FStatus.SetBounds(552, 9, 500, 16);
  FStatus.Caption := 'ничего не сгенерировано';

  ThresholdChanged(nil);
  DedupeToggled(nil);
  RandomSeedToggled(nil);
  UpdateButtons;
end;

destructor TSpxVariantsPane.Destroy;
begin
  FVariants.Free;
  inherited Destroy;
end;

function TSpxVariantsPane.Options: TSpxDedupeOpts;
begin
  Result := SpxDefaultDedupeOpts;
  Result.ShingleSize := FShingle.Value;
  { Unchecked means "keep everything": a threshold above 1 can never be reached, since the
    measure is a ratio -- which is cleaner than a second flag the core would have to know
    about. }
  if FDedupe.Checked then
    Result.Threshold := FThreshold.Position / 100
  else
    Result.Threshold := 2;
end;

procedure TSpxVariantsPane.ThresholdChanged(Sender: TObject);
begin
  FThresholdValue.Caption := Format('%.2f', [FThreshold.Position / 100]);
end;

procedure TSpxVariantsPane.DedupeToggled(Sender: TObject);
begin
  FShingle.Enabled := FDedupe.Checked;
  FThreshold.Enabled := FDedupe.Checked;
  FThresholdValue.Enabled := FDedupe.Checked;
end;

procedure TSpxVariantsPane.RandomSeedToggled(Sender: TObject);
begin
  FSeed.Enabled := not FRandomSeed.Checked;
end;

procedure TSpxVariantsPane.UpdateButtons;
var has: Boolean;
begin
  has := FVariants.Count > 0;
  FGo.Enabled := not FRunning;
  FStop.Enabled := FRunning;
  FCount.Enabled := not FRunning;
  FSeed.Enabled := (not FRunning) and (not FRandomSeed.Checked);
  FRandomSeed.Enabled := not FRunning;
  FDedupe.Enabled := not FRunning;
  FShingle.Enabled := (not FRunning) and FDedupe.Checked;
  FThreshold.Enabled := (not FRunning) and FDedupe.Checked;
  { Exporting half a set is a real thing to want -- a long batch that is clearly going
    nowhere gets stopped, and what it produced is still a set -- so these stay live while it
    runs. }
  FToXlsx.Enabled := has;
  FToTxt.Enabled := has;
  FToFiles.Enabled := has;
end;

procedure TSpxVariantsPane.GoClicked(Sender: TObject);
var seed: LongWord;
begin
  if FRunning then Exit;
  if not Assigned(FOnGenerate) then Exit;

  if FRandomSeed.Checked then
  begin
    seed := LongWord(Random($7FFFFFFF));
    { Written back into the field, so the number that produced this set is on screen and in
      every export. "Random" describes how it was chosen, not that it is unknown. }
    FSeed.Value := Integer(seed);
  end
  else
    seed := LongWord(FSeed.Value);

  FVariants.Clear;
  FGrid.RowCount := 1;
  FStale := False;
  FRunning := True;
  UpdateButtons;
  FProgress.Caption := 'идёт…';
  FStatus.Caption := '';
  FOnGenerate(FCount.Value, seed, Options);
end;

procedure TSpxVariantsPane.StopClicked(Sender: TObject);
begin
  if not FRunning then Exit;
  FProgress.Caption := 'останавливаю…';
  if Assigned(FOnCancel) then FOnCancel(Self);
end;

procedure TSpxVariantsPane.AddRow(const V: TSpxVariant);
var r: Integer; line: string; p: Integer;
begin
  r := FGrid.RowCount;
  FGrid.RowCount := r + 1;
  FGrid.Cells[COL_NO, r] := IntToStr(r);
  FGrid.Cells[COL_SEED, r] := IntToStr(V.Seed);
  FGrid.Cells[COL_LEN, r] := IntToStr(Length(V.Text));
  { The first line only: a grid cell cannot show a paragraph, and a row that tries becomes a
    stripe of squares. The whole text goes to the preview on a click. }
  line := V.Text;
  p := Pos(#10, line);
  if p > 0 then line := Copy(line, 1, p - 1);
  p := Pos(#13, line);
  if p > 0 then line := Copy(line, 1, p - 1);
  FGrid.Cells[COL_TEXT, r] := line;
end;

procedure TSpxVariantsPane.SayProgress;
begin
  FProgress.Caption := Format('%d из %d, отброшено %d, рендеров %d',
    [FReport.Generated, FReport.Requested, FReport.Dropped, FReport.Tried]);
end;

procedure TSpxVariantsPane.SayReport(ACancelled: Boolean);
begin
  if ACancelled then
    FStatus.Caption := Format('остановлено: %d вариантов, отброшено %d, рендеров %d',
      [FReport.Generated, FReport.Dropped, FReport.Tried])
  else if FReport.Exhausted then
    { The sentence that matters: a short set is the template's variety talking, not a
      failure of the run. }
    FStatus.Caption := Format(
      'получилось %d из %d — шаблон не даёт больше при этом пороге (отброшено %d, рендеров %d)',
      [FReport.Generated, FReport.Requested, FReport.Dropped, FReport.Tried])
  else
    FStatus.Caption := Format('%d вариантов, отброшено %d, рендеров %d, следующий сид %d',
      [FReport.Generated, FReport.Dropped, FReport.Tried, FReport.NextSeed]);
end;

procedure TSpxVariantsPane.BatchProgress(const P: TSpxBatchProgress);
begin
  FReport := P.Report;
  if P.Accepted then AddRow(P.Variant);
  if P.Accepted then FVariants.Add(P.Variant);

  if P.Done then
  begin
    FRunning := False;
    FProgress.Caption := '';
    SayReport(P.Cancelled);
    UpdateButtons;
    { An edit that arrived mid-run is announced now, on top of the report rather than
      instead of it. }
    if FStalePending then
    begin
      FStalePending := False;
      MarkStale;
    end;
  end
  else
    SayProgress;
end;

procedure TSpxVariantsPane.MarkStale;
begin
  if FStale then Exit;
  { Typed at while it generates: the set becomes stale the moment the text moves, but the
    sentence has to wait for the run to finish or the report would overwrite it. Remembered
    now, said at the end -- the first version dropped it on the floor instead. }
  if FRunning then
  begin
    FStalePending := True;
    Exit;
  end;
  if FVariants.Count = 0 then Exit;
  FStale := True;
  { Said, not acted on: the set is still the author's, and its seeds still name the texts
    that produced it. }
  FStatus.Caption := 'документ изменился — набор от прежнего текста; ' + FStatus.Caption;
end;

procedure TSpxVariantsPane.RowClicked(Sender: TObject);
var idx: Integer;
begin
  idx := FGrid.Row - 1;
  if (idx < 0) or (idx >= FVariants.Count) then Exit;
  if Assigned(FOnShowVariant) then FOnShowVariant(FVariants[idx].Text);
end;

procedure TSpxVariantsPane.ExportXlsx(Sender: TObject);
var dlg: TSaveDialog; rep: TSpxExportReport;
begin
  if FVariants.Count = 0 then Exit;
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Title := 'Экспорт в .xlsx';
    dlg.Filter := 'Книга Excel|*.xlsx';
    dlg.DefaultExt := 'xlsx';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if not dlg.Execute then Exit;
    if SpxWriteXlsx(dlg.FileName, 'Варианты', FVariants, rep) then
      FStatus.Caption := Format('записано %d строк в %s',
        [rep.Written, ExtractFileName(dlg.FileName)])
    else
      FStatus.Caption := 'не удалось записать файл';
  finally
    dlg.Free;
  end;
end;

procedure TSpxVariantsPane.ExportTxt(Sender: TObject);
var dlg: TSaveDialog; rep: TSpxExportReport; opts: TSpxTxtOpts;
begin
  if FVariants.Count = 0 then Exit;
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Title := 'Экспорт в .txt';
    dlg.Filter := 'Текст|*.txt';
    dlg.DefaultExt := 'txt';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if not dlg.Execute then Exit;
    opts := SpxDefaultTxtOpts;
    opts.WithSeed := FWithSeed.Checked;
    if not SpxWriteTxt(dlg.FileName, FVariants, opts, rep) then
      FStatus.Caption := 'не удалось записать файл'
    else if rep.Collapsed > 0 then
      { The one lossy thing any of these writers does, so it is said every time it happens
        rather than left for the author to notice in the file. }
      FStatus.Caption := Format(
        'записано %d строк; у %d вариантов переводы строк заменены пробелами — ' +
        'для дословности берите .xlsx или «по файлу»', [rep.Written, rep.Collapsed])
    else
      FStatus.Caption := Format('записано %d строк в %s',
        [rep.Written, ExtractFileName(dlg.FileName)]);
  finally
    dlg.Free;
  end;
end;

procedure TSpxVariantsPane.ExportFiles(Sender: TObject);
var dir: string; rep: TSpxExportReport;
begin
  if FVariants.Count = 0 then Exit;
  dir := '';
  if not SelectDirectory('Куда положить файлы', '', dir) then Exit;
  if SpxWritePerFile(dir, 'v-', '.html', FVariants, rep) then
    FStatus.Caption := Format('записано %d файлов в %s', [rep.Written, dir])
  else
    FStatus.Caption := Format('записано %d файлов, дальше не удалось', [rep.Written]);
end;

{ The text column takes whatever the fixed ones leave -- the same rule the variables panel
  follows, and for the same reason: a width in pixels is right for exactly one window. }
procedure TSpxVariantsPane.FitGrid;
var used, i: Integer;
begin
  used := 0;
  for i := 0 to COL_TEXT - 1 do used := used + FGrid.ColWidths[i];
  if FGrid.ClientWidth - used > 200 then
    FGrid.ColWidths[COL_TEXT] := FGrid.ClientWidth - used
  else
    FGrid.ColWidths[COL_TEXT] := 200;
end;

procedure TSpxVariantsPane.Resize;
begin
  inherited Resize;
  if FGrid <> nil then FitGrid;
end;

end.
