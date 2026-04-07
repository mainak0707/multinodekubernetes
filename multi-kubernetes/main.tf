terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
  }
}

# 1. Install K3s Control Plane on Node 1 (Native containerd, Flannel disabled)
resource "null_resource" "k3s_master" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    host        = var.master_ip
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io > install.sh",
      "chmod +x install.sh",
      # Install as server, disable default CNI (Flannel) so we can use Cilium
      "echo '${var.sudo_pass}' | sudo -S ./install.sh server --flannel-backend=none --disable-network-policy --write-kubeconfig-mode 644",
      "sleep 15" # Allow the API server to spin up
    ]
  }
}

# 2. Extract the Node Token and Kubeconfig to your Terraform VM
resource "null_resource" "fetch_k3s_data" {
  depends_on = [null_resource.k3s_master]

  provisioner "local-exec" {
    command = <<EOT
      # Fetch the secure join token
      ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key} ${var.ssh_user}@${var.master_ip} "echo '${var.sudo_pass}' | sudo -S cat /var/lib/rancher/k3s/server/node-token" > ./node-token
      # Fetch the cluster connection file
      ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key} ${var.ssh_user}@${var.master_ip} "cat /etc/rancher/k3s/k3s.yaml" > ./kubeconfig.yaml
      # Point the kubeconfig to the remote master IP instead of localhost
      sed -i 's/127.0.0.1/${var.master_ip}/g' ./kubeconfig.yaml
    EOT
  }
}

data "local_file" "node_token" {
  depends_on = [null_resource.fetch_k3s_data]
  filename   = "${path.module}/node-token"
}

# 3. Join the Worker Nodes
resource "null_resource" "k3s_workers" {
  depends_on = [data.local_file.node_token]
  count      = length(var.worker_ips)

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    # Dynamically select the IPs for worker nodes
    host        = element(var.worker_ips, count.index)
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io > install.sh",
      "chmod +x install.sh",
      # Join the cluster as an agent using the master's IP and the fetched token
      "echo '${var.sudo_pass}' | sudo -S K3S_URL=https://${var.master_ip}:6443 K3S_TOKEN=${trimspace(data.local_file.node_token.content)} ./install.sh agent"
    ]
  }
}

# 4. Configure Helm Provider
provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig.yaml"
  }
}

# 5. Install Cilium via Helm
resource "helm_release" "cilium" {
  depends_on = [null_resource.k3s_workers]
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = "1.15.1"

  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }
  set {
    name  = "k8sServiceHost"
    value = var.master_ip
  }
  set {
    name  = "k8sServicePort"
    value = "6443"
  }
}
