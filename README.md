# equinix_metal_terraform_volterra_ce_cluster
Volterra CE Cluster Deployment on Equinix Bare Metal IaaS

![Workspace Diagram](./assets/volterra-site-diagram.jpg)

This terraform workspace creates an Volterra site on Equinix Metal servers.

Equinix Metal services provide the necessary services to bootstrap various linux distributions on dedicated servers running in various Equinix facilities around the world. By default, the bootstrapped linux system presents a single LACP bonded network interface with a public routable IP and an private IP which is routable within the specific Equinix facility. The underlying server model, CPU and RAM, are designated by selecting an Equinix *plan*.

Volterra is a distribued application delivery system providing Internet SaaS based deployment of workloads to multi-cloud and edge deployed infrastructures through a dedicated global application delivery network (ADN).

## Volterra Customer Edge Deployment

Volterra deploys the customer edge of the ADN as either a virtual machine or a dedicated bootable ISO. Volterra also offers hardware bases solutions to ease direct deployments into various high-performance or carrier infrastructures. Though Equinix Metal supports iPXE chained scripting, remote loading of a system bootstrap requires netboot support, which has not been tested for Volterra customer edge distribution. In addition, the various hardware platforms provided by Equinix metal are not certified Volterra hardware platforms. This workspace utilizes the Volterra CE VM for linux KVM hypervisor.

This terraform workspace boots from the standard Equinix Metal CENTOS 7 distribution and builds out the necessary linux networking and KVM support to boot multiple Volterra CE KVM generic hardware VMs. The installation of various linux kernel modules, system settings, and the various KVM support tools is done via cloudinit utilizing the Equinix metadata service (packet metadata service).

This workspace allows for Equinix Metal *c3.small.x86* and *c3.medium.x86* plan deployments only. The workspace deploys between 3 and 9 Equinix Metal OnDemand servers which will register between 6 to 27 Volterra CE VMs with the Volterra SaaS. The only sizing control required is the selection of the Equinix Metal plan and the server count via terraform variables.

### Meeting Volterra Customer Edge Networking Requirements

Deploying a Volterra CE site cluster requires:

1. An external site local interface which can route to the Internet for Volterra SaaS registration and service provisioning.
2. That all Volterra CE VMs external site local interface be in the same IP subnet and be routable to each other.
3. At least 3 Volterra CE VMs be launched to provide high-availablity at the customer edge.

While Equinix Metal provides each server instance with an Internet routable management interface, there is no way to guarentee that the default public management interfaces for multiple devices are all provisioned from the same public subnet.

Equinix provides reservable public IP CIDR blocks which can be attached to an Equinix Metal instance and static routed to its public management interface. The attachment of the reserved IP addresses to a Equinix Metal instance (the creation of the static route within the Equinix facility) is referred to as an EIP (elastic IP).

In order to support the requirement for all Volterra CE VMs to be on the same logical IP subnet, while maintain the network redudancy provied by the network bonded Equinix Metal deployment, this workspace deploys the Equinix Metal server instances in a hybrid network type.

In order to support the deployment of Volterra CE VMs across redudant Equinix Metal servers for high-availability, unmanaged VLANs will be attached to each Equinix Metal server with full L3 (IPv4) management ocurring on the booted CENTOS system. Volterra CE VMs support a site local external and a site local internal network interface. This workspace will create two Equinix Metal VLANs, one external and the other internal.

![Equinix Metal Deployment](./assets/equinix-metal-deployment.jpg)

Each of the Equinix VLANs will have private (RFC1918) IPv4 address spaces configured via terraform variables. The external interface VLAN is managed by distributed IPAM services running on each Equinux Metal instance. The internal interface VLAN is managed by Volterra Network Interface configuration with the CEs optionally supplying DHCPv4 addresses by setting the `volterra_internal_dhcp_hosts` (the number of DHCP leases to support) to a value greater than one (1).

![Equinix Metal IPv4 Subnets Deployment](./assets/equinix-metal-deployment-subnets.jpg)

The external IPv4 address space used for Volterra CE VMs will have 1:1 NAT applied for Internet access via Equinix Metal EIP attachement. An Equinix Metal reserved public network CIDR will be provisioned and attached to the appropriate Equinix Metal server as part of the terraform orchestration. Providing 1:1 EIP attachment to each CE VM provides the greatest connection diversity for the Equinix Metal bonded LACP hash and allows for Volterra TLS or IPSEC connectivity back to the Volterra SaaS.

![Equinix Metal IPv4 EIP Deployment](./assets/equinix-metal-deployment-eips.jpg)

## Required Terraform Providers

This workspace uses both the Equinix Metal and Volterra terraform providers. Details on their use can be found here:

[Equinix Metal Terraform Provider](https://registry.terraform.io/providers/equinix/metal/latest/docs)

[Volterra Terraform Provider](https://registry.terraform.io/providers/volterraedge/volterra/latest/docs)

**This workspace also uses the Terraform `null_resource` and python3 scripting to poll and approve Volterra node registrations. This workspace requires a valid python3 runtime and core modules installed. The easiest way to assure this workspace deploys is to use a stock Ubuntu, CentOS, RHEL, or Fedora instance with python3 and terraform installed.**
### Variables values
The following terraform variables are supported:

| Key | Definition | Required/Optional | Default Value |
| --- | ---------- | ----------------- | ------------- |
| `metal_auth_token` | The Equinix Metal API Token | required |  |
| `metal_project_id` | The Equinix Metal Project ID | required | |
| `metal_facility` | The Equinix Metal facility code | required | da11 |
| `metal_plan` | The Equinx Metal plan, either c3.small.x86 or c3.medium.x86 | required | c3.small.x86 |
| `metal_server_count` | The Equinix Metal server count, 1, or between 3..8  | required | 3 |
| `metal_ce_count` | The number of Volterra CE instances per metal server, between 1..3  | required | 3 |
| `metal_ssh_key_name` | The name of the project SSH key to inject for metal server access | required | |
| `volterra_tenant` | The Volterra SaaS tenant name | required | |
| `volterra_site_token` | The Volterra site token to register CE instances | required | |
| `volterra_site_name` | The Volterra site name to use for registration | required |  |
| `volterra_fleet_label` | The Volterra fleet label for the CE instance | required |  |
| `volterra_voltstack` | Add the Voltstack components to the Voltmesh in the CE instances | optional | false |
| `volterra_admin_password` | The admin user password for the CE instances | optional | randomized string |
| `volterra_ssl_tunnels` | Allow SSL tunnels to connect the Volterra CE to the RE | optional | false |
| `volterra_ipsec_tunnels` | Allow IPSEC tunnels to connect the Volterra CE to the RE | optional | true |
| `volterra_download_url` | The URL for the Volterra CE qcow2 disk image | optional | https://downloads.volterra.io/releases/images/2021-03-01/centos-7.2009.5-202103011045.qcow2 |
| `volterra_external_cidr` | The external VLAN CIDR block to use | required | 192.168.122.0/24 |
| `volterra_internal_cidr` | The internal VLAN CIDR block to use | required | 192.168.180.0/24 |
| `volterra_internal_dhcp_hosts` | The number of DHCPv4 host to support on the internal VLAN | 100 |
| `volterra_internal_networks` | List of IPv4 subnets to add as site local inside reachable subnets | [] |
| `volterra_internal_networks_gateway` | The next hop gateway address to reach the internal reachable subnet hosts | |
