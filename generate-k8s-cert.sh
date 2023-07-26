#!/bin/sh

# input master lb ip, and generate k8s cert
masterLbIp=$1

# generate CA
# generate 2048 bit ca.key file
openssl genrsa -out ca.key 2048
# use ca.key product ca.crt
openssl req -x509 -new -nodes -key ca.key -subj "/CN=$masterLbIp" -days 10000 -out ca.crt

# generate server cert
# generate 2048 bit ca.key fil
openssl genrsa -out server.key 2048
# create a config file for signature requests (CSR)
cat << EOF > csr.conf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = xx
ST = xx
L = xx
O = xx
OU = xx
CN = $masterLbIp

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster
DNS.5 = kubernetes.default.svc.cluster.local
IP.1 = $masterLbIp
IP.2 = $masterLbIp

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names
EOF

# generate cert signature requests
openssl req -new -key server.key -out server.csr -config csr.conf
# use ca.key、ca.crt and server.csr to generate server cert
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 10000 -extensions v3_ext -extfile csr.conf -sha256

# generate client cert
openssl genrsa -out client.key 2048

cat << EOF > csr.client.conf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = xx
ST = xx
L = xx
O = system:masters
OU = xx
CN = kubernetes-admin

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster
DNS.5 = kubernetes.default.svc.cluster.local
IP.1 = $masterLbIp
IP.2 = $masterLbIp

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names
EOF

openssl req -new -key client.key -out client.csr -config csr.client.conf

openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 10000 -extensions v3_ext -extfile csr.client.conf -sha256

# generate kubeconfig
caBase64=$(cat ca.crt | base64 | tr -d '
')

clientCrtBase64=$(cat client.crt | base64 | tr -d '
')

clientKeyBase64=$(cat client.key | base64 | tr -d '
')

cat << EOF > kubeconfig
apiVersion: v1
clusters:
- cluster:
    server: https://$masterLbIp:6443
    certificate-authority-data: $caBase64
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: "kubernetes-admin"
  name: kubernetes-admin
current-context: kubernetes-admin
kind: Config
preferences: {}
users:
- name: "kubernetes-admin"
  user:
    client-certificate-data: $clientCrtBase64
    client-key-data: $clientKeyBase64
EOF

