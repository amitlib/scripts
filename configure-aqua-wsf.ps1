<#
    .SYNOPSIS
        Downloads and configures Aqua Security Enforcer for Windows.
#>

echo "babu" > c:\babu.txt

Param (
     [string]$AQUA_SERVER,
     [string]$AQUA_VERSION
)
$global:LogFilePath = 'CtempPSLogFile.log'

function Write-Log
{
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('1','2','3')]
        [int]$Severity = 1 ## Default to a low severity. Otherwise, override
    )
    
    $line = [pscustomobject]@{
        'DateTime' = (Get-Date)
        'Message' = $Message
        'Severity' = $Severity
    }
    
    ## Ensure that $LogFilePath is set to a global variable at the top of script
    $line | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
}

# Manual input param for testing
#$AQUA_SERVER = 104.214.225.883622
#$AQUA_TOKEN = agent-scale-token
$AQUA_TOKEN = "sf-batch-token"
Write-Log "First log entry for this run"
Write-Log "Delaying kickoff 60 sec to run after other agent installers"
Start-Sleep -s 60


function downloadFiles(){
       $urlAgent = "https://get.aquasec.com/892782101/AquaAgentWindowsInstaller.3.0.5.16633.msi"
       $agentOut = "c:\temp\AquaAgentWindowsSFInstaller.msi"

    if (!(Test-Path ctemp)) {New-Item -ItemType Directory ctemp};
    (New-Object System.Net.WebClient).DownloadFile($urlAgent, $agentOut);
    Start-Sleep -s 30
    Write-Log "Function downloadFiles complete"
    }
# Run the function that pulls the files
Write-Log "Calling downloadFiles function, first pass"
downloadFiles

#verify if file exists
# Install enforcer componant
Write-Log "Aqua server is set to $AQUA_SERVER"
Write-Log "Aqua AQUA_VERSION is set to $AQUA_VERSION"
Write-Log "AQUA_TOKEN is set to $AQUA_TOKEN"
Write-Log "Starting MSI, for MSIEXEC log check Ctempaquamsi.log"

Start-Process msiexec -Wait -ArgumentList "/I c:\temp\AquaAgentWindowsSFInstaller.msi AQUA_SERVER=$AQUA_SERVER AQUA_TOKEN=$AQUA_TOKEN /quiet /qn /L*V C:\temp\aquamsi.log";

Write-Log "MSI complete"

$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName |  Where-Object {$_.DisplayName -eq 'Aqua Security Enforcer Windows Installer'})
if (-not ([string]::IsNullOrEmpty($installed))) {New-Item c:\temp\job_complete.txt -type file -force -value "Aqua Agent Installed at $(Get-Date -format 'u')"}
else 
{New-Item c:\temp\job_failed.txt -type file -force -value "Aqua install failed at $(Get-Date -format 'u')"}
Write-Log "Script run complete"
