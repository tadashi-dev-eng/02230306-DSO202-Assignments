#!/usr/bin/env bash
# Generates ONE self-signed certificate for every Assignment 3 host and writes
# it where Kustomize's secretGenerator expects it (kustomize/base/tls/).
# The Helm release reads the same files with "kubectl create secret tls".
# Output is git-ignored: private keys never go into the repository.
set -euo pipefail
mkdir -p "$(dirname "$0")/../kustomize/base/tls"
cd "$(dirname "$0")/../kustomize/base/tls"
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 30 \
  -keyout tasktracker.key -out tasktracker.crt \
  -subj "/CN=tasktracker.local/O=DSO202" \
  -addext "subjectAltName=DNS:dev.tasktracker.local,DNS:prod.tasktracker.local,DNS:helm.tasktracker.local,DNS:helm-dev.tasktracker.local"
openssl x509 -in tasktracker.crt -noout -subject -ext subjectAltName -enddate
