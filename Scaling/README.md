# Apply all resources
kubectl apply -f scaling-example.yaml

# Manual scaling for business hours
kubectl scale deployment web-app --replicas=5

# Watch HPA automatically adjust pods
kubectl get hpa --watch