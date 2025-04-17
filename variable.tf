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
