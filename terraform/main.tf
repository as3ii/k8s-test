variable "proxmox_node" {
  type        = string
  description = "Proxmox cluster node name"
  nullable    = false
}

variable "template" {
  type        = string
  description = "Template to use"
  default     = "debian13"
  validation {
    condition     = can(regex("^[a-z0-9-.]{1,255}$", var.template))
    error_message = "Invalid template name"
  }
}

variable "nodes" {
  type = set(object({
    name    = string                               # Unique name of the VM
    id      = optional(number, 0)                  # Unique id of the VM, 0 = the first available one
    network = optional(string, "ip=dhcp,ip6=auto") # Network settings, eg: 'ip=10.0.0.100,gw=10.0.0.1'
  }))
  description = "VMs settings, see default"
  default = [
    {
      name    = "kube-0"
      id      = 0
      network = "ip=dhcp,ip6=auto"
    }
  ]
  validation {
    condition = alltrue([
      for n in var.nodes : alltrue([
        can(regex("^[a-z0-9-]+$", n.name)),
        n.id >= 0,
        can(regex("^((ip=([0-9]{1,3}[.]){3}[0-9]{1,3}/[0-9]+,gw=([0-9]{1,3}[.]){3}[0-9]{1,3})|(ip=dhcp))?,?((ip6=.*/[0-9]+,gw6=.*)|(ip6=dhcp)|(ip6=auto))?$", n.network)),
      ])
    ])
    error_message = "Invalid nodes attributes"
  }
}

variable "nameserver" {
  type        = string
  description = "Name server IP"
  default     = "9.9.9.9"
  validation {
    condition     = can(regex("^([0-9]{1,3}[.]){3}[0-9]{1,3}$", var.nameserver))
    error_message = "Invalid nameserver IP"
  }
}

variable "searchdomain" {
  type        = string
  description = "Search domain"
  nullable    = false
  default     = "" # Defaults to var.dns_name, see locals
}

variable "dns_zone" {
  type        = string
  description = "DNS zone"
  nullable    = false
  default     = ""
  validation {
    condition     = can(regex("^(|[a-z0-9-.]+\\.)$", var.dns_zone))
    error_message = "Invalid DNS zone, must be empty or a fully qualified domain"
  }
}

variable "cluster_name" {
  type        = string
  description = "Cluster name, used for DNS load balancing"
  default     = "kube"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Invalid cluster name"
  }
}

variable "cluster_vip" {
  type        = list(string)
  description = "Cluster virtual IPs"
  default     = null
  validation {
    condition = null || (length(var.cluster_vip) > 0 && alltrue([
      for i in var.cluster_vip : can(regex("^([0-9]{1,3}[.]){3}[0-9]{1,3}$", i))
    ]))
    error_message = "Invalid cluster virtual IP, must be null or a list of valid IPs"
  }
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public key files"
}

variable "password" {
  type        = string
  sensitive   = true
  description = "Container root password"
  validation {
    condition     = length(var.password) >= 5
    error_message = "Container password must be at least 5 character long"
  }
}

locals {
  searchdomain = var.searchdomain == "" ? trimpostfix(var.dns_zone, ".") : var.searchdomain
  cluster_vip  = var.cluster_vip == null ? [for n in proxmox_vm_qemu.kube : n.default_ipv4_address] : var.cluster_vip
}

resource "proxmox_vm_qemu" "kube" {
  for_each = {
    for i, n in var.nodes : n.name => n
  }

  target_node        = var.proxmox_node
  name               = each.value.name
  tags               = "k8s"
  vmid               = each.value.id
  start_at_node_boot = true
  vm_state           = "running"
  agent              = 1 # Enable QEMU guest agent

  # VM template to clone
  clone      = var.template
  full_clone = true

  # CPU and RAM
  cpu {
    sockets = 1
    cores   = 2
    type    = "x86-64-v2-AES" # Use "host" to copy the host CPU type
    #limit   = 4
    #units   = 1024
  }
  memory  = 2048
  balloon = 1024 # Minimum allocated memory

  # High Availability settings
  #hastate = ""
  #hagroup = ""

  # Cloud-init settings
  os_type      = "cloud-init"
  ciuser       = "root"
  cipassword   = var.password
  sshkeys      = join("\n", [for p in var.ssh_public_keys : file(pathexpand(p))])
  ipconfig0    = each.value.network
  nameserver   = var.nameserver
  searchdomain = local.searchdomain
  skip_ipv6    = true # Acquiring an IPv6 address from the qemu guest agent isn't required

  # HW settings
  bios = "seabios"
  serial {
    id   = 0
    type = "socket"
  }
  vga {
    type = "serial0"
  }
  boot   = "order=scsi0"
  scsihw = "virtio-scsi-single"

  disks {
    scsi {
      scsi0 {
        disk {
          storage    = "local"
          size       = "3G"
          iothread   = true
          discard    = true
          emulatessd = true
          format     = "qcow2"
        }
      }
    }
    ide {
      ide0 {
        cloudinit {
          storage = "local"
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    #tag    = 100 # VLAN
  }

  startup_shutdown {
    order            = null
    shutdown_timeout = null
    startup_delay    = null
  }
}

resource "null_resource" "wait_for_vm" {
  for_each = proxmox_vm_qemu.kube

  provisioner "remote-exec" {
    inline = [
      "echo 'waiting for VM to start...'",
      "systemctl is-system-running --wait"
    ]
    connection {
      type    = "ssh"
      user    = "root"
      host    = each.value.default_ipv4_address
      agent   = true
      timeout = "5m"
    }
  }
  depends_on = [proxmox_vm_qemu.kube]
}

resource "dns_a_record_set" "hosts_a_records" {
  for_each = (var.dns_server != "0.0.0.0" && var.dns_zone != "") ? proxmox_vm_qemu.kube : {}

  zone      = var.dns_zone
  name      = each.value.name
  addresses = [each.value.default_ipv4_address]
  ttl       = 300 # 5 minutes

  depends_on = [null_resource.wait_for_vm]
}

resource "dns_a_record_set" "cluster_a_record" {
  count = (var.dns_server != "0.0.0.0" && var.dns_zone != "") ? 1 : 0

  zone      = var.dns_zone
  name      = var.cluster_name
  addresses = local.cluster_vip
  ttl       = 300 # 5 minutes

  depends_on = [null_resource.wait_for_vm]
}
