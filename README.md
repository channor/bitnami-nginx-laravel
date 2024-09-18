# bitnami-nginx-laravel

## Initial script

```bash
sudo apt update && apt updgrade
```

## Setup SSH with GitHub

1. **Generate a new SSH key**: Replace `<email>` with your GitHub email. This will generate an SSH key that you can use for authentication with GitHub.

   ```bash
   ssh-keygen -t ed25519 -C "<email>"
   ```

   When prompted, you can either press `Enter` to accept the default location for saving the key or specify a custom path. Optionally, you can add a passphrase for additional security.

2. **Copy the public key**: After generating the key, copy the newly generated public key by running the following command:

   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

3. **Add the key to your GitHub account**:
   - Go to your GitHub account settings.
   - Navigate to **SSH and GPG keys**.
   - Click **New SSH key**.
   - Paste the public key into the key field and give it a recognizable title.

## Create database and user


