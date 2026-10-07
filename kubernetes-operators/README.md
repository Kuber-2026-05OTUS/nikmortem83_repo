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
kubectl get pods -l app=mysql-operator
### CR создан
kubectl get mysqls.otus.homework
kubectl get deployment,svc,pvc -l app=mysql-mysql-instance
kubectl get pv pv-mysql-instance

## Собираем образ внутри кластера
eval $(minikube docker-env)


## Остановка
kubectl delete -f crd/crd-mysql.yaml
kubectl delete -f rbac/service-account.yaml
kubectl delete -f rbac/cluster-role-full.yaml
kubectl delete -f rbac/cluster-role-binding.yaml
kubectl delete -f deployment/operator-deployment.yaml
kubectl delete -f cr/mysql-cr.yaml

## При kubectl delete -f cr/mysql-cr.yaml все созданные ресурсы (Deployment, Service, PV, PVC) удаляются.
 