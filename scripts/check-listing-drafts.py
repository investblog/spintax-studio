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
    python scripts/check-listing-drafts.py --regen-sr-latn   # rewrite the Latin draft from sr.md

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

SECTIONS = ('Short description', 'Description', 'Product features',
            "What's new in this version")

# Microsoft's, not ours. See the module docstring for where each one is quoted from.
# ADDITIONAL STORE LISTING LANGUAGES -- listings the product carries for a language the PACKAGE
# does not declare. Microsoft documents the mechanism: Partner Center's "Additional Store listing
# languages" -> "Manage additional languages" adds languages "that are not included in your
# packages", so the set the storefront can show in is a SUPERSET of the set the window speaks.
#
# Until 2026-08-18 the two were the same here and this script assumed it, which is why a draft
# outside the manifest was reported as an error rather than as a second, legitimate kind of
# thing. `sr-Latn` is the first: the window is Serbian CYRILLIC (gui/lang/SpxTextsSr.pas) and the
# package declares `sr-Cyrl` accordingly, while Microsoft's own table files a bare `sr` under
# Serbian (LATIN) -- so a reader whose system is Serbian Latin meets a listing that is not in
# their script unless one is written for them.
#
# Named here rather than inferred from the folder, so a stray file is still an error: the point
# of this list is that adding one is a DECISION, and it is recorded where the limits are.
ADDITIONAL_LISTING_LANGS = ('sr-Latn',)

# A DRAFT IS NAMED BY THE STORE ROW IT IS DESTINED FOR, not by the window language it came from,
# and Serbian is the one place those differ. Microsoft files a bare `sr` under Serbian (LATIN);
# the window is Cyrillic and the package declares `sr-Cyrl`. So a file called `sr.md` holding
# Cyrillic prose is a trap with a name on it: the obvious thing to do with it is paste it into
# the `sr` slot, which is the Latin row, and that is the exact defect that cost this product a
# release on 2026-08-18. The files are `sr-Cyrl.md` and `sr-Latn.md`; neither can be filed wrong
# by reading its name. This map is what lets the manifest's `sr` still find its draft.
DRAFT_FILE = {'sr': 'sr-Cyrl'}

# The bullet the What's-new field uses. Microsoft asks for no bullets in PRODUCT FEATURES,
# which it renders as a list itself; this field is free text and keeps what it is given.
BULLET = '•'

MAX_FEATURES = 20
MAX_FEATURE_CHARS = 200
MAX_SHORT_CHARS = 1000
SHOWN_SHORT_CHARS = 270          # only the first 270 are shown in some views -- advisory
MAX_DESCRIPTION_CHARS = 10000

# WHAT'S NEW IN THIS VERSION -- "This field has a 1500 character limit. (Previously, this field
# was called Release notes)", read 2026-08-20 from the same Microsoft page as the limits above.
#
# THE SECTION IS REQUIRED, and that is the point of adding it here. The drafts had no section
# for this field at all, so 0.2.1.0 went out without touching it: the text had nowhere to live,
# and the field on the live page still carries the 0.2.0.0 draft while the shipped package is a
# version further on. The field is per LANGUAGE, so a release needs fourteen of them or it needs
# to decide not to -- and this makes that a decision rather than an omission.
MAX_WHATS_NEW_CHARS = 1500


# SERBIAN LATIN IS NOT A SECOND TRANSLATION, IT IS THE FIRST ONE IN ANOTHER SCRIPT. The mapping
# is 1:1 and deterministic in this direction (the ambiguity is the other way, where `nj` may be
# one letter or two), so `sr-Latn.md` can be RECOMPUTED from `sr.md` and compared rather than
# maintained by hand. Without that the two drift the moment one is edited, which is the shape
# this project has paid for repeatedly: one fact in two files and nothing between them.
#
# Digraphs uppercase fully inside an all-caps run -- ЉУБАВ is LJUBAV, not LjUBAV.
SR_LOWER = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'ђ': 'đ', 'е': 'e', 'ж': 'ž',
    'з': 'z', 'и': 'i', 'ј': 'j', 'к': 'k', 'л': 'l', 'љ': 'lj', 'м': 'm', 'н': 'n',
    'њ': 'nj', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'ћ': 'ć', 'у': 'u',
    'ф': 'f', 'х': 'h', 'ц': 'c', 'ч': 'č', 'џ': 'dž', 'ш': 'š',
}
SR_UPPER = {
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Ђ': 'Đ', 'Е': 'E', 'Ж': 'Ž',
    'З': 'Z', 'И': 'I', 'Ј': 'J', 'К': 'K', 'Л': 'L', 'Љ': 'Lj', 'М': 'M', 'Н': 'N',
    'Њ': 'Nj', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'Ћ': 'Ć', 'У': 'U',
    'Ф': 'F', 'Х': 'H', 'Ц': 'C', 'Ч': 'Č', 'Џ': 'Dž', 'Ш': 'Š',
}


def to_serbian_latin(text):
    out = []
    for i, ch in enumerate(text):
        if ch in SR_LOWER:
            out.append(SR_LOWER[ch])
        elif ch in SR_UPPER:
            lat = SR_UPPER[ch]
            if len(lat) == 2 and (text[i + 1] if i + 1 < len(text) else '') in SR_UPPER:
                lat = lat.upper()
            out.append(lat)
        else:
            out.append(ch)
    return ''.join(out)


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

    fresh = section_body(text, "What's new in this version")
    if fresh is not None:
        if len(fresh) > MAX_WHATS_NEW_CHARS:
            notes.append("what's new %d chars, limit %d"
                         % (len(fresh), MAX_WHATS_NEW_CHARS))
        # ONE LINE PER BULLET, because the form is plain text and keeps the breaks it is
        # given. A draft wrapped to markdown width pastes as a bullet broken across three
        # lines -- which is what the live 0.2.0.0 field would have shown had nobody unwrapped
        # it by hand at the form. Checked here so the unwrapping is not a manual step.
        for number, line in enumerate(fresh.splitlines()):
            if number == 0 or not line.strip():
                continue          # the lead sentence, and the blank line under it
            if not line.startswith(BULLET):
                notes.append("what's new has a line that is neither the lead nor a "
                             "bullet, so it is a wrapped one: %s..." % line[:40])
                break
        if '`' in fresh:
            notes.append("what's new contains a backtick; the field is plain text")

    return notes


def regen_sr_latn():
    """Write sr-Latn.md from sr.md. The Latin draft is never edited: it is regenerated, which is
    what makes the check above an equality rather than a request."""
    cyr_path = os.path.join(DRAFTS, 'sr-Cyrl.md')
    lat_path = os.path.join(DRAFTS, 'sr-Latn.md')
    if not os.path.exists(cyr_path):
        fail('no %s to transliterate' % cyr_path)
    text = to_serbian_latin(io.open(cyr_path, encoding='utf-8').read())
    io.open(lat_path, 'w', encoding='utf-8', newline='').write(text)
    sys.stdout.write('wrote %s (%d chars)' % (lat_path, len(text)) + chr(10))


def main():
    if '--regen-sr-latn' in sys.argv[1:]:
        regen_sr_latn()
        return 0
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
        if DRAFT_FILE.get(code, code) not in have:
            findings.append('%s: no draft (expected %s.md)'
                            % (code, DRAFT_FILE.get(code, code)))

    expected = (set(want) | set(ADDITIONAL_LISTING_LANGS) | set(DRAFT_FILE.values())
                ) - set(DRAFT_FILE.keys())
    for code in have:
        if code in DRAFT_FILE:
            # The name is the trap. `sr.md` reads as "the Serbian draft" and Microsoft's `sr` is
            # the LATIN row, so whatever is in it gets filed under Latin -- which is how Cyrillic
            # prose would end up there again. Refused by name, not left to a reader's care.
            findings.append('%s.md exists, and its name is the defect: %s is the %s row at '
                            'Microsoft. Use %s.md instead.'
                            % (code, code, 'Latin' if code == 'sr' else 'other',
                               DRAFT_FILE[code]))
        elif code not in expected:
            findings.append('%s: a draft for a language the window does not speak' % code)

    # sr-Latn must BE the transliteration of sr, character for character
    if 'sr-Latn' in ADDITIONAL_LISTING_LANGS:
        cyr_path = os.path.join(DRAFTS, 'sr-Cyrl.md')
        lat_path = os.path.join(DRAFTS, 'sr-Latn.md')
        if os.path.exists(cyr_path) and os.path.exists(lat_path):
            cyr = io.open(cyr_path, encoding='utf-8').read()
            lat = io.open(lat_path, encoding='utf-8').read()
            want_lat = to_serbian_latin(cyr)
            if lat != want_lat:
                findings.append('sr-Latn: not the transliteration of sr-Cyrl.md -- regenerate '
                                'it rather than editing it (edit sr-Cyrl.md and regenerate)')
            left = [c for c in lat if 'Ѐ' <= c <= 'ӿ']
            if left:
                findings.append('sr-Latn: %d Cyrillic characters left in a Latin draft'
                                % len(left))

    for code in ADDITIONAL_LISTING_LANGS:
        if code in want:
            findings.append('%s: listed as an additional listing language, but the package '
                            'declares it -- it is a window language, not an extra' % code)
        elif code not in have:
            findings.append('%s: named as an additional listing language with no draft' % code)

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

        # A MISSING SECTION IS THE FINDING, not merely a file with no headings at all. This
        # loop used to complain only when `^##` matched nowhere, so deleting one section
        # passed -- measured on 2026-08-20 by deleting the What's-new block from de.md, which
        # is exactly how 0.2.1.0 shipped with that field untouched. The anchors are English in
        # every draft (checked across all fourteen), so requiring them by name is answerable.
        for section in SECTIONS:
            if ('## ' + section) not in text:
                notes.append('no "## %s"' % section)

        if licence not in text:
            notes.append('does not name %s' % licence)
        if count not in prose_of(text):
            notes.append('does not name the language count (%s)' % count)

        # The 11.16 disclosure travels with EVERY listing, not only the English one: the
        # report address and the AI paragraphs went into docs/store-listing.md on
        # 2026-08-13/14, and a review (2026-08-14) found all thirteen drafts still carrying
        # the pre-AI text with this checker reporting nothing. The address is the cheap
        # structural proxy for the paragraphs: a draft that names it was touched by the
        # disclosure rewrite, and one that does not was not.
        if 'support@301.st' not in text:
            notes.append('no AI report address (11.16 disclosure paragraphs missing?)')

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
