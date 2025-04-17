# Using OpenTofu with KVM

## Introduction
OpenTofu is an open-source infrastructure-as-code tool (a fork of Terraform) that allows you to define and manage virtual machines (VMs) declaratively. In this guide, we’ll set up OpenTofu on a Rocky Linux or Red Hat-based system to provision VMs on KVM (Kernel-based Virtual Machine). We’ll install KVM, configure OpenTofu, define VM resources, and deploy a master-worker setup.

## Environment
- **Virtualization**: KVM (via Libvirt).
- **Tool**: OpenTofu.
- **Operating System**: Rocky Linux or another Red Hat-based OS (e.g., CentOS, RHEL).

## Configure OpenTofu

### Steps
1. **Create a Workspace Directory**  
   Set up a directory for your OpenTofu project:
   ```bash
   mkdir -p ~/workspace/OpenTofu-kvm-example/
   cd ~/workspace/OpenTofu-kvm-example/
   ```

2. **Define Provider Configuration**  
   Create `main.tf` to specify the Libvirt provider:
   ```hcl
   terraform {
     required_providers {
       libvirt = {
         source = "dmacvicar/libvirt"
       }
     }
   }
   ```

   Create `provider.tf` to connect to the local KVM instance:
   ```hcl
   provider "libvirt" {
     uri = "qemu:///system"
   }
   ```
   - `qemu:///system`: Connects to the system-wide KVM instance (requires root or Libvirt permissions).

3. **Define Variables**  
   Create `variables.tf` to store customizable settings. Adjust the defaults to match your environment:
   ```hcl
   variable "baseos_image_url" {
     description = "Path to the base OS image (e.g., Rocky Linux QCOW2)"
     default     = "/pool0/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
   }

   variable "pool_name" {
     description = "KVM storage pool name (check with 'virsh pool-list')"
     default     = "pool0"
   }

   variable "VM_domain" {
     description = "Domain suffix for VM fully qualified domain names (FQDN)"
     default     = "hostmaster.id"
   }

   variable "ssh_username" {
     description = "Username for SSH access to VMs"
     default     = "apps"
   }

   variable "ssh_private_key" {
     description = "Path to the SSH private key for VM access"
     default     = "~/.ssh/id_rsa"
   }

   # --- Master Node Variables --- #

   variable "VM_hostname_master" {
     description = "Base hostname for master VMs"
     default     = "l2-hostmaster"
   }

   variable "master_description" {
     description = "Description for master VMs"
     default     = "master node"
   }

   variable "VM_master_memory" {
     description = "RAM for master VMs (in MB)"
     default     = 2048
   }

   variable "VM_master_vcpu" {
     description = "Number of CPU cores for master VMs"
     default     = 1
   }

   variable "ip_address_master" {
     type        = list(string)
     description = "IP addresses for master VMs (with CIDR)"
     default     = ["172.20.3.89/26"]
   }

   variable "master_count" {
     description = "Number of master VMs to create"
     default     = 1
   }

   # --- Worker Node Variables --- #

   variable "VM_hostname_worker" {
     description = "Base hostname for worker VMs"
     default     = "opentf-worker-node"
   }

   variable "VMs_worker_description" {
     description = "Description for worker VMs"
     default     = "worker node"
   }

   variable "VM_worker_memory" {
     description = "RAM for worker VMs (in MB)"
     default     = 1024
   }

   variable "VM_worker_vcpu" {
     description = "Number of CPU cores for worker VMs"
     default     = 1
   }

   variable "ip_address" {
     type        = list(string)
     description = "IP addresses for worker VMs (with CIDR)"
     default     = ["172.20.3.90/26", "172.20.3.91/26"]
   }

   variable "VM_worker_count" {
     description = "Number of worker VMs to create"
     default     = 2
   }
   ```
   - Use `virsh pool-list` to find available storage pools if unsure about `pool_name`.
   - Adjust IP addresses and network settings to match your setup.

4. **Define Master Node Resources**  
   Create `master.tf` for the master VM:
   ```hcl
   data "template_file" "user_data_master" {
     count    = var.master_count
     template = file("${path.module}/config/user_data.yml")
     vars     = {
       hostname = "${var.VM_hostname_master}-${count.index}"
       domain   = var.VM_domain
     }
   }

   data "template_file" "network_config_master" {
     count    = var.master_count
     template = file("${path.module}/config/networks_config.yml")
     vars = {
       ip_address = var.ip_address_master[count.index]
     }
   }

   resource "libvirt_volume" "master_vol" {
     count  = var.master_count
     name   = "${var.VM_hostname_master}-vol.${count.index}"
     pool   = var.pool_name
     source = var.baseos_image_url
     format = "qcow2"
   }

   resource "libvirt_cloudinit_disk" "master_cloudinit" {
     count          = var.master_count
     name           = "${var.VM_hostname_master}-cloudinit.${count.index}.iso"
     user_data      = data.template_file.user_data_master[count.index].rendered
     network_config = data.template_file.network_config_master[count.index].rendered
     pool           = var.pool_name
   }

   resource "libvirt_domain" "masternode" {
     count       = var.master_count
     name        = "${var.VM_hostname_master}-${count.index}"
     memory      = var.VM_master_memory
     vcpu        = var.VM_master_vcpu
     description = var.master_description
     cloudinit   = libvirt_cloudinit_disk.master_cloudinit[count.index].id
     autostart   = true

     cpu {
       mode = "host-passthrough"
     }

     network_interface {
       macvtap        = "eno1"
       wait_for_lease = false
       hostname       = "${var.VM_hostname_master}-${count.index}"
     }

     console {
       type        = "pty"
       target_port = "0"
       target_type = "serial"
     }

     console {
       type        = "pty"
       target_port = "1"
       target_type = "virtio"
     }

     disk {
       volume_id = libvirt_volume.master_vol[count.index].id
     }
   }
   ```
   - Replace `eno1` with your network interface if using MacVTAP (check with `ip link`).

5. **Define Worker Node Resources**  
   Create `worker.tf` for the worker VMs:
   ```hcl
   data "template_file" "user_data" {
     count    = var.VM_worker_count
     template = file("${path.module}/config/user_data.yml")
     vars     = {
       hostname = "${var.VM_hostname_worker}-${count.index}"
       domain   = var.VM_domain
     }
   }

   data "template_file" "network_config" {
     count    = var.VM_worker_count
     template = file("${path.module}/config/networks_config.yml")
     vars = {
       ip_address = var.ip_address[count.index]
     }
   }

   resource "libvirt_volume" "worker_vol" {
     count  = var.VM_worker_count
     name   = "${var.VM_hostname_worker}-vol.${count.index}"
     pool   = var.pool_name
     source = var.baseos_image_url
     format = "qcow2"
   }

   resource "libvirt_cloudinit_disk" "worker_cloudinit" {
     count          = var.VM_worker_count
     name           = "${var.VM_hostname_worker}-cloudinit.${count.index}.iso"
     user_data      = data.template_file.user_data[count.index].rendered
     network_config = data.template_file.network_config[count.index].rendered
     pool           = var.pool_name
   }

   resource "libvirt_domain" "worker" {
     count       = var.VM_worker_count
     name        = "${var.VM_hostname_worker}-${count.index}"
     memory      = var.VM_worker_memory
     vcpu        = var.VM_worker_vcpu
     description = var.VMs_worker_description
     cloudinit   = libvirt_cloudinit_disk.worker_cloudinit[count.index].id
     autostart   = true

     cpu {
       mode = "host-passthrough"
     }

     network_interface {
       macvtap        = "eno1"
       wait_for_lease = false
       hostname       = "${var.VM_hostname_worker}-${count.index}"
     }

     console {
       type        = "pty"
       target_port = "0"
       target_type = "serial"
     }

     console {
       type        = "pty"
       target_port = "1"
       target_type = "virtio"
     }

     disk {
       volume_id = libvirt_volume.worker_vol[count.index].id
     }
   }
   ```

6. **Create Configuration Files**  
   Create a `config` directory and add the following files:
   ```bash
   mkdir config
   ```

   - `networks_config.yml`:
     ```yaml
     version: 2
     ethernets:
       eth0:
         dhcp4: false
         dhcp6: false
         addresses:
           - ${ip_address}
         gateway4: 172.20.3.1
         nameservers:
           addresses:
             - 8.8.8.8
     ```
     - Adjust `gateway4` to match your network.

   - `user_data.yml`:
     ```yaml
     #cloud-config
     hostname: ${hostname}
     fqdn: ${hostname}.${domain}
     prefer_fqdn_over_hostname: true
     ssh_pwauth: true
     disable_root: false
     chpasswd:
       list: |
         root:password-here
       expire: false

     users:
       - name: apps
         sudo: ALL=(ALL) NOPASSWD:ALL
         groups: users, admin
         home: /home/apps
         shell: /bin/bash
         lock_passwd: true
         ssh-authorized-keys:
           - ssh-rsa <your-id-rsa>
     ```
     - Replace `password-here` with a secure password and `<your-id-rsa>` with your public SSH key.

## Deploy OpenTofu

### Steps
1. **Initialize OpenTofu**  
   Download required plugins and initialize the project:
   ```bash
   tofu init
   ```
   Example output:
   ```
   Initializing the backend...

   Initializing provider plugins...
   - Reusing previous version of dmacvicar/libvirt from the dependency lock file
   - Reusing previous version of hashicorp/template from the dependency lock file
   - Using previously-installed hashicorp/template v2.2.0
   - Using previously-installed dmacvicar/libvirt v0.6.2
   ```

2. **Plan the Deployment**  
   Preview the changes OpenTofu will make:
   ```bash
   tofu plan
   ```

3. **Apply the Configuration**  
   Deploy the VMs:
   ```bash
   tofu apply
   ```
   - Confirm with `yes` when prompted. Wait for the process to complete (time depends on image size and system resources).

## Test the VMs
From the KVM host, test SSH connectivity to a VM:
```bash
ssh root@<your-ip-address>
```
- Replace `<your-ip-address>` with an IP from `ip_address_master` or `ip_address` (e.g., `172.20.3.89`).
- If SSH fails, ensure the VM is running (`virsh list --all`) and the network is configured correctly.

## References
- [https://computingforgeeks.com/how-to-install-terraform-on-linux/](https://computingforgeeks.com/how-to-install-terraform-on-linux/)
- [https://dev.to/ruanbekker/terraform-with-kvm-2d9e](https://dev.to/ruanbekker/terraform-with-kvm-2d9e)
- [https://computingforgeeks.com/how-to-provision-vms-on-kvm-with-terraform/](https://computingforgeeks.com/how-to-provision-vms-on-kvm-with-terraform/)w
- [https://github.com/Mosibi/centos8-terraform](https://github.com/Mosibi/centos8-terraform)
