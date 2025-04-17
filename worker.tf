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
