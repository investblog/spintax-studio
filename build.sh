#!/bin/sh
# Build Studio's test binaries. Requires Free Pascal 3.2.2+ and the engine submodule.
#
# There is no application target yet: M0 is editor-core and is verified without a window
# (spec §9). When M1 adds the Lazarus project this script grows a `lazbuild` step; until
# then a green build means "the pinned engine and this layer compile and their assertions
# hold", which is exactly what the hooks and CI gate.
set -e

# The engine is a submodule pinned to a tag (ADR 0001). A clone without --recurse-submodules
# leaves engine/ empty, and the compiler error for that ("Can't find unit Spintax") points
# nowhere near the cause.
if [ ! -f engine/src/Spintax.pas ]; then
  echo "engine/ is empty - run: git submodule update --init" >&2
  exit 1
fi

# Always start from an empty unit cache. FPC reuses .ppu files it finds here, and the
# engine repo has already been bitten by a leftover unit built under different switches
# producing a DIFFERENT result from the same sources.
rm -rf lib
mkdir -p lib
fpc -Mdelphi -Fusrc -Fugui -Fuengine/src -FUlib -O2 tests/studio_tests.dpr -otests/studio_tests

# Second build with overflow and range checks ON (-Co -Cr), into its own unit dir so it
# cannot poison the optimised one. This reproduces Delphi's Debug configuration, which is
# how an EIntOverflow in the engine's mulberry32 mixer once reached a released tree: FPC's
# default build wraps silently, Delphi's Debug build raises.
mkdir -p lib/checked
fpc -Mdelphi -Co -Cr -Fusrc -Fugui -Fuengine/src -FUlib/checked tests/studio_tests.dpr \
  -otests/studio_tests_checked

# The GUI needs Lazarus (LCL + SynEdit), which plain fpc cannot see. It is built when
# lazbuild is around and skipped -- loudly -- when it is not: editor-core and its suite are
# complete without a window, so a contributor without Lazarus should still get a green
# build.sh rather than a wall of "Can't find unit Forms".
lazbuild_exe=""
for candidate in lazbuild /c/lazarus/lazbuild.exe "$LAZARUS_DIR/lazbuild"; do
  if command -v "$candidate" >/dev/null 2>&1; then lazbuild_exe="$candidate"; break; fi
done

if [ -n "$lazbuild_exe" ]; then
  "$lazbuild_exe" gui/SpintaxStudio.lpi >/dev/null
  echo "built: tests/studio_tests(+checked), spintax-studio"
else
  echo "built: tests/studio_tests(+checked)"
  echo "note: lazbuild not found - the GUI was skipped (install Lazarus to build the app)" >&2
fi
