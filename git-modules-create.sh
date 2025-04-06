#!/bin/bash

set -e
set -o pipefail

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
for row in $(jq -c '.submodules[]' "$CONFIG_FILE"); do
  name=$(echo "$row" | jq -r '.name')
  name=$(clean_name "$name")  # <-- sanitize the name
  visibility=$(echo "$row" | jq -r '.visibility')
  SUBMODULE_VISIBILITY["$name"]="$visibility"
done

# === CHECK GH LOGIN ===
if ! gh auth status &>/dev/null; then
  echo "❌ You must be logged into GitHub CLI (gh). Run: gh auth login --git-protocol ssh"
  exit 1
fi

# === CREATE SUBMODULE REPOS IF THEY DON'T EXIST ===
for module in $(jq -c '.submodules[]' "$CONFIG_FILE"); do
  name=$(echo "$module" | jq -r '.name')
  name=$(clean_name "$name")  # <-- sanitize the name
  visibility=$(echo "$module" | jq -r '.visibility')

  echo "🔧 Checking submodule repo: $name ($visibility)"
  if gh repo view "$GH_USER/$name" &>/dev/null; then
    echo "✅ Repo $name already exists, skipping creation."
  else
    echo "🚀 Creating $visibility repo: $name"
    gh repo create "$name" --"$visibility" --confirm
  fi

  if [ ! -d "$name" ]; then
    mkdir "$name"
    cd "$name"
    git init

    # Create README
    echo "# $name module" > README.md

    # .gitignore
    cat <<EOF > .gitignore
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

    git add .
    git commit -m "Initial commit with .gitignore"
    git branch -M main
    git remote add origin "https://github.com/$GH_USER/$name.git"
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

# .gitignore for main project
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
git branch -M main
git push -u origin main

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



