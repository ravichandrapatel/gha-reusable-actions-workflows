# GitHub ARC (chart 0.13.1)

Helm releases live only under `components/base/`. Set `namespace:` on the overlay kustomization you apply — that is the only namespace pin. Deploy the overlay that matches the runner mode you need.

## Layout

| Path | Role |
| --- | --- |
| `components/base/controller/0.13.1` | Helm release `gha-runner-scale-set-controller` |
| `components/base/runner/0.13.1` | Helm release `gha-runner-scale-set` (`containerMode` unset) |
| `components/base/runner-kubernetes/0.13.1` | Helm release `gha-runner-scale-set-kubernetes` |
| `components/base/runner-kubernetes-novolume/0.13.1` | Helm release `gha-runner-scale-set-k8s-novolume` |
| `components/base/namespace.yaml` | Namespace name is rewritten from overlay `namespace:` |
| `components/base/serviceaccount.yaml` | IRSA ServiceAccounts (`arc-eso`, `arc-runner-aws`) |
| `components/base/secretstore.yaml` / `externalsecret.yaml` | ESO → `github-config` (GitHub App) |
| `components/base/scc.yaml` / `rbac.yaml` | ROSA/OpenShift SCC `github-arc` + RoleBinding |
| `components/overlays/kind/dev` | Kind: controller + all three runners |
| `components/overlays/rosa/*` | ROSA entrypoints (SA + ESO + SCC) |

`kubectl apply -k` does not render Helm. Always:

```bash
kustomize build --enable-helm <overlay> | kubectl apply -f -
```

ARC CRDs exceed the 256Ki `last-applied-configuration` limit. `kind-up.sh` applies chart CRDs with `kubectl apply --server-side`, then applies the overlay with CRDs stripped.

## Namespace

Change `namespace:` in the overlay `kustomization.yaml` only. The transformer stamps `metadata.namespace`. Replacements copy that value onto:

- the Namespace object's `metadata.name`
- helm manager RoleBinding subjects (`controllerServiceAccount.namespace` is a helm-time stub)
- ROSA SCC RoleBinding subjects

## GitHub App

`github-config` keys: `github_app_id=3843629`, `github_app_installation_id=149912085`, `github_app_private_key`.

- Kind: overlay Secret has the ids. `kind-up.sh` adds the private key from repo-root `thecaptainhub-platform-app.2026-07-29.private-key.pem` (or `GITHUB_APP_PEM`). The PEM is gitignored; do not commit it.
- ROSA: ExternalSecret templates the ids and pulls only the private key from Secrets Manager (`github/arc` / `github_app_private_key`).

## Kind

```bash
export DOCKER_HOST=unix:///var/run/docker.sock
./kustomize/scripts/kind-up.sh
```

Per-environment images: edit the overlay `images:` list (`newName` / `newTag` / `digest`). Leave helm `values.yaml` on the public image names so `images.name` still matches. Copy the same `images:` block to each ROSA/stage/prod overlay.

## ROSA

Patch IRSA role ARNs in the overlay comments, put the App private key in Secrets Manager, then apply only what you need:

```bash
kustomize build --enable-helm kustomize/components/overlays/rosa/controller | oc apply -f -
kustomize build --enable-helm kustomize/components/overlays/rosa/runner-none | oc apply -f -
```

ESO must already be installed. Do not apply `components/base/scc.yaml` on kind.
