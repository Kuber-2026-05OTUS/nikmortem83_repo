# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# ДЗ №8 "Мониторинг приложения в кластере"
# Морозов Н.Н.

## 💡 Prometheus operator
### Способ установки prometheus в кластер Kubernetes в виде operator и набора CRD. Позволяет конфигурировать сбор
### метрик с объектов кластера создавая и настраивая custom объекты k8s

## 💡 Exporter
### Приложения, обеспечивающие сбор метрик с какого-либо объекта и отдачу их в Prometheus формате. Существуют
### различные экспортеры под популярные программные продукты (например nginx, kafka, haproxy и т.д) и различные
### языки и фреймворки для разработки приложений.
### В задании мы будем использовать экспортер для nginx, который будет собирать метрики с веб-сервера и
### преобразовывать их в Prometheus формат

## 📌 Задание:
### ● Необходимо создать кастомный образ nginx, отдающий свои 
### метрики на определенном endpoint ( пример из офф документации в разделе ссылок)
### ● Установить в кластер Prometheus-operator любым удобным вам
### способом (рекомендуется ставить или по ссылке из офф документации, либо через helm-чарт)
### ● Создать deployment запускающий ваш кастомный nginx образ и service для него
### ● Настроить запуск nginx prometheus exporter (отдельным подом или
### в составе пода с nginx – не принципиально) и сконфигурировать его для сбора метрик с nginx
### ● Создать манифест serviceMonitor, описывающий сбор метрик с подов, которые вы создали

## ✨ создем ветку kubernetes-monitoring
### git branch --show-current

## Запускаем minikube
minikube start --driver=docker

## Устанавливаем namespace
kubectl apply -f namespace.yaml 

## Установка Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack --namespace homework

helm install prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace homework \
  --create-namespace

## Access Grafana local instance:
  export POD_NAME=$(kubectl --namespace homework get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname)
  kubectl --namespace homework port-forward $POD_NAME 3000

## Get your grafana admin user password by running:
  kubectl get secret --namespace homework -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo
### http://localhost:3000  Login=admin  Password=TCqsRbJiySBd3zPL7a9hdcaKH8IG6tJZlfxak0N9

## Сборка и загрузка образа в minikube
cd nginx-image
docker build -t nginx-custom:1.0.0 .
minikube image load nginx-custom:1.0.0

## Запуск:
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f service-monitor.yaml

## Провреки:
### Проверка stub_status изнутри пода
POD=$(kubectl get pods -n homework -l app=nginx-with-metrics -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $POD -n homework -c nginx -- curl -s http://127.0.0.1/stub_status

http://localhost:3000
http://localhost:9090/targets
### Запрос метрик в UI Prometheus:
### •	nginx_up — должен вернуть 1 (экспортер жив).
### •	nginx_connections_active — активные соединения.
### •	nginx_http_requests_total — общее число запросов.

## Остановка и очистка
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml
kubectl delete -f service-monitor.yaml
