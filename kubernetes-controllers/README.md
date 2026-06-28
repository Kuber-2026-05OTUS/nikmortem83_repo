# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# ДЗ "Kubernetes controllers. ReplicaSet, Deployment, DaemonSet"
# "Управление жизненным циклом и взаимодействием pod в Kubernetes"
# Морозов Н.Н.

# minikube start --driver=docker --nodes 3
# kubectl label nodes minikube homework=false
# kubectl label nodes minikube-m02 homework=true
# kubectl label nodes minikube-m03 homework=false
# kubectl get nodes --show-labels

# kubectl apply -f namespace.yaml 
# kubectl apply -f config.yaml
# kubectl apply -f service.yaml 
# kubectl apply -f deployment.yaml 
# minikube service homework-service --url -n homework


