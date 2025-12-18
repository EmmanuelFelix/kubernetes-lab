# Apply all resources at once
kubectl apply -f pod-security-hardening.yaml

# Or apply step by step:
# kubectl apply -f pod-security-hardening.yaml --namespace=secure-app

# Check namespace labels
kubectl get namespace secure-app -o yaml

# Verify the Pod Security labels are applied
kubectl get ns secure-app --show-labels

# Watch pods being created
kubectl get pods -n secure-app -w

# Check deployment status
kubectl get deployment -n secure-app
kubectl describe deployment secure-nginx -n secure-app

# Inspect pod security context
kubectl get pod -n secure-app -o jsonpath='{.items[0].spec.securityContext}' | jq

# Check container security settings
kubectl get pod -n secure-app -o jsonpath='{.items[0].spec.containers[0].securityContext}' | jq

# Verify the pod is running as non-root
kubectl exec -n secure-app deployment/secure-nginx -- id

# Port forward to test locally
kubectl port-forward -n secure-app service/secure-nginx 8080:80

# In another terminal, test:
curl http://localhost:8080


kubectl exec -n secure-app deployment/secure-nginx -- ls -la /tmp/