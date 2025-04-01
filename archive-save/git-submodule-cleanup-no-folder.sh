#!/bin/bash

# === CONFIG ===
GH_USER="bernardlawes"
MAIN_REPO_NAME="Spatial_Password_Manager"

declare -a REPO_NAMES=(
  "$MAIN_REPO_NAME"
  "csharp_login"
  "csharp_pgp_encryption"
)

FORCE=false

# === ARGUMENTS ===
if [[ "$1" == "--force" ]]; then
  FORCE=true
fi

# === FUNCTION TO CONFIRM ACTION ===
confirm() {
  if [ "$FORCE" = true ]; then
    return 0
  fi
  read -p "⚠️ Are you sure you want to delete $1? [y/N] " choice
  [[ "$choice" == [Yy]* ]]
}

# === DELETE GITHUB REPOS ===
for repo in "${REPO_NAMES[@]}"; do
  if gh repo view "$GH_USER/$repo" &>/dev/null; then
    if confirm "GitHub repo: $GH_USER/$repo"; then
      echo "🔥 Deleting GitHub repo: $repo"
      gh repo delete "$GH_USER/$repo" --yes
    else
      echo "⏭️ Skipped GitHub repo: $repo"
    fi
  else
    echo "✅ Repo $repo does not exist on GitHub. Skipping."
  fi
done

# === DELETE LOCAL DIRECTORIES ===
for repo in "${REPO_NAMES[@]}"; do
  if [ -d "$repo" ]; then
    if confirm "local folder: $repo"; then
      echo "🗑️ Deleting folder: $repo"
      rm -rf "$repo"
    else
      echo "⏭️ Skipped local folder: $repo"
    fi
  else
    echo "✅ Folder $repo does not exist locally. Skipping."
  fi
done

echo "✅ Cleanup complete!"
