# Substrate worker eligibility

The three home workers share `patches/gvisor-userns-workers.yaml`. It sets
`user.max_user_namespaces=11255` for Substrate's bundled gVisor runtime and
labels prepared nodes `homelab.dev/substrate-worker=true`. This expands the
previous worker2-only hardening exception; the control plane remains excluded.
No GPU extension, GPU label, Talos/Kubernetes version, or storage setting changes.

## Ordered GitOps rollout

1. Validate the home template and inspect its Omni diff. Only the shared-worker
   prerequisite and worker2 eligibility label should change.
2. Merge this prerequisite PR and sync the exact merged home template through
   Omni. Verify configuration reconciliation and read
   `/proc/sys/user/max_user_namespaces` on each worker: all must report `11255`.
   Check each node's eligibility label and Ready status. Do not reboot manually.
3. Only then merge the homelab-k8s scheduling PR. It retains four total workers
   and the current harness selector, using three WorkerPools with preferred
   placement across workers1/2/3 and fallback to other eligible nodes.
4. Validate real simultaneous native Codex chats and command execution on all
   three nodes, not only Ready pods. Check Cilium/BGP and storage health.

Rollback scheduling through Git first, returning all actor capacity to worker2
and waiting for actors on workers1/3 to stop. Only then remove those nodes'
eligibility and user-namespace exception via an Omni PR. Never disable user
namespaces underneath active gVisor actors. Keep worker2's prerequisite intact.

This distributes actor capacity, not the complete kagent/Substrate service
stack. Node maintenance still requires checking supporting services and volumes.
