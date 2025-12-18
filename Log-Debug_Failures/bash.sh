#!/bin/bash
# Kubernetes Debugging Guide - Commands to troubleshoot the example deployments

echo "=== SETUP ==="
# Apply the manifests
kubectl apply -f k8s-debug-example.yaml

echo ""
echo "=== 1. CHECK POD STATUS ==="
# See which pods are having issues
kubectl get pods
kubectl get pods -w  # Watch mode

echo ""
echo "=== 2. DEBUGGING CRASHLOOPBACKOFF ==="
# The buggy-app will be in CrashLoopBackOff

# Get detailed pod information
kubectl describe pod -l app=buggy-app

# View current logs
kubectl logs -l app=buggy-app

# View logs from the previous crashed container (IMPORTANT!)
kubectl logs -l app=buggy-app --previous

# View logs from init container
kubectl logs -l app=buggy-app -c check-dependencies

# Follow logs in real-time
kubectl logs -l app=buggy-app -f

echo ""
echo "=== 3. KUBECTL EXEC FOR INTERACTIVE DEBUGGING ==="
# Exec into the working-app to debug
kubectl exec -it deployment/working-app -- sh

# Once inside the pod, you can:
# - Check environment variables: env
# - Check file system: ls -la
# - Test network connectivity: wget, curl, nc
# - View processes: ps aux
# - Check DNS: nslookup db-service

# Example exec commands without interactive shell:
kubectl exec deployment/working-app -- env
kubectl exec deployment/working-app -- ls -la /
kubectl exec deployment/working-app -- ps aux

echo ""
echo "=== 4. VIEW LOGS FROM PREVIOUS CONTAINER ==="
# The flaky-app restarts frequently
# View what caused the last crash
kubectl logs -l app=flaky-app --previous

# Compare with current logs
kubectl logs -l app=flaky-app

# View last 20 lines
kubectl logs -l app=flaky-app --tail=20

# View logs since specific time
kubectl logs -l app=flaky-app --since=5m

echo ""
echo "=== 5. COMMON DEBUGGING SCENARIOS ==="

# Scenario A: Check why pod won't start
kubectl describe pod -l app=buggy-app
kubectl get events --sort-by='.lastTimestamp' | grep buggy-app

# Scenario B: Check resource usage
kubectl top pod -l app=buggy-app

# Scenario C: Check if the issue is configuration
kubectl get configmap app-config -o yaml
kubectl get secret db-secret -o yaml 2>/dev/null || echo "Secret not found!"

# Scenario D: Network debugging from within pod
kubectl exec deployment/working-app -- nc -zv db-service 5432
kubectl exec deployment/working-app -- nslookup kubernetes.default

echo ""
echo "=== 6. FIX THE CRASHLOOPBACKOFF ==="
# The buggy-app is missing a secret. Let's create it:

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  password: "my-secret-password"
EOF

# Now patch the deployment to use the secret
kubectl patch deployment buggy-app --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "DB_PASSWORD",
      "valueFrom": {
        "secretKeyRef": {
          "name": "db-secret",
          "key": "password"
        }
      }
    }
  }
]'

# Watch the pod recover
kubectl get pods -l app=buggy-app -w

echo ""
echo "=== 7. DEBUGGING TIPS ==="
cat <<'EOF'

Common Issues and Solutions:

1. CrashLoopBackOff
   - Check logs: kubectl logs <pod> --previous
   - Check describe: kubectl describe pod <pod>
   - Look for: Missing env vars, incorrect commands, failed health checks

2. ImagePullBackOff
   - Check image name and tag
   - Verify image registry credentials
   - kubectl describe pod will show the error

3. Pending Pods
   - Check node resources: kubectl describe nodes
   - Check PVC status: kubectl get pvc
   - Look for scheduling constraints

4. Init Container Failures
   - Check init container logs: kubectl logs <pod> -c <init-container-name>
   - Init containers must complete before app containers start

5. Application Not Responding
   - Exec into pod: kubectl exec -it <pod> -- sh
   - Check processes: ps aux
   - Check network: netstat -tulpn
   - Test connectivity: curl, wget, nc

Key Commands Summary:
- kubectl get pods -w                    # Watch pod status
- kubectl describe pod <pod>             # Detailed pod info
- kubectl logs <pod> --previous          # Previous container logs
- kubectl logs <pod> -c <container>      # Specific container logs
- kubectl exec -it <pod> -- sh           # Interactive shell
- kubectl get events --sort-by='.lastTimestamp'  # Recent events
- kubectl top pod <pod>                  # Resource usage
EOF

echo ""
echo "=== CLEANUP ==="
# kubectl delete -f k8s-debug-example.yaml
# kubectl delete secret db-secret