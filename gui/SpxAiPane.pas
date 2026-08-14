(*
 * SpxAiPane -- the loop's settings and its manual path. No socket lives here either way:
 * the ONE file allowed to open one is SpxHttp (NET_ALLOWED), and this panel only holds what
 * a request will be built FROM.
 *
 * WHAT THIS PANEL IS SINCE R1-4. Two things, deliberately together. The SETTINGS of the
 * networked loop (ADR 0012, spec §4.5): the brief, the allow-list, and the connection
 * profile -- request format, endpoint, model, authorization mode and the key, where the key
 * goes straight to the Credential Manager and never into a config file (§6). And the MANUAL
 * path, which REMAINS on equal footing: copy the prompt, carry it to whatever model the
 * reader already uses, paste the answer back -- the path §11 has the Store reviewer walk
 * with no key and no network, and the one ADR 0011 shipped alone in R0.
 *
 * WHOSE CONSENT GATES THE NETWORK. Nothing is sent BY this panel: [Generate] and [Fix]
 * live here since the UX pass (the owner's finding -- "all the work is in one box and the
 * button that starts it is in another"), but both only FIRE AN EVENT, and the form's
 * handler walks the same consent dialog (Store policy 10.5.2) and the same key rules
 * before the loop is asked anything. The checkbox here is the visible state of that
 * consent and the way to withdraw it.
 *
 * THE BRIEF COLUMN HAS TWO MODES, AND ITS HEADER IS THE SWITCH. The main path measured on
 * the owner is "here is my TEXT, make a template of it" -- no brief to invent, so the
 * default mode takes the pasted text and composes the brief around it host-side
 * (SpxComposeFromTextBrief -- Studio's own, outside the prompt port and its byte gates).
 * The second mode is the free-form brief, unchanged. The combo that picks the mode IS the
 * column's caption, so the selected item always names what the box holds.
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
  Spintax, SpxStudio, SpxPrompt, SpxUi, SpxStrIds, SpxStrings, SpxLlm, SpxSecrets;

type
  (* What the panel needs from the form. Narrow seams, and not one of them is an engine
     call: the form owns the document, its locale, its variables and its diagnostics. *)
  TSpxAiInsertEvent = procedure(const AText: string) of object;
  (* The profile changed in the panel: the form persists it and bumps the loop's revision. *)
  TSpxAiProfileEvent = procedure(const AProfile: TSpxLlmProfile) of object;
  (* The reader is turning sending ON. The FORM owns the consent dialog (Store policy
     10.5.2: the opt-in describes the recipient), mutates the profile it is handed --
     Network and ConsentOrigin -- and answers whether consent was given. The panel only
     reflects the result. *)
  TSpxAiConsentEvent = function(var AProfile: TSpxLlmProfile): Boolean of object;

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
    (* The loop's two verbs, IN the panel that holds what they act on. They fire events;
       the form owns the consent gate, the key rules and the loop itself. The busy face of
       Generate is Stop -- one slot, two verbs, sized for the wider caption so the swap
       moves no neighbour. *)
    FGenerate: TButton;
    FFix: TButton;
    FLoopBusy: Boolean;
    FOnGenerate: TNotifyEvent;
    FOnFix: TNotifyEvent;

    (* ── the connection profile (R1-4, spec §4.5): two rows of settings under the top
       strip. The KEY FIELD IS WRITE-ONLY: the secret is never read back into a control,
       so nothing here can show or log it -- typing goes to the Credential Manager on
       "attach" and the edit is cleared. What is DISPLAYED is only whether a key is
       attached to the current endpoint, which KeyOrigin answers without touching the
       store. `service-token` is deliberately not offered (§6 reserves it; showing it
       would promise a managed endpoint that does not exist). ── *)
    FProfA: TPanel;
    FProfB: TPanel;
    FConnLabel: TLabel;
    FFormatLabel: TLabel;
    FFormat: TComboBox;
    FEndpointLabel: TLabel;
    FEndpoint: TEdit;
    FModelLabel: TLabel;
    (* Editable combo, NOT a picker: the list is SpxLlmModelSuggestions -- a dated
       suggestion, never a validator -- and the text goes into the request verbatim. *)
    FModel: TComboBox;
    FAuthLabel: TLabel;
    FAuth: TComboBox;
    FKeyLabel: TLabel;
    FKeyEdit: TEdit;
    FKeySave: TButton;
    FKeyForget: TButton;
    FKeyState: TLabel;
    FNetwork: TCheckBox;
    FProfile: TSpxLlmProfile;
    (* Set while SetProfile/Retranslate rewrite controls, so their change handlers do not
       fire OnProfileChanged about an assignment the form itself just made. *)
    FProfLoading: Boolean;
    FOnProfileChanged: TSpxAiProfileEvent;
    FOnEnableNetwork: TSpxAiConsentEvent;
    FOnDeclChanged: TNotifyEvent;

    FLeft: TPanel;
    FBriefMode: TComboBox;   (* the column's header IS the mode switch; item 0 = source text *)
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
    FReplace: TButton;
    FRepair: TButton;

    FLocale: string;
    FRows: TSpxPanelRows;
    (* The declared case per grid row, indexed by ROW (so [0] is the header and unused). This
       is the state; the cell that shows it is a view. See Retranslate for why. *)
    FCases: array of TSpxVarCase;
    FOnInsert: TSpxAiInsertEvent;
    FOnReplace: TSpxAiInsertEvent;
    FDocText: string;

    procedure CopyPromptClicked(Sender: TObject);
    procedure AcceptReply(AReplace: Boolean);
    procedure InsertClicked(Sender: TObject);
    procedure ReplaceClicked(Sender: TObject);
    procedure RepairClicked(Sender: TObject);
    procedure CaseEdited(Sender: TObject);
    function CollectVars: TSpxAllowedVars;
    procedure Say(const AText: string);
    procedure PlaceLabels;
    procedure FitColumns;
    function TextW(const S: string): Integer;
    procedure GenerateClicked(Sender: TObject);
    procedure FixClicked(Sender: TObject);
    procedure ProfileUiChanged(Sender: TObject);
    procedure FormatPicked(Sender: TObject);
    procedure RefreshModelSuggestions;
    procedure NetworkToggled(Sender: TObject);
    procedure KeySaveClicked(Sender: TObject);
    procedure KeyForgetClicked(Sender: TObject);
    procedure ReadProfileUi;
    procedure ShowKeyState;
    procedure ShowNetworkState;
    procedure AnnounceProfile;
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
    (* A DIFFERENT DOCUMENT IS A DIFFERENT SET OF VARIABLES, even when the names repeat.

       `SetVariables` carries the author's case and note across a re-read BY NAME, which is
       right while one document is being edited and wrong the moment another is opened: a
       second file with its own `%city%` inherited the first file's declared case and note,
       and both went into the prompt. Found by review.

       Only the invisible part is cleared. The brief stays: it is text the author can see and
       is still typing, and clearing it on File > New would destroy work to fix a bug about
       something they cannot see. *)
    procedure ResetDeclarations;
    procedure Retranslate;
    (* ── the loop's seams (R1-4) ── *)
    (* The saved profile, applied to the controls. The panel keeps its own copy; every edit
       flows back through OnProfileChanged so the form remains the one that persists. *)
    procedure SetProfile(const AProfile: TSpxLlmProfile);
    function Profile: TSpxLlmProfile;
    (* What a Generate request is built from -- the panel's own fields. In source-text mode
       the brief is COMPOSED around the pasted text (SpxComposeFromTextBrief); '' when the
       box is empty either way, so every "nothing to send" guard keeps working. *)
    function Brief: string;
    (* The empty-box message in the current mode's words: "paste the text" is not
       "write a brief", and saying the wrong one sends the reader to invent a document
       they already have. *)
    function EmptyBriefMessage: string;
    (* The loop's state, shown on the panel's own buttons: Generate wears Stop while busy,
       Fix is enabled only when the FORM says its snapshot is current -- the form computes
       that, because the rows and the revision are the form's. *)
    procedure ShowLoopState(ABusy, AFixEnabled: Boolean);
    function Channel: TSpxChannel;
    function Level: TSpxVariation;
    function AllowedVars: TSpxAllowedVars;
    (* A candidate the loop could not apply -- stale, degenerate, out of fix budget --
       lands in the reply box, where the manual Insert/Replace buttons already know what
       to do with it. Shown, never applied: that distinction is the loop's whole table. *)
    procedure SetReply(const AText: string);
    (* The manual path: §11 has the reviewer check the product with no key and no
       network, and this is that path -- the panel's own button, since the strip's
       ▾ menu went with the UX pass. *)
    procedure CopyPrompt;
    property OnInsert: TSpxAiInsertEvent read FOnInsert write FOnInsert;
    (* Fired for the SAME cleaned text as OnInsert. The two differ in what the window does
       with it, not in what the panel produces -- so a repair answer, which is the whole
       document, goes over the document instead of beside it. *)
    property OnReplace: TSpxAiInsertEvent read FOnReplace write FOnReplace;
    property OnGenerate: TNotifyEvent read FOnGenerate write FOnGenerate;
    property OnFix: TNotifyEvent read FOnFix write FOnFix;
    property OnProfileChanged: TSpxAiProfileEvent read FOnProfileChanged write FOnProfileChanged;
    property OnEnableNetwork: TSpxAiConsentEvent read FOnEnableNetwork write FOnEnableNetwork;
    (* The allow-list changed -- a case picked, a note edited. Part of the loop's snapshot,
       so the form bumps the revision on it. *)
    property OnDeclChanged: TNotifyEvent read FOnDeclChanged write FOnDeclChanged;
  end;

implementation

const
  LF = #10;

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

(* SpxPrompt joins with LF by contract, because the builder it ports does. The Windows
   clipboard's contract is CRLF, and a legacy EDIT control shows an LF-only payload as ONE
   line -- no characters lost, but a reader who pastes into Notepad first sees a wall of text
   and reads the panel's main button as broken. Converted at the boundary, which is the only
   place that knows it is a clipboard. *)
function ForClipboard(const S: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    if (S[i] = #10) and ((i = 1) or (S[i - 1] <> #13)) then Result := Result + #13;
    Result := Result + S[i];
  end;
end;

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

  (* Generate and Fix close the ask row: the flow reads left to right -- what to make,
     how varied, then the verb that makes it. Both fire the FORM's handlers (see the
     header); Fix is born disabled and only the form enables it. *)
  FGenerate := TButton.Create(Self);
  FGenerate.Parent := FTop;
  FGenerate.Top := Px(Self, 4);
  FGenerate.Height := Px(Self, 24);
  FGenerate.OnClick := @GenerateClicked;

  FFix := TButton.Create(Self);
  FFix.Parent := FTop;
  FFix.Top := Px(Self, 4);
  FFix.Height := Px(Self, 24);
  FFix.Enabled := False;
  FFix.OnClick := @FixClicked;

  (* ── the connection profile, two rows AT THE PANEL'S FOOT since the UX pass ──

     Settings are touched once and the work is daily, so the daily part gets the prime
     rows: ask, columns, answer actions -- and the connection sinks to the footer, still
     one glance away. Three `alBottom` siblings (actions, then these two) are ordered by
     `Top`, not by creation order -- the same LCL rule this file already states for
     `alLeft` and `alRight`; larger Top sits lower, and the numbers only state the order. *)
  FProfA := TPanel.Create(Self);
  FProfA.Parent := Self;
  FProfA.Top := 20000;
  FProfA.Align := alBottom;
  FProfA.Height := Px(Self, 30);
  FProfA.BevelOuter := bvNone;

  FConnLabel := TLabel.Create(Self);
  FConnLabel.Parent := FProfA;
  FConnLabel.Top := Px(Self, 7);
  FConnLabel.Font.Style := [fsBold];

  FFormatLabel := TLabel.Create(Self);
  FFormatLabel.Parent := FProfA;
  FFormatLabel.Top := Px(Self, 7);

  FFormat := TComboBox.Create(Self);
  FFormat.Parent := FProfA;
  FFormat.Style := csDropDownList;
  FFormat.Top := Px(Self, 3);
  FFormat.Width := Px(Self, 150);
  (* Item order IS the enum's ordinal, the same contract as the case picker's list. The
     labels are the formats' own names, not translated -- a wire format is a proper noun. *)
  FFormat.Items.Add('Anthropic Messages');
  FFormat.Items.Add('OpenAI-compatible');
  FFormat.ItemIndex := Ord(lkOpenAiCompatible);
  FFormat.OnChange := @FormatPicked;

  FEndpointLabel := TLabel.Create(Self);
  FEndpointLabel.Parent := FProfA;
  FEndpointLabel.Top := Px(Self, 7);

  FEndpoint := TEdit.Create(Self);
  FEndpoint.Parent := FProfA;
  FEndpoint.Top := Px(Self, 3);
  FEndpoint.OnEditingDone := @ProfileUiChanged;

  FModelLabel := TLabel.Create(Self);
  FModelLabel.Parent := FProfA;
  FModelLabel.Top := Px(Self, 7);

  (* csDropDown, the EDITABLE style: the list is a dated suggestion (SpxLlmModelSuggestions
     -- exact wire ids, because the owner typed "Opus 5" and the provider answered with an
     error), and free text stays first-class -- OpenAI-compatible names are server-defined
     and any id not on the list must still be typable. Both routes announce the profile:
     picking fires OnSelect at once, typing lands on OnEditingDone. *)
  FModel := TComboBox.Create(Self);
  FModel.Parent := FProfA;
  FModel.Style := csDropDown;
  FModel.Top := Px(Self, 3);
  FModel.Width := Px(Self, 150);
  FModel.OnEditingDone := @ProfileUiChanged;
  FModel.OnSelect := @ProfileUiChanged;

  FProfB := TPanel.Create(Self);
  FProfB.Parent := Self;
  FProfB.Top := 25000;
  FProfB.Align := alBottom;
  FProfB.Height := Px(Self, 30);
  FProfB.BevelOuter := bvNone;

  FAuthLabel := TLabel.Create(Self);
  FAuthLabel.Parent := FProfB;
  FAuthLabel.Top := Px(Self, 7);

  FAuth := TComboBox.Create(Self);
  FAuth.Parent := FProfB;
  FAuth.Style := csDropDownList;
  FAuth.Top := Px(Self, 3);
  FAuth.Width := Px(Self, 110);
  FAuth.OnChange := @ProfileUiChanged;

  FKeyLabel := TLabel.Create(Self);
  FKeyLabel.Parent := FProfB;
  FKeyLabel.Top := Px(Self, 7);

  FKeyEdit := TEdit.Create(Self);
  FKeyEdit.Parent := FProfB;
  FKeyEdit.Top := Px(Self, 3);
  FKeyEdit.Width := Px(Self, 160);
  (* Write-only, and masked while it is written: the one moment the secret exists in a
     control is between typing and "attach", and it is not readable off the screen even
     then. `PasswordChar` is a single-byte Char, so the mask is the ASCII asterisk -- a
     multi-byte bullet does not fit the property's type. *)
  FKeyEdit.PasswordChar := '*';

  FKeySave := TButton.Create(Self);
  FKeySave.Parent := FProfB;
  FKeySave.Top := Px(Self, 2);
  FKeySave.Height := Px(Self, 25);
  FKeySave.OnClick := @KeySaveClicked;

  FKeyForget := TButton.Create(Self);
  FKeyForget.Parent := FProfB;
  FKeyForget.Top := Px(Self, 2);
  FKeyForget.Height := Px(Self, 25);
  FKeyForget.OnClick := @KeyForgetClicked;

  FKeyState := TLabel.Create(Self);
  FKeyState.Parent := FProfB;
  FKeyState.Top := Px(Self, 7);

  FNetwork := TCheckBox.Create(Self);
  FNetwork.Parent := FProfB;
  FNetwork.Top := Px(Self, 5);
  (* A TCheckBox is BORN AutoSize, and PlaceLabels runs from Resize -- setting a width on an
     auto-sized control from a resize path is the ChangeBounds loop the charter already paid
     for twice, and it cost a startup dialog here too (measured: 204 vs 208, the auto-measure
     and the bitmap measure disagreeing forever). *)
  FNetwork.AutoSize := False;
  FNetwork.OnChange := @NetworkToggled;

  FProfile := SpxLlmDefaultProfile;
  RefreshModelSuggestions;

  (* ── the brief, the allow-list and the answer, side by side ── *)

  FBottom := TPanel.Create(Self);
  FBottom.Parent := Self;
  (* Highest of the three alBottom rows: the answer's actions stay adjacent to the answer,
     with the profile footer below them. *)
  FBottom.Top := 15000;
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

  (* The column's header is the mode switch (see the unit header). Item order is the
     mode's meaning and is relied on everywhere the mode is read: 0 = the reader's own
     text to convert (the main path, and the default), 1 = a free-form brief. *)
  FBriefMode := TComboBox.Create(Self);
  FBriefMode.Parent := FLeft;
  FBriefMode.Style := csDropDownList;
  FBriefMode.Align := alTop;
  FBriefMode.Items.Add(Tr(sAiModeFromText));
  FBriefMode.Items.Add(Tr(sAiBrief));
  FBriefMode.ItemIndex := 0;

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
  (* AND NOT `ReadOnly`, WHICH CLOSES THE PICKER TOO. `TCustomGrid.EditingAllowed`
     (grids.pas:8656-8660) answers False for a read-only column before it ever asks which
     editor the column wants, so `cbsPickList` plus `ReadOnly` is a cell that cannot be opened
     at all -- the case could never be declared, which is most of the reason this panel exists.
     Found by review, confirmed in LCL's source. Typing is refused in CaseEdited instead, by
     reading the value back: the same shape the group editor uses for a definition's value. *)
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
  FRepair.Left := 1000;
  FRepair.Align := alRight;
  FRepair.BorderSpacing.Around := Px(Self, 4);
  FRepair.OnClick := @RepairClicked;

  (* `Left` STATES THE ORDER, BECAUSE CREATION ORDER DOES NOT.

     Three `alRight` buttons all born at Left 0 are ordered by the align pass, and the pass does
     not answer the same way twice: photographed in English it gave Repair, Insert, Replace, and
     the very next build photographed in German gave Replace, Insert, Repair -- the same code,
     opposite ends for the button that overwrites the document. The charter already records this
     for two `alLeft` panels; it is the same rule and the same fix, and `alRight` needed it too.

     Larger Left is further right, so Insert -- which adds rather than overwrites -- keeps the
     corner a hand reaches without looking, and Replace sits inboard of it. *)
  FReplace := TButton.Create(Self);
  FReplace.Parent := FBottom;
  FReplace.Left := 10000;
  FReplace.Align := alRight;
  FReplace.BorderSpacing.Around := Px(Self, 4);
  FReplace.OnClick := @ReplaceClicked;

  FInsert := TButton.Create(Self);
  FInsert.Parent := FBottom;
  FInsert.Left := 20000;
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
  x, w: Integer;
begin
  if FTop = nil then Exit;

  x := Px(Self, 8);
  FLocaleLabel.Left := x;  Inc(x, TextW(FLocaleLabel.Caption) + Px(Self, 6));
  FLocaleValue.Left := x;  Inc(x, TextW(FLocaleValue.Caption) + Px(Self, 16));
  FChannelLabel.Left := x; Inc(x, TextW(FChannelLabel.Caption) + Px(Self, 6));
  FChannel.Left := x;      Inc(x, FChannel.Width + Px(Self, 16));
  FLevelLabel.Left := x;   Inc(x, TextW(FLevelLabel.Caption) + Px(Self, 6));
  FLevel.Left := x;        Inc(x, FLevel.Width + Px(Self, 16));
  (* ALL THREE ACTIONS hold the row's RIGHT edge, like every action row in this window --
     and for the minimum-width reason: laid into the left flow they were the FIRST thing a
     narrow window clipped, and in Russian the flow outgrows the form's own MinWidth (found
     by Codex review, ~822 px of flow against ~716 of row; its second pass caught Copy
     prompt left behind under the right-aligned pair -- the REQUIRED no-network path, so it
     joins the protected group). What gives way under pressure is now the Variation combo,
     a setting a wider window brings back, never a verb. The Generate slot fits the WIDER
     of its two faces, so the busy swap to Stop moves no neighbour -- the strip's old rule,
     carried over with the button. The wider gap before Copy prompt separates the manual
     path from the loop's pair. *)
  w := TextW(Tr(sGenerate));
  if TextW(Tr(sStop)) > w then w := TextW(Tr(sStop));
  FGenerate.Width := w + Px(Self, 28);
  FFix.Width := TextW(Tr(sAiFix)) + Px(Self, 28);
  FCopy.Width := TextW(FCopy.Caption) + Px(Self, 28);
  FFix.Left := FTop.ClientWidth - Px(Self, 8) - FFix.Width;
  FGenerate.Left := FFix.Left - Px(Self, 6) - FGenerate.Width;
  FCopy.Left := FGenerate.Left - Px(Self, 14) - FCopy.Width;

  (* ── the profile rows, the same rule: every caption hung off its field, measured. The
     endpoint is the one field that stretches -- an address is the longest thing here and
     the row's spare width belongs to it. ── *)
  if FProfA = nil then Exit;

  x := Px(Self, 8);
  FConnLabel.Left := x;     Inc(x, TextW(FConnLabel.Caption) + Px(Self, 16));
  FFormatLabel.Left := x;   Inc(x, TextW(FFormatLabel.Caption) + Px(Self, 6));
  FFormat.Left := x;        Inc(x, FFormat.Width + Px(Self, 16));
  FEndpointLabel.Left := x; Inc(x, TextW(FEndpointLabel.Caption) + Px(Self, 6));
  FEndpoint.Left := x;
  w := ClientWidth - x - Px(Self, 16) - TextW(FModelLabel.Caption) - Px(Self, 6)
       - FModel.Width - Px(Self, 8);
  if w < Px(Self, 120) then w := Px(Self, 120);
  FEndpoint.Width := w;
  Inc(x, w + Px(Self, 16));
  FModelLabel.Left := x;    Inc(x, TextW(FModelLabel.Caption) + Px(Self, 6));
  FModel.Left := x;

  x := Px(Self, 8);
  FAuthLabel.Left := x;  Inc(x, TextW(FAuthLabel.Caption) + Px(Self, 6));
  FAuth.Left := x;       Inc(x, FAuth.Width + Px(Self, 16));
  FKeyLabel.Left := x;   Inc(x, TextW(FKeyLabel.Caption) + Px(Self, 6));
  FKeyEdit.Left := x;    Inc(x, FKeyEdit.Width + Px(Self, 8));
  FKeySave.Left := x;
  FKeySave.Width := TextW(FKeySave.Caption) + Px(Self, 20);
  Inc(x, FKeySave.Width + Px(Self, 6));
  FKeyForget.Left := x;
  FKeyForget.Width := TextW(FKeyForget.Caption) + Px(Self, 20);
  Inc(x, FKeyForget.Width + Px(Self, 12));
  FKeyState.Left := x;   Inc(x, TextW(FKeyState.Caption) + Px(Self, 16));
  FNetwork.Left := x;
  FNetwork.Width := TextW(FNetwork.Caption) + Px(Self, 22);
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

procedure TSpxAiPane.ResetDeclarations;
var r: Integer;
begin
  for r := 1 to FAllowed.RowCount - 1 do
  begin
    FAllowed.Cells[COL_NOTE, r] := '';
    FAllowed.Cells[COL_CASE, r] := Tr(CASE_IDS[vcNone]);
  end;
  SetLength(FCases, FAllowed.RowCount);
  for r := 0 to High(FCases) do FCases[r] := vcNone;
  (* The rows themselves are left to the next render, which is already on its way: emptying
     the grid here would blink it for one render and then fill it again. *)
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

(* THE EDIT IS READ BACK, and a value this panel does not recognise is refused rather than
   stored. The picker offers exactly the seven words, but the cell is editable -- it has to be,
   or the picker will not open -- so someone can type into it. A typed word that matches
   nothing would otherwise land as "not declared", which is the one value in that column that
   must never arrive by accident: it drops the rule the model needed and says nothing.

   Runs while the language is stable, which is the only moment a word and an ordinal can be
   matched at all -- see Retranslate. *)
procedure TSpxAiPane.CaseEdited(Sender: TObject);
var
  r: Integer;
  k: TSpxVarCase;
begin
  r := FAllowed.Row;
  if (r < 1) or (r > High(FCases)) then Exit;
  (* The allow-list is part of the loop's snapshot, so any finished edit -- a case picked, a
     note typed -- tells the form, which bumps the revision. Over-announcing is safe (a stale
     result is shown rather than applied); under-announcing is the race the revision exists
     to close. *)
  if Assigned(FOnDeclChanged) then FOnDeclChanged(Self);
  for k := Low(TSpxVarCase) to High(TSpxVarCase) do
    if FAllowed.Cells[COL_CASE, r] = Tr(CASE_IDS[k]) then
    begin
      FCases[r] := k;
      Exit;
    end;
  (* Not one of the seven: put back what was declared before the edit. *)
  FAllowed.Cells[COL_CASE, r] := Tr(CASE_IDS[FCases[r]]);
end;

(* ── the connection profile (R1-4) ── *)

procedure TSpxAiPane.ReadProfileUi;
begin
  if FFormat.ItemIndex >= 0 then FProfile.Kind := TSpxLlmKind(FFormat.ItemIndex);
  FProfile.Endpoint := Trim(FEndpoint.Text);
  FProfile.Model := Trim(FModel.Text);
  (* The auth combo offers two of the three modes (§6 reserves service-token). ItemIndex -1
     -- a service-token profile from a later version's file -- leaves the mode untouched
     rather than silently rewriting it to something weaker. *)
  if FAuth.ItemIndex = 0 then FProfile.Auth := laNone
  else if FAuth.ItemIndex = 1 then FProfile.Auth := laApiKey;
end;

procedure TSpxAiPane.ShowKeyState;
var
  masked: string;
begin
  (* A service-token profile -- reachable only from a later version's or a hand-edited
     file -- has no key path in R1: the attach controls store the BYOK namespace, the loop
     reads the SERVICE one (§6 keeps them apart), so leaving them live would show "a key is
     attached" about a slot the request never reads. Disabled, and the state line speaks
     about the namespace this mode actually uses, which holds nothing. Found by Codex
     review's second pass. *)
  FKeyEdit.Enabled := FProfile.Auth <> laServiceToken;
  FKeySave.Enabled := FProfile.Auth <> laServiceToken;
  FKeyForget.Enabled := FProfile.Auth <> laServiceToken;
  (* The banner is state, so it is cleared here and set only in the one branch that has a
     readable attached key -- a stale mask over a detached or missing key would be the
     field claiming a grant nobody holds. *)
  FKeyEdit.TextHint := '';
  if FProfile.Auth = laServiceToken then FKeyState.Caption := Tr(sAiKeyMissing)
  else if FProfile.KeyOrigin = '' then FKeyState.Caption := Tr(sAiKeyMissing)
  else if SpxLlmKeyAttached(FProfile) then
  begin
    (* WHICH key, not merely that one exists (the owner's ask). The hint is read from the
       store on each refresh and shown through SpxLlmKeyHint -- start, ellipsis, last
       four: the dashboard fragment, recognisable and unusable. The FIELD stays
       write-only; this is a caption, and the variable holding the secret is cleared the
       line after. A store that no longer answers (deleted by hand, a fresh Windows
       profile) falls back to the plain sentence -- the same honest state the loop would
       later report as "enter it again". *)
    if SpxSecretRead(skByokKey, FProfile.Id, masked) then
    begin
      FKeyState.Caption := SpxLlmKeyHint(masked) + ' — ' + Tr(sAiKeyStored);
      (* AND IN THE FIELD ITSELF, as the grey cue banner: the owner attached a key and
         still read the EMPTY BOX as "no key here" -- the state label sits after two
         buttons, and the eye checks the field. The banner is a placeholder, not text:
         Text stays '', so the write-only rule holds and Attach can never re-store the
         mask as a key. *)
      FKeyEdit.TextHint := SpxLlmKeyHint(masked);
      masked := '';
    end
    else
      FKeyState.Caption := Tr(sAiKeyStored);
  end
  else FKeyState.Caption := Tr(sAiKeyDetached);
  FKeyState.Hint := FKeyState.Caption;
  FKeyState.ShowHint := True;
end;

procedure TSpxAiPane.ShowNetworkState;
var
  was: Boolean;
begin
  (* Written under the loading flag: assigning Checked fires OnChange, and this is a VIEW
     of the profile, not an edit of it. *)
  was := FProfLoading;
  FProfLoading := True;
  FNetwork.Checked := SpxLlmConsentInForce(FProfile);
  FProfLoading := was;
end;

procedure TSpxAiPane.AnnounceProfile;
begin
  ShowKeyState;
  ShowNetworkState;
  PlaceLabels;
  if (not FProfLoading) and Assigned(FOnProfileChanged) then FOnProfileChanged(FProfile);
end;

procedure TSpxAiPane.ProfileUiChanged(Sender: TObject);
begin
  if FProfLoading then Exit;
  ReadProfileUi;
  AnnounceProfile;
end;

procedure TSpxAiPane.FormatPicked(Sender: TObject);
var
  old: TSpxLlmKind;
begin
  if FProfLoading then Exit;
  old := FProfile.Kind;
  (* A reader who never typed an address meant the picked format's usual one, so the
     endpoint follows -- but only while it still IS the other format's default (or empty).
     A typed address is the reader's and is never rewritten. *)
  if (Trim(FEndpoint.Text) = '') or (Trim(FEndpoint.Text) = SpxLlmDefaultEndpoint(old)) then
  begin
    FProfLoading := True;
    if FFormat.ItemIndex >= 0 then
      FEndpoint.Text := SpxLlmDefaultEndpoint(TSpxLlmKind(FFormat.ItemIndex));
    FProfLoading := False;
  end;
  ReadProfileUi;
  RefreshModelSuggestions;
  AnnounceProfile;
end;

(* The list follows the FORMAT and only the format; the text is the reader's and survives
   every rebuild -- a suggestion list that rewrote the field would be a validator with
   extra steps. *)
procedure TSpxAiPane.RefreshModelSuggestions;
var
  keep: string;
  sugg: TSpxModelSuggestions;
  i: Integer;
begin
  keep := FModel.Text;
  FModel.Items.BeginUpdate;
  try
    FModel.Items.Clear;
    sugg := SpxLlmModelSuggestions(FProfile.Kind);
    for i := 0 to High(sugg) do FModel.Items.Add(sugg[i]);
  finally
    FModel.Items.EndUpdate;
  end;
  FModel.Text := keep;
end;

procedure TSpxAiPane.GenerateClicked(Sender: TObject);
begin
  if Assigned(FOnGenerate) then FOnGenerate(Self);
end;

procedure TSpxAiPane.FixClicked(Sender: TObject);
begin
  if Assigned(FOnFix) then FOnFix(Self);
end;

procedure TSpxAiPane.ShowLoopState(ABusy, AFixEnabled: Boolean);
begin
  FLoopBusy := ABusy;
  if ABusy then FGenerate.Caption := Tr(sStop) else FGenerate.Caption := Tr(sGenerate);
  FFix.Enabled := AFixEnabled;
end;

procedure TSpxAiPane.NetworkToggled(Sender: TObject);
begin
  if FProfLoading then Exit;
  ReadProfileUi;
  if FNetwork.Checked then
  begin
    (* ON goes through the form's consent dialog (Store policy 10.5.2): the event mutates
       Network and ConsentOrigin only on an OK. Refused -- or nobody listening -- the box
       goes straight back off; a tick that stays on without a grant would be the checkbox
       claiming a consent nobody gave. *)
    if Assigned(FOnEnableNetwork) and FOnEnableNetwork(FProfile) then
    begin
      AnnounceProfile;
      Exit;
    end;
    FProfile.Network := False;
    ShowNetworkState;
    Exit;
  end;
  (* OFF is the reader's to do freely -- the "way to turn it off" the consent text names. *)
  FProfile.Network := False;
  FProfile.ConsentOrigin := '';
  AnnounceProfile;
end;

procedure TSpxAiPane.KeySaveClicked(Sender: TObject);
var
  origin: string;
begin
  ReadProfileUi;
  if Trim(FKeyEdit.Text) = '' then
  begin
    Say(Tr(sAiKeyMissing));
    Exit;
  end;
  (* No valid origin, no grant: a key attached to an unparseable address is a key that can
     never be sent and never be detached by an address CHANGE, which is the rule doing the
     protecting. The key stays in the field so fixing the endpoint and pressing attach again
     is one step, not a retype. *)
  origin := SpxLlmOrigin(FProfile.Endpoint);
  if origin = '' then
  begin
    { NOT "no key attached" (review, 2026-08-15): the key is right there in the field --
      the ADDRESS is what cannot be read, and the old sentence sent the reader to retype
      the key and fail the same way. Name the thing to fix. }
    Say(Tr(sAiKeyBadEndpoint));
    ShowKeyState;
    Exit;
  end;
  if SpxSecretStore(skByokKey, FProfile.Id, Trim(FKeyEdit.Text)) then
  begin
    FKeyEdit.Text := '';
    FProfile.KeyOrigin := origin;
    Say(Tr(sAiKeyStored));
    AnnounceProfile;
  end
  else
    (* An OS-level refusal, rare enough to show as the component and its code -- a number,
       never a value. *)
    Say('Credential Manager: ' + IntToStr(SpxSecretsLastError));
end;

procedure TSpxAiPane.KeyForgetClicked(Sender: TObject);
begin
  if SpxSecretForget(skByokKey, FProfile.Id) then
  begin
    FProfile.KeyOrigin := '';
    Say(Tr(sAiKeyMissing));
    AnnounceProfile;
  end
  else
    Say('Credential Manager: ' + IntToStr(SpxSecretsLastError));
end;

procedure TSpxAiPane.SetProfile(const AProfile: TSpxLlmProfile);
begin
  FProfile := AProfile;
  (* An empty id would file the key under `byok/` -- one slot for every profile a hand-edited
     file can invent. The default name is the floor. *)
  if Trim(FProfile.Id) = '' then FProfile.Id := SpxLlmDefaultProfile.Id;
  FProfLoading := True;
  try
    FFormat.ItemIndex := Ord(FProfile.Kind);
    FEndpoint.Text := FProfile.Endpoint;
    FModel.Text := FProfile.Model;
    case FProfile.Auth of
      laNone: FAuth.ItemIndex := 0;
      laApiKey: FAuth.ItemIndex := 1;
    else
      (* service-token: recognised in the file, not offered here (§6) -- shown as no
         selection rather than silently rewritten to a different mode. *)
      FAuth.ItemIndex := -1;
    end;
    FNetwork.Checked := SpxLlmConsentInForce(FProfile);
    RefreshModelSuggestions;
    ShowKeyState;
  finally
    FProfLoading := False;
  end;
  PlaceLabels;
end;

function TSpxAiPane.Profile: TSpxLlmProfile;
begin
  Result := FProfile;
end;

function TSpxAiPane.Brief: string;
begin
  (* Item 0 is the source-text mode: the paste is cleaned of markup FIRST -- a browser or
     Word hands over style soup, and none of it is the reader's text (SpxCleanSourceHtml;
     plain prose passes through byte-identical, the gate is a recognised tag) -- then the
     brief is composed AROUND what remains. A paste that was ONLY markup cleans to '' and
     composes to '', so the guards upstream still answer "nothing to send". The manual
     "Copy prompt" path runs through here too, so the reader can SEE the cleaned source
     in what they carry away. *)
  if FBriefMode.ItemIndex = 0 then
    Result := SpxComposeFromTextBrief(SpxCleanSourceHtml(FBrief.Text))
  else
    Result := FBrief.Text;
end;

function TSpxAiPane.EmptyBriefMessage: string;
begin
  if FBriefMode.ItemIndex = 0 then Result := Tr(sAiNeedText)
  else Result := Tr(sAiNeedBrief);
end;

function TSpxAiPane.Channel: TSpxChannel;
begin
  Result := TSpxChannel(FChannel.ItemIndex);
end;

function TSpxAiPane.Level: TSpxVariation;
begin
  Result := TSpxVariation(FLevel.ItemIndex);
end;

function TSpxAiPane.AllowedVars: TSpxAllowedVars;
begin
  Result := CollectVars;
end;

procedure TSpxAiPane.SetReply(const AText: string);
begin
  FReply.Text := AText;
end;

procedure TSpxAiPane.CopyPrompt;
begin
  CopyPromptClicked(nil);
end;

procedure TSpxAiPane.CopyPromptClicked(Sender: TObject);
var
  built: TSpxBuiltPrompt;
  b: string;
begin
  (* Brief() and not the raw box, for the GUARD as well as the build: a paste that was
     only markup cleans to nothing, and checking the raw text would copy a prompt with an
     empty brief while the network path refuses the same input (found by Codex review).
     One call -- the cleaner runs once, and what is checked is what is sent. *)
  b := Brief;
  if Trim(b) = '' then
  begin
    Say(EmptyBriefMessage);
    Exit;
  end;
  built := SpxBuildAuthoringPrompt(b, FLocale, CollectVars,
                                   TSpxChannel(FChannel.ItemIndex),
                                   TSpxVariation(FLevel.ItemIndex));
  (* System and user prompt in one block, separated by a blank line. A reader pasting this into
     a chat window has one field, not two -- the split matters to an API and not to them. *)
  Clipboard.AsText := ForClipboard(built.SystemPrompt + LF + LF + built.UserPrompt);
  Say(Tr(sAiCopied));
end;

(* Both buttons, and the only difference is the last two lines. Written as one body so the
   cleaning, the empty-after-cleaning refusal and the reasons for both cannot drift apart --
   they were argued once and belong to both actions. *)
procedure TSpxAiPane.AcceptReply(AReplace: Boolean);
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
  (* AND THE CLEANING CAN LEAVE NOTHING. An empty fenced block is not empty until it is
     cleaned, so the guard above passes and this does not: the form refuses an empty insert,
     and saying "draft inserted" over it would be a sentence about something that did not
     happen. Reported by review with the exact input -- three backticks, a newline, three
     backticks -- which is `clean-fence-only` in the corpus, and its output is zero bytes. *)
  if cleaned = '' then
  begin
    Say(Tr(sAiNeedReply));
    Exit;
  end;
  if AReplace then
  begin
    if Assigned(FOnReplace) then FOnReplace(cleaned);
    Say(Tr(sAiReplaced));
  end
  else
  begin
    if Assigned(FOnInsert) then FOnInsert(cleaned);
    Say(Tr(sAiInserted));
  end;
end;

procedure TSpxAiPane.InsertClicked(Sender: TObject);
begin
  AcceptReply(False);
end;

procedure TSpxAiPane.ReplaceClicked(Sender: TObject);
begin
  AcceptReply(True);
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
    Clipboard.AsText := ForClipboard(built.SystemPrompt + LF + LF + built.UserPrompt);
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
  (* The loop buttons: the caption the busy state owns is re-applied in the new language
     too -- a language switch mid-flight must not turn Stop back into Generate. *)
  if FLoopBusy then FGenerate.Caption := Tr(sStop) else FGenerate.Caption := Tr(sGenerate);
  FFix.Caption := Tr(sAiFix);
  (* The mode combo rebuilds like every picker here: the MODE is the ItemIndex and the
     items are a view of it. *)
  keepC := FBriefMode.ItemIndex;
  FBriefMode.Items.BeginUpdate;
  try
    FBriefMode.Items.Clear;
    FBriefMode.Items.Add(Tr(sAiModeFromText));
    FBriefMode.Items.Add(Tr(sAiBrief));
  finally
    FBriefMode.Items.EndUpdate;
  end;
  FBriefMode.ItemIndex := keepC;
  FAllowedLabel.Caption := Tr(sAiAllowed);
  FReplyLabel.Caption := Tr(sAiReply);
  FInsert.Caption := Tr(sAiInsert);
  FReplace.Caption := Tr(sAiReplace);
  FRepair.Caption := Tr(sAiCopyRepair);
  FInsert.Width := TextW(FInsert.Caption) + Px(Self, 28);
  FReplace.Width := TextW(FReplace.Caption) + Px(Self, 28);
  FRepair.Width := TextW(FRepair.Caption) + Px(Self, 28);

  (* the profile rows. The auth list is rebuilt like the pickers below it; the MODE is
     FProfile.Auth and the combo is a view of it, so a language switch cannot reset it. *)
  if FProfA <> nil then
  begin
    FConnLabel.Caption := Tr(sAiConn);
    FFormatLabel.Caption := Tr(sAiFormat);
    FEndpointLabel.Caption := Tr(sAiEndpoint);
    FModelLabel.Caption := Tr(sAiModel);
    FAuthLabel.Caption := Tr(sAiAuthMode);
    FKeyLabel.Caption := Tr(sAiKey);
    FKeySave.Caption := Tr(sAiKeySave);
    FKeyForget.Caption := Tr(sAiKeyForget);
    FNetwork.Caption := Tr(sAiNetwork);
    FProfLoading := True;
    try
      FAuth.Items.BeginUpdate;
      try
        FAuth.Items.Clear;
        FAuth.Items.Add(Tr(sAiAuthNone));
        FAuth.Items.Add(Tr(sAiAuthKey));
      finally
        FAuth.Items.EndUpdate;
      end;
      case FProfile.Auth of
        laNone: FAuth.ItemIndex := 0;
        laApiKey: FAuth.ItemIndex := 1;
      else
        FAuth.ItemIndex := -1;
      end;
      ShowKeyState;
    finally
      FProfLoading := False;
    end;
  end;

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
