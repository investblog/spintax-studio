#!/usr/bin/env python3
"""Build the About box's contents from the files that already hold them.

NOTICE.md SAYS SO ITSELF: "Anything here that requires attribution must also appear in the
application's About box -- the About box is the copy a user can actually read, and this file is
the copy an audit can." Two copies of a licence text drift, and drift silently, so there is one
copy and this script carries it across.

THE VERSION IS ONE STRING, in `VERSION` at the root, four parts because that is what the Store's
Partner Center wants of a package. Whatever ends up in the manifest and whatever the reader sees
come from the same line.

THE ENGINE'S VERSION IS THE SUBMODULE'S TAG, read from git rather than retyped. Someone comparing
this build's output with another engine in the family needs to know which one this was built
against, and a number copied by hand is a number that stops being true at the next bump. If git
cannot answer -- a tarball, a detached checkout -- the script says so and refuses rather than
writing a guess.

Pure stdlib, like the other generators here: CI runs this on a runner that has Python and no
Pillow.

Usage:  python scripts/make-about.py

Writes: gui/SpxAbout.pas
"""
import io
import os
import re
import subprocess

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The heading whose entries the licences OBLIGE us to show. The others are carried too -- naming
# what a binary links is cheap and honest -- but this one is the legal requirement, and the suite
# checks it separately for that reason.
ATTRIBUTION_HEADING = 'Requires attribution in the shipped application'


def fail(message):
    raise SystemExit('make-about: %s' % message)


def read_version():
    path = os.path.join(HERE, 'VERSION')
    if not os.path.exists(path):
        fail('no VERSION file -- the About box and the package manifest read the same line')
    text = io.open(path, encoding='utf-8').read().strip()
    if not re.match(r'^\d+\.\d+\.\d+\.\d+$', text):
        fail('VERSION is %r; Partner Center wants four numbers, Major.Minor.Build.Revision'
             % text)
    return text


def read_engine_version():
    """The submodule's tag, from git. Refused rather than guessed -- see the module docstring."""
    try:
        out = subprocess.run(['git', '-C', os.path.join(HERE, 'engine'), 'describe', '--tags'],
                             capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        fail('cannot run git for the engine submodule: %s' % exc)
    if out.returncode != 0:
        fail('git could not describe engine/: %s' % (out.stderr or '').strip())
    tag = out.stdout.strip()
    if not tag:
        fail('git described engine/ as nothing')
    return tag


def parse_notice():
    """The entries of NOTICE.md, in file order, grouped by their `##` heading.

    An entry starts with a `**Name**` at the beginning of a line and runs to the next entry or
    heading. The licence is the first thing on the entry that reads like one -- which the file
    writes consistently, and which this refuses to guess at when it does not.
    """
    path = os.path.join(HERE, 'NOTICE.md')
    if not os.path.exists(path):
        fail('no NOTICE.md -- there is nothing to attribute from')
    lines = io.open(path, encoding='utf-8').read().split('\n')

    groups = []          # [{'title':.., 'entries':[{'name':.., 'licence':.., 'body':[..]}]}]
    group = None
    entry = None
    for raw in lines:
        line = raw.rstrip()
        if line.startswith('## '):
            group = {'title': line[3:].strip(), 'entries': []}
            groups.append(group)
            entry = None
            continue
        m = re.match(r'^\*\*(.+?)\*\*(.*)$', line)
        if m and group is not None:
            entry = {'name': m.group(1).strip(), 'licence': '', 'body': [], 'tail': ''}
            group['entries'].append(entry)
            rest = m.group(2).strip()
            if rest:
                entry['tail'] = rest.lstrip('-— ').strip()
                entry['body'].append(entry['tail'])
            continue
        if entry is not None and line.strip():
            entry['body'].append(line.strip())

    # The licence of an entry, read WHERE IT IS DECLARED and nowhere else: the rest of the
    # `**Name**` line, or the line immediately after it. NOTICE.md writes it in one of those two
    # places for every entry, and reading the whole body instead is how a wrong licence ships --
    # measured by review: a sentence mentioning MPL 1.1 inside the Lazarus entry made the About
    # box say the LCL is MPL, and the suite could not see it, because it asks the shipped text
    # for what the generator collected. The Free Pascal entry is already one edit from the same
    # fault: its prose says "ours is MIT".
    #
    # Longest first, so `modified LGPL (LGPL with the static-linking exception)` is not read as
    # the `modified LGPL` that is a prefix of it.
    known = sorted(['GNU General Public License v3.0 or later',
                    'Apache License 2.0', 'CC-BY 4.0', 'MPL 1.1',
                    'modified LGPL (LGPL with the static-linking exception)',
                    'modified LGPL', 'MIT'], key=len, reverse=True)
    for group in groups:
        for e in group['entries']:
            for k in known:
                # On the `**Name**` line itself, where six of the seven entries declare it...
                if k in e['tail']:
                    e['licence'] = k
                    break
                # ...or as the FIRST thing on a line of its own, which is where the other one
                # puts it after a description that wraps. Never mid-sentence in the prose: that
                # is the position a mention lives at, and a mention is not a declaration.
                if any(b.startswith(k) for b in e['body']):
                    e['licence'] = k
                    break
            if not e['licence']:
                fail('the entry %r in NOTICE.md names no licence this script knows; add it to '
                     '`known` on purpose rather than letting it ship unnamed' % e['name'])
    if not any(g['title'] == ATTRIBUTION_HEADING for g in groups):
        fail('NOTICE.md has no %r section' % ATTRIBUTION_HEADING)
    return groups


def literal(text):
    """A Pascal string literal. A newline cannot appear inside one."""
    out, run = [], ''
    for ch in text:
        if ch == '\n':
            if run:
                out.append("'" + run.replace("'", "''") + "'")
                run = ''
            out.append('#10')
        else:
            run += ch
    if run or not out:
        out.append("'" + run.replace("'", "''") + "'")
    return ' + '.join(out)


def main():
    version = read_version()
    engine = read_engine_version()
    groups = parse_notice()

    # One flat list of lines, the way the box will show them: a heading, then each entry as its
    # name and licence and then its prose. The window draws text and nothing else.
    lines = []
    licences = []
    obliged = []
    for group in groups:
        if lines:
            lines.append('')
        lines.append(group['title'].upper())
        for e in group['entries']:
            lines.append('')
            lines.append('%s -- %s' % (e['name'], e['licence']))
            for b in e['body']:
                lines.append('  ' + b)
            if e['licence'] not in licences:
                licences.append(e['licence'])
            if group['title'] == ATTRIBUTION_HEADING:
                obliged.append(e['name'])

    u = ['(*',
         ' * SpxAbout -- what the About box says, built from the files that already say it.',
         ' *',
         ' * GENERATED by scripts/make-about.py from NOTICE.md, VERSION and the engine',
         ' * submodule\'s tag. Do not edit: change those and run the script again.',
         ' *',
         ' * NOTICE.md asks for this in as many words -- "anything here that requires',
         ' * attribution must also appear in the application\'s About box" -- and the point of',
         ' * generating it is that the two copies cannot drift. The suite checks that every',
         ' * licence named in the file is named here, and that every entry the file OBLIGES us',
         ' * to show is in the text that ships.',
         ' *)',
         'unit SpxAbout;',
         '',
         '{$mode objfpc}{$H+}',
         '',
         'interface',
         '',
         'const',
         '  { Four parts, because that is what a Store package manifest wants. One line, in',
         '    VERSION at the root, so the manifest and the screen cannot disagree. }',
         '  SPX_VERSION = %s;' % literal(version),
         '  { The engine this was built against -- the submodule tag, read from git at',
         '    generation. Someone reporting a difference from another engine in the family',
         '    needs to know which one answered here. }',
         '  SPX_ENGINE_VERSION = %s;' % literal(engine),
         '',
         '{ The attributions, one line at a time, in the order NOTICE.md gives them. }',
         'function SpxAboutLineCount: Integer;',
         'function SpxAboutLine(AIndex: Integer): string;',
         '',
         '{ Every licence NOTICE.md names, and every entry it obliges the application to show.',
         '  Here so the suite can hold the two files to each other. }',
         'function SpxAboutLicenceCount: Integer;',
         'function SpxAboutLicence(AIndex: Integer): string;',
         'function SpxAboutObligedCount: Integer;',
         'function SpxAboutObliged(AIndex: Integer): string;',
         '',
         'implementation',
         '',
         'const']

    def arr(name, values):
        if not values:
            fail('%s would be empty; NOTICE.md is not saying what it should' % name)
        out = ['  %s: array[0..%d] of string = (' % (name, len(values) - 1)]
        for i, v in enumerate(values):
            out.append('    %s%s' % (literal(v), ',' if i < len(values) - 1 else ''))
        out.append('  );')
        return out

    u += arr('ABOUT_LINE', lines)
    u.append('')
    u += arr('ABOUT_LICENCE', licences)
    u.append('')
    u += arr('ABOUT_OBLIGED', obliged)
    u += ['',
          'function SpxAboutLineCount: Integer;',
          'begin',
          '  Result := Length(ABOUT_LINE);',
          'end;',
          '',
          'function SpxAboutLine(AIndex: Integer): string;',
          'begin',
          "  if (AIndex < 0) or (AIndex > High(ABOUT_LINE)) then Exit('');",
          '  Result := ABOUT_LINE[AIndex];',
          'end;',
          '',
          'function SpxAboutLicenceCount: Integer;',
          'begin',
          '  Result := Length(ABOUT_LICENCE);',
          'end;',
          '',
          'function SpxAboutLicence(AIndex: Integer): string;',
          'begin',
          "  if (AIndex < 0) or (AIndex > High(ABOUT_LICENCE)) then Exit('');",
          '  Result := ABOUT_LICENCE[AIndex];',
          'end;',
          '',
          'function SpxAboutObligedCount: Integer;',
          'begin',
          '  Result := Length(ABOUT_OBLIGED);',
          'end;',
          '',
          'function SpxAboutObliged(AIndex: Integer): string;',
          'begin',
          "  if (AIndex < 0) or (AIndex > High(ABOUT_OBLIGED)) then Exit('');",
          '  Result := ABOUT_OBLIGED[AIndex];',
          'end;',
          '',
          'end.',
          '']

    out = os.path.join(HERE, 'gui', 'SpxAbout.pas')
    io.open(out, 'w', encoding='utf-8', newline='').write('\n'.join(u))
    print('version %s, engine %s, %d lines, %d licences, %d obliged'
          % (version, engine, len(lines), len(licences), len(obliged)))
    print('%-30s %d bytes' % (os.path.relpath(out, HERE), os.path.getsize(out)))


if __name__ == '__main__':
    main()
