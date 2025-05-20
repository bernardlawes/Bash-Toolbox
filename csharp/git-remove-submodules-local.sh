#!/usr/bin/env bash

# Relative or absolute path to your master repo folder
REPO_DIR="Moji-Lens-Japanese"
JSON_FILE="git-remove-submodules.json"

# Check prerequisites
if ! command -v jq &> /dev/null; then
    echo "❌ jq is required but not found. Install it via scoop or from https://stedolan.github.io/jq/download/"
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "❌ JSON file '$JSON_FILE' not found!"
    exit 1
fi

# Enter the repo directory
cd "$REPO_DIR" || { echo "❌ Cannot enter directory $REPO_DIR"; exit 1; }

# Backup .gitmodules just in case
cp .gitmodules .gitmodules.bak 2>/dev/null

# Read and iterate over each submodule path
submodules=$(jq -r '.remove[]' "../$JSON_FILE")
submodules=$(echo "$submodules" | tr -d '\r')

for path in $submodules; do
    path=$(echo "$path" | tr -d '\r')
    echo "🔹 Removing submodule: $path"

    # Step 1: Deinit
    git submodule deinit -f "$path"

    # Step 2: Remove from index
    git rm --cached "$path"

    # Step 3: Delete working directory
    rm -rf "$path"

    # Step 4: Remove entry from .gitmodules
    if grep -q "$path" .gitmodules; then
        echo "🔸 Cleaning .gitmodules entry for $path"
        sed -i -e "/\[submodule \"$path\"\]/,/^\s*\[.*\]/d" .gitmodules
    fi

    # Step 5: Delete metadata from .git/modules
    rm -rf ".git/modules/$path"

    echo "✅ Done with $path"
    echo
done

# Stage and commit changes
git add .gitmodules
git commit -m "Removed specified submodules"

echo "🚀 All listed submodules have been removed."

# Optional push
read -p "Do you want to push the changes to origin? (y/n): " pushnow
if [[ "$pushnow" == "y" ]]; then
    git push
fi
