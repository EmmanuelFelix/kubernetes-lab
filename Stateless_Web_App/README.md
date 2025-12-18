Deploy a Stateless Web App Scenario: Company wants to containerize a legacy web service.
Create Deployment, Service
Add labels and selectors
Avoid default namespace
Expose via ClusterIP
Verify rollout and rollback Practices
kubectl rollout status
kubectl describe pod
kubectl logs

Prerequisites

kind create cluster --config kind-config.yaml
kubectl cluster-info


Deployment Steps


1. Apply the Configuration
# Apply all resources
kubectl apply -f deployment.yaml

# Verify namespace creation
kubectl get namespaces



2. Verify Rollout Status
# Check deployment rollout status
kubectl rollout status deployment/legacy-web-deployment -n legacy-web

# Watch the rollout in real-time
kubectl rollout status deployment/legacy-web-deployment -n legacy-web --watch


3. Inspect Resources
# Get deployment details
kubectl get deployments -n legacy-web

# Get pods with labels
kubectl get pods -n legacy-web --show-labels

# Describe a specific pod
kubectl describe pod <pod-name> -n legacy-web

# Check service
kubectl get svc -n legacy-web
kubectl describe svc legacy-web-service -n legacy-web


4. View Logs
# View logs from a specific pod
kubectl logs <pod-name> -n legacy-web

# Follow logs in real-time
kubectl logs -f <pod-name> -n legacy-web

# View logs from all pods with the label
kubectl logs -l app=legacy-web -n legacy-web

# View previous container logs (if restarted)
kubectl logs <pod-name> -n legacy-web --previous



Rollback Procedures
Update the Deployment
# Update image (simulate a new version)
kubectl set image deployment/legacy-web-deployment web-container=nginx:1.25 -n legacy-web

# Check rollout status
kubectl rollout status deployment/legacy-web-deployment -n legacy-web


Rollback Options
# View rollout history
kubectl rollout history deployment/legacy-web-deployment -n legacy-web

# Rollback to previous version
kubectl rollout undo deployment/legacy-web-deployment -n legacy-web

# Rollback to specific revision
kubectl rollout undo deployment/legacy-web-deployment --to-revision=1 -n legacy-web

# Verify rollback
kubectl rollout status deployment/legacy-web-deployment -n legacy-web


Pause/Resume Rollout
# Pause rollout (useful for canary deployments)
kubectl rollout pause deployment/legacy-web-deployment -n legacy-web

# Resume rollout
kubectl rollout resume deployment/legacy-web-deployment -n legacy-web



Testing the Service
# Test service from within cluster
kubectl run test-pod --image=busybox -n legacy-web --rm -it -- wget -O- http://legacy-web-service

# Port forward to test locally
kubectl port-forward svc/legacy-web-service 8080:80 -n legacy-web
# Then access: http://localhost:8080