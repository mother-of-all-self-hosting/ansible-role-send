<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Send

This is an [Ansible](https://www.ansible.com/) role which installs [Send](https://sendapp.org/help/dev/spec/architecture#send) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Send is a self-hosted server component for [Joplin](https://sendapp.org/) — a privacy-focused note taking and to-do application, which can handle a large number of notes organized into notebooks. Joplin is available on Desktop (Windows, macOS, and Linux) and mobile (Android and iOS). There is a [CLI application](https://sendapp.org/help/install/#terminal-application) as well.

Joplin offers multiple methods for application data synchronization among devices using End-to-End Encryption, including various cloud services like Nextcloud, Dropbox, Microsoft's OneDrive, etc. **As Send is designed specifically for Joplin, it offers improved performance, compared to other synchronization targets.**

While Joplin is architectured to be "offline first", with a Send it is able to not only synchronize data among devices but also [share a notebook](https://sendapp.org/help/apps/share_notebook/) with users and [publish a note](https://sendapp.org/help/apps/publish_note/) on the internet to share it with anyone.

See the project's [documentation](https://sendapp.org/help/) to learn what Joplin and Send do and why they might be useful to you.

## Adjusting the playbook configuration

To enable a Send with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting/mash-playbook) Ansible playbook.

```yaml
########################################################################
#                                                                      #
# send                                                                 #
#                                                                      #
########################################################################

send_enabled: true

########################################################################
#                                                                      #
# send                                                                 #
#                                                                      #
########################################################################
```

### Set the hostname

To enable the Send you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
send_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

If you wish to serve it under a prefix (`example.com/send`), you can do so by adding the following configuration to your `vars.yml` file (adapt to your needs).

```yaml
send_path_prefix: /send
```

### Configure the mailer

During installation, the Send by default creates its admin user with `admin@localhost` as its email address and `admin` as its password. To change the credentials from the admin page after logging in, authentication is required with an email sent to the updated email address. Email address authentication is also required by default for changing the credentials of non-admin users.

To enable email address authentication, you can configure the mailer by adding the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
send_environment_variable_mailer_enabled: true
send_environment_variable_mailer_host: ''  # Hostname
send_environment_variable_mailer_port: 587
send_environment_variable_mailer_user: ''  # Username of the SMTP user
send_environment_variable_mailer_password: ''  # Password of the SMTP user
send_environment_variable_mailer_noreply_name: ''
send_environment_variable_mailer_noreply_email: ''  # Email address of the sender

# Controls the `MAILER_SECURITY` environment variable
# Valid values: MailerSecurity.Starttls, MailerSecurity.Tls, MailerSecurity.None
send_environment_variable_mailer_security: MailerSecurity.Starttls
```

⚠️ **Note**: without setting an authentication method such as DKIM, SPF, and DMARC for your hostname, emails are most likely to be quarantined as spam at recipient's mail servers. If you have set up a mail server with the [MASH project's exim-relay Ansible role](https://github.com/mother-of-all-self-hosting/ansible-role-exim-relay), you can enable DKIM signing with it. Refer [its documentation](https://github.com/mother-of-all-self-hosting/ansible-role-exim-relay/blob/main/docs/configuring-exim-relay.md#enable-dkim-support-optional) for details.

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `send_environment_variables_additional_variables` variable

For a complete list of Send's config options that you could put in `send_environment_variables_additional_variables`, see its [environment variables](https://github.com/laurent22/send/blob/dev/packages/server/src/env.ts).

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/docs/just.md) are also available: `just install-all` or `just setup-all`

After the installation has completed, you can run the command below to confirm that the Joplin Sever is working properly:

```sh
curl https://example.com/api/ping
```

If it works properly, the command should return a message like this: `{"status":"ok","message":"Send is running"}`

## Usage

To configure and manage the Send, go to `example.com/login` specified with `send_hostname`, enter the admin credentials (email address: `admin@localhost`, password: `admin`) to log in. **After logging in, make sure to change the credentials.**

[<img src="../assets/send-login.png" title="Log in UI on Send" width="400">](../assets/send-login.png)

For security reason, the developer recommends [here](https://github.com/laurent22/send/tree/dev/packages/server#create-a-user-for-sync) to create a non-admin user for synchronization. You can create one on the "Users" page. After creating, you can use the email and password you specified for the user to synchronize data with your Joplin clients.

[<img src="../assets/send-admin-users.png" title="User administration UI on Send" width="400">](../assets/send-admin-users.png)

[<img src="../assets/send-add-user.png" title="Adding user UI on Send" width="400">](../assets/send-add-user.png)

### Configure the client application

ℹ️ *The instruction to download the client application is available at https://sendapp.org/help/install/.*

Open the configuration screen (see [the official documentation](https://sendapp.org/help/apps/config_screen) about how to; it depends on which platform you are on), and select the "synchronisation" section.

In the list of synchronization targets, select "Send (Beta)". Enter the Send URL (`example.com`), your email and password for your account, and confirm them. You can also configure synchronization interval (default: 5 minutes). Before confirming, you can make sure the configuration by selecting "Check synchronisation configuration".

[<img src="../assets/send-3.2.13.png" title="Synchronization configuration UI on Joplin 3.2.13 (AppImage)" width="400">](../assets/send-3.2.13.png)

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu send` (or how you/your playbook named the service, e.g. `mash-send`).

#### Enable stack traces

If you want to enable error stack traces, add the following configuration to your `vars.yml` file and re-run the playbook:

```yaml
send_environment_variable_error_stack_traces_enabled: true
```
