#!/bin/bash

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> storage/logs/deploy.log
}

# Ensure the script is called from the Laravel root folder
if [ ! -f artisan ]; then
    echo "Error: artisan file not found. Make sure you're in the Laravel root directory."
    exit 1
fi

# Log start of deployment
log_message "Deployment started."

# Get APP_ENV from .env file
APP_ENV=$(grep -w APP_ENV .env | cut -d '=' -f2)

# Install composer dependencies
log_message "Running composer install..."
if [ "$APP_ENV" == "production" ]; then
    composer install --no-dev --optimize-autoloader
else
    composer install
fi

if [ $? -ne 0 ]; then
    log_message "Composer install failed."
    echo "Error: Composer install failed."
    exit 1
fi

log_message "Composer install completed."

# Migrate the database
log_message "Running database migrations..."
php artisan migrate --force

if [ $? -ne 0 ]; then
    log_message "Database migration failed."
    echo "Error: Database migration failed."
    exit 1
fi

log_message "Database migrations completed."

# Seed the database
log_message "Seeding the database..."
php artisan db:seed --force

if [ $? -ne 0 ]; then
    log_message "Database seeding failed."
    echo "Error: Database seeding failed."
    exit 1
fi

log_message "Database seeding completed."

# Clear and optimize Laravel caches
log_message "Optimizing application..."
php artisan cache:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache

if [ $? -ne 0 ]; then
    log_message "Application optimization failed."
    echo "Error: Application optimization failed."
    exit 1
fi

log_message "Application optimized successfully."

# Log end of deployment
log_message "Deployment completed successfully."

# Success message
echo "Deployment completed successfully."
