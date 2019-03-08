# Azure Database for PostgreSQL - Query Store Monitoring
Azure Database for PostgreSQL Query Store records how your queries do over time. This information comes handy when you want to be notified of anomalies 
such as long running queries or blocked processes. The following example intends give you a starting point for a near real time monitoring and alerting
mechanism.
## Prerequisites
* [Install the Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [Install AzureRM](https://www.powershellgallery.com/packages/AzureRM.Resources/6.7.3)


## Troubleshooting
### I cannot deploy
#### The provided grant has expired...
If you are getting an error like
>Get Token request returned http error: 400 and server response: {"error":"invalid_grant","error_description":"AADSTS50173: The provided grant has expired due to it being revoked.... 

run the following in your command prompt

`az account clear`  
`az login`
#### Script cannot find a file during execution
Please ensure that you are not running in Windows Powershell ISE.

#### Name mismatch issue during deployment
If your function deployment complains about the name mismatch, please ensure what you are providing for functionAppName value and what is in ./arm/azuredeploy.parameters.json as appName is matching

#### WebApp already exists
FunctionApp names have to be universally unique. You can update the deployment on an existing functionapp, provided that you are using the same resourcegroup.

#### Keyvault already exists
Although not required, this script uses the same region same resource group for the keyvault.

### I'd like to check if my function is working
You can locate the log file of your deployment under the ./logs folder. To check whether or not your function is functioning properly, you can go to Azure portal and search for your
function app and locate `PingMyDatabase` function or the name you used if you changed the code. The log stream, if all goes well, should periodically get your secrets from keyvault
and connect to database. If you are seeing errors in the stream refer to this section.
#### No such host is known
Your connection string is most likely malformed. Please ensure that it is in the following format:
`host=yourdbinstance.postgres.database.azure.com;port=5432;database=azure_sys;username=youruser@yourdbinstance;password=yourpassword;sslmode=Require`

### I want to change stuff
You can go to portal and locate your function app. In order to change app settings, locate FunctionAppSettings, click Manage Application Settings and save your settings after your changes


|Case|SettingName|  
|---|---|  
|Frequency of runs|CronTimerInterval|  
|Who to mail to|MAIL_TO|  
|Alert condition|SENDMAILIF_QUERYRETURNSRESULTS|  

#### I just want to deploy a bare function app
If you want to do a simple function app deployment on a standard asp, you can also use below custom template but you will need to deploy the function app from your
solution yourself.

## Current shortcomings
Please note that this is not a full-fledged alerting solution! Among the missing capabilities that might end up annoying you is the deduplication process in an incident management solution you'd expect.
Choosing your cron interval for the function and choosing a proper lookback period to evaluate your alerting condition will probably help reduce noise level of your monitor until a time we can add such
a capability here.

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchisqrd%2Fqs-monitoring%2Fmaster%2Farm%2Fazuredeploy.json) 
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fchisqrd%2Fqs-monitoring%2Fmaster%2Farm%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

## References
* [How to deploy Azure Functions with zip push](http://www.frankysnotes.com/2018/06/how-to-deploy-your-azure-functions.html)
* [A bit more about zip-file deployments](https://medium.com/@fboucheros/how-to-deploy-your-azure-functions-faster-and-easily-with-zip-push-23e15d79599a)
* If you choose to run the bash script, here is [how to set up your bash in windows to run az cli](https://medium.com/azure-developers/the-ultimate-guide-to-setting-up-the-azure-cli-on-windows-adeda6c6b7e1)
