# ansible-role-cloudflared <!-- omit in toc -->

- [Authenticate the daemon](#authenticate-the-daemon)
- [Requirements](#requirements)
- [Role Variables](#role-variables)
  - [General parameters](#general-parameters)
  - [Cloudflare parameters](#cloudflare-parameters)
- [Dependencies](#dependencies)
- [Example Playbook](#example-playbook)
- [License](#license)
- [Author Information](#author-information)

This ansible role does download and install `cloudflared` on the host and optionally installs the [argo-tunnel] as a service. 

The role is made in a way that you can install multiple services in parallel - simply run the role several times with different parameters `service_name`, `hostname` and `url`.

The role performs the following steps:

1. Download and install binary according to [downloads]
2. Install/configure the daemon - see [Authenticate the daemon](#authenticate-the-daemon)
3. Create a config file per `service_name` in `/etc/cloudflare`

    The file is named `cloudflared_{{ service_name }}.yml` and will contain the minimal configuration is as follows

    ```yaml
    hostname: {{ hostname }}
    url: {{ url }}
    logfile: /var/log/cloudflared_{{ service_name }}.log
    ```

    Additional parameters are configured via [Cloudflare parameters](#cloudflare-parameters)

4. Create a systemd `service`-file and starts it

    ```bash
    cloudflared tunnel --config cloudflared_{{ service_name }}.yml
    ```

## Authenticate the daemon

According to [authenticate-the-cloudflare-daemon] when authenticate the daemon, there is a browser window opened or - if this is not possible - then the link has to be put manually. During this time the daemon waits. I could not come up with a solution how to automate this behavior so I came up with the following implementation.

- if nothing is specified, then ansible calls the `cloudflared login` and will continue when the authentication is done - this makes sens if you use the role to install the daemon locally on your machine and where you have a browser window
- if `cert_location` the certificate is actually copied from the `cert_location`. So you could login once to cloudflare from your master node (where you run ansible) or from a remote location.

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
|`service_name`|[Mandatory] Name of the service - used to create config file and systemd file|-|
|`systemd_user`|User for systemd service|`backup`|
|`systemd_group`|Group for systemd service|`backup`|
|`download_baseurl`|Base url for `cloudflare` binaries|https://bin.equinox.io/c/VdrWdbjqyF/|
|`cert_location`|Location of the certificate to be copied - see [Authenticate the daemon](#authenticate-the-daemon)|-|
|`install_only`|Set to `true` if you only want to install the binary without any configuration or login|`false`|

### Cloudflare parameters

Parameters available for configuring `cloudflared` according to [cli-args]

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


## Dependencies

none

## Example Playbook

The following example installs an ssh-tunnel for each `server`

```yaml
- hosts: server
  vars:
    hostname: "{{ inventory_hostname }}.mycompany.com"
    service_name: ssh
    url: ssh://localhost:22
    systemd_user: root
    systemd_group: root
    cert_location: /home/papanito/cert.pem
  roles:
    - papanito.cloudflared
```

The following example simply downloads `cloudflared` on your local machine

```yaml
- hosts: localhost
  remote_user: papanito #your local user who has admin
  vars:
    install_only: True
  roles:
    - papanito.cloudflared
```

## License

This is Free Software, released under the terms of the Apache v2 license.

## Author Information

Written by [Papanito](https://wyssmann.com) - [Gitlab](https://gitlab.com/papanito) / [Github](https://github.com/papanito)

[argo-tunnel]: https://developers.cloudflare.com/argo-tunnel
[downloads]: https://developers.cloudflare.com/argo-tunnel/downloads
[ssh-guide]: https://developers.cloudflare.com/access/ssh/ssh-guide/
[config]: https://developers.cloudflare.com/argo-tunnel/reference/config/
[cli-args]: https://developers.cloudflare.com/argo-tunnel/reference/arguments/
[authenticate-the-cloudflare-daemon]: https://developers.cloudflare.com/access/ssh/ssh-guide/#2-authenticate-the-cloudflare-daemon