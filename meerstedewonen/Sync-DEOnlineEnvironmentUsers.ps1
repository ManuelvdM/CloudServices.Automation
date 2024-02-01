param(
    # Environment variables
    [Parameter(Mandatory = $false)][string] $SourceEnvironmentName = $env:SOURCEENVIRONMENTNAME,
    [Parameter(Mandatory = $false)][string] $TargetEnvironmentName = $env:TARGETENVIRONMENTNAME,
    # Static parameters
    [Parameter(Mandatory = $false)][string] $ResourceGroupName = "SYS-Automation",
    [Parameter(Mandatory = $false)][string] $RefreshTokenKeyvaultName = "SYS-Automation-CS",
    [Parameter(Mandatory = $false)][string] $RefreshTokenKeyvaultSecretName = "RefreshTokenAutomation",
    [Parameter(Mandatory = $false)][string] $CompanyName = "MeerstedeWonen"
)

Write-Output "##[section] Starting: Installing bccontainerhelper modules"
Install-Module -Name 'bccontainerhelper' -Repository PSGallery -Force
Write-Output "##[section] Finishing: Installing bccontainerhelper modules"

Write-Output "Start Getting RefreshToken from Keyvault"
$RefreshToken = Get-AzKeyVaultSecret -VaultName $RefreshTokenKeyvaultName -Name $RefreshTokenKeyvaultSecretName -AsPlainText
Write-Output "Finished Getting RefreshToken from Keyvault"

$Context = New-BcAuthContext -refreshToken $RefreshToken
$Header = @{Acceptlanguage="nl-NL";Authorization="Bearer $($Context.accesstoken)";"Content-Type"="application/json" }

#Get Company Id
$AutomationURL= "https://api.businesscentral.dynamics.com/v2.0/$SourceEnvironmentName/api/microsoft/automation/v2.0/companies" 
$CompanyId = ((Invoke-RestMethod -Uri $AutomationURL -Method GET -Headers $Header).value | Where-Object {$_.name -eq $($CompanyName)}).id

#Get Enabled Users MeerstedeWonen
$UserAutomationURL = $AutomationURL + "($CompanyId)/users?`$top`=1"
$MeerstedeWonenUsers = (Invoke-RestMethod -Uri $UserAutomationURL -Method GET -Headers $Header).value | where-object {$_.state -eq "Enabled"} 

#GetNewUsersFromOffice365 from Production environment
Write-Output "##[section] Starting: Get New User From Office 365"
$GetNewUserFromOffice365URL = $UserAutomationURL = $AutomationURL + "($CompanyId)/users($($MeerstedeWonenUsers.userSecurityId))/Microsoft.NAV.getNewUsersFromOffice365"
Invoke-RestMethod -Uri $GetNewUserFromOffice365URL -Method POST -Headers $Header 
Write-Output "##[section] Finished: Get New User From Office 365"