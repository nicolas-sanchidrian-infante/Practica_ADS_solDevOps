param(
  [string]$TopologyFile = "",
  [string]$ExportsDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TopologyFile)) {
  $TopologyFile = Join-Path $PSScriptRoot "strict5-team-topology.json"
}

if ([string]::IsNullOrWhiteSpace($ExportsDir)) {
  $ExportsDir = Join-Path $PSScriptRoot "exports"
}

if (-not (Test-Path $TopologyFile)) {
  throw "Topology file not found: $TopologyFile"
}

if (-not (Test-Path $ExportsDir)) {
  throw "Exports directory not found: $ExportsDir"
}

$topology = Get-Content -Raw -Path $TopologyFile | ConvertFrom-Json

Get-ChildItem -Path $ExportsDir -Filter "*.json" | ForEach-Object {
  $item = Get-Content -Raw -Path $_.FullName | ConvertFrom-Json
  $key = [string]$item.accountKey

  if (-not $topology.accounts.$key) {
    Write-Host "Skipping export $($_.Name): unknown account key '$key'"
    return
  }

  $target = $topology.accounts.$key
  $target.accountId = $item.accountId
  $target.vpcId = $item.vpcId
  $target.vpcCidr = $item.vpcCidr
  $target.publicRouteTableId = $item.publicRouteTableId
  $target.privateRouteTableId = $item.privateRouteTableId

  if ($item.profile) { $target.profile = $item.profile }
  if ($item.stack) { $target.stack = $item.stack }

  Write-Host "Merged export for account $key from $($_.Name)"
}

$topology | ConvertTo-Json -Depth 8 | Set-Content -Path $TopologyFile -Encoding UTF8
Write-Host "Topology updated: $TopologyFile"
