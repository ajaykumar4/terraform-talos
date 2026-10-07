# Terraform/OpenTofu Talos Project

A complete Terraform/OpenTofu project for provisioning a PXE (Preboot Execution Environment) server to install **Talos Linux** and **Debian Linux** on bare metal or VM infrastructure.

## Features

- **Talos Linux**: Kubernetes-optimized Linux distribution
- **Debian Linux**: General-purpose Linux distribution
- **PXE Boot**: Network-based OS installation
- **dnsmasq**: DHCP and TFTP server for PXE
- **iPXE**: Advanced boot protocol for flexible boot options
- **Multi-Environment**: Support for different environments (home-lab, production, etc.)

## Project Structure

```
├── README.md                    # This file
├── environments/
│   └── home-lab/                # Home lab environment
│       ├── main.tf              # Environment-specific configuration
│       ├── variables.tf         # Variable definitions
│       ├── terraform.tfvars     # Variable values
│       └── outputs.tf           # Output values
└── modules/
    └── pxe_server/              # PXE server module
        ├── main.tf              # Main resource definitions
        ├── variables.tf         # Module variables
        ├── outputs.tf           # Module outputs
        ├── scripts.tf           # Script generation
        ├── assets.tf            # Asset management
        └── templates/
            ├── boot.ipxe.tftpl  # iPXE boot configuration template
            └── dnsmasq.conf.tftpl # dnsmasq configuration template
```

## Prerequisites

- **macOS**: System must be running on macOS
- **Terraform or OpenTofu**: Version 1.5+
- **dnsmasq**: Installed and configured
- **Network Setup**: 
  - Local network access to PXE server
  - DHCP range configured in dnsmasq
  - TFTP server accessible from target machines

## Quick Start

### 1. Initialize Terraform/OpenTofu

```bash
cd environments/home-lab
terraform init
# or
opentofu init
```

### 2. Configure Variables

Edit `terraform.tfvars`:

```hcl
# Home Lab Configuration
pxe_server_ip        = "192.168.1.100"
pxe_server_interface = "en0"
dhcp_range_start     = "192.168.1.200"
dhcp_range_end       = "192.168.1.250"
talos_version        = "v1.8.0"
debian_version       = "bookworm"
```

### 3. Plan and Apply

```bash
terraform plan
terraform apply
# or use opentofu
opentofu plan
opentofu apply
```

## Configuration Options

### Talos Linux

- **Version**: Default `v1.8.0` (latest stable)
- **Architecture**: Support for amd64 and arm64
- **Boot Options**:
  - Custom kernel parameters
  - Cluster configuration via machine config
  - Network configuration

### Debian Linux

- **Version**: Default `bookworm` (latest stable)
- **Architecture**: Support for amd64 and arm64
- **Boot Options**:
  - Preseed configuration for unattended installation
  - Network configuration
  - Partitioning scheme

## Usage

### Boot a Machine with Talos Linux

1. Connect target machine to network
2. Set boot order to PXE (network boot)
3. Machine will boot and download Talos Linux kernel/initrd
4. Installation proceeds based on machine configuration

### Boot a Machine with Debian Linux

1. Connect target machine to network
2. Set boot order to PXE (network boot)
3. Machine will boot and download Debian Linux kernel/initrd
4. Installation proceeds based on preseed configuration

## Network Configuration

### DHCP Setup

The project uses dnsmasq to provide DHCP and TFTP services:

```
DHCP Range: 192.168.1.200 - 192.168.1.250
DHCP Lease Time: 1 hour
PXE Server: 192.168.1.100
TFTP Boot File: boot.ipxe
```

### Firewall Configuration (macOS)

Allow dnsmasq through firewall:

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw \
  --setglobalstate off
# or configure specific rules
```

## Management

### Start PXE Server

```bash
terraform apply
```

### Stop PXE Server

```bash
terraform destroy
```

### Check PXE Server Status

```bash
terraform show
```

### Update OS Versions

Edit `terraform.tfvars`:

```hcl
talos_version = "v1.9.0"  # Update Talos
debian_version = "trixie" # Update Debian
terraform apply
```

## Troubleshooting

### Machines Not Booting from PXE

1. Verify network connectivity
2. Check DHCP server is running
3. Confirm TFTP server is accessible
4. Verify boot.ipxe is present in TFTP root

### dnsmasq Issues

```bash
# Check dnsmasq status
ps aux | grep dnsmasq

# View logs
tail -f /var/log/system.log | grep dnsmasq

# Restart dnsmasq
sudo launchctl restart homebrew.mxcl.dnsmasq
```

### Network Boot Not Starting

1. Verify PXE server IP configuration
2. Check interface configuration matches variables
3. Confirm DHCP server is responding to requests

## Security Considerations

- **Network Isolation**: Use separate network segment for PXE
- **Boot Authorization**: Implement boot script validation
- **Access Control**: Restrict TFTP access to known subnets
- **Credentials**: Use encrypted machine configurations for Talos

## References

- [Talos Linux](https://www.talos.dev/)
- [Debian Linux](https://www.debian.org/)
- [iPXE](https://ipxe.org/)
- [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html)
- [Terraform](https://www.terraform.io/)
- [OpenTofu](https://opentofu.org/)

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Talos and Debian documentation
3. Check network configuration

## License

This project is provided as-is for educational and home lab use.