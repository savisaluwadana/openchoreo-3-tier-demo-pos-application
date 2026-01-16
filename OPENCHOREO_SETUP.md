# OpenChoreo Project Setup Guide

This guide walks you through creating a project and deploying all three components in OpenChoreo.

---

## 📁 Repository Structure

Your repository now has the OpenChoreo component structure:

```
openchoreo-3-tier-demo-pos-application/
├── .choreo/
│   ├── database/
│   │   └── component.yaml       # Database component config
│   ├── backend/
│   │   └── component.yaml       # Backend service config
│   └── frontend/
│       └── component.yaml       # Frontend webapp config
├── database/
│   ├── Dockerfile
│   └── init.sql
├── backend/
│   ├── Dockerfile
│   ├── src/
│   └── package.json
└── frontend/
    ├── Dockerfile
    ├── src/
    └── package.json
```

---

## 🚀 Step-by-Step Deployment

### Step 1: Push Code to GitHub

```bash
git add .
git commit -m "Add OpenChoreo component configurations"
git push origin main
```

---

### Step 2: Create a Project in OpenChoreo

1. **Navigate to OpenChoreo Dashboard**
2. **Click "Projects"** or **"Create Project"**
3. **Fill in project details**:
   - **Project Name**: `Inventory Management System`
   - **Description**: `3-tier POS inventory application with PostgreSQL, Express, and Next.js`
   - **Repository**: Connect your GitHub repository
   - **Default Branch**: `main`

---

### Step 3: Create Component #1 - Database

1. **In your project**, click **"Create"** → **"Service"** (we'll use Service template for database)
2. **Component Configuration**:
   - **Template**: Choose "Service"
   - **Repository**: `https://github.com/YOUR_USERNAME/openchoreo-3-tier-demo-pos-application`
   - **Branch**: `main`
   - **Component Path**: `.choreo/database` or select database from detected components
   - **Name**: `inventory-database`
   - **Build Pack**: Dockerfile
   - **Dockerfile Path**: `database/Dockerfile`
   - **Port**: `5432`

3. **Environment Variables** (Secrets):
   - `POSTGRES_PASSWORD`: `postgres` (or your secure password)

4. **Click "Create"**

---

### Step 4: Create Component #2 - Backend Service

1. **Click "Create"** → **"Service"**
2. **Component Configuration**:
   - **Template**: Choose "Service"
   - **Repository**: Same as above
   - **Branch**: `main`
   - **Component Path**: `.choreo/backend`
   - **Name**: `inventory-backend`
   - **Build Pack**: Dockerfile
   - **Dockerfile Path**: `backend/Dockerfile`
   - **Port**: `5000`

3. **Environment Variables**:
   - `PORT`: `5000`
   - `NODE_ENV`: `production`
   - `FRONTEND_URL`: `<will add after frontend is created>`
   - `DATABASE_URL`: `<will connect to database component>`

4. **Click "Create"**

---

### Step 5: Create Component #3 - Frontend Web App

1. **Click "Create"** → **"Web Application"**
2. **Component Configuration**:
   - **Template**: Choose "Web Application"
   - **Repository**: Same as above
   - **Branch**: `main`
   - **Component Path**: `.choreo/frontend`
   - **Name**: `inventory-frontend`
   - **Build Pack**: Dockerfile
   - **Dockerfile Path**: `frontend/Dockerfile`
   - **Port**: `3000`

3. **Environment Variables**:
   - `NODE_ENV`: `production`
   - `NEXT_PUBLIC_API_URL`: `<will get from backend service URL>`

4. **Click "Create"**

---

### Step 6: Create Connections Between Components

#### Connect Backend → Database

1. **Navigate to Backend component**
2. **Go to "Connections" or "Dependencies"**
3. **Add Connection**:
   - **Type**: Database
   - **Target**: `inventory-database`
   - **Connection Name**: `database`
4. **This will inject** `DATABASE_URL` environment variable automatically

#### Connect Frontend → Backend

1. **Navigate to Frontend component**
2. **Go to "Connections"**
3. **Add Connection**:
   - **Type**: Service
   - **Target**: `inventory-backend`
   - **Connection Name**: `backend-api`
4. **Update Frontend Environment**:
   - `NEXT_PUBLIC_API_URL`: Use the backend service URL provided by OpenChoreo

---

### Step 7: Deploy Components in Order

#### 7.1 Deploy Database

1. **Go to Database component**
2. **Click "Deploy"** → Select environment (e.g., Development)
3. **Wait for deployment** to complete
4. **Verify**: Database pod is running and initialized with `init.sql`

#### 7.2 Deploy Backend

1. **Go to Backend component**
2. **Update** `DATABASE_URL` with the connection string from database component
3. **Click "Deploy"** → Select environment
4. **Wait for deployment** to complete
5. **Test**: Access the health endpoint `/health`

#### 7.3 Deploy Frontend

1. **Go to Frontend component**
2. **Update** `NEXT_PUBLIC_API_URL` with backend service URL
3. **Click "Deploy"** → Select environment
4. **Wait for deployment** to complete
5. **Access**: OpenChoreo will provide a public URL

---

### Step 8: Access Your Application

Once all components are deployed:

1. **Frontend URL**: OpenChoreo provides a public URL (e.g., `https://inventory-frontend-xxx.choreo.dev`)
2. **Backend API**: Internal service URL or exposed endpoint
3. **Database**: Accessible only internally by backend

**Visit the frontend URL** to use your Inventory Management System! 🎉

---

## 🔧 Environment Variables Summary

### Database Component
```
POSTGRES_DB=inventory_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<secret>
```

### Backend Component
```
PORT=5000
NODE_ENV=production
DATABASE_URL=postgresql://postgres:<password>@inventory-database:5432/inventory_db
FRONTEND_URL=<frontend-url-from-openchoreo>
```

### Frontend Component
```
NODE_ENV=production
NEXT_PUBLIC_API_URL=<backend-service-url-from-openchoreo>
```

---

## 📊 Monitoring Your Application

### In OpenChoreo Dashboard:

1. **View Logs**: Each component has a logs viewer
2. **Metrics**: CPU, Memory, Request counts
3. **Health Status**: Check if all components are running
4. **Scale**: Adjust replicas for backend/frontend

### Check Component Status:

```bash
# If OpenChoreo provides CLI
choreo component list --project inventory-system
choreo component logs inventory-backend
choreo component logs inventory-frontend
```

---

## 🔄 Making Updates

### Update Code:

1. Make changes locally
2. Commit and push to GitHub
3. OpenChoreo can auto-deploy or you trigger manually
4. Components will rebuild and redeploy

### Update Environment Variables:

1. Go to component settings
2. Update environment variables
3. Restart/redeploy the component

---

## 🐛 Troubleshooting

### Component won't build?
- Check Dockerfile paths in component.yaml
- Verify all files are in the correct directories
- Check build logs in OpenChoreo

### Database connection failed?
- Verify `DATABASE_URL` is correctly set
- Check if database component is running
- Verify connection/dependency is created

### Frontend can't reach backend?
- Check `NEXT_PUBLIC_API_URL` is set correctly
- Verify backend service is deployed and running
- Check CORS settings in backend

---

## 📋 Deployment Checklist

- [ ] Repository pushed to GitHub
- [ ] Project created in OpenChoreo
- [ ] Database component created and configured
- [ ] Backend component created and configured
- [ ] Frontend component created and configured
- [ ] Database ↔ Backend connection established
- [ ] Backend ↔ Frontend connection established
- [ ] Database deployed and initialized
- [ ] Backend deployed and health check passing
- [ ] Frontend deployed and accessible
- [ ] Can create/read/update/delete products
- [ ] All environment variables configured correctly

---

## 🎯 Next Steps

- Set up CI/CD pipelines
- Configure custom domains
- Enable SSL/TLS
- Set up monitoring and alerts
- Configure autoscaling
- Set up database backups

---

Your application is now running on OpenChoreo! 🚀
