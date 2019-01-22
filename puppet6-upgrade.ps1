# Check we already have a csr_attributes.yaml present - if not, prompt to create
if (!(Test-Path -Path "C:\ProgramData\PuppetLabs\puppet\etc\csr_attributes.yaml")) {
    Write-Error "No csr_attributes.yaml found - aborting"
    exit 1
}

# Stop the old puppet agent and clean up its SSL directory
Stop-Service puppet
Remove-Item C:\ProgramData\PuppetLabs\puppet\etc\ssl\ -Recurse -Force

# If we were previously pointing at Puppet 4 server externally, move to Puppet 6 port
$oldMasterPort = & puppet config print --section main masterport
if ($oldMasterPort -eq 8141) {
    & puppet config set --section main masterport 8142
}

# Point at the new Puppet 6 server
& puppet config set --section main server puppet6.red-gate.com

if( [Environment]::Is64BitOperatingSystem ) {
    $MsiUrl = 'https://downloads.puppetlabs.com/windows/puppet6/puppet-agent-x64-latest.msi'
} else {
    $MsiUrl = 'https://downloads.puppetlabs.com/windows/puppet6/puppet-agent-x86-latest.msi'
}
Start-BitsTransfer $MsiUrl -Destination "Puppet6.msi"

$MsiExecArgs = @(
    '/qn',
    '/norestart',
    '/i',
    'Puppet6.msi')
Start-Process -FilePath msiexec.exe -ArgumentList $MsiExecArgs -Wait -PassThru

if($env:Path -notcontains 'C:\Program Files\Puppet Labs\Puppet\bin' ) {
  $env:Path += ';C:\Program Files\Puppet Labs\Puppet\bin'
  [Environment]::SetEnvironmentVariable('Path', $env:Path, 'Machine')
}

& puppet agent -t