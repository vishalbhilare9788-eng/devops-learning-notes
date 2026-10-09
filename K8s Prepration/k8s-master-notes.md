# Kubernetes Master Notes — Lead Infra/DevOps Interview & Production Prep

> **Living document.** Started as a self-contained study guide covering every core Kubernetes
> object. As you watch each CKA video / share screenshots, tell me the topic and what stood out —
> I'll fold new detail, corrections, and real examples into the matching section below instead of
> bolting on duplicate notes.

**Lab assumed for every practice task below:** kubeadm cluster on VMware VMs — `master`,
`worker-1`, `worker-2`. Swap node names if yours differ.

---

## Table of Contents
1. [How to Use These Notes / kubectl Basics](#1-how-to-use-these-notes--kubectl-basics)
2. [Cluster Architecture, Installation & Configuration](#2-cluster-architecture-installation--configuration)
3. [Namespaces & Resource Governance](#3-namespaces--resource-governance)
4. [Workloads (Pod-owning Objects)](#4-workloads-pod-owning-objects)
5. [Configuration & Secrets](#5-configuration--secrets)
6. [Scheduling & Autoscaling](#6-scheduling--autoscaling)
7. [Services & Networking](#7-services--networking)
8. [Storage](#8-storage)
9. [Security & RBAC](#9-security--rbac)
10. [Troubleshooting — Capstone Drills](#10-troubleshooting--capstone-drills)
11. [Lead/Manager-Level Operational Topics](#11-leadmanager-level-operational-topics)
12. [Quick-Reference Appendix](#12-quick-reference-appendix)

---

## 1. How to Use These Notes / kubectl Basics

**How the sections are structured:** every topic below follows the same shape —
📘 Theory → 🌍 Real-World Example → 🧾 YAML → ⚙️ Commands → 🛠 Practice Task (on your local cluster).
Read theory first, then *type the YAML yourself* (don't copy-paste) — that's what builds exam and
on-call muscle memory.

### kubectl productivity basics

```bash
# Set a short alias — you will type `kubectl` hundreds of times
alias k=kubectl
export do="--dry-run=client -o yaml"     # k run nginx --image=nginx $do > pod.yaml
export now="--force --grace-period=0"    # emergency pod deletion

# Generate YAML skeletons instead of memorizing schema
kubectl create deployment web --image=nginx $do > deploy.yaml
kubectl explain pod.spec.containers          # in-cluster docs for ANY field, any object
kubectl explain deployment.spec --recursive  # full field tree

# Discover what objects exist / their short names
kubectl api-resources
kubectl api-resources --namespaced=true
```

**Why `kubectl explain` + `--dry-run=client -o yaml` matter:** in the real exam and in real
incidents you rarely write YAML from scratch — you generate a skeleton imperatively, then edit
just the fields that matter. This is faster and less error-prone than memorizing every schema.

---

## 2. Cluster Architecture, Installation & Configuration

### 📘 Theory

Kubernetes has two logical halves:

- **Control plane** (the "brain," usually on `master`):
  - **kube-apiserver** — the only component that talks to etcd; front door for every kubectl
    command and every internal component. Stateless, horizontally scalable.
  - **etcd** — distributed key-value store; the *entire* cluster state lives here. If etcd is
    gone, the cluster's state is gone.
  - **kube-scheduler** — watches for unscheduled Pods, picks a node based on resource fit,
    affinity/anti-affinity, taints/tolerations.
  - **kube-controller-manager** — runs the reconciliation loops (node controller, replication
    controller, endpoint controller, etc.) that keep actual state matching desired state.
  - **cloud-controller-manager** — talks to cloud provider APIs (LB provisioning, node lifecycle) —
    not present in a bare kubeadm lab.
- **Node components** (on every node, including master in a kubeadm lab unless tainted):
  - **kubelet** — the agent that actually starts/stops containers per the PodSpecs it's told about;
    reports node/pod status back to the API server.
  - **kube-proxy** — programs iptables/IPVS rules so Service IPs route to the right Pod IPs.
  - **container runtime** — containerd (or CRI-O) — what actually pulls images and runs containers,
    talked to via the CRI (Container Runtime Interface).

**Static Pods** — kubelet on `master` watches `/etc/kubernetes/manifests/*.yaml` directly (no API
server needed) and runs whatever's there. This is *how the control plane bootstraps itself*:
kube-apiserver, etcd, scheduler, and controller-manager are themselves static pods. This is a
favorite exam/interview trick — "the API server is down, how do you fix it?" → SSH to master and
look at the static manifest, because kubectl won't work without the API server.

**HA control plane (production, not a single-master lab):**
- Run 3 (or 5) control-plane nodes behind a load balancer (or DNS round robin) for the API server.
- etcd: **stacked** (etcd runs alongside API server on each control-plane node — simpler, what
  kubeadm does by default) vs. **external** (etcd on its own dedicated nodes — more resilient,
  used by larger production clusters so etcd load/failure doesn't couple to control-plane nodes).
- etcd uses the **Raft consensus algorithm**, which needs a **quorum** (majority) to accept writes
  — this is why you run an *odd* number of etcd members (3 or 5): a 3-node etcd tolerates 1 failure,
  5-node tolerates 2, while a 4-node cluster tolerates only 1 (same as 3) but costs more. Never run
  an even count "for redundancy" — it doesn't buy you anything extra and adds cost.

### 🌍 Real-World Example
A mid-size production cluster: 3 control-plane nodes (stacked etcd) behind an internal load
balancer VIP, 6+ worker nodes for real workload capacity. Upgrades are done one control-plane node
at a time so the API server never has zero replicas. A common lead-level interview question: "why
not just run 1 control-plane node?" → single point of failure for the entire cluster's brain, even
though workloads on worker nodes would briefly keep running without it.

### 🧾 Key Files & Commands

```bash
# Where the control plane lives as static pods (on master)
ls /etc/kubernetes/manifests/
cat /etc/kubernetes/manifests/kube-apiserver.yaml

# kubelet config & logs (systemd service, NOT a pod — chicken/egg problem otherwise)
systemctl status kubelet
journalctl -u kubelet -f

# kubeadm bootstrap (once, on master)
kubeadm init --pod-network-cidr=192.168.0.0/16
mkdir -p $HOME/.kube && cp /etc/kubernetes/admin.conf $HOME/.kube/config

# Join a worker (token printed by kubeadm init, or regenerate it)
kubeadm token create --print-join-command
# run the printed `kubeadm join ...` command on worker-1 / worker-2

# etcd backup & restore (THE most exam-critical command set)
ETCDCTL_API=3 etcdctl snapshot save /tmp/snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

ETCDCTL_API=3 etcdctl snapshot restore /tmp/snapshot.db \
  --data-dir=/var/lib/etcd-restore

# Upgrade (control plane first, then each worker)
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.29.x-00
kubeadm upgrade plan
kubeadm upgrade apply v1.29.x
kubectl drain worker-1 --ignore-daemonsets
apt-get install -y kubelet=1.29.x-00 kubectl=1.29.x-00
systemctl restart kubelet
kubectl uncordon worker-1
```

### 🛠 Practice Tasks (local VMware cluster)

- [ ] **Break the API server on purpose:** on `master`, `mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/`. Confirm `kubectl get nodes` hangs/fails. Look at kubelet logs to see it stop the static pod. Move the file back and confirm recovery — time yourself.
- [ ] **etcd snapshot + restore drill:** take a live snapshot, then intentionally delete a namespace, restore etcd from the snapshot into a new data-dir, and confirm the deleted namespace is back (this requires re-pointing the etcd static pod manifest to the restored data-dir — research this step, it's a real exam task).
- [ ] **Break `kubeadm join`:** on `worker-2`, let its join token expire (or run join with a wrong token) and observe the failure; generate a fresh token/hash and rejoin successfully.
- [ ] **Cordon/drain/uncordon** `worker-1` while a Deployment with 4 replicas is running on it — watch pods reschedule to `worker-2`, then bring it back.

### Addendum: Container Runtimes — Docker vs containerd vs runc, CRI & OCI

**Container ≠ Docker.** A container is an isolated **Linux process**, made with namespaces for
isolation and cgroups for limits. Docker is just one product for building and running containers
(*"Colgate ≠ toothpaste"*).

**`docker run nginx` end to end:**
1. **docker CLI** sends the request over REST (`/var/run/docker.sock`) to **dockerd**, a background
   daemon. If it isn't running you get "Cannot connect to the Docker daemon".
2. dockerd calls **containerd** over gRPC. containerd is the **high-level runtime**: it pulls the
   image, prepares the snapshot/storage and network, and manages the container lifecycle. Docker
   created it and donated it to the CNCF.
3. containerd starts a **containerd-shim**, which runs **runc**, the **low-level runtime**. runc uses
   namespaces + cgroups to create the process, and then exits.
4. The shim stays as the parent, so restarting the daemons doesn't kill running containers.

**Runtimes.**
- High-level: **containerd**, **CRI-O** (Red Hat/OpenShift).
- Low-level (OCI): **runc**, **crun**, gVisor `runsc`, Kata.
- **Firecracker** (AWS Lambda/Fargate) is a microVM monitor, plugged in via `firecracker-containerd`.

**Kubernetes path:** kubelet → **CRI** (gRPC over a unix socket) → containerd/CRI-O → runc → Pod
containers.
- The Docker CLI and daemon are dropped as unnecessary CPU/memory overhead.
- **dockershim** was deprecated in 1.20 and **removed in 1.24**.
- Docker-built images still run because they're **OCI** images.

**CRI vs OCI.**
- **CRI** is a Kubernetes-defined gRPC API (RuntimeService + ImageService). It lets the kubelet talk
  to any compliant runtime: containerd, CRI-O, and historically rkt.
- **OCI** (Linux Foundation, 2015, started by Docker, CoreOS and others) defines the **image spec**,
  **runtime spec** and distribution spec. Any OCI image runs on any OCI runtime, and runc is the
  reference implementation.

**Node CLIs (no `docker` on a containerd node).**
- `crictl`: CRI-level, runtime-agnostic, the one to use for K8s debugging.
- `ctr`: ships with containerd, low-level, uses the `-n k8s.io` namespace.
- `nerdctl`: Docker-compatible CLI for containerd.

```bash
kubectl get nodes -o wide                         # CONTAINER-RUNTIME column (containerd://1.7.x)
systemctl status containerd; journalctl -u containerd -f
crictl pods; crictl ps; crictl images; crictl logs <id>; crictl exec -it <id> sh; crictl inspect <id>
ctr -n k8s.io containers ls; ctr -n k8s.io images ls
ps -ef | grep containerd-shim                     # each container = a process under a shim
containerd config default > /etc/containerd/config.toml   # then SystemdCgroup = true (match kubelet's systemd driver)
cat /etc/crictl.yaml                              # runtime-endpoint: unix:///run/containerd/containerd.sock
```

**Practice Tasks**
- [ ] On a worker, run `kubectl get nodes -o wide` and `crictl ps`, and match a Pod to its container ID. Then find its process with `ps -ef | grep containerd-shim`.
- [ ] Restart `containerd` and confirm the running Pods' containers survive (thanks to the shim).
- [ ] Pull and run nginx with `nerdctl`, then look for it in `ctr -n default containers ls` vs `-n k8s.io`, and explain the difference.
- [ ] Set `SystemdCgroup = false` on a lab node, restart, and observe the kubelet/Pod instability. Then revert it.
- [ ] Build an image with `docker build`, push it to a registry, and run it on the containerd cluster to prove OCI portability.
- [ ] Interview drill: explain "`docker run` end to end", "why K8s removed dockershim" and "CRI vs OCI" in 90 seconds.


### Addendum: Docker Internals Hands-On — Sockets, Shim & "Container = Process" (Lecture 12)

**Real-world proof on an EC2 (Amazon Linux 2023).**
- `yum install docker` pulls in **10 packages**: docker 20.10, **containerd** 1.6, **runc** 1.1,
  plus iptables/netfilter libs (networking), libcgroup and pigz. Docker isn't one binary.
- `docker ps` before starting the daemon fails with `Cannot connect to the Docker daemon at
  unix:///var/run/docker.sock`. The CLI is only a client of that **Unix (IPC) socket**.
- `systemctl start docker` brings up **two** processes, `containerd` and then `dockerd`.

**Reading the dockerd command line** (`systemctl status docker` → CGroup):
`/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock`
- `-H fd://` means: listen on the socket that **systemd** created and handed over (`TriggeredBy:
  docker.socket`), not on a network port.
- `--containerd=` is the next hop: dockerd → containerd over **gRPC on
  `/run/containerd/containerd.sock`**.
- containerd serves `containerd.sock` (gRPC) and `containerd.sock.ttrpc` (used with the shims). Its
  `127.0.0.1:<random>` TCP port in `ss -tnlp` is the CRI **streaming server** (exec/attach/port-forward).

**Running `docker run -itd nginx` adds per-container processes:**
```
containerd-shim-runc-v2 -namespace moby -id <full container ID> -address /run/containerd/containerd.sock
 └─ nginx: master process (root)  └─ nginx: worker process (uid 101)
```
- The shim runs `runc`. runc creates the process and **exits**, so it is never seen in `ps`.
- `moby` is the **containerd namespace** Docker uses (K8s uses `k8s.io`, `ctr` uses `default`). It
  is not a Linux namespace.
- `docker kill <id>` makes the shim and the nginx processes disappear. **Container = process.**

**`/proc` gotcha.** `/proc/<shim-pid>/root` is the **host's** `/`, because the shim is a host
process. A file touched there shows up in the host `/tmp`. The container's own filesystem is at
`/proc/<container-pid>/root`, using the PID from `docker inspect -f '{{.State.Pid}}' <id>`. Its own
mount namespace and overlay2 layers mean a file written there is **not** in the host `/tmp`. The
container shares the **kernel** and gets CPU/memory via **cgroups**. It does not share the host's
filesystem.

```bash
systemctl enable --now docker                 # status shows "disabled" by default on AL2023
ss -tnlp; ss -xlp | grep -E 'docker|containerd'
ps -ef --forest | grep -A2 containerd-shim
docker inspect -f '{{.State.Pid}}' <id>
ls -l /proc/<shim-pid>/ns /proc/<container-pid>/ns /proc/1/ns   # compare namespace inodes
ls /proc/<container-pid>/root/etc/nginx
ctr -n moby containers ls; ctr -n moby tasks ls
```

**Practice Tasks**
- [ ] Fresh EC2: `yum install docker` and name every dependency and its role. Hit the
  docker.sock error, start the daemon, then `enable` it and reboot to prove it survives.
- [ ] From `systemctl status docker`, explain every flag of the dockerd command line (`-H fd://`,
  `--containerd=`, `--default-ulimit`).
- [ ] Run nginx, draw the process tree (shim → master → worker), and explain why there is no
  `runc` process.
- [ ] Repeat the `technohulk` test twice, via the shim PID and via the nginx PID, and explain why one
  file lands in the host `/tmp` and the other doesn't.
- [ ] `systemctl restart containerd` while nginx runs and confirm the container survives (the shim).
- [ ] Find Docker's container with `ctr -n moby tasks ls` and match its PID to `docker inspect`.


---

## 3. Namespaces & Resource Governance

### 📘 Theory
- **Namespace** — a virtual cluster within a cluster; scopes names, RBAC, quotas. Cluster-scoped
  objects (Nodes, PersistentVolumes, ClusterRoles, Namespaces themselves) don't live in a namespace.
- **ResourceQuota** — caps total resource consumption (CPU/mem/object counts) *per namespace*.
- **LimitRange** — sets default/min/max requests & limits *per container/pod* within a namespace,
  so a pod without explicit requests doesn't silently become unbounded.
- **PriorityClass** — assigns scheduling priority; higher-priority pending pods can **preempt**
  (evict) lower-priority running pods when the cluster is full.

### 🌍 Real-World Example
A platform team gives each product team its own namespace with a ResourceQuota (e.g. 20 CPU / 40Gi
mem cap) and a default LimitRange so a developer who forgets to set `resources:` doesn't
accidentally schedule an unbounded pod that starves the node. `system-cluster-critical`-style
PriorityClasses protect platform components (CoreDNS, CNI) from being evicted under pressure.

### 🧾 YAML

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: team-a-defaults
  namespace: team-a
spec:
  limits:
    - default: { cpu: 500m, memory: 256Mi }        # applied if container omits limits
      defaultRequest: { cpu: 250m, memory: 128Mi }  # applied if container omits requests
      type: Container
```

### ⚙️ Commands

| Action | Command |
|---|---|
| Create namespace | `kubectl create namespace team-a` |
| List quota usage | `kubectl describe resourcequota team-a-quota -n team-a` |
| List all resources in ns | `kubectl get all -n team-a` |
| Set default namespace for context | `kubectl config set-context --current --namespace=team-a` |

### 🛠 Practice Tasks
- [ ] Apply the quota above to a namespace, then try to create a Deployment with 5 replicas at 3 CPU requests each — watch it get rejected once the quota is exceeded, and read the exact error message.
- [ ] Create a Pod **without** a `resources:` block in a namespace with the LimitRange above — confirm via `kubectl describe pod` that the defaults were injected automatically.

### Addendum: Quota + LimitRange Mechanics, Live

**⚠️ The moment a ResourceQuota exists, requests/limits become mandatory:** Kubernetes can't count
usage against a quota if it doesn't know how much a pod is asking for. A pod with no `resources:`
block gets rejected outright:
```bash
kubectl create quota dev-quota --hard=cpu=2,memory=3G,pods=5,services=3 -n dev
# resourcequota/dev-quota created

kubectl create -f mypod.yaml
# Error from server (Forbidden): pods "webapp" is forbidden:
# failed quota: dev-quota: must specify cpu for: nginx; memory for: nginx
```

**🌍 Quota enforcement on a Deployment's ReplicaSet, live:** deploying more replicas than a
namespace's `pods` quota allows doesn't just silently cap the count — the Deployment shows
`ReplicaFailure: True (FailedCreate)` and the ReplicaSet's events name the exact numbers:
```
Warning FailedCreate  replicaset-controller  Error creating: pods "nginx-deployment-...-zp56v" is
forbidden: exceeded quota: dev-quota, requested: pods=1, used: pods=5, limited: pods=5
```

**📘 The gap ResourceQuota alone leaves:** with quota `cpu=2, memory=3G, pods=5`, a *single* pod
requesting `memory=2G, cpu=1` succeeds — it's within the total. But that one pod just consumed most
of the namespace's entire budget, starving everything else in it. ResourceQuota caps the *total*;
it says nothing about how much any *one* pod may hog. That's exactly the gap LimitRange closes —
per-container min/max/default bounds, not just a namespace-wide ceiling.

**How the 4 LimitRange values apply, precisely:**

| Field | Effect |
|---|---|
| `min` | Floor — requesting *below* this in `resources.requests` is denied outright |
| `max` | Ceiling — requesting *above* this in `resources.limits` is denied outright |
| `default` | Used as the container's **limit** if the Pod YAML's `resources` block omits `limits` |
| `defaultRequest` | Used as the container's **request** if the Pod YAML's `resources` block omits `requests` |

If the Pod YAML has **no `resources:` block at all**, `default`/`defaultRequest` apply
automatically — you never get "unbounded" just because you left it out.

**Proof — a request below the minimum is denied by name:**
```bash
kubectl create -f mypod.yaml
# Error from server (Forbidden): pods "webapp" is forbidden:
# [minimum memory usage per Container is 90Mi, but request is 80Mi,
#  minimum cpu usage per Container is 100m, but request is 50m]
```

> **The idea behind LimitRange: no single application should be able to dominate the
> infrastructure.** ResourceQuota protects the namespace's total budget; LimitRange protects that
> budget from being monopolized by any one pod inside it — complementary controls, not alternatives.

**🛠 Practice Tasks (Quota + LimitRange mechanics):**
- [ ] Apply a ResourceQuota to a namespace, then try creating a pod with no `resources:` block — confirm the exact `must specify cpu/memory for` error, then fix it and watch `Used` update in `kubectl describe ns`.
- [ ] Deploy more replicas than the quota's `pods` cap allows and read the ReplicaSet's `FailedCreate` events end to end — don't just note it failed, read the exact requested/used/limited numbers printed.
- [ ] Request a single pod's resources close to the *entire* namespace quota and confirm it succeeds — demonstrating why ResourceQuota alone doesn't prevent one pod from starving the rest of the namespace.
- [ ] Apply a LimitRange with distinct `min`/`max`/`default`/`defaultRequest` values, then test all 3 cases separately: a pod with no `resources:` block (defaults apply), a pod requesting below `min` (denied), and a pod requesting above `max` (denied) — confirm each behaves exactly as the table above predicts.

---

## 4. Workloads (Pod-owning Objects)

### 📘 Theory — pick the right controller

| Object | Use when | Key trait |
|---|---|---|
| **Pod** | Rarely created directly | Smallest deployable unit; ephemeral, no self-healing alone |
| **ReplicaSet** | Almost never created directly | Keeps N pod replicas alive by label selector; Deployments manage RS for you |
| **Deployment** | Stateless apps (APIs, web frontends) | Rolling updates/rollbacks, declarative desired state |
| **StatefulSet** | Databases, queues, anything needing stable identity | Stable network ID (`pod-0`, `pod-1`...) + stable storage (PVC per pod) + ordered start/stop |
| **DaemonSet** | Node-level agents | Exactly one pod per (matching) node — log shippers, CNI, monitoring agents |
| **Job** | Run-to-completion batch work | Tracks completions, retries failures, then stops |
| **CronJob** | Scheduled batch work | Creates a Job on a cron schedule |

**Why StatefulSet ≠ Deployment for a database:** a Deployment's pods are interchangeable and get
random names/IPs on restart — fine for stateless apps behind a Service, wrong for a database
replica that needs to always come back as "the same member" with its own disk. StatefulSet gives
predictable names (`db-0`, `db-1`) and a stable PVC bound to each ordinal, so `db-0` always gets
back its own volume.

### 🌍 Real-World Examples
- **Deployment**: a stateless REST API — 5 replicas, rolling update from v1→v2 with zero downtime.
- **StatefulSet**: a 3-node Postgres/Kafka cluster — each pod needs its own disk and a stable
  hostname other members connect to.
- **DaemonSet**: Fluentd/Filebeat log collector, or Prometheus `node-exporter` — must run on
  *every* node to scrape/ship local data.
- **Job**: a one-off DB migration script run during a deploy.
- **CronJob**: nightly backup job at 2 AM, or a cleanup job pruning old data every hour.

### 🧾 YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector: { matchLabels: { app: web } }
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxUnavailable: 1, maxSurge: 1 }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
        - name: web
          image: nginx:1.25
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits: { cpu: 250m, memory: 256Mi }
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: db-headless      # must point to a Headless Service — gives stable DNS per pod
  replicas: 3
  selector: { matchLabels: { app: db } }
  template:
    metadata: { labels: { app: db } }
    spec:
      containers:
        - name: db
          image: postgres:16
          volumeMounts: [{ name: data, mountPath: /var/lib/postgresql/data }]
  volumeClaimTemplates:                 # one PVC PER POD, auto-created (db-data-db-0, -1, -2)
    - metadata: { name: data }
      spec:
        accessModes: [ReadWriteOnce]
        resources: { requests: { storage: 5Gi } }
---
apiVersion: apps/v1
kind: DaemonSet
metadata: { name: node-exporter }
spec:
  selector: { matchLabels: { app: node-exporter } }
  template:
    metadata: { labels: { app: node-exporter } }
    spec:
      containers: [{ name: node-exporter, image: prom/node-exporter }]
---
apiVersion: batch/v1
kind: CronJob
metadata: { name: nightly-backup }
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      backoffLimit: 3
      template:
        spec:
          restartPolicy: OnFailure
          containers: [{ name: backup, image: backup-tool:latest }]
```

### ⚙️ Commands

| Action | Command |
|---|---|
| Scale | `kubectl scale deployment/web --replicas=5` |
| Rollout status | `kubectl rollout status deployment/web` |
| Rollout history | `kubectl rollout history deployment/web` |
| Rollback | `kubectl rollout undo deployment/web --to-revision=2` |
| Trigger new rollout (image bump) | `kubectl set image deployment/web web=nginx:1.26` |
| Pause/resume rollout | `kubectl rollout pause/resume deployment/web` |
| Restart pods (config picked up) | `kubectl rollout restart deployment/web` |
| Run a Job now from a CronJob | `kubectl create job manual-run --from=cronjob/nightly-backup` |

### 🛠 Practice Tasks
- [ ] Deploy `web` above, then `kubectl set image` to a **nonexistent tag** — watch the rollout stall (`kubectl rollout status` hangs), diagnose with `kubectl describe rs` (old + new ReplicaSet both present), then `kubectl rollout undo`.
- [ ] Deploy the 3-replica StatefulSet + a headless Service; `kubectl delete pod db-1`; confirm it comes back as `db-1` (not a new random name) with the *same* PVC reattached.
- [ ] Deploy the DaemonSet, then `kubectl cordon worker-2` and confirm the DaemonSet pod still runs there (DaemonSets tolerate scheduling differently — investigate why).
- [ ] Write a CronJob with a deliberately broken image name, watch Job failures accumulate up to `backoffLimit`, and diagnose via `kubectl get jobs` + `kubectl logs job/<name>`.

### Addendum: Pod Internals, Multi-Container Pods & Labels

**📘 Pod = wrapper around container(s):** the app runs inside a *container*; the container sits
inside a *Pod*, Kubernetes' atomic unit. **IP** and **Volume** are assigned at the **Pod** level
(shared by every container in it); **CPU/memory** requests & limits are set per **container**.
YAML is indentation-sensitive — tabs are invalid, 2 spaces = one indent level. Creating from a file
(`kubectl create -f pod.yaml`) is declarative IaC — keep it in Git so it's reusable/reviewable,
unlike a one-off imperative `docker run`/`kubectl run` with nothing left to refer back to. Which
node a Pod lands on is the **scheduler's** decision (see §6).

**⚠️ Gotcha:** `kubectl delete -f file.yaml` deletes **every object defined in that file** — if
it holds 2 pods, both go. Always check a manifest's contents before running delete against it.

**📘 Multi-container Pods:** one Pod can run several containers (e.g. `nginx` + `redis` sidecar)
sharing the Pod's IP/network namespace. `kubectl get pods` shows `READY 2/2` for pod-level
readiness — there's no `kubectl get containers`, the Pod is the atomic unit. `kubectl describe
pod` shows scheduling **events**, not application health — use logs for that. `kubectl logs <pod>`
on a multi-container pod defaults to the **first container in the YAML**
(`Defaulted container "nginx" out of: nginx, redis`); get another one with
`kubectl logs <pod> -c <container-name>`.

```yaml
apiVersion: v1
kind: Pod
metadata: { name: webserver }
spec:
  containers:
    - name: nginx
      image: nginx:1.14.2
      ports: [{ containerPort: 80 }]
    - name: redis
      image: redis
```

**📘 Labels & Selectors:** key/value pairs under `metadata.labels`, added deliberately (nothing is
labeled by default). Their real value is **filtering, sorting, and bulk actions** across many
objects — e.g. "delete every pod for this client" — not just documentation. Kubernetes'
**6 recommended labels** (an optional domain prefix like `abc.com/` avoids collisions with
other label sets):

| Label | Meaning |
|---|---|
| `.../name` | App name |
| `.../managed-by` | What manages it (`helm`, `manual`, ...) |
| `.../version` | Version |
| `.../component` | Role in the architecture (`frontend`/`backend`) |
| `.../part-of` | The higher-level app this belongs to |
| `.../instance` | Unique instance id |

*Multi-tier example:* app `webserver` has `frontend` (Apache) + `backend` (MySQL/Redis) — both
carry `part-of: webserver` (ties them together) but differ on `component: frontend` vs `backend`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  labels:
    abc.com/name: nginx
    abc.com/managed-by: manual
    abc.com/version: "1"
    abc.com/component: frontend
    abc.com/part-of: webserver
    abc.com/instance: august
spec:
  containers:
    - name: nginx
      image: nginx:1.14.2
      ports: [{ containerPort: 80 }]
```

| Action | Command |
|---|---|
| Logs of default (first) container | `kubectl logs <pod>` |
| Logs of a specific container | `kubectl logs <pod> -c <container-name>` |
| Show labels as columns | `kubectl get pods -L app -L client -L env` |
| Show all labels | `kubectl get pods --show-labels` |
| Filter by one label | `kubectl get pods -l "client=xyz"` |
| Filter: AND (comma = AND) | `kubectl get pods -l "app=nginx,env=prod"` |
| Filter: NOT equal | `kubectl get pods -l "app=apache,client!=abc"` |
| Filter: IN a set (OR) | `kubectl get pods -l "app in (apache,nginx)"` |
| Bulk-delete by label | `kubectl delete pod -l "client=xyz"` |

**🛠 Practice Tasks (labels & multi-container):**
- [ ] Create a multi-container pod (nginx + redis), confirm `2/2` ready, compare `kubectl logs <pod>` (defaults to nginx) vs `kubectl logs <pod> -c redis`.
- [ ] Put 2 pods in one YAML file, `kubectl delete -f` it, confirm **both** disappear — internalize the blast radius before running delete against a shared manifest.
- [ ] Label pods across 2 clients/environments; practice `--show-labels`, `-L`, comma-AND filters, and `in (...)` filters — predict the output before running each command.
- [ ] Apply the 6 recommended labels to a `frontend` + `backend` pair sharing `part-of: webserver`; filter with `kubectl get pods -l "abc.com/part-of=webserver"` and confirm both return.
- [ ] Bulk-delete all pods for one client with `kubectl delete pod -l "client=<name>"` and confirm only that client's pods are removed.

### Addendum: Why Not Run Naked Pods — Deployment → ReplicaSet → Pod Hierarchy

**📘 The singleton-pod problem:** a bare Pod running a business app has 3 real production gaps —
**no self-healing** (deleted/terminated pod just stays gone), **no scaling** (traffic past what its
`requests`/`limits` allow just breaks — nothing spins up more capacity), and **no zero-downtime
upgrade/rollback** (bumping the image means taking the pod down, with no built-in way back).
Conclusion: enterprise apps are never deployed as bare Pods.

**📘 The real chain:** `Deployment → creates → ReplicaSet → creates → Pod(s)`. You're still
ultimately running Pods — just never directly. Each layer earns its place: **ReplicaSet** gives
self-healing + scaling (manual or automatic replica count); **Deployment** adds **zero-downtime
deployment (ZDD)** — rolling upgrade/rollback — on top of that.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels: { app: nginx }        # Deployment's own label — cosmetic, can be anything
spec:
  replicas: 3
  selector:
    matchLabels: { app: nginx }  # which pods (by label) this ReplicaSet is responsible for
  template:
    metadata:
      labels: { app: nginx }     # MUST MATCH selector.matchLabels above
    spec:
      containers:
        - name: nginx
          image: nginx:1.14.2
          ports: [{ containerPort: 80 }]
```

**⚠️ The rule that matters most:** the Deployment's own top-level label is not load-bearing — but
`spec.template.metadata.labels` (the Pod template's label) **must match**
`spec.selector.matchLabels` (the ReplicaSet's selector), or the ReplicaSet doesn't know which pods
are its own.

**Naming hierarchy — how you trace the chain in a cluster with many deployments:** the Deployment
name prefixes the ReplicaSet name (`nginx-deployment-6fb4f44f88`), and the ReplicaSet name prefixes
the Pod name (`nginx-deployment-6fb4f44f88-66phw`) — so a bare Pod name alone tells you exactly
which ReplicaSet and Deployment it belongs to.

**🌍 Self-healing, concretely:** delete a ReplicaSet-owned pod and the ReplicaSet immediately
creates a replacement to restore the desired count — but the **new pod gets a brand-new IP**, never
the old one. This is exactly why nothing should ever talk to a pod by IP directly — see the Service
addendum in §7 for how that problem actually gets solved.

**🛠 Practice Tasks (Deployment/ReplicaSet hierarchy):**
- [ ] Run a bare single Pod, delete it, and confirm `kubectl get pods` shows nothing recreated it — make the "no self-healing" gap concrete, not theoretical.
- [ ] Deploy the YAML above, then run `kubectl get deploy`, `kubectl get rs`, `kubectl get pods` back to back and read the full 3-tier naming hierarchy off the output.
- [ ] Delete one ReplicaSet-owned pod and confirm both self-healing (new pod appears) and the new-IP behavior via `kubectl get pods -o wide` before and after.
- [ ] Deliberately break the label match — change `spec.template.metadata.labels` so it no longer matches `spec.selector.matchLabels` — apply it, and observe the Deployment/ReplicaSet controller reject or misbehave; fix it and confirm recovery.

### Addendum: StatefulSets — Deep Dive (Stateful vs. Stateless, ACID, Headless-Service DNS)

**📘 A "frontend" tier can still be stateful:** stateful just means *behavior depends on data the
component itself holds* — it doesn't have to be the database. A Web Tier pod that keeps session
data (user's currency, dark-mode preference, browsing history) in **its own local storage** is
effectively stateful: if that pod dies, a replacement pod knows nothing about the user, breaking
the experience. **The fix is never "make the pod stateful" — it's externalizing that state** (e.g.
to Amazon ElastiCache or Redis) so *any* pod can serve the next request identically. Once that's
done, both the Web and Application tiers become genuinely stateless `Deployment`s; only the Data
Tier remains truly stateful.

**🌍 Primary/replica replication, and why it exists for two separate reasons:**
- **Performance** — writes go only to the primary; reads get offloaded to replicas, scaling far
  better under concurrency than one node serving everything.
- **High availability** — if the primary fails, a replica is promoted to primary, keeping downtime
  minimal.

Setting up a replica is 2 stages: **Initial Cloning** (copy existing data to the new replica —
often cascading, replica-to-replica) and **Continuous Replication** (keep syncing every future
write from the primary going forward).

**📘 ACID — what a plain Deployment can't protect for a database:**
| Letter | Guarantee |
|---|---|
| Atomicity | Transaction is all-or-nothing, never left half-done |
| Consistency | Every transaction moves the DB from one valid state to another |
| Isolation | Concurrent transactions don't corrupt each other's view of the data |
| Durability | Once committed, a change survives even a crash |

A Deployment can't guarantee *which* pod comes back after a failure, *which* disk it reattaches to,
or *what order* replicas start in — and all three are load-bearing for keeping replication (and
therefore ACID across the cluster) intact. This is precisely the gap StatefulSet closes: **stable
pod naming**, **stable network identity**, **ordered start/stop**
(`db-0 → db-1 → db-2` up, reverse order down), and **PV re-attachment** (`db-1` always gets back
*its own* volume, never a blank one or someone else's).

**⚙️ Why block storage + `RWO`/`RWOP` specifically:** databases need high IOPS/low latency, a
volume that is **never shared across pods**, and disk-backed writes for transactional consistency —
`ReadWriteOncePod` is stricter than plain `ReadWriteOnce`: it guarantees the volume is mounted by
**at most one specific pod**, not just one node.

**🌍 The headless-Service DNS mechanism, in full:**
```
mysql-0     .   mysql          .   mysql-ha    . svc.cluster.local
<pod-name>      <headless-svc>     <namespace>    (K8s service domain)
```
- `mysql-0` alone → **not resolvable**. `mysql-0.mysql.mysql-ha.svc.cluster.local` → **resolvable**.
- **CoreDNS only generates a per-pod A record when the pod is exposed through a headless Service**
  (`clusterIP: None`) sharing the StatefulSet's name — there is no other path to a stable, addressable
  per-pod DNS name.
- **A regular ClusterIP Service won't substitute** — it load-balances across backing pods, which
  breaks the deterministic routing (address *this specific replica*) that clustering, replication,
  and leader election all depend on.
- Hardcoding pod names in application config doesn't work either — the name (`mysql-0`) exists, but
  it's still not resolvable on its own without the headless Service in front of it.

**🛠 Practice Tasks (StatefulSets deep dive):**
- [ ] Force a Web-Tier pod holding local session data to restart mid-session, and observe the user-facing failure directly — then swap in a shared cache and confirm a killed pod no longer loses session state.
- [ ] Given a 4-replica StatefulSet, write out the exact startup and (reverse) termination order from memory, then verify it against `kubectl get pods -w` while scaling up and down.
- [ ] Create a headless Service + StatefulSet pair, then from a debug pod try resolving the bare pod name vs. the full `<pod>.<svc>.<ns>.svc.cluster.local` form — confirm only the latter resolves.
- [ ] Swap the headless Service for a ClusterIP Service against the same StatefulSet and observe why per-pod DNS resolution stops working.

---

## 5. Configuration & Secrets

### 📘 Theory
- **ConfigMap** — non-sensitive config as key/value pairs, injected as env vars or mounted as files.
- **Secret** — same idea for sensitive data; base64-**encoded** (not encrypted at rest by default —
  a common interview gotcha: "is a Secret secure by default?" → No, enable etcd encryption-at-rest
  and/or an external secret manager for real security).
- **Env var vs. volume mount:** env vars are simple but static (pod restart needed to pick up
  changes); a mounted ConfigMap/Secret **file updates live** in the pod (kubelet syncs it,
  typically within ~60s) without a restart — important for apps that hot-reload config.

### 🌍 Real-World Example
12-factor app pattern: DB host/port as ConfigMap env vars, DB password as a Secret mounted as a
file and read by the app at startup. Secret rotation: update the Secret, and any app that re-reads
the mounted file (not an env var captured at boot) picks up the new value without a restart.

### 🧾 YAML

```yaml
apiVersion: v1
kind: ConfigMap
metadata: { name: app-config }
data:
  DB_HOST: "db-headless"
  DB_PORT: "5432"
---
apiVersion: v1
kind: Secret
metadata: { name: app-secret }
type: Opaque
stringData:                 # stringData = plaintext in YAML, kubectl base64-encodes it for you
  DB_PASSWORD: "S3cret!"
---
apiVersion: v1
kind: Pod
metadata: { name: app }
spec:
  containers:
    - name: app
      image: myapp:latest
      envFrom:
        - configMapRef: { name: app-config }
      env:
        - name: DB_PASSWORD
          valueFrom: { secretKeyRef: { name: app-secret, key: DB_PASSWORD } }
      volumeMounts:
        - name: secret-vol
          mountPath: /etc/secrets
          readOnly: true
  volumes:
    - name: secret-vol
      secret: { secretName: app-secret }
```

### ⚙️ Commands

| Action | Command |
|---|---|
| Imperative ConfigMap from literals | `kubectl create configmap app-config --from-literal=DB_HOST=db` |
| ConfigMap from a file | `kubectl create configmap app-config --from-file=app.properties` |
| Imperative Secret | `kubectl create secret generic app-secret --from-literal=DB_PASSWORD=S3cret!` |
| Decode a secret value | `kubectl get secret app-secret -o jsonpath='{.data.DB_PASSWORD}' \| base64 -d` |

### 🛠 Practice Tasks
- [ ] Mount `app-config` as env vars in a pod; `kubectl edit configmap` and change a value; confirm the running pod's env var **doesn't** change (restart required) — this is the gotcha to internalize.
- [ ] Redo it as a **volume mount** instead; edit the ConfigMap again; `exec` into the pod and `cat` the mounted file — confirm it updates live within ~60 seconds, no restart.
- [ ] Intentionally reference a Secret key that doesn't exist (`secretKeyRef` typo) — watch the Pod stay in `CreateContainerConfigError` and diagnose via `kubectl describe pod`.

### Addendum: Secrets & ConfigMaps — Deep Dive

**⚠️ Encoded ≠ Encrypted (recurring interview gotcha):** encoding is reversible by design — anyone
who can `kubectl get secret -o yaml` a Secret can `base64 --decode` it straight back to plaintext
in one command. Kubernetes Secrets are **only base64-encoded**, never encrypted at rest by
default. The real access boundary is **RBAC** (who is allowed to `get`/`describe` the Secret or
`exec` into a Pod that consumes it) — not the encoding itself. Enable etcd encryption-at-rest
and/or an external secret manager (Vault, AWS/GCP Secrets Manager) for genuine protection.

```bash
# The 2-step Secret workflow: create, then inject
kubectl create secret generic myuser --from-literal username=alok --from-literal password=sunday
kubectl get secrets myuser -o yaml          # shows base64 values (data.username, data.password)
kubectl describe secret myuser              # shows only byte counts — never the value itself
echo YWxvaw== | base64 --decode             # alok  <- trivially reversible
```
`describe` deliberately hides values; `-o yaml`/`-o json` do not — that distinction alone is a
common quiz question.

**⚙️ Why ConfigMaps exist — the read-only-image problem:** once a Docker image is built, it is
**read-only**; you cannot reach into it later and permanently change what's baked in. A ConfigMap
lets you override an already-built image's runtime config at container-start time, without ever
rebuilding the image.

**Worked scenario:** an `httpd` image is built with `EXPOSE 80 81`, but the baked-in
`/etc/httpd/conf/httpd.conf` still has the RPM's default `Listen 80`. Prod wants port 80 (works
immediately, no changes needed) — Dev wants the *same image* on port 81. Rebuilding a
Dev-only image just to flip one config line defeats the point of a shared image, so instead:

```bash
# 1. Take a local copy of httpd.conf, change "Listen 80" -> "Listen 81"
# 2. Turn it into a ConfigMap
kubectl create configmap devweb --from-file=httpd.conf
```
```yaml
# Mount it over the config directory in the Dev Pod only — Prod Pod stays untouched
spec:
  containers:
    - name: mypod
      image: lovelearnlinux/customweb:v1     # <- identical image used by Prod
      volumeMounts:
        - name: webroot
          mountPath: "/etc/httpd/conf/"
          readOnly: true
  volumes:
    - name: webroot
      configMap: { name: devweb }
```
Result: **one image, two Pods, two different effective ports** — Prod's Pod IP answers on `:80`
(untouched default config), Dev's Pod IP refuses `:80` but answers on `:81` (ConfigMap-overridden
`Listen 81`), provable with `curl` against each Pod IP and confirmed by `cat`-ing the mounted
`httpd.conf` from inside the Dev Pod itself. This is the general pattern for **any** per-environment
config drift (ports, feature flags, connection strings) against a single shared, immutable image.

---

## 6. Scheduling & Autoscaling

### 📘 Theory
- **Requests vs. Limits:** *requests* = what the scheduler reserves on a node (guaranteed);
  *limits* = the hard ceiling (CPU gets throttled past it, memory gets the container **OOMKilled**
  past it). This distinction is one of the most-asked interview questions.
- **QoS classes** (derived automatically, not set directly) — `Guaranteed` (requests == limits,
  last evicted), `Burstable` (requests < limits, evicted before Guaranteed), `BestEffort` (no
  requests/limits, evicted first). Full breakdown — eviction order, OOMKill-vs-throttle, pod IP
  behavior — in the addendum at the end of this section.
- **Probes:**
  - `livenessProbe` — fails → kubelet **restarts** the container.
  - `readinessProbe` — fails → pod is pulled **out of Service endpoints** (traffic stops routing
    to it) but the container is *not* restarted.
  - `startupProbe` — protects slow-starting apps from being killed by liveness before they're
    even up; liveness/readiness only start after startup succeeds.
- **Node affinity/anti-affinity** — soft (`preferred...`) or hard (`required...`) rules to
  attract/repel pods based on node labels.
- **Taints & tolerations** — the opposite direction: the **node** repels pods (`kubectl taint`)
  unless the pod explicitly **tolerates** that taint. Affinity = pod chooses node; taint = node
  filters pods. `NoSchedule` / `PreferNoSchedule` / `NoExecute` (the last also evicts already-running
  non-tolerating pods).
- **HPA (HorizontalPodAutoscaler)** — scales replica **count** based on metrics (CPU/mem or custom),
  requires `metrics-server` installed. **VPA** adjusts a pod's requests/limits instead of replica
  count (less commonly used live in the same cluster as HPA on the same metric — can fight each
  other). **Cluster Autoscaler** adds/removes **nodes** based on unschedulable pods — a different
  layer entirely (cloud-provider integration).

### 🌍 Real-World Example
GPU nodes are tainted `nvidia.com/gpu=true:NoSchedule` so only ML workloads (which tolerate that
taint) land there — regular web pods never accidentally consume expensive GPU nodes. A web tier
Deployment has an HPA target of 60% CPU; under a traffic spike it scales from 3→10 replicas
automatically, and Cluster Autoscaler adds a worker node if the existing nodes can't fit them.

### 🧾 YAML

```yaml
# Taint a node (command, not YAML): kubectl taint nodes worker-2 gpu=true:NoSchedule
apiVersion: v1
kind: Pod
metadata: { name: gpu-job }
spec:
  tolerations:
    - key: gpu
      operator: Equal
      value: "true"
      effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - { key: gpu, operator: In, values: ["true"] }
  containers:
    - name: gpu-job
      image: ml-job:latest
      livenessProbe:
        httpGet: { path: /healthz, port: 8080 }
        initialDelaySeconds: 10
        periodSeconds: 10
      readinessProbe:
        httpGet: { path: /ready, port: 8080 }
        periodSeconds: 5
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: web-hpa }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: web }
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 60 } }
```

### ⚙️ Commands

| Action | Command |
|---|---|
| Taint a node | `kubectl taint nodes worker-2 gpu=true:NoSchedule` |
| Remove a taint | `kubectl taint nodes worker-2 gpu=true:NoSchedule-` |
| List node taints | `kubectl describe node worker-2 \| grep Taints` |
| Manual schedule (no scheduler) | set `spec.nodeName: worker-1` directly in the Pod YAML |
| Watch HPA live | `kubectl get hpa -w` |
| Generate load (test HPA) | `kubectl run load --image=busybox -- /bin/sh -c "while true; do wget -q -O- http://web; done"` |

### 🛠 Practice Tasks
- [ ] Set a Pod's `limits.memory` lower than what the app actually needs — watch it get `OOMKilled` in a restart loop; check `kubectl describe pod` for `Last State: Terminated, Reason: OOMKilled`.
- [ ] Write a bad `livenessProbe` (wrong port) on an otherwise-healthy app — watch kubectl restart it endlessly even though the app is fine; fix the probe.
- [ ] Taint `worker-2`, deploy a Pod with no toleration — confirm it never schedules there; add the toleration and confirm it can (but doesn't have to) land there.
- [ ] Install `metrics-server` (or confirm it's present), apply the HPA above, generate load, and watch replicas scale up live with `kubectl get hpa -w` and `kubectl top pods`.

### Addendum: Quality of Service (QoS) Classes — Deep Dive

**📘 Why QoS exists:** if a Pod's YAML defines no CPU/memory at all, `kubectl describe pod` can't
tell you how much it's allowed to consume — and yes, a pod like that **can** consume an entire
node's memory. QoS classes exist to control exactly this. The mechanics trace back to one physical
fact: **CPU is compressible** (a starved pod just runs on fewer cycles, still alive) while
**memory is non-compressible** (a pod that can't get the memory it needs cannot run at all) — that
asymmetry is *why* exceeding a CPU limit and exceeding a memory limit produce completely different
outcomes (see table below), not an arbitrary design choice.

| Class | Defined by | Priority |
|---|---|---|
| `BestEffort` | No `resources` block at all | Lowest — evicted first |
| `Burstable` | `requests` and `limits` set, `limits` > `requests` | Middle |
| `Guaranteed` | `requests` == `limits` for every container | Highest — evicted last |

**🌍 Real-world example — eviction cascade under memory pressure:** picture Node A (32Gi RAM)
increasingly loaded with pods across all 3 classes. As the node comes under memory stress,
Kubernetes evicts in strict order: **BestEffort pods first** (moved to another node) → if still
under stress, **Burstable pods next** → **Guaranteed pods are evicted last**. This eviction order
*is* what "Guaranteed = highest priority" concretely means — it's not just a label.

**📘 What happens when a running pod exceeds its boundary — the interview-favorite distinction:**

| Exceeds... | Result | Pod IP | Why |
|---|---|---|---|
| Memory limit | Container **OOMKilled + restarted** (`CrashLoopBackOff` if repeated, restart count increments) | **Unchanged** — only the container restarts, not the pod | Non-compressible — no "slow down" option exists |
| CPU limit | Container **throttled** (slowed down), never restarted | N/A | Compressible — K8s just hands out fewer cycles |
| Node has no capacity left | **Pod evicted** to a different node entirely | **Changes** — new pod on a new node gets a new IP | Pod-level eviction, not an in-place container restart |

*Highway analogy for CPU throttling:* 4-5 cars on a highway can all drive 140 km/h; put 1000 cars
on the same highway and everyone slows down together — nobody gets removed, traffic just throttles.
That's CPU throttling — the app keeps running, just slower.

```yaml
apiVersion: v1
kind: Pod
metadata: { name: guaranteed }
spec:
  containers:
    - name: qos-demo-ctr
      image: nginx
      resources:
        limits: { memory: "128Mi", cpu: "100m" }
        requests: { memory: "128Mi", cpu: "100m" }   # requests == limits -> Guaranteed
```

| Action | Command |
|---|---|
| See a pod's QoS class | `kubectl describe pod <name> \| grep "QoS Class"` |
| Live CPU/memory usage | `kubectl top pods` |

**🛠 Practice Tasks (QoS):**
- [ ] Deploy 3 pods — one with no `resources` block, one Burstable (`requests` < `limits`), one Guaranteed (`requests` == `limits`) — and confirm `kubectl describe pod | grep "QoS Class"` reports `BestEffort`/`Burstable`/`Guaranteed` correctly for each.
- [ ] Run a stress tool (e.g. `stress --vm-bytes` sized above the container's memory `limit`) and watch it OOMKill into `CrashLoopBackOff` with a rising restart count in `kubectl get pods -o wide` — confirm the pod IP never changes across restarts.
- [ ] Deploy a CPU-bound workload with a low CPU `limit` and generate load — confirm via `kubectl top pods` that it throttles (stays alive, CPU usage caps at the limit) rather than restarting.
- [ ] If you can safely pressure a lab node's memory, deploy BestEffort + Burstable + Guaranteed pods together, induce memory pressure, and watch `kubectl get events -A` to see BestEffort pods evicted before Burstable, and Guaranteed pods survive longest.

### Addendum: Scheduler Internals, Node Selector, Node/Pod Affinity

**📘 How the scheduler works, end to end:** `kubectl create -f deploy.yaml` → API server checks
AuthN/AuthZ → Controller Manager writes Deployment/ReplicaSet/Pod objects to **etcd**, pods marked
**`pending`** → pending pods join the **scheduler's queue**. The Scheduling Phase then runs 2
sub-steps — **Filtering** (predicates: eliminate nodes that flat-out can't run this pod — 13
built-in ones by default, e.g. `PodFitsResources`, `PodMatchNodeSelector`, `CheckNodeMemPressure`,
`PodToleratesNodeTaints`) then **Scoring** (priorities: rank survivors, favoring the node with the
**most resources still available** after the pod would land there — not just "any node that
fits"). Finally the **Binding Phase** writes the chosen node name into etcd, replacing `pending`.

**🌍 Real-world filter+score example:** 7 nodes, 4 have GPUs (one 50% used, one 0% used, two 100%
used). Filtering immediately drops the 3 non-GPU nodes. Scoring then picks the **0%-used GPU node**
— most remaining capacity wins, not merely "has a GPU."

**⚠️ NodeSelector/Affinity = Pod's perspective; Taints/Tolerations = Node's perspective.** This
framing decides which mechanism you reach for: is the *pod* choosing where to go, or the *node*
deciding what it'll accept?

**📘 NodeSelector — 2 steps, 1 hard limitation:** (1) label the node, (2) reference that label via
`nodeSelector` in the pod spec. **Cannot express multiple conditions — no AND/OR, one key-value
match only.** If several nodes satisfy that one condition, scoring breaks the tie.
```bash
kubectl label node nodeone cpu=i7
kubectl label node nodeone cpu=i7 --overwrite   # required to change an EXISTING label's value
kubectl label node nodeone cpu-                  # trailing dash removes a label entirely
kubectl get nodes -L cpu -L disk -L mem -L env   # labels as columns
```
```yaml
spec:
  nodeSelector: { cpu: i7 }
```

**⚠️ `nodeName` bypasses the scheduler completely:** setting `spec.nodeName` directly on a pod
skips filtering and scoring entirely — the pod goes to that exact node unconditionally.
`kubectl describe pod` on such a pod shows `Node-Selectors: <none>`, proving no selector-based
decision was ever made.

**⚠️ Critical timing rule — checked ONLY at scheduling time:** a `nodeSelector` (and affinity)
match is evaluated once, when the pod is first scheduled. If you relabel a node **after** a
matching pod is already running there, **the running pod is completely unaffected** — Kubernetes
never re-evaluates or evicts already-scheduled pods on a label change. Only pods scheduled *after*
the relabel are affected. The affinity API even names this explicitly:
`...IgnoredDuringExecution`.

**⚙️ Editing a running Deployment — what happens to the ReplicaSet:** `kubectl edit deployment
<name>` creates a **new ReplicaSet** for the change, but **scales the old one to 0 replicas rather
than deleting it** — the object persists. Deliberate design, not a bug: it enables (1) **rollback
history** (`kubectl rollout undo` needs something to revert to) and (2) **rollout flow control**
(surge/unavailable settings manage the old→new transition smoothly instead of an abrupt swap).

**📘 Why Affinity/Anti-Affinity exist:** they fix nodeSelector's single-condition limit — real
AND/OR/NOT-style logic via `matchExpressions` operators (`In`, `NotIn`, etc.). Two independent
axes: **toward nodes** (Node Affinity) or **toward other pods** (Pod Affinity), each with an
attract (affinity) and repel (anti-affinity) direction.

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:   # HARD - unmatched = Pending forever
      nodeSelectorTerms:
        - matchExpressions:
            - { key: size, operator: In, values: [large, medium] }
    preferredDuringSchedulingIgnoredDuringExecution:   # SOFT - falls back to any valid node
      - weight: 1
        preference:
          matchExpressions:
            - { key: mem, operator: In, values: [heavy] }
```

**🌍 Real-world pod-affinity example:** a `webserver` app has `frontend` (`app: green`) and
`backend` (`app: blue`) deployments. Left alone, the scheduler might place them on different
nodes — fine, but adds network latency between tightly-coupled tiers. **Pod Affinity** says "run
wherever pods matching this label already are," co-locating them for lower latency:
```yaml
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - { key: app, operator: In, values: [nnappone] }
        topologyKey: "kubernetes.io/hostname"   # this is what actually means "same node"
```
**Pod Anti-Affinity** is the mirror case — e.g. deliberately keeping `green` and `blue` on
*different* nodes for fault isolation, so one node failure can't take out both tiers at once.

**🛠 Practice Tasks (scheduler/node-selector/affinity):**
- [ ] Trace a real deployment through `pending` → scheduler queue → filter → score → bind by watching `kubectl get pods -o wide` transition from no `NODE` value to an assigned one.
- [ ] Label two nodes identically on one key and deploy a `nodeSelector`-matched pod repeatedly — confirm scoring (not filtering) is what breaks the tie between equally-eligible nodes.
- [ ] Deploy a pod with `nodeName` set directly and confirm via `describe pod` that `Node-Selectors` shows `<none>` — proof the scheduler was bypassed entirely.
- [ ] Relabel a node hosting an already-running nodeSelector-matched pod and confirm the running pod is completely unaffected — only a newly-scheduled pod would see the change.
- [ ] Edit a running Deployment and watch `kubectl get rs` before/after: new ReplicaSet scales up, old one scales to 0 but the object itself remains listed.
- [ ] Write both a `required` and a `preferred` node affinity rule targeting a label no node has — confirm the required one leaves the pod `Pending` forever while the preferred one still schedules the pod somewhere else.
- [ ] Build the frontend/backend pod-affinity co-location example with `topologyKey: kubernetes.io/hostname`, then flip it to `podAntiAffinity` and confirm the two pods land on different nodes instead.

### Addendum: Taints & Tolerations — Deep Dive

**📘 The core idea — nodes reject by default rule, not accept:** **Taint is always applied to a
NODE; Toleration is always applied to a POD.** This is the mirror image of NodeSelector/Affinity
(the pod's perspective, choosing a node) — here the **node** sets the condition, and a pod must
explicitly "agree" via a toleration to be let on. Mnemonic: a taint is a bad smell a node gives
off; by default no node has one, which is exactly why any pod can land anywhere by default.

**🌍 Real-world example:** Node D is tainted `food=pizza:NoSchedule` — effectively "I only run pods
that like pizza." Pods without a matching toleration go to A/B/C instead; only a pod explicitly
tolerating `food=pizza` can land on D. Scaled up: Node A/C tainted `red`, Node B/D tainted `blue` —
pods tolerating `blue` land only on B/D, pods tolerating `red` land only on A/C. This is the real
mechanism behind **dedicating specific nodes to specific projects/teams** (e.g. GPU nodes reserved
for an ML team) — taint the dedicated nodes, only matching-toleration pods can ever schedule there.

**🧾 Syntax:** `key=value:policy`, e.g. `food=pizza:NoSchedule`.
```bash
kubectl taint node node2 food=pizza:NoSchedule
kubectl describe node node2 | grep -i taint
# Taints:   food=pizza:NoSchedule
```

**⚠️ The control-plane node's taint is a special case:**
```bash
kubectl describe node manager | grep -i taint
# Taints:   node-role.kubernetes.io/control-plane:NoSchedule
```
Notice: **no value** at all — straight from the key to `:NoSchedule`. That makes the condition
unmatchable by any ordinary pod toleration, which is exactly why regular application pods never
land on the control-plane node by default — no special-case logic needed, just an intentionally
unsatisfiable taint.

**🧾 Adding a toleration to a Pod:**
```yaml
spec:
  tolerations:
    - key: "color"
      operator: "Equal"
      value: "pink"
      effect: "NoSchedule"
```
The `key`/`value`/`effect` must exactly match the node's taint for the pod to be allowed on.

**📘 The 3 taint effects, by strictness:**
| Effect | Meaning |
|---|---|
| `NoSchedule` | Hard rule for *new* scheduling only — non-tolerating pods never get placed here. Pods already running before the taint existed are unaffected. |
| `PreferNoSchedule` | **Soft** — the scheduler avoids it when possible, but can still place a non-tolerating pod here if there's nowhere else valid. |
| `NoExecute` | Strictest — blocks new scheduling **and actively evicts already-running non-tolerating pods** the moment the taint is applied. |

**⚠️ `NoExecute` eviction scenario:** a pod is already running on an untainted node. `NoExecute` is
then applied. The already-running pod has no matching toleration → **Kubernetes evicts it and
moves it to another node immediately** — `NoExecute` isn't just a future-scheduling gate, it acts
on what's already there.

**⚙️ `tolerationSeconds` — a grace period before `NoExecute` eviction:**
```yaml
tolerations:
  - key: "key1"
    operator: "Equal"
    value: "value1"
    effect: "NoExecute"
    tolerationSeconds: 3600
```
The pod stays bound to the node for 3600s after a matching `NoExecute` taint appears, then gets
evicted — unless the taint is removed first, in which case it's never evicted at all.

**Default tolerations every pod gets automatically** (visible via `kubectl describe pod`):
```
node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
```
This is why a pod isn't instantly evicted on a brief node blip — it tolerates `not-ready`/
`unreachable` for 300 seconds by default before eviction kicks in.

**🛠 Practice Tasks (taints & tolerations):**
- [ ] Taint a worker node with `food=pizza:NoSchedule`, deploy a pod with no toleration and confirm it never lands there, then add the matching toleration and confirm it can.
- [ ] Compare `kubectl describe node <control-plane>` against a manually-tainted worker node — spot the missing value on the control-plane's taint and explain why that makes it unmatchable by design.
- [ ] Apply `PreferNoSchedule` on every other node in a small cluster except one, and confirm a pod can still land on a `PreferNoSchedule`-tainted node when nothing else is available.
- [ ] Start a pod on an untainted node, then apply a `NoExecute` taint to that same node with no `tolerationSeconds`, and watch the pod get evicted immediately.
- [ ] Repeat the above with `tolerationSeconds: 60` on the pod's toleration, and confirm it survives exactly that long before eviction — then repeat once more and remove the taint before the timer expires, confirming eviction never happens.

---

## 7. Services & Networking

### 📘 Theory
- **Service** is a stable virtual IP + DNS name in front of a dynamic set of Pods (selected by
  label selector). Types:
  - `ClusterIP` (default) — internal-only virtual IP.
  - `NodePort` — opens the same port on every node (30000-32767 range), routes to ClusterIP.
  - `LoadBalancer` — provisions a cloud LB (no-op / pending in a bare kubeadm lab without MetalLB).
  - `Headless` (`clusterIP: None`) — no virtual IP; DNS returns each Pod IP directly — required
    for StatefulSets so each replica gets its own resolvable DNS name.
- **Endpoints/EndpointSlice** — the actual list of pod IPs backing a Service, kept in sync by the
  endpoint controller based on the selector + **readiness** (a not-Ready pod is removed from
  Endpoints even though it still exists).
- **CoreDNS** — cluster DNS; every Service gets `<svc>.<namespace>.svc.cluster.local`.
- **CNI (Container Network Interface)** — the plugin (Calico, Flannel, Cilium...) that actually
  gives every pod an IP and wires pod-to-pod routing across nodes; kube-proxy handles
  Service-IP→Pod-IP translation, the CNI handles the underlying pod network fabric.
- **NetworkPolicy** — firewall rules *between pods*, enforced by the CNI (not all CNIs support it
  — Flannel alone doesn't, Calico/Cilium do). Default (no policy) = all traffic allowed;
  once *any* policy selects a pod, it becomes default-deny for the direction(s) that policy covers.
- **Ingress** — L7 HTTP(S) routing (host/path-based) into the cluster, needs an **Ingress
  Controller** (nginx-ingress, etc.) actually running — the Ingress object alone does nothing.

### 🌍 Real-World Example
A public web app: Ingress with TLS termination routes `app.example.com` → `web` Service
(ClusterIP) → pods. Internally, `web` calls `api.internal.svc.cluster.local` (ClusterIP, never
exposed outside). A NetworkPolicy default-denies all ingress in the `payments` namespace except
from the `checkout` namespace on port 443 — classic zero-trust segmentation for a regulated
workload.

### 🧾 YAML

```yaml
apiVersion: v1
kind: Service
metadata: { name: web }
spec:
  selector: { app: web }
  ports: [{ port: 80, targetPort: 8080 }]
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata: { name: db-headless }
spec:
  clusterIP: None            # headless — required for StatefulSet stable pod DNS
  selector: { app: db }
  ports: [{ port: 5432 }]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations: { nginx.ingress.kubernetes.io/rewrite-target: / }
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend: { service: { name: web, port: { number: 80 } } }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: payments }
spec:
  podSelector: {}             # applies to ALL pods in namespace
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-from-checkout, namespace: payments }
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: checkout } }
      ports: [{ protocol: TCP, port: 443 }]
```

### ⚙️ Commands

| Action | Command |
|---|---|
| List service endpoints | `kubectl get endpoints web` |
| DNS test from inside cluster | `kubectl run dnsutils --image=busybox:1.28 -it --rm -- nslookup web` |
| Port-forward for local test | `kubectl port-forward svc/web 8080:80` |
| Check CoreDNS pods | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| Check kube-proxy mode | `kubectl get cm kube-proxy -n kube-system -o yaml \| grep mode` |

### 🛠 Practice Tasks
- [ ] Deploy `web` + Service with a **deliberately wrong selector** (`app: webb`) — confirm `kubectl get endpoints web` shows `<none>` even though pods are running healthy; fix the selector and watch endpoints populate.
- [ ] Scale a Deployment's readiness probe to fail on purpose — confirm the pod drops out of `kubectl get endpoints` while still showing `Running` in `kubectl get pods` (this is the classic "traffic still 502s even though pods look fine" incident).
- [ ] Apply `default-deny` in a test namespace, confirm pod-to-pod traffic breaks (`curl` times out from a debug pod), then add a scoped allow policy and confirm only the intended traffic works.
- [ ] Break CoreDNS on purpose (scale it to 0 in `kube-system`) — confirm Service **names** stop resolving even though direct-IP curl still works; scale it back and confirm recovery.

### Addendum: Service Selector-Matching & the Label Chain

**📘 Why a Service exists at all:** with N replica pods you have N different IPs, and any of them
can change the moment a pod is replaced (self-healing, scaling, a node move — anything). **You
never talk to pods directly by IP.** A Service solves this with a **fixed IP + fixed DNS name**,
stable for its whole lifetime regardless of which pods currently sit behind it.

**⚠️ The rule that matters most:** the **selector of a Service must match the label of the Pods**
— not the ReplicaSet directly (though since the ReplicaSet's selector and the Pod template's label
are already required to match each other, the Service's selector ends up matching all three layers
in practice). The **Endpoints** object is the live list of `pod-ip:port` pairs currently matching
that selector, kept in sync automatically — when a pod disappears and a new one takes its place,
Endpoints updates without anyone touching the Service. This label-driven, auto-updating routing is
what's meant by **SDN (Software Defined Network)** in this context.

**The full label chain, end to end** (get any link wrong and it breaks silently — a Service with 0
endpoints, or a ReplicaSet that thinks it owns 0 pods and keeps creating duplicates — one of the
most common real-world K8s misconfigurations):
```
Deployment.metadata.labels   -> cosmetic, can be anything
ReplicaSet.spec.selector     -> MUST MATCH Pod.template.metadata.labels
Pod.metadata.labels          -> the label actually applied to running pods
Service.spec.selector        -> MUST MATCH Pod.metadata.labels
```

**🌍 Creating + verifying a Service end to end:**
```bash
kubectl expose deployment nginx-deployment --name nginx-dep-svc
# service/nginx-dep-svc exposed  (fast imperative way — auto-derives selector from the Deployment's pod labels)

kubectl describe svc nginx-dep-svc
# Selector:    app=nginx
# Endpoints:   172.16.10.99:80,172.16.3.166:80,172.16.3.170:80

kubectl get pods -l "app=nginx" -o wide
# confirm those exact IPs belong to the currently-running pods
```

> **Scope note:** a `ClusterIP` Service (the default `kubectl expose` creates) is only reachable
> **from inside the cluster**. External access (NodePort/LoadBalancer/Ingress) is covered
> separately above in this section.

**🛠 Practice Tasks (Service selector-matching):**
- [ ] Create a Deployment + `kubectl expose` it, then `kubectl describe svc` and cross-check every Endpoints IP against `kubectl get pods -o wide` — confirm they match exactly, don't just take it on faith.
- [ ] Delete one backing pod and immediately re-run `kubectl describe svc` — confirm the Endpoints list updates to the new pod's IP with no manual action taken.
- [ ] Deliberately mismatch the Service's selector from the Pod labels (edit `spec.selector`) — confirm `kubectl get endpoints <svc>` drops to `<none>` even though the pods are healthy and `Running`; fix it and confirm recovery.

---

## 8. Storage

### 📘 Theory
- **Volume** — pod-scoped storage; lifecycle tied to the pod (`emptyDir`, `hostPath`, etc.) unless
  it's a persistent type.
- **PersistentVolume (PV)** — a cluster-wide storage resource (like a Node, but for disk),
  provisioned either statically (admin creates it) or dynamically (via a StorageClass).
- **PersistentVolumeClaim (PVC)** — a namespaced *request* for storage; binds 1:1 to a PV that
  satisfies size/accessMode/storageClass.
- **StorageClass** — defines *how* dynamic provisioning happens (which provisioner, parameters,
  reclaim policy) — this is what makes "create a PVC and a PV just appears" work in cloud/CSI setups.
- **Access modes:** `ReadWriteOnce` (one node read/write), `ReadOnlyMany`, `ReadWriteMany` (needs a
  storage backend that supports it — e.g. NFS — not most block storage).
- **Reclaim policy:** `Delete` (PV + backing storage destroyed when PVC is deleted — dangerous
  default for stateful data if misconfigured) vs. `Retain` (PV kept, must be manually cleaned up —
  safer default for anything you can't afford to lose).

### 🌍 Real-World Example
Cloud: a StorageClass backed by the CSI driver dynamically provisions an EBS/PD volume per PVC —
developers never touch a PV directly. Home lab / on-prem without a CSI driver: `local-path`
provisioner (Rancher's) or manually pre-created PVs with `hostPath` for testing, with `Retain` set
on anything holding data you care about, because `Delete` + a mistaken `kubectl delete pvc` = real
data loss.

### 🧾 YAML

```yaml
apiVersion: v1
kind: PersistentVolume
metadata: { name: pv-manual }
spec:
  capacity: { storage: 5Gi }
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  hostPath: { path: /mnt/data }
  storageClassName: manual
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: pvc-manual }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: manual        # must match a PV's storageClassName to bind statically
  resources: { requests: { storage: 5Gi } }
---
apiVersion: v1
kind: Pod
metadata: { name: storage-test }
spec:
  containers:
    - name: app
      image: nginx
      volumeMounts: [{ name: data, mountPath: /usr/share/nginx/html }]
  volumes:
    - name: data
      persistentVolumeClaim: { claimName: pvc-manual }
```

### ⚙️ Commands

| Action | Command |
|---|---|
| Check PV/PVC binding status | `kubectl get pv,pvc` |
| See why a PVC is Pending | `kubectl describe pvc pvc-manual` |
| List available StorageClasses | `kubectl get storageclass` |
| Set a StorageClass as default | `kubectl annotate storageclass <name> storageclass.kubernetes.io/is-default-class=true` |

### 🛠 Practice Tasks
- [ ] Create a PVC requesting 10Gi against the 5Gi PV above — confirm it stays `Pending` forever (size mismatch), then diagnose via `kubectl describe pvc`.
- [ ] Write data into the mounted volume via the test pod, delete and recreate the pod (same PVC) — confirm the data persists across the pod's lifecycle.
- [ ] Delete the PVC with `reclaimPolicy: Retain` set — confirm the PV survives in `Released` state (not deleted, not immediately reusable) and figure out the manual steps to make it bindable again.

### Addendum: Persistent Volume Subsystem — Deep Dive

**📘 The chain, and why it has 3 links:** a Pod **never** talks to a PV directly — the flow is
always `Pod → PVC → PV → external storage`. Think of a **PVC as a ticket to use a PV**. The
external storage becomes a PV the moment it's made *visible inside* the cluster; a PVC is a
namespaced *request* against that PV.

**⚠️ The block-device sizing rule (easy to get wrong):** **one block device = one PV** — you cannot
carve a single 100Gi device into two separate PVs. A PV can be created smaller than its backing
device (wastes the remainder), and a PVC can request less than its PV's capacity (also wastes the
remainder) — but a PVC's request can never exceed what its PV actually offers.

**⚠️ Access-mode golden rule:** a PV is only ever accessible through **one** mode at a time —
`ReadWriteOnce` (RWO), `ReadOnlyMany` (ROX), or `ReadWriteMany` (RWX) — and that mode is dictated
entirely by what the **underlying storage technology supports**, not by preference. **NFS is one of
the few plugins that natively supports RWX**; most block storage (EBS, GCEPersistentDisk, iSCSI,
FC) is RWO-only. A PVC's requested access mode must match a compatible PV, or it stays `Pending`
forever.

**🌍 Static provisioning, end to end (NFS):**
```yaml
# 1. Admin hand-writes the PV
apiVersion: v1
kind: PersistentVolume
metadata: { name: pvone-nfs }
spec:
  capacity: { storage: 5Gi }
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: slow
  nfs: { path: /weekend, server: 10.0.0.99 }
---
# 2. App team hand-writes a matching PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: myclaim }
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 4Gi } }   # <= the PV's capacity — doesn't need to match exactly
  storageClassName: slow                       # MUST match the PV's storageClassName to bind statically
```
`kubectl get pv` flips `Available → Bound` only once a compatible PVC exists — matching
`storageClassName` + sufficient capacity + compatible access mode is what triggers the bind.

**🌍 Dynamic provisioning — the scaling fix:** hand-provisioning a PV per team doesn't scale (every
new app = another manual round-trip through the storage team). The fix: **one big shared export +
one StorageClass**, and every team from then on just writes a PVC — Kubernetes auto-creates the PV.

Vanilla Kubernetes has **no built-in NFS dynamic provisioner**, so `nfs-subdir-external-provisioner`
is installed via Helm:
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
kubectl create ns storagenfs
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=10.0.0.99 --set nfs.path=/k8sdata \
  --set storageClass.onDelete=true -n storagenfs
```
From then on, an app team only ever writes:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: sample-nfs-pvc }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: nfs-client        # <- the only link back to the shared NFS export
  resources: { requests: { storage: 2Gi } }
```
and a PV (e.g. `pvc-a3f0da32-...`) appears automatically, bound immediately — **no PV YAML ever
written by a human**. The provisioner names each backing folder
`<namespace>-<pvc-name>-<pv-name>` under the shared export, keeping every team's data cleanly
separated on one underlying volume. `archiveOnDelete=true` renames (rather than deletes) a
PVC's folder to `archived-...` when the PVC is removed — a safety net worth enabling even under a
`Delete` reclaim policy.

**⚙️ RWX payoff, made concrete:** a Deployment with 2+ replicas sharing one PVC backed by an
RWX-capable StorageClass — confirm with `kubectl exec ... -- df -h` in each pod that every replica
mounts the **identical** NFS path. That's the practical difference RWX buys over RWO: multiple pods
genuinely sharing one writable volume, not just one pod at a time.

---

## 9. Security & RBAC

### 📘 Theory
- **ServiceAccount (SA)** — identity for **processes running inside pods** (not humans) to talk to
  the API server. Every pod uses one (`default` SA if unspecified) with a token auto-mounted.
- **Role / ClusterRole** — a set of permissions (verbs on resources): Role is **namespaced**,
  ClusterRole is **cluster-wide** (or reusable across namespaces via RoleBinding).
- **RoleBinding / ClusterRoleBinding** — attaches a Role/ClusterRole to a user/group/ServiceAccount.
  Key combo to remember: **RoleBinding can reference a ClusterRole** (grants those cluster-defined
  permissions, but scoped to just that one namespace) — very common pattern for reusable
  "view"/"edit" style roles.
- **SecurityContext** — pod/container-level hardening: `runAsNonRoot`, `runAsUser`,
  `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, dropped Linux capabilities.
- **PodDisruptionBudget (PDB)** — limits how many pods of a set can be **voluntarily** down at once
  (during drains/upgrades) — protects availability during planned maintenance (doesn't help against
  involuntary disruption like a node crashing).

### 🌍 Real-World Example
A CI/CD pipeline gets its own ServiceAccount with a Role scoped to `create`/`update` on
Deployments in exactly one namespace — not cluster-admin — so a compromised pipeline can't touch
other teams' workloads or cluster-wide resources. A PDB (`minAvailable: 2` on a 3-replica app)
ensures a rolling node drain during patching never takes the app down to 0 available replicas.

### 🧾 YAML

```yaml
apiVersion: v1
kind: ServiceAccount
metadata: { name: ci-deployer, namespace: team-a }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: deployment-manager, namespace: team-a }
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: ci-deployer-binding, namespace: team-a }
subjects:
  - kind: ServiceAccount
    name: ci-deployer
    namespace: team-a
roleRef: { kind: Role, name: deployment-manager, apiGroup: rbac.authorization.k8s.io }
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: web-pdb }
spec:
  minAvailable: 2
  selector: { matchLabels: { app: web } }
---
apiVersion: v1
kind: Pod
metadata: { name: hardened-pod }
spec:
  serviceAccountName: ci-deployer
  securityContext: { runAsNonRoot: true, runAsUser: 1000 }
  containers:
    - name: app
      image: myapp:latest
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: { drop: ["ALL"] }
```

### ⚙️ Commands

| Action | Command |
|---|---|
| Check if a SA can do something | `kubectl auth can-i create deployments --as=system:serviceaccount:team-a:ci-deployer -n team-a` |
| List all RoleBindings in ns | `kubectl get rolebindings -n team-a` |
| Describe a Role's rules | `kubectl describe role deployment-manager -n team-a` |
| Get a SA's token (short-lived) | `kubectl create token ci-deployer -n team-a` |
| Check PDB status | `kubectl get pdb` |

### 🛠 Practice Tasks
- [ ] Create the ServiceAccount + Role **without** the RoleBinding — run `kubectl auth can-i create deployments --as=system:serviceaccount:team-a:ci-deployer -n team-a` and confirm it says `no`; add the RoleBinding and confirm it flips to `yes`.
- [ ] Try to have that same SA create a Deployment in a **different** namespace — confirm it's denied (Role is namespaced), then understand why a ClusterRole+ClusterRoleBinding would be needed instead if cross-namespace access were the actual requirement.
- [ ] Apply the PDB, then `kubectl drain` a node running 2 of the 3 `web` replicas — observe the drain **blocks/waits** because evicting would violate `minAvailable: 2`, until pods reschedule elsewhere first.

### Addendum: Accessing a Cluster in Production & Certificate-Based User Onboarding

**📘 How production access actually works:** in labs you SSH straight into `master` and run
`kubectl` there. In production you almost never get that — instead you get a **jump/bastion host**
(a regular machine with network connectivity to the API server) with `kubectl` installed, and a
**kubeconfig file** handed to you by the cluster admin, placed at `~/.kube/config`. From then on
`kubectl` on that host talks to the cluster remotely; you never log into the control plane directly.
A kubeconfig carries the cluster's CA certificate, the API server address, the cluster name, and
the username used to authenticate — that's the complete "who you are + where the cluster is."

**The 4 steps to wire up `kubectl` access on a new host:** (1) confirm network connectivity to the
API server, (2) install `kubectl` (e.g. `sudo snap install kubectl --classic`), (3) get the config
file from the cluster admin, (4) `mkdir ~/.kube` and place it as `~/.kube/config`.

**📘 RBAC is always a 2-step process:** (1) create a `Role` (namespace-scoped) or `ClusterRole`
(cluster-wide) describing *what* can be done, (2) bind it to an identity via `RoleBinding` /
`ClusterRoleBinding`. Everything else is just mechanics around those two steps.

> **Production note:** most real clusters integrate with an existing directory service (LDAP /
> Active Directory) rather than hand-creating a Kubernetes user per employee. The certificate flow
> below is the manual mechanics that kind of integration builds on top of — useful to understand
> even where AD handles it for you.

**🌍 Real-world example — onboarding a cert-based user end to end:**

```bash
# 1) User generates a key + CSR on their own workstation
openssl genrsa -out ballu.key 2048
openssl req -new -key ballu.key -out ballu.csr -subj "/CN=ballu"

# 2) User sends the CSR to the cluster admin (root CA)
scp ballu.csr alok@10.0.0.100:

# 3) Admin signs it with the cluster's own CA — this is WHY Kubernetes will trust it
openssl x509 -req -in ballu.csr \
  -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial -out ballu.crt -days 365

# 4) Admin registers the identity and scopes it to a namespace via a context
kubectl config set-credentials ballu --client-certificate=ballu.crt --client-key=ballu.key
kubectl config set-context ballu-context --cluster=kubernetes --namespace=prod --user=ballu
```

`set-credentials` creates the **identity** (proven by cert+key); `set-context` binds that identity
to a **cluster+namespace pairing** — this is what actually scopes the user to one namespace.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { namespace: prod, name: pod-creator }
rules:
  - apiGroups: [""]              # "" = core API group
    resources: ["pods"]
    verbs: ["get", "watch", "list", "create"]   # NOTE: no "delete" — deliberately
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: create-pods, namespace: prod }
subjects:
  - kind: User
    name: ballu                  # case-sensitive
    namespace: prod
roleRef: { kind: Role, name: pod-creator, apiGroup: rbac.authorization.k8s.io }
```

**⚠️ Before handing a kubeconfig to a user:** strip out every admin-related `context`/`user` entry
and set `current-context` to the user's own context. Never hand out a config file that still
contains cluster-admin credentials alongside the restricted user's.

**Proof the scoping works** (run from the user's own machine, using only their config):

| Command | Result | Why |
|---|---|---|
| `kubectl get nodes` | `Forbidden: ... cannot list resource "nodes" ... at the cluster scope` | Nodes are cluster-scoped; user only has a namespaced Role |
| `kubectl get pods -n test` / `-n default` | `Forbidden: ... in the namespace "test"/"default"` | RoleBinding only covers `prod` |
| `kubectl get pods` (in `prod`, from context) | Works — lists pods | Role grants `get/list/watch` in `prod` |
| `kubectl delete pod ballupod` (in `prod`) | `Forbidden: ... cannot delete resource "pods" ...` | `delete` was never in the Role's verb list — least-privilege enforced verb-by-verb, not just namespace-by-namespace |

| Action | Command |
|---|---|
| See what resources/verbs exist | `kubectl api-resources` |
| List roles in a namespace | `kubectl -n <ns> get roles` |
| Inspect a role's rules | `kubectl -n <ns> describe role <name>` |
| Inspect a binding | `kubectl -n <ns> describe rolebinding <name>` |

**🛠 Practice Tasks (production access & RBAC onboarding):**
- [ ] Generate a real cert-based user end-to-end (key → CSR → CA-signed crt) exactly as above for a throwaway user on your lab cluster, and get a working `kubectl` session for them from a second machine (or a separate `KUBECONFIG` env var pointing at a fresh file, if you only have one host).
- [ ] Scope that user's Role to `get/list/watch` only (no `create`, no `delete`) in one namespace, and confirm every forbidden action produces the exact `Forbidden` message shape shown above — read the message, don't just note pass/fail.
- [ ] Deliberately hand yourself a kubeconfig that still has the admin context in it alongside the restricted user's, notice the risk, then practice stripping it down to just the restricted context before treating it as "done."
- [ ] Add `delete` to the Role's verb list, re-apply, and confirm the same `kubectl delete pod` that was Forbidden now succeeds — proving the enforcement is live and verb-level, not cached from the first check.

---

## 10. Troubleshooting — Capstone Drills

### 📘 Theory: systematic method
Work top-down, don't guess randomly:
1. **Control plane** — `kubectl get componentstatuses` (deprecated but still telling on older
   clusters), or check static pods on master (`crictl ps` if kubectl itself is unreachable).
2. **Node** — `kubectl get nodes` (NotReady?), `kubectl describe node` (conditions, events,
   allocatable resources), `journalctl -u kubelet`, `systemctl status containerd`.
3. **Workload** — `kubectl get pods -o wide`, `kubectl describe pod` (Events section first —
   90% of answers are there), `kubectl logs`, `kubectl logs --previous` (for a pod that already
   restarted/crashed).
4. **Network** — endpoints populated? DNS resolving? NetworkPolicy blocking? kube-proxy healthy?

**Key log/inspection locations:**

| What | Where |
|---|---|
| kubelet logs | `journalctl -u kubelet -f` |
| Container runtime logs | `journalctl -u containerd` / `crictl logs <container-id>` |
| Static pod manifests | `/etc/kubernetes/manifests/` |
| kubelet config | `/var/lib/kubelet/config.yaml` |
| Pod logs on disk | `/var/log/pods/<namespace>_<pod>_<uid>/` |
| Low-level container ops | `crictl ps`, `crictl inspect <id>` |

### 🛠 Practice: 10 on-call-style incidents
*Diagnose before reading the "expected root cause" — that's the actual exercise.*

1. **"`kubectl get nodes` shows `worker-1` as `NotReady`."**
   Try: stop the kubelet on `worker-1` (`systemctl stop kubelet`). Investigate via `kubectl
   describe node worker-1` (conditions + last heartbeat) and `journalctl -u kubelet` on that node.
   *Expected root cause:* kubelet not reporting node status (stopped service, cert expiry, or
   disk pressure).

2. **"New pods aren't scheduling cluster-wide, but nodes look Ready."**
   Try: taint every node `NoSchedule` and watch new pods hang `Pending`. *Root cause:* taint
   mismatch, or scheduler itself down (`kubectl get pods -n kube-system` for `kube-scheduler`).

3. **"App works via `kubectl port-forward` but not via the Service."**
   Try: break the Service selector. *Root cause:* label/selector mismatch → empty Endpoints —
   port-forward talks straight to a pod IP so it bypasses the Service entirely, which is why it
   still "works" and masks the real Service-layer problem.

4. **"Pod stuck in `Pending` forever."**
   Try: request more CPU than any node has allocatable. *Root cause:* insufficient resources, or
   an unmatched node affinity/taint — check `kubectl describe pod` Events for the scheduler's
   exact "0/3 nodes are available" reason string.

5. **"Pod stuck in `ContainerCreating`."**
   Try: reference a PVC that will never bind, or a Secret volume that doesn't exist.
   *Root cause:* usually a volume mount problem — check `kubectl describe pod` Events.

6. **"Pod in `CrashLoopBackOff`."**
   Try: give the container a bad `command:` override. *Root cause:* app crashes immediately on
   start — `kubectl logs <pod> --previous` is the answer, not `kubectl logs` (which may show
   nothing if it crashes instantly on the current attempt).

7. **"`ImagePullBackOff` on one node only, works on others."**
   Try: use a private registry image and don't create an `imagePullSecret` referenced by only
   some pods. *Root cause:* missing/misconfigured `imagePullSecrets`, or that one node's containerd
   has different registry credentials/mirror config.

8. **"Users report intermittent 502s from the app, pods show `Running`."**
   Try: make the readiness probe flaky. *Root cause:* pod is Running but not Ready, flapping in
   and out of Endpoints — classic "looks healthy, isn't" incident.

9. **"kubectl commands all time out / hang."**
   Try (carefully, expect full outage): stop etcd on master. *Root cause:* API server can't reach
   etcd — nothing works cluster-wide since every kubectl call round-trips through etcd.

10. **"A namespace's pods can't reach a service in another namespace, config looks unchanged."**
    Try: apply a `default-deny` NetworkPolicy in the target namespace without an allow rule.
    *Root cause:* someone added a NetworkPolicy — this is the #1 "nothing changed but it broke"
    culprit because policies aren't obvious from `kubectl get pods`/`svc` alone; you have to
    specifically check `kubectl get networkpolicy -A`.

---

## 11. Lead/Manager-Level Operational Topics

*(Talking points for "how would you run/scale/secure Kubernetes for this org" style interview
questions — not hands-on exam material, but what separates a lead from an individual contributor.)*

- **HA & DR strategy** — 3+ control-plane nodes behind a LB, odd-count etcd, regular automated
  etcd snapshots shipped off-cluster, documented/tested restore runbook (a backup you've never
  restored isn't a backup). Multi-AZ node spread via topology spread constraints / anti-affinity
  so a single zone outage doesn't take down every replica of a service.
- **Upgrade/patching strategy** — stay within the supported version skew (kubelet can be up to 2-3
  minor versions behind API server depending on release), upgrade control plane before workers,
  one node at a time via drain/upgrade/uncordon, always test in a lower environment first, track
  deprecated API removals before every minor version bump (`kubectl-convert`, deprecation guide).
  Downtime avoidance comes from `PodDisruptionBudget` + `maxUnavailable` tuning + multiple replicas.
- **Capacity planning & cost** — right-size requests/limits from actual usage (`kubectl top`,
  Prometheus historical data) rather than guesses; use Cluster Autoscaler / Karpenter-style node
  provisioning to match capacity to demand; separate node pools for burstable/cheap spot workloads
  vs. must-run-reliably workloads; namespace ResourceQuotas to prevent one team's cost blowing the
  budget.
- **Multi-tenancy patterns** — soft multi-tenancy (namespaces + RBAC + NetworkPolicy + Quotas) for
  trusted internal teams vs. hard multi-tenancy (separate clusters, or vcluster/Kata-style
  sandboxing) when tenants are untrusted or need to be provably isolated (compliance-driven).
- **GitOps & delivery** — declarative manifests in Git as the source of truth (Helm for
  templating/packaging, Kustomize for env-specific overlays, ArgoCD/Flux for continuous
  reconciliation) instead of imperative `kubectl apply` from laptops — enables audit trail,
  rollback-by-revert, and drift detection.
- **Observability stack** — metrics (Prometheus + `kube-state-metrics` + `node-exporter` +
  Grafana), logs (Fluentd/Fluent Bit/Loki shipping from every node via DaemonSet), and tracing for
  a full picture; alert on SLOs (error rate/latency), not just raw CPU/mem.
- **Incident response for a cluster-level outage** — pre-defined runbooks per failure class (API
  server down, etcd quorum lost, node NotReady storm, CNI failure), clear escalation path, and a
  blameless postmortem culture that feeds back into automation (turn every manual fix into a
  script or alert).

---

## 12. Quick-Reference Appendix

### Full kubectl cheat sheet by object

```bash
# Generic (works for every object type)
kubectl get <object> [-n ns] [-o wide|yaml|json] [-w]
kubectl describe <object> <name> [-n ns]
kubectl delete <object> <name> [-n ns]
kubectl edit <object> <name> [-n ns]
kubectl apply -f file.yaml
kubectl diff -f file.yaml          # preview changes before apply

# Pods
kubectl exec -it <pod> -- /bin/sh
kubectl logs <pod> [-c container] [--previous] [-f]
kubectl cp <pod>:/path ./local-path
kubectl top pod

# Deployments / ReplicaSets / StatefulSets
kubectl scale deploy/<name> --replicas=N
kubectl rollout {status,history,undo,pause,resume,restart} deploy/<name>

# Nodes
kubectl cordon / uncordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl taint nodes <node> key=value:Effect
kubectl top node

# RBAC
kubectl auth can-i <verb> <resource> [--as=<user/sa>] [-n ns]
kubectl create token <serviceaccount> -n ns

# Debugging
kubectl get events --sort-by=.metadata.creationTimestamp -n ns
kubectl run debug --image=busybox -it --rm -- sh
kubectl debug <pod> -it --image=busybox   # ephemeral debug container in a running pod
```

### Common YAML skeleton generator cheat sheet

```bash
kubectl create deployment web --image=nginx --dry-run=client -o yaml > deploy.yaml
kubectl create service clusterip web --tcp=80:8080 --dry-run=client -o yaml > svc.yaml
kubectl create job my-job --image=busybox --dry-run=client -o yaml -- echo hi > job.yaml
kubectl create cronjob my-cron --image=busybox --schedule="*/5 * * * *" --dry-run=client -o yaml -- echo hi > cron.yaml
kubectl create configmap my-cm --from-literal=key=value --dry-run=client -o yaml > cm.yaml
kubectl create secret generic my-secret --from-literal=key=value --dry-run=client -o yaml > secret.yaml
kubectl create role my-role --verb=get,list --resource=pods --dry-run=client -o yaml > role.yaml
kubectl create rolebinding my-rb --role=my-role --serviceaccount=ns:sa --dry-run=client -o yaml > rb.yaml
```

### Likely interview questions — quick hits

| Question | 1-2 line answer |
|---|---|
| Deployment vs StatefulSet? | Deployment = interchangeable stateless replicas; StatefulSet = stable identity + per-pod storage for stateful apps. |
| What happens if you exceed a memory limit? | Container gets OOMKilled by the kernel; exceeding a CPU limit just throttles, doesn't kill. |
| Liveness vs readiness probe? | Liveness failure restarts the container; readiness failure just pulls it out of Service traffic. |
| Why odd-numbered etcd cluster? | Raft needs a majority quorum to commit writes; odd counts maximize fault tolerance per node added. |
| How does a Service find its pods? | Label selector → Endpoints/EndpointSlice controller keeps the IP list in sync, kube-proxy programs routing rules from it. |
| Role vs ClusterRole? | Role is namespaced; ClusterRole is cluster-wide (or reusable across namespaces via a RoleBinding). |
| What's a static pod? | A pod defined by a manifest file the kubelet watches directly, no API server involved — how the control plane bootstraps itself. |
| PV reclaim policy Delete vs Retain? | Delete destroys the underlying storage when the PVC is removed; Retain keeps it for manual recovery — use Retain for anything you can't afford to lose. |
| Why can `kubectl port-forward` work when the Service is broken? | It connects straight to a pod IP, bypassing the Service/Endpoints layer entirely. |
| HPA vs Cluster Autoscaler? | HPA scales pod replica count on metrics; Cluster Autoscaler scales the number of *nodes* when pods can't be scheduled — different layers, often used together. |
