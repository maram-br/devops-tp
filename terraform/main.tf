# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  Terraform — Provisionnement Infrastructure K8s (local via Kind)        ║
# ║  Adaptable : remplacer le provider "kind" par "aws", "google", "azurerm"║
# ╚══════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  # Backend distant (décommenter en production)
  # backend "s3" {
  #   bucket = "mon-bucket-tfstate"
  #   key    = "devops-tp/terraform.tfstate"
  #   region = "eu-west-3"
  # }
}

# ── Variables ──────────────────────────────────────────────────────────────
variable "cluster_name" {
  description = "Nom du cluster Kubernetes"
  type        = string
  default     = "devops-tp-cluster"
}

variable "image_tag" {
  description = "Tag de l'image Docker à déployer"
  type        = string
}

variable "k8s_namespace" {
  description = "Namespace Kubernetes cible"
  type        = string
  default     = "devops-tp"
}

# ── Provider : Kind (cluster K8s local) ───────────────────────────────────
provider "kind" {}

resource "kind_cluster" "main" {
  name = var.cluster_name

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      # Expose les ports pour l'Ingress
      extra_port_mappings {
        container_port = 80
        host_port      = 8080
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"
    }
  }
}

# ── Provider Kubernetes (pointe vers le cluster créé) ─────────────────────
provider "kubernetes" {
  host                   = kind_cluster.main.endpoint
  client_certificate     = kind_cluster.main.client_certificate
  client_key             = kind_cluster.main.client_key
  cluster_ca_certificate = kind_cluster.main.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.main.endpoint
    client_certificate     = kind_cluster.main.client_certificate
    client_key             = kind_cluster.main.client_key
    cluster_ca_certificate = kind_cluster.main.cluster_ca_certificate
  }
}

# ── Namespace applicatif ───────────────────────────────────────────────────
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.k8s_namespace
    labels = {
      managed-by = "terraform"
      env        = terraform.workspace
    }
  }

  depends_on = [kind_cluster.main]
}

# ── Namespace monitoring ───────────────────────────────────────────────────
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      managed-by = "terraform"
    }
  }

  depends_on = [kind_cluster.main]
}

# ── Outputs ────────────────────────────────────────────────────────────────
output "cluster_name" {
  value = kind_cluster.main.name
}

output "kubeconfig_path" {
  value     = kind_cluster.main.kubeconfig_path
  sensitive = true
}

output "app_namespace" {
  value = kubernetes_namespace.app.metadata[0].name
}
