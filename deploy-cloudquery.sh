#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------
# CloudQuery -> K8S Cluster : Automation Script
# ---------------------------------------------
# Loads environment variables from .env file
# logs into Docker Hub
# updates K8s Secrets with env vars
# builds & pushes image to Docker Hub (if --build-image true)
# applies K8s manifests to cluster
# runs a one-off CloudQuery sync job to test
# ---------------------------------------------
# Usage:
#   ./deploy_cloudquery.sh [--build-image true|false]
#
# Default: --build-image=false
# ---------------------------------------------

# Default argument values
BUILD_IMAGE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--build-image)
      BUILD_IMAGE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--build-image true|false]"
      exit 1
      ;;
  esac
done

echo ">> Build image: ${BUILD_IMAGE}"
echo

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

# > Create or update K8S Secrets
echo "Creating K8S secrets"
kubectl create ns cloud-query --dry-run=client -o yaml | kubectl apply -f -
kubectl -n cloud-query create secret generic cloudquery-secrets --from-env-file=.env -o yaml --dry-run=client | kubectl apply -f -
echo "Secrets updated."
echo

if [[ "${BUILD_IMAGE}" == "true" ]]; then
    # > Build
    echo "Building Docker image..."
    docker build --build-arg CQ_VERSION=cli-v${CQ_VERSION} -t "$IMG" .
    echo "Docker image built: $IMG"
    echo

    # > Login to Docker Hub
    echo "Logging into Docker Hub..."
    echo "${DH_PASSWORD}" | docker login -u ${DH_USERNAME} --password-stdin || { echo "Docker login failed"; exit 1; }
    echo
        
    # > Push
    echo "Pushing Docker image to Docker Hub..."
    docker push "$IMG"
    echo "Image pushed: $IMG"
    echo
else
    echo "Skipping Docker build & push (BUILD_IMAGE=${BUILD_IMAGE})"
    echo
fi

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