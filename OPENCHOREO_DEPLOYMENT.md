# Deploying to OpenChoreo

This guide walks you through deploying the Inventory Management System to OpenChoreo.

## Architecture Overview

Your application has 3 components:
1. **PostgreSQL Database** - Data storage
2. **Express Backend** - API server
3. **Next.js Frontend** - User interface

---

## Prerequisites

- OpenChoreo cluster running
- `kubectl` configured to access your cluster
- Docker installed locally
- Docker registry access (Docker Hub, GitHub Container Registry, etc.)

---

## Step 1: Prepare Your Code for Deployment

### 1.1 Push Code to GitHub

```bash
# Initialize git (if not already done)
git init
git add .
git commit -m "Initial commit - Inventory Management System"

# Create a new GitHub repository and push
git remote add origin https://github.com/YOUR_USERNAME/openchoreo-3-tier-demo-pos-application.git
git branch -M main
git push -u origin main
```

### 1.2 Project Structure

Your repository should have this structure:
```
├── backend/          # Express API
├── frontend/         # Next.js app
├── init.sql          # Database schema
├── docker-compose.yml
└── kubernetes/       # K8s manifests (we'll create this)
```

---

## Step 2: Containerize Your Applications

### 2.1 Create Backend Dockerfile

Create `backend/Dockerfile`:
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

EXPOSE 5000

CMD ["npm", "start"]
```

### 2.2 Create Frontend Dockerfile

Create `frontend/Dockerfile`:
```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:18-alpine AS runner

WORKDIR /app

ENV NODE_ENV production

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules

EXPOSE 3000

CMD ["npm", "start"]
```

---

## Step 3: Build and Push Docker Images

### 3.1 Build Images

```bash
# Build backend
cd backend
docker build -t YOUR_DOCKERHUB_USERNAME/inventory-backend:latest .

# Build frontend
cd ../frontend
docker build -t YOUR_DOCKERHUB_USERNAME/inventory-frontend:latest .
```

### 3.2 Push to Docker Registry

```bash
# Login to Docker Hub
docker login

# Push images
docker push YOUR_DOCKERHUB_USERNAME/inventory-backend:latest
docker push YOUR_DOCKERHUB_USERNAME/inventory-frontend:latest
```

---

## Step 4: Create Kubernetes Manifests

We'll create Kubernetes manifests for all three components.

### 4.1 Database Deployment

Create `kubernetes/postgres-deployment.yaml`

### 4.2 Backend Deployment

Create `kubernetes/backend-deployment.yaml`

### 4.3 Frontend Deployment

Create `kubernetes/frontend-deployment.yaml`

---

## Step 5: Deploy to OpenChoreo

### 5.1 Apply Kubernetes Manifests

```bash
# Create namespace
kubectl create namespace inventory-system

# Apply all manifests
kubectl apply -f kubernetes/ -n inventory-system

# Check deployments
kubectl get pods -n inventory-system
kubectl get services -n inventory-system
```

### 5.2 Initialize Database

```bash
# Get PostgreSQL pod name
kubectl get pods -n inventory-system | grep postgres

# Copy init.sql to pod
kubectl cp init.sql <postgres-pod-name>:/tmp/init.sql -n inventory-system

# Execute initialization
kubectl exec -it <postgres-pod-name> -n inventory-system -- psql -U postgres -d inventory_db -f /tmp/init.sql
```

---

## Step 6: Access Your Application

### Option 1: Port Forward (Development)

```bash
# Forward frontend
kubectl port-forward svc/frontend-service 3000:3000 -n inventory-system

# Access at http://localhost:3000
```

### Option 2: Ingress (Production)

Configure ingress in `kubernetes/ingress.yaml` with your domain.

---

## Step 7: Environment Variables

Update environment variables in the Kubernetes manifests:

**Backend:**
- `DATABASE_URL`: Connection to PostgreSQL service
- `PORT`: 5000
- `FRONTEND_URL`: Frontend service URL

**Frontend:**
- `NEXT_PUBLIC_API_URL`: Backend service URL

---

## Monitoring & Logs

### View Logs

```bash
# Backend logs
kubectl logs -f deployment/backend -n inventory-system

# Frontend logs
kubectl logs -f deployment/frontend -n inventory-system

# Database logs
kubectl logs -f deployment/postgres -n inventory-system
```

### Check Status

```bash
# All resources
kubectl get all -n inventory-system

# Describe pod for issues
kubectl describe pod <pod-name> -n inventory-system
```

---

## Scaling

```bash
# Scale backend
kubectl scale deployment backend --replicas=3 -n inventory-system

# Scale frontend
kubectl scale deployment frontend --replicas=3 -n inventory-system
```

---

## Troubleshooting

### Common Issues

1. **ImagePullBackOff**: Check Docker registry credentials
2. **CrashLoopBackOff**: Check logs and environment variables
3. **Connection Refused**: Verify service names and ports

### Debug Commands

```bash
# Get pod details
kubectl describe pod <pod-name> -n inventory-system

# Get into container shell
kubectl exec -it <pod-name> -n inventory-system -- sh

# Check service endpoints
kubectl get endpoints -n inventory-system
```

---

## Next Steps

1. Set up CI/CD pipeline
2. Configure monitoring (Prometheus/Grafana)
3. Set up automated backups for PostgreSQL
4. Configure SSL/TLS certificates
5. Implement horizontal pod autoscaling

---

## Cleanup

```bash
# Delete all resources
kubectl delete namespace inventory-system
```

---

For detailed Kubernetes manifest files, see the `kubernetes/` directory.
