# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2026-05" 
# ДЗ "Знакомство с решениями для запуска локального Kubernetes кластера, создание первого pod"
# Морозов Н.Н.

## ✨ создем ветку kubernetes-intro
### git branch --show-current

## Запускаем minikube
minikube start --driver=docker

## Устанавливаем namespace
kubectl apply -f namespace.yaml 

## Запуск
kubectl apply -f config.yaml
kubectl apply -f pod.yaml 
kubectl apply -f service.yaml 

## Проверка
minikube service homework-service --url -n homework

## Удаление
kubectl apply -f config.yaml
kubectl apply -f service.yaml 
kubectl apply -f pod.yaml