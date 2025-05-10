#!/bin/bash

# === CONFIG ===
GH_USER="bernardlawes"
MAIN_REPO_NAME="Spatial_Password_Manager"

declare -a REPO_NAMES=(
  "$MAIN_REPO_NAME"
  "csharp_login"
  "csharp_pgp_encryption"
  "public_utils"
)

echo "🔥 Starting full cleanup..."

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
for repo in "${REPO_NAMES[@]}"; do
  if [ -d "$repo" ]; then
    echo "🗑️ Removing local folder: $repo"
    rm -rf "$repo"
  else
    echo "✅ Folder $repo already removed"
  fi
done

echo "🎉 Cleanup complete!"
