Step-by-Step Guide: Running Kubernetes Resource Management Examples
Prerequisites
1. Set Up a Kubernetes Cluster
Choose one option:
bash# Option A: Minikube (local)
minikube start --memory=4096 --cpus=2

# Option B: Kind (local)
kind create cluster --name resource-test

# Option C: Use existing cluster
kubectl cluster-info
2. Install Metrics Server (Required for monitoring)
bashkubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For Minikube, enable metrics
minikube addons enable metrics-server

# Wait for metrics-server to be ready
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=60s
3. Save the YAML File
bash# Copy the artifact content to a file
nano k8s-resources.yaml
# Or download if you have it

Scenario 1: Resource Starvation Demo
Step 1: Deploy Apps Without Limits
bash# Deploy the resource hog
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-hog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-hog
  template:
    metadata:
      labels:
        app: resource-hog
    spec:
      containers:
      - name: hog
        image: nginx:latest
EOF

# Deploy the app that will be starved
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: starved-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: starved-app
  template:
    metadata:
      labels:
        app: starved-app
    spec:
      containers:
      - name: app
        image: nginx:latest
EOF
Step 2: Observe the Problem
bash# Check pod status
kubectl get pods -o wide

# Check resource usage (wait 30 seconds for metrics)
sleep 30
kubectl top pods

# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# See that there are no guarantees or limits
kubectl describe pod -l app=resource-hog | grep -A 10 "Limits"
Step 3: Clean Up
bashkubectl delete deployment resource-hog starved-app

Scenario 2: Proper Requests vs Limits
Step 1: Deploy Well-Configured App
bashkubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: well-configured-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: well-configured
  template:
    metadata:
      labels:
        app: well-configured
    spec:
      containers:
      - name: app
        image: nginx:latest
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
EOF
Step 2: Verify Configuration
bash# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=well-configured --timeout=60s

# Check resource configuration
kubectl describe pod -l app=well-configured | grep -A 10 "Limits"

# Output should show:
#   Limits:
#     cpu:     500m
#     memory:  256Mi
#   Requests:
#     cpu:        100m
#     memory:     128Mi
Step 3: Monitor Resource Usage
bash# Real-time monitoring
kubectl top pods -l app=well-configured

# Detailed view
kubectl get pods -l app=well-configured -o json | jq '.items[].spec.containers[].resources'
Step 4: Clean Up
bashkubectl delete deployment well-configured-app

Scenario 3: OOMKilled Troubleshooting
Step 1: Deploy OOM-Prone App
bash# Note: This requires stress tool, so we'll use a simpler example
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oom-prone-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oom-prone
  template:
    metadata:
      labels:
        app: oom-prone
    spec:
      containers:
      - name: memory-hungry
        image: polinux/stress
        resources:
          requests:
            memory: "64Mi"
          limits:
            memory: "128Mi"
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "200M", "--vm-hang", "1"]
EOF
Step 2: Watch It Get OOMKilled
bash# Watch pod status in real-time
kubectl get pods -l app=oom-prone -w

# You'll see: OOMKilled or CrashLoopBackOff
# Press Ctrl+C to stop watching
Step 3: Investigate the OOM
bash# Get pod name
POD_NAME=$(kubectl get pods -l app=oom-prone -o jsonpath='{.items[0].metadata.name}')

# Check termination reason
kubectl describe pod $POD_NAME | grep -A 10 "Last State"

# Expected output:
#   Last State:     Terminated
#     Reason:       OOMKilled
#     Exit Code:    137

# Check events
kubectl get events --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp'

# View logs from previous container
kubectl logs $POD_NAME --previous
Step 4: Deploy Fixed Version
bashkubectl delete deployment oom-prone-app

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oom-fixed-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oom-fixed
  template:
    metadata:
      labels:
        app: oom-fixed
    spec:
      containers:
      - name: memory-safe
        image: nginx:latest
        resources:
          requests:
            memory: "256Mi"
          limits:
            memory: "512Mi"
EOF

# Verify it's running
kubectl get pods -l app=oom-fixed
Step 5: Clean Up
bashkubectl delete deployment oom-fixed-app

Scenario 4: CPU Throttling Analysis
Step 1: Deploy CPU-Intensive App
bashkubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-throttled-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-throttled
  template:
    metadata:
      labels:
        app: cpu-throttled
    spec:
      containers:
      - name: cpu-intensive
        image: progrium/stress
        resources:
          requests:
            cpu: "100m"
          limits:
            cpu: "200m"
        args: ["--cpu", "2", "--timeout", "300s"]
EOF
Step 2: Monitor CPU Usage
bash# Wait for pod to start
kubectl wait --for=condition=ready pod -l app=cpu-throttled --timeout=60s

# Get pod name
POD_NAME=$(kubectl get pods -l app=cpu-throttled -o jsonpath='{.items[0].metadata.name}')

# Watch CPU usage (you'll see it hit the 200m limit)
watch -n 2 "kubectl top pod $POD_NAME"

# Press Ctrl+C when done watching
Step 3: Check for Throttling
bash# Check cgroup throttling stats
kubectl exec $POD_NAME -- sh -c 'cat /sys/fs/cgroup/cpu.stat 2>/dev/null || cat /sys/fs/cgroup/cpu/cpu.stat 2>/dev/null'

# Look for:
#   nr_throttled: >0        (number of times throttled)
#   throttled_time: >0      (nanoseconds throttled)

# Alternative: Check if CPU is consistently at limit
kubectl top pod $POD_NAME
# If it shows exactly 200m, it's being throttled
Step 4: Create Throttling Check Script
bash# Create a quick script
cat > check-throttling.sh <<'SCRIPT'
#!/bin/bash
POD_NAME=$1

echo "=== CPU Usage ==="
kubectl top pod $POD_NAME

echo -e "\n=== Throttling Stats ==="
kubectl exec $POD_NAME -- sh -c '
  if [ -f /sys/fs/cgroup/cpu.stat ]; then
    cat /sys/fs/cgroup/cpu.stat | grep throttled
  elif [ -f /sys/fs/cgroup/cpu/cpu.stat ]; then
    cat /sys/fs/cgroup/cpu/cpu.stat | grep throttled
  fi
' 2>/dev/null || echo "Unable to read cgroup stats"

echo -e "\n=== Resource Limits ==="
kubectl get pod $POD_NAME -o jsonpath='{.spec.containers[*].resources}' | jq .
SCRIPT

chmod +x check-throttling.sh

# Run the script
./check-throttling.sh $POD_NAME
Step 5: Deploy Fixed Version
bashkubectl delete deployment cpu-throttled-app

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-optimized-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-optimized
  template:
    metadata:
      labels:
        app: cpu-optimized
    spec:
      containers:
      - name: cpu-adequate
        image: nginx:latest
        resources:
          requests:
            cpu: "500m"
          limits:
            cpu: "1000m"
EOF

kubectl get pods -l app=cpu-optimized
Step 6: Clean Up
bashkubectl delete deployment cpu-optimized-app
rm check-throttling.sh

Bonus: Apply Namespace Protection
Step 1: Create Test Namespace
bashkubectl create namespace resource-test
kubectl config set-context --current --namespace=resource-test
Step 2: Apply Resource Quota
bashkubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: resource-test
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "4Gi"
    limits.cpu: "4"
    limits.memory: "8Gi"
    pods: "5"
EOF

# Verify quota
kubectl describe resourcequota namespace-quota -n resource-test
Step 3: Apply Limit Range
bashkubectl apply -f - <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: resource-test
spec:
  limits:
  - max:
      cpu: "1"
      memory: "1Gi"
    min:
      cpu: "50m"
      memory: "32Mi"
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
EOF

# Verify limit range
kubectl describe limitrange resource-limits -n resource-test
Step 4: Test the Limits
bash# Try to create a pod that violates the quota
kubectl run test-pod --image=nginx -n resource-test

# Check that it got default limits applied
kubectl describe pod test-pod -n resource-test | grep -A 10 "Limits"
Step 5: Clean Up
bashkubectl delete namespace resource-test
kubectl config set-context --current --namespace=default

Complete Cleanup
bash# Delete all test resources
kubectl delete deployment --all
kubectl delete resourcequota --all
kubectl delete limitrange --all

# Stop minikube (if using)
minikube stop

# Delete kind cluster (if using)
kind delete cluster --name resource-test

Quick Reference Commands
bash# Monitor all pods
kubectl top pods --all-namespaces

# Check node resources
kubectl top nodes

# Find OOMKilled pods
kubectl get pods -A | grep -E "OOMKilled|Error"

# Watch events
kubectl get events --sort-by='.lastTimestamp' --watch

# Describe all pods
kubectl describe pods | grep -E "Name:|Limits:|Requests:|State:"

# Get resource usage JSON
kubectl get pods -o json | jq '.items[] | {name: .metadata.name, resources: .spec