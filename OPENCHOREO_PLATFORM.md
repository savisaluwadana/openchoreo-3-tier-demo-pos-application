# Deploying to OpenChoreo Platform

The previous deployment was for plain Kubernetes. To deploy to **OpenChoreo Platform**, you need to register your components through the OpenChoreo UI.

---

## 🎯 OpenChoreo Deployment Steps

### Step 1: Prepare Your Repository

Your code needs to be in a Git repository (GitHub, GitLab, or Bitbucket).

```bash
# If not already done, push your code to GitHub
git init
git add .
git commit -m "Initial commit - Inventory Management System"
git remote add origin https://github.com/YOUR_USERNAME/openchoreo-3-tier-demo-pos-application.git
git push -u origin main
```

---

### Step 2: Create Components in OpenChoreo

You need to create **3 components** in OpenChoreo:

#### 2.1 Database Component

1. Click **"Create"** button in OpenChoreo Catalog
2. Select **"Database"** or **"PostgreSQL"**
3. Configure:
   - **Name**: `inventory-database`
   - **Type**: PostgreSQL
   - **Version**: 15
   - **Storage**: 5Gi

#### 2.2 Backend Service Component

1. Click **"Create"** → **"Service"**
2. Configure:
   - **Name**: `inventory-backend`
   - **Repository URL**: `https://github.com/YOUR_USERNAME/openchoreo-3-tier-demo-pos-application`
   - **Branch**: `main`
   - **Build Path**: `/backend`
   - **Dockerfile Path**: `/backend/Dockerfile`
   - **Port**: `5000`

3. Add **Environment Variables**:
   ```
   DATABASE_URL=<from database component>
   PORT=5000
   FRONTEND_URL=<will be set after frontend is created>
   ```

#### 2.3 Frontend Web App Component

1. Click **"Create"** → **"Web Application"**
2. Configure:
   - **Name**: `inventory-frontend`
   - **Repository URL**: `https://github.com/YOUR_USERNAME/openchoreo-3-tier-demo-pos-application`
   - **Branch**: `main`
   - **Build Path**: `/frontend`
   - **Dockerfile Path**: `/frontend/Dockerfile`
   - **Port**: `3000`

3. Add **Environment Variables**:
   ```
   NEXT_PUBLIC_API_URL=<backend service URL>
   ```

---

### Step 3: Create Component Configurations

For OpenChoreo to recognize your components, create `.choreo` directory structure:

```
.choreo/
├── backend/
│   └── component.yaml
├── frontend/
│   └── component.yaml
└── database/
    └── component.yaml
```

---

### Step 4: Link Components

In OpenChoreo UI:

1. **Database → Backend**: Create connection
   - This will inject `DATABASE_URL` into backend
   
2. **Backend → Frontend**: Create connection
   - Frontend will get the backend API URL

---

### Step 5: Deploy

1. **Deploy Database** first (wait for it to be ready)
2. **Initialize Database Schema**:
   - Run `init.sql` as an initialization job
3. **Deploy Backend** (it will connect to database)
4. **Deploy Frontend** (it will connect to backend)

---

## 📁 OpenChoreo Component Configuration Files

### Backend Component Config

Create `.choreo/backend/component.yaml`:

```yaml
apiVersion: core.choreo.dev/v1alpha1
kind: Component
metadata:
  name: inventory-backend
  displayName: Inventory Backend API
spec:
  type: Service
  buildSpec:
    path: backend
    dockerfile: backend/Dockerfile
  ports:
    - name: http
      containerPort: 5000
      protocol: TCP
  env:
    - name: PORT
      value: "5000"
    - name: NODE_ENV
      value: "production"
  dependencies:
    - name: inventory-database
      type: Database
```

### Frontend Component Config

Create `.choreo/frontend/component.yaml`:

```yaml
apiVersion: core.choreo.dev/v1alpha1
kind: Component
metadata:
  name: inventory-frontend
  displayName: Inventory Frontend
spec:
  type: WebApp
  buildSpec:
    path: frontend
    dockerfile: frontend/Dockerfile
  ports:
    - name: http
      containerPort: 3000
      protocol: TCP
  env:
    - name: NODE_ENV
      value: "production"
  dependencies:
    - name: inventory-backend
      type: Service
```

---

## 🔧 Alternative: Using OpenChoreo CLI

If OpenChoreo provides a CLI tool:

```bash
# Login to OpenChoreo
choreo login

# Create project
choreo project create inventory-system

# Create database
choreo database create \
  --name inventory-database \
  --type postgres \
  --version 15

# Create backend service
choreo service create \
  --name inventory-backend \
  --repo https://github.com/YOUR_USERNAME/openchoreo-3-tier-demo-pos-application \
  --path backend \
  --dockerfile backend/Dockerfile \
  --port 5000

# Create frontend
choreo webapp create \
  --name inventory-frontend \
  --repo https://github.com/YOUR_USERNAME/openchoreo-3-tier-demo-pos-application \
  --path frontend \
  --dockerfile frontend/Dockerfile \
  --port 3000

# Deploy all
choreo deploy --all
```

---

## 📊 Current Status

Your application is currently deployed directly to Kubernetes using `kubectl`, but **not registered in OpenChoreo**.

### To see it in OpenChoreo Dashboard:

You need to either:

**Option 1**: Register existing Kubernetes deployments in OpenChoreo
- Import existing deployments into OpenChoreo catalog

**Option 2**: Delete Kubernetes deployments and create through OpenChoreo UI
```bash
# Clean up direct Kubernetes deployment
kubectl delete namespace inventory-system
```
Then create components through OpenChoreo UI

---

## 🎨 OpenChoreo UI Workflow

1. **Create** button → Opens component creation wizard
2. Select **component type**: Service, WebApp, or Database
3. **Configure** component with:
   - Git repository
   - Build settings
   - Environment variables
4. **Deploy** to environment (Dev/Staging/Prod)
5. **Monitor** in the dashboard

---

## 📝 Next Steps

1. ✅ Ensure your code is pushed to GitHub
2. ✅ Create database component in OpenChoreo
3. ✅ Create backend service component
4. ✅ Create frontend webapp component
5. ✅ Configure connections between components
6. ✅ Deploy all components
7. ✅ Access your application through OpenChoreo URLs

---

## 🔍 Troubleshooting

**Why don't I see my components?**
- Components deployed with `kubectl` directly won't appear in OpenChoreo catalog
- You must create components through OpenChoreo UI/CLI

**How to register existing deployments?**
- Check OpenChoreo documentation for "Import" or "Discover" feature
- Or delete and recreate through OpenChoreo

**Where are the component URLs?**
- OpenChoreo generates URLs after deployment
- Check the component detail page in the dashboard

---

For platform-specific instructions, consult your OpenChoreo instance documentation or admin.
