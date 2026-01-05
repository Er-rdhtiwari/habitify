#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: AWS_REGION=<region> AWS_ACCOUNT_ID=<id> $0 <ecr-repo-name> [image-tag]"
  echo "Example: AWS_REGION=us-east-1 AWS_ACCOUNT_ID=123456789012 $0 habitify latest"
  exit 1
}

REPO_NAME=${1:-}
IMAGE_TAG=${2:-latest}

if [[ -z "$REPO_NAME" ]]; then
  usage
fi

AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
  echo "AWS_ACCOUNT_ID is required (set env var or ensure 'aws sts get-caller-identity' works)" >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:${IMAGE_TAG}"

echo "Building and pushing image:"
echo "  Region:     ${AWS_REGION}"
echo "  Account:    ${AWS_ACCOUNT_ID}"
echo "  Repository: ${REPO_NAME}"
echo "  Tag:        ${IMAGE_TAG}"
echo

aws ecr describe-repositories --repository-names "${REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "${REPO_NAME}" --region "${AWS_REGION}" >/dev/null

aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"

docker build -t "${IMAGE_URI}" "${PROJECT_ROOT}"
docker push "${IMAGE_URI}"

echo
echo "Pushed image to: ${IMAGE_URI}"
