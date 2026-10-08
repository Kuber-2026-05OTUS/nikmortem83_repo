# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# Морозов Н.Н.

# ✨ Kubernetes-2026-05
## ├── kubernetes-controllers
### │   ├── config.yaml
### │   ├── deployment.yaml
### │   ├── namespace.yaml
### │   ├── README.md
### │   └── service.yaml
## ├── kubernetes-intro
### │   ├── config.yaml
### │   ├── namespace.yaml
### │   ├── pod.yaml
### │   ├── README.md
### │   └── service.yaml
## ├── kubernetes-networks
### │   ├── config.yaml
### │   ├── deployment.yaml
### │   ├── gatewayclass.yaml
### │   ├── gateway.yaml
### │   ├── httproute.yaml
### │   ├── LICENSE
### │   ├── namespace.yaml
### │   ├── pod.yaml
### │   ├── README.md
### │   ├── service.yaml
### │   └── traefik-values.yaml
## ├── kubernetes-operators 📌
### │   ├── cr
### │   │   └── mysql-cr.yaml
### │   ├── crd
### │   │   └── crd-mysql.yaml
### │   ├── deployment
### │   │   └── operator-deployment.yaml
### │   ├── namespace.yaml
### │   ├── operator
### │   │   ├── app
### │   │   ├── Dockerfile
### │   │   ├── main.py
### │   │   └── operator-deployment-custom.yaml
### │   ├── rbac
### │   │   ├── cluster-role-binding.yaml
### │   │   ├── cluster-role-full.yaml
### │   │   ├── cluster-role-minimal.yaml
### │   │   ├── operator-clusterrolebinding.yaml
### │   │   ├── operator-clusterrole.yaml
### │   │   └── service-account.yaml
### │   └── README.md
## ├── kubernetes-security
### │   ├── deploy.sh
### │   ├── generated
### │   │   ├── kubeconfig-cd.yaml
### │   │   └── token
### │   ├── Makefile
### │   ├── manifests
### │   │   ├── cm.yaml
### │   │   ├── config.yaml
### │   │   ├── deployment.yaml
### │   │   ├── gatewayclass.yaml
### │   │   ├── gateway.yaml
### │   │   ├── httproute.yaml
### │   │   ├── namespace.yaml
### │   │   ├── pvc.yaml
### │   │   ├── rolebinding-cd-admin.yaml
### │   │   ├── rolebinding-monitoring.yaml
### │   │   ├── role-metrics-reader.yaml
### │   │   ├── sa-cd.yaml
### │   │   ├── sa-monitoring.yaml
### │   │   ├── secret-cd-token.yaml
### │   │   ├── service.yaml
### │   │   ├── storageclass.yaml
### │   │   └── traefik-values.yaml
### │   └── README.md
## ├── kubernetes-templating
### │   ├── helmfile.yaml
### │   ├── homework-app
### │   │   ├── Chart.lock
### │   │   ├── charts
### │   │   │   ├── metrics-server-3.14.0.tgz
### │   │   │   ├── redis-20.13.4.tgz
### │   │   │   └── traefik-39.0.9.tgz
### │   │   ├── Chart.yaml
### │   │   ├── crds
### │   │   │   └── gateway-api.yaml
### │   │   ├── templates
### │   │   │   ├── configmap-app.yaml
### │   │   │   ├── configmap-nginx.yaml
### │   │   │   ├── deployment.yaml
### │   │   │   ├── gateway.yaml
### │   │   │   ├── _helpers.tpl
### │   │   │   ├── httproute.yaml
### │   │   │   ├── NOTES.txt
### │   │   │   ├── pvc.yaml
### │   │   │   ├── rbac.yaml
### │   │   │   ├── serviceaccount.yaml
### │   │   │   ├── service.yaml
### │   │   │   ├── storageclass.yaml
### │   │   │   └── tests
### │   │   │       └── test-connection.yaml
### │   │   └── values.yaml
### │   └── README.md
## ├── kubernetes-volumes
### │   ├── cm.yaml
### │   ├── config.yaml
### │   ├── deployment.yaml
### │   ├── gatewayclass.yaml
### │   ├── gateway.yaml
### │   ├── httproute.yaml
### │   ├── namespace.yaml
### │   ├── pod.yaml
### │   ├── pvc.yaml
### │   ├── README.md
### │   ├── service.yaml
### │   ├── storageclass.yaml
### │   └── traefik-values.yaml
## ├── LICENSE
## └── README.md
