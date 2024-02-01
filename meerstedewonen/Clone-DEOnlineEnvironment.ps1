param(
    # Environment variables
    [Parameter(Mandatory = $false)][string] $AccountsKeyVaultName = $env:ACCOUNTSKEYVAULTNAME,
    [Parameter(Mandatory = $false)][string] $GeneralKeyVaultName = $env:GENERALKEYVAULTNAME,
    [Parameter(Mandatory = $false)][string] $SourceEnvironmentName = $env:SOURCEENVIRONMENTNAME,
    [Parameter(Mandatory = $false)][string] $TargetEnvironmentName = $env:TARGETENVIRONMENTNAME,
    [Parameter(Mandatory = $false)][string] $BackupEnvironment = $env:BACKUPENVIRONMENT,
    [Parameter(Mandatory = $false)][string] $ResourceGroupName = $env:RESOURCEGROUPNAME,
    # Static parameters
    [Parameter(Mandatory = $false)][string] $ResourceGroupName = "DEOnline-Automation",
    [Parameter(Mandatory = $false)][string] $RefreshTokenKeyvaultName = "deonline-keyvault"
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

# BaseUrl admin api
$BaseURL= "https://api.businesscentral.dynamics.com//admin/v2.19/applications/DEOnline/environments"

# Get Admin Center Environments    
$Environments = (Invoke-RestMethod -Uri $BaseURL -Method GET -Headers $Header).value

#Rename Enviroment
if ($BackupEnvironment) {
 $Body = @{NewEnvironmentName="$($EnvironmentToRename)" + "_oud"}
 $json = $Body | ConvertTo-Json
 $Environments = Invoke-RestMethod -Uri "$BaseURL/$EnvironmentToRename/rename" -Method POST -Body $json -Verbose -Headers $Header
}

# Remove Admin Center Environments
$Environments = Invoke-RestMethod -Uri "$BaseURL/$TargetEnvironmentName" -Method DELETE -Headers $Header

#Check if Environment is removed
$Environments = (Invoke-RestMethod -Uri "$BaseURL" -Method GET -Headers $Header).value | Where-Object {$_.name -eq $TargetEnvironmentName}
while (($Environments.status -eq "Active") -or ($Environments.status -eq "SoftDeleting")) {
    Write-Output "Environment $TargetEnvironmentName is not removed yet"
    sleep 15
    $Environments = (Invoke-RestMethod -Uri "$BaseURL" -Method GET -Headers $Header).value | Where-Object {$_.name -eq $TargetEnvironmentName}
}
Write-Output "Environment $TargetEnvironmentName succesfully removed"

#Copy Environment
$Body = @{environmentName=$TargetEnvironmentName;type="Sandbox"}
$json = $Body | ConvertTo-Json
$Environments = Invoke-RestMethod -Uri "$BaseURL/$SourceEnvironmentName/copy" -Method POST -Body $json -Verbose -Headers $Header

Write-Output "Clone of environment $SourceEnvironmentName to $TargetEnvironmentName is succesfully scheduled"
sleep 15
$Environments = (Invoke-RestMethod -Uri "$BaseURL" -Method GET -Headers $Header).value | Where-Object {$_.name -eq $TargetEnvironmentName}

while ($Environments.status -eq "Preparing") {
    Write-Output "Environment $TargetEnvironmentName is preparing"
    sleep 15
    $Environments = (Invoke-RestMethod -Uri "$BaseURL" -Method GET -Headers $Header).value | Where-Object {$_.name -eq $TargetEnvironmentName}
}

Write-Output "Environment $TargetEnvironmentName succesfully created"

