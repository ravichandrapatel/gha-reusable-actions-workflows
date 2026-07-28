# gha-act-ubuntu

Local [nektos/act](https://github.com/nektos/act) runner image based on `catthehacker/ubuntu:act-latest`.

| Item | Value |
| --- | --- |
| Tag | `gha-act-ubuntu:dev` |
| Typical `runs-on` | `ubuntu-latest` |

Build from the kit root:

```bash
./build-images.sh
# or: docker build -t gha-act-ubuntu:dev -f image/ubuntu/Dockerfile image/ubuntu
```
