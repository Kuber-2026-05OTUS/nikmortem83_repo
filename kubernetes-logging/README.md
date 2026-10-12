# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# ДЗ №9 "Сервисы централизованного логирования для Kubernetes
# Морозов Н.Н.

## 💡 Loki
### Решение для сбора, индексации, хранения и предоставления доступа к логам. Основной фишкой является подход индексации только метаданных логов, а сами логи хранятся в виде сжатых чанков. Система хранения и индексации логов.

## 💡 Promtail
### Агент, устанавливаемый на ноды кластера, где выполняются приложения и службы, с которых необходимо собирать логи. Отвечает за сбор логов, их препроцессинг и отправку их в loki. Агент сбора логов.

## 💡 Grafana
### Платформа для визуализации и анализа данных, ориентированная на работу с системами мониторинга и логирования. Визуализация и дашборды.

## 📌 Задание:
### ● Данное задание будет выполняться в managed k8s в Yandex cloud
### ● Разверните managed Kubernetes cluster в Yandex cloud любым удобным вам способом
### ● Для кластера создайте 2 пула нод:
### ● Для рабочей нагрузки (можно 1 ноду)
### ● Для инфраструктурных сервисов (также хватит пока и 1 ноды)
### ● Для инфраструктурной ноды/нод добавьте taint, запрещающий на нее планирование подов с посторонней нагрузкой - node-role=infra:NoSchedule
### ● Приложите к ДЗ вывод комманд kubectl get node -o wide --show-labels и kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints показывающий конфигурацию нод в вашем кластере
### ● Создайте бакет в s3 object storage Yandex cloud. В нем будут храниться логи, собираемые loki. Также необходимо будет создать ServiceAccount для доступа к бакету и сгенерировать ключи доступа согласно инструкции YC
### ● Установите в кластер Loki 
### ● монолитный или распределенный режим не принципиально
### ● Необходимо сконфигурировать параметры установки так, чтобы компоненты loki устанавливались исключительно на infra-ноды (добавить соответствующий toleration для обхода taint, а также nodeSelector или nodeAffinity на ваш выбор, для планирования подов только на заданные ноды)
### ● Место хранения логов – s3 бакет, ранее сконфигурированный вами
### ● Auth_enabled: false
### ● Установите в кластер promtail
### ● Агенты promtail должны быть развернуты на всех нодах кластера, включая infra-ноды (добавить toleration) 
### ● Установите в кластер Grafana
### ● Должна быть установлена на infra-ноды (toleration и nodeSelector/NodeAffinity)
### ● Для установленных loki, promtail и Grafana приложить к ДЗ файлы values.yaml, которые вы использовали для установки, а также команду установки и репозиторий, из которого ставили, если требуется. Не обязательно устанавливать все 3 компонента из разных чартов, приложите именно тот способ установки, который вы использовали.
### ● В Grafana необходимо настроить data source к loki и сделать explore по этому datasource и убедиться, что логи отображаются. Приложить скриншот этого экрана из Grafana
### ● Если будете ставить loki из чарта, который предлагает Yandex (там достаточно старый loki) – последние версии графаны могут не заработать с ним, необходимо будет явно установить какую-то из старых версий (например 8.5.28)

## ✨ создем ветку kubernetes-logging
### git branch --show-current

## Запускаем minikube
minikube start --driver=docker --nodes=3 --memory=2048 --cpus=2

## Добавляем taint
### kubectl get nodes

### определяем infra-ноду - minikube-m02
NODE_NAME="minikube-m02"
kubectl taint node "$NODE_NAME" node-role=infra:NoSchedule

kubectl label node minikube-m02 node-role=infra

### определяем infra-ноду - minikube-m03
NODE_NAME="minikube-m03"
kubectl taint node "$NODE_NAME" node-role=infra:NoSchedule

kubectl label node minikube-m03 node-role=infra

## Устанавливаем namespace
kubectl apply -f namespace.yaml 

## Установка Loki
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update

helm install \
    loki grafana-community/loki  \
    --create-namespace \
    --namespace homework \
    --values minikube/loki-values.yaml

## Установка Grafana
helm install \
    grafana grafana-community/grafana \
    --namespace homework \
    --values minikube/grafana-values.yaml

## Поднимаем лимит fs.inotify.max_user_instances перед установкой promtail:
minikube ssh "sudo sysctl -w fs.inotify.max_user_instances=1024"

## Установка Promtail
helm repo add grafana-legacy https://grafana.github.io/helm-charts
helm repo update

helm install \
    promtail grafana-legacy/promtail \
    --namespace homework \
    --values minikube/promtail-values.yaml

## Провреки:
### проверкаа конфигурации нод
kubectl get node -o wide --show-labels
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
### NAME           TAINTS
### minikube       <none>
### minikube-m02   [map[effect:NoSchedule key:node-role value:infra]]
### minikube-m03   [map[effect:NoSchedule key:node-role value:infra]]

### проверка Loki
kubectl get pods -w --namespace homework

kubectl port-forward --namespace homework svc/loki-gateway 3100:80 
#### http://127.0.0.1:3100/loki/api/v1/push
curl "http://127.0.0.1:3100/loki/api/v1/query_range" --data-urlencode 'query={job="test"}' | jq .data.result
% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  3764    0  3736  100    28  21642    162 --:--:-- --:--:-- --:--:-- 21883
[
  {
    "stream": {
      "detected_level": "unknown",
      "job": "test",
      "service_name": "test"
    },
    "values": [
      [
        "1791823947000000000",
        "fizzbuzz"
      ]
    ]
  }
]

### проверка Grafana
kubectl get secret --namespace homework grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
export NODE_PORT=$(kubectl get --namespace homework -o jsonpath="{.spec.ports[0].nodePort}" services grafana)
export NODE_IP=$(kubectl get nodes --namespace homework -o jsonpath="{.items[0].status.addresses[0].address}")
echo http://$NODE_IP:$NODE_PORT
### переходим на страницу графана http://192.168.49.2:30300

### проверка Promtail
kubectl --namespace homework port-forward daemonset/promtail 3101
curl http://127.0.0.1:3101/metrics

## Остановка и очистка
helm uninstall \
    loki grafana-community/loki  \
    --namespace homework

helm uninstall \
    grafana grafana-community/grafana \
    --namespace homework

helm install \
    promtail grafana-legacy/promtail \
    --namespace homework 

kubectl delete ns homework --grace-period=0 --force
