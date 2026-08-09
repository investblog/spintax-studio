(*
 * SpxAiPane -- the AI authoring loop, and there is no network anywhere in it (ADR 0011).
 *
 * WHAT THIS PANEL DOES, and why the shape looks like a missing feature until you read the
 * decision behind it. Studio builds the prompt; the reader carries it to whatever model they
 * already use; the reader brings the answer back. There is no provider, no key, no "connect"
 * and no spinner, and that is the design rather than a stage of it. The published listing has
 * said since 2026-08-04 that a draft is written in a model OUTSIDE this application and
 * brought in, and that R0 "does not call an AI service, send your documents to the cloud or
 * require a model key" -- so this slice makes no published sentence false. A networked
 * provider is a separate slice with its own ADR, because it changes the listing, the privacy
 * policy in two places and the data declaration at certification.
 *
 * WHERE THE VERDICT COMES FROM. Not from here. `Insert into document` puts the cleaned draft
 * in the editor, and the editor's own render path -- one worker thread, as every engine call
 * in this window is -- validates it and fills the diagnostics panel exactly as it does for
 * anything else the reader types. That is the point of doing it this way rather than
 * validating in the panel: Studio is the only consumer in this family with the engine already
 * in the process, so the answer is immediate and the reader sees it where they already look
 * for it, with squiggles under the spans.
 *
 * THE REPAIR PROMPT IS BUILT FROM WHAT THE PANEL ALREADY SHOWS. `TSpxPanelRow` carries the
 * severity, the code, the span and Studio's own wording of the finding, in the reader's
 * language. So the repair prompt points the model at the exact token rather than saying
 * "something is wrong" -- which is what the engine's precise positions were for.
 *
 * THE ALLOW-LIST IS PREFILLED AND THE CASE IS NOT. The document's variables come from the
 * model the window already has, so the reader does not retype them. The grammatical case
 * cannot be prefilled and must never be guessed: a variable is substituted VERBATIM, so in an
 * inflected language the sentence has to be built around the form the value already holds --
 * and upstream measured a real template set where `%CasinoGamesAcc%` carried instrumental
 * forms. The naming convention lied; a declaration cannot.
 *
 * EVERY COMMENT HERE IS STAR-PAREN, NEVER A BRACE COMMENT -- this file is full of `{a|b}`.
 *)
unit SpxAiPane;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Grids, Graphics, Clipbrd,
  Spintax, SpxStudio, SpxPrompt, SpxUi, SpxStrIds, SpxStrings;

type
  (* What the panel needs from the form. Three narrow seams, and not one of them is an engine
     call: the form owns the document, its locale, its variables and its diagnostics. *)
  TSpxAiInsertEvent = procedure(const AText: string) of object;

  TSpxAiPane = class(TPanel)
  private
    FTop: TPanel;
    FLocaleLabel: TLabel;
    FLocaleValue: TLabel;
    FChannelLabel: TLabel;
    FChannel: TComboBox;
    FLevelLabel: TLabel;
    FLevel: TComboBox;
    FCopy: TButton;

    FLeft: TPanel;
    FBriefLabel: TLabel;
    FBrief: TMemo;

    FMid: TPanel;
    FAllowedLabel: TLabel;
    FAllowed: TStringGrid;

    FRight: TPanel;
    FReplyLabel: TLabel;
    FReply: TMemo;

    FBottom: TPanel;
    FStatus: TLabel;
    FInsert: TButton;
    FRepair: TButton;

    FLocale: string;
    FRows: TSpxPanelRows;
    (* The declared case per grid row, indexed by ROW (so [0] is the header and unused). This
       is the state; the cell that shows it is a view. See Retranslate for why. *)
    FCases: array of TSpxVarCase;
    FOnInsert: TSpxAiInsertEvent;
    FDocText: string;

    procedure CopyPromptClicked(Sender: TObject);
    procedure InsertClicked(Sender: TObject);
    procedure RepairClicked(Sender: TObject);
    procedure CaseEdited(Sender: TObject);
    function CollectVars: TSpxAllowedVars;
    procedure Say(const AText: string);
    procedure PlaceLabels;
    procedure FitColumns;
    function TextW(const S: string): Integer;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    (* The document's locale, so the prompt carries the right grammar block and the right
       plural arity. The form owns it -- the panel must not guess it from the interface
       language, which is a different setting and was the bug that produced Russian headers
       over English findings elsewhere in this window. *)
    procedure SetLocale(const ATag: string);
    (* Every variable the open document defines or references, in document order. Names only:
       the case column is the author's to fill and is deliberately left alone here.

       THE NAMES ARRIVE FOLDED, and that is harmless rather than a display bug: the engine
       looks a variable up through `LowerAscii` (Spintax.pas:1736, 1753, 1768), so `%OwnLang%`
       and `%ownlang%` are one variable and a model handed either writes something that
       renders. Read off the engine's source, because a list that quietly renamed the author's
       variables would be worth stopping for. *)
    procedure SetVariables(const AVars: TSpxVarInfos);
    (* The open document and its findings, kept so the repair prompt can be built without
       asking the engine again -- the window already has both. *)
    procedure SetDocument(const AText: string; const ARows: TSpxPanelRows);
    procedure Retranslate;
    property OnInsert: TSpxAiInsertEvent read FOnInsert write FOnInsert;
  end;

implementation

const
  COL_NAME = 0;
  COL_CASE = 1;
  COL_NOTE = 2;

  (* The case picker's rows, in the order TSpxVarCase declares them, so the grid's index IS
     the enum's ordinal and no lookup table can drift from it. *)
  CASE_IDS: array[TSpxVarCase] of TSpxStr =
    (sAiCaseNone, sAiCaseNom, sAiCaseGen, sAiCaseDat, sAiCaseAcc, sAiCaseIns, sAiCasePre);

  CHANNEL_IDS: array[TSpxChannel] of TSpxStr =
    (sAiChEmail, sAiChSms, sAiChPush, sAiChLanding, sAiChGeneric);

  LEVEL_IDS: array[TSpxVariation] of TSpxStr =
    (sAiLvConservative, sAiLvBalanced, sAiLvAggressive);

constructor TSpxAiPane.Create(AOwner: TComponent);
var
  c: TSpxChannel;
  v: TSpxVariation;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;

  (* ── what to ask for ── *)

  FTop := TPanel.Create(Self);
  FTop.Parent := Self;
  FTop.Align := alTop;
  FTop.Height := Px(Self, 32);
  FTop.BevelOuter := bvNone;

  FLocaleLabel := TLabel.Create(Self);
  FLocaleLabel.Parent := FTop;
  FLocaleLabel.Top := Px(Self, 8);

  FLocaleValue := TLabel.Create(Self);
  FLocaleValue.Parent := FTop;
  FLocaleValue.Top := Px(Self, 8);
  FLocaleValue.Font.Style := [fsBold];

  FChannelLabel := TLabel.Create(Self);
  FChannelLabel.Parent := FTop;
  FChannelLabel.Top := Px(Self, 8);

  FChannel := TComboBox.Create(Self);
  FChannel.Parent := FTop;
  FChannel.Style := csDropDownList;
  FChannel.Top := Px(Self, 4);
  FChannel.Width := Px(Self, 110);
  for c := Low(TSpxChannel) to High(TSpxChannel) do FChannel.Items.Add(Tr(CHANNEL_IDS[c]));
  FChannel.ItemIndex := Ord(chGeneric);

  FLevelLabel := TLabel.Create(Self);
  FLevelLabel.Parent := FTop;
  FLevelLabel.Top := Px(Self, 8);

  FLevel := TComboBox.Create(Self);
  FLevel.Parent := FTop;
  FLevel.Style := csDropDownList;
  FLevel.Top := Px(Self, 4);
  FLevel.Width := Px(Self, 130);
  for v := Low(TSpxVariation) to High(TSpxVariation) do FLevel.Items.Add(Tr(LEVEL_IDS[v]));
  FLevel.ItemIndex := Ord(vlBalanced);

  FCopy := TButton.Create(Self);
  FCopy.Parent := FTop;
  FCopy.Top := Px(Self, 4);
  FCopy.Height := Px(Self, 24);
  FCopy.OnClick := @CopyPromptClicked;

  (* ── the brief, the allow-list and the answer, side by side ── *)

  FBottom := TPanel.Create(Self);
  FBottom.Parent := Self;
  FBottom.Align := alBottom;
  FBottom.Height := Px(Self, 32);
  FBottom.BevelOuter := bvNone;

  (* READING ORDER, AND LCL DECIDES IT BY `Left`, NOT BY CREATION ORDER. Two panels both
     `alLeft` and both at 0 come out in whatever order the align pass walks them, which put the
     allow-list before the brief on the first run. The window already uses this idiom for the
     bottom block and its splitter: park the later one far to the right and let the align pass
     sort them. *)
  FLeft := TPanel.Create(Self);
  FLeft.Parent := Self;
  FLeft.Left := 0;
  FLeft.Align := alLeft;
  FLeft.BevelOuter := bvNone;
  FLeft.Width := Px(Self, 300);

  FBriefLabel := TLabel.Create(Self);
  FBriefLabel.Parent := FLeft;
  FBriefLabel.Align := alTop;

  FBrief := TMemo.Create(Self);
  FBrief.Parent := FLeft;
  FBrief.Align := alClient;
  FBrief.ScrollBars := ssAutoVertical;
  FBrief.WordWrap := True;

  FMid := TPanel.Create(Self);
  FMid.Parent := Self;
  FMid.Left := 10000;
  FMid.Align := alLeft;
  FMid.BevelOuter := bvNone;
  FMid.Width := Px(Self, 300);

  FAllowedLabel := TLabel.Create(Self);
  FAllowedLabel.Parent := FMid;
  FAllowedLabel.Align := alTop;

  FAllowed := TStringGrid.Create(Self);
  FAllowed.Parent := FMid;
  FAllowed.Align := alClient;
  FAllowed.RowCount := 1;
  FAllowed.FixedRows := 1;
  FAllowed.FixedCols := 0;
  FAllowed.Options := FAllowed.Options + [goEditing, goColSizing, goThumbTracking];
  FAllowed.AutoFillColumns := False;
  (* THREE COLUMNS AS `Columns`, NOT AS A COLUMN COUNT, because the middle one has to be a
     PICKER. A case typed by hand is a case spelled wrong, and a spelling this panel does not
     recognise reads back as "not declared" -- the one value in that column that must never
     arrive by accident, since it silently drops the rule the model needed. *)
  FAllowed.Columns.Add;   (* name -- the document's, never edited here *)
  FAllowed.Columns.Add;   (* case -- picked from a list *)
  FAllowed.Columns.Add;   (* note -- free text, and free is right: it is a hint to a model *)
  FAllowed.Columns[COL_NAME].ReadOnly := True;
  FAllowed.Columns[COL_CASE].ButtonStyle := cbsPickList;
  FAllowed.Columns[COL_CASE].ReadOnly := True;   (* pick, do not type *)
  FAllowed.OnEditingDone := @CaseEdited;

  FRight := TPanel.Create(Self);
  FRight.Parent := Self;
  FRight.Align := alClient;
  FRight.BevelOuter := bvNone;

  FReplyLabel := TLabel.Create(Self);
  FReplyLabel.Parent := FRight;
  FReplyLabel.Align := alTop;

  FReply := TMemo.Create(Self);
  FReply.Parent := FRight;
  FReply.Align := alClient;
  FReply.ScrollBars := ssAutoBoth;
  FReply.WordWrap := False;

  (* ── what to do with the answer ── *)

  FRepair := TButton.Create(Self);
  FRepair.Parent := FBottom;
  FRepair.Align := alRight;
  FRepair.BorderSpacing.Around := Px(Self, 4);
  FRepair.OnClick := @RepairClicked;

  FInsert := TButton.Create(Self);
  FInsert.Parent := FBottom;
  FInsert.Align := alRight;
  FInsert.BorderSpacing.Around := Px(Self, 4);
  FInsert.OnClick := @InsertClicked;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := FBottom;
  FStatus.Left := Px(Self, 8);
  FStatus.Top := Px(Self, 9);

  FLocale := '';
  Retranslate;
end;

procedure TSpxAiPane.Say(const AText: string);
begin
  FStatus.Caption := AText;
  FStatus.Hint := AText;
  FStatus.ShowHint := AText <> '';
end;

(* MEASURED ON AN OFFSCREEN BITMAP, NEVER ON A CONTROL'S CANVAS.

   This panel is constructed before the form gives it a Parent, and touching a control's Canvas
   forces its handle -- which on a control with no parent window is the LCL error
   `Control "" has no parent window`, a modal box in front of a window that never appears. It
   cost exactly one launch here. A bitmap needs no window and answers the same question.

   Hang each caption off the field it names, measured rather than parked at a coordinate.
   A label placed at a number fits exactly one language -- "Variation" is narrower than
   "Варіативність" and much narrower than "Yapay zekâ taslağı" -- and the first translation to
   disagree with the number overlaps the box beside it. Measured with the canvas the label will
   actually be drawn with, because a TLabel does not know its own width until it is painted:
   `AutoSize` is already True on a fresh one, so `Width` still describes the PREVIOUS caption
   and captions placed from it land a language behind. *)
procedure TSpxAiPane.PlaceLabels;

var
  x: Integer;
begin
  if FTop = nil then Exit;

  x := Px(Self, 8);
  FLocaleLabel.Left := x;  Inc(x, TextW(FLocaleLabel.Caption) + Px(Self, 6));
  FLocaleValue.Left := x;  Inc(x, TextW(FLocaleValue.Caption) + Px(Self, 16));
  FChannelLabel.Left := x; Inc(x, TextW(FChannelLabel.Caption) + Px(Self, 6));
  FChannel.Left := x;      Inc(x, FChannel.Width + Px(Self, 16));
  FLevelLabel.Left := x;   Inc(x, TextW(FLevelLabel.Caption) + Px(Self, 6));
  FLevel.Left := x;        Inc(x, FLevel.Width + Px(Self, 16));
  FCopy.Left := x;
  FCopy.Width := TextW(FCopy.Caption) + Px(Self, 28);
end;

function TSpxAiPane.TextW(const S: string): Integer;
var
  bmp: TBitmap;
begin
  bmp := TBitmap.Create;
  try
    bmp.Canvas.Font.Assign(FLocaleLabel.Font);
    Result := bmp.Canvas.TextWidth(S);
  finally
    bmp.Free;
  end;
end;

procedure TSpxAiPane.FitColumns;
var
  w: Integer;
begin
  if FAllowed = nil then Exit;
  w := FAllowed.ClientWidth;
  if (w < Px(Self, 120)) or (FAllowed.Columns.Count < 3) then Exit;
  FAllowed.Columns[COL_NAME].Width := w * 40 div 100;
  FAllowed.Columns[COL_CASE].Width := w * 32 div 100;
  (* The last column takes what is left rather than its own percentage, so rounding cannot
     leave a sliver of empty grid beside it. *)
  FAllowed.Columns[COL_NOTE].Width :=
    w - FAllowed.Columns[COL_NAME].Width - FAllowed.Columns[COL_CASE].Width - Px(Self, 2);
end;

procedure TSpxAiPane.Resize;
var
  third: Integer;
begin
  inherited Resize;
  if FLeft = nil then Exit;
  (* Three columns of roughly equal width. Set from the panel's own width and never from a
     remembered value: re-applying a stored width from a resize path is what made both of this
     window's splitters refuse to drag. *)
  third := ClientWidth div 3;
  if third > Px(Self, 160) then
  begin
    FLeft.Width := third;
    FMid.Width := third;
  end;
  FitColumns;
  PlaceLabels;
end;

procedure TSpxAiPane.SetLocale(const ATag: string);
begin
  FLocale := ATag;
  FLocaleValue.Caption := ATag;
  PlaceLabels;
end;

procedure TSpxAiPane.SetVariables(const AVars: TSpxVarInfos);
var
  i, r, at: Integer;
  names: TStringList;
  kept: array of TSpxVarCase;
  keptNote: TStringList;
begin
  (* WHAT THE AUTHOR TYPED SURVIVES A RE-READ, AND IS KEPT BY NAME. The variable list is
     refreshed on every render, so rebuilding the grid from scratch would wipe a declaration
     the moment the reader touched the document -- which is exactly when they are working. By
     name and not by row, because adding a `#def` above the others shifts every row down and
     a row-indexed carry-over would hand each variable its neighbour's case. *)
  names := TStringList.Create;
  keptNote := TStringList.Create;
  try
    SetLength(kept, FAllowed.RowCount);
    for r := 1 to FAllowed.RowCount - 1 do
      if FAllowed.Cells[COL_NAME, r] <> '' then
      begin
        names.AddObject(FAllowed.Cells[COL_NAME, r], TObject(PtrInt(names.Count)));
        if r <= High(FCases) then kept[names.Count - 1] := FCases[r]
                             else kept[names.Count - 1] := vcNone;
        keptNote.Add(FAllowed.Cells[COL_NOTE, r]);
      end;

    FAllowed.RowCount := 1 + Length(AVars);
    SetLength(FCases, FAllowed.RowCount);
    for i := 0 to High(AVars) do
    begin
      r := i + 1;
      FAllowed.Cells[COL_NAME, r] := AVars[i].Name;
      at := names.IndexOf(AVars[i].Name);
      if at >= 0 then
      begin
        FCases[r] := kept[PtrInt(names.Objects[at])];
        FAllowed.Cells[COL_NOTE, r] := keptNote[PtrInt(names.Objects[at])];
      end
      else
      begin
        FCases[r] := vcNone;
        FAllowed.Cells[COL_NOTE, r] := '';
      end;
      FAllowed.Cells[COL_CASE, r] := Tr(CASE_IDS[FCases[r]]);
    end;
  finally
    names.Free;
    keptNote.Free;
  end;
  FitColumns;
end;

procedure TSpxAiPane.SetDocument(const AText: string; const ARows: TSpxPanelRows);
begin
  FDocText := AText;
  FRows := ARows;
end;

function TSpxAiPane.CollectVars: TSpxAllowedVars;
var
  r, n: Integer;
begin
  Result := nil;
  SetLength(Result, FAllowed.RowCount - 1);
  n := 0;
  for r := 1 to FAllowed.RowCount - 1 do
  begin
    if Trim(FAllowed.Cells[COL_NAME, r]) = '' then Continue;
    Result[n].Name := Trim(FAllowed.Cells[COL_NAME, r]);
    (* The stored ordinal, not the word on screen -- see Retranslate. *)
    if r <= High(FCases) then Result[n].Kase := FCases[r] else Result[n].Kase := vcNone;
    Result[n].Note := Trim(FAllowed.Cells[COL_NOTE, r]);
    Inc(n);
  end;
  SetLength(Result, n);
end;

(* The picker wrote a word into a cell; turn it back into the ordinal that IS the state.
   Runs while the language is stable, which is the only moment the two can be matched. *)
procedure TSpxAiPane.CaseEdited(Sender: TObject);
var
  r: Integer;
  k: TSpxVarCase;
begin
  r := FAllowed.Row;
  if (r < 1) or (r > High(FCases)) then Exit;
  for k := Low(TSpxVarCase) to High(TSpxVarCase) do
    if FAllowed.Cells[COL_CASE, r] = Tr(CASE_IDS[k]) then
    begin
      FCases[r] := k;
      Exit;
    end;
end;

procedure TSpxAiPane.CopyPromptClicked(Sender: TObject);
var
  built: TSpxBuiltPrompt;
begin
  if Trim(FBrief.Text) = '' then
  begin
    Say(Tr(sAiNeedBrief));
    Exit;
  end;
  built := SpxBuildAuthoringPrompt(FBrief.Text, FLocale, CollectVars,
                                   TSpxChannel(FChannel.ItemIndex),
                                   TSpxVariation(FLevel.ItemIndex));
  (* System and user prompt in one block, separated by a blank line. A reader pasting this into
     a chat window has one field, not two -- the split matters to an API and not to them. *)
  Clipboard.AsText := built.SystemPrompt + LineEnding + LineEnding + built.UserPrompt;
  Say(Tr(sAiCopied));
end;

procedure TSpxAiPane.InsertClicked(Sender: TObject);
var
  cleaned: string;
begin
  if Trim(FReply.Text) = '' then
  begin
    Say(Tr(sAiNeedReply));
    Exit;
  end;
  (* NEVER TRUST THE OUTPUT CONTRACT. The prompt says "no code fences, no quotes"; models emit
     them anyway. Contract in the prompt, tolerant parsing in the host -- and the cleaning
     happens HERE rather than in the editor, so the spans the repair prompt later quotes belong
     to the same text the engine validated. *)
  cleaned := SpxCleanModelTemplate(FReply.Text);
  if Assigned(FOnInsert) then FOnInsert(cleaned);
  Say(Tr(sAiInserted));
end;

procedure TSpxAiPane.RepairClicked(Sender: TObject);
var
  diags: TSpDiagList;
  d: TSpDiag;
  msgs: array of string;
  i, n: Integer;
  built: TSpxBuiltPrompt;
begin
  diags := TSpDiagList.Create;
  try
    SetLength(msgs, Length(FRows));
    n := 0;
    for i := 0 to High(FRows) do
    begin
      (* THE OPEN DOCUMENT ONLY. A finding inside an included fragment is real and the panel
         shows it, but its line and column belong to another file -- handing it to a repair
         prompt would point the model at a span of a text it has never seen. *)
      if FRows[i].Slug <> '' then Continue;
      d := Default(TSpDiag);
      d.Severity := FRows[i].Severity;
      d.Code := FRows[i].Code;
      d.Line := FRows[i].Line;
      d.Column := FRows[i].Column;
      diags.Add(d);
      msgs[n] := FRows[i].Text;
      Inc(n);
    end;
    SetLength(msgs, n);

    (* The filter that decides what a repair prompt reports lives in SpxPrompt and is gated
       there. This only has to notice that there is nothing to report, which is a different
       question and one the reader wants answered before the clipboard changes under them. *)
    n := 0;
    for i := 0 to diags.Count - 1 do
      if diags[i].Severity = 'error' then Inc(n);
    if n = 0 then
    begin
      Say(Tr(sAiNoErrors));
      Exit;
    end;

    built := SpxBuildRepairPrompt(FDocText, FLocale, diags, msgs, CollectVars);
    Clipboard.AsText := built.SystemPrompt + LineEnding + LineEnding + built.UserPrompt;
    Say(Tr(sAiRepairCopied));
  finally
    diags.Free;
  end;
end;

procedure TSpxAiPane.Retranslate;
var
  c: TSpxChannel;
  v: TSpxVariation;
  keepC, keepL: Integer;
  r, k: Integer;
begin
  FLocaleLabel.Caption := Tr(sAiLocale);
  FChannelLabel.Caption := Tr(sAiChannel);
  FLevelLabel.Caption := Tr(sAiLevel);
  FCopy.Caption := Tr(sAiCopyPrompt);
  FBriefLabel.Caption := Tr(sAiBrief);
  FAllowedLabel.Caption := Tr(sAiAllowed);
  FReplyLabel.Caption := Tr(sAiReply);
  FInsert.Caption := Tr(sAiInsert);
  FRepair.Caption := Tr(sAiCopyRepair);
  FInsert.Width := TextW(FInsert.Caption) + Px(Self, 28);
  FRepair.Width := TextW(FRepair.Caption) + Px(Self, 28);

  (* Rebuild the lists in the new language WITHOUT losing what is selected -- the choice is the
     reader's and is not a string. *)
  keepC := FChannel.ItemIndex;
  FChannel.Items.BeginUpdate;
  try
    FChannel.Items.Clear;
    for c := Low(TSpxChannel) to High(TSpxChannel) do FChannel.Items.Add(Tr(CHANNEL_IDS[c]));
  finally
    FChannel.Items.EndUpdate;
  end;
  FChannel.ItemIndex := keepC;

  keepL := FLevel.ItemIndex;
  FLevel.Items.BeginUpdate;
  try
    FLevel.Items.Clear;
    for v := Low(TSpxVariation) to High(TSpxVariation) do FLevel.Items.Add(Tr(LEVEL_IDS[v]));
  finally
    FLevel.Items.EndUpdate;
  end;
  FLevel.ItemIndex := keepL;

  (* THE DECLARED CASE IS HELD AS AN ORDINAL, NEVER READ BACK OFF THE SCREEN.

     `Retranslate` runs AFTER the language has changed, so by the time it looks at a cell,
     `Tr` already answers in the new language and the old word in that cell matches nothing.
     A version of this that recovered the case from the cell text would therefore reset every
     declaration to "not declared" on a language switch -- silently, and precisely for the
     reader who switches languages, who is the one most likely to be working in an inflected
     one. So the ordinal is the state and the cell is a view of it. *)
  FAllowed.Columns[COL_NAME].Title.Caption := Tr(sColName);
  FAllowed.Columns[COL_CASE].Title.Caption := Tr(sAiColCase);
  FAllowed.Columns[COL_NOTE].Title.Caption := Tr(sAiColNote);
  FAllowed.Columns[COL_CASE].PickList.Clear;
  for k := Ord(Low(TSpxVarCase)) to Ord(High(TSpxVarCase)) do
    FAllowed.Columns[COL_CASE].PickList.Add(Tr(CASE_IDS[TSpxVarCase(k)]));

  for r := 1 to FAllowed.RowCount - 1 do
    if r <= High(FCases) then
      FAllowed.Cells[COL_CASE, r] := Tr(CASE_IDS[FCases[r]]);

  Say('');
  PlaceLabels;
end;

end.
