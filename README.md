# Multi-node K3s Deployment

This project automates the deployment of a vanilla **K3s Kubernetes cluster** with **Cilium** as the CNI across a dynamic number of worker nodes using **Terraform**.

## Project Structure

- **`multi-kubernetes/`**: Contains the core Terraform configuration.
  - `main.tf`: The primary orchestration logic.
  - `variables.tf`: Defined variables for IPs, users, and credentials.
  - `terraform.tfvars`: User-specific environment configuration.

## Key Features

1.  **Dynamic Workers**: Supports any number (`n`) of worker nodes simply by adding their IPs to the `worker_ips` list.
2.  **Automated State Management**: Automatically fetches the `node-token` and `kubeconfig.yaml` from the master and updates connection details.
3.  **Advanced Networking**: Installs **Cilium** as the CNI by default, replacing `kube-proxy`.

## How to Run

1.  Navigate to the `multi-kubernetes` directory.
2.  Fill in your node details in `terraform.tfvars`.
3.  Run `terraform init` and `terraform apply`.