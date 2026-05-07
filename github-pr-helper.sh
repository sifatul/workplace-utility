#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAVORITES_FILE="$SCRIPT_DIR/.pr-favourites"

# Get current repository's remote URL
get_repo_url() {
    git remote get-url origin 2>/dev/null || git remote get-url $(git remote | head -1) 2>/dev/null
}

# Get favorites for current repository
get_repo_favorites() {
    local repo_url=$(get_repo_url)
    if [ -z "$repo_url" ]; then
        return 1
    fi
    if [ ! -f "$FAVORITES_FILE" ]; then
        return 1
    fi
    awk -v repo="$repo_url" '
        BEGIN { in_repo = 0 }
        $0 == repo {
            in_repo = 1
            next
        }
        /^$/ {
            in_repo = 0
            next
        }
        /^https?:|^git@|^ssh:\/\// {
            in_repo = 0
            next
        }
        in_repo {
            print
        }
    ' "$FAVORITES_FILE"
}

# Initialize favorites file if it doesn't exist
init_favorites() {
    if [ ! -f "$FAVORITES_FILE" ]; then
        touch "$FAVORITES_FILE"
    fi
}

# List favorite branches for current repository
list_favorites() {
    init_favorites
    local repo_url=$(get_repo_url)
    if [ -z "$repo_url" ]; then
        echo "Error: Cannot determine repository URL"
        return 1
    fi

    local favorites=$(get_repo_favorites)
    if [ -n "$favorites" ]; then
        echo "Favorite target branches for this repository:"
        echo "$favorites" | cat -n
    else
        echo "No favorite branches saved for this repository yet."
    fi
}

# Add a branch to favorites for current repository
add_favorite() {
    init_favorites
    local repo_url=$(get_repo_url)
    if [ -z "$repo_url" ]; then
        echo "Error: Cannot determine repository URL"
        return 1
    fi

    local branch="$1"
    local favorites=$(get_repo_favorites)

    if echo "$favorites" | grep -q "^$branch$"; then
        echo "'$branch' is already in favorites."
        return 0
    fi

    if [ ! -s "$FAVORITES_FILE" ]; then
        echo "$repo_url" >> "$FAVORITES_FILE"
        echo "$branch" >> "$FAVORITES_FILE"
        echo "Added '$branch' to favorites."
        return 0
    fi

    local temp_file=$(mktemp)
    local in_target_repo=0
    local branch_added=0

    while IFS= read -r line; do
        if [ "$line" = "$repo_url" ]; then
            in_target_repo=1
            echo "$line" >> "$temp_file"
        elif [[ "$line" =~ ^https?:|^git@|^ssh:// ]]; then
            if [ "$in_target_repo" -eq 1 ] && [ "$branch_added" -eq 0 ]; then
                echo "$branch" >> "$temp_file"
                branch_added=1
            fi
            in_target_repo=0
            echo "$line" >> "$temp_file"
        elif [ -z "$line" ]; then
            if [ "$in_target_repo" -eq 1 ] && [ "$branch_added" -eq 0 ]; then
                echo "$branch" >> "$temp_file"
                branch_added=1
            fi
            in_target_repo=0
            echo "$line" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$FAVORITES_FILE"

    if [ "$in_target_repo" -eq 1 ] && [ "$branch_added" -eq 0 ]; then
        echo "$branch" >> "$temp_file"
    fi

    mv "$temp_file" "$FAVORITES_FILE"
    echo "Added '$branch' to favorites."
}

# Remove a branch from favorites for current repository
remove_favorite() {
    init_favorites
    local repo_url=$(get_repo_url)
    if [ -z "$repo_url" ]; then
        echo "Error: Cannot determine repository URL"
        return 1
    fi

    local branch="$1"
    local favorites=$(get_repo_favorites)

    if ! echo "$favorites" | grep -q "^$branch$"; then
        echo "'$branch' not found in favorites."
        return 1
    fi

    local temp_file=$(mktemp)
    local in_target_repo=0
    local repo_has_branches=0

    while IFS= read -r line; do
        if [ "$line" = "$repo_url" ]; then
            in_target_repo=1
            echo "$line" >> "$temp_file"
        elif [[ "$line" =~ ^https?:|^git@|^ssh:// ]]; then
            in_target_repo=0
            echo "$line" >> "$temp_file"
        elif [ -z "$line" ]; then
            in_target_repo=0
            echo "$line" >> "$temp_file"
        else
            if [ "$in_target_repo" -eq 1 ]; then
                if [ "$line" != "$branch" ]; then
                    echo "$line" >> "$temp_file"
                    repo_has_branches=1
                fi
            else
                echo "$line" >> "$temp_file"
            fi
        fi
    done < "$FAVORITES_FILE"

    mv "$temp_file" "$FAVORITES_FILE"
    echo "Removed '$branch' from favorites."
}
# sdfd
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
    local repo_url=$(get_repo_url)

    echo "Current branch: $current_branch"
    if [ -n "$repo_url" ]; then
        echo "Repository: $repo_url"
    fi

    local target_branches=()
    local favorites=$(get_repo_favorites)

    if [ -n "$favorites" ]; then
        echo ""
        echo "Favorite target branches:"
        echo "$favorites" | cat -n
        echo ""
        read -p "Enter the numbers of target branches separated by space (or type custom branch names separated by space): " choices
    else
        read -p "Enter target branch names separated by space: " choices
    fi

    if [ -z "$choices" ]; then
        echo "Error: Target branch cannot be empty"
        return 1
    fi

    for choice in $choices; do
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ -n "$favorites" ]; then
                local target_branch=$(echo "$favorites" | sed -n "${choice}p")
                if [ -z "$target_branch" ]; then
                    echo "Invalid selection: $choice"
                    continue
                fi
                target_branches+=("$target_branch")
            else
                echo "Error: Cannot use numbers when no favorites exist"
                return 1
            fi
        else
            target_branches+=("$choice")
        fi
    done

    if [ ${#target_branches[@]} -eq 0 ]; then
        echo "Error: No valid target branches selected"
        return 1
    fi

    echo ""
    read -p "Enter PR title: " pr_title
    read -p "Enter PR description (optional, press Enter to skip): " pr_body

    echo ""
    echo "Will create ${#target_branches[@]} PR(s) from '$current_branch' to the following branches:"
    for branch in "${target_branches[@]}"; do
        echo "  - $branch"
    done
    echo ""
    read -p "Continue? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        return 0
    fi

    local success_count=0
    local fail_count=0

    for target_branch in "${target_branches[@]}"; do
        echo ""
        echo "Creating PR from '$current_branch' to '$target_branch'..."

        local pr_link=$(gh pr create --base "$target_branch" --title "$pr_title" --body "$pr_body" 2>&1)

        if echo "$pr_link" | grep -q "https://"; then
            echo "✓ Pull request created successfully!"
            echo "PR Link: $pr_link"
            ((success_count++))
        else
            echo "✗ Failed to create PR:"
            echo "$pr_link"
            ((fail_count++))
        fi
    done

    echo ""
    echo "Summary: $success_count successful, $fail_count failed"
}

# Show usage
show_usage() {
    echo "GitHub PR Helper"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create              Create a pull request"
    echo "  add <branch>        Add a branch to favorites (per repository)"
    echo "  remove <branch>     Remove a branch from favorites (per repository)"
    echo "  list                List favorite branches for current repository"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 create"
    echo "  $0 add main"
    echo "  $0 add develop"
    echo "  $0 list"
    echo ""
    echo "Favorites are stored per repository in a central location."
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
