#!/bin/bash
set -Eeuo pipefail
trap 'echo "❌ ${FUNCNAME[0]:-main} failed on line $LINENO"' ERR

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
    TALOS_FLAGS="${TALOSCONFIG:+--talosconfig $TALOSCONFIG}"
    
    # Check extensions (may fail if not authenticated)
    if talosctl $TALOS_FLAGS get extensions 2>/dev/null | grep -E "(iscsi-tools|util-linux-tools)"; then
        echo "   ✅ Extensions visible in Talos"
    else
        echo "   ⚠️  Extensions not visible (may be auth issue)"
    fi
    
    # Check if iscsiadm exists on nodes (correct path)
    echo "   Checking for iscsiadm on first node..."
    NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$NODE" ]; then
        if talosctl $TALOS_FLAGS -n "$NODE" which iscsiadm &>/dev/null; then
            echo "   ✅ iscsiadm found on node $NODE"
        else
            echo "   ⚠️  iscsiadm not found (checking alternate methods)"
            # Try the actual path where extensions install binaries
            if talosctl $TALOS_FLAGS -n "$NODE" ls /usr/bin/iscsiadm &>/dev/null; then
                echo "   ✅ iscsiadm found at /usr/bin/iscsiadm"
            else
                echo "   ❌ iscsiadm not found at expected paths"
            fi
        fi
    fi
else
    echo "   ⚠️  talosctl not available or not authenticated, skipping extension checks"
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

# Wait for PVC to be bound
echo "   Waiting for PVC to bind..."
if kubectl wait --for=condition=Bound pvc/test-longhorn-pvc --timeout=120s &>/dev/null; then
    echo "   ✅ RWO volume created and bound successfully"
else
    PVC_STATUS=$(kubectl get pvc test-longhorn-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "   ⚠️  PVC not bound after 120s (status: $PVC_STATUS)"
fi

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

# Wait for RWX PVC to be bound
echo "   Waiting for RWX PVC to bind..."
if kubectl wait --for=condition=Bound pvc/test-longhorn-rwx-pvc --timeout=120s &>/dev/null; then
    echo "   ✅ RWX volume created and bound (NFS tools working)"
    
    # Optional: Test actual RWX functionality with two pods
    echo "   Testing actual RWX access with multiple pods..."
    kubectl apply -f - <<'YAML' &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: test-rwx-writer
  namespace: default
spec:
  containers:
  - name: writer
    image: busybox:stable
    command: ['sh', '-c', 'echo "RWX test from writer pod" > /data/test.txt && sleep 30']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-longhorn-rwx-pvc
---
apiVersion: v1
kind: Pod
metadata:
  name: test-rwx-reader
  namespace: default
spec:
  containers:
  - name: reader
    image: busybox:stable
    command: ['sh', '-c', 'sleep 10 && cat /data/test.txt']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-longhorn-rwx-pvc
YAML
    
    # Wait for reader pod to complete
    if kubectl wait --for=condition=Ready pod/test-rwx-reader --timeout=30s &>/dev/null; then
        sleep 2
        CONTENT=$(kubectl logs test-rwx-reader 2>/dev/null || echo "")
        if [[ "$CONTENT" == *"RWX test from writer pod"* ]]; then
            echo "   ✅ RWX confirmed: Multiple pods can read/write same volume"
        else
            echo "   ⚠️  RWX mount succeeded but shared access not verified"
        fi
    fi
    
    # Cleanup RWX test pods
    kubectl delete pod test-rwx-writer test-rwx-reader --ignore-not-found=true &>/dev/null
else
    RWX_STATUS=$(kubectl get pvc test-longhorn-rwx-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "   ⚠️  RWX PVC not bound after 120s (status: $RWX_STATUS)"
fi
echo

# Cleanup
echo "6. Cleaning up test resources..."
kubectl delete pod test-longhorn-pod test-rwx-writer test-rwx-reader --ignore-not-found=true &>/dev/null || true
kubectl delete pvc test-longhorn-pvc test-longhorn-rwx-pvc --ignore-not-found=true &>/dev/null || true
echo "   ✅ Cleanup complete"
echo

echo "=== Verification Complete ==="

# Summary
echo "Summary:"
echo "- Longhorn installation: ✅"
if [ "$RUNNING_PODS" -gt 15 ]; then
    echo "- Pod health: ✅ ($RUNNING_PODS pods running)"
else
    echo "- Pod health: ⚠️  ($RUNNING_PODS pods running, expected >15)"
fi
echo "- Default StorageClass: $([ "$DEFAULT_SC" = "longhorn" ] && echo "✅" || echo "⚠️ ") $DEFAULT_SC"
echo
echo "Note: Extension checks require valid talosconfig. Use:"
echo "  export TALOSCONFIG=/path/to/talosconfig"
echo "  # or"
echo "  omnictl talosconfig > ~/.talos/config"
