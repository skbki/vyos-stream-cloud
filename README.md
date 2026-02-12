# VyOS Stream Cloud Image Builder

Automated pipeline to build VyOS Stream qcow2 images using Packer on Cirrus CI with KVM acceleration.

## Overview

This repository provides a complete DevOps pipeline for building VyOS Stream cloud images (qcow2 format) suitable for use in cloud environments like OpenStack, KVM, and other virtualization platforms that support cloud-init.

## Features

- 🚀 **Automated builds** using Cirrus CI with free KVM acceleration
- ⚡ **Fast builds** thanks to KVM hardware acceleration
- 📦 **Cloud-ready images** with cloud-init and qemu-guest-agent pre-installed
- 🔄 **Scheduled builds** with cron triggers (optional)
- 📤 **Automatic releases** to GitHub Releases
- 🔍 **Latest ISO detection** by scraping vyos.net Stream releases

## Repository Structure

```
.
├── .cirrus.yml              # Cirrus CI configuration
├── vyos.pkr.hcl            # Packer configuration for QEMU/KVM
├── scripts/
│   └── get_iso.py          # Python script to fetch latest VyOS ISO URL
└── README.md               # This file
```

## Prerequisites

To use this repository, you need:

1. A GitHub account with this repository
2. Cirrus CI connected to your GitHub repository (free for public repos)
3. (Optional) A GitHub token for automated releases

## Files Description

### 1. `scripts/get_iso.py`

Python script that scrapes the VyOS website to find the latest Stream release ISO URL (e.g., 2025.11).

**Usage:**
```bash
python3 scripts/get_iso.py
```

**Dependencies:**
- Python 3
- `requests` library

### 2. `vyos.pkr.hcl`

Packer configuration file that defines the VyOS image build process.

**Key features:**
- QEMU builder with KVM acceleration enabled (`accelerator = "kvm"`)
- Automated VyOS installation via boot commands following the official installation process:
  1. Login to live system (vyos/vyos)
  2. Configure network (DHCP on eth0)
  3. Set DNS server
  4. Enable SSH
  5. Run installation with proper prompts:
     - "Yes" to continue installation
     - Use default image name
     - Set password
     - "K" for KVM console (not serial)
     - Use default disk (vda)
     - "Y" to confirm deletion of data
     - "Y" to use all free space
     - "1" to select first boot option
- Installs `cloud-init` and `qemu-guest-agent`
- Configures Debian repository for package installation
- Outputs qcow2 format image
- Generates SHA256 checksums

**Variables:**
- `iso_url`: URL to VyOS ISO (from environment or default)
- `iso_checksum`: ISO checksum (default: "none" to skip verification)
- `output_dir`: Output directory for built image (default: "output")
- `vm_name`: Name of output image (default: "vyos-stream")
- `disk_size`: VM disk size (default: "10G")
- `memory`: VM memory in MB (default: "2048")
- `cpus`: Number of CPUs (default: "2")
- `ssh_username`: SSH username (default: "vyos")
- `ssh_password`: SSH password (default: "vyos")

### 3. `.cirrus.yml`

Cirrus CI configuration for automated builds.

**Key features:**
- KVM-enabled container for fast builds
- Installs QEMU, KVM, Packer, and dependencies
- Fetches latest VyOS ISO URL
- Builds qcow2 image with Packer
- Creates GitHub releases with artifacts
- Optional cron scheduling

**Environment variables:**
- `PACKER_VERSION`: Version of Packer to install (default: "1.10.0")
- `GITHUB_TOKEN`: GitHub token for creating releases (encrypted)

## Quick Start

### 1. Fork/Clone this repository

```bash
git clone https://github.com/YOUR_USERNAME/vyos-stream-cloud.git
cd vyos-stream-cloud
```

### 2. Connect to Cirrus CI

1. Go to https://cirrus-ci.com/
2. Sign in with your GitHub account
3. Enable Cirrus CI for your repository

### 3. Configure GitHub Token (Optional)

To enable automatic releases to GitHub:

1. Create a GitHub Personal Access Token:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Create a token with `repo` scope

2. Encrypt the token for Cirrus CI:
   ```bash
   # Install Cirrus CLI
   brew install cirruslabs/cli/cirrus
   
   # Encrypt your token
   cirrus encrypt --repository YOUR_USERNAME/vyos-stream-cloud GITHUB_TOKEN=your_token_here
   ```

3. Update `.cirrus.yml` and replace the `GITHUB_TOKEN` line with your encrypted token:
   ```yaml
   env:
     GITHUB_TOKEN: ENCRYPTED[your_encrypted_token_here]
   ```

### 4. Trigger a Build

**Manual trigger:**
- Push a commit to the repository
- Or trigger manually from Cirrus CI dashboard

**Automatic scheduled builds:**
Uncomment these lines in `.cirrus.yml`:
```yaml
trigger_type: cron
cron: "0 2 * * *"
```

This will build daily at 2 AM UTC.

## Local Development

### Prerequisites

- Linux system with KVM support
- QEMU/KVM installed
- Packer installed
- Python 3 with `requests` library

### Local Build

1. Install dependencies:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install qemu-system-x86 qemu-utils qemu-kvm python3 python3-pip
   pip3 install requests
   
   # Install Packer
   wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
   unzip packer_1.10.0_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   ```

2. Get the latest ISO URL:
   ```bash
   python3 scripts/get_iso.py
   ```

3. Build the image:
   ```bash
   export VYOS_ISO_URL=$(python3 scripts/get_iso.py)
   packer init vyos.pkr.hcl
   packer build -var "iso_url=${VYOS_ISO_URL}" -var "iso_checksum=none" vyos.pkr.hcl
   ```

4. Find your image:
   ```bash
   ls -lh output/
   ```

## Using the Built Image

The built qcow2 image can be used in various cloud and virtualization platforms:

### OpenStack

```bash
openstack image create \
  --file output/vyos-stream.qcow2 \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  vyos-stream
```

### KVM/Libvirt

```bash
# Create a VM using the image
virt-install \
  --name vyos-test \
  --ram 2048 \
  --disk path=output/vyos-stream.qcow2,format=qcow2 \
  --vcpus 2 \
  --network network=default \
  --import
```

### QEMU Direct

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -smp 2 \
  -drive file=output/vyos-stream.qcow2,format=qcow2 \
  -net nic -net user
```

## Customization

### Modify Build Parameters

Edit `vyos.pkr.hcl` to change:
- Disk size: Change `disk_size` variable
- Memory/CPU: Change `memory` and `cpus` variables
- Additional packages: Add to the provisioner shell scripts
- Cloud-init configuration: Modify the cloud-init setup provisioner

### Change Build Schedule

Edit `.cirrus.yml` cron expression:
```yaml
cron: "0 2 * * *"  # Daily at 2 AM UTC
```

Cron format: `"minute hour day month day_of_week"`

Examples:
- `"0 */6 * * *"` - Every 6 hours
- `"0 0 * * 0"` - Weekly on Sunday at midnight
- `"0 0 1 * *"` - Monthly on the 1st at midnight

## Troubleshooting

### Build fails with "KVM not available"

Cirrus CI should provide KVM-enabled containers for public repositories. If KVM is not available:
- Check that `kvm_enabled: true` is set in `.cirrus.yml`
- Verify your repository is public
- The build will still work but will be slower without KVM

### ISO download fails

The `get_iso.py` script scrapes vyos.net for the latest Stream release ISO. If it fails:
- Check if vyos.net/get/stream/ is accessible
- Verify the page structure hasn't changed
- Manually specify an ISO URL:
  ```bash
  packer build -var "iso_url=https://path/to/vyos.iso" vyos.pkr.hcl
  ```

### Build timeout

If the build times out on Cirrus CI:
- Increase the timeout in `.cirrus.yml`
- Ensure KVM acceleration is working
- Consider reducing VM resources (memory/CPU) during build

### GitHub release fails

If automatic release upload fails:
- Verify `GITHUB_TOKEN` is correctly encrypted
- Ensure the token has `repo` scope
- Check Cirrus CI logs for specific error messages

## Architecture Details

### VyOS Installation Process

The automated installation follows these steps:

1. **Boot from ISO** - System boots into VyOS live environment
2. **Login** - Automatic login with default credentials (vyos/vyos)
3. **Network Configuration** - Configure eth0 with DHCP and set DNS
4. **Enable SSH** - Configure SSH service on port 22
5. **Commit & Save** - Save the configuration
6. **Run Installer** - Execute `install image` command
7. **Installation Prompts**:
   - Confirm installation with "Yes"
   - Accept default image name
   - Set root password (twice)
   - Select KVM console ("K" not serial)
   - Accept default disk (vda)
   - Confirm data deletion ("Y")
   - Confirm using all free space ("Y")
   - Select boot loader option (1)
   - Wait for installation to complete and reboot
8. **Post-Installation** - System reboots into installed VyOS
9. **Provisioning** - Cloud-init and qemu-guest-agent are installed
10. **Cleanup** - Remove temporary files and sync filesystem
11. **Final Image** - qcow2 image is ready for use

### Cloud-init Support

The built image includes cloud-init, enabling:
- Dynamic hostname configuration
- SSH key injection
- User data script execution
- Network configuration
- Password and user management

### QEMU Guest Agent

The qemu-guest-agent enables:
- Better VM lifecycle management
- File system freeze/thaw for snapshots
- Guest information reporting
- Time synchronization

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is provided as-is. VyOS is licensed under GPLv2. Please refer to VyOS documentation for licensing details.

## Resources

- [VyOS Official Site](https://vyos.net/)
- [VyOS Documentation](https://docs.vyos.io/)
- [Packer Documentation](https://www.packer.io/docs)
- [Cirrus CI Documentation](https://cirrus-ci.org/)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)

## Support

For issues related to:
- This automation pipeline: Open an issue in this repository
- VyOS itself: Visit [VyOS Community](https://forum.vyos.io/)
- Packer: Check [Packer documentation](https://www.packer.io/docs)
- Cirrus CI: See [Cirrus CI support](https://cirrus-ci.org/support/)
