# GitHub ARC on ROSA (Kustomize + ESO)

Deploy [GitHub Actions Runner Controller on OpenShift](https://developers.redhat.com/articles/2025/02/17/how-securely-deploy-github-arc-openshift) via ArgoCD, with GitHub credentials from **AWS Secrets Manager** through **External Secrets Operator**.

Controller and runners share a single namespace, set only in the overlay:

```yaml
# components/overlays/rosa/<env>/kustomization.yaml
namespace: github-arc
```

Do not put the namespace in Helm `values.yaml`. (The runner chart still needs `controllerServiceAccount.namespace` at Helm template time; that is injected via `valuesInline` in `base/runner/kustomization.yaml` and must match the overlay `namespace`.)

## Layout

```text
components/
├── base/
│   ├── cluster/             # SCC, ClusterRole (cluster-scoped)
│   ├── secretstore / externalsecrets / ESO SA
│   ├── controller/          # helmCharts: gha-runner-scale-set-controller 0.14.2
│   └── runner/              # helmCharts: gha-runner-scale-set 0.14.2
└── overlays/rosa/
    ├── rosashared-dev/kustomization.yaml
    └── rosashared-prod/kustomization.yaml
```

## ArgoCD

```yaml
# argocd-cm
data:
  kustomize.buildOptions: --enable-helm
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: github-arc-rosashared-dev
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/ORG/REPO.git
    targetRevision: main
    path: components/overlays/rosa/rosashared-dev
  destination:
    server: https://kubernetes.default.svc
    namespace: github-arc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

## Secrets (AWS SM → ESO)

| Overlay | Secrets Manager key |
|---------|---------------------|
| rosashared-dev | `rosa/rosashared-dev/github-arc` |
| rosashared-prod | `rosa/rosashared-prod/github-arc` |

```bash
aws secretsmanager create-secret \
  --name rosa/rosashared-dev/github-arc \
  --secret-string "$(jq -n \
    --arg id 'APP_ID' \
    --arg iid 'INSTALLATION_ID' \
    --arg pem "$(cat github-app.pem)" \
    '{github_app_id:$id, github_app_installation_id:$iid, github_app_private_key:$pem}')"
```

ESO → Secret `github-arc-github-config` with `github_app_id`, `github_app_installation_id`, `github_app_private_key`.

Auth:

- ServiceAccount `github-arc-eso` in `github-arc`
- Overlay sets `eks.amazonaws.com/role-arn` (IRSA)
- Namespaced `SecretStore` → that SA; RoleBinding lets ESO mint tokens for it

Create the IAM role + trust policy first — see [docs/aws-secrets-manager.md](docs/aws-secrets-manager.md).

## Configure

Edit the overlay `kustomization.yaml`: IAM role ARN, SM key, region, `githubConfigUrl`, min/max.

## Workflow

```yaml
jobs:
  build:
    runs-on: github-arc-runners
    steps:
      - run: echo "ROSA ARC"
```

## Local build

```bash
kustomize build --enable-helm components/overlays/rosa/rosashared-dev
```
