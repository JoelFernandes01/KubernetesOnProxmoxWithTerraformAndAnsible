# Provider configuration (provider.tf)
terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc4"
    }
  }
}

provider "proxmox" {
  # set in vars.tf 
  pm_api_url = var.pm_api_url

  # insecure unless using signed certificates
  pm_tls_insecure = true

  # set either username and passowrd or token details - values in vars.tf

  # username and password options for security
  pm_user    = var.pm_user
  pm_password = var.pm_password

  # token details
  #pm_api_token_id = var.pm_api_token_id
  #pm_api_token_secret = var.pm_api_token_secret

}

resource "proxmox_vm_qemu" "k8s-master" {
  count = 1
  name = "k8s-master"
  desc = "K8s Master"
  target_node = "pvem6500"
  clone = "VM9000"
  cores = 2
  sockets = 1
  memory = 2048
  agent = 1

  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disks {
        ide {
            ide2 {
                cloudinit {
                    storage = "local-lvm"
                }
            }
        }
        scsi {
            scsi0 {
                disk {
                    size            = 32
                    cache           = "writeback"
                    storage         = "local-lvm"
                    #storage_type    = "rbd"
                    #iothread        = true
                    #discard         = true
                    replicate       = true
                }
            }
        }
    }

  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  boot = "order=scsi0"

  ipconfig0 = "ip=192.168.5.230/24,gw=192.168.5.1"
  os_type = "cloud-init"
  vmid = 230

  ciuser = var.ssh_user
  cipassword = var.ssh_password

  sshkeys = <<EOF
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCfD0M8eBePO1SzExnOtLx7buwMT6JfH2bv4cF8F9SQMt6iFO9iLwDYHw9zW0oy4GXLZJdMvBsf7oY1NMp2gCMTebR3WKFClGr8yu6+eJNrk6amWL5F8L3eLDOyxzZetfCsCyeyTjY+zqi1wFlKfnmGV68dR5kf3h3fXGysgpb3Az4khvSwKvRPW1eW3WV5Wc8w+ABruKKm0YCLWyfNEmVLrSs5lnIgacRT3q6o5NTXXpTk0cBxFZxMVQr3UrpU8zR5qaZ2ir7ciZwE2fSs2b0iP6pg7Li9NWWs0jU/3AhvLiMhsYawoMoIX6QwQhRNQf6TNlDdlHEkD4dYdU/6Xp9MHT2/EFG6eOdOF4cQfUeMYjPFLH/b11/pmURdyFmxGZ72YcrSTnz+DaERTjl4dpvvflE0CMBypHSv7sh6zQgulpCEjMOdEyPyYl12hmX/EpjJ7z4V8W1HkjDf3LmnM7ee8opdMwn4KaITyaLo6fEwmKycjOrniuBz2aKvEjyyUD8= your_email@example.com
    EOF

  serial {
      id   = 0
      type = "socket"
    }

  provisioner "remote-exec" {
    inline = ["echo ${var.ssh_password} | sudo -S -k hostnamectl set-hostname k8s-master"]

    connection {
      host = self.ssh_host
      type = "ssh"
      user = var.ssh_user
      password = var.ssh_password
      private_key = "${file("../tf-cloud-init")}"
    }
  }
}



resource "proxmox_vm_qemu" "k8s-node" {
  count = 3 # number of VMs to create
  name = "k8s-node${count.index + 1}"
  desc        = "K8s node"
  target_node = "pvem6500"
  
  ### Clone VM operation
  clone = "VM9000"
  # note that cores, sockets and memory settings are not copied from the source VM template
  cores = 2
  sockets = 1
  memory = 2048 

  # Activate QEMU agent for this VM
  agent = 1

  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disks {
        ide {
            ide2 {
                cloudinit {
                    storage = "local-lvm"
                }
            }
        }
        scsi {
            scsi0 {
                disk {
                    size            = 32
                    cache           = "writeback"
                    storage         = "local-lvm"
                    #storage_type    = "rbd"
                    #iothread        = true
                    #discard         = true
                    replicate       = true
                }
            }
        }
    }

  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  boot = "order=scsi0"

  ipconfig0 = "ip=192.168.5.${count.index + 231 }/24,gw=192.168.5.1"
  os_type = "cloud-init"
  vmid = "${count.index + 231 }"

  ciuser = var.ssh_user
  cipassword = var.ssh_password

  sshkeys = <<EOF
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCfD0M8eBePO1SzExnOtLx7buwMT6JfH2bv4cF8F9SQMt6iFO9iLwDYHw9zW0oy4GXLZJdMvBsf7oY1NMp2gCMTebR3WKFClGr8yu6+eJNrk6amWL5F8L3eLDOyxzZetfCsCyeyTjY+zqi1wFlKfnmGV68dR5kf3h3fXGysgpb3Az4khvSwKvRPW1eW3WV5Wc8w+ABruKKm0YCLWyfNEmVLrSs5lnIgacRT3q6o5NTXXpTk0cBxFZxMVQr3UrpU8zR5qaZ2ir7ciZwE2fSs2b0iP6pg7Li9NWWs0jU/3AhvLiMhsYawoMoIX6QwQhRNQf6TNlDdlHEkD4dYdU/6Xp9MHT2/EFG6eOdOF4cQfUeMYjPFLH/b11/pmURdyFmxGZ72YcrSTnz+DaERTjl4dpvvflE0CMBypHSv7sh6zQgulpCEjMOdEyPyYl12hmX/EpjJ7z4V8W1HkjDf3LmnM7ee8opdMwn4KaITyaLo6fEwmKycjOrniuBz2aKvEjyyUD8= your_email@example.com
    EOF

  serial {
      id   = 0
      type = "socket"
    }

  provisioner "remote-exec" {
    inline = ["echo ${var.ssh_password} | sudo -S -k hostnamectl set-hostname ${self.name}"]

    connection {
      host = self.ssh_host
      type = "ssh"
      user = var.ssh_user
      password = var.ssh_password
      private_key = "${file("../tf-cloud-init")}"
    }
  }
  

}

output "proxmox_master_default_ip_addresses" {
  description = "Current IP Default"
  value = proxmox_vm_qemu.k8s-master.*.default_ipv4_address
}

output "proxmox_nodes_default_ip_addresses" {
  description = "Current IP Default"
  value = proxmox_vm_qemu.k8s-node.*.default_ipv4_address
}

