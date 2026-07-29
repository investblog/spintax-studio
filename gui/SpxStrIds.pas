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
    sStatusElapsed, sShowLarge, sTooLargeToDraw
  );

implementation

end.
