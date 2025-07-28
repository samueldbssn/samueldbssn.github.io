#!/bin/bash
set -euo pipefail

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set variables for Obsidian to Hugo copy
currentUser=$USER

sourcePath="/home/$currentUser/Nextcloud/Luhman/posts"
destinationPath="/home/$currentUser/Nextcloud/website/blog/content"

# Set GitHub Repo
myrepo="git@github.com:samueldbssn/samueldbssn.github.io.git"

# Check for required commands
for cmd in git rsync python3 hugo; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd is not installed or not in PATH."
        exit 1
    fi
done

# Default: don't push
DO_PUSH=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --push)
            DO_PUSH=true
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--push]"
            exit 1
            ;;
    esac
done

# Step 1: Check if Git is initialized, and initialize if necessary
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
    git remote add origin $myrepo
else
    echo "Git repository already initialized."
    if ! git remote | grep -q 'origin'; then
        echo "Adding remote origin..."
        git remote add origin $myrepo
    fi
fi

# Step 2: Transform .md files into Hugo content folders
echo "Transforming Obsidian posts into Hugo-compatible folders..."

# Supprimer seulement les anciens index.md, pas les images
find "$destinationPath/posts" -type f -name index.md -exec rm -f {} \;

# Boucle sur chaque fichier markdown
for filepath in "$sourcePath"/*.md; do
    filename=$(basename "$filepath")
    name_no_ext="${filename%.md}"

    folder_name=$name_no_ext
    post_folder="$destinationPath/posts/$folder_name"

    mkdir -p "$post_folder"

    # Lire le fichier original
    original_content=$(cat "$filepath")

    # Séparer front matter et contenu
    frontmatter=$(awk '/^---$/ {f++; next} f==1 {print}' "$filepath")
    body=$(awk 'BEGIN{f=0} /^---$/ {f++; next} f==2 {print}' "$filepath")

    # Ajouter le Title dans le front matter
    updated_frontmatter="$frontmatter"$'\n'"Title: \"$name_no_ext\""

    # Reconstruire le fichier avec front matter modifié
    {
        echo "---"
        echo "$updated_frontmatter"
        echo "---"
        echo
        echo "$body"
    } > "$post_folder/index.md"
done

# Step 3: Process Markdown files with Python script to handle image links
echo "Processing image links in Markdown files..."

postsDir="$sourcePath"
attachmentsDir="/home/$currentUser/Nextcloud/Luhman/Attachments"
staticImagesDir="/home/$currentUser/Nextcloud/website/blog/static/images"
staticFilesDir="/home/$currentUser/Nextcloud/website/blog/static/files"

if [ ! -f "handle_attachments.py" ]; then
    echo "Python script handle_attachments.py not found."
    exit 1
fi

# Vérifier que les dossiers existent
if [ ! -d "$postsDir" ] || [ ! -d "$attachmentsDir" ] || [ ! -d "$staticImagesDir" ]; then
    echo "One or more required directories do not exist:"
    echo "postsDir: $postsDir"
    echo "attachmentsDir: $attachmentsDir"
    echo "staticImagesDir: $staticImagesDir"
    exit 1
fi

# Lancer le script avec les bons arguments
if ! python3 handle_attachments.py "$postsDir" "$attachmentsDir" "$staticImagesDir" "$staticFilesDir" "$destinationPath/posts"; then
    echo "Failed to process image links."
    exit 1
fi

# Step 4: Build the Hugo site
echo "Building the Hugo site..."
cd blog || { echo "Failed to enter 'blog' directory."; exit 1; }
if ! hugo; then
    echo "Hugo build failed."
    exit 1
fi

cd ..

if [ "$DO_PUSH" = true ]; then
    # Step 5: Add changes to Git
    echo "Staging changes for Git..."
    if git diff --quiet && git diff --cached --quiet; then
        echo "No changes to stage."
    else
        git add .
    fi

    # Step 6: Commit changes with a dynamic message
    commit_message="New Blog Post on $(date +'%Y-%m-%d %H:%M:%S')"
    if git diff --cached --quiet; then
        echo "No changes to commit."
    else
        echo "Committing changes..."
        git commit -m "$commit_message"
    fi

    # Step 7: Push all changes to the main branch
    echo "Deploying to GitHub Main..."
    if ! git push origin master; then
        echo "Failed to push to master branch."
        exit 1
    fi

    # Step 8: Push the public folder to the deploy branch using subtree split and force push
    echo "Deploying to GitHub Deploy..."
    if git branch --list | grep -q 'deploy'; then
        git branch -D deploy
    fi

    if ! git subtree split --prefix public -b deploy; then
        echo "Subtree split failed."
        exit 1
    fi

    if ! git push origin deploy --force; then
        echo "Failed to push to branch."
        git branch -D deploy
        exit 1
    fi

    git branch -D deploy
else
    echo "Skipping Git commit and push (use --push to enable)."
fi

#!/bin/bash
set -euo pipefail

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set variables for Obsidian to Hugo copy
currentUser=$USER

sourcePath="/home/$currentUser/Nextcloud/Luhman/posts"
destinationPath="/home/$currentUser/Nextcloud/website/blog/content"

# Set GitHub Repo
myrepo="git@github.com:samueldbssn/samueldbssn.github.io.git"

# Check for required commands
for cmd in git rsync python3 hugo; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd is not installed or not in PATH."
        exit 1
    fi
done

# Default: don't push
DO_PUSH=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --push)
            DO_PUSH=true
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--push]"
            exit 1
            ;;
    esac
done

# Step 1: Check if Git is initialized, and initialize if necessary
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
    git remote add origin $myrepo
else
    echo "Git repository already initialized."
    if ! git remote | grep -q 'origin'; then
        echo "Adding remote origin..."
        git remote add origin $myrepo
    fi
fi

# Step 2: Transform .md files into Hugo content folders
echo "Transforming Obsidian posts into Hugo-compatible folders..."

# Supprimer seulement les anciens index.md, pas les images
find "$destinationPath/posts" -type f -name index.md -exec rm -f {} \;

# Boucle sur chaque fichier markdown
for filepath in "$sourcePath"/*.md; do
    filename=$(basename "$filepath")
    name_no_ext="${filename%.md}"

    folder_name=$name_no_ext
    post_folder="$destinationPath/posts/$folder_name"

    mkdir -p "$post_folder"

    # Lire le fichier original
    original_content=$(cat "$filepath")

    # Séparer front matter et contenu
    frontmatter=$(awk '/^---$/ {f++; next} f==1 {print}' "$filepath")
    body=$(awk 'BEGIN{f=0} /^---$/ {f++; next} f==2 {print}' "$filepath")

    # Ajouter le Title dans le front matter
    updated_frontmatter="$frontmatter"$'\n'"Title: \"$name_no_ext\""

    # Reconstruire le fichier avec front matter modifié
    {
        echo "---"
        echo "$updated_frontmatter"
        echo "---"
        echo
        echo "$body"
    } > "$post_folder/index.md"
done

# Step 3: Process Markdown files with Python script to handle image links
echo "Processing image links in Markdown files..."

postsDir="$sourcePath"
attachmentsDir="/home/$currentUser/Nextcloud/Luhman/Attachments"
staticImagesDir="/home/$currentUser/Nextcloud/website/blog/static/images"
staticFilesDir="/home/$currentUser/Nextcloud/website/blog/static/files"

if [ ! -f "handle_attachments.py" ]; then
    echo "Python script handle_attachments.py not found."
    exit 1
fi

# Vérifier que les dossiers existent
if [ ! -d "$postsDir" ] || [ ! -d "$attachmentsDir" ] || [ ! -d "$staticImagesDir" ]; then
    echo "One or more required directories do not exist:"
    echo "postsDir: $postsDir"
    echo "attachmentsDir: $attachmentsDir"
    echo "staticImagesDir: $staticImagesDir"
    exit 1
fi

# Lancer le script avec les bons arguments
if ! python3 handle_attachments.py "$postsDir" "$attachmentsDir" "$staticImagesDir" "$staticFilesDir" "$destinationPath/posts"; then
    echo "Failed to process image links."
    exit 1
fi

# Step 4: Build the Hugo site
echo "Building the Hugo site..."
if ! hugo; then
    echo "Hugo build failed."
    exit 1
fi

if [ "$DO_PUSH" = true ]; then
    # Step 5: Add changes to Git
    echo "Staging changes for Git..."
    if git diff --quiet && git diff --cached --quiet; then
        echo "No changes to stage."
    else
        git add .
    fi

    # Step 6: Commit changes with a dynamic message
    commit_message="New Blog Post on $(date +'%Y-%m-%d %H:%M:%S')"
    if git diff --cached --quiet; then
        echo "No changes to commit."
    else
        echo "Committing changes..."
        git commit -m "$commit_message"
    fi

    # Step 7: Push all changes to the main branch
    echo "Deploying to GitHub Main..."
    if ! git push origin master; then
        echo "Failed to push to master branch."
        exit 1
    fi

    # Step 8: Push the public folder to the deploy branch using subtree split and force push
    echo "Deploying to GitHub Deploy..."
    if git branch --list | grep -q 'deploy'; then
        git branch -D deploy
    fi

    if ! git subtree split --prefix public -b deploy; then
        echo "Subtree split failed."
        exit 1
    fi

    if ! git push origin deploy --force; then
        echo "Failed to push to branch."
        git branch -D deploy
        exit 1
    fi

    git branch -D deploy
else
    echo "Skipping Git commit and push (use --push to enable)."
fi
