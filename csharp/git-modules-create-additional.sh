#!/usr/bin/env bash

JSON_FILE="git-modules-create-additional.json"
REPO_DIR="Moji-Lens-Japanese"

# --- Check prerequisites ---
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI is not authenticated."
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "❌ JSON file '$JSON_FILE' not found!"
    exit 1
fi

# --- Parse JSON ---
gh_user=$(jq -r '.gh_user' "$JSON_FILE" | tr -d '\r')
submodules=$(jq -c '.submodules[]' "$JSON_FILE")

# --- Enter the main repo directory ---
cd "$REPO_DIR" || { echo "❌ Cannot find directory '$REPO_DIR'"; exit 1; }

# --- Process each submodule ---
for sub in $submodules; do
    name=$(echo "$sub" | jq -r '.name' | tr -d '\r')
    visibility=$(echo "$sub" | jq -r '.visibility' | tr -d '\r')
    archetype=$(echo "$sub" | jq -r '.archetype' | tr -d '\r')
    create_sln=$(echo "$sub" | jq -r '.create_sln' | tr -d '\r')

    echo "📁 Creating submodule: $name ($visibility, $archetype)"

    # Step 1: Create remote repo
    gh repo create "$gh_user/$name" --$visibility --confirm --add-readme

    # Step 2: Create local folder and push initial commit
    mkdir "$name"
    cd "$name"
    git init
    git remote add origin "https://github.com/$gh_user/$name.git"
    echo "# $name" > README.md
    git add README.md
    git commit -m "Initial commit"
    git push -u origin master

    # Step 3: Optional .sln
    if [[ "$create_sln" == "true" ]]; then
        dotnet new sln -n "$name"
        git add "$name.sln"
        git commit -m "Add solution file"
        git push
    fi

    cd ..

    # Step 4: Add as submodule to MasterRepo
    git submodule add "https://github.com/$gh_user/$name.git" "$name"
    git commit -am "Add submodule $name"
done

echo "✅ Submodule creation complete."
