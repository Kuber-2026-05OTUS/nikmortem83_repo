# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# ДЗ "Настройка сервисных аккаунтов и ограничение прав для них"
# Морозов Н.Н.

# создем ветку kubernetes-networks
# git branch --show-current

# Запускаем minikube, устанавливаем метки на ноды
 minikube start --driver=docker --nodes 3
 
 kubectl label nodes minikube homework=true
 kubectl label nodes minikube-m02 homework=true
 kubectl label nodes minikube-m03 homework=true

# kubectl get nodes --show-labels

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

# Запускаем тоннель для вызова сервиса с хостовой машины
minikube tunnel

# Добавляем имя хоста homework.otus для IP traefik
# Для того, чтобы обращаться к вашему сервису по хосту
# homework.otus его будет необходимо добавить в файл
# hosts либо на вашей хостовой машине, либо на виртуалке
# миникуба, в зависимости откуда вы будете пытаться
# выполнять запрос

# на хостовой  машине
echo "10.98.61.47 homework.otus" | sudo tee -a /etc/hosts

# на виртуалке миникуба
minikube ssh
echo "10.98.61.47 homework.otus" | sudo tee -a /etc/hosts

# cat /etc/hosts

# Запускаем сетевые настройки и деплой
# сеть
kubectl apply -f service.yaml
kubectl apply -f gatewayclass.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
# диск
kubectl apply -f storageclass.yaml
kubectl apply -f pvc.yaml
# настройки
kubectl apply -f cm.yaml
kubectl apply -f config.yaml
# проект
kubectl apply -f deployment.yaml 

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