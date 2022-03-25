#/bin/bash

AZUSERID="b1a68f3c-0cb9-4ceb-8c26-a4db264c2885"
TENANTID="b1c14d5c-3625-45b3-a430-9552373a0c2f"

az login --service-principal --username $AZUSERID --tenant $TENANTID --password AzureServicePrincipalCerts/aom-infra-sp-cert.pem