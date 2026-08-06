(*
 * SpxStrIds -- the names of the things the window says.
 *
 * Only the ids. They live apart from the strings because there is one list of them and
 * FOURTEEN lists of text, one per language, and every one of those has to name this type --
 * which it cannot do if the type lives in the unit that collects them all.
 *
 * A language is a FILE (gui/lang/SpxTextsXx.pas), and each holds a `array[TSpxStr] of string`
 * so a missing entry is a compile error rather than a blank label on someone's screen. That
 * is what the first version of this promised with two languages in one array; the array did
 * not survive the fifth language, and the promise did.
 *)
unit SpxStrIds;

{$mode objfpc}{$H+}

interface

type
  TSpxStr = (
    { ── menus ── }
    sMenuFile, sMenuNew, sMenuOpen, sMenuSave, sMenuSaveAs, sMenuReloadSet, sMenuExit,
    sMenuEdit, sMenuFind, sMenuFindNext, sMenuFindPrev,
    sMenuView, sRailLeft, sRailRight,
    { The interface's own language -- tied to the template's only if the user says so.
      sLangEnglish and sLangRussian are DEAD: the menu lists every language by its own name
      (SpxLangName), which is not translated, so these two are neither used nor deleted --
      removing an entry from a positional array means editing fourteen files in step, and the
      cost of getting that wrong is higher than two unread strings. They go when the table
      next has a reason to be rewritten. }
    sMenuLanguage, sLangEnglish, sLangRussian, sLangFollow,
    { the group editor that slides out of the rail }
    sRailFaceGroup, sTabGroup, sGroupNone, sGroupApply, sGroupRefused, sGroupMultiline,
    sGroupChoice, sGroupConditional, sGroupPlural, sGroupPermutation,
    { the letters that were on the rail's buttons before the icons: unread since, kept
      because a positional array does not lose an entry cheaply, budget 0 in SpxStrings }
    sRailFaceDiag, sRailFaceVars, sRailFaceSet,
    sMenuWrapBraces, sMenuWrapBrackets, sMenuReroll, sMenuCopyResult, sMenuSelectAll,

    { ── the top strip: the output's half ── }
    sSeed, sReroll, sCopy, sViewPage, sViewSource,
    sFragmentShown, sFragmentEmpty,

    { ── the top strip: the template's half ── }
    sFindCase, sFindNothing, sFindMatches, sFindPosition, sFindClose,

    { ── the bottom tabs ── }
    sTabDiagnostics, sTabVariables, sTabVariants,
    sColLevel, sColFile, sColAt, sColMessage,
    { what a diagnostic row says in its first two columns; the message itself comes from
      editor-core, which knows the codes }
    sLevelError, sLevelWarning, sLevelNote, sDocument,

    { ── the variables panel ── }
    sVarsDefinitions, sVarsSession, sColKind, sColName, sColValue, sColLiteral,

    { ── the variants panel ── }
    sHowMany, sSeedShort, sRandomSeed, sGenerate, sStop,
    sDropSimilar, sExactOnly, sKeepAll, sShingle, sThreshold,
    sToXlsx, sToTxt, sToFiles, sSeedInTxt,
    sNothingGenerated, sWorking, sStopping,
    sReportDone, sReportExhausted, sReportStopped, sProgress, sStaleSet,
    sWroteRows, sWroteRowsCollapsed, sWroteFiles, sWroteFilesPartial, sWriteFailed,
    sColNo, sColSeed, sColLength, sColText,

    { ── dialogs ── }
    sOpenTemplate, sSaveTemplate, sFileFilter, sExcelFilter, sTextFilter,
    sExportXlsx, sExportTxt, sChooseFolder, sSheetName, sColSheetSeed, sColSheetText,
    sUnsavedTitle, sUnsavedQuestion, sUntitled, sWindowTitle,

    { ── the status bar ── }
    sStatusReady, sStatusValid, sStatusWithWarnings, sStatusErrors, sStatusNotes,
    sStatusElapsed, sShowLarge, sTooLargeToDraw,

    { ── a panel's own close button ── }
    sClose,

    { ── the editor's size and colours ── }
    sZoomIn, sZoomOut, sZoomReset, sThemeLight, sThemeDark,

    { ── the divider between the panes ── }
    sSplitEven, sSplitEvenHint,

    { ── the editor's own font ── }
    sEditorFont, sFontAuto,

    { ── a definition's value, edited in its row: what the status bar says when the edit is
      refused. The engine reads every edit back, so a refusal means the document would have
      said something other than what was typed -- a `/#` opening a comment, a line break
      ending the directive, or a comment already inside it. Silence here would be the
      "you can type but nothing sticks" defect all over again. ── }
    sDefValueRefused,

    { ── the include group: what this document pulls in, and whether the set has it (spec §4.4).
      THREE states, not two, and the third is the one that matters: `Known` is False both for a
      fragment the set does not have and for a document with no set to look in -- a new file has
      none -- so a two-state mark would tell that user "MISSING" about a question nobody asked
      yet. ── }
    sVarsIncludes, sColTarget, sColInSet, sIncludeYes, sIncludeMissing, sIncludeNoSet,

    { ── the help. Four, and the window's own caption reuses the first: "Help — Spintax Studio"
      reads right, no menu caption here carries an `&` accelerator, and every id costs
      seventeen files. The section titles the viewer lists are the help document's own, and
      the help languages are named by SpxLangName's endonyms -- neither is a string. ── }
    sMenuHelp, sHelpContents, sHelpLanguage, sHelpNotTranslated,

    { ── the help's offer to keep an example: what the right pane is showing, and the
      button that puts it in the reader's own document ── }
    sHelpExampleFrom, sHelpExampleInsert,

    { ── the About box: its menu item and its own caption ── }
    sMenuAbout,

    { ── WHAT AN EMPTY GROUP SAYS. A panel with nothing in it reads as a panel that is not
      working, and usually it is simply right: a document that defines no macros has none to
      list. So each of these says how to GET the thing rather than that the thing is missing,
      and the line is a link to the chapter that explains it (SpxHelpNav's hint slugs).

      `%name%` STAYS LATIN in all fourteen. The engine's variable names are ASCII word
      characters, so a hint showing a Cyrillic name would teach something the engine does not
      do -- the same fact the help documents record from the other side. ── }
    sVarsHintDefs, sVarsHintIncludes,

    { ── THE ABOUT BOX'S OWN WORDS. Everything else that box shows is generated from
      NOTICE.md and is English by necessity -- a licence text is not translated. These two are
      not that: the first says what this program IS, which was the whole complaint about the
      box ("it tells you nothing about the product"), and the second is the heading over the
      attributions. Prose for the reader follows the reader's language; the notice under it
      does not, and the difference is deliberate. `Crafted at` in the status bar is the third
      case again -- a signature, not a sentence. ── }
    sAboutWhat, sAboutCredits
  );

implementation

end.
