# Home AMD GPU driver-only canary

Status: **failed 2026-09-07; CPU-only rollback required**. Canary: worker2,
192.168.1.195, machine `4913bb46-7cd8-2048-84c7-a8595f97a48c`.
It already has a separate machine set, so no membership move is needed.
It is not an empty node: kagent/Substrate and gateway databases run there.

## Evidence and experiment

All three workers report AZW EQ, Ryzen 7 5825U, Barcelo PCI `1002:15e7`,
BIOS FP656V507 (2024-09-05), Talos 1.13.10 / Linux 6.18.48. They are currently
CPU-only. Worker2 previously hard-froze after amdgpu initialized; workers1/3
later became unreachable with SMU/gfxoff timeouts during the 1.12.12 rollout.
The original full failure sequence was not recovered from retained Omni logs
during the 2026-09-07 audit. Driver power management is a hypothesis, not a
confirmed root cause.

This experiment changes the kernel/firmware baseline relative to the earlier
failure and excludes GPU operator daemons/exporters and applications. It does
not assert a known GPU fix in 1.13.10. No speculative power-management mask,
IOMMU change, overclock, BIOS flash, Talos upgrade, or Kubernetes upgrade is
included. Beelink's published FP656V509 notes say only "code update"; obtain
exact-unit compatibility and fix details before considering a separate flash.

The change affects only the worker2 machine set: add `siderolabs/amdgpu`, load
the module, and explicitly keep `amd.com/gpu=false`. Preserve amd-ucode,
Realtek firmware, storage extensions, gVisor prerequisites, networking, and
`bgp=enable`. Workers1/3 and the control plane remain CPU-only. The existing
DeviceConfigs require `amd.com/gpu=true`, so neither should select the canary.
The false label does not prevent privileged pods from accessing the driver;
workload isolation and a device-mount audit are still required.

## Gates before merge and sync

- [ ] User confirms worker2 and a maintenance window, including someone at the
  correct machine with a console and power control. Omni logs are useful but
  cannot recover a machine whose kernel/network has frozen.
- [ ] Check BIOS settings, cooling/thermals and memory-test history. Resolve
  unexplained hardware faults or explicitly decide how to investigate them
  before repeating the GPU experiment. Do not clear CMOS or flash speculatively.
- [ ] Alertmanager memory remediation is deployed and stable for at least
  45 minutes; verify the Robusta/Slack notification path. OnCall receiver
  failure is separate and must not be mistaken for successful delivery.
- [ ] Capture current CPU-only schematic/installer reference and a proven
  local recovery method that can boot/install it without relying on the
  hung OS. Do not assume an ordinary reboot applies the rollback image.
- [ ] Inventory current worker2 pods, PDBs, PVCs and required node affinities.
  Verify database backups/readiness, Longhorn replica health, capacity and
  safe storage attachment on the remaining workers. Keep login/config PVCs.
- [ ] Review any needed workload-placement changes in homelab-k8s first.
  Stop active actor turns; move or intentionally pause worker2-pinned kagent
  workers and database workloads. Do not delete chats, databases or PVCs.
- [ ] Cordon and drain worker2 as a recorded maintenance operation after
  placement changes converge. Inspect a drain dry-run first; no `--force`,
  `--disable-eviction` shortcuts. Any `emptyDir` cleanup requires a recorded
  audit of the exact mounts; persistent data must remain intact. A blocking PDB,
  local data, singleton outage or affinity is a stop condition, not permission
  to force eviction. Keep the node cordoned during the initial test.
- [ ] Check Cilium BGP peers/routes before and after the drain. Worker2's
  speaker may briefly withdraw routes during reboot; remaining workers must
  preserve reachability. Do not change BGP ownership or the control-plane label.
- [ ] Review the exact merged-commit template diff: only worker2 GPU extension,
  module patch and false label. No machine deletion/membership/OS version changes.

## Driver-only rollout and acceptance

Use the reviewed, merged commit and the normal `omnictl cluster template`
validate/diff/sync workflow. Start bounded/retained Omni log capture before
the upgrade. Do not sync this draft directly from its feature branch.

Confirm worker2 returns with the expected extensions and kernel, amdgpu binds
to `1002:15e7`, and `/dev/dri` render devices exist. Check that
`amd.com/gpu=false`, GPU allocatable is absent or zero, and no GPU operator
device-plugin/labeller/exporter pods target it. Keep Qwen at zero replicas,
Plex CPU-only and other GPU device mounts absent.

Observe idle operation for at least 24 hours, with continuous reachability
and kernel log collection. Check SMU/gfxoff errors, GPU resets, firmware
failures, thermal warnings and storage/BGP health. A clean idle interval is
only an initial gate, not proof of load stability. In the coordinated window,
also test a reboot and a cold boot with recovery access. A later separate
homelab-k8s PR must introduce a bounded GPU diagnostic workload to test repeated
idle/load transitions; do not use the old Qwen ROCm configuration as the test.
Do not expand to another worker until that test and another idle soak pass.

## Stop and rollback

Any new SMU/gfxoff timeout, GPU reset, thermal fault, node disconnect or
unexplained loss of storage/network health stops the test. Preserve logs and
do not enable the exporter/apps to troubleshoot by adding more variables.

Revert this canary through a reviewed PR, restoring worker2's previous
CPU-only extension list and removing the amdgpu module patch (the false GPU
label may remain). Sync only the reviewed rollback. If the node is frozen,
use the pre-arranged console/recovery method; verify the CPU-only image is
actually installed. No Talos reset, disk wipe, PVC deletion or volume salvage.
Restore workloads and uncordon only after node, storage and BGP health pass.

## Maintenance checkpoint — 2026-09-07

The user authorized worker2, physical console/power recovery and brief singleton
outages. Hardware checks found about 57 C at idle and no retained critical thermal
or hardware-error events; no full memory test has been performed. CPU-only recovery
media and verified database restore archives are held in private local storage.

The first drain relocated the databases and passed four actor suspend/resume
smoke tests. Gateway PDB protection was restored. Envoy spread constraints were
fixed to honor cordoned nodes (homelab-k8s PR 1715). That attempt was cancelled
before GPU enablement because new CI builds displaced Plex. Jenkins quiet-down
is now API-verified; a second drain is in progress. Do not mistake preparation
checks for driver acceptance or a completed 24-hour soak.

## Sources

- [Talos AMD GPU setup](https://docs.siderolabs.com/talos/v1.13/configure-your-talos-cluster/hardware-and-drivers/amd-gpu)
- [Omni cluster templates](https://docs.siderolabs.com/omni/reference/cluster-templates)
- [Beelink FP656V509 notes](https://www.bee-link.com/blogs/all/beelink-aug-sept-bios-update-summary)
- [CPU-only incident/recovery PR](https://github.com/erauner/homelab-omni/pull/22)

## Failed canary — 2026-09-07

PR 34 was merged and synced after graceful drain and API-verified Jenkins
quiet-down. Talos remained 1.13.10 / kernel 6.18.48. The amdgpu extension
20260810-v1.13.10 initialized PCI 1002:15e7 and SMU successfully at 20:51:41 UTC;
card0 and renderD128 appeared. GPU label remained false with no allocatable GPU.
Talos uncordoned the node on return; it was immediately cordoned again and only
DaemonSet pods were present.

Last retained kernel log is approximately 20:52:08 UTC; last kubelet heartbeat
20:52:10. By 20:53:03 the node was NotReady and Talos API reads timed out. No
new SMU/gfxoff error was captured before the loss of contact. This reproduces
loss of stability with driver-only enablement; it does not establish the
hardware or driver root cause. No idle soak or application/load test passed.

Talos logged `removing fallback entry` after declaring the machine ready.
Do not assume the previous CPU-only entry remains available. The prepared
CPU-only recovery ISO remains the fallback method if remote rollback cannot
reach the node. Preserve logs and disks; do not reset or wipe. CPU-only rollback
removes the amdgpu extension/module and retains amd.com/gpu=false.
