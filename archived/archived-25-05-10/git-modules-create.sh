#!/bin/bash

set -e
set -o pipefail

write_gitignore() {
  local target_dir="$1"

  cat <<EOF > "$target_dir/.gitignore"
#############
# OS Junk
#############
.DS_Store
Thumbs.db
ehthumbs.db
Icon?
Desktop.ini

#############
# IDEs & Editors
#############
**/.vscode/
**/.idea/
**/.vs/                    # Visual Studio settings folder
*.suo
*.user
*.userosscache
*.sln.docstates
*.code-workspace
*.sublime-*

#############
# Build output
#############
**/bin/
**/obj/
**/[Bb]uild/
**/[Ll]og/
*.log
**/.vs/
*.user
*.suo
*.tmp
*.cache
*.dll   # <--- optionally ignore all DLLs unless you specifically want one
# !path/to/your/output/MyLibrary.dll #If you want to track one specific DLL, you can override it like this:

#############
# Packaging
#############
*.nupkg
*.snupkg
*.nuspec
*.vsix
*.zip
*.tar.gz

#############
# Installer logs
#############
*.msi
*.exe

#############
# Debugging & crash dumps
#############
*.pdb
*.mdb
*.opendb
*.dmp

#############
# Test Results
#############
**/TestResults/
*.trx
*.coverage
*.coveragexml
*.testsettings
*.vsmdi
*.appxrecipe

#############
# Temporary files
#############
*.tmp
*.temp
*.bak
*.swp
*.cache

#############
# Visual Studio profiler
#############
*.psess
*.vsp
*.vspx
*.sap

#############
# Resharper & Extensions
#############
**/_ReSharper*/
*.[Rr]e[Ss]harper
*.DotSettings.user
*.ncrunch*
*.dotCover

#############
# Rider
#############
**/.idea/
*.sln.iml

#############
# NuGet
#############
*.nupkg
.nuget/
**/packages/
project.lock.json
project.fragment.lock.json

#############
# Others
#############
**/node_modules/
**/vendor/
.env
.env.*
*.db
*.sqlite
*.sdf
*.class
EOF
}


CONFIG_FILE="./git-modules-config.json"

# === REQUIRE jq ===
if ! command -v jq &>/dev/null; then
  echo "❌ 'jq' is required but not installed. Install it via: sudo apt install jq (Linux) or brew install jq (Mac)"
  exit 1
fi

clean_name() {
  echo "$1" | tr -d '\r\n'
}

# === PARSE CONFIG ===
GH_USER=$(jq -r '.gh_user' "$CONFIG_FILE")
MAIN_REPO_NAME=$(jq -r '.main_repo_name' "$CONFIG_FILE")
MAIN_REPO_URL="git@github.com:$GH_USER/$MAIN_REPO_NAME.git"

# Parse submodule names into array
readarray -t SUBMODULE_NAMES < <(jq -r '.submodules[].name' "$CONFIG_FILE")

# Build associative array for submodule visibility
declare -A SUBMODULE_VISIBILITY
for module in $(jq -c '.submodules[]' "$CONFIG_FILE"); do
  name=$(echo "$module" | jq -r '.name')
  name=$(clean_name "$name")
  visibility=$(echo "$module" | jq -r '.visibility')
  REPO_URL="https://github.com/$GH_USER/$name.git"

  echo "🔧 Checking submodule repo: $name ($visibility)"
  if gh repo view "$GH_USER/$name" &>/dev/null; then
    echo "✅ Repo $name already exists, skipping creation."
  else
    echo "🚀 Creating $visibility repo: $name"
    gh repo create "$name" --"$visibility" --confirm

    sleep 2  # Allow time for GitHub to register the new repo
  fi

  if [ ! -d "$name" ]; then
    echo "📁 Attempting to clone $name"
    git clone "$REPO_URL" "$name" || {
      echo "❌ Clone failed — initializing manually"
      mkdir "$name"
      cd "$name"
      git init
      git remote add origin "$REPO_URL"
      git pull origin master --rebase || echo "ℹ️ Nothing to rebase or pull"
      cd ..
    }
  fi

  cd "$name"

  if [ ! -f "README.md" ]; then
    echo "# $name module" > README.md
  fi

  if [ ! -f ".gitignore" ]; then
    # .gitignore
    write_gitignore "$PWD"
  fi

  git add .
  git commit -m "Initial commit with .gitignore" || echo "📝 Nothing to commit"
  git branch -M master

  if ! git remote get-url origin &>/dev/null; then
    git remote add origin "$REPO_URL"
  fi

  git push -u origin master || echo "⚠️ Push failed, continuing anyway"
  cd ..
done


# === CREATE MAIN PROJECT ===
echo "📁 Checking main project: $MAIN_REPO_NAME"
if gh repo view "$GH_USER/$MAIN_REPO_NAME" &>/dev/null; then
  echo "✅ Repo $MAIN_REPO_NAME already exists."
else
  echo "🚀 Creating main repo: $MAIN_REPO_NAME"
  gh repo create "$MAIN_REPO_NAME" --public --confirm
fi

REPO_URL="$MAIN_REPO_URL"
if git ls-remote "$REPO_URL" &>/dev/null; then
  echo "🌐 Remote main repo exists — cloning instead."
  git clone "$REPO_URL" "$MAIN_REPO_NAME"
  cd "$MAIN_REPO_NAME"
  # ⬇️ Pull down submodules, too
  git submodule update --init --recursive
else
  echo "🆕 Remote main repo doesn't exist — creating new local."
  mkdir -p "$MAIN_REPO_NAME"
  cd "$MAIN_REPO_NAME"
  git init
  git remote add origin "$REPO_URL"
  git pull origin master --rebase || echo "ℹ️ Nothing to rebase or pull"
fi


# .gitignore for main project
write_gitignore "$PWD"

# === ADD SUBMODULES ===
for name in "${SUBMODULE_NAMES[@]}"; do

  name=$(clean_name "$name")  # <-- sanitize the name
  SUBMODULE_URL="https://github.com/$GH_USER/$name.git"
  if [ ! -d "$name" ]; then
    echo "🔗 Adding submodule: $name"
    echo "🔗 Adding submodule: name=$name"
    echo "🔗 Submodule URL: $SUBMODULE_URL"
    git submodule add "$SUBMODULE_URL" "$name"
  else
    echo "⚠️ Submodule $name already exists as folder. Skipping add."
  fi
done

# === COMMIT AND PUSH ===
git add .gitmodules .gitignore "${SUBMODULE_NAMES[@]}" || true
git commit -m "Add submodules and .gitignore" || echo "📝 Nothing to commit"
git branch -M master
git push -u origin master

# === FINAL CLEANUP OF TOP-LEVEL SUBMODULE FOLDERS ===
echo "🧹 Cleaning up top-level submodule folders..."
cd ..

for name in "${SUBMODULE_NAMES[@]}"; do

  name=$(clean_name "$name")  # <-- sanitize the name
  if [ -d "$name" ]; then
    echo "🗑️ Removing top-level folder: $name"
    rm -rf "$name"
  else
    echo "✅ Folder $name already removed -"
  fi
done

echo "🎉 All done! Top Level Folders Removed. Main project and submodules are cleanly set up inside $MAIN_REPO_NAME/"


# === CREATE .NET CLASSLIB IN EACH SUBMODULE IF NEEDED ===
for name in "${SUBMODULE_NAMES[@]}"; do
  name=$(clean_name "$name")
  if [ -d "$name" ]; then
    cd "$name"
    if ! find . -name "*.csproj" | grep -q .; then
      echo "📦 Creating .NET classlib in $name"
      dotnet new classlib -n "$name"
    else
      echo "✅ .csproj already exists in $name"
    fi
    cd ..
  fi
done



