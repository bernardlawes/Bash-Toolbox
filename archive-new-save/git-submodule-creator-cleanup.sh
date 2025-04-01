#!/bin/bash

set -e  # Exit on error
set -o pipefail

# === CONFIG ===
GH_USER="bernardlawes"
MAIN_REPO_NAME="Spatial_Password_Manager"
MAIN_REPO_URL="https://github.com/$GH_USER/$MAIN_REPO_NAME.git"

declare -A SUBMODULES
SUBMODULES[csharp_login]="https://github.com/$GH_USER/csharp_login.git"
SUBMODULES[csharp_pgp_encryption]="https://github.com/$GH_USER/csharp_pgp_encryption.git"

# === CHECK GH LOGIN ===
if ! gh auth status &>/dev/null; then
  echo "❌ You must be logged into GitHub CLI (gh). Run: gh auth login"
  exit 1
fi

# === CREATE SUBMODULE REPOS IF THEY DON'T EXIST ===
for name in "${!SUBMODULES[@]}"; do
  echo "🔧 Checking submodule repo: $name"
  if gh repo view "$GH_USER/$name" &>/dev/null; then
    echo "✅ Repo $name already exists, skipping creation."
  else
    echo "🚀 Creating repo: $name"
    gh repo create "$name" --public --confirm
  fi

  if [ ! -d "$name" ]; then
    mkdir "$name"
    cd "$name"
    git init

    # Create README
    echo "# $name module" > README.md

    # Create .gitignore inside the submodule
    cat <<EOF > .gitignore
# OS junk
.DS_Store
Thumbs.db
ehthumbs.db

# IDEs and editors
.vscode/
.idea/
*.sublime-*
*.code-workspace

# Logs and backups
*.log
*.bak
*.tmp
*.swp
*.cache

# Node / Composer leftovers
node_modules/
vendor/

# Environment files
.env
.env.*
EOF

    git add .
    git commit -m "Initial commit with .gitignore"
    git branch -M main
    git remote add origin "${SUBMODULES[$name]}"
    git push -u origin main
    cd ..
  else
    echo "⚠️ Directory $name already exists. Skipping init."
  fi
done

# === CREATE MAIN PROJECT ===
echo "📁 Checking main project: $MAIN_REPO_NAME"
if gh repo view "$GH_USER/$MAIN_REPO_NAME" &>/dev/null; then
  echo "✅ Repo $MAIN_REPO_NAME already exists."
else
  echo "🚀 Creating main repo: $MAIN_REPO_NAME"
  gh repo create "$MAIN_REPO_NAME" --public --confirm
fi

mkdir -p "$MAIN_REPO_NAME"
cd "$MAIN_REPO_NAME"
if [ ! -d ".git" ]; then
  git init
  git remote add origin "$MAIN_REPO_URL"
fi

# Create .gitignore inside main project
cat <<EOF > .gitignore
# OS junk
.DS_Store
Thumbs.db
ehthumbs.db

# IDEs and editors
.vscode/
.idea/
*.sublime-*
*.code-workspace

# Logs and backups
*.log
*.bak
*.tmp
*.swp
*.cache

# Node / Composer leftovers
node_modules/
vendor/

# Environment files
.env
.env.*
EOF

# === ADD SUBMODULES ===
for name in "${!SUBMODULES[@]}"; do
  if [ ! -d "$name" ]; then
    echo "🔗 Adding submodule: $name"
    git submodule add "${SUBMODULES[$name]}" "$name"
  else
    echo "⚠️ Submodule $name already exists as folder. Skipping add."
  fi
done

# === COMMIT AND PUSH ===
git add .gitmodules .gitignore "${!SUBMODULES[@]}" || true
git commit -m "Add submodules and .gitignore" || echo "📝 Nothing to commit"
git branch -M main
git push -u origin main

# === FINAL CLEANUP OF TOP-LEVEL SUBMODULE FOLDERS ===
echo "🧹 Cleaning up top-level submodule folders..."
cd ..

for name in "${!SUBMODULES[@]}"; do
  if [ -d "$name" ]; then
    echo "🗑️ Removing top-level folder: $name"
    rm -rf "$name"
  else
    echo "✅ Folder $name already removed"
  fi
done

echo "🎉 All done! Main project and submodules are cleanly set up inside $MAIN_REPO_NAME/"
