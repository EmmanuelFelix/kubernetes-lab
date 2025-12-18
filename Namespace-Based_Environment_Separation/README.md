# Create namespaces
kubectl apply -f namespaces.yaml

# Apply quotas
kubectl apply -f quota-dev.yaml
kubectl apply -f quota-staging.yaml
kubectl apply -f quota-prod.yaml

# Apply limit ranges
kubectl apply -f limitrange-dev.yaml
kubectl apply -f limitrange-staging.yaml
kubectl apply -f limitrange-prod.yaml

# Apply network policies
kubectl apply -f networkpolicy-dev.yaml

# Apply RBAC
kubectl apply -f rbac-dev.yaml
kubectl apply -f rbac-prod.yaml


# Check quotas
kubectl describe quota -n app-dev
kubectl describe quota -n app-staging
kubectl describe quota -n app-prod

# Check limit ranges
kubectl describe limitrange -n app-dev

# Test resource constraints
kubectl run test-pod --image=nginx -n app-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl describe pod test-pod -n app-dev

# View resource usage
kubectl top pods -n app-prod
kubectl get resourcequota -n app-prod