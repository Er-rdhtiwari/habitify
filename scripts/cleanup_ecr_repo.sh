#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: AWS_REGION=<region> AWS_ACCOUNT_ID=<id> $0 <ecr-repo-name> [image-tag]"
  echo "Example: AWS_REGION=us-east-1 AWS_ACCOUNT_ID=123456789012 $0 habitify latest"
  exit 1
}

REPO_NAME=${1:-}
IMAGE_TAG=${2:-latest}

if [[ -z "${REPO_NAME}" ]]; then
  usage
fi

AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}

if [[ -z "${AWS_ACCOUNT_ID}" ]]; then
  echo "AWS_ACCOUNT_ID is required (set env var or ensure 'aws sts get-caller-identity' works)" >&2
  exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:${IMAGE_TAG}"

echo "[1/4] Targeting repository '${REPO_NAME}' in region '${AWS_REGION}' (account: ${AWS_ACCOUNT_ID})"
echo "      Image tag to delete (if present): ${IMAGE_URI}"

echo "[2/4] Checking if repository exists..."
if ! aws ecr describe-repositories --repository-names "${REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "Repository '${REPO_NAME}' not found in ${AWS_REGION}; nothing to delete."
  exit 0
fi
echo "Repository found."

echo "[3/4] Attempting to delete image tag '${IMAGE_TAG}' if it exists..."
if aws ecr batch-delete-image --repository-name "${REPO_NAME}" --region "${AWS_REGION}" --image-ids imageTag="${IMAGE_TAG}" >/dev/null 2>&1; then
  echo "Deleted image: ${IMAGE_URI}"
else
  echo "Image tag '${IMAGE_TAG}' not found; continuing."
fi

echo "[4/4] Deleting repository '${REPO_NAME}' (force removes any remaining images)..."
aws ecr delete-repository --repository-name "${REPO_NAME}" --region "${AWS_REGION}" --force >/dev/null
echo "Repository '${REPO_NAME}' deleted from ${AWS_REGION}."
echo "Cleanup complete."
