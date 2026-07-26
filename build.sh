#!/bin/sh
# Build Studio's test binaries. Requires Free Pascal 3.2.2+ and the engine submodule.
#
# There is no application target yet: M0 is editor-core and is verified without a window
# (spec §9). When M1 adds the Lazarus project this script grows a `lazbuild` step; until
# then a green build means "the pinned engine and this layer compile and their assertions
# hold", which is exactly what the hooks and CI gate.
set -e

# Neither installer on Windows puts fpc on PATH, and dying with "fpc: command not found" next
# to a perfectly good Lazarus is a bad first five minutes. Look where the compiler actually
# lives -- the same resolution the git gate uses, so both agree on which one runs. On Linux
# and macOS fpc is already on PATH and this loop does nothing.
if ! command -v fpc >/dev/null 2>&1; then
  for dir in "${AGENTS_FPC:-}" /c/FPC/*/bin/* /c/lazarus/fpc/*/bin/*; do
    if [ -x "$dir/fpc" ] || [ -x "$dir/fpc.exe" ]; then
      PATH="$dir:$PATH"
      export PATH
      break
    fi
  done
fi

if ! command -v fpc >/dev/null 2>&1; then
  echo "fpc not found - install Free Pascal, or point AGENTS_FPC at its bin directory" >&2
  exit 1
fi

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
  # Quiet on success, loud on failure. lazbuild reports its errors on STDOUT, so redirecting
  # it to /dev/null turns a real failure -- "Can't create executable" while the app is still
  # running is the everyday one -- into a bare `exit 2` with nothing to read.
  # Filtered, because a failing lazbuild prints some ninety lines of Info/Hint bookkeeping
  # and the one line that says WHY is at the bottom. If nothing matches, dump it all rather
  # than report a failure with no text.
  if ! laz_out=$("$lazbuild_exe" gui/SpintaxStudio.lpi 2>&1); then
    printf '%s\n' "$laz_out" | grep -E 'Error|Fatal' >&2 || printf '%s\n' "$laz_out" >&2
    exit 1
  fi
  # gui/ is the one layer the hook's -Sew pass skips (it cannot see the LCL), so a warning
  # here has nowhere else to surface. Everything else stays quiet.
  printf '%s\n' "$laz_out" | grep -E 'Warning|Error' >&2 || true
  echo "built: tests/studio_tests(+checked), spintax-studio"
else
  echo "built: tests/studio_tests(+checked)"
  echo "note: lazbuild not found - the GUI was skipped (install Lazarus to build the app)" >&2
fi
