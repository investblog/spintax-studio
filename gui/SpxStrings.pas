(*
 * SpxStrings -- every word the window says, in one place.
 *
 * ENGLISH IS THE BASE, and that is a decision rather than a habit: it is the language the
 * spec's terms are already in (`seed`, `spintax`, `shingle`), it is the shorter of the two
 * almost everywhere, and a layout that fits the English will not fit the Russian by accident
 * -- the other way round it would, and the first translation would then break the strip.
 *
 * LENGTH IS PART OF THE CONTRACT. A caption that sits in a computed position has a BUDGET in
 * code points, and the suite checks every language against it. Without that, a translation
 * silently overflows its control and the person who added it has no way to know; with it,
 * the build says so. Budget 0 means the string has room to be as long as it needs -- a
 * status line, a message box, a dialog title.
 *
 * The table is an ARRAY, not a file to load: it ships inside the executable, it cannot go
 * missing on a user's machine, and a missing entry is a compile error rather than a blank
 * label. Two languages fit in it comfortably; if a fifth arrives, this becomes a file and
 * this comment becomes wrong.
 *)
unit SpxStrings;

{$mode objfpc}{$H+}

interface

uses
  SpxStudio;

type
  { One language for the whole product. The enum itself lives in editor-core because the
    diagnostics panel's sentences are built there, on the worker thread; this is the same
    type, not a parallel one that has to be kept in step by hand. }
  TSpxLang = SpxStudio.TSpxLang;

  TSpxStr = (
    { ── menus ── }
    sMenuFile, sMenuNew, sMenuOpen, sMenuSave, sMenuSaveAs, sMenuReloadSet, sMenuExit,
    sMenuEdit, sMenuFind, sMenuFindNext, sMenuFindPrev,
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
    sVarsDefinitions, sVarsSession, sColKind, sColName, sColValue,

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

{ The text for this id in the current language. Named Tr rather than S because Pascal
  does not distinguish case in identifiers, and half the procedures in the window keep a
  local `s` -- which silently shadowed the function and turned every call into a syntax
  error at best. }
function Tr(Id: TSpxStr): string;

{ Which language the window speaks. It follows the document's locale, which is what the user
  asked for: switching a template to Russian switches the interface with it. The obvious
  cost is that editing a German template in a Russian office gives an English interface --
  a separate setting can override this later, and the plumbing is ready for it. }
procedure SpxSetUiLang(ALang: TSpxLang);
function SpxUiLang: TSpxLang;
function SpxUiLangFor(const Locale: string): TSpxLang;

{ How many code points this id is allowed, or 0 for "as long as it needs". Exposed so the
  suite can check every language against it. }
function SpxStrBudget(Id: TSpxStr): Integer;

{ The raw text of an id in a NAMED language, for the suite. }
function SpxStrIn(ALang: TSpxLang; Id: TSpxStr): string;

implementation

uses
  SysUtils, Spintax;

var
  GLang: TSpxLang = spxLangEn;

const
  TEXTS: array[TSpxLang, TSpxStr] of string = (
    { ── English, the base ── }
    (
      'File', 'New', 'Open…', 'Save', 'Save as…', 'Reload set', 'Exit',
      'Edit', 'Find…', 'Find next', 'Find previous',
      'Wrap in {…}', 'Wrap in […]', 'Show another variant', 'Copy the result',
      'Select all',

      'seed', 'Reroll', 'Copy', 'Page', 'Source',
      'showing a fragment', 'the fragment renders nothing',

      'Case', 'not found', 'matches: %d', '%d/%d', 'x',

      'Diagnostics', 'Variables', 'Variants',
      'Level', 'File', 'At', 'Message',
      'error', 'warning', 'Studio note', 'document',

      ' Definitions — they live in the document',
      ' Session values — rendered as spintax, never written to the document',
      'Kind', 'Name', 'Value',

      'Count', 'seed', 'random', 'Generate', 'Stop',
      'Drop similar', 'Exact duplicates only', 'Keep everything', 'shingle', 'limit',
      'To .xlsx', 'To .txt', 'One file each', 'seed in .txt',
      'nothing generated yet', 'working…', 'stopping…',
      '%d variants, %d dropped, %d renders, next seed %d',
      'got %d of %d — the template gives no more at this threshold (%d dropped, %d renders)',
      'stopped: %d variants, %d dropped, %d renders',
      '%d of %d, %d dropped, %d renders',
      'the document has changed — this set is from the earlier text; ',
      'wrote %d rows to %s',
      'wrote %d rows; line breaks in %d variants became spaces — for the text as it is, ' +
        'use .xlsx or one file each',
      'wrote %d files to %s', 'wrote %d files, then could not continue',
      'could not write the file',
      '#', 'seed', 'length', 'text',

      'Open a template', 'Save the template', 'Spintax templates|*%s|All files|*.*',
      'Excel workbook|*.xlsx', 'Text|*.txt',
      'Export to .xlsx', 'Export to .txt', 'Where to put the files', 'Variants',
      'seed', 'variant',
      'Spintax Studio', 'The document has unsaved changes. Save them?', 'Untitled',
      '%s — Spintax Studio',

      'ready', 'valid', 'valid, %d warnings', '%d errors', ' · %d notes', '%s · %d ms',
      'Show', 'Output is %d KB — the page does not redraw itself'
    ),

    { ── Russian ── }
    (
      'Файл', 'Создать', 'Открыть…', 'Сохранить', 'Сохранить как…', 'Перечитать набор',
      'Выход',
      'Правка', 'Найти…', 'Найти далее', 'Найти назад',
      'Обернуть в {…}', 'Обернуть в […]', 'Показать другой вариант', 'Копировать результат',
      'Выделить всё',

      'сид', 'Другой', 'Копировать', 'Страница', 'Исходник',
      'показан фрагмент', 'фрагмент ничего не выводит',

      'Регистр', 'не найдено', 'найдено: %d', '%d/%d', 'x',

      'Диагностика', 'Переменные', 'Варианты',
      'Уровень', 'Файл', 'Место', 'Сообщение',
      'ошибка', 'предупреждение', 'заметка Studio', 'документ',

      ' Определения — живут в документе',
      ' Значения на сессию — рендерятся как spintax, в документ не пишутся',
      'Вид', 'Имя', 'Значение',

      'Сколько', 'сид', 'случайный', 'Сгенерировать', 'Стоп',
      'Убирать похожие', 'Только точные совпадения', 'Ничего не убирать', 'шингл', 'порог',
      'В .xlsx', 'В .txt', 'По файлу на текст', 'сид в .txt',
      'ничего не сгенерировано', 'идёт…', 'останавливаю…',
      '%d вариантов, отброшено %d, рендеров %d, следующий сид %d',
      'получилось %d из %d — шаблон не даёт больше при этом пороге ' +
        '(отброшено %d, рендеров %d)',
      'остановлено: %d вариантов, отброшено %d, рендеров %d',
      '%d из %d, отброшено %d, рендеров %d',
      'документ изменился — набор от прежнего текста; ',
      'записано %d строк в %s',
      'записано %d строк; у %d вариантов переводы строк заменены пробелами — ' +
        'для дословности берите .xlsx или «по файлу»',
      'записано %d файлов в %s', 'записано %d файлов, дальше не удалось',
      'не удалось записать файл',
      '#', 'сид', 'длина', 'текст',

      'Открыть шаблон', 'Сохранить шаблон', 'Шаблоны spintax|*%s|Все файлы|*.*',
      'Книга Excel|*.xlsx', 'Текст|*.txt',
      'Экспорт в .xlsx', 'Экспорт в .txt', 'Куда положить файлы', 'Варианты',
      'сид', 'вариант',
      'Spintax Studio', 'В документе есть несохранённые изменения. Сохранить?',
      'Без имени', '%s — Spintax Studio',

      'готов', 'валидно', 'валидно, %d предупреждений', '%d ошибок', ' · %d заметок',
      '%s · %d мс',
      'Показать', 'Вывод %d КБ — страница не обновляется сама'
    )
  );

  { What fits where. These are the strings placed by LayoutTopStrip and by the panels' own
    fixed coordinates; everything else is 0 and free to grow.

    A budget is the CONTROL's usable width divided by 7 px per code point, not the control's
    width: a check box spends about 18 px on its indicator and a button about 8 px on
    padding, so a 90 px check box holds ten characters and not thirteen. The earlier numbers
    were the outer widths, which is why several of them blessed a caption that overlapped its
    neighbour on screen.

    A string with a `%d` is measured with the digits SUBSTITUTED (six of them -- past that a
    variant count is not a caption problem), because 'matches: %d' fitting proves nothing
    about 'matches: 128 000'. A budgeted string must not carry `%s`: its width would then
    depend on a file name, and no fixed slot can promise that. The suite checks both rules. }
  BUDGETS: array[TSpxStr] of Integer = (
    { menus -- a menu grows to fit its longest item }
    0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0, 0,

    { top strip, output half: the seed box 55px and the two views 90px are check/radio
      buttons, Reroll and Copy are 80px buttons }
    5, 10, 10, 10, 10,
    { the fragment captions size themselves and sit between the chain and the switch }
    28, 32,

    { top strip, template half: the case box is 90px, the counter a 110px label -- and the
      counter's three captions are what a six-digit match count has to fit into }
    10, 15, 15, 15, 2,

    { tabs, the diagnostics columns (110/130/70px), and what a row says in the first two of
      them -- an item caption is indented about six pixels, a subitem is not }
    14, 14, 14,
    15, 18, 10, 0,
    14, 14, 14, 18,

    { the variables panel: two headings above full-width grids, then its columns }
    0, 0, 8, 10, 0,

    { the variants panel. The three labels that name a field are hung off that field by
      PlaceLabels, so their room is the gap before it rather than a coordinate. }
    8, 4, 10, 14, 10,
    26, 26, 26, 7, 7,
    14, 14, 20, 17,
    { BOTH lines of this panel -- the progress line above the grid and the report below it --
      stretch to the pane's edge and keep their full text in a hint, so their sentences are
      free to be sentences. At the window's minimum width they still clip; the hint is what
      makes that recoverable. }
    0, 0, 0,
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,
    4, 8, 10, 0,

    { dialogs -- a title bar, a filter and a column heading all have room }
    0, 0, 0, 0, 0,
    0, 0, 0, 28, 0, 0,
    0, 0, 20, 0,

    { the status bar, then the preview's own two: the button is 90px and the line beside it
      runs from x=8 to the button at x=420 }
    0, 0, 0, 0, 0, 0,
    11, 57
  );

function SpxStrIn(ALang: TSpxLang; Id: TSpxStr): string;
begin
  Result := TEXTS[ALang, Id];
end;

function Tr(Id: TSpxStr): string;
begin
  Result := TEXTS[GLang, Id];
end;

procedure SpxSetUiLang(ALang: TSpxLang);
begin
  GLang := ALang;
end;

function SpxUiLang: TSpxLang;
begin
  Result := GLang;
end;

function SpxUiLangFor(const Locale: string): TSpxLang;
begin
  { editor-core's rule, not a second copy of it: the panel's sentences and the window's
    captions must never disagree about what language a document is in. }
  Result := SpxLangFor(Locale);
end;

function SpxStrBudget(Id: TSpxStr): Integer;
begin
  Result := BUDGETS[Id];
end;

end.
