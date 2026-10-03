# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# ДЗ "Шаблонизация манифестов приложения, использование Helm. Установка community Helm charts"
# Морозов Н.Н.

# создем ветку kubernetes-templating
# git branch --show-current

# Запускаем minikube, устанавливаем метки на ноды
 minikube start --driver=docker --nodes 3
 
 kubectl label nodes minikube homework=true
 kubectl label nodes minikube-m02 homework=true
 kubectl label nodes minikube-m03 homework=true

# kubectl get nodes --show-labels

# Запускаем тоннель для вызова сервиса с хостовой машины
minikube tunnel

# Создаем чарт homework-app
helm create homework-app ./homework-app

# Установка CRD Gateway API в папку чарта (удаляем ValidatingAdmissionPolicy и ValidatingAdmissionPolicyBinding)
mkdir -p homework-app/crds
curl -L -o homework-app/crds/gateway-api.yaml \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml

### Формируем Helm-чарт homework-app в соответствии с заданием № 1
# Chart.yaml — зависимости: Redis из Bitnami community-чарта (condition: redis.enabled), можно включить/выключить через values
# values.yaml — ключевые параметры: имена объектов, имена контейнеров, образы (поля repository и tag раздельно), порты, хосты, количество реплик, проб
# _helpers.tpl — хелперы: homework-app.name, homework-app.fullname, homework-app.labels, homework-app.selectorLabels (стандартные лейблы app.kubernetes.io/*)
# deployment.yaml — образы через "{{ .Values.images.nginx.repository }}:{{ .Values.images.nginx.tag }}", пробы обёрнуты в {{- if .Values.probes.enabled }} / {{- if and .Values.probes.enabled .Values.probes.liveness.enabled }}
# NOTES.txt — после установки показывает адреса http://localhost:8000 и все эндпоинты, инструкцию по /etc/hosts, а также адрес Redis-зависимости
# Добавить репозиторий и подтянуть зависимость Redis

helm repo update
helm dependency update homework-app

# Helm-чарт homework-app - запуск
helm install homework-app ./homework-app \
  --namespace homework \
  --create-namespace \
  --set global.security.allowInsecureImages=true

# Helm-чарт homework-app - запуск с предварительной установкой CRDs traefik
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
helm install homework-app ./homework-app \
  --namespace homework \
  --create-namespace \
  --set global.security.allowInsecureImages=true \
  --skip-crds

# на хостовой машине при установке через helm
TRAEFIK_IP=$(kubectl get svc -n homework homework-app-traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sudo env TRAEFIK_IP="$TRAEFIK_IP" sh -c 'grep -v homework\.otus /etc/hosts > /tmp/hosts && echo "$TRAEFIK_IP homework.otus" >> /tmp/hosts && cp /tmp/hosts /etc/hosts'

# на виртуалке миникуба
minikube ssh "sudo sh -c 'grep -v homework\\.otus /etc/hosts > /tmp/hosts && echo $TRAEFIK_IP homework.otus >> /tmp/hosts && sudo cp /tmp/hosts /etc/hosts'"

# Перезапуск deploy
kubectl rollout restart deploy homework-app -n homework
deployment.apps/homework-app restarted

# Установка и перезапуск с переопределением параметров
helm install homework-app helm/homework-app \
  --set replicas=5 \
  --set images.nginx.tag=1.25 \
  --set probes.enabled=false \
  --set redis.enabled=false

helm upgrade homework-app ./homework-app \
  --namespace homework \
  --set global.security.allowInsecureImages=true \
  --set replicas=5 \
  --set images.nginx.tag=1.25 \
  --set probes.enabled=false \
  --set redis.enabled=false

# Проверяем доступ к страницам
curl http://homework.otus/index.html
curl http://homework.otus/homepage

curl http://homework.otus/conf/file
curl http://homework.otus/metrics.html

# Проверяем Radis
kubectl exec -it homework-app-redis-master-0 -n homework -- redis-cli ping
# PONG

kubectl exec -it homework-app-redis-master-0 -n homework -- sh -c "redis-cli set test-key hello-from-k8s && redis-cli get test-key"

# Удаление через Helm (для чарта homework-app и зависимостей)
helm uninstall homework-app --namespace homework

# CRD и PVC останутся — удаляем вручную при необходимости
kubectl delete crd gatewayclasses.gateway.networking.k8s.io
kubectl delete crd gateways.gateway.networking.k8s.io
kubectl delete crd httproutes.gateway.networking.k8s.io
kubectl delete pvc homework-pvc -n homework

# Удаляем старую validatingadmissionpolicy, блокирующую политику и её привязку
kubectl delete validatingadmissionpolicy safe-upgrades.gateway.networking.k8s.io
kubectl delete validatingadmissionpolicybinding safe-upgrades.gateway.networking.k8s.io

# Проверить статус после удаления
# helm list -n homework
# kubectl get all -n homework
# если в списке нет homework-app/redis — удаление прошло успешно

### Формируем helmfile в соответствии с заданием № 2
# Установка helmfile
helmfile_version=1.5.5
linux_arch=amd64

cd /tmp && wget https://github.com/helmfile/helmfile/releases/download/v${helmfile_version}/helmfile_${helmfile_version}_linux_${linux_arch}.tar.gz
tar xzvf helmfile_${helmfile_version}_linux_${linux_arch}.tar.gz
sudo install -m 755 helmfile /usr/local/bin

# Проверка
helmfile --version
# Инициализация — установит плагин helm-diff
helmfile init

# Helmfile для Kafka
# helmfile.yaml описывает два релиза:
Параметр	            PROD	                          DEV
Namespace	            prod	                          dev
Брокеров	            5	                              1
Версия Kafka	        3.5.2 (tag: 3.5.2-debian-12-r0)	latest (по умолчанию)
Протокол client	      SASL_PLAINTEXT	                PLAINTEXT
Протокол interbroker	SASL_PLAINTEXT	                PLAINTEXT
Авторизация	          включена	                      отключена

# С 28 августа 2025 года Bitnami удалила все теги из публичного репозитория docker.io/bitnami/kafka и перенесла их в docker.io/bitnamilegacy/kafka

# Скачивание образов
docker pull bitnamilegacy/kafka:3.5.2-debian-11-r10
docker pull bitnamilegacy/kafka:4.0.0-debian-12-r10
docker pull bitnamilegacy/os-shell:12-debian-12-r51

# Установка образов в minikube
docker save bitnamilegacy/kafka:3.5.2-debian-11-r10 | minikube image load -
docker save bitnamilegacy/kafka:4.0.0-debian-12-r10 | minikube image load -
docker save bitnamilegacy/os-shell:12-debian-12-r51 | minikube image load -

# Запуск kafka через Helmfile
helmfile apply
helmfile apply --selector name=kafka-prod
helmfile apply --selector name=kafka-dev
# или
helmfile sync
helmfile sync --selector name=kafka-prod
helmfile sync --selector name=kafka-dev

# Проверка
kubectl exec -n prod kafka-prod-controller-0 -- env | grep -iE "sasl|jaas|user|pass|kafka"
kubectl exec -n dev kafka-dev-controller-0 -- env | grep -iE "sasl|jaas|user|pass|kafka"
kubectl exec -n dev kafka-dev-broker- -- env | grep -iE "sasl|jaas|user|pass|kafka"

# Удаление через Helmfile
helmfile destroy
helmfile destroy --selector name=kafka-prod
helmfile destroy --selector name=kafka-dev

# Удаление всех ресурсов
kubectl delete pvc -n prod --all
kubectl delete pvc -n dev --all
kubectl delete pv $(kubectl get pv | grep kafka)
kubectl delete all -n prod --all
kubectl delete all -n dev --all
kubectl delete configmap -n prod --all
kubectl delete secret -n prod --all

# Очистка hostpath-provisioner на каждой ноде Minikube
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "Cleaning $node..."
  minikube ssh --node "$node" "sudo rm -rf /tmp/hostpath-provisioner && sudo mkdir -p /tmp/hostpath-provisioner"
done

# очистка cache
helmfile cache cleanup
# или
rm -rf ~/.cache/helmfile

# Проверить статус после удаления
# helmfile status
# kubectl get pods -n prod
# kubectl get pods -n dev