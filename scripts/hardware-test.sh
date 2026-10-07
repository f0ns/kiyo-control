#!/bin/sh
# Hardware test for the Razer-specific settings: toggles each one on a plugged-in Kiyo Pro Ultra,
# grabs a frame before and after, and checks the picture changed the expected way.
# Frames are kept in $OUT for inspection. Unplug and replug the camera afterwards to return to
# the settings stored in the camera (nothing here is saved to it).
cd "$(dirname "$0")/.."
[ -d /Applications/Xcode.app ] && export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --product kiyoctl >/dev/null || exit 1
K=.build/debug/kiyoctl
OUT=${1:-build/hardware-test}
mkdir -p "$OUT"
PASS=0; FAIL=0

isp() { $K isp "$@" >/dev/null || echo "  command $* failed"; }
shot() { $K snap "$OUT/$1.jpg" >/dev/null; }
field() { $K stats "$OUT/$1.jpg" "$OUT/$2.jpg" | awk -v f="$3" '{ for (i = 1; i < NF; i++) if ($i == f) print $(i + 1) }'; }
check() { # name, condition description, awk boolean expression
    if awk "BEGIN { exit !($3) }"; then echo "PASS  $1  ($2)"; PASS=$((PASS + 1)); else echo "FAIL  $1  ($2)"; FAIL=$((FAIL + 1)); fi
}

echo "Mirror"
isp c0 0e 03 00; shot mirror-off
isp c0 0e 03 01; shot mirror-on
isp c0 0e 03 00
d=$(field mirror-off mirror-on diff); m=$(field mirror-off mirror-on diff-to-mirrored)
check "mirror" "diff $d, diff to mirrored $m" "$m < $d / 2"

echo "Exposure compensation (auto exposure)"
$K set autoExposure 8 >/dev/null
isp c0 0e 05 0a; shot ev-minus2
isp c0 0e 05 32; shot ev-plus2
isp c0 0e 05 1e
a=$(field ev-minus2 ev-plus2 brightness); b=$(field ev-plus2 ev-minus2 brightness)
check "exposure compensation" "brightness -2 EV $a, +2 EV $b" "$b > $a + 15"

echo "Metering"
isp c0 0e 04 00; shot meter-average
isp c0 0e 04 01; shot meter-center
isp c0 0e 04 00
a=$(field meter-average meter-center brightness); b=$(field meter-center meter-average brightness)
echo "INFO  metering  (brightness average $a, center $b; depends on the scene)"

echo "ISO (manual exposure)"
$K set autoExposure 1 >/dev/null
isp c0 09 05 00 00 41 1a 00   # 1/60 s
isp c0 09 01 01; shot iso-100
isp c0 09 01 05; shot iso-1600
a=$(field iso-100 iso-1600 brightness); b=$(field iso-1600 iso-100 brightness)
check "ISO" "brightness ISO 100 $a, ISO 1600 $b" "$b > $a + 15"

echo "Shutter (manual exposure)"
isp c0 09 01 03                # ISO 400
isp c0 09 05 00 00 07 d0 00; shot shutter-500   # 1/500 s
isp c0 09 05 00 00 82 35 00; shot shutter-30    # 1/30 s
a=$(field shutter-500 shutter-30 brightness); b=$(field shutter-30 shutter-500 brightness)
check "shutter" "brightness 1/500 $a, 1/30 $b" "$b > $a + 15"
$K set autoExposure 8 >/dev/null

echo "Noise reduction"
isp c0 0e 01 00; shot nr3d-off
isp c0 0e 01 01; shot nr3d-on
a=$(field nr3d-off nr3d-on noise); b=$(field nr3d-on nr3d-off noise)
echo "INFO  3D noise reduction  (noise off $a, on $b; clearer in low light)"
isp c0 0e 02 00; shot nr2d-off
isp c0 0e 02 01; shot nr2d-on
a=$(field nr2d-off nr2d-on noise); b=$(field nr2d-on nr2d-off noise)
echo "INFO  2D noise reduction  (noise off $a, on $b)"

echo "Lens distortion compensation"
isp ff 01 00 03; shot lens-off
isp ff 01 01 03; shot lens-on
isp ff 01 00 03
d=$(field lens-off lens-on diff); n=$(field lens-off lens-off diff)
check "lens correction" "diff off/on $d" "$d > 10"

echo "Autofocus options (reply only)"
for cmd in "c0 0a 01 01" "c0 0a 01 00 00 00 00 01" "c0 0a 01 00" "ff 06 00" "ff 06 01"; do
    echo "INFO  $cmd -> $($K isp $cmd | awk '/reply/ { $1 = ""; print }')"
done

echo
echo "$PASS passed, $FAIL failed. Frames in $OUT"
[ "$FAIL" -eq 0 ]
