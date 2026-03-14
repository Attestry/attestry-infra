#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${ROOT_DIR}/secrets"
NAMESPACE="${1:-attestry}"

CORE_ENV_FILE="${SECRETS_DIR}/core-runtime-secrets.env"
LEDGER_ENV_FILE="${SECRETS_DIR}/ledger-runtime-secrets.env"

if [[ ! -f "${CORE_ENV_FILE}" ]]; then
  echo "missing ${CORE_ENV_FILE}"
  echo "copy ${SECRETS_DIR}/core-runtime-secrets.example.env to ${CORE_ENV_FILE} and fill real values"
  exit 1
fi

if [[ ! -f "${LEDGER_ENV_FILE}" ]]; then
  echo "missing ${LEDGER_ENV_FILE}"
  echo "copy ${SECRETS_DIR}/ledger-runtime-secrets.example.env to ${LEDGER_ENV_FILE} and fill real values"
  exit 1
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic core-runtime-secrets \
  --namespace "${NAMESPACE}" \
  --from-env-file="${CORE_ENV_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic ledger-runtime-secrets \
  --namespace "${NAMESPACE}" \
  --from-env-file="${LEDGER_ENV_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "created secrets in namespace ${NAMESPACE}"
