# Quick Start Guide

Get your PXE boot server running in minutes!

## Prerequisites Check

```bash
# Check if Terraform/OpenTofu is installed
terraform version || opentofu version

# Check if dnsmasq is installed
brew list dnsmasq || brew install dnsmasq

# Find your network interface
ifconfig | grep -E "^[a-z]+:" | head -5
```

## 5-Minute Setup

### 1. Update Configuration

```bash
cd environments/home-lab

# Edit terraform.tfvars and update:
# - pxe_server_ip (your macbook's IP)
# - pxe_server_interface (from ifconfig above)
# - dhcp_range_start and dhcp_range_end
nano terraform.tfvars
```

**Essential changes**:
```hcl
pxe_server_ip = "YOUR_MACBOOK_IP"      # e.g., 192.168.1.100
pxe_server_interface = "YOUR_INTERFACE" # e.g., en0
gateway = "YOUR_GATEWAY"               # e.g., 192.168.1.1
```

### 2. Deploy Configuration

```bash
# Initialize
terraform init

# Review changes
terraform plan

# Apply configuration
terraform apply
# Type 'yes' when prompted
```

### 3. Start Services

```bash
# Create TFTP directory
sudo mkdir -p /var/lib/tftp
sudo chown $(whoami):staff /var/lib/tftp

# Copy dnsmasq config
sudo cp /var/lib/tftp/dnsmasq.conf /usr/local/etc/dnsmasq.conf

# Restart dnsmasq
sudo brew services restart dnsmasq

# Verify it's running
sudo launchctl list | grep homebrew.mxcl.dnsmasq
```

### 4. Test Setup

```bash
# Check dnsmasq is running
ps aux | grep dnsmasq | grep -v grep

# Check boot script exists
ls -la /var/lib/tftp/boot.ipxe

# Test TFTP
tftp -c get boot.ipxe /tmp/
ls -la /tmp/boot.ipxe
```

## Boot a Machine

### For BIOS Machines

1. Power on machine
2. Press boot menu key (F12, F2, ESC, etc. depending on manufacturer)
3. Select network/PXE boot option
4. Machine will download boot script
5. Select "Talos Linux" or "Debian Linux" from menu
6. Installation will begin

### For UEFI Machines

1. Power on machine
2. Press boot menu key (F12, DEL, etc.)
3. Select UEFI network boot option
4. Machine will download boot script
5. Select OS from menu
6. Installation will begin

## Common Tasks

### Check Service Status

```bash
# Is dnsmasq running?
sudo launchctl list | grep homebrew.mxcl.dnsmasq

# View recent logs
tail -50 /var/log/system.log | grep dnsmasq
```

### Restart Services

```bash
# Restart dnsmasq
sudo brew services restart dnsmasq

# Full restart
sudo brew services stop dnsmasq
sleep 2
sudo brew services start dnsmasq
```

### Monitor Boot Activity

```bash
# Watch network traffic
sudo tcpdump -i en0 'port 67 or port 68 or port 69' -v

# In another terminal, try PXE boot on a machine
# You should see DHCP and TFTP packets
```

### Stop Everything

```bash
# Stop dnsmasq
sudo brew services stop dnsmasq

# Clean up (optional)
terraform destroy
```

## What Gets Installed

After `terraform apply`:

```
/var/lib/tftp/
├── boot.ipxe              # iPXE boot menu script
├── dnsmasq.conf           # dnsmasq configuration
├── talos/                 # Talos Linux assets
├── debian/                # Debian Linux assets
└── efi/                   # UEFI boot files
```

## Updating Versions

### Update Talos Version

Edit `terraform.tfvars`:
```hcl
talos_version = "v1.9.0"  # Change version
```

Then:
```bash
terraform plan
terraform apply
```

### Update Debian Version

Edit `terraform.tfvars`:
```hcl
debian_version = "trixie"  # Change version
```

Then:
```bash
terraform plan
terraform apply
```

## Troubleshooting

### Machines Not Booting

1. **Check dnsmasq is running**:
   ```bash
   sudo launchctl list | grep homebrew.mxcl.dnsmasq
   ```

2. **Verify boot file exists**:
   ```bash
   ls -la /var/lib/tftp/boot.ipxe
   ```

3. **Check logs**:
   ```bash
   tail -20 /var/log/system.log | grep dnsmasq
   ```

4. **Verify network interface**:
   ```bash
   ifconfig ${INTERFACE}  # From terraform.tfvars
   ```

### Port Conflicts

```bash
# Check what's using DHCP/TFTP ports
sudo lsof -i :67    # DHCP
sudo lsof -i :69    # TFTP

# If another service is using these ports:
# Either stop it or change dnsmasq config
```

### Configuration Not Applying

```bash
cd environments/home-lab

# Force re-apply
terraform destroy
terraform init
terraform apply
```

## Files to Know

| File | Purpose |
|------|---------|
| `terraform.tfvars` | Your configuration |
| `/var/lib/tftp/boot.ipxe` | Boot menu script |
| `/var/lib/tftp/dnsmasq.conf` | DHCP/TFTP config |
| `/var/log/system.log` | System logs |

## Support

For more detailed information:
- See [SETUP.md](SETUP.md) for complete setup guide
- See [ARCHITECTURE.md](ARCHITECTURE.md) for system architecture
- See [README.md](README.md) for project overview

## Key Commands Reference

```bash
# Navigate to environment
cd environments/home-lab

# Initialize Terraform
terraform init

# Check configuration
terraform validate

# See what will be created
terraform plan

# Create/update resources
terraform apply

# Destroy everything
terraform destroy

# See current state
terraform show

# View outputs
terraform output

# Restart services
sudo brew services restart dnsmasq

# View logs
tail -f /var/log/system.log | grep dnsmasq

# Monitor network
sudo tcpdump -i en0 'port 67 or port 68 or port 69'
```

That's it! You should now have a working PXE boot server. 🚀
