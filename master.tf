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
