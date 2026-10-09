# My Learning Notes — ArgoCD, Session-wise Log

Mirrors the Kubernetes track's convention (`F:\Claude code\K8s Prepration\My Learning Notes\`).

## Naming convention
`NN-topic-name.md` — e.g. `01-argocd-architecture.md`, `02-app-of-apps.md`

## How this works
1. You tell me you're starting an "ArgoCD chapter" and dictate what you learned (and/or share screenshots).
2. I write it up here as `NN-topic-name.md`, cleaned up but kept in your voice.
3. A polished, print-ready PDF version goes into `PDF/` — same filename, `.pdf` instead of `.md`.
4. Any screenshots from that session get bundled into their own gallery PDF in `Screenshots/`
   (`NN-topic-name-screenshots.pdf`) — matched from `C:\Users\Lemnovo\Pictures\Screenshots\` by
   timestamp, same as the Kubernetes track.
5. Reusable reference content (commands, YAML, concepts) gets merged into
   `../argocd-master-notes.md` as a new or expanded section.

## Log
| File | Topic | Date | Notes PDF | Screenshots PDF |
|---|---|---|---|---|
| [01-argocd-components.md](01-argocd-components.md) | 7 core components, API server internals, install (manifest), UI access via jump host, CLI install | 2026-09-11 | [PDF/01-argocd-components.pdf](PDF/01-argocd-components.pdf) | [Screenshots/01-argocd-components-screenshots.pdf](Screenshots/01-argocd-components-screenshots.pdf) (27 shots) |
| [02-first-gitops-application.md](02-first-gitops-application.md) | Create Application via UI/CLI/declarative YAML, Missing/OutOfSync/Sync lifecycle, Sync Loop (prune/selfHeal/retry), troubleshooting, cascade/non-cascade + foreground/background delete, PVC caveat | 2026-09-12 | [PDF/02-first-gitops-application.pdf](PDF/02-first-gitops-application.pdf) | [Screenshots/02-first-gitops-application-screenshots.pdf](Screenshots/02-first-gitops-application-screenshots.pdf) (65 shots) |
| [03-sync-policies.md](03-sync-policies.md) | Manual vs Automatic sync, 6 health statuses, pruning (Prune=false/confirm), self-healing, retry/backoff, Delete=false, per-environment policy recommendations | 2026-09-12 | [PDF/03-sync-policies.pdf](PDF/03-sync-policies.pdf) | [Screenshots/03-sync-policies-screenshots.pdf](Screenshots/03-sync-policies-screenshots.pdf) (32 shots) |
| [04-application-health-checks.md](04-application-health-checks.md) | Sync vs Health status, 6 health states (worst-case ranking), Deployment/HPA health checks, HPA+GitOps replica drift fix, ignore-healthcheck, parent-child health, reconciliation timer | 2026-09-12 | [PDF/04-application-health-checks.pdf](PDF/04-application-health-checks.pdf) | [Screenshots/04-application-health-checks-screenshots.pdf](Screenshots/04-application-health-checks-screenshots.pdf) (18 shots) |
| [05-sync-waves.md](05-sync-waves.md) | Wave-based deployment ordering, wave number reference table, 3 common mistakes (too many waves, bad probes, wrong annotation key), stuck-wave fixes, health-check overrides via argocd-cm | 2026-09-13 | [PDF/05-sync-waves.pdf](PDF/05-sync-waves.pdf) | [Screenshots/05-sync-waves-screenshots.pdf](Screenshots/05-sync-waves-screenshots.pdf) (27 shots) |
