#!/bin/bash -x

# script creates an azure function that serves as a monitor for Azure Database for PostgreSQL Query Store

resourceGroupName=$1
resourceGroupLocation=$2
subscriptionGuid=$3

templateFilePath="./arm/azuredeploy.json"
parameterFilePath="./arm/azuredeploy.parameters.json"

dateToken=`date '+%Y%m%d%H%M'`
deploymentName="qs-monitoring"$dateToken

#az.cmd login

# You can select a specific subscription if you do not want to use the default
az.cmd account set -s $subscriptionGuid

if !( $(az.cmd group exists -g  $resourceGroupName) ) then
    echo "---> Creating resource group: " $resourceGroupName
    az.cmd group create -g $resourceGroupName -l $resourceGroupLocation
else
    echo "---> Resource group:" $resourceGroupName "already exists."
fi

az.cmd group deployment create --name $deploymentName --resource-group $resourceGroupName --template-file $templateFilePath --parameters $parameterFilePath --verbose

echo "---> Deploying qs monitoring function"
az.cmd functionapp deployment source config-zip -g $resourceGroupName -n qsmonitoring --src "./zip/Alert.zip"

qsMonitoringAppSettings="MAIL_TO=___@live.com SMTP_SERVER=smtp.office365.com" 
#cronIntervalSettings="CronTimerInterval=0 */1 * * * *"

az.cmd functionapp config appsettings set --resource-group $resourceGroupName --name qsmonitoring  --settings ${qsMonitoringAppSettings} "CronTimerInterval=0 */1 * * * *" --debug

echo "---> done <---"