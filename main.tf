locals {
  create_string  = "${var.iscsi_host} ${var.iscsi_port} ${var.iqn} ${var.lvm_pool} ${var.lvm_name} ${var.lvm_size}"
  destroy_string = "${var.iscsi_host} ${var.iscsi_port} ${var.iqn} ${var.lvm_pool} ${var.lvm_name}"
}

resource "null_resource" "cloudinit_iscsi_drive" {
  connection {
    type  = var.connection_type
    user  = var.connection_user
    host  = var.connection_host
    agent = true
  }

  provisioner "file" {
    content     = "#!/bin/bash\ndeclare -a proxmox_nodes=(${var.proxmox_node_ips})"
    destination = "/tmp/pve-nodes.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/pve-create-iscsi.tpl", {
      iscsi_host    = var.iscsi_host
      iscsi_port    = var.iscsi_port
      iqn           = var.iqn
      lvm_pool      = var.lvm_pool
      lvm_name      = var.lvm_name
      lvm_size      = var.lvm_size
      proxmox_nodes = var.proxmox_nodes
    })
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
    destroy_string  = local.destroy_string
    connection_type = var.connection_type
    connection_user = var.connection_user
    connection_host = var.connection_host
  }

  provisioner "file" {
    connection {
      type  = var.connection_type
      user  = var.connection_user
      host  = var.connection_host
      agent = true
    }
    content     = "#!/bin/bash\ndeclare -a proxmox_nodes=(${var.proxmox_node_ips})"
    destination = "/tmp/pve-nodes.sh"
  }

  provisioner "remote-exec" {
    connection {
      type  = self.triggers.connection_type
      user  = self.triggers.connection_user
      host  = self.triggers.connection_host
      agent = true
    }
    when = destroy
    inline = [
      "chmod +x /tmp/pve-create-iscsi.sh",
      "/tmp/pve-create-iscsi.sh destroy ${self.triggers.destroy_string}",
    ]
  }
}
