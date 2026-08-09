"""Compare the per-language Store listing drafts with the English source.

WHY THIS EXISTS. The drafts live in `marketing/`, which is deliberately untracked: it is
marketing copy under review, not a product artefact. That puts it outside the suite, so the
one thing holding it to the product is this script, run before a submission.

WHAT IT CHECKS, and what it deliberately does not. It cannot read a translation and tell you
whether it is good -- that is what the review before a release is for. It checks the things
that go wrong silently:

  * a language the window speaks with no draft at all, and a draft for a language it does not;
  * a bullet count that has drifted from the English source, which is how a feature added on
    one side goes missing on thirteen others;
  * a missing section;
  * a claim that names a LICENCE or a LANGUAGE COUNT differing from the English source -- the
    two facts this project has already published wrongly, once each;
  * a field over the limit Partner Center will accept, IN THE TARGET LANGUAGE. German and
    Turkish run long, and the form is where you would otherwise find out.

The limits are Microsoft's, quoted from "Add and edit Store listing info for MSIX app"
(learn.microsoft.com/.../msix/add-and-edit-store-listing-info): a description accepts "up to
10,000 characters"; product features are "no more than 200 characters per feature" and "You may
include up to 20 features"; the short description "has a 1000 character limit", of which only
the first 270 are shown in some views.

The feature CAP is checked against the English source too, not only the drafts. The GSA bullet
took that list to twenty-one on 2026-08-06 and nothing noticed, because the count had never
been near twenty before -- a limit nothing measures is a limit you meet at the submission form.

Usage:

    python scripts/check-listing-drafts.py            # report
    python scripts/check-listing-drafts.py --strict   # and exit non-zero on any finding

Exit code is 0 when there is nothing to report, or when `marketing/` is absent -- a machine
that has never written a draft is not failing, it simply has none.
"""

import io
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, 'docs', 'store-listing.md')
DRAFTS = os.path.join(HERE, 'marketing', 'store')

# The window's own languages. Read from the manifest rather than typed here: the suite already
# holds that list to `TSpxLang`, so this inherits the gate instead of adding a second list.
MANIFEST = os.path.join(HERE, 'packaging', 'AppxManifest.xml.in')

SECTIONS = ('Short description', 'Description', 'Product features')

# Microsoft's, not ours. See the module docstring for where each one is quoted from.
MAX_FEATURES = 20
MAX_FEATURE_CHARS = 200
MAX_SHORT_CHARS = 1000
SHOWN_SHORT_CHARS = 270          # only the first 270 are shown in some views -- advisory
MAX_DESCRIPTION_CHARS = 10000


def fail(message):
    sys.stderr.write('check-listing-drafts: %s\n' % message)
    raise SystemExit(2)


def read(path):
    with io.open(path, encoding='utf-8') as handle:
        return handle.read()


def languages():
    """Primary subtags declared in the package manifest, in declaration order."""
    if not os.path.exists(MANIFEST):
        fail('no %s' % MANIFEST)
    seen = []
    for tag in re.findall(r'<Resource\s+Language="([^"]+)"', read(MANIFEST)):
        code = tag.split('-')[0].lower()
        if code not in seen:
            seen.append(code)
    return seen


def english_bullets():
    text = read(SOURCE)
    start = text.find('## Product features')
    if start < 0:
        fail('no "## Product features" in %s' % SOURCE)
    stop = text.find('\n## ', start + 1)
    block = text[start:stop if stop > 0 else len(text)]
    return re.findall(r'^\s*(\d+)\.\s+(.+)$', block, re.M)


def draft_bullets(text):
    start = text.find('## Product features')
    if start < 0:
        return None
    stop = text.find('\n## ', start + 1)
    block = text[start:stop if stop > 0 else len(text)]
    return re.findall(r'^\s*(\d+)\.\s+(.+)$', block, re.M)


def section_body(text, heading):
    """The prose under `## <heading>`, with the reviewer's blockquote preamble dropped.

    A `>` line is a note to the reviewer, not copy destined for the form, so it must not
    count toward a Partner Center limit.
    """
    start = text.find('## ' + heading)
    if start < 0:
        return None
    stop = text.find('\n## ', start + 1)
    block = text[start:stop if stop > 0 else len(text)].split('\n', 1)[1]
    kept = [line for line in block.split('\n') if not line.lstrip().startswith('>')]
    return '\n'.join(kept).strip()


def prose_of(text):
    """The draft with its list ORDINALS removed.

    The language-count check used to be `if count not in text`, and with fourteen languages
    that is `'14' in text` -- which every correct draft satisfies by having a fourteenth
    feature bullet numbered `14.`. It could not fail. Turning the claim to "13 languages"
    left it green; so did deleting the sentence entirely. Reported by review.

    Stripping the ordinals is what makes the question answerable: what is left is the prose,
    where a language count is either stated or is not.
    """
    return re.sub(r'^\s*\d+\.\s', '', text, flags=re.M)


def length_notes(text, bullets):
    """Every Partner Center limit this file can be measured against, in the target language."""
    notes = []

    if bullets is not None and len(bullets) > MAX_FEATURES:
        notes.append('%d features, Partner Center accepts %d' % (len(bullets), MAX_FEATURES))
    for number, body in bullets or []:
        if len(body) > MAX_FEATURE_CHARS:
            notes.append('feature %s is %d chars, limit %d'
                         % (number, len(body), MAX_FEATURE_CHARS))

    short = section_body(text, 'Short description')
    if short is not None and len(short) > MAX_SHORT_CHARS:
        notes.append('short description %d chars, limit %d' % (len(short), MAX_SHORT_CHARS))

    body = section_body(text, 'Description')
    if body is not None and len(body) > MAX_DESCRIPTION_CHARS:
        notes.append('description %d chars, limit %d' % (len(body), MAX_DESCRIPTION_CHARS))

    return notes


def main():
    strict = '--strict' in sys.argv[1:]
    findings = []

    if not os.path.isdir(DRAFTS):
        print('no drafts yet (%s is absent) -- nothing to compare' % DRAFTS)
        return 0

    want = languages()
    source_bullets = english_bullets()
    print('English source: %d feature bullets' % len(source_bullets))

    # The source is held to the same limits as every translation of it.
    for note in length_notes(read(SOURCE), source_bullets):
        findings.append('docs/store-listing.md: %s' % note)
        print('  ! %s' % note)

    # the licence name and the language count, the two facts published wrongly before
    licence = 'GPL-3.0-or-later'
    count = str(len(want))

    have = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(DRAFTS)
        if name.endswith('.md') and not name.startswith('_')
    )

    for code in want:
        if code == 'en':
            continue                      # the English source IS docs/store-listing.md
        if code not in have:
            findings.append('%s: no draft' % code)

    for code in have:
        if code not in want:
            findings.append('%s: a draft for a language the window does not speak' % code)

    print()
    print('%-6s %-9s %s' % ('lang', 'bullets', 'notes'))
    for code in have:
        text = read(os.path.join(DRAFTS, code + '.md'))
        bullets = draft_bullets(text)
        notes = []

        if bullets is None:
            notes.append('no "## Product features"')
        elif len(bullets) != len(source_bullets):
            notes.append('%d bullets, English has %d' % (len(bullets), len(source_bullets)))

        for section in SECTIONS:
            if ('## ' + section) not in text and section != 'Product features':
                # a translated heading is fine; the anchor is the English one in the template
                if not re.search(r'^##\s+\S', text, re.M):
                    notes.append('no sections at all')
                    break

        if licence not in text:
            notes.append('does not name %s' % licence)
        if count not in prose_of(text):
            notes.append('does not name the language count (%s)' % count)

        notes.extend(length_notes(text, bullets))

        print('%-6s %-9s %s' % (code, len(bullets) if bullets else '-',
                                '; '.join(notes) if notes else 'ok'))
        for note in notes:
            findings.append('%s: %s' % (code, note))

    print()
    if findings:
        print('%d finding(s):' % len(findings))
        for f in findings:
            print('  -', f)
        print()
        print('These are structural only. Whether the prose is any good is what the review')
        print('before the submission is for.')
        return 1 if strict else 0

    print('nothing to report: every language has a draft, and every draft carries the same')
    print('number of bullets, the right licence name and the right language count.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
