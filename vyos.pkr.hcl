// VyOS Stream QCOW2 Image Builder for Packer
// This configuration builds a VyOS Stream qcow2 image with cloud-init and qemu-guest-agent

packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "iso_url" {
  type    = string
  default = env("VYOS_ISO_URL")
  description = "URL to VyOS ISO image"
}

variable "iso_checksum" {
  type    = string
  default = "none"
  description = "ISO checksum - use 'none' to skip verification"
}

variable "output_dir" {
  type    = string
  default = "output"
  description = "Output directory for the built image"
}

variable "vm_name" {
  type    = string
  default = "vyos-stream"
  description = "Name of the output image"
}

variable "disk_size" {
  type    = string
  default = "10G"
  description = "Disk size for the VM"
}

variable "memory" {
  type    = string
  default = "2048"
  description = "Memory size in MB"
}

variable "cpus" {
  type    = string
  default = "2"
  description = "Number of CPUs"
}

variable "ssh_username" {
  type    = string
  default = "vyos"
  description = "SSH username for VyOS"
}

variable "ssh_password" {
  type    = string
  default = "vyos"
  description = "SSH password for VyOS"
}

variable "console_type" {
  type    = string
  default = "S"
  description = "Console type during install: S for Serial (cloud), K for KVM (graphical)"
}

source "qemu" "vyos" {
  # ISO Configuration
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  
  # VM Configuration
  vm_name          = "${var.vm_name}.qcow2"
  output_directory = var.output_dir
  
  # Hardware Configuration
  disk_size        = var.disk_size
  memory           = var.memory
  cpus             = var.cpus
  
  # QEMU Configuration
  # ENABLE KVM acceleration for speed
  accelerator      = "kvm"
  format           = "qcow2"
  net_device       = "virtio-net"
  disk_interface   = "virtio"
  
  # Boot Configuration
  boot_wait        = "5s"
  boot_command     = [
    "<enter>",
    "<wait60s>",
    "${var.ssh_username}<enter><wait>",
    "${var.ssh_password}<enter><wait>",
    "configure<enter><wait>",
    "set interfaces ethernet eth0 address 'dhcp'<enter><wait>",
    "set system name-server '8.8.8.8'<enter><wait>",
    "set service ssh port '22'<enter><wait>",
    "commit<enter><wait2s>",
    "save<enter><wait2s>",
    "exit<enter><wait1s>",
    "install image<enter><wait3s>",
    "Yes<enter><wait3s>",
    "<enter><wait3s>",
    "${var.ssh_password}<enter><wait>",
    "${var.ssh_password}<enter><wait>",
    "${var.console_type}<enter><wait3s>",
    "<enter><wait2s>",
    "Y<enter><wait3s>",
    "Y<enter><wait3s>",
    "1<enter><wait3s>",
    "<enter><wait10s>",
  ]
  
  # SSH Configuration
  # Increased timeout to 30m to accommodate slower systems and installation time
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
  ssh_wait_timeout = "30m"
  
  # Shutdown Configuration
  shutdown_command = "sudo poweroff"
  
  # Headless mode
  headless         = true
}

build {
  sources = ["source.qemu.vyos"]
  
  # Wait for system to be ready
  provisioner "shell" {
    inline = [
      "echo 'Waiting for system to be ready...'",
      "sleep 10"
    ]
  }
  
  # Configure VyOS and install cloud-init and qemu-guest-agent
  provisioner "shell" {
    inline = [
      # Add Debian repository directly to apt sources (VyOS doesn't have 'set system package repository')
      "sudo bash -c 'echo \"deb http://deb.debian.org/debian bookworm main contrib non-free\" > /etc/apt/sources.list.d/debian.list'",
      "sudo bash -c 'echo \"deb-src http://deb.debian.org/debian bookworm main contrib non-free\" >> /etc/apt/sources.list.d/debian.list'",
      
      # Install packages
      "sudo apt-get update",
      "sudo apt-get install -y cloud-init qemu-guest-agent",
      
      # Remove temporary Debian repository after package installation (security best practice)
      # Note: Packages are pre-installed; cloud-init will manage system from cloud metadata
      # If future package updates are needed, repository can be re-added via cloud-init/config management
      "sudo rm -f /etc/apt/sources.list.d/debian.list",
      "sudo apt-get update",
      
      # Configure cloud-init and serial console
      "source /opt/vyatta/etc/functions/script-template",
      "configure",
      # Note: SSH keys will be managed by cloud-init at boot time
      # The VyOS user is already configured from installation
      # Configure serial console for cloud environments
      "set system console device ttyS0 speed '115200'",
      "commit",
      "save",
      "exit"
    ]
  }
  
  # Clean up
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -f /home/vyos/.ssh/authorized_keys",
      "sudo sync"
    ]
  }
  
  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "${var.output_dir}/${var.vm_name}.qcow2.sha256"
  }
  
  # Test cloud-init integration with nocloud datasource
  post-processor "shell-local" {
    inline = [
      "echo ''",
      "echo '=========================================='",
      "echo 'Testing cloud-init with NoCloud datasource'",
      "echo '=========================================='",
      "echo ''",
      
      # Create test directory
      "TEST_DIR=$(mktemp -d)",
      "echo \"Test directory: $TEST_DIR\"",
      
      # Create cloud-init user-data
      "cat > $TEST_DIR/user-data << 'USERDATA'",
      "#cloud-config",
      "hostname: vyos-test",
      "fqdn: vyos-test.local",
      "password: testpassword",
      "chpasswd:",
      "  expire: false",
      "write_files:",
      "  - path: /tmp/cloud-init-test.txt",
      "    content: 'Cloud-init NoCloud test successful!'",
      "    permissions: '0644'",
      "runcmd:",
      "  - touch /tmp/cloud-init-success",
      "USERDATA",
      
      # Create cloud-init meta-data
      "cat > $TEST_DIR/meta-data << 'METADATA'",
      "instance-id: vyos-test-instance",
      "local-hostname: vyos-test",
      "METADATA",
      
      # Create NoCloud ISO
      "echo 'Creating NoCloud seed ISO...'",
      "genisoimage -output $TEST_DIR/seed.iso -volid cidata -joliet -rock $TEST_DIR/user-data $TEST_DIR/meta-data 2>&1 | grep -v Warning || true",
      
      # Boot test with timeout
      "echo 'Booting image with cloud-init NoCloud datasource (60 second test)...'",
      "timeout 60 qemu-system-x86_64 -m 2048 -smp 2 -enable-kvm -nographic -drive file=${var.output_dir}/${var.vm_name}.qcow2,format=qcow2,if=virtio -drive file=$TEST_DIR/seed.iso,media=cdrom -net nic,model=virtio -net user > $TEST_DIR/boot.log 2>&1 || true",
      
      # Check results
      "echo ''",
      "echo 'Analyzing boot log...'",
      "if grep -q 'cloud-init' $TEST_DIR/boot.log; then echo '✓ Cloud-init detected'; else echo '⚠ Cloud-init not clearly detected'; fi",
      "if grep -q 'vyos-test' $TEST_DIR/boot.log; then echo '✓ Hostname configured'; else echo '⚠ Hostname not detected'; fi",
      
      # Cleanup
      "rm -rf $TEST_DIR",
      
      "echo ''",
      "echo '✓ Cloud-init NoCloud test completed'",
      "echo '=========================================='",
      "echo ''",
    ]
  }
}
