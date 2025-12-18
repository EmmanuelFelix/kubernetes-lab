# 1. Apply resources
kubectl apply -f autoscaling-examples.yaml

# 2. Scale up to trigger capacity issues
kubectl scale deployment memory-intensive-app -n autoscaling-demo --replicas=15

# 3. Watch what happens
kubectl get events -n autoscaling-demo --sort-by='.lastTimestamp' | grep -i evict