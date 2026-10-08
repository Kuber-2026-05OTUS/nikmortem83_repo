#!/usr/bin/env python3
"""
MySQL Operator для Otus Homework
Задание со **

Создаёт при появлении CR mysqls.otus.homework/v1:
  - Deployment с MySQL-образом
  - Service типа ClusterIP
  - PersistentVolume
  - PersistentVolumeClaim

Удаляет всё перечисленное при удалении CR.
"""

import kopf
import kubernetes
import kubernetes.client
from kubernetes.client.rest import ApiException

# ─── Helpers ─────────────────────────────────────────────────────────────────

def _sanitize_name(name: str) -> str:
    """PV-имя не может содержать точки — заменяем на дефисы."""
    return name.replace(".", "-")


def _ensure_api():
    """Загружаем конфиг из дефолтного kubeconfig/in-cluster."""
    try:
        kubernetes.config.load_incluster_config()
    except Exception:
        kubernetes.config.load_kube_config()


# ─── Handler: создание CR ──────────────────────────────────────────────────

@kopf.on.create("otus.homework", "v1", "mysqls")
def create_mysql(spec, name, namespace, logger, **kwargs):
    """
    При создании объекта MySQL создаём:
      1. PersistentVolume
      2. PersistentVolumeClaim
      3. Deployment (MySQL)
      4. Service (ClusterIP)
    """
    _ensure_api()

    image = spec.get("image", "mysql:8.0")
    database = spec.get("database", "otusdb")
    password = spec.get("password", "otusdb")
    storage_size = spec.get("storage_size", "5Gi")

    pv_name = _sanitize_name(f"pv-{name}")
    pvc_name = f"pvc-{name}"
    deploy_name = f"mysql-{name}"
    svc_name = f"mysql-{name}"
    labels = {"app": f"mysql-{name}"}

    core_v1 = kubernetes.client.CoreV1Api()
    apps_v1 = kubernetes.client.AppsV1Api()

    # 1. PersistentVolume
    pv_body = kubernetes.client.V1PersistentVolume(
        api_version="v1",
        kind="PersistentVolume",
        metadata=kubernetes.client.V1ObjectMeta(
            name=pv_name,
            labels=labels,
        ),
        spec=kubernetes.client.V1PersistentVolumeSpec(
            capacity={"storage": storage_size},
            access_modes=["ReadWriteOnce"],
            host_path=kubernetes.client.V1HostPathVolumeSource(
                path=f"/var/lib/mysql-pv/{name}",
                type="DirectoryOrCreate",
            ),
            persistent_volume_reclaim_policy="Retain",
        ),
    )
    try:
        core_v1.create_persistent_volume(pv_body)
        logger.info(f"PV {pv_name} создан")
    except ApiException as e:
        if e.status == 409:
            logger.info(f"PV {pv_name} уже существует")
        else:
            raise

    # 2. PersistentVolumeClaim
    pvc_body = kubernetes.client.V1PersistentVolumeClaim(
        api_version="v1",
        kind="PersistentVolumeClaim",
        metadata=kubernetes.client.V1ObjectMeta(
            name=pvc_name,
            namespace=namespace,
            labels=labels,
        ),
        spec=kubernetes.client.V1PersistentVolumeClaimSpec(
            access_modes=["ReadWriteOnce"],
            resources=kubernetes.client.V1ResourceRequirements(
                requests={"storage": storage_size}
            ),
        ),
    )
    try:
        core_v1.create_namespaced_persistent_volume_claim(namespace, pvc_body)
        logger.info(f"PVC {pvc_name} создан")
    except ApiException as e:
        if e.status == 409:
            logger.info(f"PVC {pvc_name} уже существует")
        else:
            raise

    # 3. Deployment
    container = kubernetes.client.V1Container(
        name="mysql",
        image=image,
        ports=[kubernetes.client.V1ContainerPort(container_port=3306)],
        env=[
            kubernetes.client.V1EnvVar(name="MYSQL_ROOT_PASSWORD", value=password),
            kubernetes.client.V1EnvVar(name="MYSQL_DATABASE", value=database),
        ],
        volume_mounts=[
            kubernetes.client.V1VolumeMount(
                name="mysql-storage",
                mount_path="/var/lib/mysql",
            )
        ],
    )

    pod_spec = kubernetes.client.V1PodSpec(
        containers=[container],
        volumes=[
            kubernetes.client.V1Volume(
                name="mysql-storage",
                persistent_volume_claim=kubernetes.client.V1PersistentVolumeClaimVolumeSource(
                    claim_name=pvc_name
                ),
            )
        ],
    )

    deploy_body = kubernetes.client.V1Deployment(
        api_version="apps/v1",
        kind="Deployment",
        metadata=kubernetes.client.V1ObjectMeta(
            name=deploy_name,
            namespace=namespace,
            labels=labels,
        ),
        spec=kubernetes.client.V1DeploymentSpec(
            replicas=1,
            selector=kubernetes.client.V1LabelSelector(match_labels=labels),
            template=kubernetes.client.V1PodTemplateSpec(
                metadata=kubernetes.client.V1ObjectMeta(labels=labels),
                spec=pod_spec,
            ),
        ),
    )
    try:
        apps_v1.create_namespaced_deployment(namespace, deploy_body)
        logger.info(f"Deployment {deploy_name} создан")
    except ApiException as e:
        if e.status == 409:
            logger.info(f"Deployment {deploy_name} уже существует")
        else:
            raise

    # 4. Service (ClusterIP)
    svc_body = kubernetes.client.V1Service(
        api_version="v1",
        kind="Service",
        metadata=kubernetes.client.V1ObjectMeta(
            name=svc_name,
            namespace=namespace,
            labels=labels,
        ),
        spec=kubernetes.client.V1ServiceSpec(
            selector=labels,
            type="ClusterIP",
            ports=[
                kubernetes.client.V1ServicePort(
                    port=3306,
                    target_port=3306,
                    protocol="TCP",
                )
            ],
        ),
    )
    try:
        core_v1.create_namespaced_service(namespace, svc_body)
        logger.info(f"Service {svc_name} создан")
    except ApiException as e:
        if e.status == 409:
            logger.info(f"Service {svc_name} уже существует")
        else:
            raise

    return {
        "message": f"MySQL instance {name} created",
        "pv": pv_name,
        "pvc": pvc_name,
        "deployment": deploy_name,
        "service": svc_name,
    }


# ─── Handler: удаление CR ───────────────────────────────────────────────────

@kopf.on.delete("otus.homework", "v1", "mysqls")
def delete_mysql(spec, name, namespace, logger, **kwargs):
    """
    При удалении объекта MySQL удаляем все созданные ресурсы.
    Порядок: Service → Deployment → PVC → PV
    """
    _ensure_api()

    pv_name = _sanitize_name(f"pv-{name}")
    pvc_name = f"pvc-{name}"
    deploy_name = f"mysql-{name}"
    svc_name = f"mysql-{name}"

    core_v1 = kubernetes.client.CoreV1Api()
    apps_v1 = kubernetes.client.AppsV1Api()

    # 1. Service
    try:
        core_v1.delete_namespaced_service(svc_name, namespace)
        logger.info(f"Service {svc_name} удалён")
    except ApiException as e:
        if e.status != 404:
            logger.warning(f"Не удалось удалить Service {svc_name}: {e}")

    # 2. Deployment
    try:
        apps_v1.delete_namespaced_deployment(deploy_name, namespace)
        logger.info(f"Deployment {deploy_name} удалён")
    except ApiException as e:
        if e.status != 404:
            logger.warning(f"Не удалось удалить Deployment {deploy_name}: {e}")

    # 3. PVC
    try:
        core_v1.delete_namespaced_persistent_volume_claim(pvc_name, namespace)
        logger.info(f"PVC {pvc_name} удалён")
    except ApiException as e:
        if e.status != 404:
            logger.warning(f"Не удалось удалить PVC {pvc_name}: {e}")

    # 4. PV
    try:
        core_v1.delete_persistent_volume(pv_name)
        logger.info(f"PV {pv_name} удалён")
    except ApiException as e:
        if e.status != 404:
            logger.warning(f"Не удалось удалить PV {pv_name}: {e}")

    return {"message": f"MySQL instance {name} deleted"}
