# AWS Secrets Manager + ESO (IRSA) for GitHub ARC

## Kubernetes objects (this repo)

| Object | Name | Purpose |
|--------|------|---------|
| ServiceAccount | `github-arc-eso` (ns from overlay) | IRSA identity for Secrets Manager |
| Role / RoleBinding | `github-arc-eso-tokenrequest` | Lets ESO controller create tokens for that SA |
| SecretStore | `aws-secretsmanager-github-arc` | AWS SM provider using the SA above |
| ExternalSecret | `github-arc-github-config` | Syncs SM JSON → K8s Secret |

Overlay patches set the IAM role ARN, SM secret key, and region.

## IAM role (create outside GitOps)

Trust policy (ROSA / EKS OIDC) — replace placeholders:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "OIDC_PROVIDER:sub": "system:serviceaccount:github-arc:github-arc-eso",
          "OIDC_PROVIDER:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:rosa/rosashared-dev/github-arc*",
        "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:rosa/rosashared-prod/github-arc*"
      ]
    }
  ]
}
```

## Secret payload (GitHub App)

ARC expects these K8s Secret keys (created by ExternalSecret):

| SM / Secret key | Description |
|-----------------|-------------|
| `github_app_id` | App ID (or client ID) |
| `github_app_installation_id` | Installation ID |
| `github_app_private_key` | PEM private key (PKCS#1 / RSA) |

```bash
# Prefer file for the PEM to avoid shell escaping issues
aws secretsmanager create-secret \
  --name rosa/rosashared-dev/github-arc \
  --secret-string "$(jq -n \
    --arg id '123456' \
    --arg iid '78901234' \
    --arg pem "$(cat github-app.pem)" \
    '{github_app_id:$id, github_app_installation_id:$iid, github_app_private_key:$pem}')"
```

Store the PEM as a single JSON string (newlines escaped as `\n` is fine; `jq` handles this).

## Verify

```bash
oc get sa github-arc-eso -n github-arc -o yaml | grep role-arn
oc get secretstore aws-secretsmanager-github-arc -n github-arc
oc get externalsecret,secret -n github-arc
```
