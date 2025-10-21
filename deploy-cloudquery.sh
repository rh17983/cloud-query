#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------
# CloudQuery -> K8S Cluster : Automation Script
# ---------------------------------------------
# Loads environment variables from .env file
# logs into Docker Hub
# updates K8s Secrets with env vars
# builds & pushes image to Docker Hub
# applies K8s manifests to cluster
# runs a one-off CloudQuery sync job to test
# ---------------------------------------------

# > Load environment variables
if [ ! -f .env ]; then
  echo ".env file not found!"
  exit 1
fi

echo "Loading environment variables from .env..."
export $(grep -v '^#' .env | xargs)

# Verify required env vars are set
: "${DH_USERNAME:?Missing DH_USERNAME in .env}"
: "${DH_PASSWORD:?Missing DH_PASSWORD in .env}"
: "${CLOUDQUERY_API_KEY:?Missing CLOUDQUERY_API_KEY in .env}"
: "${DB_DSN:?Missing DB_DSN in .env}"
: "${CQ_VERSION:?Missing CQ_VERSION in .env}"

IMG="${DH_USERNAME}/${IMG_NAME}:${IMG_TAG}"

echo "Environment variables loaded."
echo

# > Login to Docker Hub
echo "Logging into Docker Hub..."
echo "${DH_PASSWORD}" | docker login -u ${DH_USERNAME} --password-stdin || { echo "Docker login failed"; exit 1; }
echo

# > Create or update K8S Secrets
echo "Creating K8S secrets"
kubectl create ns cloud-query --dry-run=client -o yaml | kubectl apply -f -
kubectl -n cloud-query create secret generic cloudquery-secrets --from-env-file=.env -o yaml --dry-run=client | kubectl apply -f -
echo "Secrets updated."
echo

# > Build
echo "Building Docker image..."
docker build --build-arg CQ_VERSION=cli-v${CQ_VERSION} -t "$IMG" .
echo "Docker image built: $IMG"
echo
    
# > Push
echo "Pushing Docker image to Docker Hub..."
docker push "$IMG"
echo "Image pushed: $IMG"
echo

# > Apply K8S manifests
echo "Applying K8S manifests..."
kubectl -n cloud-query apply -f cloudquery-stack.yaml
echo "Manifests applied."
echo

# > Patch CronJob with new image
echo "Patching CronJob image to ${IMG}..."
kubectl -n cloud-query set image cronjob/cloudquery-k8s-to-mysql cloudquery="${IMG}"

# > Create a one-off CloudQuery job
JOB_NAME="cloudquery-test-$(date +%s)"
echo "Creating job: $JOB_NAME"
kubectl -n cloud-query create job --from=cronjob/cloudquery-k8s-to-mysql "$JOB_NAME"
echo "Job created: $JOB_NAME"
echo

# > Stream logs
echo "Streaming logs from job $JOB_NAME..."
kubectl -n cloud-query logs job/"$JOB_NAME" -f