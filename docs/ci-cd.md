# CI/CD Pipeline (Task 2)

The pipeline is defined in [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml)
and runs on GitHub Actions. This document explains what it does, why each part
exists, and how secrets are handled.

## When it runs (`on:`)

| Trigger | What happens |
|---|---|
| Push to `main` | Full pipeline: test → build & push images → mock deploy |
| Push a `v*` tag (e.g. `v1.0.0`) | Also cuts a GitHub Release |
| Pull request to `main` | Tests only — never pushes images |

Running tests on PRs but only publishing images on real pushes is deliberate:
a PR (which can come from a fork) should be validated but must never publish
artifacts or touch the registry.

## Environment variables (`env:`)

`REGISTRY`, `BACKEND_IMAGE`, and `FRONTEND_IMAGE` centralize the image names so
they are written once. Images are pushed to **GitHub Container Registry (GHCR)**:

```
ghcr.io/chishty313/devops-project-backend:<sha>
ghcr.io/chishty313/devops-project-frontend:<sha>
```

GHCR is a real, free registry that authenticates with a token GitHub injects
automatically — so we get genuine image pushes with zero secret setup. In
Phase 3, once Azure Container Registry (ACR) exists, the push target moves to
ACR (see "Secrets" below).

## The jobs

### 1. `test`
Checks out the code, sets up Node 22, then for each app runs `npm ci`
(a clean, reproducible install from the committed `package-lock.json`) followed
by the test suite (`jest` for the backend, `vitest` for the frontend). Every
other job has `needs: test`, so if a test fails, nothing downstream runs and
broken code never ships.

### 2. `build-and-push`
Runs only after `test` passes and only on pushes (`github.event_name == 'push'`),
so pull requests never publish. Key points:

- **`permissions: packages: write`** — required for GHCR pushes.
- **Tag from commit SHA** — `${GITHUB_SHA::7}` gives a 7-char tag, so every image
  traces back to an exact commit. This is why the Kubernetes manifests never use
  `latest` as the source of truth: a moving `latest` tag makes "which version is
  running?" unanswerable. We also push a convenience `:latest`, but deploys
  reference the SHA.
- **Buildx + GHA cache** (`cache-from/to: type=gha`) — reuses image layers
  between runs, so builds get much faster after the first.
- Both the frontend and backend images are built and pushed separately, keeping
  the two apps fully independent.

### 3. `release`
Fires only when a version tag (`v*`) is pushed. It uses
`softprops/action-gh-release` to create a GitHub Release with auto-generated
notes — satisfying the "create a GitHub release or release tag" requirement.
Requires `permissions: contents: write`.

To cut a release:
```bash
git tag v1.0.0
git push origin v1.0.0
```

### 4. `deploy`
Currently a **mock** because the AKS cluster does not exist yet (Phase 3/4).
It prints the exact commands it will run so the intent is real and reviewable.
In Phase 4 the mock is replaced with a real
`az aks get-credentials` + `kubectl set image` / `kubectl apply`.

## How secrets are stored safely

This is a graded part of Task 2. The principle: **secrets never live in the repo
or in workflow files — they are injected at runtime and masked in logs.**

**Today (CI only):** the pipeline needs no manually-created secret. GHCR is
authenticated with the built-in `GITHUB_TOKEN`, which GitHub generates per run,
scopes to this repository, and discards when the run ends.

**Phase 3 onward (Azure):** the credentials needed to push to ACR and deploy to
AKS (an Azure service principal or, better, OIDC federated identity) are stored
as **GitHub Secrets** (repo → Settings → Secrets and variables → Actions) and
referenced as `${{ secrets.AZURE_CREDENTIALS }}`. They are encrypted at rest and
automatically masked in logs.

**Production-grade layering:**
- **Pipeline secrets** (how CI talks to Azure) → GitHub Secrets, or OIDC so no
  long-lived secret is stored at all.
- **App runtime secrets** (database password, etc.) → **Azure Key Vault**, pulled
  into the cluster via the Key Vault CSI driver, so they never touch git or the
  pipeline logs.

Equivalents on other platforms: Jenkins credentials store, Azure DevOps variable
groups (optionally backed by Key Vault), or AWS Secrets Manager.

## How to verify a run

1. Push to `main` (or open the Actions tab after any push).
2. Watch **Actions → CI/CD**: `test` → `build-and-push` → `deploy` should be
   green; `release` is skipped unless a `v*` tag was pushed.
3. Confirm the images appear under the repo's **Packages**.
