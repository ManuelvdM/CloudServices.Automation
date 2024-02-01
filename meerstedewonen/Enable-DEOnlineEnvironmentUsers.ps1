param(
    # Environment variables
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

$Environment = $TargetEnvironmentName
$CompanyName = "MeerstedeWonen"

#Get Company Id
$AutomationURL= "https://api.businesscentral.dynamics.com/v2.0/$Environment/api/microsoft/automation/v2.0/companies" 
$CompanyId = ((Invoke-RestMethod -Uri $AutomationURL -Method GET -Headers $Header).value | Where-Object {$_.name -eq $($CompanyName)}).id

#Get Enabled Users MeerstedeWonen
$UserAutomationURL = $AutomationURL + "($CompanyId)/users"
$MeerstedeWonenUsers = (Invoke-RestMethod -Uri $UserAutomationURL -Method GET -Headers $Header).value | where-object {$_.state -eq "Enabled"}

#Test with Alwin.goessens
#$MeerstedeWonenUsers = $MeerstedeWonenUsers | Where-Object {$_.userName -eq "ALWIN.GOESSENS" }

foreach ($MeerstedeWonenUser in $MeerstedeWonenUsers){
    #Check if User has already SUPER permissions
    $CheckUserPermissionsURL = $AutomationURL + "($CompanyId)/users($($MeerstedeWonenUser.userSecurityId))/userPermissions"
    $UserAlreadySUPER = (Invoke-RestMethod -Uri $CheckUserPermissionsURL -Method GET -Headers $Header).value | Where-Object {$_.roleId -eq "SUPER"}

    if (!$UserAlreadySUPER) {
        
        $Header = @{Acceptlanguage="nl-NL";Authorization="Bearer $($Context.accesstoken)";"Content-Type"="application/json";"If-Match"=$MeerstedeWonenUser.'@odata.etag'}
        $UserPermissionsURL = $UserAutomationURL + "($($MeerstedeWonenUser.userSecurityId))/userPermissions"
        $Body = @{userSecurityId="$($MeerstedeWonenUser.userSecurityId)";roleId="SUPER"}
        $json = $Body | ConvertTo-Json

        Invoke-RestMethod -Uri $UserPermissionsURL -Method POST -Body $json -Verbose -Headers $Header
        
        Write-Output "SUPER permissions granted to user $($MeerstedeWonenUser.userName)"
    }
    else {
        Write-Output "User $($MeerstedeWonenUser.userName) already has SUPER permissions"
    }
}
