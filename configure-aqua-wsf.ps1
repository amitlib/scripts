<#
    .SYNOPSIS
        Downloads and configures Aqua Security Enforcer for Windows.
#>
Param (
  [string]$USER_NAME,
  [string]$USER_PASSWORD,
  [string]$AQUA_SERVER,
  [string]$WIN_ENFORCER_BRANCH,
  [string]$WIN_ENFORCER_MSI_TO_INSTALL,
  [string]$WIN_SCANNER_BRANCH,
  [string]$WIN_SCANNER_MSI_TO_INSTALL,
  [string]$STORAGE_ACCOUNT_NAME,
  [string]$OPINSIGHTS_WORKSPACE_ID,
  [string]$WORKSPACE_KEY
)
if (!(Test-Path c:\temp)) {New-Item -ItemType Directory c:\temp};
$logfile = "C:\temp\aquaDeploy.log"
$Level = "INFO"
$AQUA_TOKEN = "sf-batch-token"

Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}
function validateArguments(){
Write-Log "INFO" "USER_NAME is: $USER_NAME" $logfile
Write-Log "INFO" "AQUA_SERVER is: $AQUA_SERVER" $logfile
Write-Log "INFO" "WIN_ENFORCER_BRANCH is: $WIN_ENFORCER_BRANCH" $logfile
Write-Log "INFO" "WIN_ENFORCER_MSI_TO_INSTALL is: $WIN_ENFORCER_MSI_TO_INSTALL" $logfile
Write-Log "INFO" "WIN_SCANNER_BRANCH is: $WIN_SCANNER_BRANCH" $logfile
Write-Log "INFO" "WIN_SCANNER_MSI_TO_INSTALL is: $WIN_SCANNER_MSI_TO_INSTALL" $logfile
}

function downloadFilesEnforcer(){
Start-Sleep -s 30
Write-Log "INFO" "step start: downloading file Enforcer" $logfile
$Username = $USER_NAME
$Password = $USER_PASSWORD
if (!(Test-Path c:\temp)) {New-Item -ItemType Directory c:\temp};
$url = "https://download.aquasec.com/internal/windows-enforcer/$WIN_ENFORCER_BRANCH/$WIN_ENFORCER_MSI_TO_INSTALL"
$Path = "c:\temp\AquaAgentWindowsSFInstaller.msi"
$WebClient = New-Object System.Net.WebClient
$WebClient.Credentials = New-Object System.Net.Networkcredential($Username, $Password)
$start_time = Get-Date
$WebClient.DownloadFile( $url, $path )
Write-Log "INFO" "step end: downloading file Enforcer: Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)" $logfile
}

function downloadFilesScanner(){
Start-Sleep -s 30
Write-Log "INFO" "step start: downloading file scanner-cli" $logfile
$Username = $USER_NAME
$Password = $USER_PASSWORD
if (!(Test-Path c:\temp)) {New-Item -ItemType Directory c:\temp};
$url = "https://download.aquasec.com/internal/windows-scanner/$WIN_SCANNER_BRANCH/$WIN_SCANNER_MSI_TO_INSTALL"
$Path = "c:\temp\AquaScannerCLIWindowsSFInstaller.msi"
$WebClient = New-Object System.Net.WebClient
$WebClient.Credentials = New-Object System.Net.Networkcredential($Username, $Password)
$start_time = Get-Date
$start_time = Get-Date
$WebClient.DownloadFile( $url, $path )
Write-Log "INFO" "step end: downloading file scanner-cli: Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)" $logfile
}

function deployAquaEnforcer(){
Write-Log "INFO" "step start: run enforcer MSI" $logfile
$AQUA_GATEWAY = $AQUA_SERVER + ':3622'
Write-Log "INFO" "AQUA_GATEWAY ENFORCER: $AQUA_GATEWAY" $logfile
Write-Log "INFO" "running: c:\temp\AquaAgentWindowsSFInstaller.msi AQUA_SERVER=$AQUA_GATEWAY AQUA_TOKEN=$AQUA_TOKEN" $logfile
Start-Process msiexec -Wait -ArgumentList "/I c:\temp\AquaAgentWindowsSFInstaller.msi AQUA_SERVER=$AQUA_GATEWAY AQUA_TOKEN=$AQUA_TOKEN /quiet /qn /L*V C:\temp\aquaEnforcer_msi.log";
Write-Log "INFO" "step end: run enforcer MSI" $logfile

Write-Log "INFO" "step start: validate installation" $logfile
$installedEnforcer = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName |  Where-Object {$_.DisplayName -eq 'Aqua Security Enforcer Windows Installer'})
Start-Sleep -s 10
if (-not ([string]::IsNullOrEmpty($installedEnforcer))) {New-Item c:\temp\job_enforcer_complete.txt -type file -force -value "Aqua Agent Installed at $(Get-Date -format 'u')"}
else 
{New-Item c:\temp\job_enforcer_failed.txt -type file -force -value "Aqua Enforcer install failed at $(Get-Date -format 'u')"}
Write-Log "INFO" "step end: validate Enforcer installation" $logfile
downloadFilesScanner
deployAquaScannerCli
}

function deployAquaScannerCli(){
Write-Log "INFO" "step start: run scanner MSI" $logfile
$AQUA_SERVER_URL = 'http://' + $AQUA_SERVER + ':8080'

Write-Log "INFO" "running: c:\temp\AquaScannerCLIWindowsSFInstaller.msi SERVER=$AQUA_SERVER_URL USERNAME=administrator PASSWORD=Password1" $logfile
Start-Process msiexec -Wait -ArgumentList "/I c:\temp\AquaScannerCLIWindowsSFInstaller.msi SERVER=$AQUA_SERVER_URL USERNAME=administrator PASSWORD=Password1 /quiet /qn /L*V C:\temp\aquaScannerCLI_msi.log";
Write-Log "INFO" "step end: run scanner MSI" $logfile
$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName |  Where-Object {$_.DisplayName -eq 'Aqua Security Scanner CLI Windows Installer'})
Start-Sleep -s 10
if (-not ([string]::IsNullOrEmpty($installed))) {New-Item c:\temp\job_scanner_complete.txt -type file -force -value "Aqua Scanner CLI Installed at $(Get-Date -format 'u')"}
else 
{New-Item c:\temp\job_scanner_failed.txt -type file -force -value "Aqua install scanner cli failed at $(Get-Date -format 'u')"}
Write-Log "INFO" "step end: validate Scanner CLI installation" $logfile
runAzureAgent
}

function runAzureAgent(){
Write-Log "INFO" "step start: downloading Azure Agent" $logfile
if (!(Test-Path c:\temp)) {New-Item -ItemType Directory c:\temp};
$SA_NAME = "https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/servicefabric/scripts/MMASetupAMD64.exe"
$start_time = Get-Date
Invoke-WebRequest  $SA_NAME -OutFile c:\temp\MMASetupAMD64.exe
Write-Log "INFO" "step end: downloading Azure Agent: Time taken: $((Get-Date).Subtract($start_time).Seconds)" $logfile
$start_time_run = Get-Date 
Write-Log "INFO" "step start: running Azure Agent" $logfile
cd c:\temp
c:\temp\MMASetupAMD64.exe /c /t:c:\temp
& c:\temp\setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_AZURE_CLOUD_TYPE=0 OPINSIGHTS_WORKSPACE_ID=$OPINSIGHTS_WORKSPACE_ID OPINSIGHTS_WORKSPACE_KEY=$WORKSPACE_KEY AcceptEndUserLicenseAgreement=1
Write-Log "INFO" "step end: run Azure Agent: Time taken: $((Get-Date).Subtract($start_time_run).Seconds)" $logfile
}
validateArguments
downloadFilesEnforcer
deployAquaEnforcer
