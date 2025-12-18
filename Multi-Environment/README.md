# Multi-Environment Promotion Pipeline: Complete Breakdown

## Prerequisites Setup

### Step 1: Create Kubernetes Namespaces
```bash
# Create isolated namespaces for each environment
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production
```

### Step 2: Set Up Your Directory Structure

**For Kustomize:**
```bash
mkdir -p k8s/{base,overlays/{dev,staging,prod}}
```

**For Helm:**
```bash
mkdir -p myapp-chart/templates
```

---

## KUSTOMIZE APPROACH: Detailed Steps

### Phase 1: Create Base Manifests

#### Step 3: Create Base Deployment
```bash
cat > k8s/base/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        ports:
        - containerPort: 8080
EOF
```

#### Step 4: Create Base Service
```bash
cat > k8s/base/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
EOF
```

#### Step 5: Create Base Kustomization
```bash
cat > k8s/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF
```

### Phase 2: Create Environment Overlays

#### Step 6: Create DEV Overlay
```bash
cat > k8s/overlays/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev
bases:
- ../../base

namePrefix: dev-

commonLabels:
  env: dev
  tier: development

replicas:
- name: myapp
  count: 1

images:
- name: myapp
  newTag: dev-latest
EOF
```

#### Step 7: Create STAGING Overlay
```bash
cat > k8s/overlays/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: staging
bases:
- ../../base

namePrefix: staging-

commonLabels:
  env: staging
  tier: pre-production

replicas:
- name: myapp
  count: 2

images:
- name: myapp
  newTag: v1.0.0
EOF
```

#### Step 8: Create PROD Overlay
```bash
cat > k8s/overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production
bases:
- ../../base

namePrefix: prod-

commonLabels:
  env: prod
  tier: production

replicas:
- name: myapp
  count: 3

images:
- name: myapp
  newTag: v1.0.0
EOF
```

### Phase 3: Initial Deployment

#### Step 9: Preview What Will Be Deployed (Dry Run)
```bash
# Check dev configuration
kubectl kustomize k8s/overlays/dev

# Check staging configuration
kubectl kustomize k8s/overlays/staging

# Check prod configuration
kubectl kustomize k8s/overlays/prod
```

#### Step 10: Deploy to DEV
```bash
kubectl apply -k k8s/overlays/dev

# Verify deployment
kubectl get pods -n dev -l env=dev
kubectl get svc -n dev
```

#### Step 11: Deploy to STAGING
```bash
kubectl apply -k k8s/overlays/staging

# Verify deployment
kubectl get pods -n staging -l env=staging
kubectl get svc -n staging
```

#### Step 12: Deploy to PROD
```bash
kubectl apply -k k8s/overlays/prod

# Verify deployment
kubectl get pods -n production -l env=prod
kubectl get svc -n production
```

### Phase 4: Promotion Workflow

#### Step 13: Develop and Test in DEV
```bash
# Build new image
docker build -t myapp:dev-latest .
docker push myapp:dev-latest

# Deploy to dev (automatically uses dev-latest tag)
kubectl apply -k k8s/overlays/dev

# Test the application
kubectl port-forward -n dev svc/dev-myapp 8080:80
# Test at http://localhost:8080
```

#### Step 14: Promote to STAGING
```bash
# Tag the tested dev image with version
docker tag myapp:dev-latest myapp:v1.1.0
docker push myapp:v1.1.0

# Update staging overlay
sed -i 's/newTag: .*/newTag: v1.1.0/' k8s/overlays/staging/kustomization.yaml

# Or manually edit k8s/overlays/staging/kustomization.yaml
# Change: newTag: v1.0.0
# To: newTag: v1.1.0

# Deploy to staging
kubectl apply -k k8s/overlays/staging

# Verify
kubectl get pods -n staging -l env=staging
kubectl describe pod -n staging -l env=staging | grep Image:
```

#### Step 15: Validate in STAGING
```bash
# Run integration tests
kubectl port-forward -n staging svc/staging-myapp 8080:80

# Check logs
kubectl logs -n staging -l env=staging --tail=100

# Run smoke tests, load tests, etc.
```

#### Step 16: Promote to PROD
```bash
# Update prod overlay with the SAME version from staging
sed -i 's/newTag: .*/newTag: v1.1.0/' k8s/overlays/prod/kustomization.yaml

# Or manually edit k8s/overlays/prod/kustomization.yaml
# Change: newTag: v1.0.0
# To: newTag: v1.1.0

# Deploy to production
kubectl apply -k k8s/overlays/prod

# Verify deployment
kubectl get pods -n production -l env=prod
kubectl rollout status deployment/prod-myapp -n production
```

#### Step 17: Monitor Production Deployment
```bash
# Watch rollout
kubectl rollout status deployment/prod-myapp -n production

# Check all pods are running
kubectl get pods -n production -l env=prod

# Verify correct image version
kubectl describe deployment prod-myapp -n production | grep Image:

# Check logs for errors
kubectl logs -n production -l env=prod --tail=50
```

---

## HELM APPROACH: Detailed Steps

### Phase 1: Create Helm Chart Structure

#### Step 18: Initialize Helm Chart
```bash
helm create myapp-chart
cd myapp-chart
```

#### Step 19: Create Base Values File
```bash
cat > values.yaml << 'EOF'
replicaCount: 2

image:
  repository: myapp
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

environment: base
logLevel: info
EOF
```

#### Step 20: Create Environment-Specific Values

**DEV Values:**
```bash
cat > values-dev.yaml << 'EOF'
replicaCount: 1

image:
  tag: dev-latest

environment: development
logLevel: debug

labels:
  env: dev
  tier: development
EOF
```

**STAGING Values:**
```bash
cat > values-staging.yaml << 'EOF'
replicaCount: 2

image:
  tag: v1.0.0

environment: staging
logLevel: info

labels:
  env: staging
  tier: pre-production
EOF
```

**PROD Values:**
```bash
cat > values-prod.yaml << 'EOF'
replicaCount: 3

image:
  tag: v1.0.0

environment: production
logLevel: warn

labels:
  env: prod
  tier: production

resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"
EOF
```

### Phase 2: Initial Helm Deployment

#### Step 21: Deploy to DEV with Helm
```bash
helm install myapp-dev ./myapp-chart \
  -f values-dev.yaml \
  -n dev \
  --create-namespace

# Verify
helm list -n dev
kubectl get pods -n dev
```

#### Step 22: Deploy to STAGING with Helm
```bash
helm install myapp-staging ./myapp-chart \
  -f values-staging.yaml \
  -n staging \
  --create-namespace

# Verify
helm list -n staging
kubectl get pods -n staging
```

#### Step 23: Deploy to PROD with Helm
```bash
helm install myapp-prod ./myapp-chart \
  -f values-prod.yaml \
  -n production \
  --create-namespace

# Verify
helm list -n production
kubectl get pods -n production
```

### Phase 3: Helm Promotion Workflow

#### Step 24: Test in DEV
```bash
# Deploy latest code to dev
docker build -t myapp:dev-latest .
docker push myapp:dev-latest

# Upgrade dev deployment
helm upgrade myapp-dev ./myapp-chart \
  -f values-dev.yaml \
  -n dev
```

#### Step 25: Promote to STAGING with Helm
```bash
# Tag tested version
docker tag myapp:dev-latest myapp:v1.1.0
docker push myapp:v1.1.0

# Update values-staging.yaml
sed -i 's/tag: .*/tag: v1.1.0/' values-staging.yaml

# Upgrade staging
helm upgrade myapp-staging ./myapp-chart \
  -f values-staging.yaml \
  -n staging

# Or use --set flag
helm upgrade myapp-staging ./myapp-chart \
  -f values-staging.yaml \
  --set image.tag=v1.1.0 \
  -n staging
```

#### Step 26: Promote to PROD with Helm
```bash
# Update values-prod.yaml with same version
sed -i 's/tag: .*/tag: v1.1.0/' values-prod.yaml

# Upgrade production
helm upgrade myapp-prod ./myapp-chart \
  -f values-prod.yaml \
  -n production

# Verify
helm status myapp-prod -n production
kubectl get pods -n production -l env=prod
```

---

## Verification and Troubleshooting

### Step 27: Verify Deployments Across All Environments
```bash
# Check all environments at once
echo "=== DEV ==="
kubectl get pods -n dev -l app=myapp

echo "=== STAGING ==="
kubectl get pods -n staging -l app=myapp

echo "=== PROD ==="
kubectl get pods -n production -l app=myapp
```

### Step 28: Verify Image Tags Match Expected Versions
```bash
# Dev should have dev-latest
kubectl get deployment -n dev -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'

# Staging and Prod should have same version (e.g., v1.1.0)
kubectl get deployment -n staging -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
kubectl get deployment -n production -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

### Step 29: Check Environment Labels
```bash
kubectl get pods -n dev --show-labels
kubectl get pods -n staging --show-labels
kubectl get pods -n production --show-labels
```

### Step 30: Rollback if Needed
```bash
# Kustomize rollback (revert to previous version in git)
git checkout HEAD~1 k8s/overlays/prod/kustomization.yaml
kubectl apply -k k8s/overlays/prod

# Helm rollback
helm rollback myapp-prod -n production
helm rollback myapp-prod 1 -n production  # Roll back to specific revision
```

---

## Best Practices Checklist

✅ **Always test in dev first**
✅ **Use same image tag for staging → prod promotion**
✅ **Tag images with semantic versions (v1.2.3)**
✅ **Never use `latest` tag in staging/prod**
✅ **Document what version is in each environment**
✅ **Use CI/CD to automate promotions**
✅ **Keep environment-specific configs minimal**
✅ **Use namespaces to isolate environments**
✅ **Monitor deployments with rollout status**
✅ **Have a rollback plan**

---

## Quick Reference Commands

```bash
# Kustomize
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/overlays/staging  
kubectl apply -k k8s/overlays/prod

# Helm
helm upgrade myapp-dev ./myapp-chart -f values-dev.yaml -n dev
helm upgrade myapp-staging ./myapp-chart -f values-staging.yaml -n staging
helm upgrade myapp-prod ./myapp-chart -f values-prod.yaml -n production

# Verify
kubectl get pods -n <namespace> -l env=<env>
kubectl describe deployment <name> -n <namespace>
kubectl logs -n <namespace> -l app=myapp
```