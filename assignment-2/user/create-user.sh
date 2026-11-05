#!/usr/bin/env bash
# Unit 2 practical: create a Kubernetes "user" with an x509 client certificate
# signed by the cluster CA through the CSR API, then a kube context for it.
# Outputs (tadashi.key/.csr/.crt) are git-ignored - they are credentials.
set -euo pipefail
cd "$(dirname "$0")"

USER_CN=tadashi           # -> RBAC username
GROUP_O=dev-team          # -> RBAC group
CLUSTER=kind-dso202       # from: kubectl config get-clusters
NS=dso202-assignment-02

# 1. private key (never leaves this machine)
openssl genrsa -out $USER_CN.key 2048

# 2. certificate signing request: CN = username, O = group
openssl req -new -key $USER_CN.key -out $USER_CN.csr -subj "/CN=$USER_CN/O=$GROUP_O"
openssl req -in $USER_CN.csr -noout -subject

# 3. submit to the cluster CA through the CertificateSigningRequest API
REQ=$(base64 < $USER_CN.csr | tr -d '\n')
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $USER_CN
spec:
  request: ${REQ}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 604800          # 7 days - certificates cannot be revoked, keep them short
  usages:
  - client auth
EOF

# 4. approve and extract the signed certificate
kubectl certificate approve $USER_CN
kubectl get csr $USER_CN
kubectl get csr $USER_CN -o jsonpath='{.status.certificate}' | base64 -d > $USER_CN.crt
openssl x509 -in $USER_CN.crt -noout -subject -issuer -dates

# 5. RBAC for this identity lives in ../rbac/developer.yaml (applied separately)

# 6. credential + 7. context (cluster + user + default namespace)
kubectl config set-credentials $USER_CN \
  --client-certificate=$USER_CN.crt --client-key=$USER_CN.key --embed-certs=true
kubectl config set-context $USER_CN-dev --cluster=$CLUSTER --user=$USER_CN --namespace=$NS
