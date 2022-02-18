# Viya 2020 lab401 deployment


|Offering	|Expiration Date|
|---------|---------------|
|SAS Visual Statistics	Sep 13, 2022|
|SAS IML	|Sep 13, 2022|
|SAS Intelligent Decisioning	|Sep 13, 2022|
|SAS Model Manager (on SAS Viya)	|Sep 13, 2022|
|SAS Studio Analyst	|Sep 13, 2022|
|SAS Visual Machine Learning	|Sep 13, 2022|
|SAS Visual Data Science Decisioning	|Sep 13, 2022|
|SAS Visual Text Analytics	|Sep 13, 2022|

<br>

|Component|version|
|---------|-------|
|Kubernetes|v1.22.4|
|Ingress-Nginx|v.1.1.1|
|Cert-manager| 1.5.x|
|kustomize|3.7.0|

### Kubernetes version (2022 Feb 18):

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

## Steps

### 1.Retrieve artifacts from `https://my.sas.com/en/my-orders/`

### 2.Update mirror


