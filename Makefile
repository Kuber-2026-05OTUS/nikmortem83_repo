MANIFESTS_DIR := manifests
GENERATED_DIR := generated
KUBECONFIG_CD := $(GENERATED_DIR)/kubeconfig-cd.yaml
TOKEN_FILE := $(GENERATED_DIR)/token

SHELL := /bin/bash  # ← Ключевое: используем bash, а не sh

.PHONY: all
all: setup enable-metrics-server apply create-cd-token create-kubeconfig-cd wait test

.PHONY: setup
setup:
	@echo "🔧 Создаём директорию для сгенерированных файлов..."
	@mkdir -p $(GENERATED_DIR)

	@echo "☸️ Проверяем Helm..."
	@command -v helm >/dev/null 2>&1 || (echo "Helm не установлен. Установите Helm." && exit 1)

.PHONY: enable-metrics-server
enable-metrics-server:
	@echo "📊 Включаем metrics-server ДО развёртывания..."
	@minikube addons enable metrics-server
	@echo "⏳ Ожидаем готовности metrics-server..."
	@kubectl wait --for=condition=available --timeout=180s apiservice v1beta1.metrics.k8s.io || true

.PHONY: apply
apply: create-namespace install-gateway-api install-traefik apply-manifests

.PHONY: create-namespace
create-namespace:
	@kubectl apply -f $(MANIFESTS_DIR)/namespace.yaml

.PHONY: install-gateway-api
install-gateway-api:
	@echo "🌐 Устанавливаем gateway-api CRD..."
	@kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
	@echo "⏳ Ожидаем готовности CRD..."
	@kubectl wait --for=condition=established --timeout=320s crd/gatewayclasses.gateway.networking.k8s.io
	@kubectl wait --for=condition=established --timeout=320s crd/gateways.gateway.networking.k8s.io
	@kubectl wait --for=condition=established --timeout=320s crd/httproutes.gateway.networking.k8s.io

.PHONY: install-traefik
install-traefik:
	@echo "☸️ Устанавливаем Traefik..."
	@helm upgrade --install traefik traefik/traefik \
		--namespace homework \
		--create-namespace \
		--values $(MANIFESTS_DIR)/traefik-values.yaml
	@kubectl wait --for=condition=available --timeout=120s deployment/traefik -n homework

.PHONY: apply-manifests
apply-manifests:
	@echo "📝 Применяем манифесты..."
	@kubectl apply -f $(MANIFESTS_DIR)/sa-monitoring.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/sa-cd.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/secret-cd-token.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/role-metrics-reader.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/rolebinding-monitoring.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/rolebinding-cd-admin.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/storageclass.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/pvc.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/cm.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/config.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/service.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/gatewayclass.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/gateway.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/httproute.yaml
	@kubectl apply -f $(MANIFESTS_DIR)/deployment.yaml

.PHONY: create-cd-token
create-cd-token:
	@echo "🔐 Генерируем токен для ServiceAccount 'cd'..."
	@TOKEN=$$(kubectl create token cd --namespace homework --duration=24h 2>/dev/null) && \
	if [ -n "$$TOKEN" ]; then \
		echo "$$TOKEN" > $(TOKEN_FILE); \
		echo "✅ Токен успешно создан: $$(head -c 20 $(TOKEN_FILE))..."; \
	else \
		echo "⚠️  'kubectl create token' не сработал, используем fallback..."; \
		SECRET=$$(kubectl get secret -n homework -o jsonpath='{.items[?(@.type=="kubernetes.io/service-account-token") && contains(@.metadata.annotations."kubernetes\.io/service-account\.name", "cd")].metadata.name}' | awk '{print $$1; exit}'); \
		if [ -z "$$SECRET" ]; then \
			echo "❌ Не найден secret для ServiceAccount 'cd'"; \
			exit 1; \
		fi; \
		kubectl get secret $$SECRET -n homework -o jsonpath='{.data.token}' | base64 --decode > $(TOKEN_FILE); \
		if [ -s $(TOKEN_FILE) ]; then \
			echo "✅ Токен получен из secret $$SECRET"; \
		else \
			echo "❌ Не удалось получить токен ни через create token, ни через secret"; \
			exit 1; \
		fi; \
	fi

.PHONY: create-kubeconfig-cd
create-kubeconfig-cd:
	@echo "🔐 Создаём kubeconfig для cd..."
	@SERVER=$$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}') && \
	TOKEN=$$(cat $(TOKEN_FILE)) && \
	echo "apiVersion: v1" > $(KUBECONFIG_CD) && \
	echo "kind: Config" >> $(KUBECONFIG_CD) && \
	echo "current-context: homework-cd" >> $(KUBECONFIG_CD) && \
	echo "clusters:" >> $(KUBECONFIG_CD) && \
	echo "  - name: kubernetes" >> $(KUBECONFIG_CD) && \
	echo "    cluster:" >> $(KUBECONFIG_CD) && \
	echo "      server: $$SERVER" >> $(KUBECONFIG_CD) && \
	echo "      insecure-skip-tls-verify: true" >> $(KUBECONFIG_CD) && \
	echo "contexts:" >> $(KUBECONFIG_CD) && \
	echo "  - name: homework-cd" >> $(KUBECONFIG_CD) && \
	echo "    context:" >> $(KUBECONFIG_CD) && \
	echo "      cluster: kubernetes" >> $(KUBECONFIG_CD) && \
	echo "      namespace: homework" >> $(KUBECONFIG_CD) && \
	echo "      user: cd" >> $(KUBECONFIG_CD) && \
	echo "users:" >> $(KUBECONFIG_CD) && \
	echo "  - name: cd" >> $(KUBECONFIG_CD) && \
	echo "    user:" >> $(KUBECONFIG_CD) && \
	echo "      token: $$TOKEN" >> $(KUBECONFIG_CD)
	@echo "✅ kubeconfig сохранён: $(KUBECONFIG_CD)"

.PHONY: wait
wait:
	@echo "⏳ Ожидаем готовности пода homework-app..."
	@kubectl wait --for=condition=ready pod -l app=homework-app -n homework --timeout=120s

	@echo "🌐 Обновляем /etc/hosts в Minikube..."
	@TRAEFIK_IP=$$(kubectl get svc -n homework traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	if [ -z "$$TRAEFIK_IP" ]; then \
		echo "❌ IP Traefik не получен. Убедитесь, что запущен 'minikube tunnel'"; \
		exit 1; \
	fi; \
	minikube ssh "sudo sh -c 'grep -v homework\\.otus /etc/hosts > /tmp/hosts && echo $$TRAEFIK_IP homework.otus >> /tmp/hosts && sudo cp /tmp/hosts /etc/hosts'"

.PHONY: test
test:
	@echo "🧪 Проверка доступа..."
	@minikube ssh "curl -s -o /dev/null -w '→ /conf/file: %{http_code}\n' http://homework.otus/conf/file"
	@minikube ssh "curl -s -o /dev/null -w '→ /index.html: %{http_code}\n' http://homework.otus/index.html"
	@minikube ssh "curl -s -o /dev/null -w '→ /metrics.html: %{http_code}\n' http://homework.otus/metrics.html"
	@echo "📋 Состояние подов:"
	@KUBECONFIG=$(KUBECONFIG_CD) kubectl get pods -n homework