#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/common_setup.sh"

TEMPLATE_FILE="$ROOT_DIR/templates.txt"

[ -f "$TEMPLATE_FILE" ] || { echo "templates.txt not found"; exit 1; }

while IFS= read -r repo; do
    repo="${repo%%#*}"
    repo="${repo//[[:space:]]/}"
    [ -z "$repo" ] && continue
    name="$(basename "$repo" .git)"
    target="$ROOT_DIR/$name"
    if [ ! -d "$target/.git" ]; then
        echo "📥 Cloning $repo into $target"
        git clone "$repo" "$target"
    else
        echo "🔄 Updating $target"
        git -C "$target" pull --ff-only
    fi
    if [ -d "$target/instructions" ]; then
        echo "Found instructions in $target"
    fi
done < "$TEMPLATE_FILE"

cd "$ROOT_DIR"
generate_codex_json

echo "✅ Templates synced."
