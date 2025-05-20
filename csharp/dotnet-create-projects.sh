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
MAIN_REPO_NAME=$(clean_name "$MAIN_REPO_NAME")  # <-- sanitize the name
MAIN_REPO_URL="git@github.com:$GH_USER/$MAIN_REPO_NAME.git"

MAIN_ARCHETYPE=$(jq -r '.main_archetype' "$CONFIG_FILE")
MAIN_ARCHETYPE=$(clean_name "$MAIN_ARCHETYPE")  # <-- sanitize the archetype

# Parse submodule names into array
readarray -t SUBMODULE_NAMES < <(jq -r '.submodules[].name' "$CONFIG_FILE")


# Build associative array for submodule visibility and archetype
declare -A SUBMODULE_VISIBILITY
declare -A SUBMODULE_ARCHETYPE
declare -A SUBMODULE_CREATE_SLN

# SAFE: read JSON rows properly without breaking on whitespace
while IFS= read -r row; do
  name=$(echo "$row" | jq -r '.name')
  name=$(clean_name "$name")

  visibility=$(echo "$row" | jq -r '.visibility')
  archetype=$(echo "$row" | jq -r '.archetype // "classlib"')
  create_sln=$(echo "$row" | jq -r '.create_sln // false')

  SUBMODULE_VISIBILITY["$name"]="$visibility"
  SUBMODULE_ARCHETYPE["$name"]="$archetype"
  SUBMODULE_CREATE_SLN["$name"]="$create_sln"
done < <(jq -c '.submodules[]' "$CONFIG_FILE")






# === .NET SETUP ===

MAIN_REPO_PATH="./$MAIN_REPO_NAME"
MAIN_PROJECT_NAME="MainProject"
MAIN_PROJECT_FOLDER="$MAIN_PROJECT_NAME"
MAIN_PROJECT_CSPROJ="$MAIN_PROJECT_FOLDER/$MAIN_PROJECT_NAME.csproj"
MAIN_SOLUTION_FILE="$MAIN_REPO_NAME.sln"

if [ ! -d "$MAIN_REPO_PATH" ]; then
  echo "❌ Directory '$MAIN_REPO_PATH' does not exist"
  exit 1
fi

echo "📂 Entering $MAIN_REPO_PATH"
cd "$MAIN_REPO_PATH" || { echo "❌ Failed to enter repo directory"; exit 1; }

# === Create .sln ===
if [ ! -f "$MAIN_SOLUTION_FILE" ]; then
  echo "📦 Creating solution: $MAIN_SOLUTION_FILE"
  dotnet new sln -n "$MAIN_REPO_NAME"
else
  echo "✅ Solution already exists: $MAIN_SOLUTION_FILE"
fi

# === Create MainProject ===
if [ ! -d "$MAIN_PROJECT_FOLDER" ]; then
  echo "🚀 Creating MainProject"
  echo -e
  archetype="$MAIN_ARCHETYPE";

  if [[ "$archetype" == "winforms" ]]; then
    dotnet new winforms -n "$MAIN_PROJECT_NAME"  -o "$MAIN_PROJECT_FOLDER" --framework net8.0
    echo "⚙️ Patching MainProject.csproj to use net8.0-windows"
    sed -i 's|<TargetFramework>net8.0</TargetFramework>|<TargetFramework>net8.0-windows</TargetFramework>|' MainProject/MainProject.csproj
  else
    echo "⚙️ Patching MainProject.csproj set up as console app"
    dotnet new console -n "$MAIN_PROJECT_NAME" -o "$MAIN_PROJECT_FOLDER" --framework net8.0
  fi
  
else
  echo "✅ MainProject already exists"
fi

# validate Main Repo Type after creation
echo "🔍 MainProject TargetFramework:"
grep '<TargetFramework>' MainProject/MainProject.csproj
echo -e

# === Add MainProject to solution ===
if [ -f "$MAIN_PROJECT_CSPROJ" ]; then
  dotnet sln "$MAIN_SOLUTION_FILE" add "$MAIN_PROJECT_CSPROJ"
else
  echo "❌ MainProject.csproj not found!"
  exit 1
fi



echo "📦 Creating .NET Projects for Submodules"


# === CREATE .NET PROJECTS FOR SUBMODULES ===
for name in "${SUBMODULE_NAMES[@]}"; do
  name=$(clean_name "$name")
  archetype=$(clean_name "${SUBMODULE_ARCHETYPE[$name]}")
  create_sln="${SUBMODULE_CREATE_SLN[$name]}"
  SUBMODULE_PATH="./$name"
  
  #CSPROJ_PATH="$SUBMODULE_PATH/$name.csproj"
  # Find the .csproj freshly after project creation
  CSPROJ_PATH=$(find "$SUBMODULE_PATH" -maxdepth 2 -name "*.csproj" | head -n 1)

  echo "Name: $name"
  echo "Type: $archetype"

  echo "📦 Submodule: $name (archetype=${archetype:-classlib}, create_sln=${create_sln:-false})"

  if [ ! -d "$SUBMODULE_PATH" ]; then
    echo "❌ Submodule folder missing: $SUBMODULE_PATH"
    continue
  fi

if [ ! -f "$CSPROJ_PATH" ]; then
  case "$archetype" in
    console)
      echo "creating console project"
      dotnet new console -n "$name" -o "$SUBMODULE_PATH" --framework net8.0
      ;;
    winforms)
      echo "creating winform project"
      dotnet new winforms -n "$name" -o "$SUBMODULE_PATH" --framework net8.0
      ;;
    hybrid)
      echo "📦 Creating hybrid WinForms + Console project: $name"
      dotnet new console -n "$name" -o "$SUBMODULE_PATH" --framework net8.0

      CSPROJ_PATH="$SUBMODULE_PATH/$name.csproj"
      PROGRAM_PATH="$SUBMODULE_PATH/Program.cs"

      echo "⚙️ Patching $CSPROJ_PATH to use net8.0-windows and enable WinForms"
      sed -i 's|<TargetFramework>net8.0</TargetFramework>|<TargetFramework>net8.0-windows</TargetFramework>|' "$CSPROJ_PATH"
      sed -i 's|<Project Sdk="Microsoft.NET.Sdk">|<Project Sdk="Microsoft.NET.Sdk.WindowsDesktop">|' "$CSPROJ_PATH"

      if ! grep -q '<UseWindowsForms>' "$CSPROJ_PATH"; then
        sed -i '/<TargetFramework>.*<\/TargetFramework>/a \    <UseWindowsForms>true</UseWindowsForms>' "$CSPROJ_PATH"
      fi

      echo "✍️ Writing inline WinForms Program.cs"
      cat <<"EOF" > "$PROGRAM_PATH"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

internal static class Program
{
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    private const int SW_HIDE = 0;
    private const int SW_SHOW = 5;

    private static bool ConsoleVisible = true;

    [STAThread]
    static void Main()
    {
        // Hide the console window at startup
        var handle = GetConsoleWindow();
        ShowWindow(handle, SW_HIDE);
        ConsoleVisible = false;

        ApplicationConfiguration.Initialize();

        var form = new Form
        {
            Text = "Hybrid WinForms App",
            Width = 800,
            Height = 600,
            StartPosition = FormStartPosition.CenterScreen,
            BackColor = Color.LightSteelBlue
        };

        var button = new Button
        {
            Text = "Show Console",
            Location = new Point(350, 250),
            AutoSize = true
        };

        button.Click += (sender, args) =>
        {
            if (ConsoleVisible)
            {
                ShowWindow(handle, SW_HIDE);
                ConsoleVisible = false;
                return;
            }
            ShowWindow(handle, SW_SHOW);
            ConsoleVisible = true;
        };

        form.Controls.Add(button);

        Application.Run(form);
    }
}
EOF
;;

    *)
      echo "creating classlib project"
      dotnet new classlib -n "$name" -o "$SUBMODULE_PATH" --framework net8.0
      ;;
  esac
fi

# Refresh the path to .csproj AFTER creation
CSPROJ_PATH=$(find "$SUBMODULE_PATH" -maxdepth 2 -name "*.csproj" | head -n 1)

SDK_LINE=$(grep -m 1 '<Project Sdk=' "$CSPROJ_PATH")
echo "🧠 Detected SDK in $name: $SDK_LINE"


# Workaround for WinForms SDK issue
# If the project is WinForms, we need to force the SDK to WindowsDesktop
if [[ "$archetype" == "winforms" ]]; then
  echo "⚙️ Forcing WinForms SDK and properties in $name.csproj"

  # Replace generic SDK with WindowsDesktop SDK
  sed -i 's|<Project Sdk="Microsoft.NET.Sdk">|<Project Sdk="Microsoft.NET.Sdk.WindowsDesktop">|' "$CSPROJ_PATH"

  # Inject UseWindowsForms if it's not there
  if ! grep -q "<UseWindowsForms>" "$CSPROJ_PATH"; then
    sed -i '/<TargetFramework>/a\ \ \ \ <UseWindowsForms>true' "$CSPROJ_PATH"
  fi
fi

# Check if the SDK line was modified correctly
echo "🔎 Final SDK in $name.csproj:" && grep '<Project Sdk=' "$CSPROJ_PATH"


# Continue as normal
if [[ "$create_sln" == "true" ]]; then
  if [ ! -f "$SUBMODULE_PATH/$name.sln" ]; then
    echo "🧩 Creating $name.sln"
    (cd "$SUBMODULE_PATH" && \
      dotnet new sln -n "$name" && \
      dotnet sln "$name.sln" add "$name.csproj")
  else
    echo "✅ $name.sln already exists"
  fi
else
  echo "🛑 Skipping .sln creation for $name"
fi

dotnet sln "$MAIN_SOLUTION_FILE" add "$CSPROJ_PATH"
dotnet add "$MAIN_PROJECT_CSPROJ" reference "$CSPROJ_PATH"

echo -e
echo -e "=============== END SUB MODULE PROJECT SETUP FOR $name | $archetype =========================="
echo -e

done


cd ..
