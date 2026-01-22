# 📚 Complete Guide: Deploying a Three-Tier Application on OpenChoreo

> **A comprehensive walkthrough of deploying a production-ready inventory management system with PostgreSQL, Express.js backend, and Next.js frontend on OpenChoreo's single-cluster architecture**

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Application Structure](#application-structure)
3. [OpenChoreo Workflow & Concepts](#openchoreo-workflow--concepts)
4. [Database Layer: Two Connection Methods](#database-layer-two-connection-methods)
5. [Backend Service Deployment](#backend-service-deployment)
6. [Frontend Application Deployment](#frontend-application-deployment)
7. [Complete Command Reference](#complete-command-reference)
8. [Troubleshooting Journey](#troubleshooting-journey)
9. [Production Considerations](#production-considerations)

---

## 🏗️ Architecture Overview

### Three-Tier Application Stack

```
┌─────────────────────────────────────────────────────────────┐
│                        FRONTEND TIER                         │
│  Next.js 14 App Router + TypeScript + Tailwind CSS          │
│  Port: 3000 (Container) → 80 (Service)                      │
│  Gateway: inventoryfrontend-development.openchoreoapis...   │
└─────────────────────────────────────────────────────────────┘
                              ↓ HTTP
┌─────────────────────────────────────────────────────────────┐
│                        BACKEND TIER                          │
│  Express.js + TypeScript + PostgreSQL (pg library)          │
│  Port: 5000                                                  │
│  Gateway: development.openchoreoapis.../inventorybackend/*  │
│  CORS: Configured for frontend origin                       │
└─────────────────────────────────────────────────────────────┘
                              ↓ TCP 5432/6543
┌─────────────────────────────────────────────────────────────┐
│                        DATABASE TIER                         │
│  Method 1: OpenChoreo-managed PostgreSQL 15 (StatefulSet)  │
│  Method 2: Supabase Cloud PostgreSQL (External)            │
│  Persistent Storage: local-path provisioner / Cloud PVC    │
└─────────────────────────────────────────────────────────────┘
```

### OpenChoreo Single-Cluster Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    CONTROL PLANE (default ns)                     │
│                                                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Component   │  │ Component    │  │ Component    │           │
│  │  Type        │  │              │  │  Release     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                  │                  │                   │
│         └──────────────────┴──────────────────┘                   │
│                            │                                      │
│                   ┌────────▼────────┐                            │
│                   │ ReleaseBinding  │                            │
│                   └────────┬────────┘                            │
│                            │                                      │
│                   ┌────────▼────────┐                            │
│                   │    Release      │                            │
│                   └────────┬────────┘                            │
└────────────────────────────┼─────────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────────┐
│        DATA PLANE (dp-default-inventorysyst-development-...)      │
│                                                                    │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐     │
│  │  StatefulSet   │  │  Deployment    │  │  Deployment    │     │
│  │  (Database)    │  │  (Backend)     │  │  (Frontend)    │     │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘     │
│           │                   │                    │              │
│  ┌────────▼───────┐  ┌────────▼───────┐  ┌────────▼───────┐     │
│  │  Service       │  │  Service       │  │  Service       │     │
│  │  ClusterIP     │  │  ClusterIP     │  │  ClusterIP     │     │
│  └────────────────┘  └────────────────┘  └────────────────┘     │
│                                                                    │
│  ┌────────────────┐  ┌────────────────┐                          │
│  │  ConfigMap     │  │  ConfigMap     │                          │
│  │  (DB Env)      │  │  (Backend Env) │                          │
│  └────────────────┘  └────────────────┘                          │
│                                                                    │
│  ┌────────────────┐                                               │
│  │  PVC           │                                               │
│  │  (DB Storage)  │                                               │
│  └────────────────┘                                               │
└────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Application Structure

### Complete Codebase Organization

```
openchoreo-3-tier-demo-pos-application/
│
├── backend/                          # Express.js API Service
│   ├── src/
│   │   ├── server.ts                # Main Express app with CORS & routes
│   │   └── db.ts                    # PostgreSQL connection pool
│   ├── package.json                 # Dependencies: express, pg, cors, dotenv
│   ├── tsconfig.json                # TypeScript configuration
│   └── Dockerfile                   # Multi-stage Node.js container
│
├── frontend/                         # Next.js Web Application
│   ├── app/
│   │   ├── layout.tsx               # Root layout
│   │   └── page.tsx                 # Main inventory UI
│   ├── package.json                 # Dependencies: next, react, tailwind
│   ├── tsconfig.json
│   ├── tailwind.config.ts
│   └── Dockerfile                   # Multi-stage Next.js container
│
├── database/
│   └── init.sql                     # PostgreSQL schema + sample data
│
├── openchoreo-abstractions/
│   └── componenttypes/
│       └── postgres-database.       # Custom PostgreSQL ComponentType
│           componenttype.yaml
│
└── scripts/
    └── setup-supabase.sh            # Automated Supabase integration
```

### Key Code Snippets

#### Backend Database Connection (`backend/src/db.ts`)

```typescript
import { Pool } from 'pg';

// Single connection string from environment variable
// Works identically for both local and Supabase databases
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

pool.on('connect', () => {
  console.log('✅ Database connected successfully');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected database error:', err);
  process.exit(-1);
});

export default pool;
```

**Key Design Decision**: Using a single `DATABASE_URL` environment variable makes the backend database-agnostic. The same code works with:
- Local OpenChoreo PostgreSQL StatefulSet
- Supabase cloud database
- Any PostgreSQL-compatible service

#### Backend API Routes (`backend/src/server.ts`)

```typescript
import express from 'express';
import cors from 'cors';
import pool from './db';

const app = express();

// CORS configuration using environment variable
app.use(cors({
  origin: process.env.FRONTEND_URL || '*',
  credentials: true,
}));

app.use(express.json());

// GET /api/products - List all products
app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM products ORDER BY created_at DESC'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

// POST /api/products - Create new product
app.post('/api/products', async (req, res) => {
  const { name, description, sku, quantity, price } = req.body;
  
  try {
    const result = await pool.query(
      'INSERT INTO products (name, description, sku, quantity, price) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [name, description, sku, quantity, price]
    );
    res.status(201).json(result.rows[0]);
  } catch (error: any) {
    if (error.code === '23505') { // Unique constraint violation
      res.status(409).json({ error: 'Product with this SKU already exists' });
    } else {
      console.error('Error creating product:', error);
      res.status(500).json({ error: 'Failed to create product' });
    }
  }
});

// PUT /api/products/:id - Update product
app.put('/api/products/:id', async (req, res) => {
  const { id } = req.params;
  const { name, description, sku, quantity, price } = req.body;
  
  try {
    const result = await pool.query(
      'UPDATE products SET name = $1, description = $2, sku = $3, quantity = $4, price = $5 WHERE id = $6 RETURNING *',
      [name, description, sku, quantity, price, id]
    );
    
    if (result.rows.length === 0) {
      res.status(404).json({ error: 'Product not found' });
    } else {
      res.json(result.rows[0]);
    }
  } catch (error) {
    console.error('Error updating product:', error);
    res.status(500).json({ error: 'Failed to update product' });
  }
});

// DELETE /api/products/:id - Delete product
app.delete('/api/products/:id', async (req, res) => {
  const { id } = req.params;
  
  try {
    const result = await pool.query(
      'DELETE FROM products WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      res.status(404).json({ error: 'Product not found' });
    } else {
      res.json({ message: 'Product deleted successfully' });
    }
  } catch (error) {
    console.error('Error deleting product:', error);
    res.status(500).json({ error: 'Failed to delete product' });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server is running on http://localhost:${PORT}`);
});
```

**PostgreSQL Compatibility**: All queries use standard PostgreSQL syntax:
- ✅ Parameterized queries (`$1`, `$2`) prevent SQL injection
- ✅ `RETURNING *` clause for atomic operations
- ✅ Error code handling (`23505` for unique constraints)
- ✅ 100% compatible with both local and Supabase PostgreSQL

#### Database Schema (`database/init.sql`)

```sql
-- Database initialization script for Inventory Management System
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(100) UNIQUE NOT NULL,
    quantity INTEGER DEFAULT 0,
    price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster SKU lookups
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);

-- Sample data
INSERT INTO products (name, description, sku, quantity, price) 
VALUES 
    ('Laptop', 'High-performance laptop for business use', 'LAP-001', 15, 999.99),
    ('Wireless Mouse', 'Ergonomic wireless mouse with USB receiver', 'MOU-001', 50, 29.99),
    ('Keyboard', 'Mechanical keyboard with RGB lighting', 'KEY-001', 30, 79.99)
ON CONFLICT (sku) DO NOTHING;
```

---

## 🔄 OpenChoreo Workflow & Concepts

### Core Custom Resource Definitions (CRDs)

OpenChoreo uses a declarative approach with five main CRDs:

#### 1. **ComponentType** - Reusable Templates

Defines the blueprint for how a type of component should be deployed.

**Example: PostgreSQL Database ComponentType**

```yaml
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentType
metadata:
  name: postgres-database
  namespace: default
spec:
  type: statefulset/postgres-database
  deploymentModel: statefulset
  
  # Build configuration (not used for databases, but required)
  build:
    image: postgres:15-alpine
  
  # Runtime configuration template
  runtime:
    # Environment variables passed to the container
    envVariables:
      - name: POSTGRES_DB
        valueFrom:
          componentReleaseValue: POSTGRES_DB
      - name: POSTGRES_USER
        valueFrom:
          componentReleaseValue: POSTGRES_USER
      - name: POSTGRES_PASSWORD
        valueFrom:
          componentReleaseValue: POSTGRES_PASSWORD
    
    # Container port configuration
    containerPorts:
      - name: postgres
        containerPort: 5432
        protocol: TCP
    
    # Health checks
    livenessProbe:
      tcpSocket:
        port: postgres
      initialDelaySeconds: 30
      periodSeconds: 10
    
    readinessProbe:
      exec:
        command:
          - pg_isready
          - -U
          - postgres
      initialDelaySeconds: 5
      periodSeconds: 5
    
    # Resource limits
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  # Workload-specific configuration
  workload:
    statefulset:
      # Service configuration
      service:
        type: ClusterIP
        ports:
          - name: postgres
            port: 5432
            targetPort: postgres
      
      # Persistent storage
      volumeClaimTemplates:
        - metadata:
            name: postgres-data
          spec:
            accessModes:
              - ReadWriteOnce
            storageClassName: local-path
            resources:
              requests:
                storage: 1Gi
      
      # Volume mounts
      volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
      
      # High availability settings
      podManagementPolicy: OrderedReady
      updateStrategy:
        type: RollingUpdate
      
      # Pod disruption budget for resilience
      podDisruptionBudget:
        minAvailable: 1
```

**Key Concepts**:
- `deploymentModel: statefulset` - Creates StatefulSet instead of Deployment
- `volumeClaimTemplates` - Persistent storage that survives pod restarts
- `podManagementPolicy: OrderedReady` - Ensures ordered, graceful deployment
- Health probes ensure database is ready before accepting connections

#### 2. **Component** - Application Instance

Represents a single application component (frontend, backend, or database).

**Example: Backend Component**

```yaml
apiVersion: core.openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: inventorybackend
  namespace: default
  labels:
    openchoreo.dev/project: inventorysystem
spec:
  name: inventorybackend
  type: service
  projectName: inventorysystem
  
  # Git repository configuration
  repository:
    url: https://github.com/savisaluwadana/openchoreo-3-tier-demo-pos-application
    branch: main
    path: backend  # Subdirectory in repo
  
  # Build configuration
  build:
    buildpack: nodejs
    dockerfile: backend/Dockerfile
```

**Component Types**:
- `service` - Backend API services
- `webapp` - Frontend applications
- `statefulset/postgres-database` - Custom database type

#### 3. **ComponentRelease** - Versioned Configuration

Immutable snapshot of component configuration. Each change requires a new release.

**Example: Backend ComponentRelease with Environment Variables**

```yaml
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorybackend-20260122-232210-supabase-pooler
  namespace: default
  labels:
    openchoreo.dev/component: inventorybackend
    openchoreo.dev/project: inventorysystem
spec:
  componentName: inventorybackend
  
  # Container image from build
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  
  # Environment variables injected into pods
  envVariables:
    - name: PORT
      value: "5000"
    
    - name: NODE_ENV
      value: "production"
    
    - name: FRONTEND_URL
      value: "http://inventoryfrontend-development.openchoreoapis.localhost:19080"
    
    - name: DATABASE_URL
      value: "
  
  # Port configuration
  ports:
    - name: http
      containerPort: 5000
      protocol: TCP
```

**Critical Pattern**: ComponentReleases are **immutable**. To change configuration:
1. Create new ComponentRelease with updated values
2. Update ReleaseBinding to reference new release
3. OpenChoreo automatically applies changes to dataplane

**Release Naming Convention**:
```
<component>-<date>-<time>-<suffix>
inventorybackend-20260122-232210-supabase-pooler
└──────┬──────┘ └───┬──┘ └─┬─┘ └───────┬────────┘
   component    date   time     descriptor
```

#### 4. **ReleaseBinding** - Environment Association

Binds a ComponentRelease to a specific environment.

```yaml
apiVersion: core.openchoreo.dev/v1alpha1
kind: ReleaseBinding
metadata:
  name: inventorybackend-development
  namespace: default
  labels:
    openchoreo.dev/component: inventorybackend
    openchoreo.dev/project: inventorysystem
    openchoreo.dev/environment: development
spec:
  componentName: inventorybackend
  componentReleaseName: inventorybackend-20260122-232210-supabase-pooler
  environmentName: development
  releaseName: inventorybackend-development
```

**Update Pattern**:
```bash
# Switch to a new release
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge \
  -p '{"spec":{"releaseName":"inventorybackend-20260122-232210-supabase-pooler"}}'
```

#### 5. **Release** - Dataplane Materialization

Automatically generated by OpenChoreo. Contains actual Kubernetes resources.

```yaml
apiVersion: core.openchoreo.dev/v1alpha1
kind: Release
metadata:
  name: inventorybackend-development
  namespace: default
spec:
  resources:
    # ConfigMap with environment variables
    - kind: ConfigMap
      object:
        data:
          PORT: "5000"
          NODE_ENV: "production"
          FRONTEND_URL: "http://inventoryfrontend-development.openchoreoapis.localhost:19080"
          DATABASE_URL: "postgresql://postgres.vnqpwialdwdgqcvymhox:***@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres"
    
    # Deployment specification
    - kind: Deployment
      object:
        spec:
          replicas: 1
          selector:
            matchLabels:
              openchoreo.dev/component-uid: dd2aa576-2796-4431-a1bd-eb7f17c85a3c
          template:
            spec:
              containers:
                - name: inventorybackend
                  image: ghcr.io/savisaluwadana/inventorybackend:latest
                  envFrom:
                    - configMapRef:
                        name: inventorybackend-development-main-env-configs-bd50d488
    
    # Service for internal networking
    - kind: Service
      object:
        spec:
          type: ClusterIP
          ports:
            - port: 5000
              targetPort: 5000
```

### OpenChoreo Deployment Flow

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. USER CREATES COMPONENT                                        │
│    kubectl apply -f component.yaml                               │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│ 2. USER CREATES COMPONENTRELEASE                                 │
│    kubectl apply -f componentrelease.yaml                        │
│    (contains: image, env vars, ports)                            │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│ 3. USER CREATES RELEASEBINDING                                   │
│    kubectl apply -f releasebinding.yaml                          │
│    (binds: ComponentRelease → Environment)                       │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│ 4. OPENCHOREO CONTROLLER CREATES RELEASE                         │
│    Automatically generates Release resource                      │
│    (contains: ConfigMap, Deployment, Service specs)              │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│ 5. OPENCHOREO CREATES DATAPLANE RESOURCES                        │
│    Namespace: dp-default-inventorysyst-development-e51b7a18      │
│    - ConfigMap (environment variables)                           │
│    - Deployment (pod template)                                   │
│    - Service (networking)                                        │
│    - Pod (running container)                                     │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│ 6. OPENCHOREO GATEWAY ROUTES TRAFFIC                             │
│    Ingress routing based on hostname and path                    │
│    Example: development.openchoreoapis.localhost:19080/          │
│             inventorybackend/* → backend service                 │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Database Layer: Two Connection Methods

### Method 1: OpenChoreo-Managed PostgreSQL (Local StatefulSet)

**Architecture**: Database runs as a StatefulSet within the same Kubernetes cluster.

#### Step 1: Create Custom PostgreSQL ComponentType

```bash
# Apply the custom ComponentType
kubectl apply -f openchoreo-abstractions/componenttypes/postgres-database.componenttype.yaml
```

**ComponentType YAML** (see full version above in ComponentType section)

Key features:
- ✅ StatefulSet for stable network identity
- ✅ PersistentVolumeClaim for data durability
- ✅ Health probes (liveness + readiness)
- ✅ Resource limits for cluster stability
- ✅ PodDisruptionBudget for high availability

#### Step 2: Create Database Component

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: inventorydatabase
  namespace: default
  labels:
    openchoreo.dev/project: inventorysystem
spec:
  name: inventorydatabase
  type: statefulset/postgres-database
  projectName: inventorysystem
EOF
```

#### Step 3: Create Database ComponentRelease

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorydatabase-v1
  namespace: default
  labels:
    openchoreo.dev/component: inventorydatabase
    openchoreo.dev/project: inventorysystem
spec:
  componentName: inventorydatabase
  image: postgres:15-alpine
  
  envVariables:
    - name: POSTGRES_DB
      value: "inventorydb"
    - name: POSTGRES_USER
      value: "postgres"
    - name: POSTGRES_PASSWORD
      value: "postgrespassword"
  
  ports:
    - name: postgres
      containerPort: 5432
      protocol: TCP
EOF
```

#### Step 4: Create ReleaseBinding

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ReleaseBinding
metadata:
  name: inventorydatabase-development
  namespace: default
  labels:
    openchoreo.dev/component: inventorydatabase
    openchoreo.dev/project: inventorysystem
    openchoreo.dev/environment: development
spec:
  componentName: inventorydatabase
  componentReleaseName: inventorydatabase-v1
  environmentName: development
  releaseName: inventorydatabase-development
EOF
```

#### Step 5: Verify Database Deployment

```bash
# Wait for StatefulSet to be ready
kubectl get statefulsets -n dp-default-inventorysyst-development-e51b7a18

# Expected output:
# NAME                                     READY   AGE
# inventorydatabase-development-9a30de76   1/1     5m

# Check pod status
kubectl get pods -n dp-default-inventorysyst-development-e51b7a18 | grep inventorydatabase

# Expected output:
# inventorydatabase-development-9a30de76-0   1/1   Running   0   5m

# Verify PersistentVolumeClaim
kubectl get pvc -n dp-default-inventorysyst-development-e51b7a18

# Expected output:
# NAME                                           STATUS   VOLUME     CAPACITY   STORAGECLASS
# postgres-data-inventorydatabase-development-0  Bound    pvc-xxxxx  1Gi        local-path
```

#### Step 6: Initialize Database Schema

```bash
# Copy init.sql to pod
kubectl cp database/init.sql \
  dp-default-inventorysyst-development-e51b7a18/inventorydatabase-development-9a30de76-0:/tmp/init.sql

# Execute SQL script
kubectl exec -n dp-default-inventorysyst-development-e51b7a18 \
  inventorydatabase-development-9a30de76-0 \
  -- psql -U postgres -d inventorydb -f /tmp/init.sql
```

#### Step 7: Connect Backend to Local Database

**Backend DATABASE_URL**:
```
postgresql://postgres:postgrespassword@inventorydatabase-development.dp-default-inventorysyst-development-e51b7a18.svc.cluster.local:5432/inventorydb
```

**Service DNS Pattern**:
```
<service-name>.<namespace>.svc.cluster.local:<port>
```

**Update Backend ComponentRelease**:
```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorybackend-20260122-1
  namespace: default
  labels:
    openchoreo.dev/component: inventorybackend
    openchoreo.dev/project: inventorysystem
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  
  envVariables:
    - name: PORT
      value: "5000"
    - name: DATABASE_URL
      value: "postgresql://postgres:postgrespassword@inventorydatabase-development.dp-default-inventorysyst-development-e51b7a18.svc.cluster.local:5432/inventorydb"
    - name: FRONTEND_URL
      value: "http://inventoryfrontend-development.openchoreoapis.localhost:19080"
EOF
```

**Advantages**:
- ✅ Complete control over database configuration
- ✅ Data stays within Kubernetes cluster
- ✅ No external dependencies
- ✅ Zero network latency (same cluster)
- ✅ Cost-effective for development

**Disadvantages**:
- ❌ Requires cluster storage management
- ❌ Manual backup/restore procedures
- ❌ Limited to cluster resources
- ❌ No managed database features (auto-scaling, point-in-time recovery)

---

### Method 2: Supabase Cloud PostgreSQL (External Database)

**Architecture**: Database runs in Supabase cloud, backend connects over internet.

#### Connection Architecture Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│ DIRECT CONNECTION (Port 5432) - IPv6 ❌                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Backend Pod                  Internet                          │
│  (IPv4 only) ──────X──────→  db.*.supabase.co:5432             │
│                               (Resolves to IPv6)                │
│                                                                  │
│  ERROR: ENETUNREACH 2406:da18:243:741a:5869:e9c7:edff:1c67     │
│  k3d cluster doesn't support IPv6 outbound connections         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ CONNECTION POOLER (Port 6543) - IPv4 ✅                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Backend Pod                  Internet                          │
│  (IPv4) ──────✓──────→  aws-1-ap-southeast-1.pooler.          │
│                         supabase.com:6543                       │
│                         (IPv4-compatible)                       │
│                                                                  │
│  SUCCESS: Connection established via connection pooler          │
│  Optimized for serverless and IPv4-only environments           │
└─────────────────────────────────────────────────────────────────┘
```

#### Step 1: Obtain Supabase Connection String

**From Supabase Dashboard**:
1. Navigate to: **Settings** → **Database**
2. Scroll to: **Connection pooling** tab
3. Copy connection string:

```
postgresql://postgres.[project-ref]:[password]@aws-1-[region].pooler.supabase.com:6543/postgres
```

**Example**:
```
postgresql://postgres.vnqpwialdwdgqcvymhox:Sudusalu@123@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres
```

**Connection Pooler Regions**:
- `aws-0-us-east-1` - US East (Virginia)
- `aws-0-us-west-1` - US West (California)
- `aws-0-eu-west-1` - EU West (Ireland)
- `aws-1-ap-southeast-1` - Asia Pacific (Singapore)
- `aws-0-ap-south-1` - Asia Pacific (Mumbai)

#### Step 2: Create ComponentRelease with Supabase URL

```bash
# Get current ComponentRelease
kubectl get componentrelease inventorybackend-20260122-2 -n default -o yaml > /tmp/current-release.yaml

# Create new release with Supabase connection
NEW_RELEASE="inventorybackend-20260122-232210-supabase-pooler"

cat > /tmp/new-release.yaml <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: ${NEW_RELEASE}
  namespace: default
  labels:
    openchoreo.dev/component: inventorybackend
    openchoreo.dev/project: inventorysystem
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  
  envVariables:
    - name: PORT
      value: "5000"
    - name: NODE_ENV
      value: "production"
    - name: FRONTEND_URL
      value: "http://inventoryfrontend-development.openchoreoapis.localhost:19080"
    - name: DATABASE_URL
      value: "
  
  ports:
    - name: http
      containerPort: 5000
      protocol: TCP
EOF

# Apply new release
kubectl apply -f /tmp/new-release.yaml
```

#### Step 3: Update ReleaseBinding

```bash
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge \
  -p "{\"spec\":{\"releaseName\":\"${NEW_RELEASE}\"}}"
```

#### Step 4: Verify Release Propagation

```bash
# Wait for Release to sync (5 seconds)
sleep 5

# Verify Release has correct DATABASE_URL
kubectl get release inventorybackend-development -n default \
  -o jsonpath='{.spec.resources[0].object.data.DATABASE_URL}'

# Expected output:
# postgresql://postgres.vnqpwialdwdgqcvymhox:***@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres
```

#### Step 5: Restart Backend Deployment

```bash
# Restart deployment to pick up new environment variables
kubectl rollout restart deploy inventorybackend-development-9ebcb79a \
  -n dp-default-inventorysyst-development-e51b7a18

# Wait for new pod
sleep 10

# Get new pod name
POD_NAME=$(kubectl get pods -n dp-default-inventorysyst-development-e51b7a18 \
  -l openchoreo.dev/component-uid=dd2aa576-2796-4431-a1bd-eb7f17c85a3c \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')

echo "New pod: $POD_NAME"
```

#### Step 6: Verify Supabase Connection

```bash
# Check DATABASE_URL in pod
kubectl exec -n dp-default-inventorysyst-development-e51b7a18 $POD_NAME \
  -- printenv DATABASE_URL

# Check backend logs for connection success
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 $POD_NAME --tail=30

# Expected output:
# 🚀 Server is running on http://localhost:5000
# ✅ Database connected successfully

# Test API endpoint
curl -s http://development.openchoreoapis.localhost:19080/inventorybackend/api/products | jq
```

**Expected Response**:
```json
[
  {
    "id": 1,
    "name": "Laptop",
    "description": "High-performance laptop for business use",
    "sku": "LAP-001",
    "quantity": 15,
    "price": "999.99",
    "created_at": "2026-01-22T17:43:35.910Z"
  },
  {
    "id": 2,
    "name": "Wireless Mouse",
    "description": "Ergonomic wireless mouse with USB receiver",
    "sku": "MOU-001",
    "quantity": 50,
    "price": "29.99",
    "created_at": "2026-01-22T17:43:35.910Z"
  }
]
```

#### Step 7: Initialize Supabase Database Schema

**In Supabase Dashboard**:
1. Navigate to: **SQL Editor**
2. Create new query
3. Paste content from `database/init.sql`
4. Execute

**Or via psql**:
```bash
# Install PostgreSQL client (macOS)
brew install postgresql

# Connect to Supabase
psql "postgresql://postgres.vnqpwialdwdgqcvymhox:Sudusalu@123@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres"

# In psql:
\i database/init.sql
\dt
SELECT * FROM products;
\q
```

**Advantages**:
- ✅ Managed service (auto-backups, scaling, monitoring)
- ✅ Built-in features (auth, storage, real-time subscriptions)
- ✅ Point-in-time recovery
- ✅ Global CDN for read replicas
- ✅ Web-based SQL editor and dashboard

**Disadvantages**:
- ❌ Network latency (internet roundtrip)
- ❌ Requires internet connectivity
- ❌ Cost for production usage
- ❌ External dependency
- ❌ IPv6 compatibility issues with some Kubernetes setups

---

## 🔧 Backend Service Deployment

### Step 1: Create Backend Component

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: inventorybackend
  namespace: default
  labels:
    openchoreo.dev/project: inventorysystem
spec:
  name: inventorybackend
  type: service
  projectName: inventorysystem
  
  repository:
    url: https://github.com/savisaluwadana/openchoreo-3-tier-demo-pos-application
    branch: main
    path: backend
  
  build:
    buildpack: nodejs
    dockerfile: backend/Dockerfile
EOF
```

### Step 2: Build Backend Container Image

```bash
# Navigate to backend directory
cd backend

# Build Docker image
docker build -t ghcr.io/savisaluwadana/inventorybackend:latest .

# Push to registry
docker push ghcr.io/savisaluwadana/inventorybackend:latest
```

**Backend Dockerfile**:
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./

ENV NODE_ENV=production
EXPOSE 5000

CMD ["node", "dist/server.js"]
```

### Step 3: Create ComponentRelease

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorybackend-20260122-2
  namespace: default
  labels:
    openchoreo.dev/component: inventorybackend
    openchoreo.dev/project: inventorysystem
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  
  envVariables:
    - name: PORT
      value: "5000"
    - name: NODE_ENV
      value: "production"
    - name: DATABASE_URL
      value: "postgresql://postgres:postgrespassword@inventorydatabase-development.dp-default-inventorysyst-development-e51b7a18.svc.cluster.local:5432/inventorydb"
    - name: FRONTEND_URL
      value: "http://inventoryfrontend-development.openchoreoapis.localhost:19080"
  
  ports:
    - name: http
      containerPort: 5000
      protocol: TCP
EOF
```

### Step 4: Create ReleaseBinding

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ReleaseBinding
metadata:
  name: inventorybackend-development
  namespace: default
  labels:
    openchoreo.dev/component: inventorybackend
    openchoreo.dev/project: inventorysystem
    openchoreo.dev/environment: development
spec:
  componentName: inventorybackend
  componentReleaseName: inventorybackend-20260122-2
  environmentName: development
  releaseName: inventorybackend-development
EOF
```

### Step 5: Verify Backend Deployment

```bash
# Check deployment
kubectl get deploy -n dp-default-inventorysyst-development-e51b7a18 | grep inventorybackend

# Check pods
kubectl get pods -n dp-default-inventorysyst-development-e51b7a18 -l openchoreo.dev/component=inventorybackend

# Check service
kubectl get svc -n dp-default-inventorysyst-development-e51b7a18 | grep inventorybackend

# Check logs
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 \
  -l openchoreo.dev/component=inventorybackend \
  --tail=50

# Expected log output:
# 🚀 Server is running on http://localhost:5000
# ✅ Database connected successfully
```

### Step 6: Test Backend API

```bash
# Test through OpenChoreo gateway
curl http://development.openchoreoapis.localhost:19080/inventorybackend/api/products

# Test CORS headers
curl -I -H "Origin: http://inventoryfrontend-development.openchoreoapis.localhost:19080" \
  http://development.openchoreoapis.localhost:19080/inventorybackend/api/products

# Expected CORS header:
# access-control-allow-origin: http://inventoryfrontend-development.openchoreoapis.localhost:19080
```

---

## 🌐 Frontend Application Deployment

### Step 1: Create Frontend Component

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: inventoryfrontend
  namespace: default
  labels:
    openchoreo.dev/project: inventorysystem
spec:
  name: inventoryfrontend
  type: webapp
  projectName: inventorysystem
  
  repository:
    url: https://github.com/savisaluwadana/openchoreo-3-tier-demo-pos-application
    branch: main
    path: frontend
  
  build:
    buildpack: nextjs
    dockerfile: frontend/Dockerfile
EOF
```

### Step 2: Build Frontend Container Image

```bash
# Navigate to frontend directory
cd frontend

# Build Docker image
docker build -t ghcr.io/savisaluwadana/inventoryfrontend:latest .

# Push to registry
docker push ghcr.io/savisaluwadana/inventoryfrontend:latest
```

**Frontend Dockerfile**:
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine
WORKDIR /app

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["node", "server.js"]
```

### Step 3: Create ComponentRelease

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventoryfrontend-20260122-2
  namespace: default
  labels:
    openchoreo.dev/component: inventoryfrontend
    openchoreo.dev/project: inventorysystem
spec:
  componentName: inventoryfrontend
  image: ghcr.io/savisaluwadana/inventoryfrontend:latest
  
  envVariables:
    - name: NEXT_PUBLIC_API_URL
      value: "http://development.openchoreoapis.localhost:19080/inventorybackend"
  
  ports:
    - name: http
      containerPort: 3000  # CRITICAL: Must match container's listening port
      protocol: TCP
EOF
```

**Common Mistake**:
❌ Setting `containerPort: 80` when Next.js listens on `3000`
✅ Always match containerPort with the port your application listens on

### Step 4: Create ReleaseBinding

```bash
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ReleaseBinding
metadata:
  name: inventoryfrontend-development
  namespace: default
  labels:
    openchoreo.dev/component: inventoryfrontend
    openchoreo.dev/project: inventorysystem
    openchoreo.dev/environment: development
spec:
  componentName: inventoryfrontend
  componentReleaseName: inventoryfrontend-20260122-2
  environmentName: development
  releaseName: inventoryfrontend-development
EOF
```

### Step 5: Verify Frontend Deployment

```bash
# Check deployment
kubectl get deploy -n dp-default-inventorysyst-development-e51b7a18 | grep inventoryfrontend

# Check pods
kubectl get pods -n dp-default-inventorysyst-development-e51b7a18 -l openchoreo.dev/component=inventoryfrontend

# Check service
kubectl get svc -n dp-default-inventorysyst-development-e51b7a18 | grep inventoryfrontend

# Check logs
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 \
  -l openchoreo.dev/component=inventoryfrontend \
  --tail=50
```

### Step 6: Test Frontend

```bash
# Test HTTP response
curl -I http://inventoryfrontend-development.openchoreoapis.localhost:19080/

# Expected output:
# HTTP/1.1 200 OK
# content-type: text/html; charset=utf-8

# Open in browser
open http://inventoryfrontend-development.openchoreoapis.localhost:19080/
```

---

## 📜 Complete Command Reference

### Database Commands

#### Local PostgreSQL Database

```bash
# Create ComponentType
kubectl apply -f openchoreo-abstractions/componenttypes/postgres-database.componenttype.yaml

# Create Component
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: inventorydatabase
  namespace: default
spec:
  name: inventorydatabase
  type: statefulset/postgres-database
  projectName: inventorysystem
EOF

# Create ComponentRelease
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorydatabase-v1
  namespace: default
spec:
  componentName: inventorydatabase
  image: postgres:15-alpine
  envVariables:
    - name: POSTGRES_DB
      value: "inventorydb"
    - name: POSTGRES_USER
      value: "postgres"
    - name: POSTGRES_PASSWORD
      value: "postgrespassword"
  ports:
    - name: postgres
      containerPort: 5432
EOF

# Create ReleaseBinding
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ReleaseBinding
metadata:
  name: inventorydatabase-development
  namespace: default
spec:
  componentName: inventorydatabase
  componentReleaseName: inventorydatabase-v1
  environmentName: development
  releaseName: inventorydatabase-development
EOF

# Connect to database
kubectl exec -it -n dp-default-inventorysyst-development-e51b7a18 \
  inventorydatabase-development-9a30de76-0 \
  -- psql -U postgres

# Copy and execute init.sql
kubectl cp database/init.sql \
  dp-default-inventorysyst-development-e51b7a18/inventorydatabase-development-9a30de76-0:/tmp/init.sql

kubectl exec -n dp-default-inventorysyst-development-e51b7a18 \
  inventorydatabase-development-9a30de76-0 \
  -- psql -U postgres -d inventorydb -f /tmp/init.sql
```

#### Supabase Connection

```bash
# Get connection pooler URL from Supabase dashboard
# Settings → Database → Connection pooling

# Create ComponentRelease with Supabase URL
NEW_RELEASE="inventorybackend-$(date +%Y%m%d-%H%M%S)-supabase-pooler"

kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: ${NEW_RELEASE}
  namespace: default
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  envVariables:
    - name: DATABASE_URL
      value: "postgresql://postgres.xxx:password@aws-1-region.pooler.supabase.com:6543/postgres"
EOF

# Update ReleaseBinding
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge \
  -p "{\"spec\":{\"releaseName\":\"${NEW_RELEASE}\"}}"

# Restart deployment
kubectl rollout restart deploy inventorybackend-development-9ebcb79a \
  -n dp-default-inventorysyst-development-e51b7a18

# Verify connection
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 \
  -l openchoreo.dev/component=inventorybackend \
  --tail=30 | grep -E "(Database|connected)"
```

### Backend Commands

```bash
# Create Component
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: inventorybackend
  namespace: default
spec:
  name: inventorybackend
  type: service
  projectName: inventorysystem
EOF

# Build and push image
cd backend
docker build -t ghcr.io/savisaluwadana/inventorybackend:latest .
docker push ghcr.io/savisaluwadana/inventorybackend:latest

# Create ComponentRelease
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorybackend-20260122-2
  namespace: default
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  envVariables:
    - name: PORT
      value: "5000"
    - name: DATABASE_URL
      value: "postgresql://postgres:postgrespassword@inventorydatabase-development.dp-default-inventorysyst-development-e51b7a18.svc.cluster.local:5432/inventorydb"
    - name: FRONTEND_URL
      value: "http://inventoryfrontend-development.openchoreoapis.localhost:19080"
  ports:
    - name: http
      containerPort: 5000
EOF

# Create ReleaseBinding
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ReleaseBinding
metadata:
  name: inventorybackend-development
  namespace: default
spec:
  componentName: inventorybackend
  componentReleaseName: inventorybackend-20260122-2
  environmentName: development
  releaseName: inventorybackend-development
EOF

# Test API
curl http://development.openchoreoapis.localhost:19080/inventorybackend/api/products
```

### Frontend Commands

```bash
# Create Component
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: inventoryfrontend
  namespace: default
spec:
  name: inventoryfrontend
  type: webapp
  projectName: inventorysystem
EOF

# Build and push image
cd frontend
docker build -t ghcr.io/savisaluwadana/inventoryfrontend:latest .
docker push ghcr.io/savisaluwadana/inventoryfrontend:latest

# Create ComponentRelease
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventoryfrontend-20260122-2
  namespace: default
spec:
  componentName: inventoryfrontend
  image: ghcr.io/savisaluwadana/inventoryfrontend:latest
  envVariables:
    - name: NEXT_PUBLIC_API_URL
      value: "http://development.openchoreoapis.localhost:19080/inventorybackend"
  ports:
    - name: http
      containerPort: 3000  # Match Next.js listening port
EOF

# Create ReleaseBinding
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ReleaseBinding
metadata:
  name: inventoryfrontend-development
  namespace: default
spec:
  componentName: inventoryfrontend
  componentReleaseName: inventoryfrontend-20260122-2
  environmentName: development
  releaseName: inventoryfrontend-development
EOF

# Test frontend
curl -I http://inventoryfrontend-development.openchoreoapis.localhost:19080/
```

### Debugging Commands

```bash
# List all components
kubectl get components -n default

# List all ComponentReleases
kubectl get componentreleases -n default

# List all ReleaseBindings
kubectl get releasebindings -n default

# List all Releases
kubectl get releases -n default

# Get pods in dataplane namespace
kubectl get pods -n dp-default-inventorysyst-development-e51b7a18

# Get services in dataplane namespace
kubectl get svc -n dp-default-inventorysyst-development-e51b7a18

# Get logs
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 <pod-name> --tail=50

# Describe pod
kubectl describe pod -n dp-default-inventorysyst-development-e51b7a18 <pod-name>

# Execute command in pod
kubectl exec -it -n dp-default-inventorysyst-development-e51b7a18 <pod-name> -- /bin/sh

# Check environment variables
kubectl exec -n dp-default-inventorysyst-development-e51b7a18 <pod-name> -- printenv

# Port forward to pod
kubectl port-forward -n dp-default-inventorysyst-development-e51b7a18 <pod-name> 5000:5000

# Get Release YAML
kubectl get release inventorybackend-development -n default -o yaml

# Get ConfigMap
kubectl get configmap -n dp-default-inventorysyst-development-e51b7a18

# Restart deployment
kubectl rollout restart deploy <deployment-name> -n dp-default-inventorysyst-development-e51b7a18

# Watch deployment status
kubectl rollout status deploy <deployment-name> -n dp-default-inventorysyst-development-e51b7a18
```

---

## 🐛 Troubleshooting Journey

### Issue 1: Frontend Connection Refused

**Symptom**:
```bash
curl http://inventoryfrontend-development.openchoreoapis.localhost:19080/
# curl: (52) Empty reply from server
```

**Investigation**:
```bash
# Check pod logs
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 \
  -l openchoreo.dev/component=inventoryfrontend

# Output showed Next.js listening on port 3000

# Check service configuration
kubectl get svc -n dp-default-inventorysyst-development-e51b7a18 \
  inventoryfrontend-development-xxxxx -o yaml

# Service targetPort was 80, but container listens on 3000
```

**Root Cause**: Service `targetPort` didn't match container's listening port.

**Solution**:
```bash
# Create new ComponentRelease with correct port
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventoryfrontend-20260122-2
  namespace: default
spec:
  componentName: inventoryfrontend
  image: ghcr.io/savisaluwadana/inventoryfrontend:latest
  ports:
    - name: http
      containerPort: 3000  # Changed from 80 to 3000
      protocol: TCP
EOF

# Update ReleaseBinding
kubectl patch releasebinding inventoryfrontend-development -n default \
  --type=merge \
  -p '{"spec":{"releaseName":"inventoryfrontend-20260122-2"}}'
```

**Lesson Learned**: Always verify the port your application listens on matches the `containerPort` in ComponentRelease.

---

### Issue 2: CORS Errors in Browser

**Symptom**:
```
Access to fetch at 'http://development.openchoreoapis.localhost:19080/inventorybackend/api/products' 
from origin 'http://inventoryfrontend-development.openchoreoapis.localhost:19080' 
has been blocked by CORS policy
```

**Investigation**:
```bash
# Test CORS headers
curl -I -H "Origin: http://inventoryfrontend-development.openchoreoapis.localhost:19080" \
  http://development.openchoreoapis.localhost:19080/inventorybackend/api/products

# Response:
# access-control-allow-origin: *
# (Should be specific origin, not wildcard)
```

**Root Cause**: Backend `FRONTEND_URL` environment variable was incorrect.

**Solution**:
```bash
# Create new ComponentRelease with correct FRONTEND_URL
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorybackend-20260122-2
  namespace: default
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  envVariables:
    - name: FRONTEND_URL
      value: "http://inventoryfrontend-development.openchoreoapis.localhost:19080"
EOF

# Update ReleaseBinding
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge \
  -p '{"spec":{"releaseName":"inventorybackend-20260122-2"}}'
```

**Verification**:
```bash
curl -I -H "Origin: http://inventoryfrontend-development.openchoreoapis.localhost:19080" \
  http://development.openchoreoapis.localhost:19080/inventorybackend/api/products

# Response:
# access-control-allow-origin: http://inventoryfrontend-development.openchoreoapis.localhost:19080
# ✅ Correct!
```

**Lesson Learned**: Environment variables must match deployed gateway URLs exactly.

---

### Issue 3: Supabase IPv6 Connection Failure

**Symptom**:
```bash
curl http://development.openchoreoapis.localhost:19080/inventorybackend/api/products
# {"error":"Failed to fetch products"}
```

**Investigation**:
```bash
# Check backend logs
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 \
  -l openchoreo.dev/component=inventorybackend \
  --tail=50

# Error found:
# Error fetching products: Error: connect ENETUNREACH 2406:da18:243:741a:5869:e9c7:edff:1c67:5432
# errno: -101,
# code: 'ENETUNREACH',
# syscall: 'connect',
# address: '2406:da18:243:741a:5869:e9c7:edff:1c67',
# port: 5432
```

**Root Cause**: 
- Direct Supabase connection (`db.*.supabase.co:5432`) resolves to IPv6 address
- k3d cluster only supports IPv4 outbound connections
- Result: `ENETUNREACH` (network unreachable)

**Solution**:
```bash
# Use Supabase connection pooler (port 6543) instead of direct connection (port 5432)
# Connection pooler uses IPv4-compatible addresses

# Get connection pooler URL from Supabase dashboard
# Settings → Database → Connection pooling tab

SUPABASE_POOLER_URL="postgresql://postgres.vnqpwialdwdgqcvymhox:Sudusalu@123@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres"

# Create new ComponentRelease
NEW_RELEASE="inventorybackend-20260122-232210-supabase-pooler"

kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: ${NEW_RELEASE}
  namespace: default
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  envVariables:
    - name: DATABASE_URL
      value: "${SUPABASE_POOLER_URL}"
EOF

# Update ReleaseBinding
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge \
  -p "{\"spec\":{\"releaseName\":\"${NEW_RELEASE}\"}}"

# Restart deployment
kubectl rollout restart deploy inventorybackend-development-9ebcb79a \
  -n dp-default-inventorysyst-development-e51b7a18
```

**Verification**:
```bash
# Check logs
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 \
  -l openchoreo.dev/component=inventorybackend \
  --tail=30

# Expected output:
# 🚀 Server is running on http://localhost:5000
# ✅ Database connected successfully

# Test API
curl http://development.openchoreoapis.localhost:19080/inventorybackend/api/products

# Success! Returns products from Supabase
```

**Lesson Learned**:
- Always use **connection pooler** (port 6543) for Supabase in Kubernetes
- Direct connection (port 5432) may have IPv6 compatibility issues
- Connection pooler also provides better performance and connection management

---

### Issue 4: Environment Variables Not Updating

**Symptom**:
```bash
# Patched Workload directly
kubectl patch workload inventorybackend-development -n default \
  -p '{"spec":{"envVariables":[{"name":"DATABASE_URL","value":"new-value"}]}}'

# But pod still has old DATABASE_URL
kubectl exec -n dp-default-inventorysyst-development-e51b7a18 <pod> -- printenv DATABASE_URL
# Still shows old value
```

**Root Cause**: OpenChoreo uses immutable ComponentReleases. You cannot patch resources directly.

**Correct Workflow**:
1. Create **new ComponentRelease** with updated values
2. Update **ReleaseBinding** to reference new release
3. OpenChoreo automatically propagates changes to dataplane

**Solution**:
```bash
# Step 1: Create new ComponentRelease
kubectl apply -f - <<EOF
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorybackend-20260122-updated  # New name
  namespace: default
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:latest
  envVariables:
    - name: DATABASE_URL
      value: "new-database-url"  # Updated value
EOF

# Step 2: Update ReleaseBinding
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge \
  -p '{"spec":{"releaseName":"inventorybackend-20260122-updated"}}'

# Step 3: Verify Release updated
kubectl get release inventorybackend-development -n default \
  -o jsonpath='{.spec.resources[0].object.data.DATABASE_URL}'

# Step 4: Restart deployment (if not auto-restarted)
kubectl rollout restart deploy inventorybackend-development-9ebcb79a \
  -n dp-default-inventorysyst-development-e51b7a18
```

**Lesson Learned**: OpenChoreo enforces GitOps-style immutability. Always create new ComponentReleases for changes.

---

## 🚀 Production Considerations

### Security Best Practices

#### 1. **Secret Management**

```bash
# ❌ Bad: Hardcoded passwords in ComponentRelease
envVariables:
  - name: DATABASE_URL
    value: "postgresql://user:password@host:5432/db"

# ✅ Good: Use Kubernetes Secrets
kubectl create secret generic db-credentials \
  --from-literal=DATABASE_URL="postgresql://user:password@host:5432/db" \
  -n dp-default-inventorysyst-production-xxxxxxxx

# Reference secret in ComponentRelease
envVariables:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DATABASE_URL
```

#### 2. **Network Policies**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: dp-default-inventorysyst-production-xxxxxxxx
spec:
  podSelector:
    matchLabels:
      openchoreo.dev/component: inventorybackend
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    # Allow traffic only from frontend pods
    - from:
        - podSelector:
            matchLabels:
              openchoreo.dev/component: inventoryfrontend
      ports:
        - protocol: TCP
          port: 5000
  
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
    
    # Allow database access
    - to:
        - podSelector:
            matchLabels:
              openchoreo.dev/component: inventorydatabase
      ports:
        - protocol: TCP
          port: 5432
```

#### 3. **Resource Limits**

```yaml
# Production ComponentRelease with resource limits
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorybackend-production-v1
spec:
  componentName: inventorybackend
  image: ghcr.io/savisaluwadana/inventorybackend:v1.0.0  # Pinned version
  
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
  
  # Horizontal Pod Autoscaler
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

### High Availability

#### 1. **Database Replication**

```yaml
# PostgreSQL StatefulSet with replicas
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorydatabase-production-v1
spec:
  componentName: inventorydatabase
  image: postgres:15-alpine
  
  replicas: 3  # Primary + 2 read replicas
  
  # Replication configuration
  envVariables:
    - name: POSTGRES_REPLICATION_MODE
      value: "master"
    - name: POSTGRES_REPLICATION_USER
      value: "replicator"
    - name: POSTGRES_REPLICATION_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-replication-creds
          key: password
```

#### 2. **Multiple Availability Zones**

```yaml
# Pod anti-affinity for spreading across nodes
apiVersion: core.openchoreo.dev/v1alpha1
kind: ComponentRelease
metadata:
  name: inventorybackend-production-v1
spec:
  componentName: inventorybackend
  
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              openchoreo.dev/component: inventorybackend
          topologyKey: topology.kubernetes.io/zone
```

### Monitoring & Observability

#### 1. **Prometheus Metrics**

```typescript
// backend/src/server.ts
import promClient from 'prom-client';

const register = new promClient.Registry();

// Collect default metrics
promClient.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

const databaseQueryDuration = new promClient.Histogram({
  name: 'database_query_duration_seconds',
  help: 'Duration of database queries in seconds',
  labelNames: ['query_type'],
  registers: [register],
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

#### 2. **Structured Logging**

```typescript
// backend/src/logger.ts
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'inventory-backend',
    environment: process.env.NODE_ENV,
  },
  transports: [
    new winston.transports.Console(),
  ],
});

export default logger;

// Usage
logger.info('Product created', { productId: 123, sku: 'LAP-001' });
logger.error('Database error', { error: err.message, stack: err.stack });
```

### Backup & Disaster Recovery

#### 1. **Database Backups**

```bash
# Create CronJob for automated backups
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: dp-default-inventorysyst-production-xxxxxxxx
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: postgres-backup
              image: postgres:15-alpine
              command:
                - /bin/sh
                - -c
                - |
                  pg_dump postgresql://postgres:password@inventorydatabase-production:5432/inventorydb > /backup/backup-$(date +%Y%m%d-%H%M%S).sql
                  # Upload to S3 or other storage
          restartPolicy: OnFailure
EOF
```

#### 2. **Restore Procedure**

```bash
# Restore from backup
kubectl exec -it -n dp-default-inventorysyst-production-xxxxxxxx \
  inventorydatabase-production-0 \
  -- psql -U postgres -d inventorydb -f /backup/backup-20260122-020000.sql
```

### CI/CD Integration

```yaml
# .github/workflows/deploy.yml
name: Deploy to OpenChoreo

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build backend image
        run: |
          docker build -t ghcr.io/${{ github.repository }}/inventorybackend:${{ github.sha }} ./backend
          docker push ghcr.io/${{ github.repository }}/inventorybackend:${{ github.sha }}
      
      - name: Create ComponentRelease
        run: |
          kubectl apply -f - <<EOF
          apiVersion: core.openchoreo.dev/v1alpha1
          kind: ComponentRelease
          metadata:
            name: inventorybackend-${{ github.sha }}
            namespace: default
          spec:
            componentName: inventorybackend
            image: ghcr.io/${{ github.repository }}/inventorybackend:${{ github.sha }}
          EOF
      
      - name: Update ReleaseBinding
        run: |
          kubectl patch releasebinding inventorybackend-production -n default \
            --type=merge \
            -p '{"spec":{"releaseName":"inventorybackend-${{ github.sha }}"}}'
```

---

## 📊 Summary

### What We Built

✅ **Three-tier application** on OpenChoreo single-cluster architecture
✅ **Two database connection methods**: Local StatefulSet + Supabase Cloud
✅ **Custom ComponentType** for reusable PostgreSQL deployments
✅ **Production-ready backend** with CORS, error handling, and connection pooling
✅ **Modern frontend** with Next.js 14 App Router and Tailwind CSS
✅ **Complete GitOps workflow** using immutable ComponentReleases

### Key Learnings

1. **OpenChoreo Workflow**: Component → ComponentRelease → ReleaseBinding → Release → Dataplane
2. **Immutability**: Always create new ComponentReleases, never patch directly
3. **Port Matching**: `containerPort` must match application listening port
4. **CORS Configuration**: Use specific origins, not wildcards
5. **Supabase Connection**: Use connection pooler (port 6543) for IPv4 compatibility
6. **Database Agnostic Code**: Single `DATABASE_URL` works with any PostgreSQL source

### Command Summary

```bash
# Database (Local)
kubectl apply -f postgres-database.componenttype.yaml
kubectl apply -f database-component.yaml
kubectl apply -f database-componentrelease.yaml
kubectl apply -f database-releasebinding.yaml

# Database (Supabase)
# Get connection pooler URL from dashboard
# Create new ComponentRelease with Supabase URL
# Update ReleaseBinding

# Backend
kubectl apply -f backend-component.yaml
docker build -t ghcr.io/user/inventorybackend:latest backend/
docker push ghcr.io/user/inventorybackend:latest
kubectl apply -f backend-componentrelease.yaml
kubectl apply -f backend-releasebinding.yaml

# Frontend
kubectl apply -f frontend-component.yaml
docker build -t ghcr.io/user/inventoryfrontend:latest frontend/
docker push ghcr.io/user/inventoryfrontend:latest
kubectl apply -f frontend-componentrelease.yaml
kubectl apply -f frontend-releasebinding.yaml

# Debugging
kubectl get pods -n dp-default-inventorysyst-development-e51b7a18
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 <pod-name>
kubectl exec -it -n dp-default-inventorysyst-development-e51b7a18 <pod-name> -- /bin/sh
```

---

## 🎯 Next Steps

1. **Add Authentication**: Integrate OAuth2/OIDC for user authentication
2. **Implement Caching**: Add Redis for session management and API caching
3. **Set Up Monitoring**: Deploy Prometheus + Grafana for observability
4. **Enable Tracing**: Add OpenTelemetry for distributed tracing
5. **Implement Rate Limiting**: Protect APIs with rate limiting middleware
6. **Add E2E Tests**: Implement Cypress or Playwright tests
7. **Multi-Environment**: Create staging and production environments
8. **Database Migrations**: Implement schema versioning with tools like Flyway

---

**🎉 Congratulations!** You've successfully deployed a complete three-tier application on OpenChoreo with two different database connection methods, learned the OpenChoreo workflow, and built a production-ready architecture.

