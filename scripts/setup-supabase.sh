#!/bin/bash

# 🔗 Supabase Connection Setup Script for OpenChoreo
# This script helps you quickly connect your OpenChoreo backend to Supabase

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🔗 OpenChoreo → Supabase Connection Setup          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Get Supabase connection string
echo -e "${YELLOW}📝 Step 1: Enter your Supabase connection details${NC}"
echo ""
echo "You can find this in Supabase Dashboard → Settings → Database → Connection String"
echo "Use the 'Connection Pooling' string (recommended)"
echo ""
read -p "Enter your Supabase connection string: " SUPABASE_URL

if [ -z "$SUPABASE_URL" ]; then
    echo -e "${RED}❌ Error: Connection string cannot be empty${NC}"
    exit 1
fi

# Validate connection string format
if [[ ! "$SUPABASE_URL" =~ ^postgresql:// ]]; then
    echo -e "${RED}❌ Error: Invalid connection string format. Should start with 'postgresql://'${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Connection string captured${NC}"
echo ""

# Step 2: Find dataplane namespace
echo -e "${YELLOW}🔍 Step 2: Finding OpenChoreo dataplane namespace...${NC}"
DATAPLANE_NS=$(kubectl get ns | grep 'dp-default-inventorysyst-development' | awk '{print $1}')

if [ -z "$DATAPLANE_NS" ]; then
    echo -e "${RED}❌ Error: Could not find dataplane namespace. Is OpenChoreo running?${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found dataplane: $DATAPLANE_NS${NC}"
echo ""

# Step 3: Test connection
echo -e "${YELLOW}🧪 Step 3: Testing Supabase connection...${NC}"

# Check if psql is available
if command -v psql &> /dev/null; then
    if psql "$SUPABASE_URL" -c "SELECT version();" &> /dev/null; then
        echo -e "${GREEN}✅ Connection test successful!${NC}"
    else
        echo -e "${RED}❌ Connection test failed. Please check your connection string.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  psql not found, skipping connection test${NC}"
    echo "   Install with: brew install postgresql (macOS)"
fi
echo ""

# Step 4: Create new ComponentRelease
echo -e "${YELLOW}⚙️  Step 4: Creating new ComponentRelease with Supabase URL...${NC}"

# Get the latest ComponentRelease
LATEST_RELEASE=$(kubectl get componentreleases -n default \
    -l openchoreo.dev/component=inventorybackend \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{.items[-1].metadata.name}')

if [ -z "$LATEST_RELEASE" ]; then
    echo -e "${RED}❌ Error: Could not find existing ComponentRelease for inventorybackend${NC}"
    exit 1
fi

echo "Current release: $LATEST_RELEASE"

# Create new release name
NEW_RELEASE="inventorybackend-$(date +%Y%m%d-%H%M%S)-supabase"
echo "New release: $NEW_RELEASE"

# Export current release to temp file
TMP_FILE="/tmp/componentrelease-$$.yaml"
kubectl get componentrelease "$LATEST_RELEASE" -n default -o yaml > "$TMP_FILE"

# Create new release with updated DATABASE_URL
cat "$TMP_FILE" | \
  sed "s/name: $LATEST_RELEASE/name: $NEW_RELEASE/" | \
  sed "s|value: postgresql://.*|value: $SUPABASE_URL|" | \
  grep -vE '^(  creationTimestamp:|  generation:|  resourceVersion:|  uid:)' | \
  kubectl apply -f -

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ New ComponentRelease created: $NEW_RELEASE${NC}"
else
    echo -e "${RED}❌ Failed to create ComponentRelease${NC}"
    rm -f "$TMP_FILE"
    exit 1
fi

# Clean up temp file
rm -f "$TMP_FILE"
echo ""

# Step 5: Update ReleaseBinding
echo -e "${YELLOW}🔄 Step 5: Updating ReleaseBinding...${NC}"

kubectl patch releasebinding inventorybackend-development -n default \
  --type=merge -p "{\"spec\":{\"releaseName\":\"$NEW_RELEASE\"}}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ReleaseBinding updated${NC}"
else
    echo -e "${RED}❌ Failed to update ReleaseBinding${NC}"
    exit 1
fi
echo ""

# Step 6: Wait for deployment rollout
echo -e "${YELLOW}⏳ Step 6: Waiting for backend deployment to update...${NC}"
echo "This may take 1-2 minutes..."

kubectl rollout status deploy \
  -l openchoreo.dev/component=inventorybackend \
  -n "$DATAPLANE_NS" \
  --timeout=180s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backend deployment updated successfully${NC}"
else
    echo -e "${RED}❌ Deployment rollout timed out or failed${NC}"
    exit 1
fi
echo ""

# Step 7: Verify connection
echo -e "${YELLOW}🔍 Step 7: Verifying database connection...${NC}"

# Get backend pod
BACKEND_POD=$(kubectl get pods -n "$DATAPLANE_NS" \
    -l openchoreo.dev/component=inventorybackend \
    -o jsonpath='{.items[0].metadata.name}')

if [ -z "$BACKEND_POD" ]; then
    echo -e "${RED}❌ Error: Could not find backend pod${NC}"
    exit 1
fi

echo "Checking logs for connection success..."
sleep 5  # Wait for pod to initialize

LOGS=$(kubectl logs -n "$DATAPLANE_NS" "$BACKEND_POD" --tail=50 2>/dev/null || echo "")

if echo "$LOGS" | grep -q "Database connected successfully"; then
    echo -e "${GREEN}✅ Database connection confirmed in logs!${NC}"
else
    echo -e "${YELLOW}⚠️  Could not confirm connection in logs. Check manually:${NC}"
    echo "   kubectl logs -n $DATAPLANE_NS $BACKEND_POD"
fi
echo ""

# Step 8: Test API endpoint
echo -e "${YELLOW}🧪 Step 8: Testing API endpoint...${NC}"

API_URL="http://development.openchoreoapis.localhost:19080/inventorybackend/api/products"
echo "Testing: $API_URL"

RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL" 2>/dev/null || echo "000")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    PRODUCT_COUNT=$(echo "$BODY" | jq '. | length' 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ API endpoint working! Found $PRODUCT_COUNT products${NC}"
    
    if [ "$PRODUCT_COUNT" != "unknown" ] && [ "$PRODUCT_COUNT" -gt 0 ]; then
        echo ""
        echo "Sample product:"
        echo "$BODY" | jq '.[0]' 2>/dev/null || echo "$BODY" | head -n 5
    fi
else
    echo -e "${YELLOW}⚠️  API returned HTTP $HTTP_CODE${NC}"
    echo "Response: $BODY"
fi
echo ""

# Success summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✨ Setup Complete! ✨                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "   • ComponentRelease: $NEW_RELEASE"
echo "   • Dataplane: $DATAPLANE_NS"
echo "   • Backend Pod: $BACKEND_POD"
echo "   • Database: Supabase (external)"
echo ""
echo -e "${BLUE}🔗 Access URLs:${NC}"
echo "   • API: http://development.openchoreoapis.localhost:19080/inventorybackend/api/products"
echo "   • Health: http://development.openchoreoapis.localhost:19080/inventorybackend/health"
echo "   • Supabase: https://supabase.com/dashboard/project/[your-project]"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "   1. Verify data in Supabase Table Editor"
echo "   2. Test CRUD operations via frontend"
echo "   3. Review security settings in Supabase"
echo "   4. Set up database backups and monitoring"
echo ""
echo -e "${YELLOW}💡 Tip: Your old OpenChoreo database is still running.${NC}"
echo "   To remove it (optional):"
echo "   kubectl delete component inventorydatabase -n default"
echo ""
