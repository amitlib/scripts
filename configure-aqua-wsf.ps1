<#
    .SYNOPSIS
        Downloads and configures Aqua Security Enforcer for Windows.
#>
Param (
  [string]$AQUA_SERVER,
  [string]$AQUA_ENFORCER_VERSION,
  [string]$AQUA_SCANNER_VERSION
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
Write-Log "INFO" "AQUA_SERVER is: $AQUA_SERVER" $logfile
Write-Log "INFO" "AQUA_TOKEN is: $AQUA_TOKEN" $logfile
Write-Log "INFO" "AQUA_ENFORCER_VERSION is: $AQUA_ENFORCER_VERSION" $logfile
Write-Log "INFO" "AQUA_SCANNER_VERSION is: $AQUA_SCANNER_VERSION" $logfile
}

function downloadFilesEnforcer(){
Write-Log "INFO" "step start: downloading file Enforcer" $logfile
if (!(Test-Path c:\temp)) {New-Item -ItemType Directory c:\temp};
$url = "https://aquaautomationsa.blob.core.windows.net/servicefabric/scripts/$AQUA_ENFORCER_VERSION"
$output = "c:\temp\AquaAgentWindowsSFInstaller.msi"
$start_time = Get-Date
Invoke-WebRequest -Uri $url -OutFile $output
Write-Log "INFO" "step end: downloading file Enforcer: Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)" $logfile
}

function downloadFilesScanner(){
Write-Log "INFO" "step start: downloading file scanner-cli" $logfile
if (!(Test-Path c:\temp)) {New-Item -ItemType Directory c:\temp};
$url = "https://aquaautomationsa.blob.core.windows.net/servicefabric/scripts/$AQUA_SCANNER_VERSION"
$output = "c:\temp\AquaScannerCLIWindowsSFInstaller.msi"
$start_time = Get-Date
Invoke-WebRequest -Uri $url -OutFile $output
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
Start-Sleep -s 30
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
Start-Sleep -s 30
if (-not ([string]::IsNullOrEmpty($installed))) {New-Item c:\temp\job_scanner_complete.txt -type file -force -value "Aqua Scanner CLI Installed at $(Get-Date -format 'u')"}
else 
{New-Item c:\temp\job_scanner_failed.txt -type file -force -value "Aqua install scanner cli failed at $(Get-Date -format 'u')"}
Write-Log "INFO" "step end: validate Scanner CLI installation" $logfile
}
validateArguments
downloadFilesEnforcer
deployAquaEnforcer
