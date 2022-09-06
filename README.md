# Hosting an Azure function on an App Service Environment (Isolated v3)

This example shows how to deploy an Azure function into an App Service Environment v3 (ASE) environment. 

The example todo list application is written on Go and implemented using [Azure Function custom handlers](https://docs.microsoft.com/en-us/azure/azure-functions/functions-custom-handlers). The application is compiled to a single binary file named 'handler' during the docker image build in Azure Container Registry.

## Pre-requisites

- Bash or WSL shell environment
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

## Deployment
- clone this repo [azure-iac-examples](https://github.com/cbellee/todo-api-func-asev3)
- change working directory to `./scripts` 
  ```
  $ cd ./scripts
  ```
- optionally, modify the deployment location & resource group name

  ```
  RG_NAME='aca-func-go-rg'
  LOCATION='australiaeast'
  ```

- deploy the sample
    ```
    $ ./deploy.sh
    ```

- script deployment steps
  - deploy resource group
  - deploy Azure Container Registry (ACR)
  - build container image in ACR
  - deploy App Service environment
    - Azure Monitor workspace
    - Function container app