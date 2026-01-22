# ⚠️ Supabase Connection Issue & Fix

## Problem Encountered

Your backend is trying to connect to Supabase but getting `ENETUNREACH` (network unreachable) errors.

### Root Cause
- You're using the **Direct Connection** URL: `db.vnqpwialdwdgqcvymhox.supabase.co:5432`
- This resolves to an **IPv6 address**: `2406:da18:243:741a:5869:e9c7:edff:1c67`
- Your k3d/OpenChoreo cluster **doesn't support IPv6** outbound connections

### Error Logs
```
Error: connect ENETUNREACH 2406:da18:243:741a:5869:e9c7:edff:1c67:5432
code: 'ENETUNREACH'
```

---

## ✅ Solution: Use Connection Pooler

Supabase provides two connection methods:

| Connection Type | Port | IP Version | Best For |
|----------------|------|------------|----------|
| **Direct Connection** | 5432 | IPv6 (problematic for k3d) | Direct database access |
| **Connection Pooler** ✅ | 6543 | IPv4 (works with k3d) | Serverless, containers, OpenChoreo |

---

## 🔧 How to Get the Correct Connection String

### Option 1: Get from Supabase Dashboard (Recommended)

1. Go to your Supabase project dashboard
2. Navigate to: **Settings** → **Database**
3. Scroll to **Connection String** section
4. Select **Connection pooling** tab (NOT "Direct connection")
5. Copy the **URI** format string

It should look like:
```
postgresql://postgres.[PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
```

### Option 2: Modify Your Existing URL

Change your current URL from:
```
postgresql://postgres:Sudusalu@123@db.vnqpwialdwdgqcvymhox.supabase.co:5432/postgres
```

To (replace `[REGION]` with your actual region like `ap-south-1`, `us-west-1`, etc.):
```
postgresql://postgres:Sudusalu@123@aws-0-[REGION].pooler.supabase.com:6543/postgres
```

**Common regions:**
- Asia Pacific (Mumbai): `ap-south-1`
- US West (Oregon): `us-west-1`
- Europe (Ireland): `eu-west-1`
- Southeast Asia (Singapore): `ap-southeast-1`

---

## 🚀 Apply the Fix

Once you have the correct connection pooler URL:

### Method 1: Automated Script
```bash
# Set the corrected URL
export SUPABASE_URL="postgresql://postgres:Sudusalu@123@aws-0-[YOUR-REGION].pooler.supabase.com:6543/postgres"

# Run the setup script
./scripts/setup-supabase.sh
```

### Method 2: Manual Update

```bash
# Set your corrected connection string
SUPABASE_URL="postgresql://postgres:Sudusalu@123@aws-0-[YOUR-REGION].pooler.supabase.com:6543/postgres"

# Get latest ComponentRelease
LATEST=$(kubectl get componentreleases -n default \
    -l openchoreo.dev/component=inventorybackend \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{.items[-1].metadata.name}')

# Export and modify
kubectl get componentrelease $LATEST -n default -o yaml > /tmp/current-release.yaml

# Create new release with corrected URL
NEW_RELEASE="inventorybackend-$(date +%Y%m%d-%H%M%S)-supabase-fixed"

cat /tmp/current-release.yaml | \
  sed "s/name: $LATEST/name: $NEW_RELEASE/" | \
  sed "s|value: postgresql://.*|value: $SUPABASE_URL|" | \
  grep -vE '^  (creationTimestamp|generation|resourceVersion|uid):' | \
  kubectl apply -f -

# Update ReleaseBinding
kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge -p "{\"spec\":{\"releaseName\":\"$NEW_RELEASE\"}}"

# Restart deployment
kubectl rollout restart deploy inventorybackend-development-9ebcb79a \
  -n dp-default-inventorysyst-development-e51b7a18

# Wait for rollout
kubectl rollout status deploy inventorybackend-development-9ebcb79a \
  -n dp-default-inventorysyst-development-e51b7a18
```

---

## 🧪 Verify the Fix

### 1. Check the new connection string in pod
```bash
POD=$(kubectl get pods -n dp-default-inventorysyst-development-e51b7a18 \
    -l openchoreo.dev/component-uid=dd2aa576-2796-4431-a1bd-eb7f17c85a3c \
    -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n dp-default-inventorysyst-development-e51b7a18 $POD -- \
    printenv DATABASE_URL | grep -o "pooler.supabase.com:6543"
```

**Expected:** `pooler.supabase.com:6543`

### 2. Test API endpoint
```bash
curl -s http://development.openchoreoapis.localhost:19080/inventorybackend/api/products | jq
```

**Expected:** JSON array of products (or empty array `[]` if no data yet)

### 3. Check logs for successful connection
```bash
kubectl logs -n dp-default-inventorysyst-development-e51b7a18 $POD | grep -i "database\|connected"
```

**Expected:** `✅ Database connected successfully`

---

## 📊 Connection Comparison

| Aspect | Direct (5432) ❌ | Connection Pooler (6543) ✅ |
|--------|-----------------|---------------------------|
| **Hostname** | `db.PROJECT.supabase.co` | `aws-0-region.pooler.supabase.com` |
| **Port** | 5432 | 6543 |
| **IP Version** | IPv6 (k3d incompatible) | IPv4 (k3d compatible) |
| **Connection Pooling** | No | Yes (better for containers) |
| **Idle Timeout** | Long | Short (better for serverless) |
| **Best For** | Long-running servers | Containers, serverless, OpenChoreo |

---

## 🔍 Why This Happened

1. Supabase's direct connection endpoints (`db.*.supabase.co`) use **IPv6-first** DNS resolution
2. k3d/k3s clusters typically run with **IPv4-only** networking
3. When `pg` library tries to connect, it gets an IPv6 address it can't reach
4. The **connection pooler** (`*.pooler.supabase.com`) uses IPv4-compatible addresses

---

## 📝 Next Steps After Fix

Once connected successfully:

1. **Initialize your database schema** in Supabase SQL Editor:
   ```sql
   CREATE TABLE IF NOT EXISTS products (
       id SERIAL PRIMARY KEY,
       name VARCHAR(255) NOT NULL,
       description TEXT,
       sku VARCHAR(100) UNIQUE NOT NULL,
       quantity INTEGER DEFAULT 0,
       price NUMERIC(10, 2) NOT NULL,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

2. **Insert sample data**:
   ```sql
   INSERT INTO products (name, description, sku, quantity, price) 
   VALUES 
       ('Laptop', 'High-performance laptop', 'LAP-001', 15, 999.99),
       ('Mouse', 'Wireless mouse', 'MOU-001', 50, 29.99),
       ('Keyboard', 'Mechanical keyboard', 'KEY-001', 30, 79.99)
   ON CONFLICT (sku) DO NOTHING;
   ```

3. **Test CRUD operations** via API

---

## ❓ FAQ

**Q: Can I use the direct connection at all?**  
A: Not from k3d/OpenChoreo unless you enable IPv6 networking (complex).

**Q: Is connection pooling slower?**  
A: No! It's actually faster for short-lived connections (like container restarts).

**Q: Will this affect my production deployment?**  
A: Connection pooling is **recommended** for production containers/serverless.

**Q: How do I find my region?**  
A: Check your Supabase dashboard URL: `https://supabase.com/dashboard/project/[PROJECT-ID]`  
   Or look at the "Region" shown in Settings → General.

---

**Status:** ✅ Solution provided - waiting for corrected connection pooler URL

**Action Required:** Get the connection pooling URL from Supabase dashboard (port 6543)
