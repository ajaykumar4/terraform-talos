# PXE Server Setup Guide for macOS

This guide walks you through setting up a complete PXE boot environment on your macBook for installing Talos Linux and Debian Linux via network boot.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Running](#running)
5. [Troubleshooting](#troubleshooting)
6. [Advanced Configuration](#advanced-configuration)

## Prerequisites

### System Requirements

- **macOS 11.0 or later**
- **Apple Silicon or Intel** (both supported)
- **Network connection** to your local network
- **Sudo access** (for system configuration)

### Software Requirements

```bash
# Check Terraform/OpenTofu version
terraform version
# or
opentofu version

# Both should be v1.5 or later
```

## Installation

### Step 1: Clone or Prepare the Project

```bash
cd /Users/ajay.kumar/Projects/terraform-talos
```

### Step 2: Install Terraform or OpenTofu

If you don't have Terraform or OpenTofu installed:

```bash
# Using Homebrew for Terraform
brew install terraform

# Or using Homebrew for OpenTofu
brew install opentofu
```

### Step 3: Install dnsmasq

```bash
# Install dnsmasq via Homebrew
brew install dnsmasq

# Start the service
sudo brew services start dnsmasq
```

### Step 4: Configure Network Interface

Find your network interface name:

```bash
# List all network interfaces
ifconfig

# Look for your active network interface (usually en0, en1, en10, etc.)
# Note the interface name for configuration
```

## Configuration

### Step 1: Update terraform.tfvars

Edit `environments/home-lab/terraform.tfvars` and update the following:

```hcl
# Your macbook's IP on the network
pxe_server_ip = "192.168.1.100"

# Your network interface (from ifconfig)
pxe_server_interface = "en0"

# DHCP range for PXE clients (adjust to your subnet)
dhcp_range_start = "192.168.1.200"
dhcp_range_end   = "192.168.1.250"

# Network gateway
gateway = "192.168.1.1"

# DNS servers (can use your ISP's or public DNS)
dns_servers = ["8.8.8.8", "8.8.4.4"]

# OS versions
talos_version  = "v1.8.0"
debian_version = "bookworm"

# Your macOS username
macos_user = "ajay.kumar"
```

### Step 2: Create PXE Root Directory

```bash
# Create the TFTP root directory
sudo mkdir -p /var/lib/tftp
sudo chown $(whoami):staff /var/lib/tftp
sudo chmod 755 /var/lib/tftp
```

### Step 3: Verify Configuration

```bash
cd environments/home-lab

# Check for configuration errors
terraform validate
# or
opentofu validate
```

## Running

### Step 1: Initialize Terraform/OpenTofu

```bash
cd environments/home-lab

# Initialize the project
terraform init
# or
opentofu init
```

### Step 2: Plan the Deployment

```bash
# Review what will be created
terraform plan
# or
opentofu plan
```

Review the output to ensure:
- dnsmasq configuration file path is correct
- boot script path is correct
- PXE root directory is correct

### Step 3: Apply the Configuration

```bash
# Deploy the PXE server configuration
terraform apply
# or
opentofu apply

# Type 'yes' when prompted
```

This will:
1. Create the dnsmasq configuration file
2. Generate the iPXE boot script
3. Set up the necessary directories

### Step 4: Copy Configuration to System

```bash
# Copy dnsmasq configuration (if not already done)
sudo cp /var/lib/tftp/dnsmasq.conf /usr/local/etc/dnsmasq.conf

# Restart dnsmasq to apply changes
sudo brew services restart dnsmasq
```

### Step 5: Verify Everything is Running

```bash
# Check if dnsmasq is running
sudo launchctl list | grep homebrew.mxcl.dnsmasq

# Should output something like:
# -	0	homebrew.mxcl.dnsmasq

# Check logs
tail -20 /var/log/system.log | grep dnsmasq
```

## Troubleshooting

### dnsmasq Not Starting

```bash
# Check if dnsmasq service exists
brew services list | grep dnsmasq

# If not listed, restart it
sudo brew services restart dnsmasq

# Check for errors
sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist

# View logs
tail -f /var/log/system.log | grep dnsmasq
```

### Port Already in Use

```bash
# Check what's using ports 67 (DHCP) and 69 (TFTP)
sudo lsof -i :67
sudo lsof -i :69

# If another service is using these ports, either:
# 1. Stop the conflicting service
# 2. Change dnsmasq configuration to use different ports
# 3. Use different network interface
```

### Machines Not Receiving PXE Boot

1. **Check network connectivity**:
   ```bash
   # Verify your macbook can see the network
   ping 192.168.1.1  # Your gateway
   ```

2. **Check DHCP responses**:
   ```bash
   # Monitor DHCP requests
   sudo tcpdump -i ${interface} 'port 67 or port 68'
   ```

3. **Verify boot files exist**:
   ```bash
   ls -la /var/lib/tftp/
   # Should see boot.ipxe and other boot files
   ```

4. **Check dnsmasq logs**:
   ```bash
   tail -100 /var/log/system.log | grep dnsmasq
   ```

### Configuration Changes Not Applied

If you update `terraform.tfvars`:

```bash
cd environments/home-lab

# Plan the changes
terraform plan

# Apply the changes
terraform apply

# Restart dnsmasq if configuration changed
sudo brew services restart dnsmasq
```

## Advanced Configuration

### Custom Talos Configuration

To enable automated Talos installation, create a machine configuration:

```bash
# Generate Talos machine config
talosctl gen config my-cluster https://192.168.1.100:6443 \
  --output-dir ./talos-config

# Copy to PXE server
cp talos-config/controlplane.yaml /var/lib/tftp/talos/
cp talos-config/worker.yaml /var/lib/tftp/talos/
```

### Custom Debian Configuration

To enable automated Debian installation with preseed:

```bash
# Create preseed configuration
cat > /var/lib/tftp/debian/preseed.cfg << 'EOF'
# Debian preseed configuration
d-i locale set en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/enable boolean true
d-i netcfg/choose_interface select auto
d-i hw-detect/load_firmware boolean true
d-i netcfg/get_hostname string debian
d-i netcfg/get_domain string local
d-i netcfg/wireless_wep string
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/suite string bookworm
d-i mirror/codename string bookworm
d-i mirror/udeb/suite string bookworm
d-i mirror/udeb/codename string bookworm
d-i clock-setup/utc boolean true
d-i time/zone string UTC
d-i clock-setup/ntp boolean true
d-i partman-auto/method string lvm
d-i partman-auto-lvm/guided_size string max
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto-lvm/new_vg_name string debian-vg
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i passwd/root-login boolean false
d-i passwd/user-fullname string debian
d-i passwd/username string debian
d-i passwd/user-password password debian
d-i passwd/user-password-again password debian
tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string openssh-server vim curl wget
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i finish-install/reboot_in_progress note
EOF
```

Update boot script to use preseed:

```bash
# Update boot.ipxe to include preseed URL
# kernel http://${server-ip}:8080/debian/linux \
#   ... \
#   url=http://${server-ip}:8080/debian/preseed.cfg
```

### Monitoring Boot Activity

```bash
# Real-time monitoring of DHCP requests
sudo tcpdump -i en0 'port 67 or port 68' -v

# Monitor TFTP transfers
sudo tcpdump -i en0 'port 69' -v

# Monitor all PXE activity
sudo tcpdump -i en0 '(port 67 or port 68 or port 69)' -v
```

### Disabling/Enabling Boot Options

Edit `terraform.tfvars`:

```hcl
# Disable Talos
enable_talos = false

# Disable Debian
enable_debian = false

# Apply changes
terraform apply
```

## Security Considerations

### Firewall Configuration

```bash
# Allow dnsmasq through macOS firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/sbin/dnsmasq

# Or disable firewall for this task (not recommended)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
```

### Network Isolation

For production:
1. Use a separate network segment for PXE
2. Restrict DHCP scope to known subnets
3. Implement boot authorization
4. Use encrypted boot credentials

### Boot Script Security

Keep boot scripts in secure location:

```bash
# Restrict permissions
sudo chmod 600 /var/lib/tftp/boot.ipxe

# Only allow your user to modify
sudo chown $(whoami) /var/lib/tftp/boot.ipxe
```

## Uninstalling

### Clean Up PXE Server

```bash
# Destroy Terraform resources
cd environments/home-lab
terraform destroy

# Stop dnsmasq
sudo brew services stop dnsmasq

# Remove dnsmasq configuration
sudo rm /usr/local/etc/dnsmasq.conf

# Clean up TFTP root (optional)
sudo rm -rf /var/lib/tftp
```

## Next Steps

1. **Boot a machine** from PXE to test the installation
2. **Install Talos Linux** for Kubernetes clusters
3. **Install Debian Linux** for general-purpose servers
4. **Configure NAS** on Debian if needed

## Support and Resources

- [Talos Linux Documentation](https://www.talos.dev/)
- [Debian Installation Guide](https://www.debian.org/releases/bookworm/amd64/)
- [iPXE Documentation](https://ipxe.org/cmd)
- [dnsmasq Manual](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
