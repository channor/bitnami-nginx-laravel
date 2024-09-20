# Laravel Queue Worker Setup with Supervisor on Bitnami Nginx (AWS Lightsail)

This guide provides instructions to set up **Supervisor** for managing Laravel queue workers on an AWS Lightsail instance using Bitnami's Nginx stack. It supports multiple Laravel projects, ensuring that your queued jobs run reliably in the background.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Install Supervisor](#step-1-install-supervisor)
3. [Step 2: Verify PHP and Composer Paths](#step-2-verify-php-and-composer-paths)
4. [Step 3: Configure Supervisor for Laravel Projects](#step-3-configure-supervisor-for-laravel-projects)
5. [Step 4: Update and Start Supervisor Workers](#step-4-update-and-start-supervisor-workers)
6. [Step 5: Ensure Supervisor Starts on Boot](#step-5-ensure-supervisor-starts-on-boot)
7. [Step 6: Manage Supervisor Workers](#step-6-manage-supervisor-workers)
8. [Troubleshooting](#troubleshooting)
9. [Notes](#notes)

---

## Prerequisites

- **AWS Lightsail Instance** with Bitnami's Nginx stack.
- **One or More Laravel Projects** deployed on the server.
- **SSH Access** with sudo privileges.
- **Laravel configured to use the database queue driver** (or another supported driver).

---

## Step 1: Install Supervisor

Supervisor is a process control system that allows you to monitor and control processes on UNIX-like operating systems.

1. **Update Package Lists**

   ```bash
   sudo apt-get update
   ```

2. **Install Supervisor**

   ```bash
   sudo apt-get install supervisor
   ```

3. **Verify Installation**

   ```bash
   sudo systemctl status supervisor
   ```

   Ensure Supervisor is **active and running**. If not, start it using:

   ```bash
   sudo systemctl start supervisor
   ```

---

## Step 2: Verify PHP and Composer Paths

Ensure that PHP and Composer are installed and accessible. Bitnami stacks often have their own PHP binaries.

1. **Check PHP Path**

   Bitnami typically uses its own PHP binary. Verify the PHP version:

   ```bash
   /opt/bitnami/php/bin/php -v
   ```

2. **Check Composer Path**

   If Composer isn't installed globally, install it:

   ```bash
   curl -sS https://getcomposer.org/installer | php
   sudo mv composer.phar /usr/local/bin/composer
   ```

   Verify installation:

   ```bash
   composer --version
   ```

---

## Step 3: Configure Supervisor for Laravel Projects

Create separate Supervisor configuration files for each Laravel project. This allows Supervisor to manage queue workers independently for each project.

### Example Configuration Structure

Each Supervisor configuration file should include:

- **Program Name:** A unique identifier for the worker.
- **Command:** The command to run the Laravel queue worker.
- **Directory:** The working directory of the Laravel project.
- **User:** The system user under which the worker should run (commonly `bitnami` for Bitnami stacks).
- **Autostart & Autorestart:** Ensure the worker starts on boot and restarts on failure.
- **Logging:** Specify log file locations.

### Creating a Supervisor Configuration File

1. **Navigate to Supervisor Configuration Directory**

   ```bash
   cd /etc/supervisor/conf.d/
   ```

2. **Create a Configuration File for Your Laravel Project**

   Replace `your-project` with a unique name for your project.

   ```bash
   sudo nano your-project-worker.conf
   ```

3. **Add the Following Configuration**

   ```ini
   [program:your-project-worker]
   process_name=%(program_name)s_%(process_num)02d
   command=/opt/bitnami/php/bin/php /path/to/your/project/artisan queue:work database --sleep=3 --tries=3 --timeout=90
   directory=/path/to/your/project
   user=bitnami
   autostart=true
   autorestart=true
   numprocs=1
   redirect_stderr=true
   stdout_logfile=/path/to/your/project/storage/logs/worker.log
   environment=APP_ENV="production",APP_DEBUG="false"
   ```

   **Notes:**
   - **`command`:** Adjust the PHP path if different. Replace `/path/to/your/project` with the absolute path to your Laravel project.
   - **`user`:** Typically `bitnami` for Bitnami stacks.
   - **`stdout_logfile`:** Path to the worker log file within your Laravel project.
   - **`environment`:** Set environment variables as needed. Alternatively, use a wrapper script to load variables from the `.env` file.

4. **Save and Exit**

   Press `CTRL + O` to save and `CTRL + X` to exit the editor.

5. **Repeat for Additional Projects**

   Create separate configuration files for each Laravel project you wish to manage.

---

## Step 4: Update and Start Supervisor Workers

After creating the configuration files, instruct Supervisor to recognize and start managing the workers.

1. **Reread Supervisor Configurations**

   ```bash
   sudo supervisorctl reread
   ```

   You should see output indicating that new configurations are available.

2. **Update Supervisor to Apply Changes**

   ```bash
   sudo supervisorctl update
   ```

   This command starts the newly configured workers.

3. **Verify Workers are Running**

   ```bash
   sudo supervisorctl status
   ```

   **Expected Output:**

   ```
   your-project-worker:your-project-worker_00   RUNNING   pid 12345, uptime 0:00:10
   another-project-worker:another-project-worker_00 RUNNING pid 12346, uptime 0:00:10
   ```

---

## Step 5: Ensure Supervisor Starts on Boot

Supervisor is typically configured to start on system boot. Verify this to ensure your queue workers run after a reboot.

1. **Enable Supervisor to Start on Boot**

   ```bash
   sudo systemctl enable supervisor
   ```

2. **(Optional) Reboot to Test**

   ```bash
   sudo reboot
   ```

3. **After Reboot, Check Supervisor Status**

   ```bash
   sudo systemctl status supervisor
   sudo supervisorctl status
   ```

   Ensure all configured workers are **RUNNING**.

---

## Step 6: Manage Supervisor Workers

Use `supervisorctl` to control your workers as needed.

- **Restart a Worker**

  ```bash
  sudo supervisorctl restart your-project-worker:*
  ```

- **Stop a Worker**

  ```bash
  sudo supervisorctl stop your-project-worker:*
  ```

- **Start a Worker**

  ```bash
  sudo supervisorctl start your-project-worker:*
  ```

- **Reload All Workers**

  ```bash
  sudo supervisorctl reload
  ```

---

## Troubleshooting

If you encounter issues while setting up Supervisor or the queue workers, consider the following steps:

1. **Check Supervisor Logs**

   ```bash
   sudo tail -f /var/log/supervisor/supervisord.log
   ```

2. **Check Worker Logs**

   ```bash
   tail -f /path/to/your/project/storage/logs/worker.log
   ```

3. **Check Laravel Logs**

   ```bash
   tail -f /path/to/your/project/storage/logs/laravel.log
   ```

4. **Test Queue Worker Manually**

   Run the queue worker manually to ensure it processes jobs correctly.

   ```bash
   cd /path/to/your/project
   /opt/bitnami/php/bin/php artisan queue:work database --sleep=3 --tries=3 --timeout=90
   ```

   If jobs are processed successfully, the issue might be with Supervisor's configuration.

5. **Restart Supervisor**

   ```bash
   sudo systemctl restart supervisor
   ```

6. **Verify PHP Version Compatibility**

   Ensure that the PHP version used by Supervisor matches the version required by your Laravel projects.

   ```bash
   /opt/bitnami/php/bin/php -v
   ```

---

## Notes

- **Environment Variables:** Ensure all necessary environment variables are correctly set in the Supervisor configuration or loaded via a wrapper script.
- **Permissions:** The user running the Supervisor workers (commonly `bitnami`) should have appropriate permissions for project directories and log files.
- **Multiple Projects:** Repeat the configuration steps for each Laravel project you wish to manage with Supervisor.
- **Customizing Queue Settings:** Adjust the `queue:work` command options (`--sleep`, `--tries`, `--timeout`) based on your project's requirements.

---

By following this guide, you can efficiently manage Laravel queue workers across multiple projects on an AWS Lightsail instance using Bitnami's Nginx stack and Supervisor. This setup ensures that your queued jobs are processed reliably, enhancing the performance and responsiveness of your Laravel applications.
