#!/usr/bin/env python3
"""Build the diagnostics panel's severity glyphs: three shapes, as one strip per size.

WHY A GLYPH AND NOT A COLOUR, which is what the backlog asked for. Measured, twice, on the
running window: LCL's TListView DOES call OnCustomDrawItem on Windows -- a probe's own handler
ran once per row -- and then discards what the handler put on the canvas. The reason is in the
widgetset: `win32wscustomlistview.inc` copies `Canvas.Font.Color` into `clrText`, but LCL's
result mapping has no CDRF_NEWFONT, which is what comctl32 requires before it will honour a
colour change. Forcing red text on a yellow background changed not one pixel.

The way that WOULD work is owner draw, and it costs the thing this list should not lose: the
locale list next door is owner-drawn and is invisible to a screen reader. So the level is shown
by an icon the native control draws, beside the word it already shows.

TWO CUES, NOT ONE. The shapes differ as well as the colours -- circle, triangle, square -- so
the panel is readable to someone who cannot separate red from amber, and the word in the level
column is still there for anyone reading it aloud. A list that says "error" in red and nowhere
else is a list that says nothing to a third of the people who open it.

Pure Pillow and stdlib, run by hand like the other image generators. Drawn at 4x and reduced,
because a 16 px triangle drawn at 16 px has stairs on it.

Usage:  python scripts/make-sevicons.py

Writes: gui/SpxSevIcons.pas
"""
import io
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, 'gui', 'SpxSevIcons.pas')

# 16 at 100%, and what Windows asks for at 125 / 150 / 200.
SIZES = [16, 20, 24, 32]
SUPER = 4          # drawn this many times larger, then reduced

# The colours are the ones the palette carried while the colour approach was alive, kept here
# because this is now the only place they are used. Chosen to read on white AND on a dark
# window colour, since the list is not themed and sits on whichever the desktop has.
# ONE LIST DECIDES BOTH the order the glyphs are pasted in and the constants the panel indexes
# by. They were two literals in the first draft, and nothing checked them against each other:
# reordering the paste list would have painted a red circle on every warning, with a green
# build. Found by review.
KINDS = [
    ('ERROR', 'circle', (197, 35, 52, 255)),    # #C52334
    ('WARN', 'triangle', (224, 168, 0, 255)),   # #E0A800
    # A level that says nothing is wrong should not shout; the square is the quietest shape.
    ('NOTE', 'square', (128, 128, 128, 255)),
]


def fail(message):
    raise SystemExit('make-sevicons: %s' % message)


def glyph(shape, colour, side):
    """One glyph, centred, with two pixels of air so it does not touch the row above."""
    big = side * SUPER
    im = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pad = SUPER * 2                      # two pixels at final size
    box = (pad, pad, big - pad - 1, big - pad - 1)
    if shape == 'circle':
        d.ellipse(box, fill=colour)
    elif shape == 'triangle':
        # Standing on its base, which is what a warning is everywhere.
        d.polygon([((box[0] + box[2]) // 2, box[1]), (box[2], box[3]), (box[0], box[3])],
                  fill=colour)
    elif shape == 'square':
        inset = (box[2] - box[0]) // 8
        d.rectangle((box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset),
                    fill=colour)
    else:
        fail('no such shape: %s' % shape)
    return im.resize((side, side), Image.LANCZOS)


def strip(side):
    """The glyphs in a row, which is what an image list slices."""
    out = Image.new('RGBA', (side * len(KINDS), side), (0, 0, 0, 0))
    for i, (_, shape, colour) in enumerate(KINDS):
        out.paste(glyph(shape, colour, side), (i * side, 0))
    buf = io.BytesIO()
    out.save(buf, format='PNG', optimize=True)
    data = buf.getvalue()
    # READ BACK, and not only for its size: the colour is the half a reader actually sees, and
    # nothing else in the chain would notice if a glyph came out of the reduction grey. Each
    # cell is sampled at its own centre, where every one of these shapes is solid.
    back = Image.open(io.BytesIO(data)).convert('RGBA')
    if (back.width, back.height) != (side * len(KINDS), side):
        fail('the %d px strip came back %dx%d' % (side, back.width, back.height))
    for i, (name, _, colour) in enumerate(KINDS):
        got = back.getpixel((i * side + side // 2, side // 2))
        if got != colour:
            fail('the %d px %s glyph is %s at its centre, not %s' % (side, name, got, colour))
    return data


def pas_bytes(name, data):
    out = ['  %s: array[0..%d] of Byte = (' % (name, len(data) - 1)]
    for i in range(0, len(data), 16):
        out.append('    ' + ', '.join('$%02X' % b for b in data[i:i + 16]) +
                   (',' if i + 16 < len(data) else ''))
    out.append('  );')
    return out


def main():
    strips = [(s, strip(s)) for s in SIZES]

    u = ['(*',
         ' * SpxSevIcons -- the diagnostics panel\'s three levels, as bytes.',
         ' *',
         ' * GENERATED by scripts/make-sevicons.py. Do not edit: change the script and run it',
         ' * again.',
         ' *',
         ' * AN ICON AND NOT A COLOUR, because the colour could not be made to work: LCL calls',
         ' * OnCustomDrawItem on Windows and then drops what the handler puts on the canvas,',
         ' * having no CDRF_NEWFONT to return (measured on the running window, twice). Owner',
         ' * draw would work and would cost the list its accessibility, which is the trade the',
         ' * locale list already lost.',
         ' *',
         ' * THREE SHAPES, not three colours: circle, triangle, square. The colours help whoever',
         ' * can use them; the shapes are for whoever cannot, and the word in the level column is',
         ' * for whoever is listening rather than looking.',
         ' *)',
         'unit SpxSevIcons;',
         '',
         '{$mode objfpc}{$H+}',
         '',
         'interface',
         '',
         'const',
         '  { The order in the strip, which is the ImageIndex a row carries. }'] + [
         '  SPX_SEV_%s = %d;' % (name, i) for i, (name, _, _) in enumerate(KINDS)] + [
         '  SPX_SEV_COUNT = %d;' % len(KINDS),
         '',
         '  { The sizes there are strips for, ascending. }',
         '  SPX_SEV_SIZES: array[0..%d] of Integer = (%s);'
         % (len(SIZES) - 1, ', '.join(str(s) for s in SIZES)),
         '',
         '{ The widest strip that fits, or the smallest when nothing does -- the rule',
         '  SpxIconPickSize uses, so every glyph in this window is chosen the same way. }',
         'function SpxSevPickSize(AWanted: Integer): Integer;',
         '',
         '{ The PNG strip for a size, byte for byte. A pointer INTO the executable image: read',
         '  it, do not free it, and do not write through it. }',
         'function SpxSevStrip(ASize: Integer; out ALen: Integer): Pointer;',
         '',
         'implementation',
         '',
         'const']
    for i, (side, data) in enumerate(strips):
        u.append('  { %d px, three glyphs wide }' % side)
        u += pas_bytes('SPX_SEV_%d' % side, data)
        if i < len(strips) - 1:
            u.append('')
    u += ['',
          'function SpxSevPickSize(AWanted: Integer): Integer;',
          'var i: Integer;',
          'begin',
          '  Result := SPX_SEV_SIZES[Low(SPX_SEV_SIZES)];',
          '  for i := Low(SPX_SEV_SIZES) to High(SPX_SEV_SIZES) do',
          '    if SPX_SEV_SIZES[i] <= AWanted then Result := SPX_SEV_SIZES[i];',
          'end;',
          '',
          'function SpxSevStrip(ASize: Integer; out ALen: Integer): Pointer;',
          'begin',
          '  ALen := 0;',
          '  Result := nil;',
          '  case ASize of']
    for side, data in strips:
        u.append('    %d: begin Result := @SPX_SEV_%d[0]; ALen := Length(SPX_SEV_%d); end;'
                 % (side, side, side))
    u += ['  else',
          '    { A size nobody asked for still gets a strip rather than nothing -- the same',
          '      fallback SpxIconStrip carries, so a caller that has to guard for nil is',
          '      guarding against something that cannot happen. }',
          '    Result := @SPX_SEV_%d[0]; ALen := Length(SPX_SEV_%d);' % (SIZES[0], SIZES[0]),
          '  end;',
          'end;',
          '',
          'end.',
          '']

    io.open(OUT, 'w', encoding='utf-8', newline='').write('\n'.join(u))
    for side, data in strips:
        print('  %2d px strip  %5d bytes' % (side, len(data)))
    print('%-30s %d bytes' % (os.path.relpath(OUT, HERE), os.path.getsize(OUT)))


if __name__ == '__main__':
    main()
