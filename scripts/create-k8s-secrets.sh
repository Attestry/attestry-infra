#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${ROOT_DIR}/secrets"
NAMESPACE="${1:-attestry}"

CORE_ENV_FILE="${SECRETS_DIR}/core-runtime-secrets.env"
LEDGER_ENV_FILE="${SECRETS_DIR}/ledger-runtime-secrets.env"
INFRA_ENV_FILE="${SECRETS_DIR}/infra-secrets.env"

for f in "${CORE_ENV_FILE}" "${LEDGER_ENV_FILE}" "${INFRA_ENV_FILE}"; do
  if [[ ! -f "${f}" ]]; then
    echo "missing ${f}"
    echo "copy ${f%.env}.example.env to ${f} and fill real values"
    exit 1
  fi
done

# infra-secrets.env 로드
set -a
source "${INFRA_ENV_FILE}"
set +a

# --- attestry namespace ---
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic core-runtime-secrets \
  --namespace "${NAMESPACE}" \
  --from-env-file="${CORE_ENV_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic ledger-runtime-secrets \
  --namespace "${NAMESPACE}" \
  --from-env-file="${LEDGER_ENV_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry ghcr-credentials \
  --namespace "${NAMESPACE}" \
  --docker-server=ghcr.io \
  --docker-username="${GITHUB_USERNAME}" \
  --docker-password="${GITHUB_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "created secrets in namespace ${NAMESPACE}"

# --- argocd namespace ---
kubectl create secret generic repo-attestry-infra \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/Attestry/attestry-infra.git \
  --from-literal=username="${GITHUB_USERNAME}" \
  --from-literal=password="${GITHUB_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret repo-attestry-infra -n argocd \
  argocd.argoproj.io/secret-type=repository --overwrite

kubectl patch secret argocd-secret -n argocd \
  --type merge \
  -p "{\"stringData\":{\"webhook.github.secret\":\"${ARGOCD_WEBHOOK_SECRET}\"}}"

echo "created argocd secrets"
