locals {
  script_path      = "/usr/local/bin"
  script_name_stub = "pve-create-iscsi"
}

resource "null_resource" "cloudinit_iscsi_drive_create" {
  connection {
    type  = var.connection_type
    user  = var.connection_user
    host  = var.connection_host
    agent = true
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
    destination = "${local.script_path}/${local.script_name_stub}-${var.vmid}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.script_path}/${local.script_name_stub}-${var.vmid}.sh",
      "${local.script_path}/${local.script_name_stub}-${var.vmid}.sh create",
    ]
  }
}

resource "null_resource" "cloudinit_iscsi_drive_destroy_only" {
  # dirty hack to work around destroy-time provisioners being
  # unable to access variables easily.
  triggers = {
    connection_type  = var.connection_type
    connection_user  = var.connection_user
    connection_host  = var.connection_host
    script_path      = local.script_path
    script_name_stub = local.script_name_stub
    vmid             = var.vmid
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
      "${self.triggers.script_path}/${self.triggers.script_name_stub}-${self.triggers.vmid}.sh destroy",
      "rm -f ${self.triggers.script_path}/${self.triggers.script_name_stub}-${self.triggers.vmid}.sh",
    ]
  }
}
