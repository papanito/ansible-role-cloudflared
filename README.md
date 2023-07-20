# Ansible role "papanito.cloudflared"

[![Ansible Role](https://img.shields.io/ansible/role/49833)](https://galaxy.ansible.com/papanito/cloudflared) [![Ansible Quality Score](https://img.shields.io/ansible/quality/49833)](https://galaxy.ansible.com/papanito/cloudflared) [![Ansible Role](https://img.shields.io/ansible/role/d/49833)](https://galaxy.ansible.com/papanito/cloudflared) [![GitHub issues](https://img.shields.io/github/issues/papanito/ansible-role-cloudflared)](https://github.com/papanito/ansible-role-cloudflared/issues) [![GitHub pull requests](https://img.shields.io/github/issues-pr/papanito/ansible-role-cloudflared)](https://github.com/papanito/ansible-role-cloudflared/pulls)

This ansible role does download and install `cloudflared` on the host and optionally installs the [argo-tunnel] as a service.

> **Breaking changes with 3.0.0**
>
> This is a breaking change to reflect [the new beahviour](https://blog.cloudflare.com/many-services-one-cloudflared/) of [named tunnels](https://blog.cloudflare.com/argo-tunnels-that-live-forever/)
>
> The role should take care of cleanup if you used the role before v.3.0.0. However **you have to update the configuration (variables)** in your ansible project. I renamed the variables - usually prefixed with `cf_` to make them unique to the role. If they are not unique it may happen that variables using the same name in different roles can have undesired side-effects.

## Cloudflared and connecting apps to tunnels

According to [1], in order to create and manage Tunnels, you'll first need to:

1. [Download and install cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation) on your machine
2. [Authenticate](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/setup) cloudflared

Once cloudflared has been installed and authenticated, the process to get your first Tunnel up and running includes 3 high-level steps:

3. [Create a Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/create-tunnel)
4. [Route traffic to your Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/routing-to-tunnel)
5. [Run your Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/run-tunnel)

Steps 4-5 are executed once per Tunnel, normally by an administrator, and Step 6 is executed whenever the Tunnel is to be started, normally by the owner of the Tunnel (whom may be different from the administrator).

## What does the role do?

The role has actually two purposes

- [Server side daemon installation](#server-side-daemon-installation)
- [SSH Client config](#ssh-client-config)

### Server side daemon installation

The role only takes care of **setting up the service on the nodes**, i.e. steps 1, 2, 4 and 5 from above, cause

> Creating tunnels and enable routing is a task which should be done by an administrator and not the role <sup>[1]</sup>

You can configure one to multiple [named tunnels] as well as [single service] - even so, with [named tunnels] you usually only need one daemon. The role actually performs these steps:

1. Download and install binary according to [downloads]
2. Install/configure the daemon - see [Authenticate the daemon](#authenticate-the-daemon)
3. For [named tunnels] a [credentials file] is created under `{{ cf_credentials_dir }}/{{ tunnel_id }}.json` similar to this

    ```json
    {"AccountTag":"{{ account_tag }}","TunnelSecret":"{{ tunnel_secret }}","TunnelID":"{{ tunnel_id }}","TunnelName":"{{ cf_tunnels.key }}"}
    ```

4. For each key in `cf_tunnels` create a tunnel config in `/etc/cloudflare`

    The file is named `{{ tunnel }}.yml` and will contain the minimal configuration is as follows

    **named tunnels**

    ```yaml
    tunnel: {{ cf_tunnels.key }}
    credentials-file: {{ cf_credentials_dir }}/{{ tunnel_id }}.json
    ingress:
      {{ item.value.ingress }}
    ```

    **single service**

    ```yaml
    hostname: {{ hostname }}
    url: {{ url }}
    ```

    Additional parameters are configured using [Tunnel configuration params](#tunnel-configuration-params)

5. Depending on your init system - controlled by `cf_init_system` - the role does the following

   - **Systemd**

     Create a [systemd-unit-template] `cloudflared@{{ tunnel }}.service` and start an instance for each service in the list of `cf_tunnels`

     ```bash
     cloudflared tunnel --config {{ tunnel }}.yml
     ```

   - **Init-V Systems**

     1. Install [cloudflared service](https://github.com/papanito/ansible-role-cloudflared/blob/master/templates/cloudflared.initv.j2) to `/etc/init.d/{{ systemd_filename }}-{{ tunnel_name }}`
     2. Link Stop-Script to `/etc/init.d/{{ systemd_filename }}-{{ tunnel_name }}`
     3. Link Start-Script to `/etc/init.d/{{ systemd_filename }}-{{ tunnel_name }}`

6. If you use [named tunnels] the role would also create a [dns route].

### SSH Client config

From where you access your nodes via ssh which is proxied by cloudflared, you need to follow [ssh-guide-client]. You have to add the following

```yml
Host xxx.mycompany.com
  ProxyCommand /usr/bin/cloudflared access ssh --hostname %h
```

You can achieve this configuration if you enable `cf_ssh_client_config`. In addition you also need to specify `cf_ssh_client_config_group`. So let's assume your inventory looks as follows:

```yml
all:
  children:
    servers:
      hosts:
        host001:
        host002:
```

If you specify `cf_ssh_client_config_group: servers` you would get an entry for `host001` and `host002`.

## Requirements

none

## Role Variables

### Install and uninstall parameters

The following parameters control the installation and/or un-installation

|Parameter|Description|Default Value|
|---------|-----------|-------------|
|`cf_download_baseurl`|Base url for `cloudflare` binaries|https://github.com/cloudflare/cloudflared/releases/latest/download/|
|`cf_install_only`|Set to `true` if you only want to install the binary without any configuration or login|`false`|
|`cf_ssh_client_config`|Set to `true` if you want to configure the proxy configuration for your [ssh-guide-client], see [SSH Client config](#ssh-client-config)|`false`|
|`cf_ssh_client_config_group`|Name of the inventory group for which the ssh proxy config shall be created, see [SSH Client config](#ssh-client-config)|``|
|`cf_force_install`|Set to `true` if you want to re-install `cloudflared`. By default the assumption is that `cloudflared` is running as a service and automatically auto-updates.|`false`|
|`cf_remove_unused_tunnel`|Removes unused cf_tunnels, means cf_tunnels running but not listed in `cf_tunnels`.|`false`|
|`cf_remove_setup_certificate`|Remove cert.pem after installing the service|`false`|
|`cf_credential_file_base`|Folder where to place credential files|`/root/.cloudflared/`|
|`cf_config_dir`|Folder where to place cloudflare configuration files|`/etc/cloudflared`|
|`cf_os_package_enable`|Use OS packaging system and Cloudflare package repository (currently just Debian/Ubuntu)|`false`|
|`cf_repository_key_url`|If cf_os_package_enable is true, url of the GPG key for the apt repository | `https://pkg.cloudflare.com/pubkey.gpg` |
|`cf_repository_key_install_path`|If cf_os_package_enable is true, path where to instal the GPG key for the apt repository | `/usr/share/keyrings/cloudflare-main.gpg` |
|`cf_repository`|If cf_os_package_enable is true, url for the Cloudflare apt repository | `deb [signed-by={{ cf_repository_key_install_path }}] https://pkg.cloudflare.com/cloudflared {{ ansible_distribution_release }} main` |
|`cf_binary_name`|Name of the cloudflare daemon binary - change only if you know what you are doing|`cloudflared`|

### Cloudflared service parameters

These are parameters required to create the system service

|Parameter|Description|Default Value|
|---------|-----------|-------------|
|`cf_init_system`|Define which init service to use. Possible values are `systemd` and `initv`|`systemd`|
|`cf_systemd_user`|User for systemd service in case `cf_init_system: systemd`|`root`|
|`cf_systemd_group`|Group for systemd service in case `cf_init_system: systemd`|`root`|
|`cf_cert_location`|Location of the certificate to be copied - see [Authenticate the daemon](#authenticate-the-daemon)|-|
|`cf_cert_content`|Content of the certificate to be copied - see [Authenticate the daemon](#authenticate-the-daemon)|-|
|`cf_tunnels`|[Mandatory] List of tunnel-services, each one defining [Cloudflare parameters](#cloudflare-parameters)|-|
|`cf_sysctl_buffer_size_increase`|Increase UDP receive buffer size allowed by the OS (non BSD) - [more details](https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size)|`false`|

It's recommended to use [named tunnels] for `cf_tunnels` which require [Cloudflare named tunnel parameters](#cloudflare-named-tunnel-parameters) but you can also use [Cloudflare legacy tunnel parameters](#cloudflare-legacy§-tunnel-parameters)

### Cloudflare named tunnel parameters

```yaml
  ...
    cf_tunnels:
      test:
        routes:
          dns:
            - "{{ inventory_hostname }}"
          cidr:
            - "192.168.42.0/24"
          lb:
            - hostname: website.mycompany.com
              poolname: bzh-west1.website.mycompany.com
        account_tag:  !vault....
        tunnel_secret: !vault....
        tunnel_id: !vault....
        ingress:
          - hostname: website.mycompany.com
            service: http://localhost:1313
          - hostname: hello.mycompany.com
            service: hello_world
          - hostname: ssh.mycompany.com
            service: ssh://localhost:22
          - service: http_status:404
```

The `key` of the tunnel shall match the of `tunnel_id`.

|Parameter|Description|Default Value|
|---------|-----------|-------------|
|`account_tag`|[Mandatory] Account tag from the [credentials file] generated when creating a tunnel|-|
|`tunnel_secret`|[Mandatory] Tunnel secret from the [credentials file] generated when creating a tunnel|-|
|`tunnel_id`|[Mandatory] Tunnel id from the [credentials file] generated when creating a tunnel|-|
|`ingress`|[Mandatory] [ingress rules] for the tunnel|-|
|`routes`|List of routes which shall be created. It allows a list for `dns`-routes at the moment (see example above)|`-`|

#### Routes

##### DNS

`dns` routes expect a list of `CNAME`'s to be created as [described here](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/routing-to-tunnel/dns). If the `CNAME` already exists the task will be skipped but no error thrown. Also only add `CNAME` not a FQDN as the `FQDN` is determined by `cloudlfared`.

##### Private Network

`private network` routes expect a list of `CIDR`'s to be created as [described here](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/connect-private-networks/). The playbook loop on the list to execute `cloudflared tunnel route ip add {{ cf_cidr_entry }} {{ cf_tunnel.key }}`. If the `CIDR` already exists, an error will thrown but ignored.

##### Load Balancer

`lb` routes expect a list of existing cloudflared load balancer (plus its pool) to route tunnel on as [described here](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/routing-to-tunnel/lb/). The playbook loop on the list to execute `cloudflared tunnel route lb {{ cf_tunnel.key }} {{ cf_lb_entry.host_name }} {{ cf_lb_entry.pool_name }}`. If the tunnel is already bind into the pool, an ignored error will throw.

### Cloudflare single service parameters

As with previous versions of this roles you can use the [single service configuration style][single service]

> If you need to proxy traffic to only one local service, you can do so using the config file. As an alternative, you can set up single-service configuration

```yaml
cf_tunnels:
  ssh:
    hostname: xxx
    url: ssh.mycompany.com
```

|Parameter|Description|Default Value|
|---------|-----------|-------------|
|`hostname`|[Mandatory]Name or unique|-|
|`url`|[Mandatory] url to which to connect to [config] e.g. `ssh://localhost:22` or `https://localhost:443`|-|

#### Tunnel configuration params

These are used to configure the parameters per cloudflared service. You still can configure [Per-rule configuration for named tunnels](https://blog.cloudflare.com/many-services-one-cloudflared/) as part of the `ingress` under `cf_tunnels`.

|Parameter|Description|Default Value|
|---------|-----------|-------------|
|`autoupdate_freq`|Autoupdate frequency - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#autoupdate-freq)|`24h`|
|`edge_ip_version`|Specifies the IP address version (IPv4 or IPv6) used to esablish a connection between cloudflared and the Cloudflare global network. Available values are `auto`, `4`, and `6`|`auto`|
|`edge_bind_address`|Specifies the outgoing IP address used to establish a connection between cloudflared and the Cloudflare global network|-|
|`grace_period`|When cloudflared receives SIGINT/SIGTERM it will stop accepting new requests, wait for in-progress requests to terminate, then shut down. Waiting for in-progress requests will timeout after this grace period, or when a second SIGTERM/SIGINT is received|`30s`|
|`metrics`|Address to query for usage metrics - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#metrics)|`localhost:`|
|`metrics_update_freq`|Frequency to update tunnel metrics - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#metrics-update-freq)|`5s`|
|`no_autoupdate`|Disable periodic check for updates, restarting the server with the new version - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#lb-pool)|`false`|
|`no_chunked_encoding`|Disables chunked transfer encoding; useful if you are running a WSGI server - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#no-chunked-encoding)|`false`|
|`no_tls_verify`|Disables TLS verification of the certificate presented by your origin. Will allow any certificate from the origin to be accepted - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#no-tls-verify)|-|
|`origin_server_name`|Hostname that `cloudflared` should expect from your origin server certificate - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#origin-server-name)|-|
|`origin_ca_pool`|Path to the CA for the certificate of your origin. This option should be used only if your certificate is not signed by Cloudflare - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#origin-ca-pool)|-|
|`protocol`|Specifies the protocol to use for the tunnel - see [docu](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/arguments#protocol) |`auto`|
|`logfile`|Enables writing a logfile for cloudflared - it will still log to the journal|`true`|
|`loglevel`|Specifies the verbosity of logging. The default "info" is not noisy, but you may wish to run with "warn" in production - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#loglevel)|`info`|
|`region`|Allows you to choose the regions to which connections are established. Omit or leave empty to connect to the global region. Set `--region=us` to route all connections through us region 1 and us region 2|-|
|`retries`|Maximum number of retries for connection/protocol errors. Retries use exponential backoff (retrying at 1, 2, 4, 8, 16 seconds by default) so increasing this value significantly is not recommended - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#retries)|`5`|
|`tag`|Custom tags used to identify this tunnel, in format `KEY=VALUE` - see [docu](https://developers.cloudflare.com/argo-tunnel/reference/arguments/#tag)|-|
|`token`|Associates the cloudflared instance with a specific tunnel. The tunnel’s token is shown in the dashboard when you first [create the tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/install-and-setup/tunnel-guide/remote/). You can also retrieve the token using the [API](https://developers.cloudflare.com/api/operations/cloudflare-tunnel-get-a-cloudflare-tunnel-token)|-|
|`transport_loglevel`|Specifies the verbosity of logs for the transport between cloudflared and the Cloudflare edge. Available levels are: `trace`, `debug`, `info`, `warn`, `error`, `fatal`, `panic`. Any value below warn produces substantial output and should only be used to debug low-level performance issues and protocol quirks - see [docu](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/local/local-management/arguments/#transport-loglevel)|`info`|
|`warp_routing`|Allow users to connect to internal services using WARP, details see [warp-routing]|`false`|

## Dependencies

none

## Example Playbooks

The following example installs an single service for an ssh-tunnel for each `server`

```yaml
- hosts: servers
  vars:
    cf_systemd_user: root
    cf_systemd_group: root
    cf_cert_location: /home/papanito/cert.pem
    services:
      ssh:
        hostname: "{{ inventory_hostname }}.mycompany.com"
        url: ssh://localhost:22
  roles:
    - papanito.cloudflared
```

The following example installs an [named tunnel] `servers` with an ingress to `{{ inventory_hostname }}.mycompany.com` for ssh a [hello world] if you access `hello-{{ inventory_hostname }}.mycompany.com` via the browser

```yaml
- hosts: servers
  remote_user: ansible
  become: true
  vars:
    cf_cert_location: /home/papanito/.cloudflared/cert.mycompany.com.pem
    cf_tunnels:
      test:
        account_tag: !vault...
        tunnel_secret: !vault...
        tunnel_id: !vault...
        routes:
          dns:
          - "{{ inventory_hostname }}"
          - "hello-{{ inventory_hostname }}"
        ingress:
        - hostname: "hello-{{ inventory_hostname }}.mycompany.com"
          service: hello_world
        - hostname: "{{ inventory_hostname }}.mycompany.com"
          service: ssh://localhost:22
        - service: http_status:404
  roles:
    - papanito.cloudflared
```

The following example simply downloads `cloudflared` on your local machine and configures the ssh-config file:

```yaml
- hosts: localhost
  remote_user: papanito #your local user who has admin
  vars:
    cf_install_only: true
    cf_ssh_client_config: true
    cf_ssh_client_config_group: servers
  roles:
    - papanito.cloudflared
```

## Test

```bash
ansible-playbook tests/test.yml -i tests/inventory
```

## Additional Info

### Authenticate the daemon

According to [authenticate-the-cloudflare-daemon] when authenticate the daemon, there is a browser window opened or - if this is not possible - then the link has to be put manually. During this time the daemon waits. I could not come up with a solution how to automate this behavior so I came up with the following implementation.

- if nothing is specified, then ansible calls the `cloudflared login` and will continue when the authentication is done - this makes sens if you use the role to install the daemon locally on your machine and where you have a browser window
- if `cf_cert_location` the certificate is actually copied from the `cf_cert_location`, or if `cf_cert_content` is defined then the certificate is created directly from the value stored in it. So you could login once to cloudflare from your master node (where you run ansible) or from a remote location.

   You can encrypt the `cert.pem` with ansible vault and store it somewhere save.

References:

- [downloads] - cloudflared download instructions
- [ssh-guide] - ssh connections with cloudflared
- [cli-args] - command-line arguments
- [config] - The configuration file format uses YAML syntax

## License

This is Free Software, released under the terms of the Apache v2 license.

## Author Information

Written by [Papanito](https://wyssmann.com) - [Gitlab](https://gitlab.com/papanito) / [Github](https://github.com/papanito)


[dns route]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/routing-to-tunnel/dns
[hello world]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/ingress#supported-protocols
[credentials file]: https://developers.cloudflare.com/cloudflare-one/tutorials/multi-origin#configure-cloudflared
[named tunnels]: https://blog.cloudflare.com/argo-tunnels-that-live-forever/
[argo-tunnel]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps
[ingress rules]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/ingress
[downloads]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation
[ssh-guide]: https://developers.cloudflare.com/cloudflare-one/tutorials/ssh
[ssh-guide-client]: https://developers.cloudflare.com/cloudflare-one/tutorials/ssh#connect-from-a-client-machine
[config]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/config
[cli-args]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/config
[authenticate-the-cloudflare-daemon]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/setup
[systemd-unit-template]: https://fedoramagazine.org/systemd-template-unit-files/ssh-guide-client
[warp-routing]: https://developers.cloudflare.com/cloudflare-one/tutorials/warp-to-tunnel#configure-and-run-the-tunnel
[1]: https://developers.cloudflare.com/cloudflare-one/tutorials/ssh/
[single service]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/ingress#single-service-configuration)
