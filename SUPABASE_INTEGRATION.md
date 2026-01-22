# 🔗 Connecting to Supabase (External Database)

> **Guide for integrating your OpenChoreo backend with Supabase PostgreSQL**  
> Replace the OpenChoreo-managed database with a cloud-hosted Supabase instance.

---

## 📋 Table of Contents

| Section | Description |
|---------|-------------|
| [🎯 Overview](#-overview) | Why use Supabase with OpenChoreo |
| [🚀 Setup Supabase](#-setup-supabase) | Create and configure Supabase project |
| [🔧 Configure Backend](#-configure-backend) | Update OpenChoreo backend configuration |
| [🧪 Testing](#-testing) | Verify the connection |
| [🔒 Security Best Practices](#-security-best-practices) | Secure your database credentials |

---

## 🎯 Overview

### Why Supabase?

| Feature | Benefit |
|---------|---------|
| 🌍 **Cloud-Hosted** | No need to manage database infrastructure |
| 🔄 **Auto-Backups** | Built-in daily backups and point-in-time recovery |
| 📊 **Dashboard** | Visual database editor and SQL editor |
| 🔐 **Security** | SSL connections, row-level security, and auth |
| 📈 **Scalability** | Easy to scale as your application grows |
| 💰 **Free Tier** | Generous free tier for development |

### Architecture Change

**Before (OpenChoreo-managed DB):**
```
Backend Pod → OpenChoreo PostgreSQL StatefulSet (in cluster)
```

**After (Supabase):**
```
Backend Pod → Internet → Supabase PostgreSQL (cloud)
```

---

## 🚀 Setup Supabase

### Step 1: Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign up/login
2. Click **"New Project"**
3. Fill in project details:
   - **Name**: `inventory-system` (or your preferred name)
   - **Database Password**: Generate a strong password (save this!)
   - **Region**: Choose closest to your OpenChoreo cluster
   - **Pricing Plan**: Free (or your preferred tier)
4. Click **"Create new project"**
5. Wait 2-3 minutes for provisioning

### Step 2: Get Connection String

1. In your Supabase project dashboard, navigate to:
   ```
   Settings → Database → Connection String
   ```

2. Copy the **Connection Pooling** connection string (recommended for serverless):
   ```
   postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
   ```

3. Or use the **Direct Connection** string:
   ```
   postgresql://postgres.[PROJECT_REF]:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres
   ```

> 💡 **Recommendation**: Use **Connection Pooling** for better performance with OpenChoreo deployments.

### Step 3: Initialize the Database Schema

<details>
<summary><strong>Option A: Using Supabase SQL Editor (Recommended)</strong></summary>

1. Navigate to **SQL Editor** in Supabase dashboard
2. Click **"New query"**
3. Paste your initialization SQL:

```sql
-- Create products table
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

-- Create index on barcode for faster lookups
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);

-- Create index on category
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- Insert sample data
INSERT INTO products (name, description, price, stock_quantity, category, barcode)
VALUES 
    ('Laptop', 'High-performance laptop', 999.99, 50, 'Electronics', 'ELEC-001'),
    ('Mouse', 'Wireless mouse', 29.99, 200, 'Electronics', 'ELEC-002'),
    ('Keyboard', 'Mechanical keyboard', 79.99, 150, 'Electronics', 'ELEC-003'),
    ('Monitor', '27-inch 4K monitor', 399.99, 75, 'Electronics', 'ELEC-004'),
    ('Desk Chair', 'Ergonomic office chair', 249.99, 40, 'Furniture', 'FURN-001')
ON CONFLICT (barcode) DO NOTHING;

-- Create a function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

4. Click **"Run"** or press `Ctrl+Enter`
5. Verify success in the output panel

</details>

<details>
<summary><strong>Option B: Using psql (Terminal)</strong></summary>

```bash
# Install psql if not already installed (macOS)
brew install postgresql

# Connect to Supabase (replace with your connection string)
psql "postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres"

# Once connected, paste and run the SQL from Option A
# Or run from file:
\i backend/init.sql

# Exit psql
\q
```

</details>

### Step 4: Verify Data in Supabase

1. Navigate to **Table Editor** in Supabase dashboard
2. Select the `products` table
3. You should see 5 sample products
4. Try running a test query in **SQL Editor**:
   ```sql
   SELECT COUNT(*) FROM products;
   ```
   Expected result: `5`

---

## 🔧 Configure Backend

### Method 1: Using OpenChoreo UI (Recommended)

<details>
<summary><strong>View step-by-step instructions</strong></summary>

1. **Navigate to your backend component**:
   - Open OpenChoreo Console
   - Go to Projects → `inventorysystem` → Components
   - Click on `inventorybackend`

2. **Configure Environment Variables**:
   - Click **"Configure"** tab
   - Find **Environment Variables** section
   - Update `DATABASE_URL`:

   | Variable | Value | Type |
   |----------|-------|------|
   | `DATABASE_URL` | `postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres` | Secret |

   > ⚠️ **Important**: Mark `DATABASE_URL` as **Secret** to protect credentials

3. **Deploy the changes**:
   - Click **"Save"** or **"Update"**
   - OpenChoreo will create a new `ComponentRelease`
   - Wait for deployment to complete (~2-3 minutes)

</details>

### Method 2: Using kubectl (Advanced)

<details>
<summary><strong>View kubectl commands</strong></summary>

#### Create a Kubernetes Secret

```bash
# Set your Supabase connection string
export SUPABASE_URL="postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres"

# Find the dataplane namespace
export DATAPLANE_NS=$(kubectl get ns | grep 'dp-default-inventorysyst-development' | awk '{print $1}')

# Create a secret in the dataplane
kubectl create secret generic supabase-db-secret \
  --from-literal=DATABASE_URL="$SUPABASE_URL" \
  -n $DATAPLANE_NS \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Update ComponentRelease

```bash
# Get the latest ComponentRelease name
COMPONENT_RELEASE=$(kubectl get componentreleases -n default -l openchoreo.dev/component=inventorybackend --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

echo "Latest ComponentRelease: $COMPONENT_RELEASE"

# Create a new ComponentRelease with Supabase URL
# First, get the current version
kubectl get componentrelease $COMPONENT_RELEASE -n default -o yaml > /tmp/current-release.yaml

# Create new version (increment the date/version number)
NEW_RELEASE="inventorybackend-$(date +%Y%m%d)-supabase"

# Edit and apply
cat /tmp/current-release.yaml | \
  sed "s/name: $COMPONENT_RELEASE/name: $NEW_RELEASE/" | \
  sed "s|value: postgresql://postgres:postgres@inventorydatabase.*|value: $SUPABASE_URL|" | \
  grep -vE '^(  creationTimestamp:|  generation:|  resourceVersion:|  uid:)' | \
  kubectl apply -f -

# Update ReleaseBinding
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge -p "{\"spec\":{\"releaseName\":\"$NEW_RELEASE\"}}"

# Wait for rollout
echo "Waiting for backend deployment to update..."
kubectl rollout status deploy -l openchoreo.dev/component=inventorybackend -n $DATAPLANE_NS --timeout=120s
```

</details>

### Method 3: Local Testing (Development)

For local development outside OpenChoreo:

```bash
# Create .env file in backend directory
cd backend

cat > .env.local <<EOF
# Supabase PostgreSQL Connection
DATABASE_URL=postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres

# Backend Configuration
PORT=5000
NODE_ENV=development
FRONTEND_URL=http://localhost:3000
EOF

# Install dependencies
npm install

# Run the backend
npm run dev
```

---

## 🧪 Testing

### Test 1: Check Backend Logs

```bash
# Find dataplane namespace
DATAPLANE_NS=$(kubectl get ns | grep 'dp-default-inventorysyst-development' | awk '{print $1}')

# Get backend pod name
BACKEND_POD=$(kubectl get pods -n $DATAPLANE_NS -l openchoreo.dev/component=inventorybackend -o jsonpath='{.items[0].metadata.name}')

# Check logs for successful connection
kubectl logs -n $DATAPLANE_NS $BACKEND_POD | grep -i "database"
```

**Expected Output:**
```
✅ Database connected successfully
```

### Test 2: Query Products via API

```bash
# Test the products endpoint
curl -s http://development.openchoreoapis.localhost:19080/inventorybackend/api/products | jq
```

**Expected Output:**
```json
[
  {
    "id": 1,
    "name": "Laptop",
    "description": "High-performance laptop",
    "price": "999.99",
    "stock_quantity": 50,
    "category": "Electronics",
    "barcode": "ELEC-001",
    "created_at": "2026-01-22T...",
    "updated_at": "2026-01-22T..."
  },
  ...
]
```

### Test 3: Test CRUD Operations

<details>
<summary><strong>View test commands</strong></summary>

**Create a new product:**
```bash
curl -X POST http://development.openchoreoapis.localhost:19080/inventorybackend/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Webcam",
    "description": "HD webcam with microphone",
    "price": 89.99,
    "stock_quantity": 100,
    "category": "Electronics",
    "barcode": "ELEC-005"
  }' | jq
```

**Update a product:**
```bash
curl -X PUT http://development.openchoreoapis.localhost:19080/inventorybackend/api/products/1 \
  -H "Content-Type: application/json" \
  -d '{
    "stock_quantity": 45
  }' | jq
```

**Delete a product:**
```bash
curl -X DELETE http://development.openchoreoapis.localhost:19080/inventorybackend/api/products/6
```

**Verify in Supabase:**
- Open Supabase Table Editor
- View `products` table
- Changes should be reflected in real-time

</details>

### Test 4: Check Connection from Pod

```bash
# Exec into the backend pod
kubectl exec -it -n $DATAPLANE_NS $BACKEND_POD -- sh

# Inside the pod, test the connection
apk add --no-cache postgresql-client  # If psql not available

# Test connection (use the DATABASE_URL from env)
echo $DATABASE_URL

# Try connecting
psql $DATABASE_URL -c "SELECT version();"

# Exit the pod
exit
```

---

## 🔒 Security Best Practices

### 1. Use Connection Pooling

✅ **Recommended**: Use Supabase's connection pooling endpoint
```
postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
```

This provides:
- Better connection management
- Reduced connection overhead
- Protection against connection limit exhaustion

### 2. Secure Credentials

#### Option A: OpenChoreo Secrets (Recommended for Production)

Store credentials as secrets in OpenChoreo:

1. Navigate to: **Component → Configure → Secrets**
2. Create secret: `DATABASE_URL`
3. Value: Your Supabase connection string
4. Mark as **Secret** (masked in UI)

#### Option B: External Secrets Operator

For advanced setups, integrate with external secret managers:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: supabase-db-credentials
  namespace: dp-default-inventorysyst-development-e51b7a18
spec:
  secretStoreRef:
    name: aws-secrets-manager  # or vault, etc.
    kind: ClusterSecretStore
  target:
    name: supabase-db-secret
  data:
  - secretKey: DATABASE_URL
    remoteRef:
      key: prod/inventory/database-url
```

### 3. Network Security

#### Enable SSL/TLS (Already enabled by default with Supabase)

Supabase connections use SSL by default. Verify in your connection string:
```
postgresql://...?sslmode=require
```

#### IP Allowlisting (Optional)

For production, restrict database access:

1. Go to Supabase: **Settings → Database → Connection Pooling**
2. Enable **IP Restrictions**
3. Add your OpenChoreo cluster's egress IP

> 💡 For local OpenChoreo (k3d), IP restrictions may not be necessary

### 4. Database User Permissions

Create a dedicated database user with limited permissions:

```sql
-- In Supabase SQL Editor

-- Create a dedicated user for the application
CREATE USER inventory_app WITH PASSWORD 'your-secure-password';

-- Grant only necessary permissions
GRANT CONNECT ON DATABASE postgres TO inventory_app;
GRANT USAGE ON SCHEMA public TO inventory_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON products TO inventory_app;
GRANT USAGE, SELECT ON SEQUENCE products_id_seq TO inventory_app;

-- Update connection string to use this user
-- postgresql://inventory_app:your-secure-password@...
```

### 5. Monitor Database Activity

Use Supabase's built-in monitoring:

1. **Database → Logs**: View query logs
2. **Database → Reports**: Analyze performance
3. Set up alerts for:
   - High connection count
   - Slow queries
   - Failed authentication attempts

---

## 🔄 Rollback to OpenChoreo Database

If you need to switch back:

<details>
<summary><strong>View rollback steps</strong></summary>

```bash
# Get the original ComponentRelease (before Supabase)
kubectl get componentreleases -n default -l openchoreo.dev/component=inventorybackend

# Find the one with OpenChoreo database URL
kubectl get componentrelease inventorybackend-20260122-1 -n default -o jsonpath='{.spec.workload.containers.main.env[?(@.key=="DATABASE_URL")].value}'

# Update ReleaseBinding to point back
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge -p '{"spec":{"releaseName":"inventorybackend-20260122-1"}}'

# Wait for rollout
kubectl rollout status deploy -l openchoreo.dev/component=inventorybackend -n $DATAPLANE_NS
```

</details>

---

## 📊 Comparison: OpenChoreo DB vs Supabase

| Feature | OpenChoreo-Managed DB | Supabase |
|---------|----------------------|----------|
| **Setup Complexity** | Medium (ComponentType) | Low (Web UI) |
| **Cost** | Free (self-hosted) | Free tier available |
| **Backups** | Manual (PVC snapshots) | Automatic daily |
| **Scalability** | Manual (StatefulSet scaling) | Automatic |
| **Management** | kubectl/OpenChoreo | Web Dashboard |
| **SSL/TLS** | Manual setup | Built-in |
| **Monitoring** | External tools needed | Built-in dashboard |
| **High Availability** | Manual replication | Built-in (paid tiers) |
| **Geographic Distribution** | Single cluster | Multiple regions |
| **Migration** | PVC management | Point-in-time recovery |

---

## 🎯 Next Steps

✅ **Completed**: Backend connected to Supabase

**Recommended enhancements**:

1. **Enable Row-Level Security (RLS)**:
   ```sql
   ALTER TABLE products ENABLE ROW LEVEL SECURITY;
   ```

2. **Set up Supabase Auth** (if adding user authentication)

3. **Configure Database Webhooks** for real-time notifications

4. **Set up scheduled backups** to external storage

5. **Enable Supabase Realtime** for live data updates in frontend

6. **Monitor query performance** and add indexes as needed

---

## 📚 Additional Resources

| Resource | Link |
|----------|------|
| 📖 Supabase Documentation | [supabase.com/docs](https://supabase.com/docs) |
| 🔐 Supabase Auth Guide | [Auth Docs](https://supabase.com/docs/guides/auth) |
| 📊 Database Management | [Database Docs](https://supabase.com/docs/guides/database) |
| 🔄 Realtime | [Realtime Docs](https://supabase.com/docs/guides/realtime) |
| 💾 Backups & Restore | [Backup Guide](https://supabase.com/docs/guides/platform/backups) |

---

<div align="center">

### ✨ Supabase Integration Complete

**🔗 External Database**: Connected  
**🔒 Security**: Configured  
**✅ Status**: Ready for Production

---

**Made with ❤️ using OpenChoreo + Supabase**

</div>
