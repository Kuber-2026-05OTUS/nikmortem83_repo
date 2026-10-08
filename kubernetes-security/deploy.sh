#!/bin/bash

set -eo pipefail  # ← останавливаемся при любой ошибке

# === Настройки ===
MANIFESTS_DIR="manifests"
GENERATED_DIR="generated"
KUBECONFIG_CD="$GENERATED_DIR/kubeconfig-cd.yaml"
TOKEN_FILE="$GENERATED_DIR/token"

echo "🚀 Запуск развёртывания..."

# === 1. Создаём папку ===
echo "🔧 Создаём папку $GENERATED_DIR..."
mkdir -p "$GENERATED_DIR"

# === 2. Включаем metrics-server ДО всего ===
echo "📊 Включаем metrics-server..."
minikube addons enable metrics-server
echo "⏳ Ожидаем готовности metrics-server..."
kubectl wait --for=condition=available --timeout=180s apiservice v1beta1.metrics.k8s.io || true

# === 3. Применяем манифесты ===
echo "📦 Применяем манифесты..."

kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"

echo "🌐 Устанавливаем gateway-api CRD..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
kubectl wait --for=condition=established --timeout=320s crd/gatewayclasses.gateway.networking.k8s.io
kubectl wait --for=condition=established --timeout=320s crd/gateways.gateway.networking.k8s.io
kubectl wait --for=condition=established --timeout=320s crd/httproutes.gateway.networking.k8s.io

echo "☸️ Устанавливаем Traefik..."
helm upgrade --install traefik traefik/traefik \
  --namespace homework \
  --create-namespace \
  --values "$MANIFESTS_DIR/traefik-values.yaml"
kubectl wait --for=condition=available --timeout=120s deployment/traefik -n homework

echo "📝 Применяем остальные манифесты..."
kubectl apply -f "$MANIFESTS_DIR/sa-monitoring.yaml"
kubectl apply -f "$MANIFESTS_DIR/sa-cd.yaml"
kubectl apply -f "$MANIFESTS_DIR/secret-cd-token.yaml"
kubectl apply -f "$MANIFESTS_DIR/role-metrics-reader.yaml"
kubectl apply -f "$MANIFESTS_DIR/rolebinding-monitoring.yaml"
kubectl apply -f "$MANIFESTS_DIR/rolebinding-cd-admin.yaml"
kubectl apply -f "$MANIFESTS_DIR/storageclass.yaml"
kubectl apply -f "$MANIFESTS_DIR/pvc.yaml"
kubectl apply -f "$MANIFESTS_DIR/cm.yaml"
kubectl apply -f "$MANIFESTS_DIR/config.yaml"
kubectl apply -f "$MANIFESTS_DIR/service.yaml"
kubectl apply -f "$MANIFESTS_DIR/gatewayclass.yaml"
kubectl apply -f "$MANIFESTS_DIR/gateway.yaml"
kubectl apply -f "$MANIFESTS_DIR/httproute.yaml"
kubectl apply -f "$MANIFESTS_DIR/deployment.yaml"

# === 4. Генерируем токен ===
echo "🔐 Генерируем токен для ServiceAccount 'cd'..."

TOKEN=$(kubectl create token cd --namespace homework --duration=24h 2>/dev/null)
if [ -n "$TOKEN" ]; then
  echo "$TOKEN" > "$TOKEN_FILE"
  echo "✅ Токен создан через 'kubectl create token'"
else
  echo "⚠️  'kubectl create token' не сработал, используем secret..."
  SECRET=$(kubectl get secret -n homework -o jsonpath='{.items[?(@.type=="kubernetes.io/service-account-token") && contains(@.metadata.annotations."kubernetes\.io/service-account\.name", "cd")].metadata.name}' | awk '{print $1; exit}')
  if [ -z "$SECRET" ]; then
    echo "❌ Не найден secret для ServiceAccount 'cd'"
    exit 1
  fi
  kubectl get secret "$SECRET" -n homework -o jsonpath='{.data.token}' | base64 --decode > "$TOKEN_FILE"
  if [ ! -s "$TOKEN_FILE" ]; then
    echo "❌ Не удалось получить токен"
    exit 1
  fi
  echo "✅ Токен получен из secret: $SECRET"
fi

# === 5. Создаём kubeconfig ===
echo "🔐 Создаём kubeconfig: $KUBECONFIG_CD..."

SERVER=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
TOKEN=$(cat "$TOKEN_FILE")

cat <<EOF > "$KUBECONFIG_CD"
apiVersion: v1
kind: Config
current-context: homework-cd
clusters:
  - name: kubernetes
    cluster:
      server: $SERVER
      insecure-skip-tls-verify: true
contexts:
  - name: homework-cd
    context:
      cluster: kubernetes
      namespace: homework
      user: cd
users:
  - name: cd
    user:
      token: $TOKEN
EOF

echo "✅ kubeconfig сохранён: $KUBECONFIG_CD"

# === 6. Ждём готовности пода ===
echo "⏳ Ожидаем готовности пода homework-app..."
kubectl wait --for=condition=ready pod -l app=homework-app -n homework --timeout=120s

# === 7. Обновляем /etc/hosts в Minikube ===
echo "🌐 Обновляем /etc/hosts в Minikube..."
TRAEFIK_IP=$(kubectl get svc -n homework traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$TRAEFIK_IP" ]; then
  echo "❌ IP Traefik не получен. Убедитесь, что запущен 'minikube tunnel'"
  exit 1
fi
# minikube ssh "sudo sh -c 'echo $TRAEFIK_IP homework.otus >> /etc/hosts'"
minikube ssh "sudo sh -c 'grep -v homework\\.otus /etc/hosts > /tmp/hosts && echo $TRAEFIK_IP homework.otus >> /tmp/hosts && sudo cp /tmp/hosts /etc/hosts'"

# === 8. Тестирование — БЫСТРО и ЧЁТКО ===
echo "🧪 Проверка доступа..."

# Используем --max-time, чтобы не висеть долго
minikube ssh -- "curl -s --max-time 5 -o /dev/null -w '→ /conf/file: %{http_code}\n' http://homework.otus/conf/file"
minikube ssh -- "curl -s --max-time 5 -o /dev/null -w '→ /index.html: %{http_code}\n' http://homework.otus/index.html"
minikube ssh -- "curl -s --max-time 5 -o /dev/null -w '→ /metrics.html: %{http_code}\n' http://homework.otus/metrics.html"

echo "📋 Состояние подов:"
KUBECONFIG="$KUBECONFIG_CD" kubectl get pods -n homework

echo "✅ Развёртывание завершено!"