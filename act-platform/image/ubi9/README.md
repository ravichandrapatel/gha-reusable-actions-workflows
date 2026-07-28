# gha-act-ubi9

Local [nektos/act](https://github.com/nektos/act) runner image based on Red Hat UBI9.

| Item | Value |
| --- | --- |
| Tag | `gha-act-ubi9:dev` |
| Typical `runs-on` | `ubi9` |

Requires network access to `registry.access.redhat.com` (org login if required).

```bash
./build-images.sh
# or: docker build -t gha-act-ubi9:dev -f image/ubi9/Dockerfile image/ubi9
```

Not every GitHub-hosted Ubuntu feature is available; use this for RHEL9-class parity checks.
