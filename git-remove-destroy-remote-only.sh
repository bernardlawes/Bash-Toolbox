#!/bin/bash

# === CONFIG ===
REPO_CONFIG_FILE="git-modules-config.json"

# === PARSE JSON ===
GH_USER=$(jq -r '.gh_user' "$REPO_CONFIG_FILE")
MAIN_REPO_NAME=$(jq -r '.main_repo_name' "$REPO_CONFIG_FILE")

# Use a loop-friendly JSON-safe method to get repo names
REPO_NAMES=()
REPO_NAMES+=("$MAIN_REPO_NAME")

while IFS= read -r name; do
  name_cleaned=$(echo "$name" | tr -d '\r' | xargs)
  REPO_NAMES+=("$name_cleaned")
done < <(jq -r '.submodules[].name' "$REPO_CONFIG_FILE")

echo "🔥 Starting full cleanup for GitHub user: $GH_USER"
echo "📄 Using config file: $REPO_CONFIG_FILE"

# === DELETE GITHUB REPOS ===
for repo in "${REPO_NAMES[@]}"; do
  echo "🌐 Deleting GitHub repo: $GH_USER/$repo"
  if gh repo view "$GH_USER/$repo" &>/dev/null; then
    gh repo delete "$GH_USER/$repo" --yes
    echo "✅ Deleted remote repo: $repo"
  else
    echo "⚠️ Repo $repo does not exist on GitHub"
  fi
done

# === DELETE LOCAL DIRECTORIES ===
#for repo in "${REPO_NAMES[@]}"; do
#  if [ -d "$repo" ]; then
#    echo "🗑️ Removing local folder: $repo"
#    rm -rf "$repo"
#  else
#    echo "✅ Folder $repo already removed"
#  fi
#done

echo "🎉 Cleanup complete!"
