# Home Talos and AMD GPU rolling upgrade — 2026-10-26

The user requested updating all nodes to the latest stable Talos and extending
the GFXOFF setting to the similar worker GPUs, explicitly choosing to proceed
without the earlier 24-hour canary wait. Talos 1.14.5 is the latest stable
release offered by Omni and supports Kubernetes 1.35; Kubernetes stays 1.35.8.
The new kernel is 6.18.58, versus worker2's tested 6.18.57. Its amdgpu default
mask remains 0xfff7bfff, so 0xfff73fff still clears only GFXOFF.

Preparation leaves all workers locked, adds direct temporary LAN capture for
the control plane and workers1/3, and uses firmware reboot control. Worker2
keeps its existing GPU mask, recovery taint, cordon, port-6666 capture and
Longhorn exclusion. The other nodes forward service/kernel records to the
bounded Mac receiver on UDP 6668. Raw evidence and credentials remain private.

A fresh 197,091,360-byte etcd snapshot was downloaded and validated by talosctl
before any version change, with a private SHA-256 record. Controlplane1's
server-side drain dry-run passed; remaining emptyDir was Cilium's /tmp in an
ignored DaemonSet. The single-control-plane reboot briefly interrupts API
availability. Other workloads keep running on the workers.

Stages:

1. Merge/sync preparation and verify locks, firmware control and live capture.
2. Change only the cluster Talos target to 1.14.5, upgrading the control plane
   while all workers stay locked. Verify etcd, API, node and platform services.
3. Unlock only isolated worker2, verify the new GPU image/kernel/mask, and rerun
   the bounded full-offload Qwen/API/CPU comparison before expanding.
4. Return validated capacity through recorded scheduling/storage changes.
   Worker1 currently has little disk-pressure headroom; check actual free space
   and replicas before moving data. Drain each remaining worker separately,
   respecting PDBs, active actors, PVC attachment and audited temporary data.
5. Upgrade each remaining worker CPU-only to 1.14.5 first while its workloads
   remain drained and maintenance-tainted. The CPU image already contains the
   future GPU boot argument; verify firmware-reboot control is active before
   adding that node's GPU extension/module. This avoids the first GPU boot
   occurring before ordinary config has been applied (Omni upgrades the OS
   before applying normal config). Verify each GPU before unlocking the next.
   Keep ordinary GPU workloads opt-in until
   their device exposure/inference path is tested. The control plane stays
   CPU-only. Finish with all four nodes on the same Talos target.

No force drain, forced detach, data/PVC deletion or BIOS change is authorized
by this procedure. Resolve singleton PDB and capacity constraints with reviewed
application changes before unlocking their node. Do not reset chats or delete
actor snapshots to make a drain pass.

Sources: [1.14.5](https://github.com/siderolabs/talos/releases/tag/v1.14.5),
[support matrix](https://docs.siderolabs.com/talos/v1.14/getting-started/support-matrix),
[upgrade lifecycle](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/lifecycle-management/upgrading-talos).


## Execution receipt — 2026-10-27 UTC

All four nodes report Talos 1.14.5, kernel 6.18.58 and containerd 2.3.7;
Kubernetes remains 1.35.8. Omni reports the cluster Ready, four healthy connected
machines, and completed Talos upgrade state. No worker locks remain. All workers
use the same GPU schematic 06309d28beb05b2c5d186bd71da3663735b7c1631f90542b7dcc3587b6fdba28,
with GFXOFF mask 0xfff73fff and firmware reboot control verified. The control
plane remains on its CPU-only extension set.

The three bounded Qwen3.5-4B Q4_K_M Jobs completed full 33/33 Vulkan offload and
three GPU plus three CPU requests each. Worker2 v3 completed at 03:09:33 UTC,
worker1 v1 at 03:55:06, and worker3 v1 at 04:21:16. Workers1/3 each retained one
boot ID and 31 healthy independent heartbeat samples during their measured run;
checked kernel logs had no ring timeout, GPU reset, panic or hardware-error
signature. Test servers exited at completion; these are not permanent inference
services or proof of long-term stability. The user explicitly waived 24 hours.

Application relocation preserved PVC identities, actor snapshots and chat state.
Fresh etcd and database archives remain private. Singleton PDBs were restored
with explicit enablePDB=true; the Nexus service PDB returned to minAvailable=1.
OnCall followed its existing declarative database hibernation annotation. Normal
worker scheduling and storage eligibility were restored, as was the default
Longhorn drain policy. During redistribution a redundant fourth replica briefly
caused disk pressure on worker3; removing only that extra copy after verifying
three other RW copies restored headroom. Metrics volumes gained second copies,
without claim replacement. Background replica balancing continues as needed.

See [the application maintenance receipt](https://github.com/erauner/homelab-k8s/blob/master/docs/home-talos-1145-maintenance.md)
and [GPU Jobs/results](https://github.com/erauner/homelab-k8s/tree/master/apps/worker2-gpu-canary).
Raw evidence is private under home-uniform-talos-20261027. Direct capture for
controlplane1 and workers1/3 is bounded until 2026-10-28T04:24:32Z; worker2's
receiver ends at 03:15:29Z that day. The Mac must remain on its LAN for UDP capture.
