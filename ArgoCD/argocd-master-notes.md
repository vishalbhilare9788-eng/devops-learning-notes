# ArgoCD Master Notes — Interview & Production Reference

> **Living document**, built the same way as the Kubernetes master notes: as you dictate what a
> session/video covered (or share screenshots), the relevant topic gets its own section below,
> written as theory + real-world example + full command/YAML reference + hands-on practice tasks.
> Nothing here yet — sections get added as topics come in.

---

## Table of Contents
1. [Argo CD Components & Architecture](#1-argo-cd-components--architecture)
2. [First GitOps Application](#2-first-gitops-application)
3. [Sync Policies](#3-sync-policies)
4. [Application Health Checks](#4-application-health-checks)
5. [Sync Waves](#5-sync-waves)

---

## 1. Argo CD Components & Architecture

### 📘 Theory — the 7 core components
1. **Argo CD Server (API Server)** — the front door; every UI/CLI/API request lands here first.
2. **Application Controller** — the reconciliation core (stateful, Go-based, continuous loop).
3. **ApplicationSet Controller** — templates/generates many `Application` objects at once.
4. **Repository Server** — clones Git, renders Helm/Kustomize/plain manifests, caches results.
5. **Dex** (optional) — OIDC identity-provider proxy for SSO (GitHub/Google/Okta/Azure AD/etc.).
6. **Redis** — in-memory cache only (manifests, Git revisions, session state) — **not** a store of
   record; all real state lives in Git + Kubernetes CRDs.
7. **Notification Controller** — watches Application state, dispatches alerts (Slack/Teams/Email/
   Webhooks) on deployment events.

**Mental model:** the Argo CD API Server plays the same role as Kubernetes' own `kube-apiserver` —
a single front door that authenticates/authorizes and delegates real work to specialized components
behind it, rather than doing the heavy lifting itself.

**Request flow:** UI/CLI/API → **API Server** (auth + RBAC + routing) → delegates to
**Repo Server** (clone + render manifests) and **Application Controller** (diff live vs. desired,
reconcile) → **Dex** handles SSO when configured, **Redis** caches to keep everything fast,
**Notification Controller** fires alerts on state changes.

### 🌍 Real-World Example
A platform team runs Argo CD in a dedicated management cluster (hub-and-spoke), registers 3
downstream clusters (dev/staging/prod), and sets **selective sync**: dev auto-syncs on every Git
push for fast iteration, while prod requires a manual click-to-sync approval in the UI after a
release is verified in staging. Dex is wired to the company's Azure AD so engineers log into the
Argo CD UI with their existing corporate SSO instead of a separate local account.

### 🧾 Component Deep Dive

**Argo CD Server (API Server)** exposes 3 interfaces: a gRPC API (CLI), HTTP/HTTPS endpoints (web
UI + integrations), and the web UI itself as static files. Internally it's layered:
```
INGRESS/CLIENTS (Web UI / CLI / CI-CD)
  -> ENTRYPOINTS: gRPC Server | gRPC-Gateway (REST->gRPC translation for the browser)
  -> MIDDLEWARE: Authentication Handler (JWT, coordinates with Dex/OIDC) | RBAC Engine (checks
     argocd-rbac-cm) | Audit Logs
  -> SERVICE HANDLERS: Application | Cluster/Repo | Webhook Forwarding
  -> BACKEND COOPERATORS: Dex/OIDC | Redis Cache | Etcd Engine
```
It never does syncing or manifest generation itself — purely auth, routing, and delegation.

**Application Controller** — the actual reconciliation engine:
```
INBOUND STATE WATCHERS: Git/Repo Cache Tracker (via Repo Server/Redis) + K8s Cluster Watchers (Informers)
  -> Workqueue (rate-limited)
  -> Worker Pool: diffs Git vs. live K8s state, evaluates health (Healthy/Progressing/Degraded)
  -> Sync/Reconciliation Engine: OutOfSync -> [Auto-Sync enabled?] -> Auto-Remediation
  -> applies patches/updates/deletions to target K8s clusters
```

**Repository Server** — stateless manifest-generation middleman between Git/Helm and the
Application Controller. 3 jobs: clone repos, generate manifests (`helm template`/`kustomize
build`/plain), cache results. Polls Git **every 3 minutes by default**; a webhook can replace/
supplement that polling for near-instant change detection.

**Dex** (optional) — SQL/CRD-backed session store, pluggable **connectors** per identity provider
(github/saml/oidc), and a **token signer** that issues a JWT Argo CD trusts once an external IdP
authenticates a user. Only needed for SSO integration.

**Redis** — pure performance cache: manifest caching (skip recompiling Helm/Kustomize if the
commit hash hasn't changed), Git revision/commit-SHA caching, OIDC/session-state caching, and
API rate-limit protection against GitHub/GitLab. No persistent state lives here.

**Notification Controller** — watches the `ArgoCD Application` CRD for status updates, evaluates
configured triggers, and dispatches to external integrations (Slack/Teams/Webhooks).

### ⚙️ Sync Strategies
| Strategy | Behavior | Typical use |
|---|---|---|
| Manual | Requires a click "Sync" in the UI, or pipeline approval | Prod / regulated environments |
| Automatic | Argo CD applies Git changes instantly | Dev / fast iteration |
| Selective | Per-app/per-project choice of auto vs. manual | Mixed environments in one cluster |

### 🧾 Installation Types

| Feature | Vanilla ArgoCD | Red Hat OpenShift GitOps | Akamai/Akuity Enterprise |
|---|---|---|---|
| Core Engine | Pure upstream ArgoCD | Pure upstream ArgoCD | Pure upstream ArgoCD |
| Installation | Manual YAML/Helm | OpenShift Operator Hub | Managed SaaS control plane |
| Auth | Dex/Manual OIDC | Integrated OpenShift OAuth | Enhanced multi-tenant SSO |
| Management | You manage infra | Red Hat manages platform | Akuity manages instances |
| Support | Community | Enterprise SLA (Red Hat) | Enterprise SLA (Akuity) |

**Topology:** Hub-and-Spoke (recommended — one central Argo CD manages many external clusters,
each treated identically regardless of whether it's EKS/OpenShift/Rancher/etc.) vs. In-Cluster App
(a separate Argo CD instance per cluster, managing only its own local workloads).

**Scope:** by default Argo CD controls the **entire** cluster; **namespaced mode** restricts a
given Argo CD install to specific namespaces only.

### ⚙️ Commands — install, verify, access, CLI setup

```bash
# Install (in-cluster, manifest-based)
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify
kubectl -n argocd get deploy
kubectl -n argocd get pods      # note: argocd-application-controller-0 is a StatefulSet pod
kubectl -n argocd get svc       # everything is ClusterIP by default

# Get the initial admin password
kubectl -n argocd get secrets argocd-initial-admin-secret -o yaml
echo <base64-value> | base64 -d

# Reach the UI from a laptop through a jump host (chained tunnel)
ssh -L 8080:127.0.0.1:8080 <user>@<gateway-ip>          # on your laptop
kubectl port-forward svc/argocd-server -n argocd 8080:443 # on the gateway
# then browse https://localhost:8080

# Install the CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
argocd version --client
```

### 🛠 Practice Tasks
- [ ] Install Argo CD via the official manifest into its own namespace; confirm all 6 Deployments + the 1 StatefulSet (`argocd-application-controller-0`) come up `1/1 Running`.
- [ ] Retrieve and base64-decode the initial admin secret, then log into the UI — confirm it shows "No applications available to you just yet" on a fresh install.
- [ ] Reach the UI from a separate machine through a jump host using a chained `ssh -L` + `kubectl port-forward` — understand why both hops are needed (the service is ClusterIP-only, and your laptop can't reach the cluster network directly).
- [ ] Install the `argocd` CLI and run `argocd version --client` — note that at this stage it's installed but not yet authenticated against the cluster (`argocd login` is the next step).
- [ ] Change the sync policy conceptually: describe (in your own words) which of your future test apps you'd set to Automatic vs. Manual vs. Selective sync, and why — before actually configuring one, to test your own understanding of the tradeoff.

---

## 2. First GitOps Application

### 📘 Theory
A GitOps application takes **everything from Git** — every manifest that creates a Kubernetes
object must live in a Git repo, not be applied ad hoc. Argo CD's job is to pull those files from
Git and apply them to the cluster on your behalf, then keep the two continuously in sync.

**Every Argo CD Application needs exactly 3 things:**
1. **Source of truth (Git)** — where object files are pulled from.
2. **Target (cluster/namespace)** — where those objects get applied.
3. **Sync policy** — Manual (you click Sync) or Automatic (Argo CD applies Git changes the moment
   it detects them).

Once configured, Argo CD continuously keeps a **sync between Git and the cluster/namespace** —
that's the entire GitOps loop in one sentence.

### 🌍 Real-World Example
A team keeps `deployment.yaml` + `service.yaml` for their nginx app under a `chapter4/` folder in a
Git repo. Argo CD watches that path on the `main` branch; a developer merges a change to the image
tag, and (depending on sync policy) either an on-call engineer clicks Sync during a maintenance
window, or Argo CD applies it automatically within minutes — either way, the cluster's actual state
is always explainable by "what's in Git," which is the core promise of GitOps: Git as the single
auditable source of truth, not whatever someone last ran `kubectl apply` with from their laptop.

### ⚙️ Setting Up an Application, Step by Step

**Step 1 — Connect the Git repository:** `Settings → Repositories → Connect Repo`
| Field | Value |
|---|---|
| Connection method | HTTPS (SSH also supported) |
| Type | git |
| Name | a label for this connection |
| Project | `default` (Projects covered later) |
| Repository URL | the Git URL holding the manifests |
| Credentials | not needed for public repos; username/password (or token) for private ones |

Once connected, Argo CD shows the connection as **Successful**.

**Step 2 — Create the Application:** `Applications → New App`
| Field | Value |
|---|---|
| Application Name | e.g. `nginx-app` |
| Project | `default` |
| Sync Policy | Manual or Automatic |
| Source | the connected repo + branch/revision + the path (subfolder) holding this app's manifests |
| Destination | cluster URL (in-cluster if Argo CD runs in the same cluster) + namespace |

Click **Create**.

### 📘 Reading the immediately-after-creation status
A freshly created app typically shows **`Missing`** + **`OutOfSync`** — this is expected, not a
failure:
- **OutOfSync** — Argo CD compared Git (desired) vs. cluster (live) and found the objects don't
  exist in the cluster yet.
- **Missing** — the actual K8s objects haven't been created yet.

With a **Manual** sync policy, Argo CD deliberately does nothing further until you explicitly click
**Sync** — it will never silently apply changes on its own in this mode.

### ⚙️ Syncing and verifying
Click **Sync** → app moves through **`Progressing`** (creating the resources) → settles at
**`Synced`**/`Healthy`.
```bash
kubectl get deploy
# the app's Deployment now appears here — created BY Argo CD, sourced FROM Git
```
Clicking into the Application in the UI shows the full resource tree it created and now tracks.

### ⚠️ Deleting an Application
Two cascade modes control how Argo CD tears down the underlying Kubernetes objects when the
Application itself is deleted: **foreground** and **background** deletion. *(Exact behavioral
difference between the two — flagged for deeper coverage in a later session; for now: deleting the
Application does cascade into deleting what it created, and the mode picked changes how/when that
teardown happens.)*

### 🛠 Practice Tasks
- [ ] Connect a public Git repo via HTTPS in Settings → Repositories and confirm a "Successful" connection status before creating any Application against it.
- [ ] Create an Application with Manual sync policy pointed at a specific branch + subfolder path; confirm it lands on `Missing`/`OutOfSync` immediately after creation and explain out loud *why* — don't just note that it happened.
- [ ] Click Sync and watch the status transition `Progressing` → `Synced`; cross-verify with `kubectl get deploy`/`get svc` directly on the cluster that the objects genuinely match what's in the Git path.
- [ ] Make a small change directly in the Git repo (e.g. bump replica count or an image tag), refresh the Application in the UI, and confirm it flips back to `OutOfSync` until you Sync again — this is the core GitOps drift-detection loop, made concrete.
- [ ] Delete the Application once using each cascade mode (foreground vs. background) on a disposable test app, and observe/note any difference in teardown order or timing before reading ahead on the exact mechanism.

### Addendum: 3 Ways to Create an Application, the Sync Loop, and Deletion Mechanics

**⚙️ Deploying via the Argo CD CLI (imperative, method 2):**
```bash
# Expose argocd-server as NodePort so the CLI (on a bastion/gateway host) can reach it
kubectl -n argocd expose deployment argocd-server --name argocd-server-np --type=NodePort
kubectl -n argocd get svc   # note the NodePort, e.g. 31530

# Get the initial admin password and log in
argocd admin initial-password -n argocd
argocd login <node-ip>:<nodeport> --username admin --password <password>
# argocd account update-password   <- recommended right after first login

# Basic checks, then create an app imperatively
argocd cluster list
argocd app list
argocd app create nginx-demo \
  --repo https://github.com/<org>/<repo>.git \
  --path ch-04 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

argocd app get nginx-demo      # same Missing/OutOfSync -> Synced/Healthy lifecycle as the UI
argocd app sync nginx-demo
```
Same 3 required pieces as the UI (source repo+path, destination server+namespace) — just CLI flags
instead of form fields. **Downside:** purely imperative — no file left behind to reconstruct
exactly how an app was configured months later.

**📘 Declarative creation (method 3) — an `Application` is just a Kubernetes CRD:**
Installing Argo CD registers a custom resource, `Application`. You can define one the same way as
any other K8s object and keep it in Git like everything else:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/<org>/<repo>.git'
    targetRevision: HEAD
    path: ch-04
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: dev
  syncPolicy:
    automated:
      prune: true       # deletes resources removed from Git
      selfHeal: true     # reverts manual in-cluster edits back to match Git
```
`kubectl apply -f app.yaml` — **no Argo CD login required for this path**, since you're talking to
the Kubernetes API directly (trusted via kubeconfig), not the Argo CD API server.

| Method | Needs Argo CD username/password? | Style |
|---|---|---|
| Web UI | Yes | Imperative |
| `argocd` CLI | Yes (`argocd login` first) | Imperative |
| `kubectl apply -f <Application>.yaml` | **No** | Declarative |

**📘 The Sync Loop, end to end:** Git state ≠ cluster state → `OutOfSync` → is automated sync
enabled? **No** → manual approval needed (UI click or `argocd app sync`). **Yes** → apply changes
automatically, then honor any extra options: **Prune** (delete resources removed from Git),
**SelfHeal** (overwrite manual in-cluster changes back to Git's version), **Retry** (retry a failed
sync up to a limit). A webhook (Developer → GitHub → webhook → Argo CD fetches manifests → applies
→ reports status) can replace/supplement the default polling for near-instant reaction to a push.

**⚙️ Troubleshooting:**
| Symptom | Commands |
|---|---|
| Stuck in `Progressing` | `argocd app get <app>`, `kubectl describe deployment <name>` (typos, image pull issues) |
| Sync failures | `argocd app get <app>`, `kubectl logs -n argocd deployment/argocd-application-controller` |
| `OutOfSync`, unclear why | `argocd app diff <app>` |
| Force a fresh comparison | `argocd app get <app> --refresh` |

**⚠️ Deleting an Application — two independent choices:**
1. **Cascade vs. non-cascade** — controlled by a finalizer:
   `finalizers: [resources-finalizer.argocd.argoproj.io]` on the Application enables **cascade**
   (deletes the Application AND everything it manages). **No finalizer = default = non-cascade**
   (only the Application object goes; Deployments/Services it created keep running).
2. **Foreground vs. background** (only relevant for cascade delete):

| Mode | Behavior | Command |
|---|---|---|
| Foreground (default) | Standard K8s garbage collection; root Application stays `Terminating` until every managed resource is actually deleted — safer | `argocd app delete APPNAME --cascade --propagation-policy foreground` |
| Background | Application object deleted instantly; K8s garbage-collects orphaned resources asynchronously — faster but riskier, less visibility if something stalls; **not recommended as default** | `argocd app delete APPNAME --cascade --propagation-policy background` |

Cascade delete sequence: receive delete request → check for the finalizer → identify all tracked
resources → delete each managed resource → remove the finalizer → Kubernetes completes deletion of
the Application object itself.

**⚠️ PVC caveat:** cascade delete removes PersistentVolumeClaims **if Argo CD manages them** — real
data risk. Check first: `argocd app resources app-name | grep PersistentVolumeClaim`.

**🛠 Practice Tasks (CLI/declarative creation, sync loop, deletion):**
- [ ] Expose `argocd-server` as a NodePort from a bastion host, log the CLI in against it, and create an app with `argocd app create` — compare the experience directly against the UI flow.
- [ ] Write the same app as a declarative `Application` YAML with `syncPolicy.automated` (prune+selfHeal), `kubectl apply` it, and confirm it needed no `argocd login` at all.
- [ ] Manually `kubectl edit` a Deployment that a `selfHeal: true` Application manages, and watch Argo CD revert your change back to match Git — this is SelfHeal made concrete.
- [ ] Delete a disposable app once with `--propagation-policy foreground` and once with `background` (recreate between tests) and actually observe the `Terminating` behavior difference described above, rather than just reading about it.
- [ ] Before ever running a cascade delete on an app with a PVC, practice the `argocd app resources <app> | grep PersistentVolumeClaim` safety check as a habit.

---

## 3. Sync Policies

### 📘 Theory
Every sync is a 3-way relationship: **Desired State (Git) ↔ Argo CD ↔ Live Cluster State**. Argo CD
continuously reconciles Git against the live cluster; a **sync policy** is simply the answer to
"once Git changes, does that change reach the cluster automatically, or does it wait for a human?"

**The reconciliation sequence on every app** (regardless of policy): Argo CD fetches the Git
repo/branch/path → reads the object files there as the **desired state** → compares against the
cluster's actual state → `OutOfSync` if they differ. With **Manual** policy it stops there until
you click/run Sync; with **Automatic** it proceeds to apply immediately.

**Argo CD's 6 core health statuses:**
| Status | Color | Meaning |
|---|---|---|
| Healthy | Green | Operating 100% correctly |
| Progressing | Yellow | Transforming but hasn't failed yet |
| Degraded | Red | Failed or hit an unrecoverable error |
| Suspended | Blue | Intentionally paused |
| Missing | Yellow | Absent from the live cluster |
| Unknown | Gray | Assessment execution failed or timed out |

**Manual vs. Automatic:** Manual lets you review the diff before anything touches the cluster —
full control. Automatic applies Git changes the instant they're detected — no review step. **Rule
of thumb:** Automatic for dev (fast iteration matters more than review); **Manual stays the default
for production** (every change reviewed and deployed deliberately).

### 🌍 Real-World Example
A platform sets dev to `automated: { prune: true, selfHeal: true }` so any merge instantly reflects
in the dev cluster and any manual `kubectl` drift gets silently reverted. Staging uses
`automated: { prune: false, selfHeal: true }` so nothing unexpectedly disappears without a human
first reviewing what would be pruned. Production stays fully Manual — every sync is a deliberate,
reviewed action, and a PVC holding real customer data carries a `Prune=confirm` annotation as an
extra safety net even if automation were ever accidentally enabled on it.

### ⚙️ Setting Sync Policy

```yaml
# Simplest form - automated with all default behavior
spec:
  syncPolicy:
    automated: {}
```
Equivalent via CLI: `argocd app set APP-NAME --sync-policy automated`

**Basic automation triggers a sync when:** Git repository changes occur, Argo CD's refresh cycle
detects drift, or a manual refresh happens.

### ⚠️ Pruning — the critical default to remember
**When automated sync is enabled, Argo CD does NOT delete resources by default** just because
they're no longer in Git. Deletion-on-drift is a deliberate opt-in:
```yaml
syncPolicy:
  automated:
    prune: true   # deletes resources from K8s if removed from Git
```
Pruning removes: resources deleted from Git, orphaned Kubernetes objects, resources no longer
managed.

**Protecting one resource from pruning** (classic case: a PVC holding real data):
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
  namespace: prod
  annotations:
    argocd.argoproj.io/sync-options: Prune=false   # never auto-delete this one
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 8Gi } }
```

**Pruning with confirmation** — for critical resources (Namespaces/PVCs/PVs) you want a manual gate
without fully disabling pruning:
```yaml
annotations:
  argocd.argoproj.io/sync-options: Prune=confirm
```
The app then shows `Syncing... waiting for pruning confirmation of <resource>` until approved in
the UI. This can be set per-resource (annotation, as above) or as an Application-level default:
```yaml
syncPolicy:
  automated: { prune: true, selfHeal: true }
  syncOptions:
    - Prune=confirm
```

### 📘 Self-Healing
**Automatically reverts unauthorized or manual changes made directly to the live cluster.** If
someone runs `kubectl edit`/`kubectl delete` on a resource Argo CD manages, Argo CD detects the
drift and overwrites it back to match Git. **Only functions when `syncPolicy.automated` is
enabled** — there's no self-healing under a Manual policy.

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**The 4-step self-healing loop:** (1) Git = Cluster State — in sync → (2) Out-of-Band Change —
someone edits via `kubectl`, drift occurs, `OutOfSync` → (3) Argo CD Control Plane — constantly
monitoring, self-healing enabled → (4) Cluster Corrected — automatic re-apply to match Git, back to
`Synced`/`Healthy`.

### ⚙️ Retry
```yaml
syncPolicy:
  automated: { prune: true, selfHeal: true }
  retry:
    limit: 5            # retries before giving up (-1 = unlimited)
    backoff:
      duration: 5s        # initial wait before first retry
      factor: 2            # multiplier applied after each failure
      maxDuration: 3m       # cap on wait time between retries
    refresh: true            # optional: forces a Git refresh on new commits while retrying
```
Prevents transient cluster errors, network hiccups, or temporary API timeouts from breaking the
GitOps pipeline outright.

### ⚠️ Preventing deletion outright — `Delete=false`
Even after a `Prune=confirm` confirmation, a specific resource can be told to never actually be
deleted — sync proceeds, this one object stays untouched:
```yaml
annotations:
  argocd.argoproj.io/sync-options: Prune=confirm, Delete=false
```

### 🧾 Full advanced `syncPolicy` block
```yaml
syncPolicy:
  automated:              # enables automated sync and self-healing
    prune: true
    selfHeal: true
  retry:
    limit: 5
    backoff: { duration: 5s, factor: 2, maxDuration: 3m }
    refresh: true
  syncOptions:
    - Prune=confirm
    - Delete=confirm
    - CreateNamespace=true
```

### ⚙️ Choosing the right policy per environment
| Environment | Recommended `syncPolicy` | Why |
|---|---|---|
| Development | `automated: { prune: true, selfHeal: true }` | Fast iteration outweighs review overhead |
| Staging | `automated: { prune: false, selfHeal: true }` | Catch what would be pruned before it happens |
| Production | Manual (no `automated` block) | Every change deliberately reviewed before sync |

### 🛠 Practice Tasks
- [ ] Create an app with Manual sync and watch the exact reconciliation sequence (fetch → compare → `OutOfSync`) before ever clicking Sync — narrate out loud what each stage is doing.
- [ ] Enable `automated: {}` with no `prune` set, delete a Git-tracked file, and confirm the corresponding cluster resource is **not** removed — the "no delete by default" gotcha, made concrete.
- [ ] Add `prune: true`, repeat the same deletion, and confirm the resource now actually gets removed on the next sync.
- [ ] Annotate one resource with `Prune=confirm`, trigger a sync that would prune it, and watch the app sit in "waiting for pruning confirmation" until you approve it in the UI.
- [ ] With `selfHeal: true` enabled, manually `kubectl delete` (or `kubectl edit`) a resource Argo CD manages and confirm it gets automatically recreated/reverted without any sync action from you.
- [ ] Configure `retry` with a low `limit` and short `backoff.duration`, deliberately break the sync target briefly, and watch the retry attempts in `argocd app get <app>` before it either recovers or gives up.

---

## 4. Application Health Checks

### 📘 Theory — Sync Status vs. Health Status
- **Sync Status** answers: "Does the cluster match my Git repo?"
- **Health Status** answers: "Is the live code actually working?"

These are **fully independent**. An app can be **Synced but Unhealthy** (all pods crashing, even
though what's deployed exactly matches Git) or **OutOfSync but Healthy** (running an older version
that still works fine). Confusing the two is a common GitOps operating mistake.

**The 6 health statuses:**
| Status | Meaning |
|---|---|
| Healthy | Working as expected |
| Progressing | Rollout in progress |
| Degraded | Error state |
| Suspended | Paused or suspended |
| Missing | Resource not found |
| Unknown | Cannot be determined |

**⚠️ Worst-case aggregation rule (non-obvious, interview-relevant):** the **lower a status sits in
this list, the worse it is**, and an application's overall health is the **lowest (worst) status
among all its resources** — one bad resource is enough to drag the whole app's reported health
down. Ranking best→worst: **Healthy → Progressing → Degraded → Suspended → Missing → Unknown**.
E.g. `Missing`+`Degraded` → app shows **Missing**; `Degraded`+`Unknown` → app shows **Unknown**
(lowest of all); `Progressing`+`Degraded` → app shows **Degraded**.

### 🧾 Built-in Health Checks for Specific Types

**Deployment:**
| State | Condition |
|---|---|
| Healthy | `status.updatedReplicas`==`spec.replicas`, `status.availableReplicas`==`status.updatedReplicas`, no old ReplicaSets with running pods, generation matches observed generation |
| Progressing | Replicas being updated, new pods starting but not yet available, rollout hasn't exceeded `progressDeadlineSeconds` |
| Degraded | Condition reason `ProgressDeadlineExceeded` (K8s default: 600s) |

**HorizontalPodAutoscaler:**
| State | Condition |
|---|---|
| Healthy | `AbleToScale` or `ScalingLimited` condition, status `True` |
| Progressing | Argo CD waiting for autoscaling conditions |
| Degraded | `AbleToScale` reason `FailedGetScale`/`FailedUpdateScale`, or `ScalingActive` reason `FailedGetResourceMetric`/`InvalidSelector` |

### ⚠️ The HPA + GitOps replica-drift problem, and its fix
A Deployment YAML with `replicas: 4` plus an HPA that scales it to 5 under load creates a real
conflict: **Git says 4, live cluster says 5** — a drift Argo CD would otherwise try to "correct"
right back down, fighting the autoscaler. The fix has 3 parts:

1. **Remove `replicas` entirely from the Deployment spec** — let the HPA own scaling via its own
   `minReplicas`/`maxReplicas`:
```yaml
spec:
  # IMPORTANT: 'replicas' is completely removed to prevent drift detection on scale events.
  selector: { matchLabels: { app: argoapp } }
  template: { ... }
```
2. **Tell the Application to ignore that field:**
```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers: [/spec/replicas]
```
3. **Make automated syncs actually respect that ignore rule:**
```yaml
syncPolicy:
  automated: { prune: true, selfHeal: true }
  syncOptions:
    - RespectIgnoreDifferences=true   # without this, autosync can still stomp the HPA's live count
```

### ⚙️ Excluding a Resource From Health Checks Entirely
Useful for one-shot resources like a `Job` that don't need ongoing health monitoring:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/ignore-healthcheck: "true"
```

### 📘 Parent–Child Health Is NOT Automatically Inherited
Each resource's health is computed from **only its own state** — a Deployment's health comes from
its own replica/generation conditions, not by blindly inheriting from its Pods. A temporarily
unhealthy ReplicaSet mid-rollout doesn't automatically make the parent Deployment unhealthy; it may
correctly show `Progressing` instead.

### ⚙️ Commands
```bash
# Inspect the full health tree for an app (note: --output tree=detailed, an "=" not a space)
argocd app resources <app-name> --output tree=detailed

# Change how often Argo CD re-evaluates health (default: every 180s)
kubectl -n argocd edit cm argocd-cm
#   data: { timeout.reconciliation: "60s" }
kubectl -n argocd rollout restart statefulset argocd-application-controller   # required to apply it
```

### 🛠 Practice Tasks
- [ ] Force an app into "Synced but Unhealthy" (deploy a bad image/command that crash-loops) and separately into "OutOfSync but Healthy" (edit Git to a new version but don't sync yet, on a currently-working app) — confirm both states really are independent in the UI.
- [ ] Put two resources in an app into different health states (e.g. one Missing, one Degraded) and confirm the app-level health reflects the worse of the two per the ranking table, not just the "first" resource.
- [ ] Build the HPA + Deployment combo, remove `replicas` from the Deployment, add `ignoreDifferences` + `RespectIgnoreDifferences=true`, trigger a CPU-based scale-up, and confirm Argo CD stays `Synced`/`Healthy` instead of fighting the HPA back down.
- [ ] Annotate a one-shot Job with `ignore-healthcheck: "true"` and confirm it no longer affects the parent Application's aggregated health.
- [ ] Change `timeout.reconciliation` to a short value (e.g. `30s`), restart the application-controller StatefulSet, and confirm health re-evaluation actually speeds up — don't just trust the ConfigMap edit alone.

---

## 5. Sync Waves

### 📘 Theory
Applications have implicit deployment ordering even though Kubernetes itself doesn't enforce it —
a Deployment starting before its ConfigMap exists crash-loops; a Service targeting a Deployment
that doesn't exist yet errors; nothing runs if its namespace doesn't exist. **Sync waves** let you
define the Kubernetes object deployment sequence explicitly, the same way you'd sequence
foundation → pillars → walls → roof when building a house.

**Mechanics:**
- A **wave** is a number set via the `argocd.argoproj.io/sync-wave` annotation.
- **Lowest number = highest priority** (deployed first) — same mental model as Linux `nice` values.
- **No annotation = wave `0`** by default.
- Argo CD deploys waves in strict numerical order (negative → zero → positive) and **will not
  start the next wave until every resource in the current wave is both Synced AND Healthy** — this
  is what actually enforces the ordering, not just apply-order.
- Resources within the **same** wave deploy together (sorted by kind, then alphabetically by name).

### 🌍 Real-World Example
A CRD gets wave `-5` (nothing else can exist without it), Namespace gets `-3`, RBAC/ServiceAccounts
`-1`, ConfigMaps/Secrets `0`, Deployments/Services `3`, and Ingress/external resources `5+`. A team
that instead wave-annotates *every single resource* "just to be safe" ends up with a 10-wave
config where waves 3/4/5 have zero actual dependencies between them — pure added latency, since
Argo CD gates each wave transition on full health, for no ordering benefit at all.

### 🧾 Reference Wave Table
| Wave | Purpose |
|---|---|
| -5 | CRDs, Operators |
| -3 | Namespaces |
| -1 | RBAC, ServiceAccounts |
| 0 | ConfigMaps, Secrets |
| 1 | Databases, Caches |
| 2 | Migrations, Init Jobs |
| 3 | Applications (Deployments/Services) |
| 5 | Ingress, External Services |

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app-ns
  annotations: { argocd.argoproj.io/sync-wave: "-5" }
---
apiVersion: v1
kind: ServiceAccount
metadata: { name: my-app-sa, namespace: my-app-ns }
  # annotations: { argocd.argoproj.io/sync-wave: "-2" }
```

### ⚠️ Common Mistake #1 — Too Many Waves
Every wave transition costs real latency (Argo CD waits for full health before advancing). Keep
the wave count proportional to **genuine** dependencies — don't wave resources that don't actually
depend on each other; Kubernetes already handles plenty of this without manual staging.

### ⚠️ Common Mistake #2 — Missing/Incorrect Readiness Probes
The health chain is: Pod healthy (containers running + readiness passes) → ReplicaSet healthy →
Deployment healthy → wave completes. **A missing or broken readiness probe means the Pod never
reports healthy, so the Deployment never does, so the wave — and every wave after it — stays
blocked indefinitely**, even if the app is actually fine. The readiness probe is the literal
contract between your application and the sync-wave system.

**Sync waves vs. Kubernetes probes:** probes check if a *container* is ready; sync waves control
the *order* resources deploy in. Together: a wave only completes once its resources pass their
probe-driven health checks. Wave 0 must reach fully `Healthy` before wave 1 even starts.

### ⚠️ Common Mistake #3 — Wrong Annotation Key (Silent Failure)
```yaml
# WRONG - Argo CD ignores this entirely, silently treats the resource as wave 0
annotations:
  sync-wave: "1"
# CORRECT
annotations:
  argocd.argoproj.io/sync-wave: "1"
```
**Always confirm Argo CD actually sees the annotation first** when debugging any sync-wave issue —
a typo here fails silently, with no error or warning.

### ⚙️ Other Causes of a Stuck Wave, and the 3 Fixes
Insufficient cluster resources (pod unschedulable, Deployment stuck `Progressing`),
`ImagePullBackOff`, a readiness probe that never passes, or a CRD that never reaches `Established`
(schema validation errors) all block a wave the same way. Fix options, in order of preference:
1. **Fix the stuck resource** — find and fix the actual root cause (right answer, most cases).
2. **Remove it from the app** — if optional, delete from Git and re-sync; Argo CD prunes it.
3. **Override its health check** — via `argocd-cm`, treat that resource type as always-healthy.

### 🧾 Overriding Health Checks via `argocd-cm`
```yaml
# kubectl edit configmap argocd-cm -n argocd
data:
  # key format: resource.customizations.health.<API-GROUP>_<Kind>
  resource.customizations.health.core_Pod: |
    hs = {}
    hs.status = "Healthy"
    hs.message = "Forced to be always healthy"
    return hs
```
**⚠️ The API-group prefix matters and fails silently if wrong:** check via `kubectl api-resources`
— `Pod` is core API group (bare `v1`) → `core_Pod`; `ReplicaSet` is the `apps` API group
(`apps/v1`) → `apps_ReplicaSet`. Wrong prefix = the override silently does nothing, same failure
mode as the wrong sync-wave annotation key.

**A scoped, opt-in override** (safer than blanket-forcing an entire Kind healthy everywhere) — only
force-healthy resources carrying a specific label:
```yaml
resource.customizations.health.apps_ReplicaSet: |
  if obj.metadata.labels ~= nil and obj.metadata.labels["argo-health-override"] == "always-healthy" then
    hs.status = "Healthy"
    hs.message = "Forced to Healthy via application-specific label override"
    return hs
  end
  -- fallback to normal ArgoCD ReplicaSet health logic if label absent
  if obj.status ~= nil and obj.spec.replicas == obj.status.readyReplicas then
    hs.status = "Healthy"
    return hs
  end
  hs.status = "Progressing"
  return hs
```
```yaml
metadata:
  labels:
    argo-health-override: "always-healthy"   # opts this one ReplicaSet into the override
```

### ⚙️ Commands
```bash
argocd app get <app> --show-operation                    # current operation, incl. resources being synced
argocd app resources <app> --output tree=detailed         # resources + their wave numbers
kubectl api-resources                                      # confirm a Kind's API group for the health-override key
```

### 🛠 Practice Tasks
- [ ] Build a 4-wave app (CRD → Namespace/ServiceAccount → ConfigMap/Secret → Deployment/Service) and watch the UI's sync result table confirm resources land in exactly the assigned wave order, gated on health each step.
- [ ] Deliberately use the wrong annotation key (`sync-wave` instead of `argocd.argoproj.io/sync-wave`) and confirm the resource silently lands in wave 0 with no error — internalize that this fails silently, not loudly.
- [ ] Remove a readiness probe from a pod in an early wave and confirm every later wave stays permanently blocked, even though the container is technically running fine.
- [ ] Override `core_Pod` health in `argocd-cm` to always report Healthy, confirm it takes effect, then try the same key with a deliberately wrong API-group prefix and confirm it silently does nothing.
- [ ] Build the scoped label-based override for `apps_ReplicaSet` and confirm only ReplicaSets carrying `argo-health-override: always-healthy` skip real health evaluation — everything else still gets checked normally.
