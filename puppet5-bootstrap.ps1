<#
.SYNOPSIS
    Installs Puppet on this machine.

.DESCRIPTION
    Downloads and installs the PuppetLabs Puppet MSI package.

    This script requires administrative privileges.
#>
param(
    # Whether to stop and disable the puppet service that will be started by the installer
    [switch] $DisablePuppetService,

    [string] $PuppetAgentAccountUser,
    [string] $PuppetAgentAccountPassword,
    [string] $PuppetAgentAccountDomain,
    [string] $PuppetServer
)

if(Get-Command puppet -ErrorAction 0) {
    Write-Host "puppet is already installed. Nothing to do, bye!"
    exit 0
}

if( [Environment]::Is64BitOperatingSystem ) {
    $MsiUrl = 'https://downloads.puppetlabs.com/windows/puppet5/puppet-agent-x64-latest.msi'
} else {
    $MsiUrl = 'https://downloads.puppetlabs.com/windows/puppet5/puppet-agent-x86-latest.msi'
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (! ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-Host -ForegroundColor Red "You must run this script as an administrator."
    Exit 1
}

$installFile = 'C:\Windows\Temp\puppet-agent.msi'
while(!(Test-Path $installFile)) {
    Write-Host "Downloading puppet-agent from $MsiUrl to $installFile"
    (new-object net.webclient).DownloadFile($MsiUrl, $installFile)
}

$install_args = @("/qn", "/norestart","/i", 'C:\Windows\Temp\puppet-agent.msi')
if($PuppetAgentAccountDomain) { $install_args += "PUPPET_AGENT_ACCOUNT_DOMAIN=$PuppetAgentAccountDomain" }
if($PuppetAgentAccountUser) { $install_args += "PUPPET_AGENT_ACCOUNT_USER=$PuppetAgentAccountUser" }
if($PuppetAgentAccountPassword) { $install_args += "PUPPET_AGENT_ACCOUNT_PASSWORD=$PuppetAgentAccountPassword" }
if($PuppetServer) { $install_args += "PUPPET_MASTER_SERVER=$PuppetServer" }

Write-Host "Installing Puppet. Running msiexec.exe $install_args"
$process = Start-Process -FilePath msiexec.exe -ArgumentList $install_args -Wait -PassThru
if ($process.ExitCode -ne 0) {
    Write-Host "Installer failed with code $($process.ExitCode)"
    Exit 1
}

# Stop the service that it autostarts
if($DisablePuppetService.IsPresent) {
    Write-Host "Stopping Puppet service that is running by default..."
    Start-Sleep -s 5
    Stop-Service -Name puppet
    Set-Service -Name puppet -StartupType Disabled
}

Write-Host "Puppet successfully installed."

# Update the path environment variable so that we can use the puppet command
# without requiring an awkward reboot.
if($env:Path -notcontains 'C:\Program Files\Puppet Labs\Puppet\bin' ) {
  $env:Path += ';C:\Program Files\Puppet Labs\Puppet\bin'
  [Environment]::SetEnvironmentVariable('Path', $env:Path, 'Machine')
}