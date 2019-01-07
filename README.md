# Azure Database for PostgreSQL - Query Store Monitoring
Azure Database for PostgreSQL Query Store records how your queries do over time. This information comes handy when you want to be notified of anomalies 
such as long running queries or blocked processes. The following example intends give you a starting point for a near real time monitoring and alerting
mechanism.
## Getting started
You can clone this repo and make changes to the function code as you wish or you can just deploy via the scripts provided by making the minimum changes that fits to
your environment. 

1. If you choose to deploy with the scripts provided, you will first need to provide some additional information within DeployFunction.bat file 
where it says 'SET VALUES AS APPROPRIATE' before you run this statement. 

:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

:: +++++++++++++++++ SET VALUES AS APPROPRIATE ++++++++++++++++++++++++

:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

We suggest that you define these values at a minimum here

|Variable|Notes|
|---|---|
|functionAppName|create a function app by this name if it does not already exist|
|keyVaultName|create a keyvault if not exists, else get the uri for the keyvault|
|mailTo|email adress that the alert will go to|
|senderAccount|email address that the alert will be sent from|
|smtpServer|smtp relay to be used|
|cronIntervalSetting|the frequency to run the alert on. Supports the standard cron syntax, e.g. CronTimerInterval=0 */1 * * * *
|ifQuerySetting|replace the query after SENDMAILIF_QUERYRETURNSRESULTS= with your own alert condition. If query returns any rows back, monitor will run then queries and send an email alert|
|thenQueriesSetting|expects a json doc that is in format {""QueryName"":""Query"",""QueryName"":""Query""} after LIST_OF_QUERIESWITHSUPPORTINGDATA=|


2. You will then need to run the following in a command prompt

```
DeployFunction.bat <ResourceGroupName> <AzureRegionName> [<SubscriptionGuid>]
```
Though the first two parameters are required, if you choose to not provide a subscription guid, it will use your default subscription. If resource group name you
provided does not exist, the script will create a resource group for you.

3. You can choose to provide your secrets to the keyvault within the script or you can just change it later via az cli or portal as you wish.

## How secure is this?
The script provides you with the means to store your secrets in a keyvault. Your secrets are always encrypted in-transit as well as at-rest. However, the function app 
does access the keyvault over internet. If you want to avoid this and access your secrets over your vnet through the backbone, you will need to configure a vnet for 
both your function app and your keyvault. Please be aware that vnet support of function apps is in preview and is currently only available in eastus. Once the proper
deployment scenarios are supported, we may revisit this script to accommodate this. Until then, you will need to configure vnet manually to accomplish below.

![Query Store Monitoring](https://github.com/chisqrd/qs-monitoring/blob/master/qsmonitoring.png)

## Deploying a bare function app
If you want to do a simple function app deployment on a standard asp, you can also use below custom template but you will need to deploy the function app from your
solution yourself.

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchisqrd%2Fqs-monitoring%2Fmaster%2Farm%2Fazuredeploy.json) 
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fchisqrd%2Fqs-monitoring%2Fmaster%2Farm%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

### References
* [How to deploy Azure Functions with zip push](http://www.frankysnotes.com/2018/06/how-to-deploy-your-azure-functions.html)
* [A bit more about zip-file deployments](https://medium.com/@fboucheros/how-to-deploy-your-azure-functions-faster-and-easily-with-zip-push-23e15d79599a)
* If you choose to run the bash script, here is [how to set up your bash in windows to run az cli](https://medium.com/azure-developers/the-ultimate-guide-to-setting-up-the-azure-cli-on-windows-adeda6c6b7e1)