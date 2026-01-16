#!/bin/bash

# OpenChoreo Deployment Script for Inventory Management System

set -e

echo "🚀 Starting OpenChoreo Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOCKER_USERNAME="${DOCKER_USERNAME:-YOUR_DOCKERHUB_USERNAME}"
NAMESPACE="inventory-system"
BACKEND_IMAGE="${DOCKER_USERNAME}/inventory-backend:latest"
FRONTEND_IMAGE="${DOCKER_USERNAME}/inventory-frontend:latest"

# Step 1: Build Docker Images
echo -e "${YELLOW}Step 1: Building Docker images...${NC}"

echo "Building backend image..."
cd backend
docker build -t ${BACKEND_IMAGE} .
cd ..

echo "Building frontend image..."
cd frontend
docker build -t ${FRONTEND_IMAGE} .
cd ..

echo -e "${GREEN}✓ Docker images built successfully${NC}"

# Step 2: Push to Docker Registry
echo -e "${YELLOW}Step 2: Pushing images to Docker registry...${NC}"

docker push ${BACKEND_IMAGE}
docker push ${FRONTEND_IMAGE}

echo -e "${GREEN}✓ Images pushed successfully${NC}"

# Step 3: Update Kubernetes manifests with image names
echo -e "${YELLOW}Step 3: Updating Kubernetes manifests...${NC}"

# Update backend deployment
sed -i.bak "s|YOUR_DOCKERHUB_USERNAME/inventory-backend:latest|${BACKEND_IMAGE}|g" kubernetes/backend-deployment.yaml

# Update frontend deployment
sed -i.bak "s|YOUR_DOCKERHUB_USERNAME/inventory-frontend:latest|${FRONTEND_IMAGE}|g" kubernetes/frontend-deployment.yaml

# Remove backup files
rm -f kubernetes/*.bak

echo -e "${GREEN}✓ Manifests updated${NC}"

# Step 4: Create namespace
echo -e "${YELLOW}Step 4: Creating namespace...${NC}"

kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Namespace created${NC}"

# Step 5: Deploy database
echo -e "${YELLOW}Step 5: Deploying PostgreSQL database...${NC}"

kubectl apply -f kubernetes/postgres-deployment.yaml -n ${NAMESPACE}

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=120s

echo -e "${GREEN}✓ PostgreSQL deployed${NC}"

# Step 6: Initialize database
echo -e "${YELLOW}Step 6: Initializing database schema...${NC}"

POSTGRES_POD=$(kubectl get pod -l app=postgres -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')

kubectl cp init.sql ${NAMESPACE}/${POSTGRES_POD}:/tmp/init.sql
kubectl exec -it ${POSTGRES_POD} -n ${NAMESPACE} -- psql -U postgres -d inventory_db -f /tmp/init.sql

echo -e "${GREEN}✓ Database initialized${NC}"

# Step 7: Deploy backend
echo -e "${YELLOW}Step 7: Deploying backend...${NC}"

kubectl apply -f kubernetes/backend-deployment.yaml -n ${NAMESPACE}

echo "Waiting for backend to be ready..."
kubectl wait --for=condition=ready pod -l app=backend -n ${NAMESPACE} --timeout=120s

echo -e "${GREEN}✓ Backend deployed${NC}"

# Step 8: Deploy frontend
echo -e "${YELLOW}Step 8: Deploying frontend...${NC}"

kubectl apply -f kubernetes/frontend-deployment.yaml -n ${NAMESPACE}

echo "Waiting for frontend to be ready..."
kubectl wait --for=condition=ready pod -l app=frontend -n ${NAMESPACE} --timeout=120s

echo -e "${GREEN}✓ Frontend deployed${NC}"

# Step 9: Display deployment status
echo -e "${YELLOW}Step 9: Deployment summary${NC}"

echo ""
echo "📊 Deployment Status:"
kubectl get all -n ${NAMESPACE}

echo ""
echo "🌐 Services:"
kubectl get svc -n ${NAMESPACE}

echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"

echo ""
echo "📝 Next steps:"
echo "1. Access your application:"
echo "   kubectl port-forward svc/frontend-service 3000:3000 -n ${NAMESPACE}"
echo "   Then open http://localhost:3000"
echo ""
echo "2. View logs:"
echo "   Backend:  kubectl logs -f deployment/backend -n ${NAMESPACE}"
echo "   Frontend: kubectl logs -f deployment/frontend -n ${NAMESPACE}"
echo "   Database: kubectl logs -f deployment/postgres -n ${NAMESPACE}"
echo ""
echo "3. Scale deployments:"
echo "   kubectl scale deployment backend --replicas=3 -n ${NAMESPACE}"
echo "   kubectl scale deployment frontend --replicas=3 -n ${NAMESPACE}"
