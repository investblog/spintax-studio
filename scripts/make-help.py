#!/usr/bin/env python3
"""Convert the help documents into the Pascal unit that ships inside the .exe.

THE MARKDOWN STAYS THE SINGLE SOURCE. `TestHelpExamples` reads those same files and runs every
example through the real engine, so what the reader sees in the window cannot diverge from what
the suite verified -- that is the whole reason this is generated rather than written by hand.

A PAGE PER SECTION, never one document. TIpHtmlPanel's layout is quadratic (35 ms on 1.5 KB,
12.9 s on 172 KB -- ADR 0004), and measured here on a 12.7 KB page: 156 ms. Cutting at `##`
keeps every page around 100 ms; the Russian document whole would be four times that and a
language reference on top of it would be seconds.

ESCAPING IS LOAD-BEARING, NOT HYGIENE. Six real lines across the two documents carry a literal
`<` -- `[<foo=1>a|b|c]`, `[<minsize=two>a|b|c]`, `` `[a<br>|b]` `` -- and the renderer swallows
each as an unknown tag. The `permutation.unknown-key` article would show an output with its
cause invisible. So every `&`, `<` and `>` in text is escaped, inside code spans and fences too,
and those three are the whole escape set: arrows, ellipses, fullwidth braces and Cyrillic pass
through as the UTF-8 they are.

REFUSES TO WRITE A BAD ARTIFACT, like the other generators here. Unsupported markdown, an
oversized page, a page whose HTML could hang the renderer -- it stops and says which line.

Usage:  python scripts/make-help.py

Writes: gui/SpxHelpText.pas
"""
import io
import os
import re

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The languages the help exists in, and the order the unit indexes them by. The interface has
# fourteen; a language with no document here falls back to English, which is what the interface
# strings already do for a language with no table.
LANGS = ['en', 'ru']

# Above this a page starts costing what ADR 0004's curve says it does. Nothing is near it today
# (the largest is about 9 KB); it is here so that growth trips a build rather than a user.
PAGE_LIMIT = 24 * 1024

# A slug names a section across BOTH documents, so the viewer can keep your place when the
# interface language changes. Taken from the English titles, applied by position -- which is
# sound only while the two documents run parallel, and that is asserted below.
SLUGS = [
    'about', 'reading', 'brackets', 'definitions', 'variables', 'includes',
    'plurals', 'permutations', 'notes', 'abbreviations', 'correct', 'faq',
]


class Bad(SystemExit):
    def __init__(self, lang, line_no, message):
        SystemExit.__init__(self, 'docs/help/%s/diagnostics.md:%d: %s' % (lang, line_no, message))


def fnv1a(data):
    """FNV-1a, 64-bit, as sixteen hex digits.

    NOT sha1, though the RTL has it: `hash` is a package rather than the RTL proper, and a
    drift check that fails to COMPILE on some distro's fpc would be the gate breaking for a
    reason that has nothing to do with the help. This is eight lines on both sides, needs no
    unit at all, and the suite pins a test vector so the two implementations cannot drift from
    each other while checking that nothing else does.
    """
    h = 14695981039346656037
    for b in data:
        h = ((h ^ b) * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return '%016x' % h


def esc(text):
    """The three characters the renderer would otherwise read as markup. Nothing else."""
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def markup(lang, line_no, escaped):
    """The two inline forms, over text that is ALREADY escaped -- so a tag in the result can only
    be one this script wrote.

    Runs on a whole BLOCK, never on a single line. `**as text**` in the English document is split
    across a soft wrap, and a per-line pass reported it as an unmatched `**`. Markdown lets inline
    markup cross a soft break, and the prose that is already written uses that.
    """
    out = re.sub(r'`([^`]*)`', r'<code>\1</code>', escaped)
    out = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', out, flags=re.S)
    if '`' in out:
        raise Bad(lang, line_no, 'an unmatched backtick in this block')
    if '**' in out:
        raise Bad(lang, line_no, 'an unmatched ** in this block')
    if re.search(r'(?<!\*)\*(?!\*)', out):
        raise Bad(lang, line_no, 'a single * -- this subset has no emphasis, only **bold**')
    return out


def inline(lang, line_no, text):
    """One line that cannot wrap: a heading, a table cell."""
    return markup(lang, line_no, esc(text))


# The three-space gap that sets a NOTE off from an example's output. The suite's own parser
# already reads what follows as prose rather than as part of the answer.
NOTE_GAP = re.compile('^(.*→.*?)   +(\\S.*)$')


def fence_line(text):
    """One line of a fenced block, escaped -- with a trailing note moved to a line of its own.

    A <pre> cannot wrap, so its longest line sets the layout width for the WHOLE page: measured,
    the Russian plurals page wanted 770 px against a 460 px panel, and the widest lines were wide
    because of a note pinned after the output. Moving the note down is not a liberty -- the
    suite's parser already excludes it from the comparison -- and it buys twenty-odd characters
    exactly where they cost most. The note itself is not touched.
    """
    m = NOTE_GAP.match(text)
    if not m:
        return esc(text)
    return esc(m.group(1).rstrip()) + '\n' + esc('      ' + m.group(2))


def reject_unsupported(lang, line_no, raw):
    if re.match(r'^#{4,} ', raw.strip()):
        raise Bad(lang, line_no, 'a heading deeper than ###')
    if re.search(r'!\[', raw):
        raise Bad(lang, line_no, 'an image -- the renderer has no data provider and would draw '
                                 'a broken-image placeholder')
    if re.search(r'\[[^\]]*\]\([^)]*\)', raw):
        raise Bad(lang, line_no, 'a link -- the viewer has no href handling in R0')
    if re.match(r'^\s*\d+\. ', raw):
        raise Bad(lang, line_no, 'a numbered list is not in this subset')
    if '~~' in raw:
        raise Bad(lang, line_no, 'strikethrough is not in this subset')


def heading_anchor(page_slug, index, text):
    """A `### `code` -- …` heading is that code's article; anything else gets a positional id.

    Positional rather than a slug of the title, because the title is prose in fourteen possible
    languages and an id has to be ASCII and the same in both documents.
    """
    m = re.match(r'^`([^`]+)`', text.strip())
    if m and re.match(r'^[a-z]+\.[a-z.-]+$', m.group(1)):
        return m.group(1), True
    return '%s-%d' % (page_slug, index), False


def convert(lang, path):
    """One document into pages. Each page: slug, title, html lines, anchors."""
    raw = io.open(path, 'rb').read()
    digest = fnv1a(raw)
    lines = raw.decode('utf-8').split('\n')

    pages = []
    page = None
    fence = None          # the info string while inside a fence, else None
    para = []             # ESCAPED text; joined and marked up at flush, never per line
    item = []
    quote = []
    at = {'para': 0, 'item': 0, 'quote': 0}   # the line each open block started on
    table = []
    fence_body = []
    fence_start = 0

    def start_page(title, line_no):
        n = len(pages)
        if n >= len(SLUGS):
            raise Bad(lang, line_no, 'more sections than SLUGS names -- add one to the script')
        pages.append({'slug': SLUGS[n], 'title': title, 'html': [], 'anchors': []})
        return pages[-1]

    def flush():
        """Close whatever block was open. Called before every block-level construct."""
        if para:
            page['html'].append('<p>' + markup(lang, at['para'], ' '.join(para)) + '</p>')
            del para[:]
        if item:
            page['html'].append('<li>' + markup(lang, at['item'], ' '.join(item)) + '</li>')
            del item[:]
        if quote:
            page['html'].append('<blockquote>' +
                                markup(lang, at['quote'], ' '.join(quote)) + '</blockquote>')
            del quote[:]
        if table:
            emit_table()

    def close_list():
        if page['html'] and page['html'][-1].startswith('<li>'):
            # walk back to the run of items and wrap it
            i = len(page['html'])
            while i > 0 and page['html'][i - 1].startswith('<li>'):
                i -= 1
            page['html'].insert(i, '<ul>')
            page['html'].append('</ul>')

    def emit_table():
        rows = list(table)
        del table[:]
        if len(rows) < 2 or not re.match(r'^\|[\s|:-]+\|$', rows[1][1]):
            raise Bad(lang, rows[0][0], 'a table without a |---| delimiter row')
        width = None
        # WIDTH 100%, and it is not decoration. Without it IPro sizes the columns by what
        # they would PREFER, which for three columns of prose is wider than any panel -- and
        # the table then sets the layout width for the whole page, so the heading and the
        # paragraphs were clipped too and the panel grew a horizontal scrollbar. Measured on
        # the first page, which has no <pre> at all and was still cut off.
        page['html'].append('<table border=1 cellpadding=4 cellspacing=0 width="100%">')
        for i, (no, text) in enumerate(rows):
            if i == 1:
                continue
            cells = [c.strip() for c in text.strip().strip('|').split('|')]
            if width is None:
                width = len(cells)
            elif len(cells) != width:
                raise Bad(lang, no, 'this table row has %d cells, the first had %d'
                                    % (len(cells), width))
            tag = 'th' if i == 0 else 'td'
            page['html'].append('<tr>' + ''.join(
                '<%s>%s</%s>' % (tag, inline(lang, no, c), tag) for c in cells) + '</tr>')
        page['html'].append('</table>')

    for n, raw_line in enumerate(lines, 1):
        line = raw_line.rstrip()
        stripped = line.strip()

        if stripped.startswith('```'):
            if fence is None:
                flush()
                close_list()
                fence = stripped[3:].strip()
                if fence not in ('', 'spx-fixture'):
                    raise Bad(lang, n, 'an unknown fence info string %r' % fence)
                fence_body = []
                fence_start = n
            else:
                page['html'].append('<pre>' + '\n'.join(fence_body) + '</pre>')
                fence = None
            continue

        if fence is not None:
            fence_body.append(fence_line(raw_line.rstrip('\r')))
            continue

        reject_unsupported(lang, n, line)

        if stripped.startswith('# '):
            if page is not None:
                raise Bad(lang, n, 'a second level-1 heading')
            page = start_page(stripped[2:].strip(), n)
            page['html'].append('<h1 id="%s">%s</h1>' % (page['slug'], inline(lang, n, page['title'])))
            continue

        if page is None:
            if not stripped:
                continue
            raise Bad(lang, n, 'text before the document title')

        if stripped.startswith('## '):
            flush()
            close_list()
            title = stripped[3:].strip()
            page = start_page(title, n)
            page['html'].append('<h2 id="%s">%s</h2>' % (page['slug'], inline(lang, n, title)))
            continue

        if stripped.startswith('### '):
            flush()
            close_list()
            text = stripped[4:].strip()
            anchor, is_code = heading_anchor(page['slug'], len(page['anchors']), text)
            page['anchors'].append({'id': anchor, 'title': text, 'code': is_code})
            page['html'].append('<h3 id="%s">%s</h3>' % (anchor, inline(lang, n, text)))
            continue

        if stripped == '---':
            flush()
            close_list()
            page['html'].append('<hr>')
            continue

        if stripped.startswith('|'):
            if para or item or quote:
                flush()
            table.append((n, stripped))
            continue
        if table:
            emit_table()

        if stripped.startswith('> '):
            if para or item:
                flush()
            if not quote:
                at['quote'] = n
            quote.append(esc(stripped[2:]))
            continue
        if quote:
            flush()

        if stripped.startswith('- '):
            if para:
                flush()
            if item:
                page['html'].append('<li>' + markup(lang, at['item'], ' '.join(item)) + '</li>')
                del item[:]
            at['item'] = n
            item.append(esc(stripped[2:]))
            continue

        if not stripped:
            flush()
            close_list()
            continue

        # a continuation: of a list item when one is open, else of a paragraph
        if item:
            item.append(esc(stripped))
        else:
            if not para:
                at['para'] = n
            para.append(esc(stripped))

    if fence is not None:
        raise Bad(lang, fence_start, 'this fence is never closed')
    flush()
    close_list()
    return pages, digest


BLOCK_TAGS = ['p', 'pre', 'blockquote', 'ul', 'li', 'table', 'tr', 'th', 'td',
              'h1', 'h2', 'h3']


def refuse_bad_html(lang, page):
    """The renderer's hazards, checked before anything is written. The suite re-runs all of it
    over the shipped artifact -- the generator must not be the only thing checking the
    generator."""
    html = '\n'.join(page['html'])
    where = 'page %r' % page['slug']

    if '<!' in html:
        raise SystemExit('%s/%s: a `<!` -- IPro\'s NextToken scans to the end of string with no '
                         'guard, and parsing runs on the UI thread, so this is a permanently '
                         'frozen window (ADR 0004)' % (lang, where))
    for m in re.finditer(r'<(.?)', html):
        if not re.match(r'[A-Za-z/]', m.group(1) or ' '):
            raise SystemExit('%s/%s: a `<` that opens no tag' % (lang, where))
    for m in re.finditer(r'&([^;]*);?', html):
        if m.group(1) not in ('amp', 'lt', 'gt'):
            raise SystemExit('%s/%s: the entity &%s; is not one of the three this emits'
                             % (lang, where, m.group(1)))
    if html.endswith('<'):
        raise SystemExit('%s/%s: ends with a bare `<`, which eats the closing tag' % (lang, where))
    if '<img' in html:
        raise SystemExit('%s/%s: an image, and there is no data provider' % (lang, where))
    if '<a ' in html:
        raise SystemExit('%s/%s: a link -- SpxHelpResolveHref exists but nothing routes to it '
                         'yet' % (lang, where))
    for tag in BLOCK_TAGS:
        opens = len(re.findall(r'<%s\b' % tag, html))
        closes = len(re.findall(r'</%s>' % tag, html))
        if opens != closes:
            raise SystemExit('%s/%s: <%s> opened %d times and closed %d'
                             % (lang, where, tag, opens, closes))
    if len(html.encode('utf-8')) > PAGE_LIMIT:
        raise SystemExit('%s/%s: %d bytes, over the %d limit -- split the section'
                         % (lang, where, len(html.encode('utf-8')), PAGE_LIMIT))


def literal(text):
    """A Pascal string literal, wrapped so no source line runs away.

    A newline cannot appear INSIDE a literal -- `Fatal: String exceeds line` -- and a fenced
    block is full of them, so they leave the quotes as #10.
    """
    parts = []
    chunk = []
    width = 0
    for ch in text:
        if ch == '\n':
            parts.append("'%s'" % ''.join(chunk))
            parts.append('#10')
            chunk = []
            width = 0
            continue
        piece = "''" if ch == "'" else ch
        if width + len(piece) > 86 and chunk:
            parts.append("'%s'" % ''.join(chunk))
            chunk = []
            width = 0
        chunk.append(piece)
        width += len(piece)
    parts.append("'%s'" % ''.join(chunk))
    # an empty literal next to a #10 is noise; '' alone is still needed when the whole line is
    parts = [p for p in parts if p != "''"] or ["''"]
    return " +\n      ".join(parts)


def main():
    docs = []
    for lang in LANGS:
        path = os.path.join(HERE, 'docs', 'help', lang, 'diagnostics.md')
        if not os.path.exists(path):
            raise SystemExit('missing help document: %s' % path)
        pages, digest = convert(lang, path)
        for page in pages:
            refuse_bad_html(lang, page)
        docs.append({'lang': lang, 'pages': pages, 'digest': digest,
                     'path': 'docs/help/%s/diagnostics.md' % lang})

    # THE DOCUMENTS MUST RUN PARALLEL, because a slug names a section in both of them and the
    # viewer keeps your place across a language switch by that name. Checked on the CODES, which
    # are the part that cannot be a matter of taste: page N carries the same articles in both.
    base = docs[0]
    for other in docs[1:]:
        if len(other['pages']) != len(base['pages']):
            raise SystemExit('%s has %d sections and %s has %d -- they must run parallel'
                             % (other['lang'], len(other['pages']),
                                base['lang'], len(base['pages'])))
        for i, (a, b) in enumerate(zip(base['pages'], other['pages'])):
            ca = sorted(x['id'] for x in a['anchors'] if x['code'])
            cb = sorted(x['id'] for x in b['anchors'] if x['code'])
            if ca != cb:
                raise SystemExit('section %d (%s) holds %s in %s but %s in %s'
                                 % (i, a['slug'], ca, base['lang'], cb, other['lang']))

    npages = len(base['pages'])
    flat = []          # every HTML line of every page, in (lang, page) order
    spans = []         # (first, last) into flat, indexed lang*npages + page
    titles = []
    anchors = []       # (page, id, title, is_code)
    anchor_span = []   # (first, last) into anchors, per language

    for doc in docs:
        first_anchor = len(anchors)
        for page in doc['pages']:
            spans.append((len(flat), len(flat) + len(page['html']) - 1))
            flat.extend(page['html'])
            titles.append(page['title'])
        for p, page in enumerate(doc['pages']):
            for a in page['anchors']:
                anchors.append((p, a['id'], a['title'], a['code']))
        anchor_span.append((first_anchor, len(anchors) - 1))

    u = ['(*',
         ' * SpxHelpText -- the help documents, as HTML, one page per section.',
         ' *',
         ' * GENERATED by scripts/make-help.py from docs/help/<lang>/diagnostics.md. Do not edit:',
         ' * change the markdown and run the script again. The markdown is the single source --',
         ' * TestHelpExamples runs every example in it through the real engine, so what ships here',
         ' * cannot diverge from what was verified. The suite compares SpxHelpSourceDigest against',
         ' * the file on disk, which is what makes "edited the markdown, forgot to regenerate" a',
         ' * failing build rather than a stale window.',
         ' *',
         ' * A PAGE PER SECTION. TIpHtmlPanel\'s layout is quadratic -- measured 156 ms on 12.7 KB,',
         ' * and 12.9 s on 172 KB (ADR 0004). Whole documents would be seconds.',
         ' *',
         ' * The index is ALang * SPX_HELP_PAGE_COUNT + APage. Both documents carry the same',
         ' * sections in the same order, and the script refuses to write unless they do, because a',
         ' * slug names a section in BOTH -- that is how the viewer keeps your place when the',
         ' * interface language changes.',
         ' *)',
         'unit SpxHelpText;',
         '',
         '{$mode objfpc}{$H+}',
         '',
         'interface',
         '',
         'const',
         '  SPX_HELP_LANG_COUNT = %d;' % len(LANGS),
         '  SPX_HELP_PAGE_COUNT = %d;' % npages,
         '',
         '{ The help languages, by the engine\'s own code. Not the interface\'s fourteen: a',
         '  language with no document here falls back, and SpxHelpNav owns that rule. }',
         'function SpxHelpLangCode(ALang: Integer): string;',
         'function SpxHelpLangIndex(const ACode: string): Integer;   { -1 when absent }',
         '',
         '{ Where the document came from, and an FNV-1a of its bytes. The suite reads the file and',
         '  compares -- an edit without a regeneration fails the build. }',
         'function SpxHelpSourcePath(ALang: Integer): string;',
         'function SpxHelpSourceDigest(ALang: Integer): string;',
         '',
         '{ A page. The slug is the same string in every language; the title is that language\'s. }',
         'function SpxHelpPageSlug(APage: Integer): string;',
         'function SpxHelpPageIndex(const ASlug: string): Integer;   { -1 when absent }',
         'function SpxHelpPageTitle(ALang, APage: Integer): string;',
         '',
         '{ The page\'s HTML -- a FRAGMENT, with no <html> around it. SpxHelpNav.SpxHelpDocument',
         '  wraps it, and the renderer must never be handed a bare fragment (ADR 0004). }',
         'function SpxHelpPageHtml(ALang, APage: Integer): string;',
         '',
         '{ The `###` articles of a language, in document order. IsCode says the id is a',
         '  diagnostic code, which is what a row in the panel can be looked up by. }',
         'function SpxHelpAnchorCount(ALang: Integer): Integer;',
         'function SpxHelpAnchorPage(ALang, AIndex: Integer): Integer;',
         'function SpxHelpAnchorId(ALang, AIndex: Integer): string;',
         'function SpxHelpAnchorTitle(ALang, AIndex: Integer): string;',
         'function SpxHelpAnchorIsCode(ALang, AIndex: Integer): Boolean;',
         '',
         'implementation',
         '',
         'const',
         '  HELP_LANG: array[0..%d] of string = (%s);'
         % (len(LANGS) - 1, ', '.join("'%s'" % c for c in LANGS)),
         '  HELP_PATH: array[0..%d] of string = (%s);'
         % (len(LANGS) - 1, ', '.join("'%s'" % d['path'] for d in docs)),
         '  HELP_DIGEST: array[0..%d] of string = (%s);'
         % (len(LANGS) - 1, ', '.join("'%s'" % d['digest'] for d in docs)),
         '',
         '  HELP_SLUG: array[0..%d] of string = (' % (npages - 1),
         '    ' + ', '.join("'%s'" % p['slug'] for p in base['pages']),
         '  );',
         '']

    u.append('  { Titles, indexed ALang * SPX_HELP_PAGE_COUNT + APage. }')
    u.append('  HELP_TITLE: array[0..%d] of string = (' % (len(titles) - 1))
    for i, t in enumerate(titles):
        u.append('    %s%s' % (literal(t), ',' if i < len(titles) - 1 else ''))
    u.append('  );')
    u.append('')

    u.append('  { First and last line of each page in HELP_LINE, same index. }')
    u.append('  HELP_FIRST: array[0..%d] of Integer = (' % (len(spans) - 1))
    u.append('    ' + ', '.join(str(a) for a, _ in spans))
    u.append('  );')
    u.append('  HELP_LAST: array[0..%d] of Integer = (' % (len(spans) - 1))
    u.append('    ' + ', '.join(str(b) for _, b in spans))
    u.append('  );')
    u.append('')

    u.append('  { Every page of every language, one element per line of HTML -- a change to the')
    u.append('    prose is then one readable hunk in a diff, which a byte array would not be. }')
    u.append('  HELP_LINE: array[0..%d] of string = (' % (len(flat) - 1))
    for i, line in enumerate(flat):
        u.append('    %s%s' % (literal(line), ',' if i < len(flat) - 1 else ''))
    u.append('  );')
    u.append('')

    u.append('  { The `###` articles: page, id, title, and whether the id is a diagnostic code. }')
    u.append('  HELP_ANCHOR_FIRST: array[0..%d] of Integer = (%s);'
             % (len(LANGS) - 1, ', '.join(str(a) for a, _ in anchor_span)))
    u.append('  HELP_ANCHOR_LAST: array[0..%d] of Integer = (%s);'
             % (len(LANGS) - 1, ', '.join(str(b) for _, b in anchor_span)))
    u.append('  HELP_ANCHOR_PAGE: array[0..%d] of Integer = (' % (len(anchors) - 1))
    u.append('    ' + ', '.join(str(a[0]) for a in anchors))
    u.append('  );')
    u.append('  HELP_ANCHOR_ID: array[0..%d] of string = (' % (len(anchors) - 1))
    for i, a in enumerate(anchors):
        u.append('    %s%s' % (literal(a[1]), ',' if i < len(anchors) - 1 else ''))
    u.append('  );')
    u.append('  HELP_ANCHOR_TITLE: array[0..%d] of string = (' % (len(anchors) - 1))
    for i, a in enumerate(anchors):
        u.append('    %s%s' % (literal(a[2]), ',' if i < len(anchors) - 1 else ''))
    u.append('  );')
    u.append('  HELP_ANCHOR_CODE: array[0..%d] of Boolean = (' % (len(anchors) - 1))
    u.append('    ' + ', '.join('True' if a[3] else 'False' for a in anchors))
    u.append('  );')
    u.append('')

    u += ['function SpxHelpLangCode(ALang: Integer): string;',
          'begin',
          '  if (ALang < 0) or (ALang > High(HELP_LANG)) then Exit(\'\');',
          '  Result := HELP_LANG[ALang];',
          'end;',
          '',
          'function SpxHelpLangIndex(const ACode: string): Integer;',
          'var i: Integer;',
          'begin',
          '  for i := Low(HELP_LANG) to High(HELP_LANG) do',
          '    if HELP_LANG[i] = ACode then Exit(i);',
          '  Result := -1;',
          'end;',
          '',
          'function SpxHelpSourcePath(ALang: Integer): string;',
          'begin',
          '  if (ALang < 0) or (ALang > High(HELP_PATH)) then Exit(\'\');',
          '  Result := HELP_PATH[ALang];',
          'end;',
          '',
          'function SpxHelpSourceDigest(ALang: Integer): string;',
          'begin',
          '  if (ALang < 0) or (ALang > High(HELP_DIGEST)) then Exit(\'\');',
          '  Result := HELP_DIGEST[ALang];',
          'end;',
          '',
          'function SpxHelpPageSlug(APage: Integer): string;',
          'begin',
          '  if (APage < 0) or (APage > High(HELP_SLUG)) then Exit(\'\');',
          '  Result := HELP_SLUG[APage];',
          'end;',
          '',
          'function SpxHelpPageIndex(const ASlug: string): Integer;',
          'var i: Integer;',
          'begin',
          '  for i := Low(HELP_SLUG) to High(HELP_SLUG) do',
          '    if HELP_SLUG[i] = ASlug then Exit(i);',
          '  Result := -1;',
          'end;',
          '',
          '{ The one place the two-dimensional index is computed. -1 when either is out of range,',
          '  so every caller above can answer with an empty string rather than a range error. }',
          'function PageAt(ALang, APage: Integer): Integer;',
          'begin',
          '  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) or',
          '     (APage < 0) or (APage >= SPX_HELP_PAGE_COUNT) then Exit(-1);',
          '  Result := ALang * SPX_HELP_PAGE_COUNT + APage;',
          'end;',
          '',
          'function SpxHelpPageTitle(ALang, APage: Integer): string;',
          'var i: Integer;',
          'begin',
          '  i := PageAt(ALang, APage);',
          '  if i < 0 then Exit(\'\');',
          '  Result := HELP_TITLE[i];',
          'end;',
          '',
          'function SpxHelpPageHtml(ALang, APage: Integer): string;',
          'var i, n: Integer;',
          'begin',
          '  Result := \'\';',
          '  i := PageAt(ALang, APage);',
          '  if i < 0 then Exit;',
          '  for n := HELP_FIRST[i] to HELP_LAST[i] do',
          '  begin',
          '    if n > HELP_FIRST[i] then Result := Result + #10;',
          '    Result := Result + HELP_LINE[n];',
          '  end;',
          'end;',
          '',
          'function SpxHelpAnchorCount(ALang: Integer): Integer;',
          'begin',
          '  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then Exit(0);',
          '  Result := HELP_ANCHOR_LAST[ALang] - HELP_ANCHOR_FIRST[ALang] + 1;',
          'end;',
          '',
          '{ -1 rather than a range error, for the same reason PageAt gives. }',
          'function AnchorAt(ALang, AIndex: Integer): Integer;',
          'begin',
          '  if (AIndex < 0) or (AIndex >= SpxHelpAnchorCount(ALang)) then Exit(-1);',
          '  Result := HELP_ANCHOR_FIRST[ALang] + AIndex;',
          'end;',
          '',
          'function SpxHelpAnchorPage(ALang, AIndex: Integer): Integer;',
          'var i: Integer;',
          'begin',
          '  i := AnchorAt(ALang, AIndex);',
          '  if i < 0 then Exit(-1);',
          '  Result := HELP_ANCHOR_PAGE[i];',
          'end;',
          '',
          'function SpxHelpAnchorId(ALang, AIndex: Integer): string;',
          'var i: Integer;',
          'begin',
          '  i := AnchorAt(ALang, AIndex);',
          '  if i < 0 then Exit(\'\');',
          '  Result := HELP_ANCHOR_ID[i];',
          'end;',
          '',
          'function SpxHelpAnchorTitle(ALang, AIndex: Integer): string;',
          'var i: Integer;',
          'begin',
          '  i := AnchorAt(ALang, AIndex);',
          '  if i < 0 then Exit(\'\');',
          '  Result := HELP_ANCHOR_TITLE[i];',
          'end;',
          '',
          'function SpxHelpAnchorIsCode(ALang, AIndex: Integer): Boolean;',
          'var i: Integer;',
          'begin',
          '  i := AnchorAt(ALang, AIndex);',
          '  Result := (i >= 0) and HELP_ANCHOR_CODE[i];',
          'end;',
          '',
          'end.',
          '']

    out = os.path.join(HERE, 'gui', 'SpxHelpText.pas')
    io.open(out, 'w', encoding='utf-8', newline='').write('\n'.join(u))
    for doc in docs:
        big = max(len('\n'.join(p['html']).encode('utf-8')) for p in doc['pages'])
        print('%-30s %2d pages, %2d articles, largest %d bytes'
              % (doc['path'], len(doc['pages']),
                 sum(len(p['anchors']) for p in doc['pages']), big))
    print('%-30s %d bytes' % (os.path.relpath(out, HERE), os.path.getsize(out)))


if __name__ == '__main__':
    main()
