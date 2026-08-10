param(
  [string]$SecretDirectory = (Join-Path $env:USERPROFILE '.config\vpn'),
  [string]$DeploymentName = 'vpn',
  [string]$ApiTokenUser = 'automation',
  [switch]$IncludeApiToken
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Decrypts one DPAPI value owned by the current Windows user.
function Get-DpapiPlaintext {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "DPAPI file not found: $Path"
  }

  $encrypted = (Get-Content -LiteralPath $Path -Raw).Trim()
  if ([string]::IsNullOrWhiteSpace($encrypted)) {
    throw "DPAPI file is empty: $Path"
  }

  $secure = ConvertTo-SecureString -String $encrypted
  $plaintext = [PSCredential]::new('secret', $secure).GetNetworkCredential().Password
  if ([string]::IsNullOrWhiteSpace($plaintext)) {
    throw "Unable to decrypt DPAPI file: $Path"
  }

  return $plaintext
}

# Parses the installer result and validates the fields required for panel access.
function Get-PanelSettings {
  param([Parameter(Mandatory)][string]$Plaintext)

  if ([string]::IsNullOrWhiteSpace($Plaintext)) {
    throw 'Panel data is empty.'
  }

  $settings = ConvertFrom-StringData -StringData $Plaintext
  foreach ($key in 'XUI_ACCESS_URL', 'XUI_USERNAME', 'XUI_PASSWORD') {
    if (-not $settings.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($settings[$key])) {
      throw "Panel data does not contain $key."
    }
  }

  return $settings
}

$prefix = $DeploymentName
$panelFile = Join-Path $SecretDirectory "$prefix-3x-ui.dpapi"
$subscriptionsFile = Join-Path $SecretDirectory "$prefix-subscriptions.dpapi"
$apiTokenFile = Join-Path $SecretDirectory "$prefix-api-token.dpapi"

$panelPlaintext = Get-DpapiPlaintext -Path $panelFile
$panel = Get-PanelSettings -Plaintext $panelPlaintext
$subscriptionsPlaintext = Get-DpapiPlaintext -Path $subscriptionsFile
$subscriptions = $subscriptionsPlaintext | ConvertFrom-Json

[PSCustomObject]@{
  Purpose = '3x-ui panel'
  User = $panel.XUI_USERNAME
  Value = $panel.XUI_ACCESS_URL
}
[PSCustomObject]@{
  Purpose = 'Panel password'
  User = $panel.XUI_USERNAME
  Value = $panel.XUI_PASSWORD
}

foreach ($property in $subscriptions.PSObject.Properties) {
  [PSCustomObject]@{
    Purpose = "Subscription $($property.Name)"
    User = $property.Name
    Value = $property.Value
  }
}

if ($IncludeApiToken) {
  [PSCustomObject]@{
    Purpose = 'API token'
    User = $ApiTokenUser
    Value = Get-DpapiPlaintext -Path $apiTokenFile
  }
}

$panelPlaintext = $null
$subscriptionsPlaintext = $null
