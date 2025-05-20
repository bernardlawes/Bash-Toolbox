#!/usr/bin/env bash

set -e

clean_name() {
  echo "$1" | tr -d '\r\n'
}

# ✅ Define this function BEFORE using it
get_clean_array() {
  jq -r "$1" "$CONFIG_FILE" | tr -d '\r' | sed '/^$/d'
}

CONFIG_FILE="git-modules-config.json"

# Check for config file
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

# Extract values
main_repo=$(jq -r '.main_repo_name' "$CONFIG_FILE")
gh_user=$(jq -r '.gh_user' "$CONFIG_FILE")


# commenting out the old way of getting submodules
#submodules=($(jq -r '.submodules[].name' "$CONFIG_FILE"))

# Use the function to load submodules
submodules=($(get_clean_array '.submodules[].name'))

# Ensure main repo folder exists
if [[ ! -d "$main_repo" ]]; then
    echo "❌ Main repo folder not found: $main_repo"
    exit 1
fi

# Go into main repo
echo "📂 Entering main repo: $main_repo"
pushd "$main_repo" > /dev/null

# Function: commit and push if needed
commit_if_needed() {
    local repo_path=$1
    local label=$2

    pushd "$repo_path" > /dev/null

    if [[ -n $(git status --porcelain) ]]; then
        echo "📦 Changes detected in $label. Committing..."
        git add .
        git commit -m "Auto-commit from push script"
    else
        echo "✅ No changes to commit in $label."
    fi

    current_branch=$(git symbolic-ref --short HEAD)
    git push origin "$current_branch"

    popd > /dev/null
}

# Step 1: Push submodules
echo "🔁 Processing submodules..."
for submodule in "${submodules[@]}"; do
    submodule=$(clean_name "$submodule")
    echo "🔄 Submodule: $submodule"
    if [[ -d "$submodule" ]]; then
        commit_if_needed "$submodule" "submodule '$submodule'"
    else
        echo "⚠️  Submodule folder not found: $submodule"
    fi
done

# Step 2: Push main repo
echo "🚀 Processing main repo: $main_repo"
commit_if_needed "." "main repo"

# Leave main repo
popd > /dev/null

echo "✅ All commits and pushes complete!"