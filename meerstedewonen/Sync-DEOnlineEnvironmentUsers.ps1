param(
    # Environment variables
    [Parameter(Mandatory = $false)][string] $AccountsKeyVaultName = $env:ACCOUNTSKEYVAULTNAME,
    [Parameter(Mandatory = $false)][string] $GeneralKeyVaultName = $env:GENERALKEYVAULTNAME,
    [Parameter(Mandatory = $false)][string] $SourceEnvironmentName = $env:SOURCEENVIRONMENTNAME,
    [Parameter(Mandatory = $false)][string] $TargetEnvironmentName = $env:TARGETENVIRONMENTNAME,
    [Parameter(Mandatory = $false)][string] $BackupEnvironment = $env:BACKUPENVIRONMENT,
    # Static parameters
    [Parameter(Mandatory = $false)][string] $ResourceGroupName = "DEOnline-Automation",
    [Parameter(Mandatory = $false)][string] $RefreshTokenKeyvaultName = "deonline-keyvault",
    [Parameter(Mandatory = $false)][string] $RefreshTokenKeyvaultSecretName = "RefreshTokenAutomation"
)

Write-Output "Start Import Module BCContainerHelper"
Import-Module bccontainerhelper
Write-Output "Finished Import Module BCContainerHelper"

Write-Output "Start Getting RefreshToken from Keyvault"
$RefreshToken = Get-AzKeyVaultSecret -VaultName $RefreshTokenKeyvaultName -Name $RefreshTokenKeyvaultSecretName -AsPlainText
Write-Output "Finished Getting RefreshToken from Keyvault"

$Context = New-BcAuthContext -refreshToken $RefreshToken
$Header = @{Acceptlanguage="nl-NL";Authorization="Bearer $($Context.accesstoken)";"Content-Type"="application/json" }

$Environment = "Production"
$CompanyName = "MeerstedeWonen"

#Get Company Id
$AutomationURL= "https://api.businesscentral.dynamics.com/v2.0/$Environment/api/microsoft/automation/v2.0/companies" 
$CompanyId = ((Invoke-RestMethod -Uri $AutomationURL -Method GET -Headers $Header).value | Where-Object {$_.name -eq $($CompanyName)}).id

#Get Enabled Users MeerstedeWonen
$UserAutomationURL = $AutomationURL + "($CompanyId)/users?`$top`=1"
$MeerstedeWonenUsers = (Invoke-RestMethod -Uri $UserAutomationURL -Method GET -Headers $Header).value | where-object {$_.state -eq "Enabled"} 

#GetNewUsersFromOffice365 from Production environment
$GetNewUserFromOffice365URL = $UserAutomationURL = $AutomationURL + "($CompanyId)/users($($MeerstedeWonenUsers.userSecurityId))/Microsoft.NAV.getNewUsersFromOffice365"
Invoke-RestMethod -Uri $GetNewUserFromOffice365URL -Method POST -Headers $Header 
