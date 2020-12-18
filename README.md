# Ansible role "papanito.cloudflared" <!-- omit in toc -->

[![Ansible Role](https://img.shields.io/ansible/role/49833)](https://galaxy.ansible.com/papanito/cloudflared) [![Ansible Quality Score](https://img.shields.io/ansible/quality/49833)](https://galaxy.ansible.com/papanito/cloudflared) [![Ansible Role](https://img.shields.io/ansible/role/d/49833)](https://galaxy.ansible.com/papanito/cloudflared) [![GitHub issues](https://img.shields.io/github/issues/papanito/ansible-role-cloudflared)](https://github.com/papanito/ansible-role-cloudflared/issues) [![GitHub pull requests](https://img.shields.io/github/issues-pr/papanito/ansible-role-cloudflared)](https://github.com/papanito/ansible-role-cloudflared/pulls)

- [Authenticate the daemon](#authenticate-the-daemon)
- [Requirements](#requirements)
- [Role Variables](#role-variables)
  - [General parameters](#general-parameters)
  - [Cloudflare parameters](#cloudflare-parameters)
  - [SSH Client config](#ssh-client-config)
- [Dependencies](#dependencies)
- [Example Playbook](#example-playbook)
- [Test](#test)
- [License](#license)
- [Author Information](#author-information)

This ansible role does download and install `cloudflared` on the host and optionally installs the [argo-tunnel] as a service. 

The role is made in a way that you can install multiple services in parallel - simply run the role several times with different parameters `service`, `hostname` and `url`.

The role performs the following steps:

1. Download and install binary according to [downloads]
1. Install/configure the daemon - see [Authenticate the daemon](#authenticate-the-daemon)
1. Create a config file per `service` in `/etc/cloudflare`

    The file is named `{{ tunnel }}.yml` and will contain the minimal configuration is as follows

    ```yaml
    hostname: {{ hostname }}
    url: {{ url }}
    logfile: /var/log/cloudflared_{{ tunnel }}.log
    ```

    Additional parameters are configured via [Cloudflare parameters](#cloudflare-parameters)

1. Create a [systemd-unit-template] `cloudflared@{{ tunnel }}.service` and start an instance for each service in the list of `tunnels`

    ```bash
    cloudflared tunnel --config {{ tunnel }}.yml
    ```

## Authenticate the daemon

According to [authenticate-the-cloudflare-daemon] when authenticate the daemon, there is a browser window opened or - if this is not possible - then the link has to be put manually. During this time the daemon waits. I could not come up with a solution how to automate this behavior so I came up with the following implementation.

- if nothing is specified, then ansible calls the `cloudflared login` and will continue when the authentication is done - this makes sens if you use the role to install the daemon locally on your machine and where you have a browser window
- if `cert_location` the certificate is actually copied from the `cert_location`, or if `cert_content` is defined then the certificate is created directly from the value stored in it. So you could login once to cloudflare from your master node (where you run ansible) or from a remote location.

   You can encrypt the `cert.pem` with ansible vault and store it somewhere save.

References:

- [downloads] - cloudflared download instructions
- [ssh-guide] - ssh connections with cloudflared
- [cli-args] - command-line arguments
- [config] - The configuration file format uses YAML syntax

## Requirements

none

## Role Variables

### General parameters

These are all variables

|Parameter|Description|Default Value|
|---------|-----------|-------------|
|`systemd_user`|User for systemd service|`backup`|
|`systemd_group`|Group for systemd service|`backup`|
|`download_baseurl`|Base url for `cloudflare` binaries|https://bin.equinox.io/c/VdrWdbjqyF/|
|`cert_location`|Location of the certificate to be copied - see [Authenticate the daemon](#authenticate-the-daemon)|-|
|`cert_content`|Content of the certificate to be copied - see [Authenticate the daemon](#authenticate-the-daemon)|-|
|`install_only`|Set to `true` if you only want to install the binary without any configuration or login|`false`|
|`ssh_client_config`|Set to `true` if you want to configure the proxy configuration for your [ssh-guide-client], see [SSH Client config](#ssh-client-config)|`false`|
|`ssh_client_config_group`|Name of the inventory group for which the ssh proxy config shall be created, see [SSH Client config](#ssh-client-config)|``|
|`force_install`|Set to `true` if you want to re-install `cloudflared`. By default the assumption is that `cloudflared` is running as a service and automatically auto-updates.|`false`|
|`tunnels`|[Mandatory] List of services, each one defining [Cloudflare parameters](#cloudflare-parameters)|-|
|`do_legacy_cleanup`|Due to the changes of switching to [systemd-unit-template] you may need to cleanup the "legacy" stuff, if you used the role before.|`false`|
|`remove_unused_tunnels`|Removes unused tunnels, means tunnels running but not listed in `tunnels`.|`false`|

### Cloudflare parameters

Tunnel-specific parameters available for configuring `cloudflared` according to [cli-args].

```yaml
tunnels:
  ssh:
    hostname: xxx
    url: ssh.mycompany.com
```

|Parameter|Description|Default Value|
|---------|-----------|-------------|
|`hostname`|[Mandatory] Argo-tunnel hostname according to [config] e.g. `tunnel.example.com`|-|
|`url`|[Mandatory] url to which to connect to [config] e.g. `ssh://localhost:22` or `https://localhost:443`|-|
|`lb_pool`|LoadBalancer pool name - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#lb-pool)|-|
|`autoupdate_freq`|Autoupdate frequency - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#autoupdate-freq)|`24h`|
|`no_autoupdate`|Disable periodic check for updates, restarting the server with the new version - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#lb-pool)|`false`|
|`no_tls_verify`|Disables TLS verification of the certificate presented by your origin. Will allow any certificate from the origin to be accepted - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#no-tls-verify)|-|
|`origin_ca_pool`|Path to the CA for the certificate of your origin. This option should be used only if your certificate is not signed by Cloudflare - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#origin-ca-pool)|-|
|`origin_server_name`|Hostname that `cloudflared` should expect from your origin server certificate - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#origin-server-name)|-|
|`metrics`|Address to query for usage metrics - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#metrics)|`localhost:`|
|`metrics_update_freq`|Frequency to update tunnel metrics - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#metrics-update-freq)|`5s`|
|`tag`|Custom tags used to identify this tunnel, in format `KEY=VALUE` - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#tag)|-|
|`loglevel`|Specifies the verbosity of logging. The default "info" is not noisy, but you may wish to run with "warn" in production - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#loglevel)|`info`|
|`proto_loglevel`|Specifies the verbosity of the HTTP/2 protocol logging. Any value below 'warn' is noisy and should only be used to debug low - level performance issues and protocol quirks - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#proto-loglevel)|`info`|
|`retries`|Maximum number of retries for connection/protocol errors. Retries use exponential backoff (retrying at 1, 2, 4, 8, 16 seconds by default) so increasing this value significantly is not recommended - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#retries)|`5`|
|`no_chunked_encoding`|Disables chunked transfer encoding; useful if you are running a WSGI server - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#no-chunked-encoding)|`false`|
|`no_logfile`|Disables writing a logfile for cloudflared - it will still log to the journal|`false`|

### SSH Client config

From where you access your nodes via ssh which is proxied by cloudflared, you need to follow [ssh-guide-client]. You have to add the following

```yml
Host xxx.mycompany.com
  ProxyCommand /usr/bin/cloudflared access ssh --hostname %h
```

You can achieve this configuration if you enable `ssh_client_config`. In addition you also need to specify `ssh_client_config_group`. So let's assume your inventory looks as follows:

```yml
all:
  children:
    servers:
      hosts:
        host001:
        host002:
```

If you specify `ssh_client_config_group` = `servers` you would get an entry for `host001` and `host002`.

## Dependencies

none

## Example Playbook

The following example installs an ssh-tunnel for each `server`

```yaml
- hosts: servers
  vars:
    systemd_user: root
    systemd_group: root
    cert_location: /home/papanito/cert.pem
    services:
      ssh:
        hostname: "{{ inventory_hostname }}.mycompany.com"
        url: ssh://localhost:22
  roles:
    - papanito.cloudflared
```

The following example simply downloads `cloudflared` on your local machine and configures the ssh-config file:

```yaml
- hosts: localhost
  remote_user: papanito #your local user who has admin
  vars:
    install_only: True
    ssh_client_config: True
    ssh_client_config_group: servers
    external_domain: mycompany.com
  roles:
    - papanito.cloudflared
```

## Test

```bash
ansible-playbook tests/test.yml -i tests/inventory
```

## License

This is Free Software, released under the terms of the Apache v2 license.

## Author Information

Written by [Papanito](https://wyssmann.com) - [Gitlab](https://gitlab.com/papanito) / [Github](https://github.com/papanito)

[argo-tunnel]: https://developers.cloudflare.com/argo-tunnel
[downloads]: https://developers.cloudflare.com/argo-tunnel/downloads
[ssh-guide]: https://developers.cloudflare.com/access/ssh/ssh-guide/
[ssh-guide-client]: https://developers.cloudflare.com/access/ssh/ssh-guide/#2-authenticate-the-cloudflare-daemon
[config]: https://developers.cloudflare.com/argo-tunnel/reference/config/
[cli-args]: https://developers.cloudflare.com/argo-tunnel/reference/arguments/
[authenticate-the-cloudflare-daemon]: https://developers.cloudflare.com/access/ssh/ssh-guide/#2-authenticate-the-cloudflare-daemon
[systemd-unit-template]: https://fedoramagazine.org/systemd-template-unit-files/ssh-guide-client