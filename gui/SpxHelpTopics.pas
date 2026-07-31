(*
 * SpxHelpTopics -- the contents, in the slot the group editor otherwise has.
 *
 * The help itself is not here. It is in the LEFT PANE, as a document, so that putting the caret
 * in an example renders it on the right through the partial preview that already exists. This
 * panel only says where to go.
 *
 * Two levels: the twelve sections, and under each the articles it holds. A tree rather than a
 * list because a diagnostic code is looked up by name and there are twenty-four of them --
 * flattened they would be a wall, and grouped they are a contents page.
 *)
unit SpxHelpTopics;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, ComCtrls, Buttons, Graphics,
  SpxStudio, SpxUi, SpxIcons, SpxTheme, SpxStrIds, SpxStrings, SpxHelpText, SpxHelpNav;

type
  { Where the reader asked to go: a page, and the article in it -- empty for the page's top. }
  TSpxTopicPicked = procedure(APage: Integer; const AAnchor: string) of object;

  TSpxHelpTopics = class(TPanel)
  private
    FTop: TPanel;
    FClose: TSpeedButton;
    FLangBox: TComboBox;
    FNote: TLabel;
    FTree: TTreeView;
    FLang: Integer;
    FFilling: Boolean;
    FOnPicked: TSpxTopicPicked;
    FOnLangChanged: TNotifyEvent;
    FOnClose: TNotifyEvent;
    procedure CloseClicked(Sender: TObject);
    procedure TreeClicked(Sender: TObject);
    procedure LangPicked(Sender: TObject);
    procedure Fill;
  public
    constructor Create(AOwner: TComponent); override;
    { TTreeNode.Data is a raw pointer, so nothing frees what hangs off it. Fill clears the
      previous set on every refill; this clears the last one, which otherwise leaks at
      shutdown. }
    destructor Destroy; override;
    procedure Retranslate;
    procedure ApplyTheme(const APalette: TSpxPalette);
    { Light the node for this page and article, without firing OnPicked -- the window calls it
      when something else did the navigating (F1, a diagnostics row). }
    procedure ShowAt(APage: Integer; const AAnchor: string);
    property HelpLang: Integer read FLang;
    property OnPicked: TSpxTopicPicked read FOnPicked write FOnPicked;
    property OnLangChanged: TNotifyEvent read FOnLangChanged write FOnLangChanged;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

implementation

type
  { What a node stands for. A section's node carries line 0 -- the top of its page. }
  TTopicRef = class
    Page: Integer;
    Anchor: string;   { empty for a section's own node: the top of its page }
  end;

constructor TSpxHelpTopics.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Color := clWindow;
  FLang := SpxHelpLangFor(SpxUiLang);

  FTop := TPanel.Create(Self);
  FTop.Parent := Self;
  FTop.Align := alTop;
  FTop.BevelOuter := bvNone;
  FTop.Height := Px(Self, 30);

  FClose := TSpeedButton.Create(Self);
  FClose.Parent := FTop;
  FClose.Anchors := [akTop, akRight];
  FClose.SetBounds(FTop.Width - Px(Self, 28), Px(Self, 2), Px(Self, 26), Px(Self, 26));
  FClose.Flat := True;
  FClose.OnClick := @CloseClicked;

  { By ENDONYM, from the one table with no language of its own -- so a Russian speaker running
    an English interface can reach the Russian document, which the fallback rule alone denies
    them. }
  FLangBox := TComboBox.Create(Self);
  FLangBox.Parent := FTop;
  FLangBox.Align := alClient;
  FLangBox.BorderSpacing.Right := Px(Self, 32);
  FLangBox.BorderSpacing.Around := Px(Self, 2);
  FLangBox.Style := csDropDownList;
  FLangBox.OnChange := @LangPicked;

  { Shown only when the reader's own language has no document. Nothing needs saying when the
    two agree, and a standing notice about a language you do not use is noise. }
  FNote := TLabel.Create(Self);
  FNote.Parent := Self;
  FNote.Align := alBottom;
  FNote.WordWrap := True;
  FNote.BorderSpacing.Around := Px(Self, 4);
  FNote.Visible := False;

  FTree := TTreeView.Create(Self);
  FTree.Parent := Self;
  FTree.Align := alClient;
  FTree.ReadOnly := True;
  FTree.ShowRoot := False;
  FTree.HideSelection := False;
  FTree.RowSelect := True;
  FTree.OnClick := @TreeClicked;

  Fill;
  Retranslate;
end;

destructor TSpxHelpTopics.Destroy;
var i: Integer;
begin
  if FTree <> nil then
    for i := 0 to FTree.Items.Count - 1 do
      if FTree.Items[i].Data <> nil then
      begin
        TObject(FTree.Items[i].Data).Free;
        FTree.Items[i].Data := nil;
      end;
  inherited Destroy;
end;

procedure TSpxHelpTopics.CloseClicked(Sender: TObject);
begin
  if Assigned(FOnClose) then FOnClose(Self);
end;

procedure TSpxHelpTopics.Fill;
var page, i, doc: Integer; sect, node, docNode: TTreeNode; ref: TTopicRef;
begin
  FFilling := True;
  FTree.Items.BeginUpdate;
  try
    { The refs are owned by the nodes -- TTreeNode.Data is a raw pointer, so they are freed by
      hand here rather than by anything watching. }
    for i := 0 to FTree.Items.Count - 1 do
      if FTree.Items[i].Data <> nil then TTopicRef(FTree.Items[i].Data).Free;
    FTree.Items.Clear;
    { THREE LEVELS, AND THE MARKDOWN ALREADY HAS THEM. A language has more than one document
      now, and a flat list of every section put two chapters called "How to read the examples"
      one under the other with nothing to say which was which. The `#` heading that opens a
      document is its title and its first page; the `##` sections are its chapters, and the
      `###` articles hang under those. So the document node IS a page -- clicking it opens the
      document's own front page rather than doing nothing, which a bare grouping label would. }
    doc := -1;
    docNode := nil;
    for page := 0 to SpxHelpPageCount(FLang) - 1 do
    begin
      ref := TTopicRef.Create;
      ref.Page := page;
      if SpxHelpPageDoc(FLang, page) <> doc then
      begin
        doc := SpxHelpPageDoc(FLang, page);
        docNode := FTree.Items.AddChild(nil, SpxHelpPageTitle(FLang, page));
        docNode.Data := ref;
        sect := docNode;
      end
      else
      begin
        sect := FTree.Items.AddChild(docNode, SpxHelpPageTitle(FLang, page));
        sect.Data := ref;
      end;
      for i := 0 to SpxHelpAnchorCount(FLang) - 1 do
        if SpxHelpAnchorPage(FLang, i) = page then
        begin
          node := FTree.Items.AddChild(sect, SpxHelpAnchorTitle(FLang, i));
          ref := TTopicRef.Create;
          ref.Page := page;
          ref.Anchor := SpxHelpAnchorId(FLang, i);
          node.Data := ref;
        end;
    end;
    { Opened, because a reader who pressed F1 wants the chapters, not two closed folders. }
    FTree.FullExpand;
  finally
    FTree.Items.EndUpdate;
    FFilling := False;
  end;
end;

procedure TSpxHelpTopics.TreeClicked(Sender: TObject);
var ref: TTopicRef;
begin
  if FFilling or (FTree.Selected = nil) or (FTree.Selected.Data = nil) then Exit;
  ref := TTopicRef(FTree.Selected.Data);
  if Assigned(FOnPicked) then FOnPicked(ref.Page, ref.Anchor);
end;

procedure TSpxHelpTopics.LangPicked(Sender: TObject);
begin
  if FFilling then Exit;
  if (FLangBox.ItemIndex < 0) or (FLangBox.ItemIndex = FLang) then Exit;
  FLang := FLangBox.ItemIndex;
  Fill;
  if Assigned(FOnLangChanged) then FOnLangChanged(Self);
end;

procedure TSpxHelpTopics.ShowAt(APage: Integer; const AAnchor: string);
var i: Integer; ref: TTopicRef;
begin
  FFilling := True;
  try
    for i := 0 to FTree.Items.Count - 1 do
    begin
      if FTree.Items[i].Data = nil then Continue;
      ref := TTopicRef(FTree.Items[i].Data);
      if (ref.Page = APage) and (ref.Anchor = AAnchor) then
      begin
        FTree.Items[i].Selected := True;
        if FTree.Items[i].Parent <> nil then FTree.Items[i].Parent.Expand(False);
        FTree.Items[i].MakeVisible;
        Exit;
      end;
    end;
  finally
    FFilling := False;
  end;
end;

procedure TSpxHelpTopics.Retranslate;
var i, want: Integer;
begin
  if FLangBox = nil then Exit;
  FClose.Hint := Tr(sClose);
  FClose.ShowHint := True;

  want := SpxHelpLangFor(SpxUiLang);
  FFilling := True;
  try
    FLangBox.Items.BeginUpdate;
    try
      FLangBox.Items.Clear;
      for i := 0 to SPX_HELP_LANG_COUNT - 1 do
        FLangBox.Items.Add(SpxLangName(SpxLangFor(SpxHelpLangCode(i))));
    finally
      FLangBox.Items.EndUpdate;
    end;
    if want <> FLang then
    begin
      FLang := want;
      Fill;
    end;
    FLangBox.ItemIndex := FLang;
  finally
    FFilling := False;
  end;

  FNote.Visible := not SpxHelpIsTranslated(SpxUiLang);
  if FNote.Visible then
    FNote.Caption := Format(Tr(sHelpNotTranslated), [SpxLangName(SpxUiLang)]);
end;

procedure TSpxHelpTopics.ApplyTheme(const APalette: TSpxPalette);
begin
  Color := APalette.Back;
  if FTop <> nil then FTop.Color := APalette.Back;
  if FTree <> nil then
  begin
    { THE THEMED DRAW HAS TO GO, or the ink is Windows' and not ours. LCL assigns
      Canvas.Font.Color := Font.Color (treeview.inc:5558) and then, with tvoThemedDraw in
      Options -- the default -- hands the node's text to ThemeServices.DrawText (:5519-5523)
      as a ttItemNormal element when it is unselected and a ttItemSelected one when it is
      (:5482-5506). Either way the theme paints it in the SYSTEM's colour for a tree item and
      never consults the canvas. So the panel went dark and the text stayed black.

      Measured on the shipped exe: Color was $001E1E1E and Font.Color $00D4D4D4 -- both
      correct -- while the pixels were black on #1E1E1E, a contrast of 1.26:1. The reader
      reported it as everything blending together, and it was: the contents of the help were
      invisible in the dark theme while the page beside them was fine. Confirmed from the
      other side by drawing both branches into a memory DC: DrawThemeText lays down #000000
      where the canvas says #D4D4D4, and plain DrawTextW lays down #D4D4D4. }
    FTree.Options := FTree.Options - [tvoThemedDraw];
    FTree.Color := APalette.Back;
    FTree.Font.Color := APalette.Text;
    { The selection comes with the text: off the themed path the tree fills the row itself,
      and takes the ink from SelectionFontColor -- but ONLY when SelectionFontColorUsed says
      so. SetSelectedFontColor does not set that flag (treeview.inc:3770-3776); it is a
      published property of its own, and without it the assignment above is dead and the ink
      is InvertNdColor(SelectionColor) instead. Found by review, measured: the inversion gives
      white on both palettes today, so nothing looked wrong -- and it would flip to black in
      silence if the dark Sel were ever lightened past a channel sum of 384 (:5109).

      The dark palette's SelText is clNone, which SynEdit reads as "leave the token its own
      colour" and this control cannot read at all, so it is translated into what it means
      here: the node's own ink. Both branches assign, on both themes.

      The light theme's selected row DOES change, and it was measured before it was accepted:
      the legacy `treeview` theme class fills TVP_TREEITEM white in every state, so a selected
      row used to be a white band with a grey border under black text -- a 1:1 band. It is
      clHighlight with white text now, 4.5:1, which is what every other list in this window
      does. Unselected rows in light are pixel-identical. }
    FTree.SelectionColor := APalette.Sel;
    if APalette.SelText <> clNone then FTree.SelectionFontColor := APalette.SelText
    else FTree.SelectionFontColor := APalette.Text;
    FTree.SelectionFontColorUsed := True;
  end;
  if FNote <> nil then FNote.Font.Color := APalette.Text;
end;

end.
