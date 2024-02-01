param(
    # Environment variables
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

Write-Output "##[section] Starting: Getting RefreshToken from Keyvault"
$RefreshToken = Get-AzKeyVaultSecret -VaultName $RefreshTokenKeyvaultName -Name $RefreshTokenKeyvaultSecretName -AsPlainText
Write-Output "##[section] Finished: Getting RefreshToken from Keyvault"

$Context = New-BcAuthContext -refreshToken $RefreshToken
$Header = @{Acceptlanguage="nl-NL";Authorization="Bearer $($Context.accesstoken)";"Content-Type"="application/json" }

#Get Company Id
$AutomationURL= "https://api.businesscentral.dynamics.com/v2.0/$TargetEnvironmentName/api/microsoft/automation/v2.0/companies" 
$CompanyId = ((Invoke-RestMethod -Uri $AutomationURL -Method GET -Headers $Header).value | Where-Object {$_.name -eq $($CompanyName)}).id

#Get Enabled Users MeerstedeWonen
$UserAutomationURL = $AutomationURL + "($CompanyId)/users"
$MeerstedeWonenUsers = (Invoke-RestMethod -Uri $UserAutomationURL -Method GET -Headers $Header).value | where-object {$_.state -eq "Enabled"}

Write-Output "##[section] Starting: Granting SUPER permissions"
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
Write-Output "##[section] Finished: Granting SUPER permissions"
