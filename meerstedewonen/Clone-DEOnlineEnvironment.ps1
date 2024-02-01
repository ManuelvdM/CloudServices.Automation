param(
    # Environment variables
    [Parameter(Mandatory = $false)][string] $SourceEnvironmentName = $env:SOURCEENVIRONMENTNAME,
    [Parameter(Mandatory = $false)][string] $TargetEnvironmentName = $env:TARGETENVIRONMENTNAME,
    [Parameter(Mandatory = $false)][string] $BackupEnvironment = $env:BACKUPENVIRONMENT,
    # Static parameters
    [Parameter(Mandatory = $false)][string] $ResourceGroupName = "SYS-Automation",
    [Parameter(Mandatory = $false)][string] $RefreshTokenKeyvaultName = "SYS-Automation-CS",
    [Parameter(Mandatory = $false)][string] $RefreshTokenKeyvaultSecretName = "RefreshTokenAutomation"
)

Write-Output "##[section] Starting: Installing bccontainerhelper modules"
Install-Module -Name 'bccontainerhelper' -Repository PSGallery -Force
Write-Output "##[section] Finishing: Installing bccontainerhelper modules"

Write-Output "Start Getting RefreshToken from Keyvault"
$RefreshToken = Get-AzKeyVaultSecret -VaultName $RefreshTokenKeyvaultName -Name $RefreshTokenKeyvaultSecretName -AsPlainText
Write-Output "Finished Getting RefreshToken from Keyvault"

$Context = New-BcAuthContext -refreshToken $RefreshToken
$Header = @{Acceptlanguage="nl-NL";Authorization="Bearer $($Context.accesstoken)";"Content-Type"="application/json" }

# BaseUrl admin api
$BaseURL= "https://api.businesscentral.dynamics.com//admin/v2.19/applications/DEOnline/environments"

# Get Admin Center Environments    
$Environments = (Invoke-RestMethod -Uri $BaseURL -Method GET -Headers $Header).value

#Rename Environment
if ($BackupEnvironment -eq "1") {
    Write-Output "##[section] Starting: Rename of Environment"
    $Body = @{NewEnvironmentName="$($TargetEnvironmentName)" + "_oud"}
    $json = $Body | ConvertTo-Json
    $Environments = Invoke-RestMethod -Uri "$BaseURL/$TargetEnvironmentName/rename" -Method POST -Body $json -Verbose -Headers $Header
    Write-Output "##[section] Finished: Rename of Environment"
}
else {
    # Remove Admin Center Environments
    Write-Output "##[section] Starting: Remove of Environment"
    $Environments = Invoke-RestMethod -Uri "$BaseURL/$TargetEnvironmentName" -Method DELETE -Headers $Header
}

#Check if Environment is removed
$Environments = (Invoke-RestMethod -Uri "$BaseURL" -Method GET -Headers $Header).value | Where-Object {$_.name -eq $TargetEnvironmentName}
while (($Environments.status -eq "Active") -or ($Environments.status -eq "SoftDeleting")) {
    Write-Output "Environment $TargetEnvironmentName is not removed yet"
    sleep 15
    $Environments = (Invoke-RestMethod -Uri "$BaseURL" -Method GET -Headers $Header).value | Where-Object {$_.name -eq $TargetEnvironmentName}
}
Write-Output "##[section] Finished: Remove of Environment"

#Copy Environment
$Body = @{environmentName=$TargetEnvironmentName;type="Sandbox"}
$json = $Body | ConvertTo-Json
$Environments = Invoke-RestMethod -Uri "$BaseURL/$SourceEnvironmentName/copy" -Method POST -Body $json -Verbose -Headers $Header

Write-Output "##[section] Starting: Clone of environment $SourceEnvironmentName to $TargetEnvironmentName is succesfully scheduled"
sleep 15
$Environments = (Invoke-RestMethod -Uri "$BaseURL" -Method GET -Headers $Header).value | Where-Object {$_.name -eq $TargetEnvironmentName}

while ($Environments.status -eq "Preparing") {
    Write-Output "Environment $TargetEnvironmentName is preparing"
    sleep 15
    $Environments = (Invoke-RestMethod -Uri "$BaseURL" -Method GET -Headers $Header).value | Where-Object {$_.name -eq $TargetEnvironmentName}
}

Write-Output "##[section] Finished: Clone of environment $SourceEnvironmentName to $TargetEnvironmentName"


