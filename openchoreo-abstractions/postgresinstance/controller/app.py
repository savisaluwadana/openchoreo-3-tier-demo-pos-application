import base64
import datetime
import urllib.parse

import kopf
from kubernetes import client, config
from kubernetes.client.rest import ApiException

GROUP = "openchoreo.dev"
VERSION = "v1alpha1"
PLURAL = "postgresinstances"
KIND = "PostgresInstance"


def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _b64decode(value: str) -> str:
    return base64.b64decode(value).decode("utf-8")


def _build_database_url(*, host: str, port: int, database: str, username: str, password: str, ssl_mode: str | None, additional_params: dict[str, str] | None) -> str:
    user_enc = urllib.parse.quote(username, safe="")
    pass_enc = urllib.parse.quote(password, safe="")
    host_enc = host  # host should not be URL-escaped (can include DNS).
    db_enc = urllib.parse.quote(database, safe="")

    base = f"postgresql://{user_enc}:{pass_enc}@{host_enc}:{port}/{db_enc}"

    params: dict[str, str] = {}
    if ssl_mode:
        params["sslmode"] = ssl_mode
    if additional_params:
        params.update({str(k): str(v) for k, v in additional_params.items() if v is not None})

    if not params:
        return base

    return base + "?" + urllib.parse.urlencode(params)


def _ensure_kube_config_loaded() -> None:
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()


def _read_password_from_secret(namespace: str, name: str, key: str) -> str:
    v1 = client.CoreV1Api()
    sec = v1.read_namespaced_secret(name=name, namespace=namespace)
    if not sec.data or key not in sec.data:
        raise kopf.TemporaryError(f"Secret '{name}' missing key '{key}'.", delay=10)
    return _b64decode(sec.data[key])


def _upsert_binding_secret(
    *,
    namespace: str,
    secret_name: str,
    owner: dict,
    database_url: str,
    host: str,
    port: int,
    database: str,
    username: str,
    password: str,
) -> None:
    v1 = client.CoreV1Api()

    metadata = client.V1ObjectMeta(
        name=secret_name,
        namespace=namespace,
        owner_references=[
            client.V1OwnerReference(
                api_version=owner["apiVersion"],
                kind=owner["kind"],
                name=owner["metadata"]["name"],
                uid=owner["metadata"]["uid"],
                controller=True,
                block_owner_deletion=True,
            )
        ],
        labels={"app.kubernetes.io/managed-by": "postgresinstance-controller"},
    )

    body = client.V1Secret(
        api_version="v1",
        kind="Secret",
        metadata=metadata,
        type="Opaque",
        string_data={
            "DATABASE_URL": database_url,
            "DB_HOST": host,
            "DB_PORT": str(port),
            "DB_NAME": database,
            "DB_USER": username,
            "DB_PASSWORD": password,
        },
    )

    try:
        v1.create_namespaced_secret(namespace=namespace, body=body)
    except ApiException as e:
        if e.status != 409:
            raise
        v1.patch_namespaced_secret(name=secret_name, namespace=namespace, body=body)


def _set_status(namespace: str, name: str, patch: dict) -> None:
    api = client.CustomObjectsApi()
    api.patch_namespaced_custom_object_status(
        group=GROUP,
        version=VERSION,
        namespace=namespace,
        plural=PLURAL,
        name=name,
        body={"status": patch},
    )


@kopf.on.startup()
def _startup(**_):
    _ensure_kube_config_loaded()


@kopf.on.create(GROUP, VERSION, PLURAL)
@kopf.on.update(GROUP, VERSION, PLURAL)
def reconcile(spec, meta, status, **_):
    namespace = meta["namespace"]
    name = meta["name"]

    host = spec.get("host")
    port = int(spec.get("port", 5432))
    database = spec.get("database")
    username = spec.get("username")
    ssl_mode = spec.get("sslMode")
    additional_params = spec.get("additionalParams")

    psr = spec.get("passwordSecretRef") or {}
    psr_name = psr.get("name")
    psr_key = psr.get("key")

    binding_secret_name = spec.get("bindingSecretName") or f"{name}-binding"

    if not (host and database and username and psr_name and psr_key):
        raise kopf.PermanentError("spec.host, spec.database, spec.username, spec.passwordSecretRef.{name,key} are required")

    password = _read_password_from_secret(namespace, psr_name, psr_key)
    database_url = _build_database_url(
        host=host,
        port=port,
        database=database,
        username=username,
        password=password,
        ssl_mode=ssl_mode,
        additional_params=additional_params,
    )

    owner = {
        "apiVersion": f"{GROUP}/{VERSION}",
        "kind": KIND,
        "metadata": {"name": name, "uid": meta["uid"]},
    }

    _upsert_binding_secret(
        namespace=namespace,
        secret_name=binding_secret_name,
        owner=owner,
        database_url=database_url,
        host=host,
        port=port,
        database=database,
        username=username,
        password=password,
    )

    cond = {
        "type": "Ready",
        "status": "True",
        "reason": "SecretReady",
        "message": f"Binding Secret '{binding_secret_name}' is ready.",
        "lastTransitionTime": _now_iso(),
    }

    _set_status(
        namespace,
        name,
        {
            "observedGeneration": meta.get("generation"),
            "bindingSecretName": binding_secret_name,
            "conditions": [cond],
        },
    )

    return {"bindingSecretName": binding_secret_name}
