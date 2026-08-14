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
    sAboutWhat, sAboutCredits,

    { ── THE GSA IMPORT (spec §4.7), which is off until the reader turns it on. Five strings:
      the switch in the View menu, the File item it reveals, the file dialog's filter, and the
      two things the summary has to say — what was lifted out of the template, and that those
      values live for this session only. The refusal list needs no string of its own: it is
      the engine's `name=text`, shown as it came. ── }
    sMenuGsaImport, sMenuGsaOpen, sGsaFilter, sGsaLifted, sGsaSessionOnly,
    sGsaRefusedCount, sGsaRefusedMore,

    { ── HOW MANY VARIANTS THE TEMPLATE CAN MAKE, which is the question an author asks before
      they ask for fifty of them. Two sentences rather than one with a word slotted in: the
      qualifier lands in a different place in a different language, and "at least" is not a
      word every one of these fourteen spells with one. The number itself is not translated —
      it is grouped in code, the way GTW writes it. ── }
    sPossible, sPossibleAtLeast,

    (* ── THE AI PANEL (ADR 0011), and every word of it is about a loop that has no network in
       it. The panel builds a prompt, the reader carries it to whatever model they use, and
       brings the answer back; the verdict on that answer comes from the engine that is already
       in this process. So there is no "connect", no "key", no "sending" and no "waiting" here,
       and there is not meant to be.

       THE CASE NAMES ARE NOT DECORATION. A variable is substituted verbatim -- the engine
       never inflects it -- so in an inflected language the sentence has to be built around the
       form the value already has, and the model can only choose correctly if it is TOLD which
       form each name holds. Upstream measured a real template set where `%CasinoGamesAcc%`
       carried instrumental forms: the naming convention lied and the declaration could not.
       That is why the case is a column the author fills in and never a guess from the name.

       Seven cases, and the first is "not declared" rather than a case: English needs none of
       them, and a blank in that column has to mean "no claim" instead of "nominative". ── *)
    sTabAi, sAiBrief, sAiAllowed, sAiReply, sAiChannel, sAiLevel, sAiLocale,
    sAiCopyPrompt, sAiCopyRepair, sAiInsert,
    sAiColCase, sAiColNote,
    sAiCopied, sAiRepairCopied, sAiInserted,
    sAiNeedBrief, sAiNeedReply, sAiNoErrors,
    sAiChEmail, sAiChSms, sAiChPush, sAiChLanding, sAiChGeneric,
    sAiLvConservative, sAiLvBalanced, sAiLvAggressive,
    sAiCaseNone, sAiCaseNom, sAiCaseGen, sAiCaseDat, sAiCaseAcc, sAiCaseIns, sAiCasePre,
    (* ── REPLACE, BECAUSE A REPAIR IS NOT AN INSERT ──────────────────────────────────────
       The repair prompt ends "Return the corrected template" -- the model answers with the
       WHOLE document -- and the only action the panel had put it at the caret. So repairing a
       template left the broken one where it was and added a corrected copy beside it. Found by
       review.

       Two buttons rather than one that changes meaning: the panel cannot tell a repair answer
       from a draft answer, and a button whose behaviour depends on which prompt was copied
       last is a hidden mode -- the kind that gets reported as "it ate my document". Appended
       to the end of this enum on purpose: the language tables are `array[TSpxStr] of string`,
       so appending is the one edit the compiler checks for all fourteen at once. ── *)
    sAiReplace, sAiReplaced,

    (* ── R1-4: THE LOOP REACHES THE WINDOW. `[Generate]` reuses sGenerate/sStop; everything
       below is new, appended so the compiler checks all fourteen tables at once.

       THE ERROR SENTENCES name every TSpxLlmError a reader can meet, one id per member --
       the ErrName lesson from the other side: a shared "something went wrong" would send a
       reader with an expired key to check their network. The three the plan demanded by name
       are here (redirected, insecure, no-key), and a silent button would be worse than a
       missing one.

       THE PROFILE WORDS follow spec §4.5's vocabulary: the recipient is "this endpoint" --
       an address the reader configured -- and no string below claims anything about what the
       software at that address does or where it runs. ── *)
    sAiFix, sAiSettings, sAiStopped,
    sAiAsking, sAiVerifying, sAiFixRound,
    sAiDegenerate, sAiClosure, sAiStillInvalid, sAiStale,
    sAiErrNoKey, sAiErrRedirected, sAiErrInsecure, sAiErrAuth, sAiErrRate,
    sAiErrContext, sAiErrTransport, sAiErrBad, sAiErrEmpty, sAiErrProvider,
    sAiConn, sAiFormat, sAiEndpoint, sAiModel, sAiAuthMode, sAiAuthNone, sAiAuthKey,
    sAiKey, sAiKeySave, sAiKeyForget, sAiKeyStored, sAiKeyMissing, sAiKeyDetached,
    sAiNetwork, sAiConsentTitle, sAiConsentBody,

    (* ── R1-5: THE REPORT CHANNEL (Store policy 11.16) -- the "means for users to report
       inappropriate content" the policy demands, reachable whether or not the network is
       on: pasted AI output is AI output too. Born as a Help-menu mailto item; since
       2026-08-14 (owner's call) this string is the LABEL of a plain-text line in the About
       box, beside the licence -- the About strips its menu-era trailing ellipsis, because
       the line opens nothing. ── *)
    sMenuReportAi,

    (* ── THE UX PASS (owner, 2026-08-13): the brief column's two modes. The mode combo IS
       the column's header, so its selected item NAMES what the box holds: the reader's own
       text to convert (the main path -- no brief to invent), or a free-form brief (sAiBrief,
       reused as the item). sAiNeedText is the empty-box message of the first mode. ── *)
    sAiModeFromText, sAiNeedText,

    (* ── FIND AND REPLACE (UX-plan item 8, designed 2026-08-14). The bar's second row:
       the menu verb, the field's cue, the two buttons, and the status sentence that
       reports REPLACEMENTS -- which can honestly be fewer than the counter's matches,
       because overlaps are stepped through, never replaced twice. ── *)
    sMenuReplace, sReplaceWith, sReplaceOne, sReplaceAll, sReplacedCount,

    (* ── THE INSERT MENU (owner, 2026-08-14): the wraps move out of Edit, a comment wrap
       joins them, and the constructs the owner asked for -- #set, #def, #include and the
       condition -- become one menu. The four construct captions ARE the inserted text,
       byte for byte, so the menu cannot promise one thing and land another; their shapes
       and the Latin NAME placeholders are pinned per language in TestInsertMenu. The two
       refusals are status-line sentences: the engine is silent about both harms (a #/
       escaping a comment, a bare | adding a branch), so the guard has to speak. ── *)
    sMenuInsert, sMenuWrapComment, sMenuInsSet, sMenuInsDef, sMenuInsInclude, sMenuInsCond,
    sWrapCommentRefused, sCondWrapRefused,
    (* A caret parked between the two characters of `/#` or `#/`: anything inserted there
       cuts the mark in half and can resurrect commented text (measured; review round two
       and three). Every caret-insert path refuses with this sentence. *)
    sInsSplitRefused,

    (* Attach key with an endpoint the parser cannot read said "no key attached" -- but the
       key was right there in the field; the ADDRESS was the problem, and the reader's next
       move (retype the key) failed identically (review, 2026-08-15). The truthful sentence:
       name the endpoint as the thing to fix. *)
    sAiKeyBadEndpoint
  );

implementation

end.
