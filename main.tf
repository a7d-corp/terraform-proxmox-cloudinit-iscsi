locals {
  create_string  = "${var.iscsi_host} ${var.iscsi_port} ${var.iqn} ${var.lvm_pool} ${var.lvm_name} ${var.lvm_size}"
  destroy_string = "${var.iscsi_host} ${var.iscsi_port} ${var.iqn} ${var.lvm_pool} ${var.lvm_name}"
}

resource "null_resource" "cloudinit_iscsi_drive" {
  connection {
    type     = var.connection_type
    user     = var.connection_user
    password = var.connection_password
    host     = var.connection_host
  }

  provisioner "file" {
    content     = "#!/bin/bash\ndeclare -a proxmox_nodes=(${var.proxmox_node_ips})"
    destination = "/tmp/pve-nodes.sh"
  }

  provisioner "file" {
    source      = "${path.module}/files/pve-create-iscsi.sh"
    destination = "/tmp/pve-create-iscsi.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/pve-create-iscsi.sh",
      "/tmp/pve-create-iscsi.sh create ${local.create_string}",
    ]
  }
}

resource "null_resource" "cloudinit_iscsi_drive_destroy_only" {
  # dirty hack to work around destroy-time provisioners being
  # unable to access variables easily.
  triggers = {
    destroy_string      = local.destroy_string
    connection_type     = var.connection_type
    connection_user     = var.connection_user
    connection_password = var.connection_password
    connection_host     = var.connection_host
  }

  provisioner "file" {
    connection {
      type     = var.connection_type
      user     = var.connection_user
      password = var.connection_password
      host     = var.connection_host
    }
    content     = "#!/bin/bash\ndeclare -a proxmox_nodes=(${var.proxmox_node_ips})"
    destination = "/tmp/pve-nodes.sh"
  }

  provisioner "remote-exec" {
    connection {
      type     = self.triggers.connection_type
      user     = self.triggers.connection_user
      password = self.triggers.connection_password
      host     = self.triggers.connection_host
    }
    when = destroy
    inline = [
      "chmod +x /tmp/pve-create-iscsi.sh",
      "/tmp/pve-create-iscsi.sh destroy ${self.triggers.destroy_string}",
    ]
  }
}
