(*
 * SpxTextsEn -- the window in English, and the base every other language falls back to.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen. The compiler counts the entries;
 * what it cannot check is that each one is in its own place, which is why the sections carry
 * the same headings as the id list.
 *
 * LENGTH IS PART OF THE CONTRACT: a caption in a computed position has a budget in code
 * points (SpxStrings.BUDGETS), and the suite checks every language against it. A translation
 * that overflows fails the build rather than the layout.
 *)
unit SpxTextsEn;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_EN: array[TSpxStr] of string = (
      'File', 'New', 'Open…', 'Save', 'Save as…', 'Reload set', 'Exit',
      'Edit', 'Find…', 'Find next', 'Find previous',
      'View', 'Tools on the left', 'Tools on the right',
      'Interface language', 'English', 'Русский', 'Follow the template',
      'G', 'Group under the caret',
      'The caret is not inside a group.', 'Apply',
      'Refused: the result would say something other than this list — a variant cannot ' +
        'carry | } { or /#.',
      'A variant here contains a line break, so this group is shown but not edited.',
      'Choice', 'Conditional', 'Plural', 'Permutation',
      'D', 'V', 'S',
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
      'Kind', 'Name', 'Value', 'as text',

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
      'Show', 'Output is %d KB — the page does not redraw itself',

      'Close',

      'Zoom in', 'Zoom out', 'Reset zoom', 'Light', 'Dark',

      'Even panes', 'Double-click: even panes'
  );

implementation

end.
