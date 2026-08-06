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
  Spintax, SpxStudio, SpxCount, SpxDedupe, SpxExport, SpxEngineThread, SpxUi, SpxStrIds,
  SpxStrings;

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
    FMode: TComboBox;
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
    { Which sentence the progress line is showing. Without it a language switch cannot
      rebuild that line, and 'останавливаю…' would sit in an English window until the batch
      reported back. }
    FStopping: Boolean;
    (* WHAT THE TEMPLATE CAN MAKE, as a finished sentence in the language it was built in.

       It shares the progress line's slot on purpose, and the strip is not re-cut for it: the
       two are never wanted at once. A run is happening or it is not; while it is, the reader
       is watching variants land, and the ceiling they came from is the question they asked
       BEFORE pressing Generate. So the line says the count when idle and the progress while
       running, and the count comes back when the run ends. *)
    FPossible: string;
    { The count itself, kept so a language switch can rebuild the sentence from it. }
    FCount_: TSpxCount;
    FHavePossible: Boolean;
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
    procedure RowSelected(Sender: TObject; ACol, ARow: Integer);
    procedure ExportXlsx(Sender: TObject);
    procedure ExportTxt(Sender: TObject);
    procedure ExportFiles(Sender: TObject);
    procedure AddRow(const V: TSpxVariant);
    procedure UpdateButtons;
    procedure SayProgress;
    { The one place the shared line is written, so the two sentences cannot both think they
      own it. }
    procedure SayTopLine;
    { The status line and its hint in one move. They must not drift apart: the hint exists
      because the longest report outgrows the row even stretched, so a hint left over from an
      earlier run is a tooltip that describes a set the user has already replaced. }
    procedure SetStatus(const AText: string);
    procedure SayReport(ACancelled: Boolean);
    function Options: TSpxDedupeOpts;
    procedure FitGrid;
  protected
    procedure Resize; override;
    { Hang each field's caption off the field itself. A label parked at a coordinate fits
      exactly one language: 'shingle' is wider than 'шингл', 'Count' narrower than
      'Сколько', and the first translation to disagree with the number overlaps the box it
      names. Measured and placed instead, so any language lands right. }
    procedure PlaceLabels;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { One step of a running batch, straight from the worker. }
    procedure BatchProgress(const P: TSpxBatchProgress);
    { The document changed under a set that is already generated. }
    procedure MarkStale;
    { How many variants the open document can produce, as the worker counted it -- see
      SpxCount's header for why that word and not "texts". }
    procedure SetPossible(const ACount: TSpxCount);
    { Every caption re-read, after the interface language changes. }
    procedure Retranslate;
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
  FTop.Height := Px(Self, 32);
  FTop.BevelOuter := bvNone;

  FCountLabel := TLabel.Create(Self);
  FCountLabel.Parent := FTop;
  FCountLabel.SetBounds(Px(Self, 8), Px(Self, 8), Px(Self, 60), Px(Self, 16));
  FCountLabel.Caption := Tr(sHowMany);

  FCount := TSpinEdit.Create(Self);
  FCount.Parent := FTop;
  FCount.SetBounds(Px(Self, 64), Px(Self, 4), Px(Self, 70), Px(Self, 24));
  FCount.MinValue := 1;
  FCount.MaxValue := 100000;
  FCount.Value := 20;

  FSeedLabel := TLabel.Create(Self);
  FSeedLabel.Parent := FTop;
  FSeedLabel.SetBounds(Px(Self, 146), Px(Self, 8), Px(Self, 30), Px(Self, 16));
  FSeedLabel.Caption := Tr(sSeedShort);

  FSeed := TSpinEdit.Create(Self);
  FSeed.Parent := FTop;
  FSeed.SetBounds(Px(Self, 172), Px(Self, 4), Px(Self, 90), Px(Self, 24));
  FSeed.MinValue := 0;
  FSeed.MaxValue := MaxInt;
  FSeed.Value := 1;

  { A recorded seed is what makes a set reproducible: even "random" writes the number it
    used, because a batch nobody can regenerate is a batch nobody can fix. }
  FRandomSeed := TCheckBox.Create(Self);
  FRandomSeed.Parent := FTop;
  FRandomSeed.SetBounds(Px(Self, 270), Px(Self, 6), Px(Self, 90), Px(Self, 20));
  FRandomSeed.Caption := Tr(sRandomSeed);
  FRandomSeed.OnChange := @RandomSeedToggled;

  FGo := TButton.Create(Self);
  FGo.Parent := FTop;
  FGo.SetBounds(Px(Self, 368), Px(Self, 4), Px(Self, 110), Px(Self, 24));
  FGo.Caption := Tr(sGenerate);
  FGo.OnClick := @GoClicked;

  FStop := TButton.Create(Self);
  FStop.Parent := FTop;
  FStop.SetBounds(Px(Self, 484), Px(Self, 4), Px(Self, 80), Px(Self, 24));
  FStop.Caption := Tr(sStop);
  FStop.Enabled := False;
  FStop.OnClick := @StopClicked;

  FProgress := TLabel.Create(Self);
  FProgress.Parent := FTop;
  FProgress.SetBounds(Px(Self, 576), Px(Self, 8), Px(Self, 400), Px(Self, 16));
  { Same reason as the status line below: Resize owns its width, so it must not also size
    itself to its caption -- LCL raises ELayoutException when the two pull against each
    other. }
  FProgress.AutoSize := False;
  FProgress.Caption := '';

  { ── how close is too close ── }

  FOpts := TPanel.Create(Self);
  FOpts.Parent := Self;
  FOpts.Align := alTop;
  FOpts.Top := Px(Self, 100);
  FOpts.Height := Px(Self, 30);
  FOpts.BevelOuter := bvNone;

  { Three ways, the same three the tool this syntax came from offers: near-duplicates by
    shingles, literal repeats only, or nothing. They are genuinely different questions --
    "is this the same article" and "is this the same bytes" -- and a checkbox could only ask
    one of them. }
  FMode := TComboBox.Create(Self);
  FMode.Parent := FOpts;
  FMode.Style := csDropDownList;
  FMode.SetBounds(Px(Self, 8), Px(Self, 3), Px(Self, 210), Px(Self, 24));
  FMode.Items.Add(Tr(sDropSimilar));
  FMode.Items.Add(Tr(sExactOnly));
  FMode.Items.Add(Tr(sKeepAll));
  FMode.ItemIndex := 0;
  FMode.OnChange := @DedupeToggled;

  FShingleLabel := TLabel.Create(Self);
  FShingleLabel.Parent := FOpts;
  FShingleLabel.SetBounds(Px(Self, 230), Px(Self, 7), Px(Self, 50), Px(Self, 16));
  FShingleLabel.Caption := Tr(sShingle);

  FShingle := TSpinEdit.Create(Self);
  FShingle.Parent := FOpts;
  FShingle.SetBounds(Px(Self, 276), Px(Self, 3), Px(Self, 56), Px(Self, 24));
  FShingle.MinValue := 1;
  FShingle.MaxValue := 12;
  FShingle.Value := SpxDefaultDedupeOpts.ShingleSize;

  FThresholdLabel := TLabel.Create(Self);
  FThresholdLabel.Parent := FOpts;
  FThresholdLabel.SetBounds(Px(Self, 342), Px(Self, 7), Px(Self, 60), Px(Self, 16));
  FThresholdLabel.Caption := Tr(sThreshold);

  { A slider rather than a number field: the value is a judgement about how similar is too
    similar, and it is nudged rather than typed. }
  FThreshold := TTrackBar.Create(Self);
  FThreshold.Parent := FOpts;
  FThreshold.SetBounds(Px(Self, 388), Px(Self, 2), Px(Self, 150), Px(Self, 26));
  FThreshold.Min := 5;
  FThreshold.Max := 100;
  FThreshold.Position := Round(SpxDefaultDedupeOpts.Threshold * 100);
  FThreshold.ShowSelRange := False;
  FThreshold.TickStyle := tsNone;
  FThreshold.OnChange := @ThresholdChanged;

  FThresholdValue := TLabel.Create(Self);
  FThresholdValue.Parent := FOpts;
  FThresholdValue.SetBounds(Px(Self, 546), Px(Self, 7), Px(Self, 60), Px(Self, 16));

  { ── the set ── }

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.RowCount := 1;
  FGrid.FixedRows := 1;
  FGrid.FixedCols := 0;
  FGrid.ColCount := 4;
  FGrid.Cells[COL_NO, 0] := Tr(sColNo);
  FGrid.Cells[COL_SEED, 0] := Tr(sColSeed);
  FGrid.Cells[COL_LEN, 0] := Tr(sColLength);
  FGrid.Cells[COL_TEXT, 0] := Tr(sColText);
  FGrid.ColWidths[COL_NO] := Px(Self, 50);
  FGrid.ColWidths[COL_SEED] := Px(Self, 90);
  FGrid.ColWidths[COL_LEN] := Px(Self, 70);
  FGrid.ColWidths[COL_TEXT] := Px(Self, 600);
  FGrid.Options := FGrid.Options + [goRowSelect] - [goEditing, goRangeSelect];
  { ON SELECTION rather than ON CLICK. Arrow keys already reached the old handler -- MoveSel
    calls Click (grids.pas:7697) -- so this is not new keyboard support; what it fixes is
    TCustomGrid.Click's FIgnoreClick gate (:3455), which a click on a column HEADER leaves set
    until the next click on a row, silently stopping the arrows from previewing anything.
    Showing a variant costs a string assignment and takes no focus, so selection-follows is
    exactly right here. }
  FGrid.OnSelection := @RowSelected;

  { ── writing it out ── }

  FBottom := TPanel.Create(Self);
  FBottom.Parent := Self;
  FBottom.Align := alBottom;
  FBottom.Height := Px(Self, 34);
  FBottom.BevelOuter := bvNone;

  FToXlsx := TButton.Create(Self);
  FToXlsx.Parent := FBottom;
  FToXlsx.SetBounds(Px(Self, 8), Px(Self, 5), Px(Self, 110), Px(Self, 24));
  FToXlsx.Caption := Tr(sToXlsx);
  FToXlsx.OnClick := @ExportXlsx;

  FToTxt := TButton.Create(Self);
  FToTxt.Parent := FBottom;
  FToTxt.SetBounds(Px(Self, 124), Px(Self, 5), Px(Self, 110), Px(Self, 24));
  FToTxt.Caption := Tr(sToTxt);
  FToTxt.OnClick := @ExportTxt;

  FToFiles := TButton.Create(Self);
  FToFiles.Parent := FBottom;
  FToFiles.SetBounds(Px(Self, 240), Px(Self, 5), Px(Self, 150), Px(Self, 24));
  FToFiles.Caption := Tr(sToFiles);
  FToFiles.OnClick := @ExportFiles;

  FWithSeed := TCheckBox.Create(Self);
  FWithSeed.Parent := FBottom;
  FWithSeed.SetBounds(Px(Self, 400), Px(Self, 7), Px(Self, 140), Px(Self, 20));
  FWithSeed.Caption := Tr(sSeedInTxt);

  FStatus := TLabel.Create(Self);
  FStatus.Parent := FBottom;
  FStatus.SetBounds(Px(Self, 552), Px(Self, 9), Px(Self, 500), Px(Self, 16));
  { Sized by the row, not by the text: Resize gives it the rest of the row, and a label that
    also sizes itself to its caption fights that -- LCL detects the two pulling against each
    other and raises ELayoutException on the next resize. }
  FStatus.AutoSize := False;
  SetStatus(Tr(sNothingGenerated));

  ThresholdChanged(nil);
  DedupeToggled(nil);
  RandomSeedToggled(nil);
  UpdateButtons;
end;

procedure TSpxVariantsPane.Retranslate;
var idx: Integer;
begin
  FCountLabel.Caption := Tr(sHowMany);
  FSeedLabel.Caption := Tr(sSeedShort);
  FRandomSeed.Caption := Tr(sRandomSeed);
  FGo.Caption := Tr(sGenerate);
  FStop.Caption := Tr(sStop);
  { The chosen mode survives the rename: it is an index, and the list is rebuilt in the same
    order. }
  idx := FMode.ItemIndex;
  FMode.Items.Clear;
  FMode.Items.Add(Tr(sDropSimilar));
  FMode.Items.Add(Tr(sExactOnly));
  FMode.Items.Add(Tr(sKeepAll));
  FMode.ItemIndex := idx;
  FShingleLabel.Caption := Tr(sShingle);
  FThresholdLabel.Caption := Tr(sThreshold);
  { The captions just changed width; where they sit follows from that. }
  PlaceLabels;
  FGrid.Cells[COL_NO, 0] := Tr(sColNo);
  FGrid.Cells[COL_SEED, 0] := Tr(sColSeed);
  FGrid.Cells[COL_LEN, 0] := Tr(sColLength);
  FGrid.Cells[COL_TEXT, 0] := Tr(sColText);
  FToXlsx.Caption := Tr(sToXlsx);
  FToTxt.Caption := Tr(sToTxt);
  FToFiles.Caption := Tr(sToFiles);
  FWithSeed.Caption := Tr(sSeedInTxt);
  { The progress line is one of three sentences, and which one is state rather than text --
    hence FStopping. Without this the line stays in the previous language: during a run the
    next variant repaints it, but after Stop nothing does until the batch reports back. }
  { The count was built as a sentence in the previous language, so it is rebuilt rather than
    kept -- unlike the finished report below, which the pane cannot rebuild. }
  if FHavePossible then SetPossible(FCount_);
  SayTopLine;

  { Only the idle line is rewritten. A run in flight says 'working…' with a count behind it,
    and translating the panel is no reason to tell the user nothing has been generated while
    variants are landing in the grid.

    A FINISHED run's report keeps the language it was written in, and that is a real gap
    rather than a decision: re-running SayReport would need the cancelled flag, which the
    pane does not keep. It costs one stale line until the next run. }
  if (FVariants.Count = 0) and (not FRunning) then SetStatus(Tr(sNothingGenerated));
end;

destructor TSpxVariantsPane.Destroy;
begin
  FVariants.Free;
  inherited Destroy;
end;

function TSpxVariantsPane.Options: TSpxDedupeOpts;
begin
  Result := SpxDefaultDedupeOpts;
  case FMode.ItemIndex of
    1: Result.Mode := spxDedupeExact;
    2: Result.Mode := spxDedupeOff;
  else
    Result.Mode := spxDedupeShingles;
  end;
  Result.ShingleSize := FShingle.Value;
  Result.Threshold := FThreshold.Position / 100;
end;

procedure TSpxVariantsPane.ThresholdChanged(Sender: TObject);
begin
  { A percentage, because that is how the number reads to a person -- "considered the same
    at 75% overlap" -- and how the tool this came from puts it. }
  FThresholdValue.Caption := IntToStr(FThreshold.Position) + '%';
end;

procedure TSpxVariantsPane.DedupeToggled(Sender: TObject);
var byShingles: Boolean;
begin
  byShingles := FMode.ItemIndex = 0;
  FShingleLabel.Enabled := byShingles;
  FShingle.Enabled := byShingles;
  FThresholdLabel.Enabled := byShingles;
  FThreshold.Enabled := byShingles;
  FThresholdValue.Enabled := byShingles;
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
  FMode.Enabled := not FRunning;
  FShingle.Enabled := (not FRunning) and (FMode.ItemIndex = 0);
  FThreshold.Enabled := (not FRunning) and (FMode.ItemIndex = 0);
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
  FStopping := False;
  UpdateButtons;
  FProgress.Caption := Tr(sWorking);
  SetStatus('');
  FOnGenerate(FCount.Value, seed, Options);
end;

procedure TSpxVariantsPane.StopClicked(Sender: TObject);
begin
  if not FRunning then Exit;
  FStopping := True;
  FProgress.Caption := Tr(sStopping);
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

procedure TSpxVariantsPane.SetStatus(const AText: string);
begin
  FStatus.Caption := AText;
  FStatus.Hint := AText;
  FStatus.ShowHint := AText <> '';
end;

procedure TSpxVariantsPane.SayProgress;
begin
  FProgress.Caption := Format(Tr(sProgress),
    [FReport.Generated, FReport.Requested, FReport.Dropped, FReport.Tried]);
end;

procedure TSpxVariantsPane.SayTopLine;
begin
  if FRunning then
  begin
    if FStopping then FProgress.Caption := Tr(sStopping)
    else if FReport.Tried > 0 then SayProgress
    else FProgress.Caption := Tr(sWorking);
  end
  else
    FProgress.Caption := FPossible;
end;

(* THE NUMBER, GROUPED THE WAY A PERSON READS IT -- 241 864 704, not 241864704, which is what
   GTW does and what makes the difference between "thin" and "enormous" visible without
   counting digits. The space is a NON-BREAKING one so the line never wraps inside the number.

   The separator is not taken from the locale: `ThousandSeparator` is the OS's, and this window
   is translated into fourteen languages that the OS is not necessarily set to. A space groups
   digits in every one of them, and no language reads it as a decimal point. *)
function GroupDigits(V: Int64): string;
var s: string; i, n: Integer;
begin
  s := IntToStr(V);
  Result := '';
  n := 0;
  for i := Length(s) downto 1 do
  begin
    Result := s[i] + Result;
    Inc(n);
    if (n mod 3 = 0) and (i > 1) then Result := #$C2#$A0 + Result;   { U+00A0, UTF-8 }
  end;
end;

procedure TSpxVariantsPane.SetPossible(const ACount: TSpxCount);
begin
  FCount_ := ACount;
  FHavePossible := True;
  { EXACT is a promise and the panel makes it or it does not. A conditional, a plural or an
    include the set has not got are all decided by something other than chance, so the honest
    answer is a floor -- and the SATURATED case is a floor too, for a different reason: the
    counter stopped adding, it did not finish. Both say "at least", which is true of both. }
  if FCount_.Exact and not FCount_.Saturated then
    FPossible := Format(Tr(sPossible), [GroupDigits(FCount_.Value)])
  else
    FPossible := Format(Tr(sPossibleAtLeast), [GroupDigits(FCount_.Value)]);
  SayTopLine;
end;

procedure TSpxVariantsPane.SayReport(ACancelled: Boolean);
begin
  if ACancelled then
    SetStatus(Format(Tr(sReportStopped),
      [FReport.Generated, FReport.Dropped, FReport.Tried]))
  else if FReport.Exhausted then
    { The sentence that matters: a short set is the template's variety talking, not a
      failure of the run. }
    SetStatus(Format(Tr(sReportExhausted),
      [FReport.Generated, FReport.Requested, FReport.Dropped, FReport.Tried]))
  else
    SetStatus(Format(Tr(sReportDone),
      [FReport.Generated, FReport.Dropped, FReport.Tried, FReport.NextSeed]));
end;

procedure TSpxVariantsPane.BatchProgress(const P: TSpxBatchProgress);
begin
  FReport := P.Report;
  if P.Accepted then AddRow(P.Variant);
  if P.Accepted then FVariants.Add(P.Variant);

  if P.Done then
  begin
    FRunning := False;
    { Not blanked: the run is over, so the line goes back to what the template can make. }
    SayTopLine;
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
  { Warning plus report is the longest line this pane can produce, and the only one that
    outgrows the row even stretched -- SetStatus keeps the whole of it in the hint. }
  SetStatus(Tr(sStaleSet) + FStatus.Caption);
end;

procedure TSpxVariantsPane.RowSelected(Sender: TObject; ACol, ARow: Integer);
var idx: Integer;
begin
  idx := ARow - 1;
  if (idx < 0) or (idx >= FVariants.Count) then Exit;
  if Assigned(FOnShowVariant) then FOnShowVariant(FVariants[idx].Text);
end;

procedure TSpxVariantsPane.ExportXlsx(Sender: TObject);
var dlg: TSaveDialog; rep: TSpxExportReport;
begin
  if FVariants.Count = 0 then Exit;
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Title := Tr(sExportXlsx);
    dlg.Filter := Tr(sExcelFilter);
    dlg.DefaultExt := 'xlsx';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if not dlg.Execute then Exit;
    if SpxWriteXlsx(dlg.FileName, Tr(sSheetName), Tr(sColSheetSeed), Tr(sColSheetText),
                    FVariants, rep) then
      SetStatus(Format(Tr(sWroteRows),
        [rep.Written, ExtractFileName(dlg.FileName)]))
    else
      SetStatus(Tr(sWriteFailed));
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
    dlg.Title := Tr(sExportTxt);
    dlg.Filter := Tr(sTextFilter);
    dlg.DefaultExt := 'txt';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if not dlg.Execute then Exit;
    opts := SpxDefaultTxtOpts;
    opts.WithSeed := FWithSeed.Checked;
    if not SpxWriteTxt(dlg.FileName, FVariants, opts, rep) then
      SetStatus(Tr(sWriteFailed))
    else if rep.Collapsed > 0 then
      { The one lossy thing any of these writers does, so it is said every time it happens
        rather than left for the author to notice in the file. }
      SetStatus(Format(Tr(sWroteRowsCollapsed),
        [rep.Written, rep.Collapsed]))
    else
      SetStatus(Format(Tr(sWroteRows),
        [rep.Written, ExtractFileName(dlg.FileName)]));
  finally
    dlg.Free;
  end;
end;

procedure TSpxVariantsPane.ExportFiles(Sender: TObject);
var dir: string; rep: TSpxExportReport;
begin
  if FVariants.Count = 0 then Exit;
  dir := '';
  if not SelectDirectory(Tr(sChooseFolder), '', dir) then Exit;
  if SpxWritePerFile(dir, 'v-', '.html', FVariants, rep) then
    SetStatus(Format(Tr(sWroteFiles), [rep.Written, dir]))
  else
    SetStatus(Format(Tr(sWroteFilesPartial), [rep.Written]));
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
    FGrid.ColWidths[COL_TEXT] := Px(Self, 200);
end;

procedure TSpxVariantsPane.PlaceLabels;
var
  ruler: TBitmap;

  { The label's own size, measured rather than requested. Two roads not taken, both by
    measurement: `AutoSize := True` is a no-op (TLabel is born with it) and leaves Width at
    whatever the previous caption needed, so labels landed a language behind -- 'limit' at
    x=322 under a spin box spanning 276..332; and `AdjustSize` re-enters the parent's layout,
    which from Resize is `ELayoutException: TControl.AdjustSize loop detected` at startup.
    An off-screen bitmap has no layout to disturb and needs no window handle. }
  procedure Fit(ALabel: TLabel);
  begin
    ALabel.AutoSize := False;
    ruler.Canvas.Font.Assign(ALabel.Font);
    ALabel.Width := ruler.Canvas.TextWidth(ALabel.Caption);
  end;

  procedure Hang(ALabel: TLabel; ACtl: TControl);
  begin
    Fit(ALabel);
    ALabel.Left := ACtl.Left - ALabel.Width - Px(Self, 6);
  end;

begin
  ruler := TBitmap.Create;
  try
    { The first label stays flush with the panel's left edge -- there is nothing to its left
      to push against, and a gap there would read as a missing control. Its budget is what
      keeps it out of the spin box. }
    Fit(FCountLabel);
    Hang(FSeedLabel, FSeed);
    Hang(FShingleLabel, FShingle);
    Hang(FThresholdLabel, FThreshold);
  finally
    ruler.Free;
  end;
end;

procedure TSpxVariantsPane.Resize;
var w: Integer;
begin
  inherited Resize;
  if FGrid <> nil then FitGrid;
  { Here rather than in the constructor: a control measures its caption only once it has a
    parent, and in the constructor the pane itself has none. }
  if FThresholdLabel <> nil then PlaceLabels;
  { Both lines are sentences with four numbers in them, and in Russian each is half again as
    long as the box it was given. They take the rest of their row instead. }
  if (FProgress <> nil) and (FTop <> nil) then
  begin
    w := FTop.ClientWidth - FProgress.Left - Px(Self, 8);
    if w < Px(Self, 40) then w := Px(Self, 40);
    FProgress.Width := w;
  end;
  if (FStatus <> nil) and (FBottom <> nil) then
  begin
    w := FBottom.ClientWidth - FStatus.Left - Px(Self, 8);
    { A pane narrower than the export row leaves nothing for the status; it keeps a sliver
      rather than a negative width, which no widgetset owes us an answer for. }
    if w < Px(Self, 40) then w := Px(Self, 40);
    FStatus.Width := w;
  end;
end;

end.
