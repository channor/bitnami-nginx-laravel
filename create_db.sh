#!/bin/bash

# Fetch the root password for MariaDB
ROOT_PASSWORD=$(cat ~/bitnami_application_password)

# Ask for the database name
read -p "Enter the name of the new database: " DB_NAME

# Suggest a default username based on the database name
# Remove the last underscore if it exists, then append "_user"
USER_NAME=$(echo "$DB_NAME" | sed 's/_$//' | sed 's/\(.*\)_.*$/\1/')_user

# Prompt for the username, with the default option
read -p "Enter the username for the database (default: $USER_NAME): " DB_USER
DB_USER=${DB_USER:-$USER_NAME}

# Ask if the user wants to manually input a password or generate a random one
read -p "Would you like to generate a random password? (y/n): " GEN_PASSWORD

if [[ "$GEN_PASSWORD" =~ ^[Yy]$ ]]; then
    # Generate a random password
    DB_USER_PASSWORD=$(openssl rand -base64 12)
    echo "Generated password for user '$DB_USER': $DB_USER_PASSWORD"
else
    # Manually enter the password with confirmation
    while true; do
        read -sp "Enter the password for user '$DB_USER': " DB_USER_PASSWORD
        echo
        read -sp "Confirm the password: " DB_USER_PASSWORD_CONFIRM
        echo

        if [ "$DB_USER_PASSWORD" == "$DB_USER_PASSWORD_CONFIRM" ]; then
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
fi

# Log in to MariaDB as root and create the database and user
mariadb -u root -p"$ROOT_PASSWORD" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Output success message
if [ $? -eq 0 ]; then
    echo "Database '$DB_NAME' and user '$DB_USER' created successfully."
else
    echo "Failed to create database '$DB_NAME' or user '$DB_USER'."
fi
