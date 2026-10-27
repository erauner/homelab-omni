# Home AMD GPU driver-only canary

Status: **CPU-only Talos 1.13.12 recovered and reboot verified; GPU canary
failed (2026-10-26)**. Both the September and October driver-only retries lost contact.
Canary: worker2,
192.168.1.195, machine `4913bb46-7cd8-2048-84c7-a8595f97a48c`.
It already has a separate machine set, so no membership move is needed.
Worker2 is cordoned with `homelab.dev/recovery=cpu-only:NoSchedule`; normal
workloads and databases have moved to the other workers. The earlier incident
and maintenance notes below are historical.

## Talos GFXOFF canary — 2026-10-26

The user authorized carrying the Linux comparison into the real Talos image.
Worker2 alone gains `siderolabs/amdgpu`, a module configuration setting
`ppfeaturemask=0xfff73fff`, and the image kernel argument
`amdgpu.ppfeaturemask=0xfff73fff` so the setting is present for early loading.
The mask clears only GFXOFF from the measured `0xfff7bfff` default, which is
also unchanged in the Linux 6.18.57 source used by Talos 1.13.12. Talos remains
1.13.12 and Kubernetes 1.35.8. Workers1/3 stay locked and CPU-only.

The Linux driver remained responsive with no captured GPU fault when checked
again after more than 80 minutes. The completed 30-minute comparison below is
the retained observation interval, not proof of a fix. The Talos kernel and
firmware differ from Linux, so this is a new canary, not production acceptance.

Before booting back to the internal CPU-only installation, sync the merged
worker2-only desired configuration and verify Omni has generated a schematic
containing both the GPU extension and the GFXOFF kernel argument. Preserve the
cordon, recovery taint, false GPU label, direct log capture, firmware reboots,
and Longhorn exclusion with zero worker2 replicas/engines/attachments. No
application GPU workload or storage scheduling is enabled by this change.

After the image transition, verify the actual running mask, GPU binding,
render device, expected image/kernel, a new boot ID and fresh LAN kernel logs.
Capture the first idle interval beyond the previous failure time, then retain
at least 24 hours of idle observation before production acceptance and a
separate bounded load/transition test. Do not treat Ready as GPU stability.

Rollback through a reviewed CPU-only change: remove the worker2 GPU extension
and module patch and set its managed `kernelArgs: []` explicitly. Omitting
`kernelArgs` returns its lifecycle outside template management and will not
reliably clear the KernelArgs resource. Preserve isolation and storage
exclusion. If the node is unresponsive, the Samsung GPU-blocked recovery image
and the retained internal CPU UKI remain the local recovery path; do not reset
Talos, reformat storage or remove PVCs.

## Crash capture — 2026-10-26

Verified against a CPU-only reboot before GPU enablement: worker2 returned
Ready with a new boot ID, and the Mac received fresh raw kernel records and
Talos service messages during startup. The Talos receiver was restarted at
23:16 UTC with the refreshed private Talos configuration and a deadline of 2026-10-27 23:16 UTC. The separate Linux
netconsole receiver was restarted through 2026-10-27 01:16 UTC. Check each
receiver's status file and fresh packets before relying on it; the earlier
Talos receiver was no longer running when checked. The GPU canary has ended.

The worker2-only `worker2-crash-logging` patch forwards Talos service logs and
kernel logs directly over the LAN to the Mac at `192.168.1.174:6666/udp`.
The named `KmsgLogConfig` supplements Omni's existing kernel-log destination.
This does not change the OS image, Kubernetes version or GPU configuration.
Remove this temporary patch after the investigation or when the receiver moves.

On the Mac, a user launch agent runs a bounded 24-hour receiver, direct ping
checks and Kubernetes node checks every five seconds, plus a Talos kernel-log
stream that reconnects every minute. Logs and status are retained privately in
`~/.local/state/homelab-maintenance/talos-11312-20261026/`:

- `worker2-udp-logs.jsonl`: timestamped datagrams from worker2, including both
  kernel and Talos service records.
- `worker2-heartbeats.jsonl`: direct reachability, Ready condition and boot ID.
- `worker2-talos-kernel.log`: separate capture through the Talos API.
- `worker2-capture-status.json`: receiver PID, deadline and packet counts.

The receiver uses `caffeinate` to prevent idle sleep for its lifetime. Keep
the Mac powered, on this LAN with its lid open and address unchanged. To stop
capture early, run `launchctl bootout gui/$(id -u)/local.homelab.worker2-crash-capture`.
Retain raw logs privately: boot messages can contain Omni enrollment credentials.

This is userspace log forwarding, not kernel netconsole or a persistent crash
dump. The installed 6.18.57 kernel has `CONFIG_NETCONSOLE=y`,
`CONFIG_NETCONSOLE_DYNAMIC` disabled and `CONFIG_R8169=m`. Built-in netconsole
initializes before the modular Realtek NIC driver exists, so a boot argument
alone cannot establish capture. The current pstore backend is also unset.
No speculative netconsole boot argument or custom kernel is applied.

The LAN stream removes dependence on Kubernetes and the Omni tunnel, but a
complete hardware lock can still prevent the final message from being sent.
Record the physical console during the first GPU boot. More reliable final
panic capture would require a supported serial console path or a separately
built kernel with suitable netconsole/NIC configuration.

References: [Talos log forwarding](https://docs.siderolabs.com/talos/v1.13/configure-your-talos-cluster/logging-and-telemetry/logging),
[KmsgLogConfig](https://docs.siderolabs.com/talos/v1.13/reference/configuration/runtime/kmsglogconfig),
[Linux 6.18.57 netconsole initialization](https://github.com/gregkh/linux/blob/v6.18.57/drivers/net/netconsole.c).

## Driver retry — 2026-10-26

The user authorized another worker2-only test after the CPU-only capture check.
Talos 1.13.12 uses Linux 6.18.57, replacing the failed canary's Talos 1.13.10 /
Linux 6.18.48 baseline. No confirmed fix for this particular freeze has been
identified. Kubernetes stays at 1.35.8 and BIOS settings stay unchanged.

Add only `siderolabs/amdgpu` and the existing `kernel-amdgpu` module patch to
worker2. Preserve the CPU-only recovery media, direct logging, recovery taint,
cordon and `amd.com/gpu=false`. Only DaemonSet pods remain on worker2; active
databases and storage attachments are on the other workers. Workers1/3 stay
locked in Omni while this test runs.

The first gate is successful driver initialization and an isolated idle soak
of at least 24 hours. No application or GPU load test is part of this rollout.
Follow the stop/rollback criteria below if the node disconnects or GPU errors
appear. A successful boot alone does not establish stability.

### Failed retry and retained evidence

PR 39 was merged and synced. Omni confirmed worker2's AMD GPU extension and
schematic `b0f6147ed4de8943dcbaea1a9af2e9c447cd2210659611021492273042238411`.
The node booted at approximately 19:41:18 UTC with boot ID
`9f653b3a-ca91-474b-b46d-d383d8944a01`. The Talos API kernel capture shows
`Initialized amdgpu 3.64.0` at 19:41:20.872 UTC and successful framebuffer
initialization. Kubernetes Ready returned shortly afterward.

Last received UDP log: 19:42:22.519 UTC (14:42:22 CDT), a routine successful
dashboard resource-list request. The last successful ping sample started at
19:42:22.520; the next sample at 19:42:27.961 failed. The Talos API stopped
responding and Kubernetes subsequently reported Ready=Unknown. The user also
observed a frozen physical console. No final panic, SMU timeout or GPU reset
was captured. This reproduces loss of availability on the new kernel, without
a GPU application or device-plugin workload; it does not identify the root cause.

The idle acceptance gate failed. Remove the GPU extension/module patch and
restore the proven CPU-only schematic
`4d159fd47ebc33ce9c1e17e182bcb5533b688c67e33ec093a5da55618b5c5fda`.
Retain direct logging, cordon, recovery taint and false GPU labels. The hung
node cannot apply the rollback until physical recovery restores contact;
use the verified CPU-only USB rather than assuming a fallback boot entry exists.
Do not run GPU applications or extend this test to another worker.

An immutable copy of UDP, Talos API and heartbeat logs, kernel build config,
and a summary of the final records is held privately on the Mac under
`~/.local/state/homelab-maintenance/talos-11312-20261026/worker2-freeze-20261026T194222Z/`.
Raw boot logs may contain enrollment credentials and must not be published.

## CPU-only recovery — 2026-10-26

The first CPU-only USB boot mounted the existing STATE partition but could
not load its machine configuration. Read-only inspection from SystemRescue
found `config.yaml` was zero bytes, with mtime 19:41:33.521 UTC during the GPU
rollout. Node identity and encryption-salt files remained present. This
explains the subsequent boot failure; it does not explain the GPU hard lock.

Before repairs, raw STATE (100 MiB), META (1 MiB), and EFI (2,203,058,176 bytes)
backups were copied to private storage and SHA-256 checked. The NVMe reported
zero critical warnings, media errors and error-log entries. XFS had pending
journal updates; normal journal replay followed by a read-only filesystem
check passed, while the config file remained empty.

The recovery image was SystemRescue 13.02 / Linux 6.18.41-1-lts, booted to RAM
with amdgpu/radeon blocked. It guarded worker2's hardware UUID, made the NVMe
read-only initially, and allowed temporary SSH only from the Mac using a
dedicated key. The following repair preserved the existing files and data:

- Renamed the empty config to `config.yaml.empty-20261026T194133Z` so Talos
  could enter maintenance mode and receive its configuration again.
- Moved the failed GPU UKI out of `EFI/Linux` to
  `EFI/disabled-recovery/Talos-v1.13.12-gpu.efi.disabled`.
- Kept the original CPU-only `Talos-v1.13.12.efi` unchanged and selected its
  `@main` profile as the default. The next firmware boot selected the internal
  Talos entry. No image reinstall or partition reset was performed.

Omni's cached applied-config SHA prevented a full config apply to a machine
now in maintenance; the API exposes that status as read-only. After confirming
maintenance mode, no application pods and no attached volumes, the normal
cluster-assignment removal/re-add path let Omni recreate that status and resend
its configuration. Omni verified maintenance and skipped reset. The machine
stayed in the Omni account with the same hardware UUID and Talos node identity;
the Kubernetes Node object was recreated. The force/account-deletion path was
not used.

PR 41 makes the recovery NoSchedule taint part of worker2's initial kubelet
registration. Preserve this taint, the cordon and false GPU labels during the
investigation. STATE UUID `542d6317-4369-47cf-84d4-1f2a7ab5b289` and EPHEMERAL
UUID `b3493df4-f617-4541-b2b2-be72e84799c3` were verified unchanged after rejoin.
The node returned Ready on the CPU-only schematic, all scheduled system pods
were ready, Cilium/BGP was healthy and all 17 attached Longhorn volumes on the
other workers were healthy before the persistence reboot. The controlled
internal-disk reboot then passed: boot ID changed from
`0536d916-5866-4ce6-9245-0866e801e10e` to
`d744dddd-780b-4d34-b23d-1fac852ddeea`, Talos and kubelet returned healthy,
Kubernetes Ready returned, and Omni confirmed maintenance=false with the
CPU-only schematic and no config error. The cordon and recovery taint persisted;
no amdgpu/radeon module was loaded. Cilium was OK and BGP to the router was
established. Direct kernel/service capture resumed after reboot.

The reboot temporarily degraded ten volumes because their worker2 replica
processes stopped. Longhorn 1.9.1 does not recreate an instance-manager pod
while its node is cordoned. After verifying the recovery taint remained and no
application pods were pending, a brief uncordon allowed the instance manager
and replica rebuilds to finish. All 17 attached volumes returned healthy by
21:23:54 UTC, and worker2 was re-cordoned. No Longhorn toleration or global
storage setting was changed. See the [Longhorn controller guard](https://github.com/longhorn/longhorn-manager/blob/v1.9.1/controller/instance_manager_controller.go#L649-L653).

Backups, checksums and repair logs are retained privately at
`~/.local/state/homelab-maintenance/worker2-live-recovery-20261026/`.

## Linux diagnostic tests — 2026-10-26

Longhorn native replica eviction completed before leaving Talos: worker2 has
scheduling disabled, eviction requested, and zero replicas, engines or volume
attachments. Replica rebalancing temporarily filled worker1 below its kubelet
free-space threshold and caused node-pressure evictions/image garbage
collection. After the replacement Plex copy finished, an extra local copy was
removed, disk pressure cleared, essential images were warmed, and the evicted
Synology CSI DaemonSet pod was recreated. Database, NATS, Mimir and SeaweedFS
readiness was verified before GPU loading. Keep worker2 excluded from storage
placement throughout diagnosis.

SystemRescue 13.02 uses Linux 6.18.41-1-lts and AMD firmware package
20260622-1. Its loadable netconsole was configured after the Realtek NIC came
up. A real `/dev/kmsg` test packet was received by the Mac on UDP 6667 before
loading amdgpu. Independent SSH kernel capture and ping/SSH availability
sampling supplemented that kernel stream. Internal NVMe partitions remained
read-only and unmounted; no Kubernetes/application GPU workload was running.

The first Linux case used kexec to remove the recovery image's hard module
blacklist. At 22:10:24 UTC, manual `modprobe amdgpu modeset=1` loaded the driver
with default power settings and created `/dev/dri/renderD128`. Last successful
SSH/ping: 22:12:40 UTC; first failed sample: 22:12:45. The user reported a
frozen console; the final state of that first Linux session is unverified. Final
kernel packets were routine firewall drops, with no captured GPU fault or
panic. NMI/soft watchdog sysctls were enabled. The default keyboard SysRq mask
was 16, which did not allow debug dumps, so the unsuccessful keyboard attempt
is not independent proof of a completely locked kernel.

The cold-boot comparison began at 22:27:51 UTC after the user removed power
and booted the Samsung through firmware. Same Linux kernel, firmware and
amdgpu load parameters; keyboard SysRq debugging was explicitly enabled.
The edited command line contained `nomodeset,radeon` instead of `nomodeset`;
record this discrepancy. Automatic GPU loading was still prevented by
`modprobe.blacklist`, and the explicit driver `modeset=1` setting was retained.
The apparently healthy 11-minute checkpoint was superseded: last successful
SSH/ping was 22:41:47 UTC, first failed sample 22:41:52, about 14 minutes after
driver loading. Talos started a new kernel at 22:41:59 and finished its boot
sequence at 22:42:11. The user confirmed Talos appeared without a manual
restart. Talos returned with boot ID `e11e5ead-3147-4e2b-9adf-d4d5c4e54c0d`,
CPU-only, with no amdgpu/radeon module loaded. This case was an unexpected
platform reboot, not a still-running Linux session with lost SSH.

Linux's baseline boot reported previous reset reason `0x00200800` (ACPI power
state transition). After the failure, Talos reported `0x08000800`:
"an uncorrected error caused a data fabric sync flood event". The changed
flag supports a new fatal fabric reset. It does not identify the originating
component or distinguish a driver-triggered hardware error from a physical,
power or firmware problem. No final GPU fault, panic or stack was captured.
See [Linux AMD reset-reason documentation](https://docs.kernel.org/arch/x86/amd-debugging.html#random-reboot-issues).

Retained Talos logs show `kexecPrepare` before the failed 19:41 GPU boot. The
worker2-only `firmware-reboots` patch disables kernel kexec on the CPU-only
baseline; `/proc/sys/kernel/kexec_load_disabled` was verified as 1. Retain
this as a restart-path control, not a demonstrated GPU fix: the cold Linux
case also failed. Do not restore the Talos GPU extension based on that patch.
A [Talos maintainer documents the sysctl](https://github.com/siderolabs/talos/issues/13785).

A subsequent photo shows extensive green corruption in the firmware's boot
selection menu, before Linux or Talos starts. Earlier artifacts were visible
on responsive CPU-only Talos using the EFI framebuffer. Display corruption
therefore does not require the running amdgpu driver. Check the display cable,
input and another display before attributing it to the GPU or shared RAM.
The user subsequently unplugged and reconnected the same HDMI cable and the
picture became normal. This makes the display connection/negotiation a useful
lead for the artifacts but does not establish the cause of the fabric reset.
None of those components has been isolated as the cause. No BIOS flash,
voltage adjustment or memory test has been performed.

Both cold Linux baselines also contain one early-boot AMD-Vi
`INVALID_DEVICE_REQUEST` for `0000:00:01.4`, before manual amdgpu loading.
That function is absent from the current enumerated PCI tree, so it has not
been mapped to a device. Preserve this as unresolved firmware/IOMMU evidence;
its appearance before both trials does not establish that it caused the
later reset. Do not disable IOMMU or change BIOS settings during this
single-feature comparison.

A file comparison found 11 of 15 Renoir/Green Sardine firmware candidates were
identical between this Linux image and the failed Talos image; four differ.
This is not an inventory of the exact firmware requests made at runtime, and
neither the package date nor this comparison identifies the cause.

Raw evidence and per-boot records remain private under
`~/.local/state/homelab-maintenance/worker2-gpu-diagnostic-20261026/`.

## Next GPU investigation

Keep the node isolated. Before the next diagnostic shutdown, worker2 was
cordoned with the recovery taint, Longhorn scheduling disabled and eviction
requested, with zero replicas, engines and volume attachments and only
infrastructure DaemonSet pods. Recheck these conditions before every GPU test;
no attached application volumes alone is not sufficient. Establish actual
kernel-level capture before loading the driver. SystemRescue has loadable
`netconsole.ko`, so it can be configured after the Realtek NIC is up. Its
firmware package is
`linux-firmware-amdgpu 20260622-1`; the failed Talos image used
`amdgpu 20260916-v1.13.12`. These are useful comparison baselines, not a known fix.

The current recovery image uses `module_blacklist=amdgpu,radeon`, which also
blocks manual loading. A separate diagnostic boot must prevent automatic GPU
loading while permitting a deliberate load after actual kernel datagram
capture is verified. This can be a deliberate edit of the live USB boot
parameters without changing its default recovery entry; keep the internal NVMe
read-only and do not load the driver automatically. Start with a driver-only
test, then compare kernel and firmware baselines and vary one documented power-management setting at a time.
Earlier SMU/gfxoff reports make power management a hypothesis worth testing;
the latest retry captured successful SMU initialization and no final fault.
Do not enable application workloads or expand to another worker on that basis.

The user selected a shorter isolated GFXOFF comparison instead of a memory
test. The load is `modprobe amdgpu modeset=1 ppfeaturemask=0xfff73fff`:
this clears only `PP_GFXOFF_MASK` (`0x8000`) from the measured Linux default
`0xfff7bfff`; it does not disable all power management. Driver loading began
at 23:36:43 UTC on Linux boot `f12d20bf-6936-47da-b374-31622711e4dc`.
SMU and DRM initialized; the actual module mask was verified as `0xfff73fff`,
with cached `amdgpu_gfxoff=0` and hardware status 2. The isolated idle check
passed at 00:07:26 UTC on October 27 (19:07 CDT on October 26), 30 minutes
43 seconds after initialization: 361 post-initialization availability
samples had zero ping, SSH-port or SSH-command failures, and the boot ID
remained unchanged. No GPU fault or reset was captured. Final temperatures
were 37–47 C; renderD128 remained present, and internal NVMe partitions stayed
read-only and unmounted. Logs were snapshotted with SHA-256 hashes.

This is one passing idle comparison against one default cold run that reset
after about 14 minutes. It supports further GFXOFF investigation, not a
confirmed root cause or production acceptance. GPU load tests and a Talos
canary with the same setting have not been performed. Keep
the same Linux image, read-only/unmounted NVMe and verified capture; retain
`nomodeset` and `modprobe.blacklist=amdgpu,radeon`, changing only the hard
blacklist to `module_blacklist=radeon` for deliberate loading. Record the
previous command-line typo as a comparison limitation. Verify the actual
module mask and GPU state after loading, and observe for at least 30 minutes
before drawing even a preliminary conclusion. A pass would be evidence for
further testing, not proof of production stability or a Talos fix.

If a complete lock still prevents final messages, investigate a supported
hardware serial-console path or a separately built debug kernel with suitable
netconsole/persistent-crash support. The driver-only failure gives no evidence
that a Kubernetes upgrade or ROCm application change would fix this lockup.
See [Linux netconsole](https://docs.kernel.org/networking/netconsole.html) and
[amdgpu module parameters](https://docs.kernel.org/gpu/amdgpu/module-parameters.html).

## Earlier evidence and experiment — 2026-09-07

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
