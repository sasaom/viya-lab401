# lab401 infrastructure

|Component|version|
|---------|-------|
|Kubernetes|v1.22.4|
|Ingress-Nginx|v.1.1.1|
|Cert-manager| 1.5.x|
|kustomize|3.7.0|

## Kubernetes version (2022 Feb 18):

```bash
az aks get-versions --location northeurope -o table

KubernetesVersion    Upgrades
-------------------  -------------------------
1.23.3(preview)      None available
1.22.6               1.23.3(preview)
1.22.4               1.22.6, 1.23.3(preview)
1.21.9               1.22.4, 1.22.6
1.21.7               1.21.9, 1.22.4, 1.22.6
1.20.15              1.21.7, 1.21.9
1.20.13              1.20.15, 1.21.7, 1.21.9
1.19.13              1.20.13, 1.20.15
1.19.11              1.19.13, 1.20.13, 1.20.15
```

```bash
# The lab401-setup.sh scripts use az cli commands to setup the lab401 infrastructure
cd infra
./lab401-setup.sh
```

## ingress-nginx

```bash
# ngress-nginx manifest copied locally

INGRESS_VERSION="v1.1.1"
cd infra/ingress-nginx
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-$INGRESS_VERSION/deploy/static/provider/cloud/deploy.yaml
mv deploy.yaml ingress.yaml

# infra/
# ├── ingress-nginx
# │   └── ingress.yaml
# └── ...

# update ingress.yaml
#
# ...
# apiVersion: v1
# kind: Service
# metadata:
#  annotations:
#   ...
#   service.beta.kubernetes.io/azure-dns-label-name: lab401 
#   ...
#   name: ingress-nginx-controller
#   namespace: ingress-nginx
# spec:
#   type: LoadBalancer
#   ...
#   selector:
#   ...
#   loadBalancerSourceRanges:
#   - 80.80.4.0/27
#   - 212.237.135.190/32
``` 

## Storage classes

```bash
# infra/
# ├── ...
# └── storage-class
#     ├── storage-class-RWX-azure-files.yaml
#     └── storage-class-RWX-nfs-provider.yaml
```

### NFS Provisioner

```yaml
...
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: 10.0.0.7
            - name: NFS_PATH
              value: /nfs/aks-pv
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.0.0.7
            path: /nfs/aks-pv
...
apiVersion: storage.k8s.io/v1
kind: StorageClass
...
parameters:
  pathPattern: "${.PVC.namespace}/${.PVC.name}"
  onDelete: delete
```

### Azure files

> dir_mode and file_mode are 777, all mounted as root

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: sas-azurefile
provisioner: kubernetes.io/azure-file
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1001
  - gid=1001
parameters:
  skuName: Standard_LRS
allowVolumeExpansion: true
```

