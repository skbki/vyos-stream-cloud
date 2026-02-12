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
  description = "Console type: S for Serial (recommended for cloud), K for KVM"
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
      "source /opt/vyatta/etc/functions/script-template",
      "configure",
      
      # Install cloud-init and qemu-guest-agent
      "set system package repository community",
      "set system package repository community distribution bookworm",
      "set system package repository community components 'main contrib non-free'",
      "set system package repository community url 'http://deb.debian.org/debian'",
      "commit",
      "save",
      "exit",
      
      # Install packages
      "sudo apt-get update",
      "sudo apt-get install -y cloud-init qemu-guest-agent",
      
      # Remove community repository after package installation
      "source /opt/vyatta/etc/functions/script-template",
      "configure",
      "delete system package repository community",
      "commit",
      "save",
      "exit",
      
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
}
