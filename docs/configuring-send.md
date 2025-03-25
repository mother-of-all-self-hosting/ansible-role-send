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

This is an [Ansible](https://www.ansible.com/) role which installs [Send](https://github.com/timvisee/send) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

See the project's [documentation](https://github.com/timvisee/send/blob/master/README.md) to learn what Send does and why it might be useful to you.

## Adjusting the playbook configuration

To enable Send with this role, add the following configuration to your `vars.yml` file.

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

**Note**: hosting Send under a subpath (by configuring the `send_path_prefix` variable) does not seem to be possible due to Send's technical limitations.

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `send_environment_variables_additional_variables` variable

For a complete list of Send's config options that you could put in `send_environment_variables_additional_variables`, see its [environment variables](https://github.com/timvisee/send/blob/master/docs/docker.md#environment-variables).

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

Send should be available at the specified hostname like `https://example.com`.

It can be used via [CLI client](https://github.com/timvisee/ffsend). With the client you can upload a file specifying your host with `--host` option as below:

```sh
ffsend upload --host https://example.com YOUR_FILE_PATH_HERE
```

To download the file, you can use `ffsend download` command like below:

```sh
ffsend download https://example.com/#url-to-the-uploaded-file
```

See its [documentation](https://github.com/timvisee/ffsend/blob/master/README.md) for details about how to use the client.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu send` (or how you/your playbook named the service, e.g. `mash-send`).
