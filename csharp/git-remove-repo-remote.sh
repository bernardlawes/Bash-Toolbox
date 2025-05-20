#!/usr/bin/env bash

JSON_FILE="git-remove-repo-remote.json"

# Check prerequisites
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Install from https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ You are not authenticated with GitHub CLI. Run: gh auth login"
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "❌ JSON file '$JSON_FILE' not found!"
    exit 1
fi

# Extract values from JSON (and sanitize)
owner=$(jq -r '.owner' "$JSON_FILE" | tr -d '\r')
confirm_all=$(jq -r '.confirm // false' "$JSON_FILE" | tr -d '\r')
repos=$(jq -r '.repos[]' "$JSON_FILE" | tr -d '\r')

if [[ -z "$owner" ]]; then
    echo "❌ 'owner' field is missing or empty in JSON."
    exit 1
fi

for repo in $repos; do
    full_repo="${owner}/${repo}"

    if [[ "$confirm_all" == "true" ]]; then
        echo "⛔ Deleting $full_repo..."
        gh repo delete "$full_repo" --yes
    else
        echo "⚠️  About to delete GitHub repo: $full_repo"
        read -p "Are you sure you want to delete $full_repo? (y/N): " confirm
        if [[ "$confirm" == "y" ]]; then
            echo "⛔ Deleting $full_repo..."
            gh repo delete "$full_repo" --yes
        else
            echo "❎ Skipped $full_repo"
        fi
    fi
done

echo "✅ Done."
