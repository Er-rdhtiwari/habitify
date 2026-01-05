#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO="habitify"
DEFAULT_TAG="latest"
DEFAULT_REGION="us-east-1"
DEFAULT_ACCOUNT="253484721204"

usage() {
  echo "Usage: AWS_REGION=<region> AWS_ACCOUNT_ID=<id> $0 [ecr-repo-name] [image-tag]"
  echo "Defaults: repo='${DEFAULT_REPO}', tag='${DEFAULT_TAG}', region='${DEFAULT_REGION}', account='${DEFAULT_ACCOUNT}'"
  echo "Example: AWS_REGION=us-west-2 AWS_ACCOUNT_ID=123456789012 $0 my-repo v1"
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

REPO_NAME=${1:-${DEFAULT_REPO}}
IMAGE_TAG=${2:-${DEFAULT_TAG}}

AWS_REGION=${AWS_REGION:-${DEFAULT_REGION}}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-}

if [[ -z "${AWS_ACCOUNT_ID}" ]]; then
  # Try to detect from caller identity, otherwise fall back to default account.
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)
  AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-${DEFAULT_ACCOUNT}}
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
