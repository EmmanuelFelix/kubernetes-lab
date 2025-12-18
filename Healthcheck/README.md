# Deploy everything
kubectl apply -f health-checks.yaml

# Watch pod status
kubectl get pods -n health-demo -w

# Check endpoints (only ready pods listed)
kubectl get endpoints -n health-demo

# Get into test client
kubectl exec -it test-client -n health-demo -- sh

# Test the service
curl http://health-demo-service

# Simulate readiness failure on a pod
curl http://health-demo-service/fail-ready

# Watch as pod is removed from endpoints
kubectl get endpoints -n health-demo -w

# Simulate liveness failure (triggers restart)
curl http://health-demo-service/fail-liveness

# Watch pod restart
kubectl get pods -n health-demo -w

# Recover health
curl http://health-demo-service/recover