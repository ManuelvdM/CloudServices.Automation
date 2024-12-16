<#
    .SYNOPSIS
        This cmdlet initialize new DEOnline tenants

    .DESCRIPTION
#>
param (
    $ConfigFile = "..\..\others\AppManagement\config.json"
)
function Read-Configuration{
    [CmdletBinding()]
    param($ConfigFile)

    return (Get-Content $ConfigFile|ConvertFrom-Json)
}
function get-IdentityModelClientDLL {
    $AdalModule = get-module "ADAL.PS" -ListAvailable|Select-Object -First 1
    $AssemblyName = "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    if (!$AdalModule) {
        Install-Module "ADAL.PS" -Force
        $AdalModule = get-module "ADAL.PS" -ListAvailable|Select-Object -First 1
    }
    return $AdalModule.FileList|where-object {$_ -like "*$AssemblyName"}
}
function get-AccessToken {
    param($Config,
          $TenantID)

    $CegekaAppId=$Config.adminAppId

    Add-type -Path (get-IdentityModelClientDLL)
    $ctx = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new("https://login.windows.net/$TenantID")
    $redirectUri = New-Object -TypeName System.Uri -ArgumentList "http://localhost"
    $platformParameters = New-Object -TypeName Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters -ArgumentList ([Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Always)
    $token = $ctx.AcquireTokenAsync("https://api.businesscentral.dynamics.com", "$CegekaAppId", $redirectUri, $platformParameters).GetAwaiter().GetResult().AccessToken
    return $token
}

function Get-TokenWithoutPrompt{
    param ($config,$Password, $UserName, $TenantName)

    $CdsaTenantID= $Config.tenantIdCDSA
    $AdminCenterAppid=$Config.adminCenterAppId

    Add-type -Path (get-IdentityModelClientDLL)

    $cred = [Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential]::new($UserName, $Password)
    $ctx = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new("https://login.windows.net/$CdsaTenantID")
    $token = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($ctx, "https://api.businesscentral.dynamics.com", "$AdminCenterAppid", $cred).GetAwaiter().GetResult().AccessToken
    return $token;
}

function write-InnerWebException
{
    param($Exception)
    function Write-Error($message) {
        [Console]::ForegroundColor = 'red'
        [Console]::Error.WriteLine($message)
        [Console]::ResetColor()
    }

    $Exception = $_.Exception
    if ($Exception.Response) {
        $respStream = $Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($respStream)
        $respBody = $reader.ReadToEnd() | ConvertFrom-Json | ConvertTo-Json -Depth 100
        $reader.Close();
        Write-Error ("ms-correlation-x: "+$Exception.Response.Headers["ms-correlation-x"])
        Write-Error $respBody
    }
}
function invoke-AdminManagementApi {
    [CmdletBinding()]
    param ($ResourceUrl
          ,$Token
          ,$Method="get"
          ,$Body)

    $baseUrl = "https://api.businesscentral.dynamics.com/admin/v2.1/"
    $url = ($baseUrl+$ResourceUrl)
    Write-Verbose "invoke API [$url]"

    $headers = @{
        'Authorization'       = "Bearer $Token"
        'content-type'        = 'application/json'
    }

    try
    {
        $result1 = Invoke-WebRequest -Uri $url -Headers $headers -Method $Method -Body $Body -ContentType "application/json"
        return $result1.Content | ConvertFrom-Json
    }
    catch [System.Net.WebException]
    {
        write-InnerWebException -Exception $_.Exception
        throw
    }
}
function Get-ManageableApps
{
    [CmdletBinding()]
    param($token)

    return (invoke-AdminManagementApi -ResourceUrl "manageableapplications" -Token $token)
}
function Set-ManageableApps
{
    [CmdletBinding()]
    param($token,
          $applicatonName,
          $Country,
          $AllowAccess)
    $Body = $AllowAccess.ToString().ToLower()
    return (invoke-AdminManagementApi -ResourceUrl "manageableapplications/$applicatonName/countries/$Country" -Token $token -Body $Body -Method "put")
}


$config = Read-Configuration -ConfigFile $ConfigFile
<#$UserName = "ron.koppelaar@cegeka-dsa.nl"
Get-TokenWithoutPrompt -config $config -Password $Password -UserName $UserName
#>
$TenantID = "4fca03dc-464c-4742-9fbc-a3ce55f2c56f" #Valburg....
$TenantID = "4a4699e8-81d6-4b55-96a5-37d69964a799" #cdsa
$TenantID = "eb808b1b-f54c-422c-80c7-bb4ccd3e629f" # Wierdenen & Borgen
$TenantID = "356bc37e-23a3-43a1-8626-d5548dddb45f" #cns
$TenantID = "c3ca7c2f-4ec2-4202-a1f1-313b2e9ef963" #007
$TenantID = "071ab549-0170-41cb-96e0-557c444315b1" #Maaswonen
$TenantID = "181b6bff-e287-4b5d-8868-09164e292380" #Delden
$TenantID = "742f88a8-6cd1-40d1-9176-e1464707a753" #WormerWonen
$TenantID = "d80021be-23fb-42e8-81e5-5652b8e953b7" #FienWonen
$TenantID = "c5ff8b21-19f7-4d3e-b4c0-6524a80a64ac" #Poort6
$TenantID = "24a7f2ce-d4c0-4c0b-b4bb-a404adaff178" #TablisWonen
$TenantID = "4ee3a4f1-4d8c-4ea9-b4a4-a0cedd4ebf14" #Habeko
$TenantID = "19d45992-edcb-403c-a9ad-a85d03db2506" #Rhiant
$TenantID = "1a468f9d-baca-4fd6-b0dd-3b66f1e7d2c4" #WoonMensen
$TenantID = "52549867-0011-4385-beed-34c697dbdc89" #KleurrijkWonen
$TenantID = "6d0f8e22-f4eb-470e-88a3-5f6b41fd7a22" #Breevast
$TenantID = "54d2d214-a3d4-40f1-9422-a941861798a6" #Mooiland
$TenantID = "4382a252-6b96-443e-8268-beec5087283a" #Nijkerk
$TenantID = "20f0ba46-48de-433f-9607-34e938509ce0" #DeWoonplaats
$TenantID = "a60746a0-fef7-4636-9639-435f151144d9" #MaarsenGroep
$TenantID = "c36b0008-7dd4-4de6-a62a-75ebf61ce137" #DeltaWonen
## TenantIDs pending for Global Admin Approval
$TenantID = "2bd48bd1-be56-438b-99f3-0a1dfb3ad1a9" #Casade Woonstichting
$TenantID = "1d309691-a269-418b-9a63-fc192d56a481" #Centrada
$TenantID = "49c0435c-e38b-41ca-b579-8ad43db2db3a" #De goede Woning
$TenantID = "46b21888-5e82-41dd-9175-8d9fd8a3a0c1" #Segesta Groep B.V.
$TenantID = "73f14b3c-ee55-4ed4-8d7f-168e705d46f0" #Stichting Woonwaard
$TenantID = "796a4481-4173-4c5d-837b-a13c5413a965" #Wonen Zuid
$TenantID = "a6c10eb8-fe67-414d-b193-6efe96bab5a2" #Weller
$TenantID = "0d386942-6605-456d-a7df-d63387e3e90d" #Woningbedrijf Velsen
$TenantID = "8a3d885b-4e22-479e-b729-6f08aeb7a692" #Zayas


#$TenantID = Read-Host -Prompt "Please provide AAD tenant ID of the customer"
$token = get-AccessToken -config $config -TenantID $TenantID
$Apps = Get-ManageableApps -token $token -verbose
$Apps.value
#Disable all application families not being DEOnline
$DisableApps = $Apps.value|Where-Object {$_.applicationFamily -ne "DEOnline" }
$DisableApps|foreach-object {
    try {
        Set-ManageableApps -token $token -applicatonName $_.applicationFamily -Country $_.countryCode -AllowAccess $false -Verbose
    }
    catch {
        Write-Warning "$($_.applicationFamily) $($_.countryCode)"
    }
}

# Enable DEOnline
Set-ManageableApps -token $token -applicatonName "DEOnline" -Country "NL" -AllowAccess $true -Verbose

$Apps = Get-ManageableApps -token $token -verbose
$Apps.value