#!/bin/bash
# Creates a new shop app for iPhone Duo from the recipe-shop template: a product grid, a
# basket and a paywall, with StoreKit 2 and a local StoreKit configuration.
#
#   new-project.sh <AppName> <bundle-id> <dest-dir>
#
#   AppName    letters and digits, starting with a letter. It becomes the Xcode
#              target, the scheme and a Swift type name (<AppName>App). Not Tools,
#              and not the name of an Apple module such as SwiftUI or Foundation.
#   bundle-id  reverse-DNS, for example com.example.soundshop
#   dest-dir   the new project folder. It must not exist yet, or be empty.
#
# Example:
#   new-project.sh SoundShop com.example.soundshop ~/Developer/SoundShop
set -euo pipefail

usage() {
  echo "usage: $(basename "$0") <AppName> <bundle-id> <dest-dir>" >&2
  exit 64
}

[[ $# -eq 3 ]] || usage
NAME="$1"
BUNDLE="$2"
DEST="$3"

if [[ ! "$NAME" =~ ^[A-Za-z][A-Za-z0-9]{0,39}$ ]]; then
  echo "error: AppName must start with a letter and use only letters and digits (max 40): '$NAME'" >&2
  exit 65
fi
# The app folder can't share a name with the template's Tools/ or StoreKit/ folder, and the app module
# can't share one with a module it imports. Compare in lower case: macOS folders usually
# ignore case. Checked before anything is created, so a refusal leaves nothing behind.
case "$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')" in
  tools|storekit|storekittest|swift|swiftui|foundation|uikit|xctest|xcuiautomation|observation|combine|coregraphics|darwin|dispatch|os)
    echo "error: AppName '$NAME' clashes with the template's Tools or StoreKit folder or an Apple module. Pick another name." >&2
    exit 65
    ;;
esac
if [[ ! "$BUNDLE" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "error: bundle id must look like com.example.app (letters, digits, hyphens, dots): '$BUNDLE'" >&2
  exit 65
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$(cd "$SCRIPT_DIR/../template" && pwd)"

if [[ -e "$DEST" ]]; then
  if [[ ! -d "$DEST" || -n "$(ls -A "$DEST")" ]]; then
    echo "error: '$DEST' already exists and is not an empty folder. Pick a new folder." >&2
    exit 73
  fi
fi
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

# 1. Copy the template, without build output or per-user Xcode state.
(cd "$TEMPLATE" && tar -cf - \
  --exclude './build' --exclude 'DerivedData' --exclude 'xcuserdata' \
  --exclude '*.xcresult' --exclude '.DS_Store' .) | (cd "$DEST" && tar -xf -)

# 2. Rename files and folders, deepest first so parent paths stay valid.
find "$DEST" -depth -name '*__APP_NAME__*' | while IFS= read -r path; do
  base="$(basename "$path")"
  mv "$path" "$(dirname "$path")/${base//__APP_NAME__/$NAME}"
done

# 3. Replace the placeholders inside text files. `cat >` keeps each file's permissions.
grep -rlI --null -e '__APP_NAME__' -e '__BUNDLE_ID__' "$DEST" | while IFS= read -r -d '' file; do
  LC_ALL=C sed -e "s/__APP_NAME__/$NAME/g" -e "s/__BUNDLE_ID__/$BUNDLE/g" "$file" > "$file.new"
  cat "$file.new" > "$file"
  rm "$file.new"
done

# 4. Check nothing was missed.
if grep -rlI -e '__APP_NAME__' -e '__BUNDLE_ID__' "$DEST" >/dev/null \
   || [[ -n "$(find "$DEST" -name '*__APP_NAME__*' -print -quit)" ]]; then
  echo "error: placeholders left in $DEST:" >&2
  grep -rlI -e '__APP_NAME__' -e '__BUNDLE_ID__' "$DEST" >&2 || true
  find "$DEST" -name '*__APP_NAME__*' >&2
  exit 70
fi
chmod +x "$DEST"/Tools/*.sh

echo "Created $NAME ($BUNDLE) in $DEST"
echo
echo "Next steps:"
echo "  cd \"$DEST\""
printf '  %-34s %s\n' "Tools/run-model-tests.sh" "# basket, checkout and catalog rules, on this Mac"
printf '  %-34s %s\n' "open $NAME.xcodeproj" "# pick the iPhone Duo simulator, then Run"
printf '  %-34s %s\n' "Tools/run-ui-tests.sh" "# UI tests on the iPhone Duo simulator"
cat <<EOF

Build from Terminal:
  DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \\
  xcodebuild -project $NAME.xcodeproj -scheme $NAME \\
    -destination 'platform=iOS Simulator,name=iPhone Duo' \\
    -derivedDataPath build/DerivedData build

Products come from StoreKit/Shop.storekit (the scheme's StoreKit configuration), with no
network. Replace the sample in $NAME/Model/SampleCatalog.swift and that file together.
EOF
