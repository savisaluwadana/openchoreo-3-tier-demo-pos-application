# OpenChoreo Deployment Guide (Simplified)

## 🎯 Quick Overview

Since OpenChoreo doesn't have direct GitHub integration, you'll deploy using:
1. **Build Docker images locally** (already done with `deploy.sh`)
2. **Push images to Docker Hub**
3. **Create project in OpenChoreo**
4. **Create components pointing to Docker images**

---

## 📦 Step 1: Build and Push Docker Images

Your images are already built. Now push them to Docker Hub:

```bash
# Login to Docker Hub
docker login

# Tag your images (replace YOUR_USERNAME)
docker tag inventory-backend:latest YOUR_USERNAME/inventory-backend:latest
docker tag inventory-frontend:latest YOUR_USERNAME/inventory-frontend:latest

# Push to Docker Hub
docker push YOUR_USERNAME/inventory-backend:latest
docker push YOUR_USERNAME/inventory-frontend:latest
```

---

## 🏗️ Step 2: Create Project in OpenChoreo

1. Go to OpenChoreo Dashboard
2. Click **"Create Project"** or navigate to Projects
3. Fill in:
   - **Name**: `inventory-system`
   - **Description**: `POS Inventory Management Application`
4. Click **"Create"**

---

## 🔧 Step 3: Create Components

### 3.1 Database Component (Service)

1. Inside your project, click **"Create"**
2. Select **"Service"** template
3. Configure:
   - **Name**: `inventory-database`
   - **Deployment Type**: Container Image
   - **Image**: `postgres:15-alpine`
   - **Port**: `5432`
   - **Environment Variables**:
     - `POSTGRES_DB`: `inventory_db`
     - `POSTGRES_USER`: `postgres`
     - `POSTGRES_PASSWORD`: `postgres` (add as secret)

4. **Storage** (if available):
   - Add persistent volume for `/var/lib/postgresql/data`
   - Size: `5Gi`

5. Click **"Create"**

---

### 3.2 Backend Component (Service)

1. Click **"Create"** again
2. Select **"Service"** template
3. Configure:
   - **Name**: `inventory-backend`
   - **Deployment Type**: Container Image
   - **Image**: `YOUR_USERNAME/inventory-backend:latest`
   - **Port**: `5000`
   - **Environment Variables**:
     - `PORT`: `5000`
     - `NODE_ENV`: `production`
     - `DATABASE_URL`: `postgresql://postgres:postgres@inventory-database:5432/inventory_db`
     - `FRONTEND_URL`: `http://inventory-frontend:3000`

4. Click **"Create"**

---

### 3.3 Frontend Component (Web Application)

1. Click **"Create"** again
2. Select **"Web Application"** template
3. Configure:
   - **Name**: `inventory-frontend`
   - **Deployment Type**: Container Image
   - **Image**: `YOUR_USERNAME/inventory-frontend:latest`
   - **Port**: `3000`
   - **Environment Variables**:
     - `NODE_ENV`: `production`
     - `NEXT_PUBLIC_API_URL`: `http://inventory-backend:5000/api`

4. Click **"Create"**

---

## 🚀 Step 4: Deploy Components

Deploy in this order:

1. **Deploy Database** first
   - Go to database component
   - Click "Deploy"
   - Wait for it to be running

2. **Initialize Database** (manual step):
   - Get the database pod name
   - Copy `init.sql` to the pod
   - Execute: `psql -U postgres -d inventory_db -f init.sql`

3. **Deploy Backend**
   - Go to backend component
   - Click "Deploy"
   - Wait for it to be running

4. **Deploy Frontend**
   - Go to frontend component
   - Click "Deploy"
   - Get the public URL

---

## 🌐 Step 5: Access Your Application

OpenChoreo will provide:
- **Frontend URL**: `https://inventory-frontend-xxx.openchoreo.dev` (or similar)
- Visit this URL to use your application

---

## 🔄 Alternative: Using Kubernetes Manifests

If OpenChoreo supports importing Kubernetes manifests:

1. **Upload** the files from `kubernetes/` directory
2. **Apply** them to your project
3. Components will be created automatically

---

## 📝 Component Summary

| Component | Type | Image | Port |
|-----------|------|-------|------|
| inventory-database | Service | postgres:15-alpine | 5432 |
| inventory-backend | Service | YOUR_USERNAME/inventory-backend:latest | 5000 |
| inventory-frontend | Web App | YOUR_USERNAME/inventory-frontend:latest | 3000 |

---

## 🔧 Environment Variables Reference

### Database
```
POSTGRES_DB=inventory_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
```

### Backend
```
PORT=5000
NODE_ENV=production
DATABASE_URL=postgresql://postgres:postgres@inventory-database:5432/inventory_db
FRONTEND_URL=http://inventory-frontend:3000
```

### Frontend
```
NODE_ENV=production
NEXT_PUBLIC_API_URL=http://inventory-backend:5000/api
```

**Note**: Update URLs based on actual service names in OpenChoreo.

---

## 🐛 Troubleshooting

### Images not pulling?
- Make sure images are public on Docker Hub
- Or add Docker registry credentials in OpenChoreo

### Database not initialized?
- Manually exec into database pod
- Run `init.sql` script

### Backend can't connect to database?
- Check `DATABASE_URL` environment variable
- Verify database service name matches
- Check if database is running

### Frontend can't reach backend?
- Update `NEXT_PUBLIC_API_URL` with correct backend URL
- Check CORS settings in backend

---

## ✅ Deployment Checklist

- [ ] Docker images built locally
- [ ] Images pushed to Docker Hub
- [ ] Project created in OpenChoreo
- [ ] Database component created
- [ ] Backend component created
- [ ] Frontend component created
- [ ] Database deployed
- [ ] Database initialized with schema
- [ ] Backend deployed
- [ ] Frontend deployed
- [ ] Application accessible via URL

---

Your application is now deployed on OpenChoreo! 🎉
