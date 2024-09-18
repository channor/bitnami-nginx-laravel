#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display error messages
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
for cmd in mariadb openssl sed; do
    if ! command_exists "$cmd"; then
        error_exit "Required command '$cmd' is not installed. Please install it and try again."
    fi
done

# Path to the Bitnami application password file
PASSWORD_FILE="$HOME/bitnami_application_password"

# Check if the password file exists and is readable
if [[ ! -f "$PASSWORD_FILE" ]]; then
    error_exit "Password file '$PASSWORD_FILE' does not exist."
fi

if [[ ! -r "$PASSWORD_FILE" ]]; then
    error_exit "Password file '$PASSWORD_FILE' is not readable. Please check permissions."
fi

# Fetch the root password for MariaDB
ROOT_PASSWORD=$(cat "$PASSWORD_FILE") || error_exit "Failed to read the root password."

# Function to generate default username
generate_default_username() {
    local db_name="$1"
    echo "${db_name%_*}_user"
}

# Function to validate database and username
validate_name() {
    local name="$1"
    # MariaDB database and user names should not contain spaces or special characters
    if [[ ! "$name" =~ ^[a-zA-Z0-9_]+$ ]]; then
        error_exit "Invalid name '$name'. Only letters, numbers, and underscores are allowed."
    fi
}

# Ask for the database name
read -p "Enter the name of the new database: " DB_NAME
validate_name "$DB_NAME"

# Suggest a default username based on the database name
DEFAULT_USER=$(generate_default_username "$DB_NAME")

# Prompt for the username, with the default option
read -p "Enter the username for the database (default: $DEFAULT_USER): " DB_USER
DB_USER=${DB_USER:-$DEFAULT_USER}
validate_name "$DB_USER"

# Ask if the user wants to manually input a password or generate a random one
while true; do
    read -p "Would you like to generate a random password? (y/n): " GEN_PASSWORD
    case "$GEN_PASSWORD" in
        [Yy]* )
            # Generate a random password
            DB_USER_PASSWORD=$(openssl rand -base64 12)
            echo "Generated password for user '$DB_USER': $DB_USER_PASSWORD"
            break
            ;;
        [Nn]* )
            # Manually enter the password with confirmation
            while true; do
                read -sp "Enter the password for user '$DB_USER': " DB_USER_PASSWORD
                echo
                read -sp "Confirm the password: " DB_USER_PASSWORD_CONFIRM
                echo

                if [[ "$DB_USER_PASSWORD" == "$DB_USER_PASSWORD_CONFIRM" ]]; then
                    # Ensure password is not empty
                    if [[ -z "$DB_USER_PASSWORD" ]]; then
                        echo "Password cannot be empty. Please try again."
                    else
                        break
                    fi
                else
                    echo "Passwords do not match. Please try again."
                fi
            done
            break
            ;;
        * )
            echo "Please answer 'y' or 'n'."
            ;;
    esac
done

# Confirm the actions with the user
echo
echo "You are about to create the following:"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Password: [HIDDEN]"
read -p "Do you want to proceed? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

# Function to execute MariaDB commands
execute_mariadb_commands() {
    local root_pwd="$1"
    shift
    mariadb -u root -p"$root_pwd" <<EOF
CREATE DATABASE \`$DB_NAME\`;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
}

# Execute the MariaDB commands
if execute_mariadb_commands "$ROOT_PASSWORD"; then
    echo "Database '$DB_NAME' and user '$DB_USER' created successfully."
    if [[ "$GEN_PASSWORD" =~ ^[Yy]$ ]]; then
        echo "Generated password for '$DB_USER': $DB_USER_PASSWORD"
    fi
else
    error_exit "Failed to create database '$DB_NAME' or user '$DB_USER'."
fi
