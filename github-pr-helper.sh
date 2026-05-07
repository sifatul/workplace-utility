#!/bin/bash

FAVORITES_FILE=".pr-favourites"

# Initialize favorites file if it doesn't exist
init_favorites() {
    if [ ! -f "$FAVORITES_FILE" ]; then
        touch "$FAVORITES_FILE"
    fi
}

# List favorite branches
list_favorites() {
    init_favorites
    if [ -s "$FAVORITES_FILE" ]; then
        echo "Favorite target branches:"
        cat -n "$FAVORITES_FILE"
    else
        echo "No favorite branches saved yet."
    fi
}

# Add a branch to favorites
add_favorite() {
    init_favorites
    local branch="$1"
    if grep -q "^$branch$" "$FAVORITES_FILE" 2>/dev/null; then
        echo "'$branch' is already in favorites."
    else
        echo "$branch" >> "$FAVORITES_FILE"
        echo "Added '$branch' to favorites."
    fi
}

# Remove a branch from favorites
remove_favorite() {
    init_favorites
    local branch="$1"
    if grep -q "^$branch$" "$FAVORITES_FILE" 2>/dev/null; then
        grep -v "^$branch$" "$FAVORITES_FILE" > "${FAVORITES_FILE}.tmp"
        mv "${FAVORITES_FILE}.tmp" "$FAVORITES_FILE"
        echo "Removed '$branch' from favorites."
    else
        echo "'$branch' not found in favorites."
    fi
}

# Create pull request
create_pr() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi

    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI (gh) is not installed"
        echo "Install it from: https://cli.github.com/"
        return 1
    fi

    init_favorites

    local current_branch=$(git branch --show-current)
    echo "Current branch: $current_branch"

    if [ -s "$FAVORITES_FILE" ]; then
        echo ""
        echo "Favorite target branches:"
        cat -n "$FAVORITES_FILE"
        echo ""
        read -p "Enter the number of the target branch (or type a custom branch name): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            local target_branch=$(sed -n "${choice}p" "$FAVORITES_FILE")
            if [ -z "$target_branch" ]; then
                echo "Invalid selection."
                return 1
            fi
        else
            local target_branch="$choice"
        fi
    else
        read -p "Enter target branch name: " target_branch
    fi

    if [ -z "$target_branch" ]; then
        echo "Error: Target branch cannot be empty"
        return 1
    fi

    echo ""
    read -p "Enter PR title: " pr_title
    read -p "Enter PR description (optional, press Enter to skip): " pr_body

    echo ""
    echo "Creating PR from '$current_branch' to '$target_branch'..."

    local pr_link=$(gh pr create --base "$target_branch" --title "$pr_title" --body "$pr_body" 2>&1)

    if echo "$pr_link" | grep -q "https://"; then
        echo ""
        echo "✓ Pull request created successfully!"
        echo ""
        echo "PR Link: $pr_link"
    else
        echo ""
        echo "Failed to create PR:"
        echo "$pr_link"
        return 1
    fi
}

# Show usage
show_usage() {
    echo "GitHub PR Helper"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create              Create a pull request"
    echo "  add <branch>        Add a branch to favorites"
    echo "  remove <branch>     Remove a branch from favorites"
    echo "  list                List favorite branches"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 create"
    echo "  $0 add main"
    echo "  $0 add develop"
    echo "  $0 list"
}

# Main script logic
case "$1" in
    create)
        create_pr
        ;;
    add)
        if [ -z "$2" ]; then
            echo "Error: Please specify a branch name"
            echo "Usage: $0 add <branch>"
            exit 1
        fi
        add_favorite "$2"
        ;;
    remove)
        if [ -z "$2" ]; then
            echo "Error: Please specify a branch name"
            echo "Usage: $0 remove <branch>"
            exit 1
        fi
        remove_favorite "$2"
        ;;
    list)
        list_favorites
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        show_usage
        ;;
esac
