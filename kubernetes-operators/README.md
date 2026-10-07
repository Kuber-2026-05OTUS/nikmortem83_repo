# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# ДЗ №7 "Создание собственного CRD"
# Морозов Н.Н.

## 💡 CustomResourceDeﬁnition
## CRD –это инструмент, который позволяет расширять API Kubernetes, добавляя собственные, пользовательские ресурсы.

## 💡 Operator - это под в Kubernetes-кластере, приложение которое по большому счету, следит за установкой и изменениями CRD. 
### Его сила в том, что он может взаимодействовать как с API кластера, так и с внешними ресурсами.

## ✨ создем ветку kubernetes-operators
### git branch --show-current

## Запускаем minikube
minikube start --driver=docker --nodes 2

## 📌 1. CRD — crd-mysql.yaml 
### CRD уровня namespace, группа otus.homework, kind MySQL, plural mysqls, версия v1. Четыре обязательных строковых поля с валидацией:
### image — docker-образ
### database — имя БД
### password — пароль
### storage_size — размер хранилища
## 2. RBAC — три файла
### ServiceAccount mysql-operator-sa 
### ClusterRole с полными правами (apiGroups: ["*"], resources: ["*"], verbs: ["*"]) 
### ClusterRoleBinding связывает SA и ClusterRole 
## 3. Deployment оператора использует образ roflmaoinmysoul/mysql-operator:1.0.0, привязан к созданному ServiceAccount.
## 4. Custom Resource MySQL валидный экземпляр CR: образ mysql:8.0, база otusdb, пароль SuperSecret123, хранилище 5Gi.

## Устанавливаем namespace
kubectl apply -f namespace.yaml 

## Запуск:
kubectl apply -f crd/crd-mysql.yaml
kubectl apply -f rbac/service-account.yaml
kubectl apply -f rbac/cluster-role-full.yaml
kubectl apply -f rbac/cluster-role-binding.yaml
kubectl apply -f deployment/operator-deployment.yaml
kubectl apply -f cr/mysql-cr.yaml

## Провреки:
### CRD создан
kubectl get crd mysqls.otus.homework
### оператор работает
kubectl get pods -l app=mysql-operator -n homework
### CR создан
kubectl get mysqls.otus.homework -n homework

## 📌 Задание со * — минимальный ClusterRole 
kubectl delete clusterrole mysql-operator-role
kubectl apply -f rbac/cluster-role-minimal.yaml
kubectl rollout restart deployment mysql-operator -n homework 

## 📌 Задание с ** — свой оператор на Python + фреймворк Kopf 
### 💡 Создание CR (@kopf.on.create):
### PersistentVolume — hostPath, размер из spec.storage_size
### PersistentVolumeClaim — привязан к PV
### Deployment — образ из spec.image, переменные MYSQL_ROOT_PASSWORD и MYSQL_DATABASE, том из PVC
### vService — ClusterIP, порт 3306

### 💡 Удаление CR (@kopf.on.delete):
### Service → 2. Deployment → 3. PVC → 4. PV (в обратном порядке)
### Каждый ресурс помечается labels: {app: mysql-<name>} — оператор находит свои ресурсы по имени, а не по лейблам, что надёжнее при удалении.

## Сборка собственного оператора
cd operator/
docker build -t mysql-operator:1.0.0 .
### docker images | grep mysql-operator

### добавляем образ в minikube
minikube image load mysql-operator:1.0.0

## Сборка собственного оператора в registry
minikube addons enable registry

### добавляем IP minikube в insecure-registries
MINIKUBE_IP=$(minikube ip)
echo "{\"insecure-registries\": [\"$MINIKUBE_IP:5000\"]}" | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

### сборка и добавление в registry
docker tag mysql-operator:1.0.0 $MINIKUBE_IP:5000/mysql-operator:1.0.0
docker push $MINIKUBE_IP:5000/mysql-operator:1.0.0

## Запуск собственного оператора
kubectl apply -f deployment/operator-deployment-custom.yaml



## Собираем образ внутри кластера
eval $(minikube docker-env)
# Собираем образ
docker build -t mysql-operator:1.0.0 .

## Остановка
kubectl delete -f crd/crd-mysql.yaml
kubectl delete -f rbac/service-account.yaml
kubectl delete -f rbac/cluster-role-full.yaml
kubectl delete -f rbac/cluster-role-binding.yaml
kubectl delete -f deployment/operator-deployment.yaml
kubectl delete -f cr/mysql-cr.yaml

## При kubectl delete -f cr/mysql-cr.yaml все созданные ресурсы (Deployment, Service, PV, PVC) удаляются.
 