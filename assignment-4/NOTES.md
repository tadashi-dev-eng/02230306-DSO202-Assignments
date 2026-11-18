# Assignment 4 — What it is about and what it is trying to teach

## The one-sentence idea

Stop deploying by hand. Put the **desired state** of the whole system in a Git repository and let a
controller inside the cluster (**Argo CD**) keep the cluster equal to Git, forever. This way of
operating is called **GitOps**.

## Where it fits in the module

| Assignment | What reached the cluster | Who did it |
| --- | --- | --- |
| 1 | Plain manifests (frontend, backend, Postgres) | you, `kubectl apply` |
| 2 | Same app with StatefulSet, Ingress, RBAC, quotas | you, `kubectl apply` |
| 3 | Same app packaged with Kustomize and Helm | you, `kubectl apply -k` / `helm install` |
| **4** | **The Assignment 3 chart + Assignment 2 platform objects** | **Argo CD, pulling from Git** |

No application code is written. The work is the **repository** (layout, pinned versions, Argo CD
objects), and the proof that GitOps behaves as promised.

## The four GitOps principles the assignment makes you *prove*

1. **Declarative.** Everything that exists after bootstrap is a file in Git, never `kubectl create`.
2. **Versioned and immutable.** Versions are pinned, staging follows a *tag*, a release is a
   commit, and recovery is a `git revert`, not editing history.
3. **Pulled automatically.** The cluster fetches from GitHub (every 60 s). No person or pipeline
   pushes into the cluster.
4. **Continuously reconciled.** A manual change is reverted (dev) or at least reported (staging),
   and a file removed from Git is removed from the cluster.

## The main concepts, in plain words

* **Argo CD Application.** "Take *this* path or chart at *this* Git revision and deploy it to
  *this* namespace, with *this* sync policy."
* **AppProject.** A fence around Applications: which repos, which namespaces, which resource kinds.
  `platform` is the admin fence and `dso202` is the narrow workload fence.
* **App of apps.** One hand-made `root` Application watches the `argocd/` folder. Adding a YAML
  file there creates an Application, and deleting it removes one.
* **Sync waves.** Order of deployment. Project (-3) → Sealed Secrets controller (-2) → namespaces,
  quotas, credentials (-1) → workloads (0). Inside the chart: database (0) → backend (1) →
  frontend (2). Each wave waits for the previous one to be *Healthy*.
* **Hooks.** A PostSync Job (the smoke test) runs after everything is healthy. If it fails, the
  sync fails.
* **Synced vs Healthy.** *Synced* means the cluster matches Git. *Healthy* means it actually works.
  You can be Synced and Degraded at the same time (the backend 1.1 failure).
* **Sealed Secrets.** Passwords are encrypted with the cluster's public key, so the encrypted file
  is safe to commit. Only the controller's private key (the *sealing key*) can decrypt it, which is
  why that key must be backed up outside Git.
* **Two environments, two rules.** `dev` follows `main` and syncs automatically, for fast feedback.
  `staging` follows a tag and syncs only when a person clicks or runs `argocd app sync`. That is
  the **promotion gate**.
* **Argo CD RBAC.** Argo CD has its own users and permissions (`policy.csv`), separate from
  Kubernetes RBAC. The `reviewer` user can look but not sync, and since Argo CD 3.0 needs an
  explicit rule to read logs.

## What each task is really testing

| Task | What you do | The lesson |
| --- | --- | --- |
| 1 | Build the repo, adapt the chart to a "contract", make the cluster | A chart must be *GitOps-ready*: tags as values, no Secrets, probes, waves, limits |
| 2 | Install Argo CD from a pinned Kustomize file | Even the GitOps tool is installed declaratively and pinned |
| 3 | Two projects + the root Application | Least privilege, and "only one thing is made by hand" |
| 4 | Sealed Secrets + platform layer | How to keep credentials in Git *safely*, and why the key backup matters |
| 5 | Deploy dev and staging | Waves, hooks, health; automated vs manual sync |
| 6 | A read-only `reviewer` user | Argo CD's own access control, separate from Kubernetes RBAC |
| 7 | Good release → faulty release → recovery | Releases are PRs; `argocd app rollback` is refused under auto-sync; the GitOps fix is `git revert` then a fix-forward; staging never sees the bad build |
| 8 | Four drills with predictions | Self-heal, drift reporting, pruning, project guardrails, each tested and not just claimed |
| 9 | Delete the cluster and rebuild it | The repo + one key really is the whole system (except the database data) |
| 10 (bonus) | Chart and values from two sources | Chart and config can move independently |

## What was learned along the way (things the brief did not say)

* Argo CD hides kinds that the project does not permit **from the resource tree**, so a very strict
  whitelist also hides Pods and their logs.
* Logging in with `argocd login --name reviewer` makes `reviewer` the *current* context, so later
  "admin" commands silently run as reviewer until you log in as admin again.
* When a sync of a bad revision is stuck in its retry backoff, auto-sync waits for the retries to
  finish before it picks up the revert (about 8 minutes here).
* A child Application that is `Missing` did not make the root `Progressing` on v3.5.6, but a
  `Degraded` one did make the root `Degraded`.
* Things still *not* under GitOps after the rebuild: the bootstrap layer, the root Application, the
  sealing key, Argo CD passwords, and database contents.
