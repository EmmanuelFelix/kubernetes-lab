# ============================================
# KUBERNETES BACKUP & DISASTER RECOVERY
# COMPLETE EXECUTION GUIDE
# ============================================

# PREREQUISITES:
# - kubectl installed and configured
# - Access to a Kubernetes cluster
# - Sufficient permissions to create namespaces and resources

# ============================================
# STEP 1: CREATE A SAMPLE APPLICATION
# ============================================
# This creates a namespace with a stateful app (MySQL) and a stateless app (nginx)

# Execute this step:
# 1. Save the manifest below to a file: app-manifests.yaml
# 2. Run: kubectl apply -f app-manifests.yaml
# 3. Wait for pods to be ready: kubectl wait --for=condition=Ready pods --all -n production-app --timeout=300s
# 4. Verify: kubectl get all,pvc -n production-app

---
apiVersion: v1
kind: Namespace
metadata:
  name: production-app

---
# Persistent Volume Claim for MySQL data
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: production-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi

---
# MySQL Deployment with persistent storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: production-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpassword123"
        - name: MYSQL_DATABASE
          value: "myappdb"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc

---
# MySQL Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: production-app
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306

---
# Nginx Deployment (stateless)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: production-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80

---
# Nginx Service
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: production-app
  labels:
    app: nginx
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80


# ============================================
# STEP 2: BACKUP MANIFESTS
# ============================================
# Execute these commands to backup all Kubernetes manifests

# 2.1: Create a backup directory
mkdir -p k8s-backups
cd k8s-backups

# 2.2: Backup entire namespace (all resources)
kubectl get all,pvc,configmap,secret -n production-app -o yaml > backup-production-app-all.yaml

# 2.3: Backup specific resource types separately (alternative approach)
kubectl get deployments -n production-app -o yaml > backup-deployments.yaml
kubectl get services -n production-app -o yaml > backup-services.yaml
kubectl get pvc -n production-app -o yaml > backup-pvc.yaml
kubectl get configmaps -n production-app -o yaml > backup-configmaps.yaml
kubectl get secrets -n production-app -o yaml > backup-secrets.yaml

# 2.4: Verify backups were created
ls -lh *.yaml

# OPTIONAL: Backup with kubectl-neat (removes cluster-specific fields)
# Install: kubectl krew install neat
# kubectl get all -n production-app -o yaml | kubectl neat > backup-clean.yaml


# ============================================
# STEP 3: BACKUP PVC DATA
# ============================================
# Execute these steps to backup persistent volume data

# METHOD 1: Using a backup pod to copy data (RECOMMENDED)

# 3.1: Save the backup pod manifest below to: pvc-backup-pod.yaml
# 3.2: Create the backup pod
kubectl apply -f pvc-backup-pod.yaml

# 3.3: Wait for pod to be ready
kubectl wait --for=condition=Ready pod/pvc-backup-pod -n production-app --timeout=120s

# 3.4: Check the backup was created inside the pod
kubectl exec -it pvc-backup-pod -n production-app -- ls -lh /backup/

# 3.5: Copy the backup file to your local machine
# First, get the exact filename with timestamp
BACKUP_FILE=$(kubectl exec pvc-backup-pod -n production-app -- ls /backup/ | grep mysql-data)
echo "Backup file: $BACKUP_FILE"

# Copy to local directory
kubectl cp production-app/pvc-backup-pod:/backup/$BACKUP_FILE ./k8s-backups/mysql-data-backup.tar.gz

# 3.6: Verify local backup
ls -lh ./k8s-backups/mysql-data-backup.tar.gz

# 3.7: Clean up backup pod
kubectl delete pod pvc-backup-pod -n production-app

# --- Backup Pod Manifest (save as pvc-backup-pod.yaml) ---
---
apiVersion: v1
kind: Pod
metadata:
  name: pvc-backup-pod
  namespace: production-app
spec:
  containers:
  - name: backup
    image: alpine:latest
    command: ["/bin/sh"]
    args: ["-c", "tar czf /backup/mysql-data-$(date +%Y%m%d-%H%M%S).tar.gz -C /data . && sleep 3600"]
    volumeMounts:
    - name: mysql-data
      mountPath: /data
    - name: backup-storage
      mountPath: /backup
  volumes:
  - name: mysql-data
    persistentVolumeClaim:
      claimName: mysql-pvc
  - name: backup-storage
    hostPath:
      path: /tmp/k8s-backups
      type: DirectoryOrCreate
  restartPolicy: Never

# Commands to create and retrieve backup:
# kubectl apply -f pvc-backup-pod.yaml
# kubectl wait --for=condition=Ready pod/pvc-backup-pod -n production-app --timeout=60s
# kubectl cp production-app/pvc-backup-pod:/backup/mysql-data-TIMESTAMP.tar.gz ./mysql-data-backup.tar.gz


# METHOD 2: Direct kubectl cp (for small volumes - alternative method)
# 3.8: Get the MySQL pod name
MYSQL_POD=$(kubectl get pod -n production-app -l app=mysql -o jsonpath='{.items[0].metadata.name}')
echo "MySQL Pod: $MYSQL_POD"

# 3.9: Copy data directly from the pod
kubectl exec $MYSQL_POD -n production-app -- tar czf /tmp/mysql-backup.tar.gz -C /var/lib/mysql .
kubectl cp production-app/$MYSQL_POD:/tmp/mysql-backup.tar.gz ./k8s-backups/mysql-direct-backup.tar.gz


# METHOD 3: Volume Snapshot (if your storage class supports it - most cloud providers do)

# 3.10: Check if your cluster supports volume snapshots
kubectl get volumesnapshotclass

# 3.11: If supported, save the snapshot manifest below to: mysql-snapshot.yaml
# 3.12: Create the snapshot
# kubectl apply -f mysql-snapshot.yaml

# 3.13: Wait for snapshot to be ready
# kubectl wait --for=jsonpath='{.status.readyToUse}'=true volumesnapshot/mysql-snapshot -n production-app --timeout=300s

# 3.14: Verify snapshot
# kubectl get volumesnapshot -n production-app
# kubectl describe volumesnapshot mysql-snapshot -n production-app

# --- Volume Snapshot Manifest (save as mysql-snapshot.yaml) ---
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot
  namespace: production-app
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: mysql-pvc

# Check snapshot: kubectl get volumesnapshot -n production-app

# ============================================
# STEP 3B: ADD SAMPLE DATA (Optional but recommended)
# ============================================
# Add some test data to MySQL so you can verify restoration works

# 3.15: Connect to MySQL pod
MYSQL_POD=$(kubectl get pod -n production-app -l app=mysql -o jsonpath='{.items[0].metadata.name}')

# 3.16: Create a test database and table with data
kubectl exec -it $MYSQL_POD -n production-app -- mysql -uroot -prootpassword123 << EOF
CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (name, email) VALUES 
    ('John Doe', 'john@example.com'),
    ('Jane Smith', 'jane@example.com'),
    ('Bob Johnson', 'bob@example.com');
SELECT * FROM users;
EOF

# 3.17: Verify data was created
kubectl exec -it $MYSQL_POD -n production-app -- mysql -uroot -prootpassword123 -e "SELECT COUNT(*) as total_users FROM testdb.users;"


# ============================================
# STEP 4: SIMULATE DISASTER (Namespace Deletion)
# ============================================
# WARNING: This will delete EVERYTHING in the namespace!
# Make sure you have completed all backup steps above

# 4.1: Verify you have all backups
echo "Checking backups..."
ls -lh ./k8s-backups/

# You should see:
# - backup-production-app-all.yaml (or individual backup files)
# - mysql-data-backup.tar.gz (or mysql-direct-backup.tar.gz)

# 4.2: Take a screenshot or note current state
kubectl get all,pvc -n production-app

# 4.3: Delete the namespace (THIS IS THE DISASTER)
kubectl delete namespace production-app

# 4.4: Verify deletion (namespace should be gone)
kubectl get namespace production-app
# Should return: Error from server (NotFound): namespaces "production-app" not found

# 4.5: Verify all resources are gone
kubectl get all -n production-app
# Should return: No resources found


# ============================================
# STEP 5: RESTORE NAMESPACE AND MANIFESTS
# ============================================
# Now we'll recover from the disaster

# 5.1: Recreate the namespace first
kubectl create namespace production-app

# 5.2: Verify namespace exists
kubectl get namespace production-app

# 5.3: Apply the backed-up manifests
# Option A: Restore from single backup file
kubectl apply -f ./k8s-backups/backup-production-app-all.yaml

# Option B: Restore from individual backup files
# kubectl apply -f ./k8s-backups/backup-pvc.yaml
# kubectl apply -f ./k8s-backups/backup-deployments.yaml
# kubectl apply -f ./k8s-backups/backup-services.yaml
# kubectl apply -f ./k8s-backups/backup-configmaps.yaml
# kubectl apply -f ./k8s-backups/backup-secrets.yaml

# 5.4: Check resources are being created
kubectl get all,pvc -n production-app

# 5.5: Wait for PVC to be bound (this might take a minute)
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/mysql-pvc -n production-app --timeout=300s

# 5.6: Check pod status (pods might be in Pending or ContainerCreating)
kubectl get pods -n production-app

# 5.7: Wait for all pods to be ready
kubectl wait --for=condition=Ready pods --all -n production-app --timeout=300s

# Note: At this point, resources are restored but PVC data is still empty!


# ============================================
# STEP 6: RESTORE PVC DATA
# ============================================
# Now restore the actual data to the PVC

# METHOD 1: Restore from backup tar file (RECOMMENDED)

# 6.1: First, scale down MySQL deployment to prevent conflicts
kubectl scale deployment mysql -n production-app --replicas=0

# 6.2: Wait for MySQL pod to terminate
kubectl wait --for=delete pod -l app=mysql -n production-app --timeout=120s

# 6.3: Save the restore pod manifest below to: pvc-restore-pod.yaml
# 6.4: Before applying, we need to make the backup accessible to the cluster
# Create a ConfigMap or copy the backup to a location the pod can access

# For simplicity, we'll create a temporary pod and copy the backup into it
cat > pvc-restore-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pvc-restore-pod
  namespace: production-app
spec:
  containers:
  - name: restore
    image: alpine:latest
    command: ["/bin/sh"]
    args: ["-c", "echo 'Waiting for backup file...' && while [ ! -f /backup/mysql-data-backup.tar.gz ]; do sleep 2; done && tar xzf /backup/mysql-data-backup.tar.gz -C /data && echo 'Restore completed!' && sleep 300"]
    volumeMounts:
    - name: mysql-data
      mountPath: /data
    - name: backup-storage
      mountPath: /backup
  volumes:
  - name: mysql-data
    persistentVolumeClaim:
      claimName: mysql-pvc
  - name: backup-storage
    emptyDir: {}
  restartPolicy: Never
EOF

# 6.5: Create the restore pod
kubectl apply -f pvc-restore-pod.yaml

# 6.6: Wait for pod to be ready
kubectl wait --for=condition=Ready pod/pvc-restore-pod -n production-app --timeout=120s

# 6.7: Copy your backup file into the restore pod
kubectl cp ./k8s-backups/mysql-data-backup.tar.gz production-app/pvc-restore-pod:/backup/mysql-data-backup.tar.gz

# 6.8: Watch the restore process
kubectl logs -f pvc-restore-pod -n production-app

# You should see: "Restore completed!"

# 6.9: Verify files were restored
kubectl exec pvc-restore-pod -n production-app -- ls -lh /data/

# 6.10: Delete the restore pod
kubectl delete pod pvc-restore-pod -n production-app

# 6.11: Scale MySQL deployment back up
kubectl scale deployment mysql -n production-app --replicas=1

# 6.12: Wait for MySQL to be ready
kubectl wait --for=condition=Ready pod -l app=mysql -n production-app --timeout=300s

# METHOD 2: Restore from VolumeSnapshot (if you created one in Step 3)

# 6.13: First, delete the current PVC
# kubectl delete pvc mysql-pvc -n production-app

# 6.14: Create new PVC from snapshot (save as mysql-pvc-from-snapshot.yaml)
cat > mysql-pvc-from-snapshot.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: production-app
spec:
  dataSource:
    name: mysql-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# 6.15: Apply the new PVC
# kubectl apply -f mysql-pvc-from-snapshot.yaml

# 6.16: Wait for PVC to be bound
# kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/mysql-pvc -n production-app --timeout=300s

# 6.17: MySQL deployment will automatically use the restored PVC
# kubectl get pods -n production-app


# ============================================
# STEP 7: VERIFY RESTORATION
# ============================================
# Comprehensive verification that everything is restored correctly

# 7.1: Check namespace exists
kubectl get namespace production-app
# Expected: STATUS = Active

# 7.2: Check all resources are present
kubectl get all,pvc -n production-app
# Expected: See deployments, services, pods, and PVC

# 7.3: Check PVCs are bound
kubectl get pvc -n production-app
# Expected: STATUS = Bound

# 7.4: Check all pods are running
kubectl get pods -n production-app
# Expected: STATUS = Running for all pods

# 7.5: Verify pod details
kubectl describe pods -n production-app

# 7.6: Check MySQL is healthy
MYSQL_POD=$(kubectl get pod -n production-app -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $MYSQL_POD -n production-app -- mysql -uroot -prootpassword123 -e "SELECT VERSION();"

# 7.7: Verify the test data we created earlier is restored
kubectl exec -it $MYSQL_POD -n production-app -- mysql -uroot -prootpassword123 << EOF
USE testdb;
SELECT * FROM users;
SELECT COUNT(*) as total_users FROM users;
EOF

# Expected output: Should show the 3 users we created (John, Jane, Bob)

# 7.8: Check MySQL databases
kubectl exec -it $MYSQL_POD -n production-app -- mysql -uroot -prootpassword123 -e "SHOW DATABASES;"
# Expected: Should see 'myappdb' and 'testdb'

# 7.9: Verify Nginx is responding
kubectl get service nginx-service -n production-app
# Get the service endpoint

# 7.10: Test Nginx with port-forward
kubectl port-forward service/nginx-service -n production-app 8080:80 &
PF_PID=$!
sleep 3

# 7.11: Test connection
curl http://localhost:8080
# Expected: Nginx welcome page HTML

# 7.12: Kill port-forward
kill $PF_PID

# 7.13: Check events for any issues
kubectl get events -n production-app --sort-by='.lastTimestamp'

# 7.14: Final health check - all pods should show 1/1 READY
kubectl get pods -n production-app -o wide

echo ""
echo "================================"
echo "RESTORATION VERIFICATION COMPLETE!"
echo "================================"
echo ""
echo "Summary:"
kubectl get all,pvc -n production-app


# ============================================
# BONUS: AUTOMATED BACKUP CRONJOB
# ============================================
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: namespace-backup
  namespace: production-app
spec:
  schedule: "0 2 * * *"  # Run daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: backup-sa
          containers:
          - name: backup
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              DATE=$(date +%Y%m%d-%H%M%S)
              kubectl get all,pvc,configmap,secret -n production-app -o yaml > /backup/backup-${DATE}.yaml
              # Add your logic to upload to S3, GCS, etc.
              echo "Backup completed: backup-${DATE}.yaml"
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
          volumes:
          - name: backup-volume
            hostPath:
              path: /var/backups/k8s
              type: DirectoryOrCreate
          restartPolicy: OnFailure

---
# ServiceAccount for backup cronjob
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backup-sa
  namespace: production-app

---
# Role for backup operations
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backup-role
  namespace: production-app
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list"]

---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backup-rolebinding
  namespace: production-app
subjects:
- kind: ServiceAccount
  name: backup-sa
  namespace: production-app
roleRef:
  kind: Role
  name: backup-role
  apiGroup: rbac.authorization.k8s.io