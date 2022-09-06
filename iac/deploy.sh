#!/bin/bash

# zipName=funcapp.zip
LOCATION='australiaeast'
APP_NAME='todo-api'
RG_NAME="$APP_NAME-func-asev3-rg"

ENVIRONMENT=dev
SEMVER=0.1.0
TAG="$ENVIRONMENT-$SEMVER"
IMAGE="func-api:$TAG"

az group create --name $RG_NAME --location $LOCATION

az deployment group create \
--resource-group $RG_NAME \
--name 'acr-deployment' \
--template-file ./modules/acr.bicep \
--parameters location=$LOCATION

ACR_NAME=$(az deployment group show --resource-group $RG_NAME --name 'acr-deployment' --query properties.outputs.acrName.value -o tsv)

# build image in ACR
az acr build -r $ACR_NAME -t $IMAGE -f ../func/Dockerfile ../func

# create a file named '.env' in the same directory as this script 
# add the line below to the file 
# sqlAdminUserPassword=<your password> 
# dot-source the ./.env file to load the password as an env var

# . ./.env

# compile app
# 'handler' executable is referenced in ../api/host.json '"defaultExecutablePath": "handler"'

# cd ../api
# go build -o handler

# compress funtion app code to .zip file
# you'll need to install the 'zip' package first
# $ apt install zip

# zip -r ../iac/$zipName *

# cd ../iac

az deployment group create \
    --name 'infra-deployment' \
    --resource-group $RG_NAME \
    --template-file ./main.bicep \
    --parameters location=$LOCATION \
    --parameters appName=$APP_NAME \
    --parameters environment='dev' \
    --parameters containerImageName="$ACR_NAME.azurecr.io/$IMAGE" \
    --parameters acrName=$ACR_NAME

#functionName=$(az deployment group show \
#    --name 'infra-deployment' \
#    --resource-group $RG_NAME \
#    --query properties.outputs.functionName.value -o tsv)

#echo "functionName: $functionName"

# deploy web app code as zip file
#az webapp deployment source config-zip \
#    --resource-group $RG_NAME \
#    --name $functionName \
#    --src ./$zipName