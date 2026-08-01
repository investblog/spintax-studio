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
 *
 * AND ALMOST NOTHING ELSE. The panel used to carry a strip above the tree with a language box
 * and a close button, and the reader asked for both to go: the help's language is the
 * INTERFACE's language, which the View menu already switches, and a second place to set it is a
 * second thing to keep in step. The close went with it because the header strip had one.
 *
 * AND NO CLOSE OF ITS OWN. One was added here while the header had none, and taken out again
 * when the header got the help's own toggle: the way in and the way out are one glyph in the
 * strip now, and a second X over the contents would be the duplicate the first removal was
 * about. What made the ORIGINAL one read as broken is worth keeping written down -- it had no
 * image assigned at all and drew as an empty box.
 *
 * What the removal costs is named honestly, in two parts. A Russian speaker running an English
 * interface can no longer read the Russian document without switching the whole interface. And
 * nothing in the window NAMES the language the help is in any more: the box did, by showing the
 * endonym of the current help language, and the note that stays says only `There is no help in
 * %s yet` about the reader's own -- it has never mentioned English, and it is not a substitute
 * for what the box said. What a German reader has instead is the page in front of them, which
 * is in English and says so by being it.
 *)
unit SpxHelpTopics;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, ComCtrls, Graphics, LCLType,
  SpxStudio, SpxUi, SpxTheme, SpxStrIds, SpxStrings, SpxHelpText, SpxHelpNav;

type
  { Where the reader asked to go: a page, and the article in it -- empty for the page's top. }
  TSpxTopicPicked = procedure(APage: Integer; const AAnchor: string) of object;

  TSpxHelpTopics = class(TPanel)
  private
    FNote: TLabel;
    FTree: TTreeView;
    FLang: Integer;
    FFilling: Boolean;
    FOnPicked: TSpxTopicPicked;
    procedure TreeClicked(Sender: TObject);
    procedure TreeKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PickSelected;
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
  FTree.OnKeyUp := @TreeKeyUp;

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

procedure TSpxHelpTopics.PickSelected;
var ref: TTopicRef;
begin
  if FFilling or (FTree.Selected = nil) or (FTree.Selected.Data = nil) then Exit;
  ref := TTopicRef(FTree.Selected.Data);
  if Assigned(FOnPicked) then FOnPicked(ref.Page, ref.Anchor);
end;

procedure TSpxHelpTopics.TreeClicked(Sender: TObject);
begin
  PickSelected;
end;

(* ENTER AND SPACE, AND DELIBERATELY NOT THE ARROWS -- which is the opposite of what the
   diagnostics list does, for a reason that is about cost rather than taste.

   The tree was mouse-only: TCustomTreeView.KeyDown moves the selection and never calls Click
   (treeview.inc:4373-4444), so arrowing lit a chapter and opened nothing. That is a real gap
   and this closes it.

   But opening a chapter FEEDS AN IPro PAGE, measured at 62-234 ms, and the pane's cache keys
   on the whole document string, so stepping through the contents would parse a new document
   on nearly every press. Worse, GoToHelp focuses the page, so the first arrow would hand the
   keyboard to the reader and the second would scroll it -- the very defect just fixed in the
   variables grids. So selection-follows is wrong here even though it is right there, and
   arrowing merely moves while Enter and Space open. That is also what every contents tree on
   this platform does.

   Both keys are free: the tree is ReadOnly, so the label editor that consumes VK_RETURN
   (treeview.inc:6551) never exists, and KeyDown's own case handles neither. *)
procedure TSpxHelpTopics.TreeKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  { A modified key means something else -- Ctrl+Space is not "open this". }
  if Shift * [ssShift, ssAlt, ssCtrl] <> [] then Exit;
  if (Key = VK_RETURN) or (Key = VK_SPACE) then PickSelected;
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
var want: Integer;
begin
  if FTree = nil then Exit;
  { THE DOCUMENT FOLLOWS THE INTERFACE. It always did -- this is the same want/refill the
    language box wrapped -- and now it is the only thing that decides, so there is no second
    control to leave disagreeing with the menu. }
  want := SpxHelpLangFor(SpxUiLang);
  if want <> FLang then
  begin
    FLang := want;
    Fill;
  end;

  FNote.Visible := not SpxHelpIsTranslated(SpxUiLang);
  if FNote.Visible then
    FNote.Caption := Format(Tr(sHelpNotTranslated), [SpxLangName(SpxUiLang)]);
end;

procedure TSpxHelpTopics.ApplyTheme(const APalette: TSpxPalette);
begin
  Color := APalette.Back;
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
