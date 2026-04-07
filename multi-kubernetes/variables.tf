variable "sudo_pass" {
  description = "The sudo password for the remote user"
  type        = string
  sensitive   = true
}

variable "ssh_user" {
  description = "The username for SSH connection"
  type        = string
  default     = "amdocs"
}

variable "master_ip" {
  description = "The IP address of the master node"
  type        = string
}

variable "worker_ips" {
  description = "A list of IP addresses for the worker nodes"
  type        = list(string)
}

variable "ssh_private_key" {
  description = "Path to the SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}
