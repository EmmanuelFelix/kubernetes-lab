kubectl apply -f <filename>.yaml
kubectl get pods
kubectl exec -it app-pod -- env | grep APP

# Create ConfigMap from literals
kubectl create configmap app-config --from-literal=DATABASE_HOST=postgres

# Create ConfigMap from file
kubectl create configmap nginx-config --from-file=nginx.conf

# Create Secret from literals
kubectl create secret generic db-credentials --from-literal=username=admin

# Create Docker registry secret
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=user --docker-password=pass

# Base64 encode (for manual creation)
echo -n 'mypassword' | base64