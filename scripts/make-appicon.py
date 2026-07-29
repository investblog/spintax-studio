#!/usr/bin/env python3
"""Build the application icon: the .ico, and the Windows resource that carries it into the exe.

THE MARK IS OURS -- it is the spintax.net brand, vendored in assets/brand as the 180 px raster
the site publishes (spintax-mark-180.png) alongside the vector it was drawn from
(spintax-mark.svg, kept for the day someone can rasterise it properly). 180 is the largest
raster the site has, so the icon tops out at 128: Windows only needs 256 for Explorer's largest
view, and an upscale of ours would be no better than the upscale Windows already does. A real
256 wants a vector export -- that is a request to make of the brand, not a thing to fake here.

WHY A SEPARATE .res AND NOT THE PROJECT'S. gui/SpintaxStudio.res is Lazarus's, holding the
manifest, and lazbuild rewrites it from the .lpi whenever the project's own resources change --
an icon hand-added there would disappear on somebody's next build. This one is included by the
program file with its own {$R} and is nobody's to regenerate. The group is named MAINICON,
which is the name LCL itself looks up for Application.Icon, so the window, the taskbar and the
exe all end up with the same picture.

WHY THE .res IS WRITTEN HERE RATHER THAN BY windres. The format is a flat list of records and
this needs three of them; requiring a binutils windres on every machine that touches the icon
(including CI, which builds on ubuntu) is a bigger dependency than fifty lines.

Usage:  python scripts/make-appicon.py

Writes:  assets/brand/spintax.ico   -- the icon, for Windows and for looking at
         gui/SpxAppIcon.res         -- the same images as a resource the linker takes
"""
import io
import os
import struct

from PIL import Image

# What Windows asks for: 16 in the title bar, 32 alt-tab, 48 in Explorer, the rest for the
# larger views and for high-dpi versions of the small ones.
SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128]

RT_ICON = 3
RT_GROUP_ICON = 14

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def res_name(value):
    """A resource type or name: an ordinal, or a UTF-16 string ending in a null."""
    if isinstance(value, int):
        return struct.pack('<HH', 0xFFFF, value)
    return value.encode('utf-16-le') + b'\x00\x00'


def res_entry(rtype, name, data, flags=0x1030, lang=0):
    """One record of a .res file: header, then the data, both padded to four bytes."""
    head = res_name(rtype) + res_name(name)
    head += b'\x00' * ((4 - len(head) % 4) % 4)
    #        DataVersion, MemoryFlags (moveable|discardable|pure), LanguageId, Version, Chars
    head += struct.pack('<IHHII', 0, flags, lang, 0, 0)
    header_size = 8 + len(head)
    out = struct.pack('<II', len(data), header_size) + head + data
    return out + b'\x00' * ((4 - len(out) % 4) % 4)


def main():
    src_path = os.path.join(HERE, 'assets', 'brand', 'spintax-mark-180.png')
    src = Image.open(src_path).convert('RGBA')
    print('%-28s %d x %d' % (os.path.relpath(src_path, HERE), src.width, src.height))

    ico_path = os.path.join(HERE, 'assets', 'brand', 'spintax.ico')
    # bitmap_format='bmp' IS THE WHOLE POINT of this line. Pillow will otherwise write every
    # frame as a PNG inside the .ico, which Windows itself reads happily -- Explorer, the
    # taskbar, ExtractAssociatedIcon -- and LCL does not: TIcon only looks for a PNG when the
    # directory entry's width is 0, the 256x256 convention (icon.inc:880-897), and reads
    # everything else as a DIB. A PNG read as a DIB is a modal "Bitmap with unknown
    # compression (268435456)" at startup, which is how this was found: by the app refusing
    # to open, after the icon had been "verified" through Windows rather than through LCL.
    src.save(ico_path, format='ICO', sizes=[(s, s) for s in SIZES], bitmap_format='bmp')
    print('%-28s %s' % (os.path.relpath(ico_path, HERE),
                        ', '.join('%d' % s for s in SIZES)))

    # Read back what Pillow actually wrote, rather than re-encoding: the resource must carry
    # the same bytes the .ico does, or the two pictures could drift apart.
    blob = io.open(ico_path, 'rb').read()
    count, = struct.unpack_from('<H', blob, 4)
    images = []
    for i in range(count):
        w, h, colours, _, planes, bits, size, offset = struct.unpack_from(
            '<BBBBHHII', blob, 6 + i * 16)
        frame = blob[offset:offset + size]
        # The check that would have caught it. A PNG frame is legal in an .ico ONLY where the
        # entry says width 0; anywhere else it is a picture half the world cannot read.
        if frame[:4] == b'\x89PNG' and w != 0:
            raise SystemExit('the %dx%d frame is a PNG but its entry says %d wide -- LCL will '
                             'read it as a DIB and refuse to start. Pillow needs '
                             "bitmap_format='bmp'." % (w, h, w))
        images.append((w, h, colours, planes, bits, frame))

    # The group: what Windows reads to decide which image to draw at a given size. Its entries
    # are the .ico's, with the file offset replaced by the id of the RT_ICON beside it.
    group = struct.pack('<HHH', 0, 1, len(images))
    body = b''
    for i, (w, h, colours, planes, bits, data) in enumerate(images, start=1):
        group += struct.pack('<BBBBHHIH', w, h, colours, 0, planes, bits, len(data), i)
        body += res_entry(RT_ICON, i, data)

    # The null record every .res starts with -- and it must be ALL zeros past the header
    # size: that is what a reader checks to recognise the format at all. Writing the usual
    # moveable|discardable flags here instead cost a build with "No known file format
    # detected", from a file whose every other byte matched Lazarus's own.
    res = res_entry(0, 0, b'', flags=0)
    res += body
    res += res_entry(RT_GROUP_ICON, 'MAINICON', group)

    res_path = os.path.join(HERE, 'gui', 'SpxAppIcon.res')
    io.open(res_path, 'wb').write(res)
    print('%-28s %d bytes, %d images + the group' %
          (os.path.relpath(res_path, HERE), len(res), len(images)))


if __name__ == '__main__':
    main()
