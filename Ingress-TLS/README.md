# 1. Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml

# 2. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 3. Wait for cert-manager to be ready
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deployment/cert-manager

# 4. Apply the configuration
kubectl apply -f <your-file.yaml>

# 5. Add to /etc/hosts
echo "127.0.0.1 hello.local.dev world.local.dev" | sudo tee -a /etc/hosts

# 6. Test the setup
curl -k https://hello.local.dev
curl -k https://world.local.dev