variable "kubeconfig_path" {
  description = "Path to kubeconfig that points at the k3s cluster (reachable via WARP/Cloudflare tunnel)"
  type        = string
  default     = "~/.kube/k3s-lk-personal"
}

variable "kubeconfig_context" {
  description = "Context to use within kubeconfig"
  type        = string
  default     = "default"
}
