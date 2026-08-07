#!/usr/bin/env python3
"""Convert the help documents into the Pascal unit that ships inside the .exe.

THE MARKDOWN STAYS THE SINGLE SOURCE. `TestHelpExamples` reads those same files and runs every
example through the real engine, so what the reader sees in the window cannot diverge from what
the suite verified -- that is the whole reason this is generated rather than written by hand.

THE TEMPLATE OF EVERY EXAMPLE IS A LINK, and the output beside it is not: you click the input
and get the output, which is what the arrow already says. Measured before it was built -- an
inline anchor is a link to IPro, HotURL comes back as written, and the output half of the same
line reports nothing.

AN EXAMPLE BLOCK IS NOT A <pre>, though it looks like one -- see `preformatted` below for the
measurement that cost: inside a PRE, IPro shows `&lt;` as those four characters.

AN EXAMPLE IN A ` ```spx-good ` FENCE IS A CLAIM THAT NOTHING IS WRONG WITH IT, and the suite
holds it to that: not one diagnostic row. The chapter about what correct looks like had five
examples and no articles, so the causation check -- which works per article -- never reached
them, and its own sentence about being parsed without a remark was verified by nothing. The word
goes in the fence's info string because that vocabulary is already validated here and an unknown
one already fails; no new markdown was needed.

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
LANGS = ['en', 'ru', 'de', 'fr', 'es', 'it']

# Above this a page starts costing what ADR 0004's curve says it does. Nothing is near it today
# (the largest is about 9 KB); it is here so that growth trips a build rather than a user.
PAGE_LIMIT = 24 * 1024

# The document KINDS, in the order a reader meets them, each with the slugs naming its
# sections. The guide goes first and the diagnostic reference below it: the contents tree should
# read like a manual, not like an implementation panel. A slug names the same section in every
# language -- that is what lets the viewer keep your place when the interface language changes --
# so the list is the contract and the script refuses a document with more sections than names.
# The product first: a reader who opens the help wants to know what this program is before
# being told how the language works, and long before being told how to read an example. That
# ordering was a reader's complaint, 2026-08-06.
DOCS = ['studio', 'syntax', 'diagnostics']

DOC_SLUGS = {
    'studio': [
        'studio', 'panes', 'panels', 'groups', 'settings', 'gsa',
    ],
    'diagnostics': [
        'about', 'reading', 'brackets', 'definitions', 'variables', 'includes',
        'plurals', 'permutations', 'notes', 'abbreviations', 'correct', 'faq',
    ],
    'syntax': [
        'language', 'reading-syntax', 'choices', 'shuffles', 'macros', 'conditions',
        'counting', 'fragments', 'remarks', 'tidying', 'silences', 'next',
    ],
}


# The document being converted, so an error names the file it is in. A module-level cell in
# the style this script already uses for ANY_EXAMPLES and seen_fixture -- it is single-pass and
# single-threaded, and threading a path through thirty raise sites would say less.
CURRENT = ['docs/help/en/diagnostics.md']


class Bad(SystemExit):
    def __init__(self, lang, line_no, message):
        SystemExit.__init__(self, '%s:%d: %s' % (CURRENT[0], line_no, message))


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


def preformatted(lines):
    """An example block, laid out like a <pre> and NOT one.

    IPro DOES NOT DECODE ENTITIES INSIDE <pre>. Measured, and then found in its source:
    `iphtmlparser.pas:1965-1968` puts the token into `ANSIText` when it is inside a PRE and into
    `EscapedText` when it is not -- and `SetAnsiText` runs `AnsiToEscape` over it, so `&lt;`
    becomes `&amp;lt;` and the one decode that follows gives back a visible `&lt;`. The reader
    saw `[&lt;minsize=2;sep=", "&gt;a|b|c]` where the document says `[<minsize=2;sep=", ">a|b|c]`.

    Writing the character raw instead is not the way out: the tokenizer takes `<` followed by a
    letter as a tag and eats it (`iphtmlparser.pas:695-712`), which is the measurement the escaping
    was introduced for in the first place. Inside a PRE both forms are wrong -- so the block stops
    being a PRE.

    <small><tt> in a paragraph, spaces as &nbsp; and breaks as <br>, gives the same monospace
    and the same preserved alignment, decodes entities, and keeps the anchor a link. Measured side
    by side against the <pre> it replaces.

    <small> IS NOT DECORATION. A PRE sets the fixed typeface AND `FontSize := FontSize - 2`
    (`iphtmlnodes.pas:2593`); <tt> sets only the typeface, so every example came out at 12 pt
    instead of 10 -- a quarter wider. The widest block sets the layout width for the WHOLE page,
    so the headings and the prose were clipped with it: the Russian plurals page needs 942 px
    where it used to need 760, and the ADR's sentence about the panel reaching 900 px stopped
    being true. hfsSMALL applies the same subtraction (`:3912-3915`). Found by review, measured
    against the old rendering at the same width.

    The spaces INSIDE a tag must survive as spaces -- `<a href="ex:28">` is not text -- so this
    walks the line rather than calling replace() on it.

    A RUN OF SPACES KEEPS ONE ORDINARY SPACE AT ITS END, and that is the difference between an
    example a narrow panel can show and one it cuts off. With every space non-breaking the block
    is a single unbreakable run, and IPro lays the PAGE out at that run's width -- so at a 503 px
    panel the PROSE beside the example was clipped mid-sentence, because the widest example
    demanded 95 characters. The width is unchanged (k-1 non-breaking and one ordinary is still
    k); what changes is that the line may break where the author put a space. A LEADING run stays
    wholly non-breaking: there is nothing before it to break after, and an ordinary space at the
    start of a line is dropped by the layout.
    """
    out = []
    # FLATTENED FIRST. A line may itself carry a newline -- fence_line puts a trailing note on
    # its own line that way, and the arrow puts the output on one -- and inside a PRE that LF was
    # a break. In a paragraph it is not: TrimFormatting turns it into a space, so the output
    # would join the template.
    for line in '\n'.join(lines).split('\n'):
        buf, in_tag, run, seen = [], False, 0, False
        for ch in line:
            if ch == ' ' and not in_tag:
                run += 1
                continue
            if run:
                buf.append('&nbsp;' * run if not seen else '&nbsp;' * (run - 1) + ' ')
                run = 0
            if ch == '<':
                in_tag = True
            elif ch == '>':
                in_tag = False
            elif not in_tag:
                seen = True
            buf.append(ch)
        # Trailing spaces have nothing after them to break before, so they stay as they were.
        if run:
            buf.append('&nbsp;' * run)
        out.append(''.join(buf))
    return '<p><small><tt>' + '<br>'.join(out) + '</tt></small></p>'


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


def convert(lang, path, slugs, ex_base):
    """One document into pages. Each page: slug, title, html lines, anchors.

    `ex_base` is where this document's examples start in the LANGUAGE's numbering: `ex:N` in a
    page is looked up by the window against one flat table per language, so a second document's
    links have to continue the first's rather than start again at zero.
    """
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
        if n >= len(slugs):
            raise Bad(lang, line_no,
                      'more sections than DOC_SLUGS names for this document -- add one')
        pages.append({'slug': slugs[n], 'title': title, 'html': [], 'anchors': []})
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
                if fence not in ('', 'spx-fixture', 'spx-good'):
                    raise Bad(lang, n, 'an unknown fence info string %r' % fence)
                fence_body = []
                del acc[:]
                fence_start = n
            else:
                # A CLOSING fence carries no info string, and saying otherwise is refused here
                # rather than ignored. Both parsers read only the opening one, so a `spx-good`
                # written on the closing line reads as a marked block and is checked as an
                # ordinary one -- measured by review: the suite stayed green with the word
                # visibly in the document. The suite's count catches it now; this names it.
                if stripped[3:].strip():
                    raise Bad(lang, n, 'an info string on a closing fence (%r) -- it belongs on '
                                       'the opening one, where both parsers read it'
                                       % stripped[3:].strip())
                if fence == 'spx-fixture':
                    if seen_fixture[0]:
                        raise Bad(lang, fence_start, 'a second conditions block')
                    seen_fixture[0] = True
                    read_fixture(lang, fence_start, [x for x in fence_body], fixture)
                page['html'].append(preformatted(fence_body))
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
                    ex = ex_base + len(examples) - 1
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
                    # THE OUTPUT GOES ON ITS OWN LINE, and the spaces that aligned the arrow into
                    # a column go nowhere. That column is what a fixed-width file wants; on a
                    # panel it made every example as wide as BOTH its sides at once -- 95
                    # characters at the worst, against 58 for the widest line this now emits
                    # (`→  ｛plural %n%: ｛товар|штука｝|товара｝   скобки внутри форм`, and the 95
                    # was that same line with its template in front of it). The widest example
                    # sets the width of the whole page. fence_line already moves a
                    # trailing note down for this reason and says so; the arrow is the larger
                    # half of the same problem. Still ONE entry per source line, so the anchors
                    # counted backwards above still land on the lines they mean.
                    if here:
                        fence_body.append(link(ex, esc(left.rstrip())) + '\n' +
                                          ARROW + fence_note(right))
                    else:
                        fence_body.append(ARROW + fence_note(right))
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


# How many examples the LANGUAGE has so far -- the bound every `ex:N` in a page must be under.
# Per language and not per document, because a second document continues the first's numbering.
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
    # `nbsp` joins the three because `preformatted` writes it for every space in an example
    # block: a paragraph collapses runs of spaces and the arrow columns are made of them.
    for m in re.finditer(r'&([^;]*);?', html):
        if m.group(1) not in ('amp', 'lt', 'gt', 'nbsp'):
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


# The unit's function bodies. Constants only above them, no uses clause at all: this unit is a
# table and stays one, so nothing it is compiled into can pull a dependency through it.
ACCESSORS = """function SpxHelpLangCode(ALang: Integer): string;
begin
  if (ALang < 0) or (ALang > High(HELP_LANG)) then Exit('');
  Result := HELP_LANG[ALang];
end;

function SpxHelpLangIndex(const ACode: string): Integer;
var i: Integer;
begin
  for i := Low(HELP_LANG) to High(HELP_LANG) do
    if HELP_LANG[i] = ACode then Exit(i);
  Result := -1;
end;

function SpxHelpKindSlug(AKind: Integer): string;
begin
  if (AKind < 0) or (AKind > High(HELP_KIND_SLUG)) then Exit('');
  Result := HELP_KIND_SLUG[AKind];
end;

function SpxHelpDocCount(ALang: Integer): Integer;
begin
  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then Exit(0);
  Result := HELP_DOC_LAST[ALang] - HELP_DOC_FIRST[ALang] + 1;
end;

{ The one place a (language, document) pair becomes a row. -1 when either is out of range, so
  every caller answers with an empty string rather than a range error. }
function DocAt(ALang, ADoc: Integer): Integer;
begin
  if (ADoc < 0) or (ADoc >= SpxHelpDocCount(ALang)) then Exit(-1);
  Result := HELP_DOC_FIRST[ALang] + ADoc;
end;

function SpxHelpDocKind(ALang, ADoc: Integer): Integer;
var i: Integer;
begin
  i := DocAt(ALang, ADoc);
  if i < 0 then Exit(-1);
  Result := HELP_DOC_KIND[i];
end;

function SpxHelpSourcePath(ALang, ADoc: Integer): string;
var i: Integer;
begin
  i := DocAt(ALang, ADoc);
  if i < 0 then Exit('');
  Result := HELP_DOC_PATH[i];
end;

function SpxHelpSourceDigest(ALang, ADoc: Integer): string;
var i: Integer;
begin
  i := DocAt(ALang, ADoc);
  if i < 0 then Exit('');
  Result := HELP_DOC_DIGEST[i];
end;

function SpxHelpPageCount(ALang: Integer): Integer;
begin
  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then Exit(0);
  Result := HELP_PAGE_LAST[ALang] - HELP_PAGE_FIRST[ALang] + 1;
end;

{ The same rule as DocAt, for pages. }
function PageAt(ALang, APage: Integer): Integer;
begin
  if (APage < 0) or (APage >= SpxHelpPageCount(ALang)) then Exit(-1);
  Result := HELP_PAGE_FIRST[ALang] + APage;
end;

function SpxHelpPageSlug(ALang, APage: Integer): string;
var i: Integer;
begin
  i := PageAt(ALang, APage);
  if i < 0 then Exit('');
  Result := HELP_SLUG[i];
end;

function SpxHelpPageIndex(ALang: Integer; const ASlug: string): Integer;
var i: Integer;
begin
  for i := 0 to SpxHelpPageCount(ALang) - 1 do
    if HELP_SLUG[HELP_PAGE_FIRST[ALang] + i] = ASlug then Exit(i);
  Result := -1;
end;

function SpxHelpPageTitle(ALang, APage: Integer): string;
var i: Integer;
begin
  i := PageAt(ALang, APage);
  if i < 0 then Exit('');
  Result := HELP_TITLE[i];
end;

function SpxHelpPageDoc(ALang, APage: Integer): Integer;
var i: Integer;
begin
  i := PageAt(ALang, APage);
  if i < 0 then Exit(-1);
  Result := HELP_PAGE_DOC[i];
end;

function SpxHelpPageHtml(ALang, APage: Integer): string;
var i, n: Integer;
begin
  Result := '';
  i := PageAt(ALang, APage);
  if i < 0 then Exit;
  for n := HELP_FIRST[i] to HELP_LAST[i] do
  begin
    if n > HELP_FIRST[i] then Result := Result + #10;
    Result := Result + HELP_LINE[n];
  end;
end;

function SpxHelpAnchorCount(ALang: Integer): Integer;
begin
  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then Exit(0);
  Result := HELP_ANCHOR_LAST[ALang] - HELP_ANCHOR_FIRST[ALang] + 1;
end;

function AnchorAt(ALang, AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= SpxHelpAnchorCount(ALang)) then Exit(-1);
  Result := HELP_ANCHOR_FIRST[ALang] + AIndex;
end;

function SpxHelpAnchorPage(ALang, AIndex: Integer): Integer;
var i: Integer;
begin
  i := AnchorAt(ALang, AIndex);
  if i < 0 then Exit(-1);
  Result := HELP_ANCHOR_PAGE[i];
end;

function SpxHelpAnchorId(ALang, AIndex: Integer): string;
var i: Integer;
begin
  i := AnchorAt(ALang, AIndex);
  if i < 0 then Exit('');
  Result := HELP_ANCHOR_ID[i];
end;

function SpxHelpAnchorTitle(ALang, AIndex: Integer): string;
var i: Integer;
begin
  i := AnchorAt(ALang, AIndex);
  if i < 0 then Exit('');
  Result := HELP_ANCHOR_TITLE[i];
end;

function SpxHelpAnchorIsCode(ALang, AIndex: Integer): Boolean;
var i: Integer;
begin
  i := AnchorAt(ALang, AIndex);
  Result := (i >= 0) and HELP_ANCHOR_CODE[i];
end;

function SpxHelpLocale(ALang, ADoc: Integer): string;
var i: Integer;
begin
  i := DocAt(ALang, ADoc);
  if i < 0 then Exit('');
  Result := HELP_DOC_LOCALE[i];
end;

function SpxHelpSeed(ALang, ADoc: Integer): LongWord;
var i: Integer;
begin
  i := DocAt(ALang, ADoc);
  if i < 0 then Exit(1);
  Result := HELP_DOC_SEED[i];
end;

function SpxHelpIncludeCount(ALang, ADoc: Integer): Integer;
var i: Integer;
begin
  i := DocAt(ALang, ADoc);
  if i < 0 then Exit(0);
  Result := HELP_INC_LAST[i] - HELP_INC_FIRST[i] + 1;
end;

function IncAt(ALang, ADoc, AIndex: Integer): Integer;
var i: Integer;
begin
  i := DocAt(ALang, ADoc);
  if (i < 0) or (AIndex < 0) or (AIndex >= SpxHelpIncludeCount(ALang, ADoc)) then Exit(-1);
  Result := HELP_INC_FIRST[i] + AIndex;
end;

function SpxHelpIncludeName(ALang, ADoc, AIndex: Integer): string;
var i: Integer;
begin
  i := IncAt(ALang, ADoc, AIndex);
  if i < 0 then Exit('');
  Result := HELP_INC_NAME[i];
end;

function SpxHelpIncludeText(ALang, ADoc, AIndex: Integer): string;
var i: Integer;
begin
  i := IncAt(ALang, ADoc, AIndex);
  if i < 0 then Exit('');
  Result := HELP_INC_TEXT[i];
end;

function SpxHelpExampleCount(ALang: Integer): Integer;
begin
  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then Exit(0);
  Result := HELP_EX_LAST[ALang] - HELP_EX_FIRST[ALang] + 1;
end;

function SpxHelpExample(ALang, AIndex: Integer; out ATemplate: string): Boolean;
begin
  ATemplate := '';
  Result := (AIndex >= 0) and (AIndex < SpxHelpExampleCount(ALang));
  if Result then ATemplate := HELP_EX_TEMPLATE[HELP_EX_FIRST[ALang] + AIndex];
end;

function SpxHelpExampleDoc(ALang, AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= SpxHelpExampleCount(ALang)) then Exit(-1);
  Result := HELP_EX_DOC[HELP_EX_FIRST[ALang] + AIndex];
end;

function SpxHelpExampleOf(const AHref: string): Integer;
var i, n: Integer; digits: string;
begin
  Result := -1;
  if Copy(AHref, 1, 3) <> 'ex:' then Exit;
  digits := Copy(AHref, 4, MaxInt);
  if (digits = '') or (Length(digits) > 6) then Exit;
  { Added up here rather than through StrToIntDef, so this unit needs no uses clause
    at all -- it is a table of constants and nothing else, and it stays that way. }
  n := 0;
  for i := 1 to Length(digits) do
  begin
    if (digits[i] < '0') or (digits[i] > '9') then Exit;
    n := n * 10 + (Ord(digits[i]) - Ord('0'));
  end;
  Result := n;
end;

end.
""".split('\n')


def main():
    # Per language, the documents it has -- in DOCS order. A language must have EVERY document:
    # a slug names the same section in every language, and the viewer keeps the reader's place
    # across a language switch by that name. Lagging by a whole document is a thing this shape
    # could grow (the pages are already a per-language span) and deliberately does not have yet:
    # nothing needs it, and an invariant is worth more than a capability nobody asked for.
    langs = []
    for lang in LANGS:
        entries = []
        for kind in DOCS:
            path = os.path.join(HERE, 'docs', 'help', lang, kind + '.md')
            if not os.path.exists(path):
                raise SystemExit('missing help document: %s' % path)
            CURRENT[0] = 'docs/help/%s/%s.md' % (lang, kind)
            # The examples of a language are ONE table, so this document's `ex:N` continue where
            # the previous document's stopped.
            ex_base = sum(len(e['examples']) for e in entries)
            pages, digest, fixture, examples = convert(lang, path, DOC_SLUGS[kind], ex_base)
            if not seen_any(fixture):
                raise SystemExit('%s: no spx-fixture block -- the pane could not reproduce the '
                                 'outputs it prints' % CURRENT[0])
            if fixture['locale'] != lang:
                raise SystemExit('%s declares locale %r' % (CURRENT[0], fixture['locale']))
            ANY_EXAMPLES[0] = ex_base + len(examples)
            for page in pages:
                refuse_bad_html(lang, page)
            entries.append({'kind': kind, 'path': CURRENT[0], 'digest': digest,
                            'pages': pages, 'fixture': fixture, 'examples': examples})
        langs.append({'lang': lang, 'docs': entries})

    # THE DOCUMENTS MUST RUN PARALLEL, per kind, across the languages -- see above for why. The
    # comparison is on the CODES, which are the part that cannot be a matter of taste: section N
    # of a kind carries the same articles in every language.
    base = langs[0]
    for other in langs[1:]:
        for d, (a_doc, b_doc) in enumerate(zip(base['docs'], other['docs'])):
            if len(a_doc['pages']) != len(b_doc['pages']):
                raise SystemExit('%s has %d sections and %s has %d -- they must run parallel'
                                 % (b_doc['path'], len(b_doc['pages']),
                                    a_doc['path'], len(a_doc['pages'])))
            for i, (a, b) in enumerate(zip(a_doc['pages'], b_doc['pages'])):
                ca = sorted(x['id'] for x in a['anchors'] if x['code'])
                cb = sorted(x['id'] for x in b['anchors'] if x['code'])
                if ca != cb:
                    raise SystemExit('section %d (%s) holds %s in %s but %s in %s'
                                     % (i, a['slug'], ca, a_doc['path'], cb, b_doc['path']))
                # AND THE PROSE HEADINGS MUST LINE UP TOO, because their ids are POSITIONAL --
                # `slug-0`, `slug-1`, counted over every ### on the page. A section with three
                # of them in one language and two in another gives the same id to different
                # headings, and SpxHelpRelocate then lands a reader who switches language on
                # the wrong paragraph -- silently, since the id resolves. It has never happened
                # with two languages that were written together; with twelve translated later
                # it is a matter of time, and the check costs one comparison.
                na = [x['id'] for x in a['anchors'] if not x['code']]
                nb = [x['id'] for x in b['anchors'] if not x['code']]
                if na != nb:
                    raise SystemExit('section %d (%s) has prose headings %s in %s but %s in %s '
                                     '-- their ids are positional, so they must match'
                                     % (i, a['slug'], na, a_doc['path'], nb, b_doc['path']))

    # ── flat tables ────────────────────────────────────────────────────────────────────────
    # A SLUG IS LOOKED UP ACROSS THE WHOLE LANGUAGE, because that is what a page number is to
    # the window -- so two documents claiming `about` would make the second one's page
    # unreachable, and every route that resolves a slug (a language switch, F1 on a construct,
    # the contents tree) would land in the first. The suite catches the symptom; this names the
    # cause, which is the generator's job and where its other eight refusals live.
    all_slugs = [s for k in DOCS for s in DOC_SLUGS[k]]
    dupes = sorted({s for s in all_slugs if all_slugs.count(s) > 1})
    if dupes:
        raise SystemExit('two documents share the page slug(s) %s -- a slug is looked up across '
                         'the whole language, so the second would be unreachable' % dupes)

    kinds = list(DOCS)
    docs_flat = []          # one row per (language, document)
    doc_span = []           # (first, last) into docs_flat, per language
    incs, inc_span = [], []  # the fragments of each document
    flat_pages = []         # (slug, title, doc_in_lang, first_line, last_line)
    page_span = []          # (first, last) into flat_pages, per language
    flat = []               # every HTML line of every page
    exs, ex_span, ex_doc = [], [], []
    anchors, anchor_span = [], []

    for entry in langs:
        first_doc, first_page, first_ex, first_anchor = (
            len(docs_flat), len(flat_pages), len(exs), len(anchors))
        for d, doc in enumerate(entry['docs']):
            first_inc = len(incs)
            incs.extend(doc['fixture']['includes'])
            inc_span.append((first_inc, len(incs) - 1))
            docs_flat.append({'kind': kinds.index(doc['kind']), 'path': doc['path'],
                              'digest': doc['digest'],
                              'locale': doc['fixture']['locale'],
                              'seed': doc['fixture']['seed']})
            for page in doc['pages']:
                flat_pages.append({'slug': page['slug'], 'title': page['title'], 'doc': d,
                                   'first': len(flat), 'last': len(flat) + len(page['html']) - 1})
                flat.extend(page['html'])
            exs.extend(doc['examples'])
            ex_doc.extend([d] * len(doc['examples']))
        doc_span.append((first_doc, len(docs_flat) - 1))
        page_span.append((first_page, len(flat_pages) - 1))
        ex_span.append((first_ex, len(exs) - 1))
        # Anchors carry a page number IN THE LANGUAGE, so they are numbered after the pages are.
        p = 0
        for doc in entry['docs']:
            for page in doc['pages']:
                for a in page['anchors']:
                    anchors.append((p, a['id'], a['title'], a['code']))
                p += 1
        anchor_span.append((first_anchor, len(anchors) - 1))

    def arr(name, kind, values, per_line=None):
        """One Pascal constant array -- and one unreachable element where it would be empty.

        Pascal has no empty array constant (`array[0..-1] of string = ()` is `Illegal
        expression`) and the accessors below name every array unconditionally, so a comment in
        its place turns a range error into six `Identifier not found`. Found by review, which
        registered a second document with no fragments and no `###` headings -- the shape a
        language reference has -- and got a unit that would not compile.

        The element is never read: every accessor range-checks against a count derived from the
        spans, and an empty span answers zero.
        """
        if not values:
            zero = {'string': "''", 'Integer': '0', 'LongWord': '0', 'Boolean': 'False'}[kind]
            return ['  { %s: nothing to carry in this build. The one element exists because'
                    ' Pascal has' % name,
                    '    no empty array constant and the accessors name it; the count is taken'
                    ' from the spans,',
                    '    which are empty, so nothing ever reads it. }',
                    '  %s: array[0..0] of %s = (%s);' % (name, kind, zero)]
        out = ['  %s: array[0..%d] of %s = (' % (name, len(values) - 1, kind)]
        if per_line:
            for i, v in enumerate(values):
                out.append('    %s%s' % (v, ',' if i < len(values) - 1 else ''))
        else:
            out.append('    ' + ', '.join(values))
        out.append('  );')
        return out

    u = ['(*',
         ' * SpxHelpText -- the help documents, as HTML, one page per section.',
         ' *',
         ' * GENERATED by scripts/make-help.py from docs/help/<lang>/<document>.md. Do not edit:',
         ' * change the markdown and run the script again. The markdown is the single source --',
         ' * TestHelpExamples runs every example in it through the real engine, so what ships here',
         ' * cannot diverge from what was verified. The suite compares SpxHelpSourceDigest against',
         ' * the file on disk, which is what makes "edited the markdown, forgot to regenerate" a',
         ' * failing build rather than a stale window.',
         ' *',
         ' * A PAGE PER SECTION. TIpHtmlPanel\'s layout is quadratic -- measured 156 ms on 12.7 KB,',
         ' * and 12.9 s on 172 KB (ADR 0004). Whole documents would be seconds.',
         ' *',
         ' * A LANGUAGE HAS DOCUMENTS AND A DOCUMENT HAS PAGES, and the two dimensions are kept',
         ' * apart because the CONDITIONS are the document\'s: each declares its own locale, seed',
         ' * and fragments in its own spx-fixture block, and a click has to render under the ones',
         ' * belonging to the page it was clicked on. Pages and examples are numbered per LANGUAGE,',
         ' * flat across its documents, because that is what a page index and an `ex:N` mean to the',
         ' * window.',
         ' *)',
         'unit SpxHelpText;',
         '',
         '{$mode objfpc}{$H+}',
         '',
         'interface',
         '',
         'const',
         '  SPX_HELP_LANG_COUNT = %d;' % len(LANGS),
         '  { The document KINDS this build knows, whether or not a language carries them. }',
         '  SPX_HELP_KIND_COUNT = %d;' % len(kinds),
         '',
         '{ The help languages, by the engine\'s own code. Not the interface\'s fourteen: a',
         '  language with no document here falls back, and SpxHelpNav owns that rule. }',
         'function SpxHelpLangCode(ALang: Integer): string;',
         'function SpxHelpLangIndex(const ACode: string): Integer;   { -1 when absent }',
         '',
         '{ A KIND is `diagnostics` or `syntax`: what the document is about, the same in every',
         '  language. A DOCUMENT is one language\'s copy of a kind, and carries the conditions its',
         '  examples were measured under. }',
         'function SpxHelpKindSlug(AKind: Integer): string;',
         'function SpxHelpDocCount(ALang: Integer): Integer;',
         'function SpxHelpDocKind(ALang, ADoc: Integer): Integer;   { -1 when absent }',
         '',
         '{ Where the document came from, and an FNV-1a of its bytes. The suite reads the file and',
         '  compares -- an edit without a regeneration fails the build. }',
         'function SpxHelpSourcePath(ALang, ADoc: Integer): string;',
         'function SpxHelpSourceDigest(ALang, ADoc: Integer): string;',
         '',
         '{ A page. Numbered per LANGUAGE, flat across its documents; the slug is the same string',
         '  in every language and the title is that language\'s. SpxHelpPageDoc says which of the',
         '  language\'s documents the page came from, which is how its conditions are found. }',
         'function SpxHelpPageCount(ALang: Integer): Integer;',
         'function SpxHelpPageSlug(ALang, APage: Integer): string;',
         'function SpxHelpPageIndex(ALang: Integer; const ASlug: string): Integer;  { -1 absent }',
         'function SpxHelpPageTitle(ALang, APage: Integer): string;',
         'function SpxHelpPageDoc(ALang, APage: Integer): Integer;',
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
         '{ THE CONDITIONS THE OUTPUTS WERE MEASURED UNDER, from the DOCUMENT\'s own spx-fixture',
         '  block. A click rendered under anything else would disagree with the arrow printed',
         '  beside it, which is the one thing this document may never do. }',
         'function SpxHelpLocale(ALang, ADoc: Integer): string;',
         'function SpxHelpSeed(ALang, ADoc: Integer): LongWord;',
         'function SpxHelpIncludeCount(ALang, ADoc: Integer): Integer;',
         'function SpxHelpIncludeName(ALang, ADoc, AIndex: Integer): string;',
         'function SpxHelpIncludeText(ALang, ADoc, AIndex: Integer): string;',
         '',
         '{ THE TEMPLATE BEHIND A LINK. Every example`s template is an `ex:N` anchor in the page,',
         '  and this is what N means -- stored verbatim, as the fixture rendered it, so a click',
         '  runs exactly what the suite verified. The window parses nothing: it is handed the',
         '  href and asks here. False for a number this build does not have. }',
         'function SpxHelpExampleCount(ALang: Integer): Integer;',
         'function SpxHelpExample(ALang, AIndex: Integer; out ATemplate: string): Boolean;',
         '{ Which document it belongs to, so it renders under that document\'s conditions. }',
         'function SpxHelpExampleDoc(ALang, AIndex: Integer): Integer;',
         '{ `ex:7` -> 7, or -1 for anything else. The one place the href form is known. }',
         'function SpxHelpExampleOf(const AHref: string): Integer;',
         '',
         'implementation',
         '',
         'const']

    u += arr('HELP_LANG', 'string', ["'%s'" % c for c in LANGS])
    u += arr('HELP_KIND_SLUG', 'string', ["'%s'" % k for k in kinds])
    u.append('')
    u.append('  { Each language\'s documents: a span into the tables below. }')
    u += arr('HELP_DOC_FIRST', 'Integer', [str(a) for a, _ in doc_span])
    u += arr('HELP_DOC_LAST', 'Integer', [str(b) for _, b in doc_span])
    u += arr('HELP_DOC_KIND', 'Integer', [str(d['kind']) for d in docs_flat])
    u += arr('HELP_DOC_PATH', 'string', [literal(d['path']) for d in docs_flat], True)
    u += arr('HELP_DOC_DIGEST', 'string', ["'%s'" % d['digest'] for d in docs_flat])
    u += arr('HELP_DOC_LOCALE', 'string', ["'%s'" % d['locale'] for d in docs_flat])
    u += arr('HELP_DOC_SEED', 'LongWord', [str(d['seed']) for d in docs_flat])
    u += arr('HELP_INC_FIRST', 'Integer', [str(a) for a, _ in inc_span])
    u += arr('HELP_INC_LAST', 'Integer', [str(b) for _, b in inc_span])
    u += arr('HELP_INC_NAME', 'string', [literal(e[0]) for e in incs], True)
    u += arr('HELP_INC_TEXT', 'string', [literal(e[1]) for e in incs], True)
    u.append('')
    u.append('  { Each language\'s pages: a span into the tables below. }')
    u += arr('HELP_PAGE_FIRST', 'Integer', [str(a) for a, _ in page_span])
    u += arr('HELP_PAGE_LAST', 'Integer', [str(b) for _, b in page_span])
    u += arr('HELP_SLUG', 'string', ["'%s'" % p['slug'] for p in flat_pages])
    u += arr('HELP_TITLE', 'string', [literal(p['title']) for p in flat_pages], True)
    u += arr('HELP_PAGE_DOC', 'Integer', [str(p['doc']) for p in flat_pages])
    u += arr('HELP_FIRST', 'Integer', [str(p['first']) for p in flat_pages])
    u += arr('HELP_LAST', 'Integer', [str(p['last']) for p in flat_pages])
    u.append('')
    u.append('  { Every page of every language, one element per line of HTML -- a change to the')
    u.append('    prose is then one readable hunk in a diff, which a byte array would not be. }')
    u += arr('HELP_LINE', 'string', [literal(x) for x in flat], True)
    u.append('')
    u.append('  { The templates the `ex:N` links point at, verbatim as the fixture ran them. }')
    u += arr('HELP_EX_FIRST', 'Integer', [str(a) for a, _ in ex_span])
    u += arr('HELP_EX_LAST', 'Integer', [str(b) for _, b in ex_span])
    u += arr('HELP_EX_TEMPLATE', 'string', [literal(e) for e in exs], True)
    u += arr('HELP_EX_DOC', 'Integer', [str(d) for d in ex_doc])
    u.append('')
    u.append('  { The `###` articles: page, id, title, and whether the id is a diagnostic code. }')
    u += arr('HELP_ANCHOR_FIRST', 'Integer', [str(a) for a, _ in anchor_span])
    u += arr('HELP_ANCHOR_LAST', 'Integer', [str(b) for _, b in anchor_span])
    u += arr('HELP_ANCHOR_PAGE', 'Integer', [str(a[0]) for a in anchors])
    u += arr('HELP_ANCHOR_ID', 'string', [literal(a[1]) for a in anchors], True)
    u += arr('HELP_ANCHOR_TITLE', 'string', [literal(a[2]) for a in anchors], True)
    u += arr('HELP_ANCHOR_CODE', 'Boolean', ['True' if a[3] else 'False' for a in anchors])
    u.append('')

    u += ACCESSORS
    out = os.path.join(HERE, 'gui', 'SpxHelpText.pas')
    io.open(out, 'w', encoding='utf-8', newline='').write('\n'.join(u))
    for entry in langs:
        for doc in entry['docs']:
            big = max(len('\n'.join(p['html']).encode('utf-8')) for p in doc['pages'])
            print('%-30s %2d pages, %2d articles, %2d examples, largest %d bytes'
                  % (doc['path'], len(doc['pages']),
                     sum(len(p['anchors']) for p in doc['pages']),
                     len(doc['examples']), big))
    print('%-30s %d bytes' % (os.path.relpath(out, HERE), os.path.getsize(out)))


if __name__ == '__main__':
    main()
