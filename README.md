# 🌀 Git Bash Automation Toolkit

A suite of Bash scripts to simplify and automate the creation, management, editing, removal, and pushing of multi-project Git repositories with Git submodules — including support for **multi-repo setups** with **submodules**, **custom structures**, and **modular workflows**.

## ⚡ Purpose

Managing Git submodules, nested repositories, and batch repo creation can be tedious and error-prone. This toolkit streamlines those operations into fast, repeatable Bash commands — ideal for mono-repos, microservice setups, modular codebases, or multi-project pipelines.

## ✅ Features

- 🚀 **Create main repos + submodules** from a single JSON config
- 🔁 **Pull, push, or clone all** submodules recursively
- 🔗 **Initialize, sync, and update** submodule links
- 🧹 **Remove or detach** submodules safely
- 🛠️ **Batch edit repo metadata** (descriptions, remotes, visibility)
- 📄 **Generate or sync `.gitmodules`**, `.gitignore`, and other scaffolding
- 🧪 **Dry run mode** for safe previews before executing changes

## 🛠️ Requirements

- Bash (Unix-like environment or Git Bash for Windows)
- [GitHub CLI (`gh`)](https://cli.github.com/) (for repo creation/editing)
- `jq` (for JSON parsing)

## 🗂️ Directory Structure


git-bash-toolkit/
├── create_repos.sh # Create repo + submodules from config
├── update_submodules.sh # Pull latest changes for all submodules
├── remove_submodule.sh # Cleanly remove a submodule
├── sync_metadata.sh # Sync descriptions or remote info
├── .gitignore # (Optional) Ignore system/temp files
└── git-modules-config.json # JSON config with repo structure


🚨 Safety Tips
Always run git status before/after script execution.

Use a test branch or dummy org for initial runs.

When modifying remote repos, ensure GitHub CLI is authenticated.

📦 To Do
 Add logging support

 Add backup/restore mode

 GitLab support

🤝 Contributing
PRs and suggestions welcome! This toolkit is evolving with real-world usage — feel free to fork and enhance for your setup.

📄 License
MIT License — use freely and modify as needed.


## 🧪 Example Usage

JSON Config Structure

```json
{
  "main_repo": "MainProject",
  "visibility": "private",
  "submodules": [
    {
      "name": "Utils",
      "path": "libs/utils",
      "visibility": "public",
      "archetype": "classlib"
    },
    {
      "name": "UI",
      "path": "apps/ui",
      "visibility": "private",
      "archetype": "winforms"
    }
  ]
}

```

### Create a full repo structure from JSON:

```bash
# Create a full repo structure based on config.json
./create_repos.sh ./git-modules-config.json

# Update and Sync Submodules
./update_submodules.sh

# Remove a submodule Cleanly
./remove_submodule.sh path/to/submodule

```
