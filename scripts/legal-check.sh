#!/bin/sh
# Guards the repository against proprietary material. Run in CI and before releases.
# Fails when it finds third-party binaries, foreign copyright notices, or Razer/Synapse files.
cd "$(dirname "$0")/.."
FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }

FILES=$(git ls-files)

# 1. Only our own binary files are allowed (the icon is drawn by scripts/make-icon.swift).
ALLOWED_BINARIES="Resources/AppIcon.icns"
for f in $FILES; do
    case "$f" in *.swift|*.c|*.h|*.sh|*.md|*.yml|*.json|.gitignore|LICENSE) continue ;; esac
    if [ -n "$(grep -Il . "$f" 2>/dev/null)" ]; then continue; fi  # text file
    echo "$ALLOWED_BINARIES" | grep -qx "$f" || fail "unexpected binary file: $f"
done

# 2. No executables, drivers or installers from other software.
echo "$FILES" | grep -iE '\.(exe|dll|sys|msi|cab|inf|bin|fw|img|dmg|pkg)$' && fail "proprietary-looking file type in repo"

# 3. No copyright notices other than ours, and nothing claiming to be from Razer.
git grep -n -i -E 'copyright' -- . ':!LICENSE' ':!scripts/legal-check.sh' ':!README.md' \
    | grep -v -i 'kiyo control contributors' && fail "foreign copyright notice"
git grep -n -i -E '(©|\(c\)) *(20[0-9]{2} *)?razer' -- . ':!scripts/legal-check.sh' && fail "Razer copyright notice"
git grep -n -i -E 'synapse.*\.(dll|exe)|razer.*\.(png|jpg|svg|ico)' -- . ':!scripts/legal-check.sh' && fail "Razer/Synapse file reference"

# 4. The project license and the trademark disclaimer must be present.
grep -q "MIT License" LICENSE || fail "LICENSE is not MIT"
grep -q "not affiliated with" README.md || fail "README lacks the trademark disclaimer"

[ $FAIL -eq 0 ] && echo "legal check passed"
exit $FAIL
