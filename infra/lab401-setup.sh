#!/bin/bash

echo
echo "###############################################################################"
echo "Infrastructure setup for lab401"
echo "###############################################################################"
echo

# PRE-ALLOCATE: Azure Container Registry
ACR_RESOURCE_GROUP="aom-container-registry"
AOM_CONTAINER_REGISTRY_NAME="aomdk"

######################################################################################
#                                    START
######################################################################################

AZ_LOCATION="northeurope"

echo "> AZ Location: $AZ_LOCATION"
echo

#---------------------------------------------------------------------------------
# RESOURCE GROUP
#---------------------------------------------------------------------------------

VIYA4_RESOURCE_GROUP="aom-lab401"

echo "---------------------------------------------------------------------------"
echo "> Creating Resource Group $VIYA4_RESOURCE_GROUP"

az group create --location "$AZ_LOCATION" --name "$VIYA4_RESOURCE_GROUP"

rgId=`echo $jsonResponse | jq -r ".id"`
provisioningState=`echo $jsonResponse | jq -r ".properties.provisioningState"`
echo "  provisioningState: $provisioningState"
echo "  id: $rgId"
echo

## To check if rg exists:
## az group list --query "[?name=='aom-lab401-rgd']"

#---------------------------------------------------------------------------------
# AKS SUBNET
#---------------------------------------------------------------------------------

NORDICLABS_VNET_NAME="sas-aom-test-win-vnet"
NORDICLABS_VNET_RG="aom-network"

AKS_VNET_DNS_LIST="10.0.0.6 8.8.8.8"
AKS_VNET_NAME="lab401-vnet"
AKS_VNET_ADDR_PREFIX="10.20.0.0/24"  #10.20.0.[0..255]
AKS_SUBNET_NAME="lab401-aks-subnet"
AKS_SUBNET_ADDR_PREFIX="10.20.0.0/26" #10.20.0.[0..63]

echo "---------------------------------------------------------------------------"

# Check if vnet just exists
AKS_VNET_ID=`az network vnet list \
             --resource-group $VIYA4_RESOURCE_GROUP  \
             -o tsv \
             --query "[?name=='$AKS_VNET_NAME'].id"`

echo "> Creating vnet $AKS_VNET_NAME and subnet $AKS_SUBNET_NAME"
jsonResponse=`az network vnet create --location $AZ_LOCATION \
                                    --resource-group $VIYA4_RESOURCE_GROUP \
                                    --name $AKS_VNET_NAME \
                                    --address-prefix $AKS_VNET_ADDR_PREFIX \
                                    --subnet-name $AKS_SUBNET_NAME \
                                    --subnet-prefix $AKS_SUBNET_ADDR_PREFIX \
                                    --dns-servers $AKS_VNET_DNS_LIST`

AKS_VNET_ID=`az network vnet list \
             --resource-group $VIYA4_RESOURCE_GROUP  \
             -o tsv \
             --query "[?name=='$AKS_VNET_NAME'].id"`

echo "  AKS_VNET_ID: $AKS_VNET_ID"

AKS_SUBNET_ID=`az network vnet subnet list \
              --resource-group $VIYA4_RESOURCE_GROUP \
              --vnet-name $AKS_VNET_NAME \
              -o tsv --query "[0].id"`

echo "  AKS_SUBNET_ID: $AKS_SUBNET_ID"
echo

# Peering 
echo "> Peering $AKS_VNET_NAME <--> $NORDICLABS_VNET_NAME"

NORDICLABS_VNET_ID=`az network vnet list \
                    --resource-group $NORDICLABS_VNET_RG  \
                    -o tsv \
                    --query "[?name=='$NORDICLABS_VNET_NAME'].id"`

jsonResponse=`az network vnet peering create \
              --name $AKS_VNET_NAME---$NORDICLABS_VNET_NAME \
              --remote-vnet $NORDICLABS_VNET_ID \
              --resource-group $VIYA4_RESOURCE_GROUP \
              --vnet-name $AKS_VNET_NAME \
              --allow-forwarded-traffic \
              --allow-gateway-transit \
              --allow-vnet-access`

echo "> Peering  $NORDICLABS_VNET_NAME <--> $AKS_VNET_NAME"

jsonResponse=`az network vnet peering create \
              --name $NORDICLABS_VNET_NAME---$AKS_VNET_NAME \
              --remote-vnet $AKS_VNET_ID \
              --resource-group $NORDICLABS_VNET_RG \
              --vnet-name $NORDICLABS_VNET_NAME \
              --allow-forwarded-traffic \
              --allow-gateway-transit \
              --allow-vnet-access`
echo

#---------------------------------------------------------------------------------
# AKS CREATION
#---------------------------------------------------------------------------------

VIYA4_CLUSTER_NAME="lab401-aks"
K8S_VERSION="1.22.4"
K8S_NODE_COUNT=1
AOM_CONTAINER_REGISTRY="aomdk"
NOSAS_NODEPOOL_NAME="nosas"
NOSAS_VM_SIZE="Standard_A8m_v2"
VIYA4_AKS_MANAGED_IDENTITY_NAME="viya401-aks-managed-identity"

echo "> Creating Maknaged Identity $VIYA4_AKS_MANAGED_IDENTITY_NAME for the AKS Cluster $VIYA4_CLUSTER_NAME"
echo
az identity create --name $VIYA4_AKS_MANAGED_IDENTITY_NAME --resource-group $VIYA4_RESOURCE_GROUP

VIYA4_AKS_MANAGED_IDENTITY_PRINCIPAL_ID=`az identity show --name $VIYA4_AKS_MANAGED_IDENTITY_NAME --resource-group $VIYA4_RESOURCE_GROUP -o tsv --query "principalId"`
echo "  VIYA4_AKS_MANAGED_IDENTITY_PRINCIPAL_ID= $VIYA4_AKS_MANAGED_IDENTITY_PRINCIPAL_ID"
VIYA4_AKS_MANAGED_IDENTITY_ID=`az identity show --name $VIYA4_AKS_MANAGED_IDENTITY_NAME --resource-group $VIYA4_RESOURCE_GROUP -o tsv --query "id"`
echo "  VIYA4_AKS_MANAGED_IDENTITY_ID= $VIYA4_AKS_MANAGED_IDENTITY_ID"
echo

echo "> Assign Network Contributor Role to $VIYA4_AKS_MANAGED_IDENTITY_NAME for the $AKS_SUBNET_NAME subnet"
az role assignment create --assignee $VIYA4_AKS_MANAGED_IDENTITY_PRINCIPAL_ID --role "Network Contributor" --scope $AKS_SUBNET_ID
echo
echo "> Creating AKS Cluster $VIYA4_CLUSTER_NAME"

az aks create --resource-group $VIYA4_RESOURCE_GROUP \
              --location $AZ_LOCATION \
              --name $VIYA4_CLUSTER_NAME \
              --kubernetes-version $K8S_VERSION \
              --network-plugin kubenet \
              --vnet-subnet-id $AKS_SUBNET_ID \
              --generate-ssh-keys \
              --enable-cluster-autoscaler \
              --node-count 1 \
              --min-count 1 \
              --max-count 2 \
              --nodepool-name $NOSAS_NODEPOOL_NAME\
              --node-vm-size ${NOSAS_VM_SIZE} \
              --attach-acr $AOM_CONTAINER_REGISTRY \
              --enable-managed-identity \
              --assign-identity $VIYA4_AKS_MANAGED_IDENTITY_ID
echo "   ..Done"

# AKS cluster will create a new Resource Group for the kubernetes resources (nodes, load balancer, ip addresses, etc.)
# - when using a public load balancer, the public IP address is used by the LB to connect to the K8S control pane

VIYA4_AKS_NODE_RG=`az aks show  --name $VIYA4_CLUSTER_NAME --resource-group $VIYA4_RESOURCE_GROUP --query "nodeResourceGroup" -o tsv`
echo "  VIYA4_AKS_NODE_RG: $VIYA4_AKS_NODE_RG"
echo
az resource list --resource-group $VIYA4_AKS_NODE_RG -o table
echo

#---------------------------------------------------------------------------------
# AKS CAS NODE POOL
#---------------------------------------------------------------------------------

CAS_NODEPOOL_NAME="cas"
CAS_VM_SIZE="Standard_E16s_v3"
echo
echo "> Add NodePool $CAS_NODEPOOL_NAME"

az aks nodepool add -g $VIYA4_RESOURCE_GROUP \
                    -n $CAS_NODEPOOL_NAME \
                    --cluster-name $VIYA4_CLUSTER_NAME \
                    --enable-cluster-autoscaler \
                    --node-count 1 \
                    --min-count 1 \
                    --max-count 2 \
                    --node-vm-size $CAS_VM_SIZE \
                    --node-taints "workload.sas.com/class=cas:NoSchedule" \
                    --labels "workload.sas.com/class"="cas"

#---------------------------------------------------------------------------------
# AKS SAS NODE POOL
#---------------------------------------------------------------------------------

SAS_NODEPOOL_NAME="sas"
SAS_VM_SIZE="Standard_A8m_v2"

echo
echo "> Add NodePool $SAS_NODEPOOL_NAME"

az aks nodepool add -g $VIYA4_RESOURCE_GROUP \
                    -n $SAS_NODEPOOL_NAME \
                    --cluster-name $VIYA4_CLUSTER_NAME \
                    --enable-cluster-autoscaler \
                    --node-count 1 \
                    --min-count 1 \
                    --max-count 5 \
                    --max-pods 150 \
                    --node-vm-size ${SAS_VM_SIZE} \
                    --labels "workload.sas.com/class"="compute" "launcher.sas.com/prepullImage"="sas-programming-environment"

echo

echo "> AKS resources"
echo
az resource list --resource-group $VIYA4_RESOURCE_GROUP -o table
echo
az resource list --resource-group $VIYA4_AKS_NODE_RG -o table
echo
az aks nodepool list --cluster-name $VIYA4_CLUSTER_NAME --resource-group $VIYA4_RESOURCE_GROUP --output table
echo

#---------------------------------------------------------------------------------
# RETRIEVE AKS CREDENTIALS
#---------------------------------------------------------------------------------

echo "-------------------------------------------------------------------------------"
echo 
echo "> Get cluster credentials"
az aks get-credentials --resource-group $VIYA4_RESOURCE_GROUP --name $VIYA4_CLUSTER_NAME
echo
echo "> Show cluster nodes"
echo
kubectl get nodes -o wide
echo
echo "> Show taints"
echo
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints --no-headers
echo
echo "> Show labels"
echo
kubectl get nodes --show-labels
echo
echo "-------------------------------------------------------------------------------"

#---------------------------------------------------------------------------------
# INGRESS
#---------------------------------------------------------------------------------

INGRESS_NAMESPACE="ingress-nginx"
#INGRESS_VERSION="v0.49.3"
INGRESS_VERSION="v1.1.1"

# ingress.yaml
#
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

echo "-------------------------------------------------------------------------------"
echo "> Deploy INGRESS $INGRESS_VERSION" 
echo
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-$INGRESS_VERSION/deploy/static/provider/cloud/deploy.yaml
kubectl apply -f ingress-nginx/ingress.yaml
sleep 5
echo "> Check services in $INGRESS_NAMESPACE"
echo
kubectl --namespace $INGRESS_NAMESPACE get services -o wide
sleep 5
echo "> Check Ingress version"
echo
POD_NAME=$(kubectl get pods -n $INGRESS_NAMESPACE -l app.kubernetes.io/name=ingress-nginx --field-selector=status.phase=Running -o name)
kubectl exec $POD_NAME -n $INGRESS_NAMESPACE -- /nginx-ingress-controller --version
echo

#---------------------------------------------------------------------------------
# NFS Providers + STORAGE CLASSES for RWX pvcs
#---------------------------------------------------------------------------------
echo "-------------------------------------------------------------------------------"
echo "> Create storage class sas-azurefile (it uses kubernetes.io/azure-file)"
kubectl apply -f storage-class/storage-class-RWX-azure-files.yaml

echo "> Create storage class nfs-client (it uses fs-subdir-external-provisioner:v4.0.2)"
kubectl apply -f storage-class/storage-class-RWX-nfs-provider.yaml
sleep 2
kubectl get sc -o wide
echo "-------------------------------------------------------------------------------"
echo

#---------------------------------------------------------------------------------
# Cert Manager
#---------------------------------------------------------------------------------
echo "-------------------------------------------------------------------------------"
echo "> Deploy cert-manager"
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
sleep 5
echo
kubectl get pods -n cert-manager -o wide
echo "-------------------------------------------------------------------------------"
echo



## az group delete --resource-group $VIYA4_RESOURCE_GROUP