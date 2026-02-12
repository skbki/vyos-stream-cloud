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
  boot_wait        = "10s"
  boot_command     = [
    "<enter><wait30>",
    "vyos<enter><wait>",
    "vyos<enter><wait>",
    "install image<enter><wait>",
    "<enter><wait>",
    "<enter><wait>",
    "<enter><wait>",
    "<enter><wait>",
    "yes<enter><wait30>",
    "<enter><wait>",
    "<enter><wait>",
    "vyos<enter><wait>",
    "vyos<enter><wait10>",
    "reboot<enter><wait>",
    "yes<enter><wait60>",
  ]
  
  # SSH Configuration
  ssh_username     = "vyos"
  ssh_password     = "vyos"
  ssh_timeout      = "20m"
  ssh_wait_timeout = "20m"
  
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
      
      # Configure cloud-init
      "source /opt/vyatta/etc/functions/script-template",
      "configure",
      "set system login user vyos authentication public-keys cloud-init type ssh-rsa",
      "set system login user vyos authentication public-keys cloud-init key AAAAB3NzaC1yc2EAAAADAQABAAABAQC",
      "delete system login user vyos authentication public-keys cloud-init",
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
