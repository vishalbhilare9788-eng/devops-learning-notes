# My Learning Notes — Video-wise Log

This folder holds a **separate note file per video/topic**, in your own words as you dictate them
after watching. Keep this distinct from `../k8s-master-notes.md`, which is the polished reference
doc — I'll pull relevant detail from here into that master file when it strengthens a section.

## Naming convention
`NN-topic-name.md` — e.g. `01-pods-and-replicasets.md`, `02-deployments.md`

## How this works
1. Watch a video/topic.
2. Tell me what you learned (dictate, paste, or share a screenshot).
3. I create/update the matching file here with your raw notes, cleaned up but kept in your voice.
4. If it adds something new to the master notes (a command, gotcha, real example), I merge that
   into the matching section of `k8s-master-notes.md` too.
5. A polished, print-ready PDF version of each topic is generated into `PDF/` — same filename,
   `.pdf` instead of `.md`. That's the one to read/revise from; the `.md` is the working source.
6. Any screenshots you shared for that topic are bundled into their own gallery PDF in
   `Screenshots/` (`NN-topic-name-screenshots.pdf`) — one screenshot per page, in the order
   captured, for visual reference alongside the written notes.

### Note on screenshots
Windows saves your Snip/screenshot captures to `C:\Users\Lemnovo\Pictures\Screenshots\`. Rather
than trying to extract images from the chat itself (not reliably possible), I match the files
there by timestamp to whichever topic session you just described, and build the gallery PDF from
the real files. If a batch ever pulls in an unrelated screenshot (or misses one), just tell me and
I'll fix that topic's PDF.

## Log
| File | Topic | Date | Notes PDF | Screenshots PDF |
|---|---|---|---|---|
| [01-labels-and-running-pods.md](01-labels-and-running-pods.md) | Pod internals, multi-container pods, labels & selectors | 2026-09-10 | [PDF/01-labels-and-running-pods.pdf](PDF/01-labels-and-running-pods.pdf) | [Screenshots/01-labels-and-running-pods-screenshots.pdf](Screenshots/01-labels-and-running-pods-screenshots.pdf) (33 shots) |
| [02-quality-of-service.md](02-quality-of-service.md) | QoS classes (BestEffort/Burstable/Guaranteed), eviction order, OOMKill vs CPU throttling | 2026-09-10 | [PDF/02-quality-of-service.pdf](PDF/02-quality-of-service.pdf) | [Screenshots/02-quality-of-service-screenshots.pdf](Screenshots/02-quality-of-service-screenshots.pdf) (10 shots) |
| [03-production-access-and-rbac.md](03-production-access-and-rbac.md) | Jump-host cluster access, RBAC 2-step model, cert-based user onboarding (CSR→CA-signed crt), Role/RoleBinding, kubeconfig hand-off | 2026-09-11 | [PDF/03-production-access-and-rbac.pdf](PDF/03-production-access-and-rbac.pdf) | [Screenshots/03-production-access-and-rbac-screenshots.pdf](Screenshots/03-production-access-and-rbac-screenshots.pdf) (21 shots) |
| [04-replicaset-deployment-and-service.md](04-replicaset-deployment-and-service.md) | Singleton-pod problems, Deployment→ReplicaSet→Pod hierarchy, ZDD, Service selector/Endpoints label chain | 2026-09-11 | [PDF/04-replicaset-deployment-and-service.pdf](PDF/04-replicaset-deployment-and-service.pdf) | [Screenshots/04-replicaset-deployment-and-service-screenshots.pdf](Screenshots/04-replicaset-deployment-and-service-screenshots.pdf) (27 shots) |
| [05-namespace-quota-and-limitrange.md](05-namespace-quota-and-limitrange.md) | ResourceQuota (namespace totals), mandatory requests/limits once quota exists, LimitRange min/max/default/defaultRequest | 2026-09-11 | [PDF/05-namespace-quota-and-limitrange.pdf](PDF/05-namespace-quota-and-limitrange.pdf) | [Screenshots/05-namespace-quota-and-limitrange-screenshots.pdf](Screenshots/05-namespace-quota-and-limitrange-screenshots.pdf) (11 shots) |
| [06-scheduler-node-selector-affinity.md](06-scheduler-node-selector-affinity.md) | Scheduler internals (filter+score), node labeling, nodeName bypass, scheduling-time-only rule, Node/Pod Affinity & Anti-Affinity | 2026-09-14 | [PDF/06-scheduler-node-selector-affinity.pdf](PDF/06-scheduler-node-selector-affinity.pdf) | [Screenshots/06-scheduler-node-selector-affinity-screenshots.pdf](Screenshots/06-scheduler-node-selector-affinity-screenshots.pdf) (55 shots) |
| [07-taints-and-tolerations.md](07-taints-and-tolerations.md) | Taint=node/toleration=pod, key=value:policy syntax, control-plane's unmatchable taint, NoSchedule/PreferNoSchedule/NoExecute, tolerationSeconds grace period | 2026-09-16 | [PDF/07-taints-and-tolerations.pdf](PDF/07-taints-and-tolerations.pdf) | [Screenshots/07-taints-and-tolerations-screenshots.pdf](Screenshots/07-taints-and-tolerations-screenshots.pdf) (23 shots) |
| [08-secrets-and-configmaps.md](08-secrets-and-configmaps.md) | Secrets (base64-encoded not encrypted), 2-step create+inject, env var injection via secretKeyRef, ConfigMap for overriding a read-only image's config (httpd Listen 80 vs 81 per env) | 2026-09-18 | [PDF/08-secrets-and-configmaps.pdf](PDF/08-secrets-and-configmaps.pdf) | [Screenshots/08-secrets-and-configmaps-screenshots.pdf](Screenshots/08-secrets-and-configmaps-screenshots.pdf) (45 shots) |
| [09-persistent-volumes-pvc-storageclass.md](09-persistent-volumes-pvc-storageclass.md) | PV/PVC/StorageClass subsystem, access modes (RWX/ROX/RWO) + block-device sizing rule, static NFS provisioning end to end, dynamic provisioning via Helm nfs-subdir-external-provisioner | 2026-09-21 | [PDF/09-persistent-volumes-pvc-storageclass.pdf](PDF/09-persistent-volumes-pvc-storageclass.pdf) | [Screenshots/09-persistent-volumes-pvc-storageclass-screenshots.pdf](Screenshots/09-persistent-volumes-pvc-storageclass-screenshots.pdf) (92 shots) |
| [10-statefulsets-concepts.md](10-statefulsets-concepts.md) | Stateful vs stateless apps (session-data problem + shared-cache fix), primary/replica DB replication, ACID, StatefulSet naming + headless-Service DNS, first look at EKS control/data plane | 2026-09-22 | [PDF/10-statefulsets-concepts.pdf](PDF/10-statefulsets-concepts.pdf) | [Screenshots/10-statefulsets-concepts-screenshots.pdf](Screenshots/10-statefulsets-concepts-screenshots.pdf) (9 shots) |
| [11-containerd-container-runtimes-cri-oci.md](11-containerd-container-runtimes-cri-oci.md) | Container ≠ Docker (Colgate analogy), Docker as a car, `docker run nginx` end to end: docker CLI → dockerd → containerd (pull, network/storage, lifecycle) → shim → runc (namespaces + cgroups → process), high vs low-level runtimes (containerd/CRI-O vs runc/crun, Firecracker), why K8s dropped the Docker layer (dockershim removed 1.24), CRI (K8s gRPC API; rkt/containerd/CRI-O), OCI (image + runtime spec), CRI vs OCI table, `crictl`/`ctr`/`nerdctl`, `SystemdCgroup` | 2026-10-07 | [PDF/11-containerd-container-runtimes-cri-oci.pdf](PDF/11-containerd-container-runtimes-cri-oci.pdf) | [Screenshots/11-containerd-container-runtimes-cri-oci-screenshots.pdf](Screenshots/11-containerd-container-runtimes-cri-oci-screenshots.pdf) (7 shots) · Extra: [Containers-Decoded-Knowledge-Base.pdf](../Reference/Containers-Decoded-Knowledge-Base.pdf) (your own CRI + OCI one-pager) |
| [12-docker-internals-hands-on.md](12-docker-internals-hands-on.md) | Practical for Ch 11 on EC2 (AL2023): `yum install docker` pulls containerd + runc, docker.sock error = daemon down, dockerd flags (`-H fd://`, `--containerd=` socket), containerd sockets + CRI streaming port, `containerd-shim-runc-v2 -namespace moby -id`, runc exits after create, container = process (`docker kill` → process gone), `/proc/<pid>`, technohulk test (shim root = host root vs container's own root) | 2026-10-08 | [PDF/12-docker-internals-hands-on.pdf](PDF/12-docker-internals-hands-on.pdf) | [Screenshots/12-docker-internals-hands-on-screenshots.pdf](Screenshots/12-docker-internals-hands-on-screenshots.pdf) (32 shots) |
