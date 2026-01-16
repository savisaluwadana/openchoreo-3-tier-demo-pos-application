# OpenChoreo Deployment - Using Pre-Built Images

Since OpenChoreo CI/CD is having issues, we'll use pre-built Docker images instead.

---

## 🚀 Quick Deployment Steps

### Step 1: Build and Push Images Locally

```bash
# Make sure you're in the project root
cd /Users/savisaluwadana/Desktop/OpenChoreo\ POS\ Demo/openchoreo-3-tier-demo-pos-application

# Login to Docker Hub
docker login

# Build all three images
docker build -t YOUR_USERNAME/inventory-database:latest ./database
docker build -t YOUR_USERNAME/inventory-backend:latest ./backend
docker build -t YOUR_USERNAME/inventory-frontend:latest ./frontend

# Push to Docker Hub
docker push YOUR_USERNAME/inventory-database:latest
docker push YOUR_USERNAME/inventory-backend:latest
docker push YOUR_USERNAME/inventory-frontend:latest
```

Replace `YOUR_USERNAME` with your actual Docker Hub username.

---

## 📦 Step 2: Delete and Recreate Components

### Delete Current Database Component
1. Go to the `inventorydatabase` component
2. Delete it (since CI/CD build failed)

---

### Create Database Component (Using Image)

1. Click **"Create"** → **"Service"**
2. Fill in **Component Metadata**:
   - **Component Name**: `inventorydatabase`
   - **Description**: `PostgreSQL database for inventory system`

3. **Service Configuration**:
   - **Container Name**: `main`
   - **Exposed**: ☐ Unchecked
   - **Image Pull Policy**: `IfNotPresent`
   - **Port**: `5432`
   - **Replicas**: `1`

4. **CI/CD Setup**:
   - **Use Built-in CI**: ❌ **DISABLE THIS**
   - Skip all workflow parameters

5. **Traits**:
   - Skip (we'll add env vars later)

6. **Review and Create**

---

### After Creation - Add Image Manually

Since we disabled CI/CD, you need to configure the component to use your Docker Hub image:

1. Go to component settings or configuration
2. Find **Container Image** or **Image** field
3. Set it to: `YOUR_USERNAME/inventory-database:latest`

---

## 🔧 Step 3: Add Environment Variables

Go to **TRAITS** tab and add:

```
POSTGRES_DB=inventory_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
```

Mark `POSTGRES_PASSWORD` as secret.

---

## ✅ Step 4: Deploy Database

1. Go to **DEPLOY** tab
2. Click **"Go to Deploy"**
3. Deploy to Production
4. Wait for it to be running

---

## 🔄 Step 5: Create Backend Component

1. Build and push backend image (if not done):
   ```bash
   docker build -t YOUR_USERNAME/inventory-backend:latest ./backend
   docker push YOUR_USERNAME/inventory-backend:latest
   ```

2. Create Service Component:
   - **Name**: `inventorybackend`
   - **Port**: `5000`
   - **Image**: `YOUR_USERNAME/inventory-backend:latest`
   - **CI/CD**: DISABLED
   
3. Add environment variables:
   ```
   PORT=5000
   NODE_ENV=production
   DATABASE_URL=postgresql://postgres:postgres@inventorydatabase-main:5432/inventory_db
   FRONTEND_URL=http://inventoryfrontend-main:3000
   ```

4. Deploy

---

## 🌐 Step 6: Create Frontend Component

1. Build and push frontend image (if not done):
   ```bash
   docker build -t YOUR_USERNAME/inventory-frontend:latest ./frontend
   docker push YOUR_USERNAME/inventory-frontend:latest
   ```

2. Create Web Application Component:
   - **Name**: `inventoryfrontend`
   - **Port**: `3000`
   - **Image**: `YOUR_USERNAME/inventory-frontend:latest`
   - **CI/CD**: DISABLED
   
3. Add environment variables:
   ```
   NODE_ENV=production
   NEXT_PUBLIC_API_URL=http://inventorybackend-main:5000/api
   ```

4. Deploy

---

## 🎯 Service Names in OpenChoreo

Components communicate using these service names:
- Database: `inventorydatabase-main:5432`
- Backend: `inventorybackend-main:5000`
- Frontend: `inventoryfrontend-main:3000`

Update environment variables if the service names are different in your cluster.

---

## ✅ Verification

1. Check all three components are running
2. Access frontend URL from OpenChoreo
3. Test CRUD operations

---

This approach bypasses the CI/CD build issues and uses your pre-built images directly! 🚀
