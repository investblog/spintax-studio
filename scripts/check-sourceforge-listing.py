"""Hold docs/sourceforge-listing.md to the form it is pasted into, and to itself.

WHY THIS EXISTS. The SourceForge project page carries the same product claims as the Store
listing in fields a third of the size, and every limit in that file was read off the form's
own DOM once, on 2026-09-05. Nothing would notice if an edit later pushed the description
past the 1000 the textarea accepts -- the submission form would, halfway through a paste,
which is where this project has met a limit twice before (twenty features, and the icon
frames Windows asks for).

WHAT IT CHECKS:

  * the three fields against the limits the form declares, counted the way a BROWSER counts
    them: UTF-16 code units, not Python code points, because `maxlength` and every ordinary
    JavaScript counter count units and an astral character is one here and two there. The
    description is measured with CRLF line endings, because a textarea submits CRLF: the five
    paragraphs are joined by four blank-line separators, which is eight LF characters, and
    normalising them adds eight;
  * that no description paragraph is hard-wrapped. Partner Center's What's-new field keeps
    the breaks it is given and turned a wrapped draft into bullets broken across three
    lines; a textarea does the same;
  * the two facts this project has published wrongly before -- the licence name and the
    language count, the second read from the package manifest rather than typed here;
  * the two wordings the network slice is careful about (spec 4.5). "with your own key when
    it needs one" is not "your own provider and key", which overstates it, and "talks only
    to the endpoint you configure" is not "nothing leaves the computer", which the
    application cannot know: a proxy answers on a loopback port too. Both were corrections
    made ON the live Store page; a copy that loses them re-publishes what was corrected;
  * every NUMBER the file states about itself. It says the name is "14 of 40", the summary
    "62 characters", the description "973 characters as written and 981 as the browser will
    count it", and that 16 features are filled. Those are claims like any other, and the way
    they fail is by being right when written and stale after one edit. Written as DIGITS on
    purpose: an earlier cut read number WORDS through a table and therefore ignored any
    numeral the table lacked, so "forty features" passed while a correct "sixteen features"
    elsewhere kept the check happy;
  * that the feature list's own ordinals run 1..N, since sixteen non-empty lines numbered
    1..15 with a second 15 count as sixteen and read as broken.

HOW IT REFUSES TO GUESS. Each field is a single fenced block under a heading matched in full
and required to occur exactly once, and each stated number must occur exactly once too. An
earlier draft of this script inferred the description from paragraph formatting -- everything
under the heading not opening with `**` -- and a review pointed out that `**Spintax Studio**
is a native Windows editor...` would then drop a real paragraph out of every length and
wording check, silently, leaving the gate green over a field it had mis-read. A check that
cannot find its subject must fail, not pass; so nothing here is inferred.

WHAT IT DOES NOT CHECK, and cannot:

  * the live SourceForge page. It reads a file. If somebody edits the page in the browser
    and not here, this passes and the file is fiction -- the same shape as the Store's
    SupportUris, which moved to spintax.studio and was found only by a read-back;
  * whether a required wording is ASSERTED or merely present. The two AI phrases are checked
    as substrings, so a sentence denying one of them would satisfy the check. That is a real
    hole and it is left open deliberately: the alternative pins whole sentences and turns
    every innocent rewording into a failure, and the field is 970 characters of marketing
    copy in which a denial is not a plausible edit. It is written here rather than assumed;
  * whether the categories listed in the file are the ones actually selected on the project;
  * whether any of the prose is good.

It is deliberately NOT the sibling `check-listing-drafts.py`, and CI runs this one only:
`marketing/` is untracked, so on a clone that script has no subject and exits 0 -- a green
check measuring nothing. This file is tracked, so this check has something to fail on.

Usage:

    python scripts/check-sourceforge-listing.py           # report, exit 1 on any finding
    python scripts/check-sourceforge-listing.py --quiet   # only the findings
"""

import io
import os
import re
import sys
import xml.etree.ElementTree as ElementTree

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, 'docs', 'sourceforge-listing.md')
MANIFEST = os.path.join(HERE, 'packaging', 'AppxManifest.xml.in')

# Read off the admin form's own DOM on 2026-09-05: `maxlength` on name and summary, the live
# counter on the description. If SourceForge changes them, this file is where it is recorded.
MAX_NAME = 40
MAX_SUMMARY = 70
MAX_DESCRIPTION = 1000

LICENCE = 'GPL-3.0-or-later'

# Corrections made on the live Store page; a copy that drops them re-publishes the overclaim.
LOAD_BEARING = (
    'with your own key when it needs one',
    'talks only to the endpoint you configure',
)

def read(path):
    with io.open(path, encoding='utf-8') as handle:
        return handle.read()


def die(message):
    sys.stderr.write('check-sourceforge-listing: %s\n' % message)
    raise SystemExit(2)


def utf16_len(text):
    """What the form counts: UTF-16 code units, as `maxlength` and a JS counter do."""
    return len(text.encode('utf-16-le')) // 2


def section(text, heading):
    """The body under `## <heading>`, which must appear exactly once, matched in full."""
    pattern = r'^## ' + re.escape(heading) + r'[ \t]*$'
    starts = [m.end() for m in re.finditer(pattern, text, re.M)]
    if len(starts) != 1:
        die('expected exactly one "## %s" heading in %s, found %d'
            % (heading, SOURCE, len(starts)))
    start = starts[0]
    stop = text.find('\n## ', start)
    return text[start:stop if stop > 0 else len(text)]


FENCE = '`' * 3


def fenced(body, heading):
    """The single fenced block in a section: the field's value, verbatim and not inferred.

    Counting DELIMITER LINES rather than regex pairs. A non-greedy match across THREE fences
    pairs the first with the second and leaves the third orphaned -- so one stray fence above
    the field would hand this check some other text to validate while the real field sat
    outside it, green. Two delimiter lines, or a named failure.
    """
    lines = body.split('\n')
    marks = [i for i, line in enumerate(lines) if line.rstrip() == FENCE]
    if len(marks) != 2:
        die('expected exactly two fence lines under "%s", found %d' % (heading, len(marks)))
    return '\n'.join(lines[marks[0] + 1:marks[1]])


def manifest_language_count():
    """How many languages the PACKAGE declares. Parsed, and inherited rather than typed.

    A regex over XML reads a COMMENTED-OUT element as a live one, which is how two gates in
    this repository once passed over a bad `<Resource Language="sr" />` quoted in a comment.
    ElementTree drops comments, so a language commented out is a language gone.
    """
    if not os.path.exists(MANIFEST):
        die('no %s' % MANIFEST)
    try:
        root = ElementTree.parse(MANIFEST).getroot()
    except ElementTree.ParseError as error:
        die('%s does not parse as XML: %s' % (MANIFEST, error))
    tags = set()
    for element in root.iter():
        if element.tag.rsplit('}', 1)[-1] != 'Resource':
            continue
        raw = element.get('Language')
        if raw is None:
            continue
        # Strip BEFORE asking whether it is there. Testing the raw value first lets
        # Language=" " count as a language: the tag it replaced disappears, the empty string
        # takes its place, and the total is unchanged -- a deletion that reads as green.
        language = raw.strip().lower()
        if not language:
            die('%s declares a <Resource> whose Language is blank' % MANIFEST)
        tags.add(language)
    if not tags:
        die('no <Resource Language=...> elements in %s -- cannot check the language count'
            % MANIFEST)
    return len(tags)


def stated_number(text, pattern, what, findings):
    """A number the file states about itself, which must be stated exactly once."""
    matches = re.findall(pattern, text, re.M)
    if not matches:
        findings.append('%s: the file no longer states it, so nothing can check it' % what)
        return None
    if len(matches) > 1:
        findings.append('%s: stated %d times, so a stale one could hide behind a fresh one'
                        % (what, len(matches)))
        return None
    groups = matches[0]
    if not isinstance(groups, tuple):
        groups = (groups,)
    return tuple(int(g) for g in groups)


def main():
    quiet = '--quiet' in sys.argv[1:]
    if not os.path.exists(SOURCE):
        die('no %s' % SOURCE)
    text = read(SOURCE)
    findings = []

    # ---- Name ----------------------------------------------------------------------------
    heading = 'Name'
    name_body = section(text, heading)
    name = fenced(name_body, heading)
    if utf16_len(name) > MAX_NAME:
        findings.append('name is %d characters, the form accepts %d'
                        % (utf16_len(name), MAX_NAME))
    stated = stated_number(name_body, r'^(\d+) of (\d+)\b', 'name length', findings)
    if stated and stated != (utf16_len(name), MAX_NAME):
        findings.append('name says "%d of %d"; it is %d of %d'
                        % (stated[0], stated[1], utf16_len(name), MAX_NAME))

    # ---- Short Summary -------------------------------------------------------------------
    heading = 'Short Summary (%d)' % MAX_SUMMARY
    summary_body = section(text, heading)
    summary = fenced(summary_body, heading)
    if utf16_len(summary) > MAX_SUMMARY:
        findings.append('summary is %d characters, the form accepts %d'
                        % (utf16_len(summary), MAX_SUMMARY))
    stated = stated_number(summary_body, r'^(\d+) characters\.', 'summary length', findings)
    if stated and stated[0] != utf16_len(summary):
        findings.append('summary says %d characters; it is %d'
                        % (stated[0], utf16_len(summary)))

    # ---- Full Description ------------------------------------------------------------------
    heading = 'Full Description (%d)' % MAX_DESCRIPTION
    description = fenced(section(text, heading), heading)
    # The SHAPE first, because every count below is taken on the assumption of it: one line
    # per paragraph, exactly one blank line between them, nothing leading or trailing. A
    # `split('\n\n')` that drops empties hides a doubled blank line and a stray edge newline,
    # and those are characters the form counts even though this file's own description of
    # itself says they are not there.
    if not re.match(r'^[^\n]+(?:\n\n[^\n]+)*$', description):
        findings.append('the description is not one line per paragraph separated by exactly'
                        ' one blank line, which is the shape every count here assumes')
    paras = [p for p in description.split('\n\n') if p.strip()]
    as_written = utf16_len(description)
    as_submitted = utf16_len(description.replace('\n', '\r\n'))
    if as_submitted > MAX_DESCRIPTION:
        findings.append('description is %d characters as the browser counts it (%d as written),'
                        ' the form accepts %d' % (as_submitted, as_written, MAX_DESCRIPTION))
    for index, para in enumerate(paras, 1):
        if '\n' in para.strip():
            findings.append('description paragraph %d is hard-wrapped; a textarea keeps the'
                            ' breaks it is given' % index)
    stated = stated_number(text, r'(\d+) characters as written and (\d+) as',
                           'description length', findings)
    if stated and stated != (as_written, as_submitted):
        findings.append('description says "%d as written and %d"; it is %d and %d'
                        % (stated[0], stated[1], as_written, as_submitted))

    if LICENCE not in description:
        findings.append('the description does not name the licence as %s' % LICENCE)
    languages = manifest_language_count()
    if not re.search(r'\b%d languages\b' % languages, description):
        findings.append('the description does not say "%d languages"; the package manifest'
                        ' declares %d' % (languages, languages))
    for phrase in LOAD_BEARING:
        if phrase not in description:
            findings.append('the description no longer says "%s" -- that wording is a'
                            ' correction already made on the live Store page' % phrase)

    # ---- Features ---------------------------------------------------------------------------
    rows = re.findall(r'^\s*(\d+)\.[ \t]*(.*)$', section(text, 'Features'), re.M)
    if not rows:
        die('no numbered features found under "## Features"')
    features = [body for _, body in rows]
    for index, (ordinal, body) in enumerate(rows, 1):
        if not body.strip():
            findings.append('feature %d is empty' % index)
        # The ORDINALS are checked, not discarded. Sixteen non-empty lines numbered 1..15 with
        # a second 15 is sixteen features to a counter and a broken list to a reader, and it
        # is also how unrelated numbered prose would be swept into this list unnoticed.
        if int(ordinal) != index:
            findings.append('feature %d is numbered %s; the list must run 1..%d'
                            % (index, ordinal, len(rows)))
    # DIGITS, not number words. An earlier cut matched "<word> features" and looked the word
    # up in a table, which silently ignored any numeral the table lacked -- "forty features"
    # passed, because a correct "sixteen features" elsewhere satisfied the check. A digit
    # needs no table and cannot be half-known.
    claims = [int(n) for n in re.findall(r'\b(\d+) features\b', text)]
    if not claims:
        findings.append('the file no longer states how many features are filled, so nothing'
                        ' can check the list against it')
    for claimed in claims:
        if claimed != len(features):
            findings.append('the file says "%d features"; the list has %d'
                            % (claimed, len(features)))

    # ---- Report -----------------------------------------------------------------------------
    if not quiet:
        sys.stdout.write(
            'name        %d/%d\n'
            'summary     %d/%d\n'
            'description %d/%d as the browser counts it (%d as written), %d paragraphs\n'
            'features    %d\n'
            'languages   %d, parsed from the package manifest\n'
            % (utf16_len(name), MAX_NAME, utf16_len(summary), MAX_SUMMARY,
               as_submitted, MAX_DESCRIPTION, as_written, len(paras),
               len(features), languages))
    # The same sentence can be stated in two places -- the header and the gate section both
    # say "16 features" -- and one stale claim should read as one finding, not as two
    # identical lines. Order is kept: the first mention is where a reader will look.
    unique = list(dict.fromkeys(findings))
    if unique:
        sys.stdout.write('\n%d finding(s):\n' % len(unique))
        for finding in unique:
            sys.stdout.write('  - %s\n' % finding)
        return 1
    if not quiet:
        sys.stdout.write('\nnothing to report: every field fits the form, every number the'
                         ' file states about itself is the number it is.\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
