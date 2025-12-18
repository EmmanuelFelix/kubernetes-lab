# Apply all resources
kubectl apply -f rolling-update.yaml

# Verify deployment
kubectl get all -n demo-app

# Watch the rollout status
kubectl rollout status deployment/web-app -n demo-app

# Update to nginx 1.22 (simulating new version)
kubectl set image deployment/web-app nginx=nginx:1.22 -n demo-app

# Watch the rolling update in real-time
kubectl rollout status deployment/web-app -n demo-app -w

# Or watch pods being replaced
kubectl get pods -n demo-app -w

# Deploy a broken version
kubectl set image deployment/web-app nginx=nginx:invalid-tag -n demo-app

# Check rollout status (will fail)
kubectl rollout status deployment/web-app -n demo-app

# Rollback to previous version
kubectl rollout undo deployment/web-app -n demo-app

# Verify rollback
kubectl rollout status deployment/web-app -n demo-app

# View rollout history
kubectl rollout history deployment/web-app -n demo-app

# Rollback to specific revision
kubectl rollout undo deployment/web-app --to-revision=2 -n demo-app

# Pause/Resume rollout
kubectl rollout pause deployment/web-app -n demo-app
kubectl rollout resume deployment/web-app -n demo-app

# Clean up
kubectl delete namespace demo-app