variable "connection_type" {
  default     = "ssh"
  description = "Connection type."
  type        = string
}

variable "connection_user" {
  description = "SSH user of the storage server."
  type        = string
}

variable "connection_host" {
  description = "Hostname of the storage server to connect to (likely to be the same as iscsi_host)."
  type        = string
}

variable "iscsi_host" {
  description = "Hostname or IP of the ISCSI server."
  type        = string
}

variable "iscsi_port" {
  default     = 3260
  description = "The ISCSI server port."
  type        = number
}

variable "proxmox_nodes" {
  description = "List of Proxmox host IPs in cluster."
  type        = list(any)
}

variable "iqn" {
  description = "IQN of ISCSI target."
  type        = string
}

variable "lvm_pool" {
  description = "Name of the LVM thin pool to contain the LVM volume."
  type        = string
}

variable "lvm_name" {
  description = "Name of the LVM volume to create."
  type        = string
}

variable "lvm_size" {
  description = "Size of the LVM volume. Must include the unit (i.e. 50G for a 50Gb volume)."
  type        = string
}

variable "vmid" {
  description = "ID of the VM."
  type        = number
}
