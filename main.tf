resource "null_resource" "cloudinit_iscsi_drive" {
  connection {
    type     = var.connection_type
    user     = var.connection_user
    password = var.connection_password
    host     = var.connection_host
  }

  provisioner "file" {
    source      = "files/pve-create-iscsi.sh"
    destination = "/tmp/pve-create-iscsi.sh"
  }

  provisioner "file" {
    content     = "#!/bin/bash\ndeclare -a proxmox_nodes=(${var.proxmox_node_ips})"
    destination = "/tmp/pve-nodes.sh"
  }

  provisioner "remote-exec" {
    ignore_changes = [
      all,
    ]
    inline = [
      "chmod +x /tmp/pve-create-iscsi.sh",
      "/tmp/pve-create-iscsi.sh create ${var.iscsi_host} ${var.iscsi_port} ${var.iqn} ${var.lvm_pool} ${var.lvm_name} ${var.lvm_size}",
      "rm /tmp/pve-create-iscsi.sh",
    ]
  }

  provisioner "remote-exec" {
    when   = destroy
    inline = [
      "chmod +x /tmp/pve-create-iscsi.sh",
      "/tmp/pve-create-iscsi.sh destroy ${var.iscsi_host} ${var.iscsi_port} ${var.iqn} ${var.lvm_pool} ${var.lvm_name},
    ]
  }
}
