#!/usr/bin/env python3
"""Build the MSIX package: stage the exe and its tiles, fill the manifest, call MakeAppx.

WHY THIS EXISTS BEFORE THERE IS AN ACCOUNT. Whether a Lazarus .exe packages and installs as an
MSIX is the one unknown that can invalidate the whole distribution plan (spec 11 names an
EXE/MSI fallback that would put signing, hosting and update mechanics on us). It is answerable
today, with the Windows SDK already on the machine, and the answer does not depend on Partner
Center -- so it is answered first and the identity is filled in later.

IDENTITY IS A PLACEHOLDER UNTIL PARTNER CENTER SAYS OTHERWISE, and the script says so on every
run rather than letting a made-up publisher look settled. `Publisher` is the certificate subject
Microsoft signs with; it is reserved with the account, not chosen here.

THE TILES ARE BUILD OUTPUT, not committed artefacts. They are resized from the brand raster the
application icon already uses, and they live only in the staging folder: unlike the icons and
the help, they do not travel inside the executable, and a second copy in the tree would be a
second thing to keep in step. Everything above 180 px is refused rather than upscaled -- the
same rule make-appicon.py states, and for the same reason.

Pillow for the images, stdlib for the rest. Run by hand, like the other image generators; CI
has neither Pillow nor the Windows SDK.

Usage:  python scripts/make-msix.py [--out DIR]

Writes: build/msix/            -- the staged package (manifest + exe + Assets)
        build/spintax-studio.msix
"""
import argparse
import glob
import io
import os
import re
import shutil
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, 'assets', 'brand', 'spintax-mark-180.png')
TEMPLATE = os.path.join(HERE, 'packaging', 'AppxManifest.xml.in')
EXE = os.path.join(HERE, 'spintax-studio.exe')

# IDENTITY. What is settled is here; what Partner Center still has to say is marked, and the
# script says which on every run rather than letting a guess look like an answer.
#
# The PUBLISHER is real: it is the account's Windows publisher ID, which is the certificate
# subject Microsoft signs with. It is not a secret -- it is readable in every package that
# account ever ships -- and it is the one identity field that cannot be guessed at all.
PUBLISHER = 'CN=BEE1F94B-ABDE-4CF8-9F30-1DF4DAFDAE83'
# The package NAME and the publisher's DISPLAY name come from reserving the app in Partner
# Center (Product identity), which has not been done. An upload with these is rejected.
IDENTITY_NAME = 'RESERVE-IN-PARTNER-CENTER.SpintaxStudio'
PUBLISHER_DISPLAY = 'RESERVE-IN-PARTNER-CENTER'
DISPLAY_NAME = 'Spintax Studio'
DESCRIPTION = ('An editor for spintax templates: write a template once, see every variant it '
               'produces, and export them. Works offline.')
PENDING = 'RESERVE-IN-PARTNER-CENTER'

# What the manifest names, and the side of the square. A tile is drawn from the mark centred on
# transparency -- the mark is a hexagon and a tile is a square, and stretching one into the
# other is how a brand stops being one.
TILES = [
    ('Square44x44Logo.png', 44),
    ('Square71x71Logo.png', 71),      # SmallTile below points at this size
    ('Square150x150Logo.png', 150),
    ('StoreLogo.png', 50),
]
# The manifest also names three by role; they are the same pictures under the names it wants.
ROLE_TILES = [
    ('SmallTile.png', 71, 71),
    ('LargeTile.png', 180, 180),      # 310 would be an upscale: refused, see below
    ('WideTile.png', 180, 88),
]


def fail(message):
    raise SystemExit('make-msix: %s' % message)


def read_version():
    path = os.path.join(HERE, 'VERSION')
    text = io.open(path, encoding='utf-8').read().strip()
    if not re.match(r'^\d+\.\d+\.\d+\.\d+$', text):
        fail('VERSION is %r; a package version is four numbers' % text)
    return text


def find_sdk_tool(name):
    """The newest SDK build that has the tool. Refused rather than guessed: a missing MakeAppx
    is a machine that cannot answer the question this script exists to answer."""
    pattern = os.path.join(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)'),
                           'Windows Kits', '10', 'bin', '*', 'x64', name)
    found = sorted(glob.glob(pattern))
    if not found:
        fail('no %s under the Windows SDK -- install the SDK, or point PATH at it' % name)
    return found[-1]


def mark():
    im = Image.open(SOURCE)
    if im.mode != 'RGBA':
        im = im.convert('RGBA')
    if im.width != im.height:
        fail('the brand raster is %dx%d; a tile is drawn from a square mark' % (im.size))
    return im


def tile(im, path, width, height):
    """The mark, centred on a transparent tile of this size. Never upscaled."""
    side = min(width, height)
    if side > im.width:
        fail('a %dx%d tile would upscale the %d px source; the Store sizes above that need a '
             'render from the vector, which docs/TODO.md tracks' % (width, height, im.width))
    small = im.resize((side, side), Image.LANCZOS)
    out = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    out.paste(small, ((width - side) // 2, (height - side) // 2))
    out.save(path, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(HERE, 'build'))
    args = ap.parse_args()

    if not os.path.exists(EXE):
        fail('no %s -- run sh ./build.sh first' % os.path.relpath(EXE, HERE))
    version = read_version()
    makeappx = find_sdk_tool('makeappx.exe')

    stage = os.path.join(args.out, 'msix')
    if os.path.isdir(stage):
        shutil.rmtree(stage)
    os.makedirs(os.path.join(stage, 'Assets'))

    im = mark()
    for name, side in TILES:
        tile(im, os.path.join(stage, 'Assets', name), side, side)
    for name, w, h in ROLE_TILES:
        tile(im, os.path.join(stage, 'Assets', name), w, h)

    shutil.copy2(EXE, os.path.join(stage, os.path.basename(EXE)))

    text = io.open(TEMPLATE, encoding='utf-8').read()
    for key, value in [('@IDENTITY_NAME@', IDENTITY_NAME), ('@PUBLISHER@', PUBLISHER),
                       ('@PUBLISHER_DISPLAY@', PUBLISHER_DISPLAY), ('@VERSION@', version),
                       ('@DISPLAY_NAME@', DISPLAY_NAME), ('@DESCRIPTION@', DESCRIPTION)]:
        text = text.replace(key, value)
    left = re.findall(r'@[A-Z_]+@', text)
    if left:
        fail('the manifest still holds %s' % ', '.join(sorted(set(left))))
    io.open(os.path.join(stage, 'AppxManifest.xml'), 'w', encoding='utf-8',
            newline='\r\n').write(text)

    package = os.path.join(args.out, 'spintax-studio.msix')
    if os.path.exists(package):
        os.remove(package)
    run = subprocess.run([makeappx, 'pack', '/d', stage, '/p', package, '/o'],
                         capture_output=True, text=True)
    sys.stdout.write(run.stdout)
    if run.returncode != 0:
        sys.stderr.write(run.stderr)
        fail('MakeAppx refused the package (exit %d)' % run.returncode)

    print('%-30s %d bytes' % (os.path.relpath(package, HERE), os.path.getsize(package)))
    print('Publisher %s (real), Version %s (from VERSION)' % (PUBLISHER, version))
    missing = [n for n, v in [('Identity Name', IDENTITY_NAME),
                              ('PublisherDisplayName', PUBLISHER_DISPLAY)] if PENDING in v]
    if missing:
        print('STILL TO RESERVE in Partner Center, and an upload is rejected without them: %s'
              % ', '.join(missing))


if __name__ == '__main__':
    main()
