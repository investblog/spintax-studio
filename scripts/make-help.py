#!/usr/bin/env python3
"""Convert the help documents into the Pascal unit that ships inside the .exe.

THE MARKDOWN STAYS THE SINGLE SOURCE. `TestHelpExamples` reads those same files and runs every
example through the real engine, so what the reader sees in the window cannot diverge from what
the suite verified -- that is the whole reason this is generated rather than written by hand.

THE TEMPLATE OF EVERY EXAMPLE IS A LINK, and the output beside it is not: you click the input
and get the output, which is what the arrow already says. Measured before it was built -- an
anchor inside a <pre> is a link to IPro, HotURL comes back as written, and the output half of the
same line reports nothing.

THE CONDITIONS TRAVEL WITH IT. Each document's spx-fixture block declares the locale, the seed
and the template set its outputs were measured under, and those go into the unit too: a click
renders under the document's own conditions, or the help would print one answer and the pane show
another -- which is the one thing a document whose examples are fixtures may never do.

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


ARROW = '→'


def link(index, inner):
    """An anchor the window resolves by number. `ex:` rather than a bare digit so a future kind
    of link cannot be mistaken for this one."""
    return '<a href="ex:%d">%s</a>' % (index, inner)


def fence_note(right):
    """What follows the arrow, with a trailing note kept on the line but out of the link."""
    return esc(right)


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


def read_fixture(lang, line_no, body, into):
    """The conditions the document's outputs were measured under.

    The suite reads this same block out of the markdown; this carries it into the exe so the
    pane can render under them too. Unknown keys fail rather than reverting to a default -- a
    typo'd `locale` that silently fell back would render every example against the wrong engine.
    """
    for raw in body:
        t = raw.strip()
        if not t:
            continue
        at = t.find(': ')
        if at < 0:
            raise Bad(lang, line_no, 'a conditions line that is not `key: value` [%s]' % t)
        key, val = t[:at].strip(), t[at + 2:]
        if key == 'locale':
            into['locale'] = val.strip()
        elif key == 'seed':
            if not val.strip().isdigit() or int(val.strip()) == 0:
                raise Bad(lang, line_no, 'the seed is not a positive number [%s]' % val)
            into['seed'] = int(val.strip())
        elif key == 'empty':
            into['empty'] = val.strip()
        elif key.startswith('include '):
            into['includes'].append((key[8:].strip(), val))
        else:
            raise Bad(lang, line_no, 'a conditions key this script does not know [%s]' % key)


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
    fixture = {'locale': '', 'seed': 0, 'empty': '', 'includes': []}
    examples = []         # every example's template, in document order
    acc = []              # the template lines of the one being read
    seen_fixture = [False]
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
                del acc[:]
                fence_start = n
            else:
                if fence == 'spx-fixture':
                    if seen_fixture[0]:
                        raise Bad(lang, fence_start, 'a second conditions block')
                    seen_fixture[0] = True
                    read_fixture(lang, fence_start, [x for x in fence_body], fixture)
                page['html'].append('<pre>' + '\n'.join(fence_body) + '</pre>')
                fence = None
            continue

        if fence is not None:
            t = raw_line.rstrip()
            if fence == 'spx-fixture':
                fence_body.append(esc(t))
                continue
            # EVERY EXAMPLE'S TEMPLATE, by the same rule the suite reads them by: a line without
            # an arrow continues the template, a line with one ends the example and contributes
            # what stands before it, a blank line starts over. The parsing happens HERE, so the
            # window has none of its own -- it is handed a number and looks the template up.
            if not t.strip():
                del acc[:]
                fence_body.append('')
                continue
            if ARROW in t:
                left, right = t.split(ARROW, 1)
                if left.strip():
                    acc.append(left.rstrip())
                if acc:
                    examples.append('\n'.join(acc))
                    ex = len(examples) - 1
                    # The TEMPLATE is the link and the output is not. Each line of a multi-line
                    # template is its own anchor pointing at the same example: a single-line
                    # inline anchor inside a <pre> is the case that was measured, and a bigger
                    # click target costs nothing.
                    #
                    # HOW MANY LINES CAME BEFORE depends on whether THIS line carried any of the
                    # template. When the arrow line's left side is blank the whole template is
                    # above it, and subtracting one anyway left the first line unclickable and
                    # emitted an empty anchor on the output line -- shipped twice in the Russian
                    # document, and the two languages then behaved differently from the same
                    # markdown.
                    here = 1 if left.strip() else 0
                    for i in range(len(fence_body) - (len(acc) - here), len(fence_body)):
                        fence_body[i] = link(ex, fence_body[i])
                    if here:
                        fence_body.append(link(ex, esc(left.rstrip())) +
                                          esc(left[len(left.rstrip()):]) + ARROW +
                                          fence_note(right))
                    else:
                        fence_body.append(esc(left) + ARROW + fence_note(right))
                else:
                    fence_body.append(fence_line(t))
                del acc[:]
                continue
            acc.append(t)
            fence_body.append(esc(t))
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
    return pages, digest, fixture, examples


BLOCK_TAGS = ['p', 'pre', 'blockquote', 'ul', 'li', 'table', 'tr', 'th', 'td',
              'h1', 'h2', 'h3']


# How many examples the document being checked has -- set before the pages are walked, so the
# link check can say "a link to example 40 of 34" rather than only "a link".
ANY_EXAMPLES = [0]


def seen_any(fixture):
    return (fixture['locale'] != '') and (fixture['seed'] > 0)


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
    # EVERY LINK IS AN EXAMPLE, and its number is one this document has. The window resolves an
    # href by looking the number up, so a link to nothing would be a click that silently does
    # nothing -- and a click that does nothing reads as a broken feature, not as prose.
    for m in re.finditer('<a href="([^"]*)"', html):
        if not re.match('^ex:[0-9]+$', m.group(1)):
            raise SystemExit('%s/%s: a link to %r, and the only kind this emits is ex:N'
                             % (lang, where, m.group(1)))
        if int(m.group(1)[3:]) >= ANY_EXAMPLES[0]:
            raise SystemExit('%s/%s: a link to example %s of %d'
                             % (lang, where, m.group(1)[3:], ANY_EXAMPLES[0]))
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
        pages, digest, fixture, examples = convert(lang, path)
        if not seen_any(fixture):
            raise SystemExit('%s: no spx-fixture block -- the pane could not reproduce the '
                             'outputs it prints' % lang)
        if fixture['locale'] != lang:
            raise SystemExit('%s declares locale %r' % (lang, fixture['locale']))
        ANY_EXAMPLES[0] = len(examples)
        for page in pages:
            refuse_bad_html(lang, page)
        docs.append({'lang': lang, 'pages': pages, 'digest': digest, 'fixture': fixture,
                     'examples': examples,
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

    exs, ex_span, incs, inc_span = [], [], [], []
    for doc in docs:
        first_anchor, first_ex, first_inc = len(anchors), len(exs), len(incs)
        for page in doc['pages']:
            spans.append((len(flat), len(flat) + len(page['html']) - 1))
            flat.extend(page['html'])
            titles.append(page['title'])
        for p, page in enumerate(doc['pages']):
            for a in page['anchors']:
                anchors.append((p, a['id'], a['title'], a['code']))
        anchor_span.append((first_anchor, len(anchors) - 1))
        exs.extend(doc['examples'])
        ex_span.append((first_ex, len(exs) - 1))
        incs.extend(doc['fixture']['includes'])
        inc_span.append((first_inc, len(incs) - 1))

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
         '{ THE CONDITIONS THE OUTPUTS WERE MEASURED UNDER, from the document\'s own spx-fixture',
         '  block. A click rendered under anything else would disagree with the arrow printed',
         '  beside it, which is the one thing this document may never do. }',
         'function SpxHelpLocale(ALang: Integer): string;',
         'function SpxHelpSeed(ALang: Integer): LongWord;',
         'function SpxHelpIncludeCount(ALang: Integer): Integer;',
         'function SpxHelpIncludeName(ALang, AIndex: Integer): string;',
         'function SpxHelpIncludeText(ALang, AIndex: Integer): string;',
         '',
         '{ THE TEMPLATE BEHIND A LINK. Every example`s template is an `ex:N` anchor in the page,',
         '  and this is what N means -- stored verbatim, as the fixture rendered it, so a click',
         '  runs exactly what the suite verified. The window parses nothing: it is handed the',
         '  href and asks here. False for a number this build does not have. }',
         'function SpxHelpExampleCount(ALang: Integer): Integer;',
         'function SpxHelpExample(ALang, AIndex: Integer; out ATemplate: string): Boolean;',
         '{ `ex:7` -> 7, or -1 for anything else. The one place the href form is known. }',
         'function SpxHelpExampleOf(const AHref: string): Integer;',
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

    u.append('  { The conditions the outputs were measured under, and the template set. }')
    u.append('  HELP_LOCALE: array[0..%d] of string = (%s);'
             % (len(LANGS) - 1, ', '.join("'%s'" % d['fixture']['locale'] for d in docs)))
    u.append('  HELP_SEED: array[0..%d] of LongWord = (%s);'
             % (len(LANGS) - 1, ', '.join(str(d['fixture']['seed']) for d in docs)))
    u.append('  HELP_INC_FIRST: array[0..%d] of Integer = (%s);'
             % (len(LANGS) - 1, ', '.join(str(a) for a, _ in inc_span)))
    u.append('  HELP_INC_LAST: array[0..%d] of Integer = (%s);'
             % (len(LANGS) - 1, ', '.join(str(b) for _, b in inc_span)))
    u.append('  HELP_INC_NAME: array[0..%d] of string = (' % (len(incs) - 1))
    for i, e in enumerate(incs):
        u.append('    %s%s' % (literal(e[0]), ',' if i < len(incs) - 1 else ''))
    u.append('  );')
    u.append('  HELP_INC_TEXT: array[0..%d] of string = (' % (len(incs) - 1))
    for i, e in enumerate(incs):
        u.append('    %s%s' % (literal(e[1]), ',' if i < len(incs) - 1 else ''))
    u.append('  );')
    u.append('')

    u.append('  { The templates the `ex:N` links point at, verbatim as the fixture ran them. }')
    u.append('  HELP_EX_FIRST: array[0..%d] of Integer = (%s);'
             % (len(LANGS) - 1, ', '.join(str(a) for a, _ in ex_span)))
    u.append('  HELP_EX_LAST: array[0..%d] of Integer = (%s);'
             % (len(LANGS) - 1, ', '.join(str(b) for _, b in ex_span)))
    u.append('  HELP_EX_TEMPLATE: array[0..%d] of string = (' % (len(exs) - 1))
    for i, e in enumerate(exs):
        u.append('    %s%s' % (literal(e), ',' if i < len(exs) - 1 else ''))
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
          'function SpxHelpLocale(ALang: Integer): string;',
          'begin',
          "  if (ALang < 0) or (ALang > High(HELP_LOCALE)) then Exit('');",
          '  Result := HELP_LOCALE[ALang];',
          'end;',
          '',
          'function SpxHelpSeed(ALang: Integer): LongWord;',
          'begin',
          '  if (ALang < 0) or (ALang > High(HELP_SEED)) then Exit(1);',
          '  Result := HELP_SEED[ALang];',
          'end;',
          '',
          'function SpxHelpIncludeCount(ALang: Integer): Integer;',
          'begin',
          '  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then Exit(0);',
          '  Result := HELP_INC_LAST[ALang] - HELP_INC_FIRST[ALang] + 1;',
          'end;',
          '',
          'function IncAt(ALang, AIndex: Integer): Integer;',
          'begin',
          '  if (AIndex < 0) or (AIndex >= SpxHelpIncludeCount(ALang)) then Exit(-1);',
          '  Result := HELP_INC_FIRST[ALang] + AIndex;',
          'end;',
          '',
          'function SpxHelpIncludeName(ALang, AIndex: Integer): string;',
          'var i: Integer;',
          'begin',
          '  i := IncAt(ALang, AIndex);',
          "  if i < 0 then Exit('');",
          '  Result := HELP_INC_NAME[i];',
          'end;',
          '',
          'function SpxHelpIncludeText(ALang, AIndex: Integer): string;',
          'var i: Integer;',
          'begin',
          '  i := IncAt(ALang, AIndex);',
          "  if i < 0 then Exit('');",
          '  Result := HELP_INC_TEXT[i];',
          'end;',
          '',
          'function SpxHelpExampleCount(ALang: Integer): Integer;',
          'begin',
          '  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then Exit(0);',
          '  Result := HELP_EX_LAST[ALang] - HELP_EX_FIRST[ALang] + 1;',
          'end;',
          '',
          'function SpxHelpExample(ALang, AIndex: Integer; out ATemplate: string): Boolean;',
          'begin',
          "  ATemplate := '';",
          '  Result := (AIndex >= 0) and (AIndex < SpxHelpExampleCount(ALang));',
          '  if Result then ATemplate := HELP_EX_TEMPLATE[HELP_EX_FIRST[ALang] + AIndex];',
          'end;',
          '',
          'function SpxHelpExampleOf(const AHref: string): Integer;',
          'var i, n: Integer; digits: string;',
          'begin',
          '  Result := -1;',
          "  if Copy(AHref, 1, 3) <> 'ex:' then Exit;",
          '  digits := Copy(AHref, 4, MaxInt);',
          "  if (digits = '') or (Length(digits) > 6) then Exit;",
          '  { Added up here rather than through StrToIntDef, so this unit needs no uses clause',
          '    at all -- it is a table of constants and nothing else, and it stays that way. }',
          '  n := 0;',
          '  for i := 1 to Length(digits) do',
          '  begin',
          "    if (digits[i] < '0') or (digits[i] > '9') then Exit;",
          "    n := n * 10 + (Ord(digits[i]) - Ord('0'));",
          '  end;',
          '  Result := n;',
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
