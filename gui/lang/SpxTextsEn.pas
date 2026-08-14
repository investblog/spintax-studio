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

      'Even panes', 'Double-click: even panes',

      'Editor font', 'Auto',

      'Value not applied: the engine would read the directive differently',

      'Includes — the fragments this document pulls in', 'Target', 'Found', 'yes', 'MISSING', 'no set',

      'Help', 'Contents', 'Help language', 'There is no help in %s yet.',

      'from the help', 'Insert into my document',

      'About',

      'No macros yet — write #set %name% = value in the document, then use %name% in the text.',
      'Nothing included yet — #include "fragment" pulls in another file, and only from the start of a line.',

      'Write a template on the left and see what it renders on the right. Validation, variables, includes, variant generation and export — all offline: no account, no network, no runtime.',
      'Licences and credits',

      'GSA import',
      'Import GSA template…',
      'GSA templates|*.txt;*.spintax|All files|*.*',
      '%d variables were lifted out of the template.',
      'They are session values: they are shown in the Variables panel and are NOT saved with the document. Rendering also runs without post-processing, so the template stays exactly as GSA wrote it.',
      '%d blocks were refused and left exactly as they were.',
      '…and %d more.',

      'Possible variants: %s',
      'Possible variants: at least %s',

      (* the AI panel (ADR 0011) *)
      'AI draft',
      'Brief',
      'Variables the model may use',
      'The model''s answer',
      'Channel',
      'Variation',
      'Language',
      'Copy prompt',
      'Copy repair prompt',
      'Insert into document',
      'Case',
      'Note',
      'Prompt copied. Take it to your model and bring the answer back.',
      'Repair prompt copied. It points at the exact spans.',
      'Draft inserted. The diagnostics panel has the verdict.',
      'Write a brief first.',
      'Paste the model''s answer first.',
      'No errors to repair.',
      'email',
      'SMS',
      'push',
      'landing',
      'generic',
      'conservative',
      'balanced',
      'aggressive',
      '—',
      'nominative',
      'genitive',
      'dative',
      'accusative',
      'instrumental',
      'prepositional',
      'Replace the document',
      'Document replaced. The diagnostics panel has the verdict.',

      (* R1-4: the loop in the window. The recipient is "this endpoint" -- an address the
         reader configured -- and no sentence here claims to know what the software at that
         address does or where it runs (spec §4.5). *)
      'Fix',
      'AI settings…',
      'stopped',
      'asking the model…',
      'checking the draft with the engine…',
      'fix attempt %d of %d',
      'No errors, but some test renders come out empty — check the plural forms. The draft is in the AI panel, not applied.',
      'The draft is clean, but an included fragment has an error. Fix that file — regenerating the template cannot.',
      '%d errors remain after %d fix attempts. The draft is in the AI panel, not applied.',
      'The document changed while the answer was on its way. The draft is in the AI panel, not applied.',
      'This profile authenticates, and no key is attached. Enter the key in the AI panel.',
      'The endpoint asks to go to a different address (%s). It was not followed; change the profile if that is intended.',
      'Plain http off this machine would send the key and the text in clear. Use https.',
      'The endpoint refused the key. Check it in the AI panel.',
      'The endpoint reports a rate limit or an exhausted quota. Try again later.',
      'The prompt is longer than this model accepts.',
      'The request did not go through: %s',
      'The endpoint answered, but not in a form this application can read: %s',
      'The answer carried no template.',
      'The endpoint reports: %s',
      'Connection',
      'Format',
      'Endpoint',
      'Model',
      'Authorization',
      'none',
      'API key',
      'Key',
      'Attach key',
      'Forget key',
      'a key is attached to this endpoint',
      'no key attached',
      'the endpoint changed — enter the key again to attach it to the new address',
      'Sending allowed',
      'Send to this endpoint?',
      'Generate and Fix send the brief, the current template and the declared variables to the endpoint of this profile:'#10'%s'#10#10'With API-key authorization the key travels in the request headers. Nothing is sent at any other moment, and the address never changes on its own: a redirect is refused and shown. What the software at that address does with the text is up to its operator.'#10#10'You can turn this off at any time in the AI settings.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Report inappropriate AI output…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Text to convert',
      'Paste the text to convert first.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Replace…',
      'replace with',
      'Replace',
      'Replace all',
      'Replaced: %d'
  );

implementation

end.
