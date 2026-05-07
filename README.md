# GitHub PR Helper

A simple bash script to help you create GitHub pull requests with your favorite target branches.

## Features

- Create pull requests from current branch to multiple target branches
- Save and manage favorite target branches per repository
- Centralized favorites storage (shared across machines if synced)
- Simple command-line interface
- Works with GitHub CLI (`gh`)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/workplace-utility.git
cd workplace-utility
```

2. Add the helper function to your shell configuration:

**For ZSH (add to `~/.zshrc`):**
```bash
# PR Helper - Create GitHub pull requests
pr-helper() {
    /path/to/workplace-utility/github-pr-helper.sh "$@"
}
```

3. Reload your shell:
```bash
source ~/.zshrc
```

4. Ensure GitHub CLI is installed:
```bash
gh --version
```

If not installed, get it from: https://cli.github.com/

## Usage

### Available Commands

```bash
pr-helper create              # Create a pull request
pr-helper add <branch>        # Add a branch to favorites
pr-helper remove <branch>     Remove a branch from favorites
pr-helper list                List favorite branches
pr-helper help                Show help message
```

### Creating Pull Requests

#### Single Target Branch
```bash
pr-helper create
```
This will:
1. Show your current branch and repository
2. Display your favorite target branches (if any)
3. Ask you to select target branches by number or enter custom names
4. Ask for PR title and description
5. Create the pull request

#### Multiple Target Branches
```bash
pr-helper create
```
When prompted for target branches, enter multiple selections separated by space:
- Use numbers: `1 2 3`
- Mix numbers and custom: `1 custom-branch`
- Multiple custom: `main develop staging`

The script will ask for confirmation before creating multiple PRs.

### Managing Favorites

#### Add a Branch to Favorites
```bash
pr-helper add main
pr-helper add develop
pr-helper add staging
```

#### List Favorite Branches
```bash
pr-helper list
```
This shows favorites for the current repository only.

#### Remove a Branch from Favorites
```bash
pr-helper remove develop
```

## How Favorites Work

Favorites are stored **per repository** in a centralized file:
- Location: `.pr-favourites` in the script directory
- Identified by: Git remote URL (e.g., `git@github.com:user/repo.git`)
- Format: Repository URL followed by branch names

### Example Favorites File Structure
```
https://github.com/user/repo1.git
main
develop

git@github.com:user/repo2.git
staging
production
```

### Benefits
- Each repository has its own favorites
- Favorites are stored in one central location
- Can be synced across machines
- No `.pr-favourites` files cluttering your repositories

## Workflow Example

1. **Set up favorites for a new project:**
```bash
cd ~/projects/my-project
pr-helper add main
pr-helper add develop
pr-helper list
```

2. **Create a feature branch and work on changes:**
```bash
git checkout -b feature/new-feature
# ... make changes ...
git add .
git commit -m "Add new feature"
```

3. **Create PR to multiple branches:**
```bash
pr-helper create
# When prompted, enter: "1 2" (for main and develop)
# Enter title and description
# Confirm and PRs will be created
```

## Requirements

- Git repository with remote configured
- GitHub CLI (`gh`) installed and authenticated
- Bash shell (or ZSH with the wrapper function)

## Troubleshooting

### "Error: Cannot determine repository URL"
Ensure you're in a git repository with a remote configured:
```bash
git remote -v
```

### "Error: GitHub CLI (gh) is not installed"
Install GitHub CLI from: https://cli.github.com/

### Favorites not showing
Check that you're in the correct repository:
```bash
git remote get-url origin
```

### Script not found
Verify the path in your shell configuration matches the actual script location:
```bash
which pr-helper
```

## File Structure

```
workplace-utility/
├── github-pr-helper.sh    # Main script
├── .pr-favourites         # Centralized favorites (gitignored)
├── .gitignore            # Ignores .pr-favourites
└── README.md             # This file
```

## License

MIT License
