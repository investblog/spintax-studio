#!/usr/bin/env python3
"""Build the window's icon sprite and the Pascal unit that carries it.

WHY A SCRIPT AND NOT A CHECKED-IN BINARY ALONE. The icons come from Material Design Icons
(pictogrammers.com, Apache-2.0), and they arrive as a FONT rather than as images: this
renders the glyphs we use into one strip per size, which is exactly the shape LCL's
TImageList.AddSliced wants. Keeping the recipe means a new icon is a line here rather than
an image someone has to find and match by eye.

WHY THE BYTES END UP IN A .pas. R0 ships as one self-contained offline .exe (spec §11), so
the images cannot be files beside it, and a Lazarus .lpi storing them as base64 would put a
blob in the one file the project reviews as text. A generated unit is honest about being
generated, and the exe stays one file.

Usage:  python scripts/make-icons.py <path-to-materialdesignicons-webfont.ttf>
        (the font is not vendored: it is 1.3 MB of someone else's work, and only the
         handful of glyphs below ever reach the product)

Writes:  assets/icons/rail-<size>.png   -- the sprites, for looking at
         gui/SpxIcons.pas               -- the same bytes, for shipping
"""
import io
import os
import sys

from PIL import Image, ImageDraw, ImageFont

# The rail's tools, in the order the rail shows them. The name is MDI's own; the comment is
# what it means here, because `variable` and `code-braces` are obvious and the other two are
# a choice someone may want to revisit.
# The Pascal name is here rather than in the emitter: adding a fifth icon used to produce a
# five-cell strip and only four constants, and REORDERING two used to re-point both names at
# the wrong glyph with nothing to notice it.
ICONS = [
    ('SPX_ICON_DIAG', 'alert-circle-outline', 'Diagnostics -- the panel that says what is wrong'),
    ('SPX_ICON_VARS', 'variable', 'Variables -- definitions and session values'),
    ('SPX_ICON_SET', 'content-duplicate', 'Variants -- the generated set and its export'),
    ('SPX_ICON_GROUP', 'code-braces', 'the group editor -- {a|b} is what it edits'),
    # The user's call 2026-07-29, and the right one. A die says "random", which is what
    # the feature IS, but at 16 px dice-multiple was a blob and dice-5-outline read as a
    # picture of a die rather than as a button. `sync` says "do it again" -- the thing the
    # user actually wants from it -- and is the most legible of the five candidates that
    # were rendered side by side at 16 and 20. `cached` is the same shape rotated and is
    # one line away if it reads better in place.
    ('SPX_ICON_REROLL', 'sync', 'Reroll -- another draw of the same template'),
    ('SPX_ICON_COPY', 'content-copy', 'Copy the result'),
    ('SPX_ICON_PAGE', 'eye-outline', 'the preview as a rendered page'),
    ('SPX_ICON_SOURCE', 'code-tags', 'the preview as the source behind it'),
    ('SPX_ICON_CLOSE', 'close', 'close a slide-out panel'),
    # Not used yet, and here on purpose (the user's call 2026-07-29): the AI work is R1, and
    # an icon added when the feature lands is an icon chosen in a hurry. Outline, like the
    # rest of this set.
    ('SPX_ICON_AI', 'robot-outline', 'the AI features, when they arrive (R1)'),
]

# Two homes, two ladders. The rail's face is 36 px and its icon 24, so 24/30/36/48 are that
# icon at 100/125/150/200%. The top strip's buttons are 26 px and their icon 16, so 16/20/24/32
# are the same ladder for them -- 24 does double duty. Sizes cost bytes in the exe: add one when
# something asks for it, rather than in case.
SIZES = sorted(set([16, 20, 24, 30, 32, 36, 48]))   # sorted: the picker keeps the last that fits

# Dark grey rather than black: the rail is a shade off the window, and pure black on it reads
# as heavier than the text beside it.
COLOUR = (60, 60, 60, 255)

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def codepoints(css_path):
    """name -> codepoint, read from the font's own CSS rather than a table typed by hand."""
    css = io.open(css_path, encoding='utf-8').read()
    out = {}
    for _, name, _ in ICONS:
        at = css.find('.mdi-' + name + '::before')
        if at < 0:
            raise SystemExit('no such icon in this font: ' + name)
        seg = css[at:at + 140]
        q1 = seg.find('"')
        q2 = seg.find('"', q1 + 1)
        out[name] = int(seg[q1 + 1:q2].lstrip(chr(92)), 16)
    return out


def glyph(font_path, code, px):
    """One glyph, centred on what is actually drawn rather than on the em box."""
    img = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ch = chr(code)
    f = ImageFont.truetype(font_path, px)
    box = d.textbbox((0, 0), ch, font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    if w > px or h > px:
        f = ImageFont.truetype(font_path, int(px * px / max(w, h)))
        box = d.textbbox((0, 0), ch, font=f)
        w, h = box[2] - box[0], box[3] - box[1]
    d.text(((px - w) / 2 - box[0], (px - h) / 2 - box[1]), ch, font=f, fill=COLOUR)
    return img


def pascal_bytes(name, data):
    lines = ['  %s: array[0..%d] of Byte = (' % (name, len(data) - 1)]
    row = []
    for i, b in enumerate(data):
        row.append('$%02X' % b)
        if len(row) == 16:
            lines.append('    ' + ', '.join(row) + (',' if i < len(data) - 1 else ''))
            row = []
    if row:
        lines.append('    ' + ', '.join(row))
    lines.append('  );')
    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    font_path = sys.argv[1]
    css_path = os.path.join(os.path.dirname(font_path), '..', 'css',
                            'materialdesignicons.css')
    if not os.path.exists(css_path):
        css_path = os.path.join(os.path.dirname(font_path), 'mdi.css')
    codes = codepoints(css_path)

    out_dir = os.path.join(HERE, 'assets', 'icons')
    os.makedirs(out_dir, exist_ok=True)
    blobs = []
    for px in SIZES:
        strip = Image.new('RGBA', (px * len(ICONS), px), (0, 0, 0, 0))
        for i, (_, name, _) in enumerate(ICONS):
            strip.paste(glyph(font_path, codes[name], px), (i * px, 0))
        path = os.path.join(out_dir, 'rail-%d.png' % px)
        strip.save(path)
        buf = io.BytesIO()
        strip.save(buf, format='PNG')
        blobs.append((px, buf.getvalue()))
        print('%-28s %d x %d' % (os.path.relpath(path, HERE), strip.width, strip.height))

    unit = ['(*',
            ' * SpxIcons -- the rail\'s icons, as bytes.',
            ' *',
            ' * GENERATED by scripts/make-icons.py from the Material Design Icons webfont',
            ' * (pictogrammers.com, Apache-2.0). Do not edit: add an icon to the script and',
            ' * run it again. The credit belongs in the About box and the NOTICE, not only here.',
            ' *',
            ' * One PNG strip per size, sliced into an image list at run time -- which is what a',
            ' * sprite is called in LCL. The bytes travel INSIDE the executable because R0 ships',
            ' * as one offline file (spec §11).',
            ' *)',
            'unit SpxIcons;',
            '',
            '{$mode objfpc}{$H+}',
            '',
            'interface',
            '',
            'const',
            '  { The icons in the strip, in order. }'] +            ['  %s = %d;' % (name, i) for i, (name, _, _) in enumerate(ICONS)] +            ['  SPX_ICON_COUNT = %d;' % len(ICONS),
            '',
            '  { The sizes there are strips for, ascending. }',
            '  SPX_ICON_SIZES: array[0..%d] of Integer = (%s);' %
            (len(SIZES) - 1, ', '.join(str(s) for s in SIZES)),
            '',
            '{ The strip to use for an AWanted px face: the largest one that still FITS. An',
            '  image list draws at its own size rather than at the face size, so a bigger',
            '  would be clipped, not shrunk. The scalings Windows offers all have an exact',
            '  strip; a size between them lands on the one below and is centred.',
            '',
            '  BELOW THE SMALLEST STRIP there is nothing to return but the smallest strip,',
            '  so that is what comes back -- larger than asked for. It takes a face under',
            '  %d px to reach, which is a display no version of Windows offers. }' % SIZES[0],
            'function SpxIconPickSize(AWanted: Integer): Integer;',
            '',
            '{ The PNG strip for a size SpxIconPickSize returned -- byte for byte the file in',
            '  assets/icons. It is a pointer INTO the executable image: read it, do not free',
            '  it, and do not write through it. }',
            'function SpxIconStrip(ASize: Integer; out ALen: Integer): Pointer;',
            '',
            'implementation',
            '',
            'const']
    for px, data in blobs:
        unit.append('  { %d px strip, %d icons wide }' % (px, len(ICONS)))
        unit.append(pascal_bytes('SPX_RAIL_%d' % px, data))
        unit.append('')
    unit += ['function SpxIconPickSize(AWanted: Integer): Integer;',
             'var i: Integer;',
             'begin',
             '  Result := SPX_ICON_SIZES[Low(SPX_ICON_SIZES)];',
             '  for i := Low(SPX_ICON_SIZES) to High(SPX_ICON_SIZES) do',
             '    if SPX_ICON_SIZES[i] <= AWanted then Result := SPX_ICON_SIZES[i];',
             'end;',
             '',
             'function SpxIconStrip(ASize: Integer; out ALen: Integer): Pointer;',
             'begin',
             '  case ASize of']
    for px, _ in blobs:
        unit.append('    %d: begin Result := @SPX_RAIL_%d[0]; ALen := Length(SPX_RAIL_%d); end;'
                    % (px, px, px))
    unit += ['  else',
             '    { Not one of ours: the rail\'s own size, so a caller that computed a size',
             '      some other way still gets icons rather than an empty strip. }',
             '    Result := @SPX_RAIL_24[0];',
             '    ALen := Length(SPX_RAIL_24);',
             '  end;',
             'end;',
             '',
             'end.',
             '']

    unit_path = os.path.join(HERE, 'gui', 'SpxIcons.pas')
    io.open(unit_path, 'w', encoding='utf-8', newline='').write('\n'.join(unit))
    print('%-28s %d bytes' % (os.path.relpath(unit_path, HERE),
                              os.path.getsize(unit_path)))


if __name__ == '__main__':
    main()
