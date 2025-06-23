#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Default templates file path if not provided via TEMPLATE_FILE
TEMPLATE_FILE="${TEMPLATE_FILE:-$ROOT_DIR/templates.txt}"

[ -f "$TEMPLATE_FILE" ] || { echo "templates.txt not found"; exit 1; }

while IFS= read -r repo; do
    repo="${repo%%#*}"
    repo="${repo//[[:space:]]/}"
    [ -z "$repo" ] && continue
    name="$(basename "$repo" .git)"
    target="$ROOT_DIR/$name"
    if grep -q "path = $name" "$ROOT_DIR/.gitmodules" 2>/dev/null; then
        echo "🔄 Updating submodule $target"
        git submodule update --remote "$target"
    elif [ -d "$target" ]; then
        echo "⚠️ $target exists but is not a submodule. Skipping..."
    else
        echo "🔗 Adding $repo as submodule at $target"
        git submodule add "$repo" "$target"
    fi
    if [ -d "$target/instructions" ]; then
        echo "Found instructions in $target"
    fi
done < "$TEMPLATE_FILE"

cd "$ROOT_DIR"

echo "✅ Templates synced."
