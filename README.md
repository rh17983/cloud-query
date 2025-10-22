# CloudQuery: K8S --> DB

- Set environment variables in .env file

example:

```text
CLOUDQUERY_API_KEY=api_key
CQ_VERSION=6.29.7
DH_USERNAME=docker_registry_username
DH_PASSWORD=docker_registry_password # needed if building to the private repo

# connection link to the DB
# if local (minukube):
# DB_DSN=username:password@tcp(host.minikube.internal:port)/db_name?parseTime=true&loc=Local
# if remote host:
# DB_DSN=username:password@tcp(ip:port)/db_name?parseTime=true

IMG_NAME=cloudquery-k8s-mysql
IMG_TAG=1.0.2
```

- Then run deployment script

```bash
chmod +x deploy-cloudquery.sh

# Default (build disabled)
./deploy_cloudquery.sh

# Explicitly disable build (same as default)
./deploy_cloudquery.sh --build-image false

# Enable build & push
./deploy_cloudquery.sh --build-image true

# Short version
./deploy_cloudquery.sh -b true
```
