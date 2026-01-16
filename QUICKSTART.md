# 🚀 Quick Start: Deploy to OpenChoreo

## Prerequisites Checklist

- [ ] OpenChoreo/Kubernetes cluster running
- [ ] `kubectl` installed and configured
- [ ] Docker installed
- [ ] Docker Hub account (or other container registry)
- [ ] Code pushed to GitHub

---

## 🎯 Deployment Steps

### Option 1: Automated Deployment (Recommended)

```bash
# 1. Set your Docker Hub username
export DOCKER_USERNAME=your_dockerhub_username

# 2. Login to Docker Hub
docker login

# 3. Run the deployment script
./deploy.sh
```

The script will:
- ✅ Build Docker images for backend and frontend
- ✅ Push images to Docker Hub
- ✅ Create Kubernetes namespace
- ✅ Deploy PostgreSQL database
- ✅ Initialize database schema
- ✅ Deploy backend API
- ✅ Deploy frontend application

---

### Option 2: Manual Deployment

#### Step 1: Build and Push Docker Images

```bash
# Build backend
cd backend
docker build -t your_username/inventory-backend:latest .
docker push your_username/inventory-backend:latest

# Build frontend
cd ../frontend
docker build -t your_username/inventory-frontend:latest .
docker push your_username/inventory-frontend:latest
```

#### Step 2: Update Kubernetes Manifests

Edit the following files and replace `YOUR_DOCKERHUB_USERNAME`:
- `kubernetes/backend-deployment.yaml`
- `kubernetes/frontend-deployment.yaml`

#### Step 3: Deploy to Kubernetes

```bash
# Create namespace
kubectl create namespace inventory-system

# Deploy database
kubectl apply -f kubernetes/postgres-deployment.yaml -n inventory-system

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n inventory-system --timeout=120s

# Initialize database
POSTGRES_POD=$(kubectl get pod -l app=postgres -n inventory-system -o jsonpath='{.items[0].metadata.name}')
kubectl cp init.sql inventory-system/${POSTGRES_POD}:/tmp/init.sql
kubectl exec -it ${POSTGRES_POD} -n inventory-system -- psql -U postgres -d inventory_db -f /tmp/init.sql

# Deploy backend
kubectl apply -f kubernetes/backend-deployment.yaml -n inventory-system

# Deploy frontend
kubectl apply -f kubernetes/frontend-deployment.yaml -n inventory-system
```

---

## 🌐 Access Your Application

### Local Access (Port Forward)

```bash
# Forward frontend to localhost
kubectl port-forward svc/frontend-service 3000:3000 -n inventory-system
```

Open `http://localhost:3000` in your browser

### Production Access (Ingress)

1. Update `kubernetes/ingress.yaml` with your domain
2. Apply ingress:
```bash
kubectl apply -f kubernetes/ingress.yaml -n inventory-system
```

---

## 📊 Monitoring & Management

### View All Resources

```bash
kubectl get all -n inventory-system
```

### View Logs

```bash
# Backend logs
kubectl logs -f deployment/backend -n inventory-system

# Frontend logs
kubectl logs -f deployment/frontend -n inventory-system

# Database logs
kubectl logs -f deployment/postgres -n inventory-system
```

### Check Pod Status

```bash
kubectl get pods -n inventory-system
```

### Describe Resources

```bash
kubectl describe deployment backend -n inventory-system
kubectl describe service backend-service -n inventory-system
```

---

## 🔧 Scaling

```bash
# Scale backend to 3 replicas
kubectl scale deployment backend --replicas=3 -n inventory-system

# Scale frontend to 3 replicas
kubectl scale deployment frontend --replicas=3 -n inventory-system
```

---

## 🛠️ Troubleshooting

### Pods not starting?

```bash
# Check pod status
kubectl get pods -n inventory-system

# View pod details
kubectl describe pod <pod-name> -n inventory-system

# Check logs
kubectl logs <pod-name> -n inventory-system
```

### Database connection issues?

```bash
# Test database connectivity
kubectl exec -it <backend-pod> -n inventory-system -- sh
# Inside pod:
nc -zv postgres-service 5432
```

### Image pull errors?

```bash
# Verify image exists in registry
docker pull your_username/inventory-backend:latest

# Check if Kubernetes can pull the image
kubectl describe pod <pod-name> -n inventory-system
```

---

## 🔄 Update Deployment

### Update Backend

```bash
cd backend
docker build -t your_username/inventory-backend:v2 .
docker push your_username/inventory-backend:v2

# Update deployment
kubectl set image deployment/backend backend=your_username/inventory-backend:v2 -n inventory-system

# Or restart deployment
kubectl rollout restart deployment/backend -n inventory-system
```

### Update Frontend

```bash
cd frontend
docker build -t your_username/inventory-frontend:v2 .
docker push your_username/inventory-frontend:v2

kubectl set image deployment/frontend frontend=your_username/inventory-frontend:v2 -n inventory-system
```

---

## 🗑️ Cleanup

```bash
# Delete all resources
kubectl delete namespace inventory-system

# Or delete specific resources
kubectl delete -f kubernetes/ -n inventory-system
```

---

## 📋 Post-Deployment Checklist

- [ ] All pods are running (`kubectl get pods -n inventory-system`)
- [ ] Services are created (`kubectl get svc -n inventory-system`)
- [ ] Database is initialized (check logs)
- [ ] Backend health check is passing (curl backend/health)
- [ ] Frontend is accessible
- [ ] Can create/read/update/delete products
- [ ] Set up monitoring and alerts
- [ ] Configure backups for database
- [ ] Set up CI/CD pipeline

---

## 🔗 Useful Commands

```bash
# Get all resources in namespace
kubectl get all -n inventory-system

# Watch pod status
kubectl get pods -n inventory-system -w

# Execute command in pod
kubectl exec -it <pod-name> -n inventory-system -- sh

# Copy files to/from pod
kubectl cp file.txt inventory-system/<pod-name>:/tmp/

# Port forward any service
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n inventory-system

# View events
kubectl get events -n inventory-system --sort-by='.lastTimestamp'
```

---

For detailed deployment documentation, see `OPENCHOREO_DEPLOYMENT.md`
