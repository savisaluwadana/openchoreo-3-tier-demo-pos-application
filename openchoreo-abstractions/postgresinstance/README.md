# PostgresInstance (Custom CRD)

This folder adds a **developer abstraction** for databases: a `PostgresInstance` custom resource that represents an existing PostgreSQL endpoint and automatically creates a **binding Secret** containing `DATABASE_URL` (and `DB_*` keys).

It follows the pattern described in: https://openchoreo.dev/blog/creating-developer-abstractions-for-k8s/

## What it does

- You create a `PostgresInstance` with `host`, `port`, `database`, `username`, and a `passwordSecretRef`.
- The controller creates/updates a Secret (default: `<name>-binding`) with:
  - `DATABASE_URL`
  - `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`

## Install (on your cluster)

1) Install the CRD:

```bash
kubectl apply -f openchoreo-abstractions/postgresinstance/crd.yaml
```

2) Build & push the controller image (edit the image name/tag as needed):

```bash
docker build -t savisaluwadana/postgresinstance-controller:latest openchoreo-abstractions/postgresinstance/controller
docker push savisaluwadana/postgresinstance-controller:latest
```

3) Deploy RBAC + controller (namespace is `inventory-system` in these manifests):

```bash
kubectl apply -f openchoreo-abstractions/postgresinstance/manifests/rbac.yaml
kubectl apply -f openchoreo-abstractions/postgresinstance/manifests/deployment.yaml
```

## Usage

Apply the example (creates creds + PostgresInstance that generates `backend-secret`):

```bash
kubectl apply -f openchoreo-abstractions/postgresinstance/examples/postgresinstance.yaml
```

Verify the binding Secret:

```bash
kubectl get secret backend-secret -n inventory-system -o yaml
```

## Backend integration

Your existing `kubernetes/backend-deployment.yaml` already reads `DATABASE_URL` from `backend-secret`, so if you set `spec.bindingSecretName: backend-secret`, the backend will work without changes.
