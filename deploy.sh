#!/bin/bash

# =========================================
# Enhanced Deployment Script for Laravel Application
# =========================================

# ---------------------------
# Function Definitions
# ---------------------------

# Function to log messages
log() {
    echo "$(date +"%Y-%m-%d %T") : $1" | tee -a "$LOG_FILE"
}

# Function to execute commands and handle errors
execute() {
    eval "$1"
    if [ $? -ne 0 ]; then
        log "❌ Error: $2"
        exit 1
    fi
}

# Function to list directories in /opt/bitnami/projects/
list_project_dirs() {
    echo "📁 Available Project Directories in /opt/bitnami/projects/:"
    select dir in /opt/bitnami/projects/*/; do
        if [ -n "$dir" ]; then
            APP_DIR="${dir%/}"  # Remove trailing slash
            echo "✅ Selected Directory: $APP_DIR"
            break
        else
            echo "❌ Invalid selection. Please try again."
        fi
    done
}

# Function to list remote Git branches
list_git_branches() {
    echo "🔀 Fetching remote Git branches..."
    execute "git fetch origin" "Failed to fetch remote branches."

    # Get current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "🌟 Current Branch: $CURRENT_BRANCH"

    # Get list of remote branches
    REMOTE_BRANCHES=$(git branch -r | grep origin/ | sed 's/origin\///')

    echo "📌 Available Remote Branches:"
    # Use an array to store branch options
    IFS=$'\n' read -rd '' -a BRANCH_ARRAY <<< "$REMOTE_BRANCHES"

    # Default selection is the current branch
    SELECTED_BRANCH="$CURRENT_BRANCH"

    PS3="Select the branch to deploy (default: $CURRENT_BRANCH): "

    select branch in "${BRANCH_ARRAY[@]}"; do
        if [ -n "$branch" ]; then
            SELECTED_BRANCH="$branch"
            echo "✅ Selected Branch: $SELECTED_BRANCH"
            break
        else
            echo "❌ Invalid selection. Using default branch: $CURRENT_BRANCH"
            SELECTED_BRANCH="$CURRENT_BRANCH"
            break
        fi
    done

    # If the current branch is not in remote branches, offer to select from remote
    if [[ ! " ${BRANCH_ARRAY[@]} " =~ " ${CURRENT_BRANCH} " ]]; then
        read -p "Current branch '$CURRENT_BRANCH' is not a remote branch. Do you want to use it? (y/N): " use_current
        case "$use_current" in
            [yY][eE][sS]|[yY])
                SELECTED_BRANCH="$CURRENT_BRANCH"
                ;;
            *)
                echo "❌ Deployment aborted. Please select a valid remote branch."
                exit 1
                ;;
        esac
    fi
}

# Function to select deployment environment
select_environment() {
    echo "🌐 Select Deployment Environment:"
    select env in "Production" "Staging" "Development"; do
        case "$env" in
            Production|Staging|Development)
                ENVIRONMENT="$env"
                echo "✅ Selected Environment: $ENVIRONMENT"
                break
                ;;
            *)
                echo "❌ Invalid selection. Please choose a valid environment."
                ;;
        esac
    done
}

# ---------------------------
# Start Deployment
# ---------------------------

echo "🚀 Laravel Deployment Script"

# Step 1: Select Application Directory
list_project_dirs

# Step 2: Navigate to the application directory
cd "$APP_DIR" || { echo "❌ Failed to navigate to application directory: $APP_DIR"; exit 1; }

# Step 3: Select Git Branch
list_git_branches

# Step 4: Select Deployment Environment
select_environment

# Step 5: Set LOG_FILE path
LOG_FILE="$APP_DIR/storage/logs/deploy.log"

# Step 6: Start Logging
log "🔄 Starting Deployment Process for $APP_DIR on branch '$SELECTED_BRANCH' in '$ENVIRONMENT' environment."

# Step 7: Fetch latest changes from GitHub
log "📥 Fetching latest changes from GitHub (branch: $SELECTED_BRANCH)..."

# Set the remote branch
REMOTE_BRANCH="origin/$SELECTED_BRANCH"

# Attempt to fetch and merge the selected branch
execute "git fetch origin \"$SELECTED_BRANCH\"" "Failed to fetch branch '$SELECTED_BRANCH' from GitHub."

if git merge "$REMOTE_BRANCH"; then
    log "✅ Git pull successful for branch '$SELECTED_BRANCH'."
else
    log "⚠️ Git pull encountered conflicts or errors."
    read -p "Do you want to force pull and overwrite local changes? (y/N): " FORCE_PULL
    case "$FORCE_PULL" in
        [yY][eE][sS]|[yY])
            log "🛑 Force pulling changes..."
            execute "git reset --hard \"$REMOTE_BRANCH\"" "Force pull failed."
            ;;
        *)
            log "🚫 Deployment aborted by user."
            exit 1
            ;;
    esac
fi

# Step 8: Install/update Composer dependencies
if [ "$ENVIRONMENT" = "Production" ]; then
    COMPOSER_FLAGS="--no-interaction --prefer-dist --optimize-autoloader --no-dev"
    log "📦 Installing/updating Composer dependencies (Production - excluding dev packages)..."
else
    COMPOSER_FLAGS="--no-interaction --prefer-dist --optimize-autoloader"
    log "📦 Installing/updating Composer dependencies..."
fi
execute "composer install $COMPOSER_FLAGS" "Composer install failed."

# Step 9: Clear and cache configuration
log "🔧 Caching configuration..."
execute "php artisan config:cache" "Config cache failed."

# Step 10: Clear and cache routes
log "🗺️ Caching routes..."
execute "php artisan route:cache" "Route cache failed."

# Step 11: Clear and cache views
log "👁️ Caching views..."
execute "php artisan view:cache" "View cache failed."

# Step 12: Run database migrations
log "🔄 Running database migrations..."
execute "php artisan migrate --force" "Database migrations failed."

# (Optional) Step 13: Run database seeders
# Uncomment the lines below if you need to run seeders
# log "🌱 Running database seeders..."
# execute "php artisan db:seed --force" "Database seeding failed."

# Step 14: Optimize the application
log "⚡ Optimizing the application..."
execute "php artisan optimize" "Application optimization failed."

# Step 15: Clear any remaining caches
log "🧹 Clearing unnecessary caches..."
execute "php artisan cache:clear" "Cache clear failed."
execute "php artisan config:clear" "Config clear failed."

# Final message
log "🎉 Deployment completed successfully!"

exit 0
