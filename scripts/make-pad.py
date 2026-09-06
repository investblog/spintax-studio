"""Generate the PAD file for the software portals, from copy that is already gated.

WHY THIS IS GENERATED. A PAD file carries the version, the download URL, the file size and
the descriptions -- five facts that already live in this repository and one that lives in a
release asset. Hand-written, it becomes the fifth place a version number is stated, and this
project has twice published a claim that was true in the file where it was written and false
about the product. So `pad.xml` is output: the copy comes from `docs/pad-listing.md`, the
version from `VERSION`, the languages from the package manifest, and the size from the
release asset itself.

THE THREE LANGUAGES A PAD FILE TALKS ABOUT, which are easy to conflate:

  1. `Program_Info/Program_Language` -- the languages the PROGRAM speaks, one flat
     comma-separated list. Ours is fourteen, and it is derived from
     `packaging/AppxManifest.xml.in` here rather than typed, so it cannot drift from the
     package.
  2. `Program_Descriptions/<Language>` -- one block per language the DESCRIPTION is written
     in, the element named by the English name of the language (`<English>`, `<Russian>`).
     Confirmed against real PAD files in the wild, because the canonical spec host
     (pad.asp-software.org) no longer resolves at all.
  3. The `Char_Desc_45/80/250/450/2000` limits, which apply INSIDE each block. They are the
     reason the two are not the same question: the same sentence in Russian is longer, and
     45 characters is where that stops being a detail. The Store listing already taught this
     once -- count in the target language, not in English.

WHAT IT REFUSES TO DO. It does not write a PAD file that would be wrong on arrival:

  * a description over its limit, in any language, naming the language and the overshoot;
  * a language block for a language the file does not carry, or a stated language count that
    disagrees with the manifest;
  * a URL that does not answer. Every URL the PAD hands a portal -- download, mirror,
    homepage, screenshot, icon -- is fetched before the file is written. A PAD file is read
    by a robot that will not tell you it found a 404; it will just list the program with a
    broken link.

The one URL it cannot check is `Application_XML_File_URL`, which is the file's own address
and does not exist until this file is published. That is written on the gate rather than
pretended away.

Usage:

    python scripts/make-pad.py                 # write to the site repo, checking everything
    python scripts/make-pad.py --check         # check only, write nothing (for CI)
    python scripts/make-pad.py --out pad.xml   # write somewhere else
    python scripts/make-pad.py --offline       # skip the URL checks (and say so)
"""

import argparse
import io
import os
import re
import sys
import xml.etree.ElementTree as ElementTree
from urllib import request, error

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COPY = os.path.join(HERE, 'docs', 'pad-listing.md')
VERSION_FILE = os.path.join(HERE, 'VERSION')
MANIFEST = os.path.join(HERE, 'packaging', 'AppxManifest.xml.in')
DEFAULT_OUT = os.path.join(os.path.dirname(HERE), 'spintax.studio', 'static', 'pad.xml')

PAD_VERSION = '3.11'

# The PAD character limits, which are the element names themselves.
LIMITS = (45, 80, 250, 450, 2000)

# BCP-47 primary subtag -> the English name PAD wants. Named failure on anything absent: a
# language the package gains must be added here deliberately, not silently dropped or, worse,
# handed the previous language's name.
LANGUAGE_NAMES = {
    'en': 'English',   'ru': 'Russian',    'uk': 'Ukrainian', 'be': 'Belarusian',
    'sr': 'Serbian',   'hr': 'Croatian',   'bs': 'Bosnian',   'de': 'German',
    'fr': 'French',    'es': 'Spanish',    'it': 'Italian',   'pt': 'Portuguese',
    'nl': 'Dutch',     'tr': 'Turkish',
}


def die(message):
    sys.stderr.write('make-pad: %s\n' % message)
    raise SystemExit(2)


def read(path):
    with io.open(path, encoding='utf-8') as handle:
        return handle.read()


def manifest_languages():
    """The languages the PACKAGE declares, in declaration order, as PAD names."""
    try:
        root = ElementTree.parse(MANIFEST).getroot()
    except (IOError, OSError, ElementTree.ParseError) as problem:
        die('cannot read %s: %s' % (MANIFEST, problem))
    names, seen = [], set()
    for element in root.iter():
        if element.tag.rsplit('}', 1)[-1] != 'Resource':
            continue
        tag = (element.get('Language') or '').strip()
        if not tag:
            die('the manifest declares a <Resource> with a blank Language')
        code = tag.split('-')[0].lower()
        if code not in LANGUAGE_NAMES:
            die('no PAD language name for manifest tag %r -- add it to LANGUAGE_NAMES '
                'deliberately rather than letting it fall through' % tag)
        name = LANGUAGE_NAMES[code]
        if name not in seen:
            seen.add(name)
            names.append(name)
    if not names:
        die('no <Resource Language=...> in the manifest')
    return names


def fields(text, heading):
    """The `### <Field>` blocks under a `## <heading>` section, as {field: value}.

    Each value is the single fenced block under its `###` heading -- fenced so that nothing
    has to be inferred about where copy starts and stops, the same convention the SourceForge
    listing uses.
    """
    pattern = r'^## ' + re.escape(heading) + r'[ \t]*$'
    starts = [m.end() for m in re.finditer(pattern, text, re.M)]
    if len(starts) != 1:
        die('expected exactly one "## %s" in %s, found %d' % (heading, COPY, len(starts)))
    stop = text.find('\n## ', starts[0])
    block = text[starts[0]:stop if stop > 0 else len(text)]
    out = {}
    for match in re.finditer(r'^### (\S+)[ \t]*\n(.*?)(?=^### |\Z)', block, re.S | re.M):
        name, body = match.group(1), match.group(2)
        fence = re.findall(r'^```\n(.*?)\n```$', body, re.S | re.M)
        if len(fence) != 1:
            die('field "%s" under "%s" needs exactly one fenced block, found %d'
                % (name, heading, len(fence)))
        out[name] = fence[0].strip('\n')
    if not out:
        die('no "### Field" blocks under "## %s"' % heading)
    return out


def check_url(url, what, findings):
    """A URL the PAD hands a robot. A 404 here is a broken listing nobody reports."""
    req = request.Request(url, method='HEAD', headers={'User-Agent': 'make-pad/1.0'})
    try:
        with request.urlopen(req, timeout=30) as response:
            if response.status >= 400:
                findings.append('%s: HTTP %d for %s' % (what, response.status, url))
            return response.headers.get('Content-Length')
    except error.HTTPError as problem:            # some hosts refuse HEAD; try a ranged GET
        if problem.code in (403, 405, 501):
            try:
                ranged = request.Request(url, headers={'User-Agent': 'make-pad/1.0',
                                                       'Range': 'bytes=0-0'})
                with request.urlopen(ranged, timeout=30) as response:
                    return response.headers.get('Content-Range', '').split('/')[-1] or None
            except Exception as second:
                findings.append('%s: %s for %s' % (what, second, url))
        else:
            findings.append('%s: HTTP %d for %s' % (what, problem.code, url))
    except Exception as problem:
        findings.append('%s: %s for %s' % (what, problem, url))
    return None


def element(parent, tag, text=''):
    node = ElementTree.SubElement(parent, tag)
    node.text = text if text else None
    return node


def report(version, download, languages, described, blocks, urls, size):
    """What was measured, printed the same way whether or not a file gets written."""
    sys.stdout.write('version     %s\n' % version)
    sys.stdout.write('download    %s%s\n'
                     % (download, ' (%s bytes)' % size if size else ' (size NOT measured)'))
    sys.stdout.write('languages   %d spoken by the program: %s\n'
                     % (len(languages), ','.join(languages)))
    sys.stdout.write('described   %s\n' % ', '.join(described))
    for name in described:
        sizes = ' '.join('%d:%d' % (limit, len(blocks[name]['Char_Desc_%d' % limit]))
                         for limit in LIMITS)
        sys.stdout.write('            %-8s %s\n' % (name, sizes))
    if size:
        sys.stdout.write("urls        %d checked, all answered (except the file's own"
                         " address, which does not exist until it is published)\n" % len(urls))
    else:
        sys.stdout.write('urls        NOT checked\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default=DEFAULT_OUT)
    parser.add_argument('--check', action='store_true', help='check only, write nothing')
    parser.add_argument('--offline', action='store_true', help='skip the URL checks')
    args = parser.parse_args()

    if not os.path.exists(COPY):
        die('no %s' % COPY)
    text = read(COPY)
    version = read(VERSION_FILE).strip()
    findings = []

    fixed = fields(text, 'Fixed fields')
    languages = manifest_languages()

    stated = fixed.get('Program_Language', '')
    if [x.strip() for x in stated.split(',') if x.strip()] != languages:
        findings.append('Program_Language in the copy disagrees with the package manifest;'
                        ' the manifest declares %d: %s' % (len(languages), ','.join(languages)))

    # ---- the per-language description blocks ------------------------------------------------
    described = [name for name in ('English', 'Russian') if '## ' + name in text]
    if not described:
        die('no "## English" or "## Russian" description section in %s' % COPY)
    blocks = {}
    for name in described:
        if name not in languages:
            findings.append('there is a %s description block, but the program does not list'
                            ' %s among its own languages' % (name, name))
        block = fields(text, name)
        for limit in LIMITS:
            key = 'Char_Desc_%d' % limit
            value = block.get(key)
            if value is None:
                findings.append('%s: %s is missing' % (name, key))
                continue
            if len(value) > limit:
                findings.append('%s: %s is %d characters, %d over the limit'
                                % (name, key, len(value), len(value) - limit))
        blocks[name] = block

    # ---- the URLs, and the size of the thing being described --------------------------------
    download = fixed['Primary_Download_URL'].replace('{version}', version)
    urls = {
        'Primary_Download_URL': download,
        'Secondary_Download_URL': fixed['Secondary_Download_URL'],
        'Application_Info_URL': fixed['Application_Info_URL'],
        'Application_Screenshot_URL': fixed['Application_Screenshot_URL'],
        'Application_Icon_URL': fixed['Application_Icon_URL'],
    }
    size = None
    if args.offline:
        sys.stdout.write('URL checks SKIPPED (--offline); the file size cannot be measured\n')
    else:
        for what, url in urls.items():
            got = check_url(url, what, findings)
            if what == 'Primary_Download_URL':
                size = got
        if size is None and not findings:
            findings.append('could not measure the size of %s, which the PAD must state'
                            % download)

    if findings:
        sys.stdout.write('%d finding(s):\n' % len(findings))
        for finding in findings:
            sys.stdout.write('  - %s\n' % finding)
        sys.stdout.write('\nno PAD file written.\n')
        return 1

    report(version, download, languages, described, blocks, urls, size)

    # STOP HERE when only checking, and REFUSE when offline. Both used to fall through into
    # the builder, where `File_Size_Bytes` is `int(size)` and `size` is None without the
    # network -- a crash, not a message. It survived the mutation sweep because every mutation
    # returned above on a finding, so the clean offline path was the one nobody had run. A
    # branch reached only when everything else is right is the branch nothing exercises.
    if args.check:
        sys.stdout.write('\n--check: nothing written.\n')
        return 0
    if args.offline:
        die('--offline cannot write a PAD file: the size of the download is measured from the'
            ' download, and a PAD that misstates it misleads every portal that reads it')

    # ---- build ------------------------------------------------------------------------------
    root = ElementTree.Element('XML_DIZ_INFO')
    info = element(root, 'MASTER_PAD_VERSION_INFO')
    element(info, 'MASTER_PAD_VERSION', PAD_VERSION)
    element(info, 'MASTER_PAD_EDITOR', 'scripts/make-pad.py (spintax-studio)')
    element(info, 'MASTER_PAD_INFO',
            'Portable Application Description, generated from docs/pad-listing.md')

    company = element(root, 'Company_Info')
    for tag in ('Company_Name', 'Address_1', 'Address_2', 'City_Town', 'State_Province',
                'Zip_Postal_Code', 'Country', 'Company_WebSite_URL'):
        element(company, tag, fixed.get(tag, ''))

    support = element(root, 'Support_Info')
    for tag in ('Sales_Email', 'Support_Email', 'General_Email'):
        element(support, tag, fixed.get(tag, ''))

    program = element(root, 'Program_Info')
    element(program, 'Program_Name', fixed['Program_Name'])
    element(program, 'Program_Version', version)
    for tag in ('Program_Release_Month', 'Program_Release_Day', 'Program_Release_Year',
                'Program_Cost_Dollars', 'Program_Type', 'Program_Release_Status',
                'Program_Install_Support', 'Program_OS_Support'):
        element(program, tag, fixed.get(tag, ''))
    element(program, 'Program_Language', ','.join(languages))
    element(program, 'Program_Change_Info', fixed.get('Program_Change_Info', ''))
    element(program, 'Program_Specific_Category', fixed.get('Program_Specific_Category', ''))
    element(program, 'Program_Category_Class', fixed.get('Program_Category_Class', ''))
    element(program, 'Program_System_Requirements',
            fixed.get('Program_System_Requirements', ''))

    file_info = element(root, 'File_Info')
    total = int(size)
    element(file_info, 'File_Size_Bytes', str(total))
    element(file_info, 'File_Size_K', str(int(round(total / 1024.0))))
    element(file_info, 'File_Size_MB', '%.2f' % (total / 1048576.0))

    descriptions = element(root, 'Program_Descriptions')
    for name in described:
        block = blocks[name]
        section = element(descriptions, name)
        element(section, 'Keywords', block.get('Keywords', ''))
        for limit in LIMITS:
            element(section, 'Char_Desc_%d' % limit, block['Char_Desc_%d' % limit])

    web = element(root, 'Web_Info')
    app_urls = element(web, 'Application_URLs')
    element(app_urls, 'Application_Info_URL', urls['Application_Info_URL'])
    element(app_urls, 'Application_Order_URL', '')
    element(app_urls, 'Application_Screenshot_URL', urls['Application_Screenshot_URL'])
    element(app_urls, 'Application_Icon_URL', urls['Application_Icon_URL'])
    element(app_urls, 'Application_XML_File_URL', fixed['Application_XML_File_URL'])
    downloads = element(web, 'Download_URLs')
    element(downloads, 'Primary_Download_URL', download)
    element(downloads, 'Secondary_Download_URL', urls['Secondary_Download_URL'])

    permissions = element(root, 'Permissions')
    element(permissions, 'Distribution_Permissions', fixed.get('Distribution_Permissions', ''))
    element(permissions, 'EULA', fixed.get('EULA', ''))

    ElementTree.indent(root, space='\t')
    xml = ElementTree.tostring(root, encoding='unicode')
    document = '<?xml version="1.0" encoding="UTF-8"?>\n' + xml + '\n'

    with io.open(args.out, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(document)
    sys.stdout.write('\nwritten: %s (%d bytes)\n' % (args.out, len(document.encode('utf-8'))))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
