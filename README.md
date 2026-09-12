# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# ДЗ "Настройка сервисных аккаунтов и ограничение прав для них"
# Морозов Н.Н.

kubernetes-security/
├── Makefile
├── deploy.sh
├── manifests/
│   ├── namespace.yaml
│   ├── sa-monitoring.yaml
│   ├── sa-cd.yaml
│   ├── role-metrics-reader.yaml
│   ├── rolebinding-monitoring.yaml
│   ├── rolebinding-cd-admin.yaml
│   ├── storageclass.yaml
│   ├── pvc.yaml
│   ├── cm.yaml
│   ├── config.yaml
│   ├── service.yaml
│   ├── gatewayclass.yaml
│   ├── gateway.yaml
│   ├── httproute.yaml
│   ├── deployment.yaml
│   └── traefik-values.yaml
└── generated/
    ├── token
    └── kubeconfig-cd.yaml

# создем ветку kubernetes-security
# git branch --show-current

# Запускаем minikube, устанавливаем метки на ноды
 minikube start --driver=docker --nodes 3
 
 kubectl label nodes minikube homework=true
 kubectl label nodes minikube-m02 homework=true
 kubectl label nodes minikube-m03 homework=true

# kubectl get nodes --show-labels

# Запускаем тоннель для вызова сервиса с хостовой машины
minikube tunnel

# добавляем metrics-server
minikube addons enable metrics-server

# Устанавливаем namespace
kubectl apply -f namespace.yaml 

# Устанавливаем traefik
helm install traefik traefik/traefik \
  --namespace homework \
  --create-namespace \
  --values traefik-values.yaml
# kubectl get svc -n homework traefik
# kubectl exec -n homework deploy/traefik -- netstat -tuln | grep -E ':8000|:8443'

# Устанавливаем gateway-api CRD
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml -n homework
# kubectl get crd | grep gateway


# Добавляем имя хоста homework.otus для IP traefik
# Для того, чтобы обращаться к вашему сервису по хосту
# homework.otus его будет необходимо добавить в файл
# hosts либо на вашей хостовой машине, либо на виртуалке
# миникуба, в зависимости откуда вы будете пытаться
# выполнять запрос

# на хостовой  машине
TRAEFIK_IP=$(kubectl get svc -n homework traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sudo echo $TRAEFIK_IP homework.otus | sudo tee -a /etc/hosts

# на виртуалке миникуба
minikube ssh "sudo sh -c 'echo $TRAEFIK_IP homework.otus >> /etc/hosts'"

# cat /etc/hosts

# Запускаем сетевые настройки и деплой
kubectl apply -f manifests/sa-monitoring.yaml
kubectl apply -f manifests/sa-cd.yaml
kubectl apply -f manifests/role-metrics-reader.yaml
kubectl apply -f manifests/rolebinding-monitoring.yaml
kubectl apply -f manifests/rolebinding-cd-admin.yaml
kubectl apply -f manifests/storageclass.yaml
kubectl apply -f manifests/pvc.yaml
kubectl apply -f manifests/cm.yaml
kubectl apply -f manifests/config.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/gatewayclass.yaml
kubectl apply -f manifests/gateway.yaml
kubectl apply -f manifests/httproute.yaml
kubectl apply -f manifests/deployment.yaml

# Получаем токен
kubectl create token cd --namespace homework --duration=24h > generated/token

# Создаём kubeconfig
KUBECONFIG=generated/kubeconfig-cd.yaml kubectl config set-credentials cd --token=$(cat generated/token)
KUBECONFIG=generated/kubeconfig-cd.yaml kubectl config set-cluster kubernetes \
  --server=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}') \
  --insecure-skip-tls-verify=true
KUBECONFIG=generated/kubeconfig-cd.yaml kubectl config set-context homework-cd --cluster=kubernetes --namespace=homework --user=cd
KUBECONFIG=generated/kubeconfig-cd.yaml kubectl config use-context homework-cd

# Проверяем доступ к страницам
curl http://homework.otus/index.html
curl http://homework.otus/homepage

curl http://homework.otus/conf/file
cat /homework/conf/file

# удаление
kubectl delete -f deployment.yaml 
kubectl delete -f config.yaml
kubectl delete -f cm.yaml
kubectl delete -f pvc.yaml
kubectl delete -f storageclass.yaml
kubectl delete -f httproute.yaml
kubectl delete -f gateway.yaml
kubectl delete -f gatewayclass.yaml
kubectl delete -f service.yaml