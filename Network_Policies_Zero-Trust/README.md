kubectl apply -f network-policies.yaml

# Verify policies are applied
kubectl get networkpolicies --all-namespaces

# Test frontend can reach backend (should work)
kubectl exec -n frontend deployment/frontend-app -- wget -O- backend-service.backend.svc.cluster.local:8080

# Test frontend CANNOT reach database directly (should fail)
kubectl exec -n frontend deployment/frontend-app -- nc -zv postgres-service.database.svc.cluster.local 5432

# Test backend CAN reach database (should work)
kubectl exec -n backend deployment/backend-api -- nc -zv postgres-service.database.svc.cluster.local 5432