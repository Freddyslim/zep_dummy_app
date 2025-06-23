#!/bin/bash
set -euo pipefail

# Farben
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"

[ -n "${DEBUG:-}" ] && set -x
REPAIR_BROKEN_SUBMODULES="${REPAIR_BROKEN_SUBMODULES:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="${TEMPLATE_FILE:-$ROOT_DIR/templates.txt}"

echo -e "${BLUE}📄 Reading templates from: ${TEMPLATE_FILE}${RESET}"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}❌ templates.txt not found: $TEMPLATE_FILE${RESET}"
    exit 1
fi

sanitize_line() {
    local line="$1"
    echo "$line" | sed 's/#.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

changes_made=false

while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    repo="$(sanitize_line "$raw_line")"
    [ -z "$repo" ] && continue

    name="$(basename "$repo" .git)"
    target="$ROOT_DIR/$name"

    echo -e "${BLUE}➡️  Processing: $repo${RESET}"

    if grep -q "path = $name" "$ROOT_DIR/.gitmodules" 2>/dev/null; then
        echo -e "${YELLOW}🔄 Submodule exists: $name. Checking...${RESET}"

        if [ ! -d "$target" ]; then
            echo -e "${YELLOW}⚠️  Directory for submodule '$name' is missing!${RESET}"
            if [ "$REPAIR_BROKEN_SUBMODULES" = true ]; then
                echo -e "${YELLOW}🛠 Attempting to remove and re-add broken submodule $name...${RESET}"
                git submodule deinit -f "$name" || true
                git rm -f "$name" || true
                rm -rf ".git/modules/$name"
                git add .gitmodules || true
                git commit -am "Remove broken submodule $name" || true
                rm -rf "$target"
                echo -e "${GREEN}➕ Re-adding submodule $name...${RESET}"
                if git submodule add "$repo" "$target"; then
                    echo -e "${GREEN}✅ Re-added submodule: $name${RESET}"
                    changes_made=true
                    continue
                else
                    echo -e "${RED}❌ Failed to re-add submodule: $name${RESET}"
                    continue
                fi
            else
                echo -e "${RED}❌ Submodule $name is broken. Run with REPAIR_BROKEN_SUBMODULES=true to auto-fix.${RESET}"
                continue
            fi
        fi

        pushd "$target" > /dev/null
        git fetch origin &> /dev/null
        LOCAL_COMMIT=$(git rev-parse HEAD)
        REMOTE_COMMIT=$(git rev-parse origin/HEAD || git rev-parse origin/master || echo "")
        popd > /dev/null

        if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
            echo -e "${GREEN}⬆️  Updating submodule $name from $LOCAL_COMMIT → $REMOTE_COMMIT${RESET}"
            git submodule update --remote "$target"
            changes_made=true
        else
            echo -e "${GREEN}✅ Submodule $name already up-to-date${RESET}"
        fi
    elif [ -d "$target" ]; then
        echo -e "${YELLOW}⚠️  Directory $target exists but is not a submodule. Skipping...${RESET}"
    else
        echo -e "${GREEN}➕ Adding new submodule $name...${RESET}"
        if git submodule add "$repo" "$target"; then
            echo -e "${GREEN}✅ Added submodule: $name${RESET}"
            changes_made=true
        else
            echo -e "${RED}❌ Failed to add submodule: $name${RESET}"
        fi
    fi

    if [ -d "$target/instructions" ]; then
        echo -e "${BLUE}📘 Found instructions in $target/instructions${RESET}"
    fi
done < "$TEMPLATE_FILE"

cd "$ROOT_DIR"

if $changes_made; then
    echo -e "${GREEN}✅ Templates updated successfully.${RESET}"
else
    echo -e "${YELLOW}ℹ️  No changes detected. Everything is up-to-date.${RESET}"
fi
