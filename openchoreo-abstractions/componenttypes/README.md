# OpenChoreo ComponentTypes (Developer Abstractions)

This folder contains **OpenChoreo `ComponentType`** definitions (as described in the blog post on creating developer abstractions), plus example `Component` + `Workload` instances.

## Postgres (PVC-backed)

Files:
- `postgres-database.componenttype.yaml` – a `ComponentType` that provisions PostgreSQL using a StatefulSet + Service + Secret + PVC via `volumeClaimTemplates`.
- `postgres-database.example.yaml` – an example `Component` + `Workload` using `postgres:15-alpine`.

In this local setup, OpenChoreo dataplane blocks Kubernetes `Secret` operations, so this `ComponentType` does **not** create Secrets. Database credentials are provided via `parameters.dbUser` / `parameters.dbPassword` for development only.

### Apply

```bash
kubectl apply -f openchoreo-abstractions/componenttypes/postgres-database.componenttype.yaml
kubectl apply -f openchoreo-abstractions/componenttypes/postgres-database.example.yaml
```

### Verify persistence

```bash
kubectl get pvc -n default
kubectl get statefulset -n default
kubectl get pods -n default
```

### Connect backend

Configure your backend component with a `DATABASE_URL` that points to the DB **service name** (the OpenChoreo component name) in the same environment:

Example (if DB component name is `inventorydatabase`):
`postgresql://postgres:postgres@inventorydatabase:5432/inventory_db`

To confirm data persists:
1. Create a table/row in the DB.
2. Delete the Postgres pod (not the PVC).
3. Verify the row still exists.

> Notes
- `storageClassName` defaults to `standard`. If your cluster uses a different StorageClass, set `parameters.storageClassName` accordingly.
- This example stores `dbPassword` as a parameter and writes it into a Secret. For production, prefer referencing an existing Secret instead of putting passwords in the `Component` spec.
