:: script creates an azure function that serves as a monitor for Azure Database for PostgreSQL Query Store
@setlocal enableextensions enabledelayedexpansion
@echo off
if "%~1"=="" goto blank_required_argument
if "%~2"=="" goto blank_required_argument

set resourceGroupName=%1
set resourceGroupLocation=%2
set subscriptionGuid=%3

call az login

:: if a specific subscription guid is not provided, it will use your default
if not "%~3"=="" (call az account set -s %subscriptionGuid%)

:: check if the resourcegroup exists and create if not
for /f "tokens=* usebackq" %%f in (`call az group exists -g  %resourceGroupName%`) do (
	set var=%%f
)

if %var%==true ( echo "---> Resource group:" %resourceGroupName% "already exists.")
if %var%==false ( echo "---> Creating resource group: " %resourceGroupName% && call az group create -g %resourceGroupName% -l %resourceGroupLocation%)

:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
:: +++++++++++++++++++++++++ SET VALUES AS APPROPRIATE ++++++++++++++++++++++++++++++++
:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
set functionAppName=qsmonitoring
set keyVaultName=kikv14
set mailTo=opiferous@live.com
set senderAccount=dummy_sender@outlook.com
set smtpServer=smtp.office365.com

:: your secrets will be stored with below secret names in the keyvault
set keyVaultConnectionStringSecretName=pgConnectionString
set keyVaultSenderAccountSecretName=senderSecret

set templateFilePath="./arm/azuredeploy.json"
set parameterFilePath="./arm/azuredeploy.parameters.json"

set cronIntervalSetting="CronTimerInterval=0 */1 * * * *"

:: if ifQuery generates a result then the function will parse the queries in thenQueries will be parsed out and executed to attach to the alert
set ifQuerySetting="SENDMAILIF_QUERYRETURNSRESULTS=SELECT pid FROM pg_stat_activity WHERE age(clock_timestamp(),query_start) > interval '5 minutes' AND usename NOT like 'postgres' AND state  like 'active'"
set thenQueriesSetting="LIST_OF_QUERIESWITHSUPPORTINGDATA={""LONG_QUERY_PSQL_STRING"":""SELECT datname as Database, pid as Process_ID, usename as Username, query,client_hostname,state, now() - query_start as Query_Duration, now() - backend_start as Session_Duration FROM pg_stat_activity WHERE age(clock_timestamp(),query_start) > interval '5 minutes' AND state like 'active' AND usename NOT like 'postgres' ORDER BY 1 desc;"",""LIST_OF_PROCESSES"":""select now()-query_start as Running_Since,pid,client_hostname,client_addr, usename, state, left(query,60) as query_text from pg_stat_activity;""}"

echo "---> Getting the uri for the keyvault specified"

:: create keyvault or get the keyvault uri
for /f "tokens=1,2 delims=,}{ usebackq" %%I in (`az keyvault create --name %keyVaultName% --resource-group %resourceGroupName%`) do (
	set "vaultAddressField=%%I"
	set "vstripped=!vaultAddressField:": "=|!"
	:: use substitution to check if the current token is containts the vaultUri
	if not "!vaultAddressField:vaultUri=!"=="!vaultAddressField!" (
		rem echo !vstripped!
		for /f "tokens=1,2 delims=|" %%J in (!vstripped!) do (
			set "vaultAddress=%%K"
			goto kv_break
		)
	)
)
:kv_break

set keyVaultUriSetting="KeyVaultUri=%vaultAddress%"

:: these settings do not include any special characters like for az cli config settings. Special characters include space and *
:: you can add additional settins here by delimiting it with a space
:: e.g. "setting1=abc setting2=defg"
set qsMonitoringAppSettings="MAIL_TO=%mailTo% SMTP_SERVER=%smtpServer% CONNECTION_STRING_SECRET_NAME=%keyVaultConnectionStringSecretName% SENDER_ACCOUNT_SECRET_NAME=%keyVaultSenderAccountSecretName% SENDER_ACCOUNT=%senderAccount%"

:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

:: set delimiter to null
set delimiter=
set dateString=%date:~-4,4%%delimiter%%date:~-7,2%%delimiter%%date:~-10,2%
set timeString=%time%
:: trim off miliseconds
set timeString=%timeString:~0,-3%

:: replace ':'
set timeString=%timeString::=!delimiter!%

:: substitute leading spaces with a zero
set deploymentName= %functionAppName%%dateString%%timeString: =0%

:: deploy the function and update the settings
:: remove below comment if you want to use a json file for the parameters instead
:: call az group deployment create --name %deploymentName% --resource-group %resourceGroupName% --template-file %templateFilePath% --parameters %parameterFilePath% --verbose
call az group deployment create --name %deploymentName% --resource-group %resourceGroupName% --template-file %templateFilePath% --parameters "{""appName"":{""value"":""%functionAppName%""}}" --verbose
echo "---> Deploying qs monitoring function"
call az functionapp deployment source config-zip -g %resourceGroupName% -n %functionAppName% --src "./zip/Alert.zip" --verbose

echo "---> Updating configuration settings"

call az functionapp config appsettings set --resource-group %resourceGroupName% --name %functionAppName%  --settings "%qsMonitoringAppSettings%" %cronIntervalSetting% %ifQuerySetting% %thenQueriesSetting% %keyVaultUriSetting%

echo "---> Getting the system assigned identity for the function"

:: get principal id of function app. assign option will create if no system assigned identity exists or return existing one
for /f "tokens=1,2 delims=,}:{ usebackq" %%I in (`az functionapp identity assign --name %functionAppName% --resource-group  %resourceGroupName%`) do (
	set "principalIdField=%%I"
	set "principalId=%%J"
	:: use substitution to check if the curret token is principalId
	if not "!principalIdField:prin=!"=="!principalIdField!" goto fn_break
)
:fn_break

echo "---> Adding the system assigned identity for the function to the keyvault to set the appropriate policy"

:: adding the identity of the function to the keyvault to set policy
call az keyvault set-policy --name %keyVaultName% --object-id %principalId% --secret-permissions get

echo "---> Sleeping for 60 seconds to workaround keyvault dns propagation"
timeout /t 60 /nobreak
echo "---> Setting up the required keyvault secrets"

:: adding keyvault secrets as outlined above with temporary values. you will need to update the values to the actual ones as appropriate
:: sample connection string to store
:: Server=YourServerName.postgres.database.azure.com;Database=azure_sys;Port=5432;User Id=YourUser@YourServerName;Password=YourPassword;SslMode=Require;
call az keyvault secret set --vault-name %keyVaultName% --name %keyVaultConnectionstringSecretName% --value 'Pa$$w0rd'
call az keyvault secret set --vault-name %keyVaultName% --name %keyVaultSenderAccountSecretName% --value 'Pa$$w0rd'

echo "---> Secrets set. Please don't forget to update it to real vaules if you haven't changed the vaulues above"
echo "---> Though secrets are encrypted in transit or at rest, if you want function to access secrets over your vnet and not through public internet,"
echo "---> you will need to configure VNet on the function app, keyvault."
echo "---> ************** <---"

@echo on
endlocal
exit /B

:blank_required_argument
echo "---> one of the required arguments is missing <---"
echo "---> example: DeployFunction.bat <ResourceGroupName> <AzureRegion> [<SubscriptionGuid>]"
exit /B