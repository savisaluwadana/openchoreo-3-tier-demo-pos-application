# 🎯 Supabase Connection - Quick Guide

## How It Works (No Service Required!)

### Current Architecture (OpenChoreo DB):
```
┌─────────────────┐         ┌──────────────────────┐
│  Backend Pod    │────────▶│ PostgreSQL Service   │
│  (port 5000)    │         │ (ClusterIP)          │
└─────────────────┘         └──────────────────────┘
                                     │
                            ┌────────▼─────────┐
                            │ PostgreSQL Pod   │
                            │ (StatefulSet)    │
                            └──────────────────┘
```
**Needs**: Service + StatefulSet + PVC

---

### New Architecture (Supabase):
```
┌─────────────────┐         
│  Backend Pod    │────────▶ Internet ────────▶ ☁️ Supabase Cloud
│  (port 5000)    │         (HTTPS/SSL)         (aws-0-region.pooler.supabase.com)
└─────────────────┘         
```
**Needs**: Just a connection string! 🎉

---

## ✅ What You Need to Do:

### Step 1: Get Your Supabase Connection String

1. Go to [supabase.com](https://supabase.com) and create a project
2. Navigate to: **Settings** → **Database** → **Connection String**
3. Copy the **Connection Pooling** string (looks like this):

```
postgresql://postgres.xxxxxxxxxxxxx:[YOUR-PASSWORD]@aws-0-us-west-1.pooler.supabase.com:6543/postgres
```

### Step 2: Update Backend Environment Variable

**Option A: Use the Automated Script (Easiest)**

```bash
./scripts/setup-supabase.sh
```

When prompted, paste your connection string. The script will:
- ✅ Test the connection
- ✅ Create a new ComponentRelease
- ✅ Update the ReleaseBinding
- ✅ Restart your backend
- ✅ Verify everything works

**Option B: Manual via OpenChoreo UI**

1. Open OpenChoreo Console
2. Go to: **Projects** → **inventorysystem** → **Components** → **inventorybackend**
3. Click **Configure** tab
4. Find **Environment Variables**
5. Update `DATABASE_URL` to your Supabase connection string
6. Click **Save** and wait for redeployment

**Option C: Manual via kubectl**

```bash
# Set your Supabase URL
export SUPABASE_URL="postgresql://postgres.xxxxx:[PASSWORD]@aws-0-region.pooler.supabase.com:6543/postgres"

# Get latest ComponentRelease
LATEST=$(kubectl get componentreleases -n default -l openchoreo.dev/component=inventorybackend --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# Create new release with Supabase
kubectl get componentrelease $LATEST -n default -o yaml | \
  sed "s/name: $LATEST/name: inventorybackend-$(date +%Y%m%d)-supabase/" | \
  sed "s|value: postgresql://.*|value: $SUPABASE_URL|" | \
  grep -vE '^(  creationTimestamp:|  generation:|  resourceVersion:|  uid:)' | \
  kubectl apply -f -

# Update binding
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge -p '{"spec":{"releaseName":"inventorybackend-'$(date +%Y%m%d)'-supabase"}}'
```

---

## 🤔 Why No Service Needed?

### With OpenChoreo Database:
- Database runs **inside** the cluster
- Needs a **Kubernetes Service** for pod-to-pod communication
- Uses internal DNS (`inventorydatabase-development-xxx.svc.cluster.local`)

### With Supabase:
- Database runs **outside** the cluster (in Supabase cloud)
- Backend connects via **public internet** using hostname
- Uses external DNS (`aws-0-us-west-1.pooler.supabase.com`)
- No Kubernetes Service required!

---

## 🔐 How Your Backend Code Works

Your existing `backend/src/db.ts` already handles this perfectly:

```typescript
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,  // ← This is all you need!
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

The `pg` library (PostgreSQL client) automatically:
- ✅ Parses the connection string
- ✅ Establishes TCP connection to Supabase
- ✅ Handles SSL/TLS encryption
- ✅ Manages connection pooling
- ✅ Reconnects on failure

---

## 🧪 Testing the Connection

### Test 1: From Your Local Machine

```bash
# Install psql if needed (macOS)
brew install postgresql

# Test connection (replace with your string)
psql "postgresql://postgres.xxxxx:[PASSWORD]@aws-0-region.pooler.supabase.com:6543/postgres" -c "SELECT version();"
```

**Expected Output:**
```
PostgreSQL 15.x on x86_64-pc-linux-gnu...
```

### Test 2: From Backend Pod

```bash
# Find your backend pod
DATAPLANE_NS=$(kubectl get ns | grep 'dp-default-inventorysyst-development' | awk '{print $1}')
BACKEND_POD=$(kubectl get pods -n $DATAPLANE_NS -l openchoreo.dev/component=inventorybackend -o jsonpath='{.items[0].metadata.name}')

# Check if DATABASE_URL is set
kubectl exec -n $DATAPLANE_NS $BACKEND_POD -- env | grep DATABASE_URL

# Check logs for connection
kubectl logs -n $DATAPLANE_NS $BACKEND_POD | grep -i database
```

**Expected Output:**
```
DATABASE_URL=postgresql://postgres.xxxxx@aws-0-region.pooler.supabase.com:6543/postgres
✅ Database connected successfully
```

### Test 3: Via API Endpoint

```bash
# Query products
curl -s http://development.openchoreoapis.localhost:19080/inventorybackend/api/products | jq

# Health check
curl http://development.openchoreoapis.localhost:19080/inventorybackend/health
```

---

## 🆚 Comparison: Service vs Direct Connection

| Aspect | With Kubernetes Service | With Supabase (Direct) |
|--------|------------------------|------------------------|
| **Connectivity** | ClusterIP Service required | Direct internet connection |
| **DNS** | Internal (`svc.cluster.local`) | External (`supabase.com`) |
| **SSL/TLS** | Manual setup | Built-in |
| **Authentication** | k8s secrets | Connection string |
| **Network Path** | Pod → Service → Pod | Pod → Internet → Cloud |
| **Latency** | ~1ms (local) | ~20-100ms (depends on region) |
| **Setup** | Complex (StatefulSet + Service + PVC) | Simple (just connection string) |

---

## ❓ Common Questions

### Q: Do I need to create a Kubernetes Service for Supabase?
**A:** No! Services are only for in-cluster communication.

### Q: Will my backend be able to reach the internet?
**A:** Yes! OpenChoreo/k3d allows outbound connections by default.

### Q: What if I'm behind a corporate firewall?
**A:** You might need to:
- Allow outbound connections to `*.supabase.com` on port 6543 (or 5432)
- Configure proxy settings if required
- Use connection pooling endpoint (port 6543) instead of direct (5432)

### Q: Can I use both OpenChoreo DB and Supabase?
**A:** Yes! You could:
- Keep both databases running
- Use environment-based switching
- Run OpenChoreo DB for dev, Supabase for prod

### Q: How do I secure the connection string?
**A:** Use OpenChoreo secrets (see SUPABASE_INTEGRATION.md, Security section)

---

## 🎯 Next Steps

1. **Get Supabase connection string** from your project dashboard
2. **Run the setup script**: `./scripts/setup-supabase.sh`
3. **Initialize database schema** in Supabase SQL Editor (see SUPABASE_INTEGRATION.md)
4. **Test the connection** using the commands above
5. **(Optional)** Remove old OpenChoreo database:
   ```bash
   kubectl delete component inventorydatabase -n default
   ```

---

## 🚨 Troubleshooting

### "Connection refused" or "timeout"
- ✅ Check Supabase project is active (not paused)
- ✅ Verify connection string is correct (copy/paste carefully)
- ✅ Check password has no special characters that need escaping
- ✅ Ensure Supabase region is accessible from your location

### "Password authentication failed"
- ✅ Double-check password in connection string
- ✅ Password might have special chars: use `%XX` encoding
- ✅ Verify you're using the correct user (usually `postgres`)

### "Database does not exist"
- ✅ Connection string should end with `/postgres` (default database)
- ✅ Check if you changed the database name

### Backend logs show old database
- ✅ ComponentRelease may not have been created properly
- ✅ Re-run the setup script
- ✅ Check ReleaseBinding points to new release:
   ```bash
   kubectl get releasebinding inventorybackend-development -n default -o yaml
   ```

---

**TL;DR**: Just update the `DATABASE_URL` environment variable in your backend component. No Kubernetes Service needed! 🎉

