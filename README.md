# k8s-cert
generate k8s cert  
  
input a master lb ip, and generate k8s cert   
```shell
sh generate-k8s-cert.sh master_lb_ip
```
  
generate file include:
```
ca.crt
ca.key
ca.srl

csr.conf
server.crt
server.csr
server.key

csr.client.conf
client.crt
client.csr
client.key

kubeconfig
```
   
