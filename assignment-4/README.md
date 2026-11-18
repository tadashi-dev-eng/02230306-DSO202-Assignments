# DSO202 — Assignment 4: GitOps Delivery of the Task Tracker with Argo CD

| | |
| --- | --- |
| **GitOps repository** | <https://github.com/tadashi-dev-eng/dso202-gitops> (public) |
| **Commit SHA of `main` at submission** | `08e635dc04b30219effe58ab2a1cb4b53fc7145d` |
| **Tags** | `v1.0.0` (baseline), `v1.1.0` (frontend 1.1), `v1.2.0` (backend 1.1 + `APP_ENV`) |
| **Cluster** | kind `dso202-gitops` (1 control plane + 2 workers), Argo CD v3.5.6, Sealed Secrets chart 2.20.0 / controller 0.40.0 |
| **Written answers Q1–Q6** | in the repository [`README.md`](https://github.com/tadashi-dev-eng/dso202-gitops#written-answers) |
| **Full command output** | repository [`docs/evidence.md`](https://github.com/tadashi-dev-eng/dso202-gitops/blob/main/docs/evidence.md), and `evidence/` in this folder |

In Assignments 1–3 the Task Tracker reached the cluster because a person ran `kubectl apply` or
`helm install`. Here nobody does that after bootstrap. **Argo CD** runs inside the cluster, polls
the Git repository every 60 s and makes the cluster equal to it. A release is a commit, a rollback
is a `git revert`, and the whole system can be rebuilt from the repository plus one backed-up key.

| Environment | Namespace | Follows | Sync | Frontend |
| --- | --- | --- | --- | --- |
| dev | `dso202-dev` | branch `main` | automated (prune + self-heal) | `http://localhost:30080` |
| staging | `dso202-staging` | tag `v1.2.0` | manual (approval gate) | port-forward → `http://localhost:8081` |

| GitOps principle | Shown in |
| --- | --- |
| 1. Declarative | Tasks 3–5: every object after bootstrap comes from a file in Git |
| 2. Versioned and immutable | Tasks 2, 5, 7: pinned versions, staging on tags, recovery by `git revert` |
| 3. Pulled automatically | Tasks 5, 7: merges reach dev with nobody running `kubectl` |
| 4. Continuously reconciled | Task 8: drift reverted in dev, reported in staging, removed files pruned |

---

This folder (`assignment-4/`) holds the report, `NOTES.md`, the terminal transcripts in
`evidence/`, the screenshots in `assets/`, and the stand-in images in `standin-images/` (see
Deviations).

---

## Task 1 — Repository, chart contract and cluster

The Assignment 3 chart was copied to `charts/tasktracker/` and adjusted to the chart contract.
Image tags are values (C1), extra env vars are values (C2), the chart never renders a Secret and
reads `existingSecret` (C3), it has readiness probes (C4) and sync waves db 0, backend 1,
frontend 2 (C5), `progressDeadlineSeconds: 120` (C6), requests and limits everywhere (C7), no
platform kinds (C8), no Ingress (C9), and the NodePort is a value (C10). The full table, file by
file, is in `docs/evidence.md`. `.gitignore` was the very first commit.

![Tool check](assets/a4-01-tool-check.png)
![helm lint and rendered kinds](assets/a4-02-chart-lint.png)
![New kind cluster with port 30080 mapped](assets/a4-03-cluster.png)

## Task 2 — Install Argo CD declaratively

Argo CD is installed from `bootstrap/argocd/kustomization.yaml`, which pins the `v3.5.6` upstream
manifest and patches `argocd-cm` (60 s polling, a `reviewer` account, and the restored Application
health check) and `argocd-rbac-cm` (empty default role). Server-side apply is needed because the
ApplicationSet CRD exceeds the client-side annotation limit. Seven Pods and three CRDs are running.

![Kustomize render, server-side apply, 7 Pods, 3 CRDs](assets/a4-04-argocd-install.png)
![Login and argocd-cm settings](assets/a4-05-argocd-login.png)
![Argo CD UI after sign-in](assets/a4-ui-01-applications.png)

## Task 3 — AppProjects and the root Application

`platform` (administrator level) and `root` were applied by hand. Everything after that comes
from Git. The root created the `dso202` project, which allows only two namespaces, no
cluster-scoped kinds, and exactly the kinds the chart renders.

![root Synced/Healthy; dso202 created by root](assets/a4-06-root.png)
![Root Application resource tree](assets/a4-ui-02-root-tree.png)

## Task 4 — Platform layer and Sealed Secrets

A commit of `argocd/applications/sealed-secrets.yaml` installed the controller. The sealing key
was backed up to `../dso202-keys/` (mode 600) **before** anything was sealed. Credentials for each
environment were typed into git-ignored `secrets-plain/<env>.env` files and sealed through a pipe,
so no plaintext Secret was ever written to disk. `platform-dev` and `platform-staging` then
delivered the namespaces, quota, limits, RBAC, and the SealedSecrets. The controller turned these
into `tasktracker-credentials` with four keys. A search of the whole Git history found none of the
values.

![Controller installed from Git, key backed up](assets/a4-07-sealed-secrets.png)
![kubeseal output](assets/a4-08-seal.png)
![Platform Applications healthy; Secrets, quota, limits and RBAC delivered from Git](assets/a4-09-platform.png)
![No plaintext in history](assets/a4-10-no-plaintext.png)

## Task 5 — Workloads in dev and staging

`v1.0.0` was tagged, then the two Applications were added. Dev deployed in wave order: the
database became ready, then the backend Pod was created, then the frontend, and finally the
PostSync smoke-test Job ran and passed. A full create/read/update/delete cycle worked through
`http://localhost:30080`. Staging stayed `OutOfSync` / `Missing` until it was synced by hand.

![Wave order: db → backend → frontend → smoke test; smoke-test log; app status](assets/a4-11-dev-waves.png)
![CRUD cycle in dev](assets/a4-12-dev-crud.png)
![Staging and root before the manual sync](assets/a4-13-staging-synca.png)
![Manual sync; root and all apps after it; staging reachable on 8081](assets/a4-13-staging-syncb.png)
![tasktracker-dev resource tree](assets/a4-ui-03-tasktracker-dev-tree.png)
![Dev frontend](assets/a4-web-01-dev-frontend.png)

> **Finding (Q3).** On Argo CD v3.5.6 the root stayed `Healthy` while `tasktracker-staging` was
> `OutOfSync`/`Missing`, so the brief's expected `Progressing` did not appear. A `Degraded` child
> did propagate (root became `Degraded` in Task 7).

## Task 6 — Access control for Argo CD users

`reviewer` sees only the `dso202` Applications. `can-i get` returns **yes**, `can-i sync` returns
**no**, `can-i get logs` returns **no**, and reading the `platform` project is denied. The logs rule
was then enabled **by a commit** to `argocd-rbac-cm-patch.yaml`, and the bootstrap layer was
re-applied by hand (Git alone does not deliver it). After that, `can-i get logs` returned **yes**.

![reviewer: three permission states](assets/a4-14-reviewer.png)
![Logs rule committed, bootstrap re-applied, admin context restored](assets/a4-15-reviewer-logs.png)
![reviewer session showing Pod logs](assets/a4-ui-05-reviewer-logs-allowed.png)

> **Finding.** With the strict `dso202` whitelist, Argo CD left Pods and ReplicaSets out of the
> resource tree, so even the granted logs permission had nothing to show. Adding `apps/ReplicaSet`
> and `Pod` to the whitelist (commented in the file) fixed it without adding any platform or
> cluster-scoped kind. Logging in with `--name reviewer` also switched the CLI's *current*
> context, which is why step 5 (log in as admin again) matters.

## Task 7 — A release, a faulty release, and recovery

Every change in this task went through a pull request (squash merge):

![Pull requests #1–#6](assets/a4-web-06-github-prs.png)

**Part A.** Frontend 1.1 (PR #1) rolled out in dev, the smoke test re-ran, and the header shows
**v1.1**. Staging kept serving 1.0 until tag `v1.1.0` was created, PR #2 moved its
`targetRevision`, and a person ran the sync.

![Dev rolls the frontend to 1.1](assets/a4-16-frontend-release.png)
![Dev frontend shows v1.1](assets/a4-web-03-dev-frontend-1.1.png)
![Staging still 1.0 behind the gate](assets/a4-web-04-staging-still-1.0.png)
![Staging OutOfSync behind the gate, manual sync to v1.1.0, history](assets/a4-17-promote-v1.1.0.png)

**Part B.** Backend 1.1 (PR #3, bad commit `9dc39a1`) crash-looped. The old 1.0 Pod kept serving,
the frontend still answered, the smoke test did not run, and after 120 s the app was
`Synced` + `Degraded`. The log said why:
`[config] FATAL: required environment variable APP_ENV is not set; expected one of: dev, staging, prod`.
`argocd app rollback` was refused: *rollback cannot be initiated when auto-sync is enabled*.

![New backend Pod crash-loops; old Pod keeps running](assets/a4-18-backend-failurea.png)
![Synced + Degraded, root Degraded, frontend still up](assets/a4-18-backend-failureb.png)
![describe pod and the log line](assets/a4-19-diagnose.png)
![Rollback refused](assets/a4-20-rollback-refused.png)

Recovery happened through Git: `git revert` (PR #4) brought dev back to backend 1.0. The
fix-forward (PR #5) set the tag back to 1.1 and added `APP_ENV` **as a value** (C2, no template
change), and dev became healthy with a passing smoke test. `v1.2.0` was promoted to staging
(PR #6). Staging's history contains `v1.0.0 → v1.1.0 → v1.2.0` and never the bad commit.

![git revert through a PR](assets/a4-21-revert.png)
![Fix forward: APP_ENV as a value; dev healthy on backend 1.1](assets/a4-22-fix-forward.png)
![Tag v1.2.0 and promotion PR](assets/a4-23-promote-v1.2.0a.png)
![Manual sync; staging never ran the faulty release](assets/a4-23-promote-v1.2.0b.png)
![PR list, graph and tags](assets/a4-24-pr-list.png)

> **Finding (Q5).** Dev took about 8½ minutes to pick up the revert. The in-flight sync of the
> bad revision was still retrying (`retry.limit: 5`, backoff up to 3 min), and auto-sync only moved
> to the new commit once those retries were used up.

## Task 8 — Drift, pruning and project guardrails

| Drill | Prediction | Observed | Explanation |
| --- | --- | --- | --- |
| 1. Scale dev backend to 3 | Reverted to 1 | 3 → 1 within ~5 s, sync `initiatedBy: automated` | `selfHeal: true` |
| 2. Scale staging backend to 3 | Stays 3, reported `OutOfSync` | Stayed 3/3; `app diff` showed `replicas: 3` vs `1`; manual sync restored 1 | no `automated` block: reconciliation still compares and reports |
| 3. Add then `git rm` a ConfigMap | Created, then deleted | Present after the first push, `NotFound` after the second | `prune: true`. The namespace carries `Prune=false`, so deleting its file would not delete it |
| 4. ResourceQuota in the chart | Sync refused; staging unaffected | `resource :ResourceQuota is not permitted in project dso202`; staging stayed `Synced` on `v1.2.0` | project whitelist; staging reads an older tag and has no auto-sync |

All four predictions held.

![Drill 1](assets/a4-25-drill1.png)
![Drill 2](assets/a4-26-drill2.png)
![Drill 3](assets/a4-27-drill3.png)
![Drill 4: sync refused by the project](assets/a4-28-drill4a.png)
![Drill 4: staging unaffected, revert restores dev](assets/a4-28-drill4b.png)

## Task 9 — Rebuild from Git

The key was backed up, the cluster was deleted and recreated, the key was restored **before** the
controller existed, and only the two bootstrap steps were applied. The Applications became healthy
in wave order: sealed-secrets → platform-dev/staging → tasktracker-dev. The platform layer could
only become healthy because the restored key decrypted the SealedSecrets. Staging was synced by
hand back to `v1.2.0`, both smoke tests passed, and a new task was created in each environment.
**Elapsed: 12 min 30 s** from `kind create cluster` to a working dev frontend.

![Backup, record state, delete and recreate the cluster](assets/a4-29-rebuilda.png)
![DNS workaround, image preload, key restore, Argo CD bootstrap](assets/a4-29-rebuildb.png)
![Root applied, wave order, new admin login](assets/a4-29-rebuildc.png)
![Staging synced, both environments working, fresh key backup](assets/a4-29-rebuildd.png)

## Task 10 (bonus) — Chart and values from separate sources

`tasktracker-dev` was converted to a two-source Application (`sources:`, with
`$values/environments/dev/values.yaml` and a `ref: values` source). It is `Synced` and `Healthy`.
Separating the sources lets a chart stay pinned to a tag while values follow a branch.

![Multi-source Application](assets/a4-30-multisource.png)

---
