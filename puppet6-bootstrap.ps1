<#
.SYNOPSIS
    Installs Puppet 6 on this machine.

.DESCRIPTION
    Downloads and installs the PuppetLabs Puppet MSI package.

    This script requires administrative privileges.
#>
param(
    # Whether to stop and disable the puppet service that will be started by the installer
    [ValidateSet('Automatic', 'Manual', 'Disabled')]
    [ValidateNotNullOrEmpty()]
    [string] $PuppetAgentStartupMode = 'Automatic',
    [string] $PuppetAgentAccountUser,
    [string] $PuppetAgentAccountPassword,
    [string] $PuppetAgentAccountDomain,
    [string] $PuppetServer,
    [Integer] $PuppetServerPort,
    [string] $PuppetEnvironment,
    # A list of certificate extensions as defined in https://puppet.com/docs/puppet/5.5/ssl_attributes_extensions.html
    # example: @{ pp_environment='staging'; pp_role='kubernetes-master' }
    [ValidateNotNull()]
    [HashTable] $CertificateExtensions = @{}
)

if(Get-Command puppet -ErrorAction 0) {
    Write-Host "puppet is already installed. Nothing to do, bye!"
    exit 0
}

if( [Environment]::Is64BitOperatingSystem ) {
    $MsiUrl = 'https://downloads.puppetlabs.com/windows/puppet6/puppet-agent-x64-latest.msi'
} else {
    $MsiUrl = 'https://downloads.puppetlabs.com/windows/puppet6/puppet-agent-x86-latest.msi'
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

if($CertificateExtensions) {
    # Create the csr_attributes.yaml with values from $CertificateExtensions
    # Do it before installing puppet, in case the installer start the puppet service
    # ($PuppetAgentStartupMode = Automatic)

    New-Item $env:ProgramData\PuppetLabs\puppet\etc -ItemType Directory -Force | Out-Null

    @(
        'extension_requests:',
        ($CertificateExtensions.GetEnumerator() | % { "  $($_.Name): $($_.Value)" })
    ) | Set-Content -Path $env:ProgramData\PuppetLabs\puppet\etc\csr_attributes.yaml
}

$install_args = @(
    '/qn',
    '/norestart',
    '/i',
    'C:\Windows\Temp\puppet-agent.msi',
    "PUPPET_AGENT_STARTUP_MODE=$PuppetAgentStartupMode"
    )
if($PuppetAgentAccountDomain) { $install_args += "PUPPET_AGENT_ACCOUNT_DOMAIN=$PuppetAgentAccountDomain" }
if($PuppetAgentAccountUser) { $install_args += "PUPPET_AGENT_ACCOUNT_USER=$PuppetAgentAccountUser" }
if($PuppetAgentAccountPassword) { $install_args += "PUPPET_AGENT_ACCOUNT_PASSWORD=$PuppetAgentAccountPassword" }
if($PuppetServer) { $install_args += "PUPPET_MASTER_SERVER=$PuppetServer" }
if($PuppetEnvironment) { $install_args += "PUPPET_AGENT_ENVIRONMENT=$PuppetEnvironment" }

Write-Host "Installing Puppet. Running msiexec.exe $install_args"
$process = Start-Process -FilePath msiexec.exe -ArgumentList $install_args -Wait -PassThru
if ($process.ExitCode -ne 0) {
    Write-Host "Installer failed with code $($process.ExitCode)"
    Exit 1
}

Write-Host "Puppet successfully installed."

# Update the path environment variable so that we can use the puppet command
# without requiring an awkward reboot.
if($env:Path -notcontains 'C:\Program Files\Puppet Labs\Puppet\bin' ) {
  $env:Path += ';C:\Program Files\Puppet Labs\Puppet\bin'
  [Environment]::SetEnvironmentVariable('Path', $env:Path, 'Machine')
}

if ($PuppetServerPort) {
    $set_port_args = @('config', 'set', 'masterport', $PuppetServerPort, '--section', 'main')
    Start-Process -FilePath puppet.exe -ArgumentList $set_port_args -Wait -PassThru
}