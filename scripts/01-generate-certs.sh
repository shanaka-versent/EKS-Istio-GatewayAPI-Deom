#!/bin/bash
# MTKC POC EKS - Generate TLS Certificates
# @author Shanaka Jayasundera - shanakaj@gmail.com
#
# This script generates self-signed TLS certificates for the Istio Gateway

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../certs"
DOMAIN="${1:-mtkc-poc.local}"

echo "=== Generating TLS Certificates ==="
echo "Domain: ${DOMAIN}"
echo "Output directory: ${CERTS_DIR}"

mkdir -p "${CERTS_DIR}"

# Generate CA private key
echo "Generating CA private key..."
openssl genrsa -out "${CERTS_DIR}/ca.key" 4096

# Generate CA certificate
echo "Generating CA certificate..."
openssl req -new -x509 -days 365 -key "${CERTS_DIR}/ca.key" \
  -out "${CERTS_DIR}/ca.crt" \
  -subj "/C=AU/ST=NSW/L=Sydney/O=MTKC POC/CN=MTKC POC CA"

# Generate server private key
echo "Generating server private key..."
openssl genrsa -out "${CERTS_DIR}/server.key" 2048

# Create OpenSSL config for SAN
cat > "${CERTS_DIR}/server.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = AU
ST = NSW
L = Sydney
O = MTKC POC
CN = ${DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.3 = localhost
DNS.4 = mtkc-gateway-istio.istio-ingress.svc.cluster.local
IP.1 = 127.0.0.1
EOF

# Generate server CSR
echo "Generating server CSR..."
openssl req -new -key "${CERTS_DIR}/server.key" \
  -out "${CERTS_DIR}/server.csr" \
  -config "${CERTS_DIR}/server.cnf"

# Sign server certificate with CA
echo "Signing server certificate..."
openssl x509 -req -days 365 \
  -in "${CERTS_DIR}/server.csr" \
  -CA "${CERTS_DIR}/ca.crt" \
  -CAkey "${CERTS_DIR}/ca.key" \
  -CAcreateserial \
  -out "${CERTS_DIR}/server.crt" \
  -extensions req_ext \
  -extfile "${CERTS_DIR}/server.cnf"

# Cleanup
rm -f "${CERTS_DIR}/server.csr" "${CERTS_DIR}/server.cnf" "${CERTS_DIR}/ca.srl"

echo ""
echo "=== Certificates Generated Successfully ==="
echo "CA Certificate: ${CERTS_DIR}/ca.crt"
echo "Server Certificate: ${CERTS_DIR}/server.crt"
echo "Server Key: ${CERTS_DIR}/server.key"
echo ""
echo "Next step: Run 02-deploy-istio.sh"
