# 🚀 OpenChoreo 3-Tier POS Application Deployment Guide

> **Complete deployment guide for the Inventory Management System on OpenChoreo**  
> Includes custom database abstractions, step-by-step instructions, and production-ready patterns.

---

## 📋 Table of Contents

| Section | Description |
|---------|-------------|
| [🏗️ Architecture Overview](#️-architecture-overview) | System design and component relationships |
| [🗄️ Custom Database Abstraction](#️-custom-database-abstraction) | Reusable PostgreSQL ComponentType |
| [📦 Deployment Steps](#-deployment-steps) | Complete deployment walkthrough |
| [⚙️ Configuration Details](#️-configuration-details) | Environment variables and routing |
| [🔧 Troubleshooting](#-troubleshooting) | Common issues and solutions |
| [🎯 Key Learnings](#-key-learnings) | OpenChoreo patterns and best practices |
| [✅ Production Checklist](#-production-checklist) | Pre-production requirements |

---

## 🏗️ Architecture Overview

### 📚 Application Stack

| Layer | Technology | Details |
|-------|------------|----------|
| 🗄️ **Database** | PostgreSQL 15 | Deployed as OpenChoreo ComponentType with PVC persistence |
| ⚙️ **Backend** | Node.js/Express + TypeScript | REST API with CORS, connects to PostgreSQL |
| 🎨 **Frontend** | Next.js 14 + TypeScript + Tailwind | App Router, server-side rendering |

### 🌐 OpenChoreo Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    OpenChoreo Gateway                        │
│  inventoryfrontend-development.openchoreoapis.localhost     │
│  development.openchoreoapis.localhost/inventorybackend      │
└─────────────────────────────────────────────────────────────┘
                           ▼
┌──────────────────┬──────────────────┬─────────────────────┐
│  Frontend Pod    │  Backend Pod     │  Database Pod       │
│  Next.js:3000    │  Express:5000    │  PostgreSQL:5432    │
│  (Deployment)    │  (Deployment)    │  (StatefulSet)      │
└──────────────────┴──────────────────┴─────────────────────┘
                           ▼
                  ┌──────────────────┐
                  │  PersistentVolume │
                  │  (local-path)     │
                  └──────────────────┘
```

---

## 🗄️ Custom Database Abstraction

> 💡 **Innovation**: We created a reusable **PostgreSQL ComponentType** for OpenChoreo that provisions production-ready databases with persistent storage using PVCs.

### 📝 ComponentType Definition

<details>
<summary><strong>Click to expand full ComponentType YAML</strong></summary>

**File**: `openchoreo-abstractions/componenttypes/postgres-database.componenttype.yaml`

```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: ComponentType
metadata:
  name: postgres-database
  namespace: default
spec:
  workloadType: statefulset
  
  schema:
    parameters:
      port:
        type: integer
        default: 5432
      replicas:
        type: integer
        default: 1
      postgresUser:
        type: string
        default: "postgres"
      postgresPassword:
        type: string
        default: "postgres"
      postgresDatabase:
        type: string
        default: "postgres"
      storageSize:
        type: string
        default: "1Gi"
      storageClassName:
        type: string
        default: "local-path"
    
    envOverrides:
      resources:
        type: ResourceRequirements
        default: {}
    
    types:
      ResourceQuantity:
        cpu:
          type: string
          default: "250m"
        memory:
          type: string
          default: "512Mi"
      ResourceRequirements:
        limits:
          type: ResourceQuantity
          default: {}
        requests:
          type: ResourceQuantity
          default: {}

  resources:
    # StatefulSet for PostgreSQL
    - id: statefulset
      targetPlane: dataplane
      template:
        apiVersion: apps/v1
        kind: StatefulSet
        metadata:
          name: ${metadata.name}
          namespace: ${metadata.namespace}
          labels: ${metadata.labels}
        spec:
          replicas: ${parameters.replicas}
          serviceName: ${metadata.componentName}
          selector:
            matchLabels: ${metadata.podSelectors}
          template:
            metadata:
              labels: ${metadata.podSelectors}
            spec:
              containers:
              - name: postgres
                image: postgres:15
                imagePullPolicy: IfNotPresent
                ports:
                - containerPort: ${parameters.port}
                  name: postgres
                  protocol: TCP
                env:
                - name: POSTGRES_USER
                  value: ${parameters.postgresUser}
                - name: POSTGRES_PASSWORD
                  value: ${parameters.postgresPassword}
                - name: POSTGRES_DB
                  value: ${parameters.postgresDatabase}
                - name: PGDATA
                  value: /var/lib/postgresql/data/pgdata
                resources:
                  limits:
                    cpu: ${envOverrides.resources.limits.cpu}
                    memory: ${envOverrides.resources.limits.memory}
                  requests:
                    cpu: ${envOverrides.resources.requests.cpu}
                    memory: ${envOverrides.resources.requests.memory}
                volumeMounts:
                - name: postgres-data
                  mountPath: /var/lib/postgresql/data
          volumeClaimTemplates:
          - metadata:
              name: postgres-data
            spec:
              accessModes:
              - ReadWriteOnce
              storageClassName: ${parameters.storageClassName}
              resources:
                requests:
                  storage: ${parameters.storageSize}

    # Service for PostgreSQL
    - id: service
      targetPlane: dataplane
      template:
        apiVersion: v1
        kind: Service
        metadata:
          name: ${metadata.componentName}
          namespace: ${metadata.namespace}
          labels: ${metadata.labels}
        spec:
          type: ClusterIP
          clusterIP: None  # Headless service for StatefulSet
          ports:
          - port: ${parameters.port}
            targetPort: ${parameters.port}
            protocol: TCP
            name: postgres
          selector: ${metadata.podSelectors}

    # PodDisruptionBudget for high availability
    - id: pdb
      targetPlane: dataplane
      template:
        apiVersion: policy/v1
        kind: PodDisruptionBudget
        metadata:
          name: ${metadata.componentName}-pdb
          namespace: ${metadata.namespace}
          labels: ${metadata.labels}
        spec:
          minAvailable: 1
          selector:
            matchLabels: ${metadata.podSelectors}
```

### Example Component Manifest

**File**: `openchoreo-abstractions/componenttypes/postgres-database-example.component.yaml`

```yaml
apiVersion: openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: inventorydatabase
  namespace: default
  annotations:
    openchoreo.dev/display-name: "inventorydatabase"
spec:
  componentType: statefulset/postgres-database
  owner:
    projectName: inventorysystem
  parameters:
    port: 5432
    replicas: 1
    postgresUser: "postgres"
    postgresPassword: "postgres"
    postgresDatabase: "inventory_db"
    storageSize: "2Gi"
    storageClassName: "local-path"
```

</details>

---

## 📦 Deployment Steps

> ⏱️ **Estimated Time**: 20-30 minutes  
> 🎓 **Difficulty**: Intermediate

### ✅ Prerequisites

| Requirement | Status |
|-------------|--------|
| OpenChoreo cluster running locally | ☐ |
| kubectl configured to access cluster | ☐ |
| Docker Hub account (for pushing images) | ☐ |
| Git repository with application code | ☐ |
| Docker installed and running | ☐ |

### 📍 Step 1: Create the Database ComponentType

<details>
<summary><strong>View commands and expected output</strong></summary>

```bash
# Apply the custom ComponentType
kubectl apply -f openchoreo-abstractions/componenttypes/postgres-database.componenttype.yaml

# Verify it was created
kubectl get componenttypes -n default
```

**Expected Output:**
```
NAME                WORKLOADTYPE   AGE
postgres-database   statefulset    5s
```

</details>

### 📍 Step 2: Deploy the Database Component

<details>
<summary><strong>View commands and expected output</strong></summary>

```bash
# Apply the database component
kubectl apply -f openchoreo-abstractions/componenttypes/postgres-database-example.component.yaml

# Wait for the database to be ready
kubectl get statefulset -n dp-default-inventorysyst-development-e51b7a18 -w
```

**Expected Output:**
```
NAME                                     READY   AGE
inventorydatabase-development-9a30de76   1/1     2m
```

> ✅ **Success**: StatefulSet shows `1/1` READY

</details>

### 📍 Step 3: Initialize the Database

<details>
<summary><strong>View commands and expected output</strong></summary>

```bash
# Find the dataplane namespace
DATAPLANE_NS=$(kubectl get ns | grep 'dp-default-inventorysyst-development' | awk '{print $1}')

# Find the database pod
DB_POD=$(kubectl get pods -n $DATAPLANE_NS -l openchoreo.dev/component=inventorydatabase -o jsonpath='{.items[0].metadata.name}')

# Copy the init.sql script to the pod
kubectl cp backend/init.sql $DATAPLANE_NS/$DB_POD:/tmp/init.sql

# Execute the initialization script
kubectl exec -n $DATAPLANE_NS $DB_POD -- psql -U postgres -d inventory_db -f /tmp/init.sql

# Verify data was seeded
kubectl exec -n $DATAPLANE_NS $DB_POD -- psql -U postgres -d inventory_db -c "SELECT COUNT(*) FROM products;"
```

**Expected Output:**
```
 count 
-------
     5
(1 row)
```

> ✅ **Success**: Database initialized with 5 sample products

</details>

### 📍 Step 4: Deploy the Backend Service

<details>
<summary><strong>View detailed backend deployment steps</strong></summary>

#### 4️⃣.1 Build and Push Backend Image

```bash
# Build the backend image
docker build -t savisaluwadana/inventory-backend:latest -f backend/Dockerfile .

# Push to Docker Hub
docker push savisaluwadana/inventory-backend:latest
```

#### 4️⃣.2 Create Backend Component via OpenChoreo UI

Navigate to OpenChoreo UI and create a service component with:
- **Name**: `inventorybackend`
- **Component Type**: `deployment/service`
- **Repository**: Your Git repository URL
- **Branch**: `main`
- **Build Context**: `backend/`
- **Port**: `5000`

#### 4️⃣.3 Configure Backend Environment Variables

In the OpenChoreo UI, configure the following environment variables:

| Variable | Value | Required |
|----------|-------|----------|
| `PORT` | `5000` | ✅ |
| `NODE_ENV` | `production` | ✅ |
| `DATABASE_URL` | `postgresql://postgres:postgres@inventorydatabase-development-<hash>:5432/inventory_db` | ✅ |
| `FRONTEND_URL` | `http://inventoryfrontend-development.openchoreoapis.localhost:19080` | ✅ |

> ⚠️ **Important**: The `DATABASE_URL` must use the exact service name from the dataplane. Find it with:
```bash
kubectl get svc -n $DATAPLANE_NS | grep inventorydatabase
```

</details>

### 📍 Step 5: Deploy the Frontend

<details>
<summary><strong>View detailed frontend deployment steps</strong></summary>

#### 5️⃣.1 Configure Frontend Environment

**File**: `frontend/.env.production`
```env
NEXT_PUBLIC_API_URL=http://development.openchoreoapis.localhost:19080/inventorybackend/api
```

**File**: `frontend/.dockerignore`
```
.env.local
.next
node_modules
.git
```

#### 5️⃣.2 Build and Push Frontend Image

```bash
# Build the frontend with production config
docker build -t savisaluwadana/inventory-frontend:openchoreo -f frontend/Dockerfile .

# Push to Docker Hub
docker push savisaluwadana/inventory-frontend:openchoreo
```

#### 5️⃣.3 Create Frontend Component via OpenChoreo UI

Navigate to OpenChoreo UI and create a web application component with:
- **Name**: `inventoryfrontend`
- **Component Type**: `deployment/web-application`
- **Repository**: Your Git repository URL
- **Branch**: `main`
- **Build Context**: `frontend/`
- **Port**: `3000` (critical - Next.js listens on 3000, not 80)
- **Image**: `savisaluwadana/inventory-frontend:openchoreo`

> ⚠️ **Critical**: Port must be `3000`, not `80`. Next.js containers listen on port 3000.

</details>

---

## ⚙️ Configuration Details

### 🔧 Backend Configuration

The backend uses the following environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `PORT` | `5000` | Express server port |
| `NODE_ENV` | `production` | Node.js environment |
| `DATABASE_URL` | `postgresql://postgres:postgres@inventorydatabase-development-<hash>:5432/inventory_db` | PostgreSQL connection string |
| `FRONTEND_URL` | `http://inventoryfrontend-development.openchoreoapis.localhost:19080` | CORS allowed origin |

### 🎨 Frontend Configuration

The frontend uses build-time environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `NEXT_PUBLIC_API_URL` | `http://development.openchoreoapis.localhost:19080/inventorybackend/api` | Backend API base URL |
| `PORT` | `3000` | Next.js dev server port (container listens here) |
| `NODE_ENV` | `production` | Node.js environment |
| `NEXT_TELEMETRY_DISABLED` | `1` | Disable Next.js telemetry |

### 🌐 OpenChoreo Gateway Routing

#### 🔹 Backend Route
- **Hostname**: `development.openchoreoapis.localhost`
- **Path**: `/inventorybackend/*`
- **URLRewrite**: Strips `/inventorybackend` prefix before forwarding to backend service
- **Target**: `inventorybackend:80` → backend pod `5000`

#### 🔹 Frontend Route
- **Hostname**: `inventoryfrontend-development.openchoreoapis.localhost`
- **Path**: `/`
- **Target**: `inventoryfrontend:80` → frontend pod `3000`

---

## 🔧 Troubleshooting

> 💡 **Tip**: Most issues stem from environment variable configuration or port mismatches. Check these first!

### ❌ Issue 1: Backend CORS Errors

**🔴 Symptom**: Browser console shows CORS policy blocking requests from frontend.

**🔍 Root Cause**: Backend `FRONTEND_URL` doesn't match the actual frontend origin.

**✅ Fix**:
1. The correct way to update environment variables in OpenChoreo is through `ComponentRelease` objects, not direct workload patches:

```bash
# Create a new ComponentRelease with updated env
kubectl get componentrelease inventorybackend-20260122-1 -n default -o yaml \
  | sed 's/^  name: inventorybackend-20260122-1$/  name: inventorybackend-20260122-2/' \
  | sed 's|value: http://localhost:3000|value: http://inventoryfrontend-development.openchoreoapis.localhost:19080|' \
  | grep -vE '^(  creationTimestamp:|  generation:|  resourceVersion:|  uid:)' \
  | kubectl apply -f -

# Update the ReleaseBinding to point to the new ComponentRelease
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge -p '{"spec":{"releaseName":"inventorybackend-20260122-2"}}'

# Restart the deployment to pick up the new env
kubectl rollout restart deploy inventorybackend-development-<hash> -n $DATAPLANE_NS
```

2. Verify CORS headers:
```bash
curl -sS -D - -o /dev/null \
  -H 'Origin: http://inventoryfrontend-development.openchoreoapis.localhost:19080' \
  http://development.openchoreoapis.localhost:19080/inventorybackend/api/products \
  | grep -i 'access-control-allow-origin'
```

**Expected Output:**
```
access-control-allow-origin: http://inventoryfrontend-development.openchoreoapis.localhost:19080
```

### ❌ Issue 2: Frontend "Connection Refused" or "Upstream Connect Error"

**🔴 Symptom**: Gateway returns 503 or connection refused when accessing frontend.

**🔍 Root Cause**: OpenChoreo `Component` parameter `port` doesn't match the container's listening port. The Service `targetPort` is generated from this parameter.

**✅ Fix**:
1. Create a new ComponentRelease with the correct port:

```bash
# Create ComponentRelease with port: 3000
kubectl get componentrelease inventoryfrontend-20260122-1 -n default -o yaml \
  | sed 's/^  name: inventoryfrontend-20260122-1$/  name: inventoryfrontend-20260122-2/' \
  | sed 's/^      port: 80$/      port: 3000/' \
  | grep -vE '^(  creationTimestamp:|  generation:|  resourceVersion:|  uid:)' \
  | kubectl apply -f -

# Force ReleaseBinding reconcile
kubectl annotate releasebinding inventoryfrontend-development -n default \
  openchoreo.dev/force-reconcile="$(date +%s)" --overwrite
```

2. Verify Service targetPort:
```bash
kubectl get svc inventoryfrontend -n $DATAPLANE_NS -o jsonpath='{.spec.ports[0].targetPort}'
```

**Expected Output:** `3000`

3. Test connectivity:
```bash
curl -I http://inventoryfrontend-development.openchoreoapis.localhost:19080/
```

**Expected Output:** `HTTP/1.1 200 OK`

### ❌ Issue 3: Database PVC Not Binding

**🔴 Symptom**: StatefulSet pod stuck in Pending state, PVC in "Pending" status.

**🔍 Root Cause**: StorageClass mismatch or not available in cluster.

**✅ Fix**:
1. Check available StorageClasses:
```bash
kubectl get storageclass
```

2. Update the ComponentType or Component to use the correct StorageClass (e.g., `local-path` for k3d):
```bash
kubectl patch component inventorydatabase -n default \
  --type=merge -p '{"spec":{"parameters":{"storageClassName":"local-path"}}}'
```

3. Delete and recreate the StatefulSet to rebind PVC:
```bash
kubectl delete statefulset inventorydatabase-development-<hash> -n $DATAPLANE_NS
# OpenChoreo will recreate it automatically
```

### ❌ Issue 4: Database Connection Failed

**🔴 Symptom**: Backend logs show "connection refused" or "could not connect to server".

**🔍 Root Cause**: Incorrect `DATABASE_URL` or database service not ready.

**✅ Fix**:
1. Find the exact database service name:
```bash
kubectl get svc -n $DATAPLANE_NS | grep inventorydatabase
```

2. Update backend `DATABASE_URL` via ComponentRelease (as shown in Issue 1).

3. Verify database is running and accepting connections:
```bash
DB_POD=$(kubectl get pods -n $DATAPLANE_NS -l openchoreo.dev/component=inventorydatabase -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n $DATAPLANE_NS $DB_POD -- pg_isready -U postgres
```

**Expected Output:** `accepting connections`

### ❌ Issue 5: Environment Variables Not Updating

**🔴 Symptom**: After patching Workload env, the pod still has old values.

**🔍 Root Cause**: OpenChoreo uses `envFrom` with ConfigMaps generated by the `Release` controller. The env source is the `ComponentRelease.spec.workload.containers[].env`, not the `Workload.spec.containers[].env`.

**✅ Fix**: Always update environment variables by creating a new `ComponentRelease` (see Issue 1 for detailed steps).

> ⚠️ **Important**: Never patch `Workload` directly for env changes. Always use `ComponentRelease`.

---

## 🎯 Key Learnings

### 1️⃣ OpenChoreo Resource Hierarchy
```
ComponentRelease (source of truth for env/config)
       ↓
ReleaseBinding (points to a ComponentRelease)
       ↓
Release (rendered resources for dataplane)
       ↓
Dataplane Resources (ConfigMap, Deployment, Service, etc.)
```

> 💡 **Key Insight**: `ComponentRelease` is the source of truth for all component configuration.

### 2️⃣ Environment Variable Management
- **DO NOT** patch `Workload.spec.containers[].env` directly
- **DO** create a new `ComponentRelease` with updated `spec.workload.containers[].env`
- **DO** update the `ReleaseBinding.spec.releaseName` to point to the new ComponentRelease
- ConfigMaps are automatically generated from ComponentRelease and are immutable

> ⚠️ **Critical**: Direct Workload patches are ignored. Always update via ComponentRelease.

### 3️⃣ Port Configuration
- The `Component.spec.parameters.port` must match the container's listening port
- This parameter is used to generate `Service.spec.ports[].targetPort`
- For Next.js: use `3000`, not `80`
- For Express: use `5000` (or your configured port)

### 4️⃣ CORS Configuration
- Backend must set `Access-Control-Allow-Origin` to match the **exact** frontend origin (protocol + hostname + port)
- With `credentials: true`, wildcards are not allowed
- Use the OpenChoreo gateway hostname, not localhost

### 5️⃣ Build-time vs Runtime Configuration
- **Frontend** environment variables starting with `NEXT_PUBLIC_` are baked into the build
- **Backend** environment variables are injected at runtime via ConfigMaps
- Frontend `.env.production` must be set **before** building the Docker image

---

## 🌐 Access URLs

After successful deployment:

| Service | URL | Purpose |
|---------|-----|----------|
| 🎨 **Frontend** | http://inventoryfrontend-development.openchoreoapis.localhost:19080/ | Web UI |
| 📊 **Backend API** | http://development.openchoreoapis.localhost:19080/inventorybackend/api/products | Get products |
| ❤️ **Backend Health** | http://development.openchoreoapis.localhost:19080/inventorybackend/health | Health check |

---

## 🗄️ Database Schema

The PostgreSQL database uses the following schema:

```sql
-- Products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    category VARCHAR(100),
    barcode VARCHAR(100) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sample data
INSERT INTO products (name, description, price, stock_quantity, category, barcode)
VALUES 
    ('Laptop', 'High-performance laptop', 999.99, 50, 'Electronics', 'ELEC-001'),
    ('Mouse', 'Wireless mouse', 29.99, 200, 'Electronics', 'ELEC-002'),
    ('Keyboard', 'Mechanical keyboard', 79.99, 150, 'Electronics', 'ELEC-003'),
    ('Monitor', '27-inch 4K monitor', 399.99, 75, 'Electronics', 'ELEC-004'),
    ('Desk Chair', 'Ergonomic office chair', 249.99, 40, 'Furniture', 'FURN-001');
```

---

## 🚀 Next Steps

### 💡 Enhancements
1. **Add Authentication**: Integrate OpenChoreo managed auth for the frontend
2. **Database Backups**: Implement automated PostgreSQL backups
3. **Monitoring**: Add observability (logs, metrics, traces)
4. **CI/CD Pipeline**: Automate builds and deployments
5. **Multi-environment**: Deploy to staging and production environments
6. **Secret Management**: Use external secrets for sensitive data
7. **High Availability**: Scale backend replicas, add database replication

### ✅ Production Checklist
- [ ] Use production-grade StorageClass (not local-path)
- [ ] Configure resource limits and requests appropriately
- [ ] Set up database connection pooling
- [ ] Enable HTTPS/TLS for gateway routes
- [ ] Implement proper secret management (not hardcoded passwords)
- [ ] Add health checks and readiness probes
- [ ] Configure autoscaling for backend
- [ ] Set up centralized logging
- [ ] Implement monitoring and alerting
- [ ] Add database migration strategy

---

## 📚 References

| Resource | Link |
|----------|------|
| 📖 OpenChoreo Documentation | [wso2.com/choreo/docs](https://wso2.com/choreo/docs/) |
| 🔧 OpenChoreo ComponentType Spec | [GitHub](https://github.com/wso2/choreo-control-plane) |
| 🐘 PostgreSQL Docker Image | [Docker Hub](https://hub.docker.com/_/postgres) |
| ⚛️ Next.js Environment Variables | [Next.js Docs](https://nextjs.org/docs/app/building-your-application/configuring/environment-variables) |
| 🔐 Express CORS Configuration | [Express Docs](https://expressjs.com/en/resources/middleware/cors.html) |

---

<div align="center">

### ✨ Deployment Completed Successfully

**📅 Date**: January 22, 2026  
**🔧 OpenChoreo Version**: v0.11.0  
**👤 Deployment**: Automated via OpenChoreo platform

---

**Made with ❤️ using OpenChoreo**

</div>
