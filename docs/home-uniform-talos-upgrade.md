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
5. Apply the same GPU mask/firmware control to workers1/3, upgrade and verify
   each before unlocking the next. Keep ordinary GPU workloads opt-in until
   their device exposure/inference path is tested. The control plane stays
   CPU-only. Finish with all four nodes on the same Talos target.

No force drain, forced detach, data/PVC deletion or BIOS change is authorized
by this procedure. Resolve singleton PDB and capacity constraints with reviewed
application changes before unlocking their node. Do not reset chats or delete
actor snapshots to make a drain pass.

Sources: [1.14.5](https://github.com/siderolabs/talos/releases/tag/v1.14.5),
[support matrix](https://docs.siderolabs.com/talos/v1.14/getting-started/support-matrix),
[upgrade lifecycle](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/lifecycle-management/upgrading-talos).
