#\!/bin/bash
set -e

echo "=== Longhorn on Talos Verification Script ==="
echo

# Check if we're connected to a cluster
if \! kubectl cluster-info &>/dev/null; then
    echo "❌ Not connected to a Kubernetes cluster"
    exit 1
fi

# 1. Check Talos extensions
echo "1. Checking Talos system extensions..."
if command -v talosctl &>/dev/null; then
    echo "   Checking for iSCSI and util-linux tools..."
    talosctl get extensions | grep -E "(iscsi-tools|util-linux-tools)" || echo "   ⚠️  Extensions not visible via talosctl"
    
    # Check if iscsiadm exists on nodes
    echo "   Checking for iscsiadm on first node..."
    NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    talosctl -n $NODE ls /usr/local/bin/iscsiadm &>/dev/null && echo "   ✅ iscsiadm found" || echo "   ❌ iscsiadm not found"
else
    echo "   ⚠️  talosctl not available, skipping extension checks"
fi
echo

# 2. Check Longhorn pods
echo "2. Checking Longhorn deployment..."
LONGHORN_PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep Running | wc -l)
echo "   Total pods: $LONGHORN_PODS, Running: $RUNNING_PODS"
if [ "$RUNNING_PODS" -gt 15 ]; then
    echo "   ✅ Longhorn appears healthy"
else
    echo "   ⚠️  Some Longhorn pods may not be running"
fi
echo

# 3. Check StorageClasses
echo "3. Checking StorageClasses..."
kubectl get storageclass | grep longhorn
DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
echo "   Default StorageClass: $DEFAULT_SC"
[ "$DEFAULT_SC" = "longhorn" ] && echo "   ✅ Longhorn is default" || echo "   ⚠️  Longhorn is not default"
echo

# 4. Test volume creation (RWO)
echo "4. Testing RWO volume creation..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-longhorn-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
YAML

sleep 5
PVC_STATUS=$(kubectl get pvc test-longhorn-pvc -o jsonpath='{.status.phase}')
echo "   PVC Status: $PVC_STATUS"
[ "$PVC_STATUS" = "Bound" ] && echo "   ✅ RWO volume created successfully" || echo "   ⚠️  PVC not bound yet"

# Create a test pod
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: test-longhorn-pod
  namespace: default
spec:
  containers:
  - name: test
    image: nginx:alpine
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-longhorn-pvc
YAML

echo "   Waiting for pod to start..."
kubectl wait --for=condition=Ready pod/test-longhorn-pod --timeout=60s &>/dev/null && echo "   ✅ Pod attached to volume" || echo "   ⚠️  Pod not ready yet"
echo

# 5. Test RWX capability (optional)
echo "5. Testing RWX volume creation (share-manager)..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-longhorn-rwx-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
YAML

sleep 5
RWX_STATUS=$(kubectl get pvc test-longhorn-rwx-pvc -o jsonpath='{.status.phase}' 2>/dev/null)
echo "   RWX PVC Status: $RWX_STATUS"
[ "$RWX_STATUS" = "Bound" ] && echo "   ✅ RWX volume created (NFS tools working)" || echo "   ⚠️  RWX not supported or not ready"
echo

# Cleanup
echo "6. Cleaning up test resources..."
kubectl delete pod test-longhorn-pod --ignore-not-found=true
kubectl delete pvc test-longhorn-pvc test-longhorn-rwx-pvc --ignore-not-found=true
echo "   ✅ Cleanup complete"
echo

echo "=== Verification Complete ==="
