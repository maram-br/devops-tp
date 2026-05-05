# 🏭 Usine Logicielle DevOps — TP Complet

> Pipeline CI/CD complet : Jenkins → SonarQube → Docker → Trivy → Kubernetes → Prometheus/Grafana

---

## 📁 Structure du projet

```
devops-tp/
├── app/
│   ├── app.py               # Application Flask (+ métriques Prometheus)
│   ├── test_app.py          # Tests unitaires pytest
│   └── requirements.txt     # Dépendances Python
├── Dockerfile               # Build multi-stage optimisé
├── sonar-project.properties # Config SonarQube Scanner
├── Jenkinsfile              # Pipeline CI/CD complet (Ex 1→3)
├── terraform/
│   └── main.tf              # Provisionnement cluster K8s (Kind)
├── ansible/
│   ├── inventory.ini
│   └── playbook-deploy.yml  # Configuration + déploiement K8s
├── k8s-manifests/
│   └── deployment.yaml      # Manifests K8s (Deployment, Service, Ingress)
└── monitoring/
    ├── helm-values.yaml     # Config kube-prometheus-stack (Exercice 4)
    └── grafana-dashboard.yaml # Dashboard + ServiceMonitor
```

---

## 🛠️ Prérequis

| Outil | Version min | Installation |
|-------|-------------|-------------|
| Jenkins | 2.440+ | https://www.jenkins.io/doc/book/installing/ |
| Docker | 24+ | https://docs.docker.com/engine/install/ |
| kubectl | 1.29+ | https://kubernetes.io/docs/tasks/tools/ |
| Terraform | 1.6+ | https://developer.hashicorp.com/terraform/install |
| Ansible | 2.15+ | `pip install ansible kubernetes` |
| Helm | 3.14+ | https://helm.sh/docs/intro/install/ |
| Kind | 0.22+ | https://kind.sigs.k8s.io/docs/user/quick-start/ |
| Trivy | 0.50+ | https://aquasecurity.github.io/trivy/latest/getting-started/installation/ |
| SonarQube | 10+ | Docker : `docker run -p 9000:9000 sonarqube:community` |

---

## 🚀 Mise en place pas à pas

### 1. Jenkins — Plugins requis

```
Manage Jenkins → Plugins → Installer :
- SonarQube Scanner
- Docker Pipeline
- Kubernetes CLI
- AnsiColor
- HTML Publisher
- Pipeline: Stage View
```

### 2. Jenkins — Credentials à créer

```
Manage Jenkins → Credentials → System → Global credentials :

ID: dockerhub-credentials  → Username/Password (Docker Hub)
ID: sonarqube-token        → Secret text (token SonarQube)
ID: kubeconfig-k8s         → Secret file (kubeconfig du cluster)
```

### 3. Jenkins — Configurer SonarQube

```
Manage Jenkins → Configure System → SonarQube servers :
  Name: SonarQubeServer
  URL: http://localhost:9000
  Token: (sélectionner sonarqube-token)
```

### 4. Lancer SonarQube (Docker)

```bash
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  sonarqube:community

# Accès : http://localhost:9000
# Login par défaut : admin / admin
# Créer un projet "flask-devops-app" et générer un token
```

### 5. Provisionner l'infrastructure (Terraform)

```bash
cd terraform
terraform init
terraform plan -var="image_tag=latest"
terraform apply -var="image_tag=latest"
```

### 6. Déploiement manuel (sans Jenkins)

```bash
# Via Ansible
ansible-playbook ansible/playbook-deploy.yml \
  -e image_tag=1 \
  -e image_name=votre-user/flask-devops-app \
  -e k8s_namespace=devops-tp

# Ou directement via kubectl
kubectl apply -f k8s-manifests/deployment.yaml
```

### 7. Installer la stack Monitoring (Exercice 4)

```bash
# Ajout du repo Helm
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

# Installation
kubectl create namespace monitoring
helm install kube-prom-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/helm-values.yaml

# Dashboard Grafana
kubectl apply -f monitoring/grafana-dashboard.yaml

# Accès Grafana (port-forward)
kubectl port-forward svc/kube-prom-stack-grafana 3000:80 -n monitoring
# http://localhost:3000  →  admin / DevOps-TP-2024!
```

---

## 🔁 Workflow du pipeline Jenkins

```
[Git Push]
    │
    ▼
[1] Checkout ──────────────────────────── récupère le code
    │
[2] Install Dependencies ─────────────── pip install
    │
[3] Unit Tests ───────────────────────── pytest + coverage
    │
[4] SonarQube Analysis ───────────────── analyse statique
    │
[5] Quality Gate ─────────────────────── ❌ arrêt si KO
    │
[6] Docker Build ─────────────────────── image multi-stage
    │
[7] Trivy Scan ───────────────────────── ❌ arrêt si CRITICAL
    │
[8] Docker Push ──────────────────────── push DockerHub
    │
[9] Terraform Plan/Apply ─────────────── provisionne K8s
    │
[10] Ansible Deploy ──────────────────── configure + déploie
    │
[11] Smoke Test ──────────────────────── curl /health → 200
    │
    ▼
  ✅ Application en ligne !
```

---

## 📊 Métriques exposées par l'application

| Métrique | Type | Description |
|----------|------|-------------|
| `app_request_count_total` | Counter | Nombre total de requêtes par endpoint |
| `app_request_latency_seconds` | Histogram | Latence des requêtes |

---

## 📋 Livrables du TP

- [x] **Code source** : `app/app.py` + tests
- [x] **Dockerfile** : build multi-stage sécurisé
- [x] **Jenkinsfile** : pipeline complet Exercice 1→3
- [x] **Terraform** : provisionnement cluster K8s
- [x] **Ansible** : playbook de déploiement
- [x] **Manifests K8s** : Deployment + Service + Ingress
- [x] **Stack Monitoring** : Helm values + Dashboard Grafana + AlertManager

---

## 🔧 Commandes utiles

```bash
# Vérifier les pods
kubectl get pods -n devops-tp -w

# Logs de l'app
kubectl logs -f -l app=flask-devops-app -n devops-tp

# Vérifier les alertes
kubectl port-forward svc/kube-prom-stack-alertmanager 9093:9093 -n monitoring

# Accès Prometheus
kubectl port-forward svc/kube-prom-stack-kube-prome-prometheus 9090:9090 -n monitoring
```
