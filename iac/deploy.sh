zipName=funcapp.zip
location='australiaeast'
appName='todo-api'
rgName="$appName-func-rg"
adminObjectId='57963f10-818b-406d-a2f6-6e758d86e259'
sqlAdminUserPassword='M1cr0soft1234567890'

# compile app
cd ../api
go build -o handler

# compress funtion app code to .zip file
zip -r ../iac/$zipName *

cd ../iac

az group create \
    --location $location \
    --name $rgName

az deployment group create \
    --name 'infra-deployment' \
    --resource-group $rgName \
    --template-file ./main.bicep \
    --parameters location=$location \
    --parameters appName=$appName \
    --parameters environment='dev' \
    --parameters sqlAdminUserPassword=$sqlAdminUserPassword \
    --parameters adminObjectId=$adminObjectId

functionName=$(az deployment group show \
    --name 'infra-deployment' \
    --resource-group $rgName \
    --query properties.outputs.functionName.value -o tsv)

echo "functionName: $functionName"

# deploy web app code as zip file
az webapp deployment source config-zip \
    --resource-group $rgName \
    --name $functionName \
    --src ./$zipName