
# login as a user and set the appropriate subscription ID
az login

export SUBSCRIPTION_ID=$(az account show --query id --output tsv)
export TENANT_ID=$(az account show --query tenantId  --output tsv)

export KEYVAULT_RESOURCE_GROUP="<resource-group>"
export KEYVAULT_LOCATION="<location>"
export KEYVAULT_NAME="<keyvault-name>"

# add and install the secret-store-provider for azure keyvault with helm
helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
helm install csi csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --set secrets-store-csi-driver.syncSecret.enabled=true

# if you don't have a keyvault create one
az group create -n ${KEYVAULT_RESOURCE_GROUP} --location ${KEYVAULT_LOCATION}
az keyvault create -n ${KEYVAULT_NAME} -g ${KEYVAULT_RESOURCE_GROUP} --location ${KEYVAULT_LOCATION}

# add secret
az keyvault secret set --vault-name ${KEYVAULT_NAME} --name secret1 --value "Hello\!"

# (OPTIONAL) Create a service principal to access keyvault
export SERVICE_PRINCIPAL_CLIENT_SECRET="$(az ad sp create-for-rbac --skip-assignment --name http://kv-secret-test --query 'password' -otsv)"
export SERVICE_PRINCIPAL_CLIENT_ID="$(az ad sp show --id http://kv-secret-test --query 'appId' -otsv)"

az keyvault set-policy -n ${KEYVAULT_NAME} --secret-permissions get --spn ${SERVICE_PRINCIPAL_CLIENT_ID}

# only when accessing with service principal, create secret for SP
kubectl create secret generic secrets-store-creds --from-literal clientid=${SERVICE_PRINCIPAL_CLIENT_ID} --from-literal clientsecret=${SERVICE_PRINCIPAL_CLIENT_SECRET}
kubectl label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

# create a storage provider class
cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kvname
  namespace: default
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    userAssignedIdentityID: ""
    keyvaultName: "${KEYVAULT_NAME}"
    objects: |
      array:
        - |
          objectName: secret1              
          objectType: secret
          objectVersion: ""
    tenantId: "${TENANT_ID}"
EOF

# test pod, secret is available in pod mounted /mnt/secrets-store
cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: busybox-secrets-store-inline
spec:
  containers:
  - name: busybox
    image: k8s.gcr.io/e2e-test-images/busybox:1.29
    command:
      - "/bin/sleep"
      - "10000"
    volumeMounts:
    - name: secrets-store-inline
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kvname"
        nodePublishSecretRef:                       # Only required when using service principal mode
          name: secrets-store-creds                 # Only required when using service principal mode
EOF