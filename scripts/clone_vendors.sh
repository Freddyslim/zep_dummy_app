#!/bin/bash
set -euo pipefail

# Colors for output
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"

[ -n "${DEBUG:-}" ] && set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$ROOT_DIR/vendor"

mkdir -p "$VENDOR_DIR"

# gather apps.json files from root and template directories
APP_FILES=()
if [ -f "$ROOT_DIR/apps.json" ]; then
    APP_FILES+=("$ROOT_DIR/apps.json")
fi
while IFS= read -r f; do
    APP_FILES+=("$f")
done < <(find "$ROOT_DIR" -maxdepth 2 -path "*template*/apps.json" 2>/dev/null | sort)

if [ "${#APP_FILES[@]}" -eq 0 ]; then
    echo -e "${RED}❌ No apps.json files found${RESET}"
    exit 1
fi

# associative arrays for repo url and tag
declare -A REPOS
declare -A TAGS

for file in "${APP_FILES[@]}"; do
    echo -e "${BLUE}📄 Reading $file${RESET}"
    while IFS='|' read -r name repo tag; do
        [ -z "$name" ] && continue
        REPOS["$name"]="$repo"
        TAGS["$name"]="$tag"
    done < <(jq -r 'to_entries[] | "\(.key)|\(.value.repo)|\(.value.branch // .value.tag)"' "$file")
 done

changes=false

for app in "${!REPOS[@]}"; do
    repo="${REPOS[$app]}"
    tag="${TAGS[$app]}"
    target="$VENDOR_DIR/$app"

    echo -e "${BLUE}➡️  Processing $app ($tag)${RESET}"

    if grep -q "path = vendor/$app" "$ROOT_DIR/.gitmodules" 2>/dev/null; then
        git submodule update --init "vendor/$app"
    else
        git submodule add "$repo" "vendor/$app" || true
        changes=true
    fi

    pushd "$target" >/dev/null
    git fetch --tags
    git checkout "$tag"
    popd >/dev/null
 done

# rebuild apps.json
filter='{}'
for app in "${!REPOS[@]}"; do
    repo="${REPOS[$app]}"
    tag="${TAGS[$app]}"
    filter="$filter | .[\"$app\"]={repo:\"$repo\",branch:\"$tag\"}"
 done
 jq -n "$filter" > "$ROOT_DIR/apps.json"

# rebuild codex.json
sources=("app/")
for app in "${!REPOS[@]}"; do
    sources+=("vendor/$app/")
 done
sources+=("instructions/" "sample_data/")

sources_json=$(printf '%s\n' "${sources[@]}" | jq -R '.' | jq -s '.')

jq -n --argjson s "$sources_json" '{"_comment":"Directories indexed by Codex. Adjust paths as needed.","sources":$s}' > "$ROOT_DIR/codex.json"

echo -e "${GREEN}✅ Vendor repositories cloned.${RESET}"
