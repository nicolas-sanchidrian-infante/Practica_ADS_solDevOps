param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("A", "B", "C", "D", "E")]
  [string]$AccountKey,

  [Parameter(Mandatory = $true)]
  [string]$Profile,

  [string]$Region = "eu-south-2",

  [string]$TopologyFile = "",

  [switch]$WhatIfOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TopologyFile)) {
  $TopologyFile = Join-Path $PSScriptRoot "strict5-team-topology.json"
}

if (-not (Test-Path $TopologyFile)) {
  throw "Topology file not found: $TopologyFile"
}

$topology = Get-Content -Raw -Path $TopologyFile | ConvertFrom-Json
if (-not $topology.accounts) {
  throw "Invalid topology file: missing 'accounts'"
}

$local = $topology.accounts.$AccountKey
if (-not $local) {
  throw "Account '$AccountKey' not present in topology file"
}

if (-not $local.vpcId -or -not $local.vpcCidr -or -not $local.publicRouteTableId) {
  throw "Account '$AccountKey' is missing required data in topology (vpcId, vpcCidr, publicRouteTableId)"
}

$peerings = $topology.peerings
if (-not $peerings) {
  $peerings = @(
    @{ from = "A"; to = "B" },
    @{ from = "A"; to = "C" },
    @{ from = "A"; to = "D" },
    @{ from = "A"; to = "E" },
    @{ from = "B"; to = "C" },
    @{ from = "B"; to = "D" },
    @{ from = "B"; to = "E" }
  )
}

function Ensure-Route {
  param(
    [string]$RouteTableId,
    [string]$DestinationCidr,
    [string]$PeeringId
  )

  if (-not $RouteTableId -or $RouteTableId -eq "None") {
    return
  }

  if ($WhatIfOnly) {
    Write-Host "[WHATIF] Route in ${RouteTableId}: $DestinationCidr -> $PeeringId"
    return
  }

  aws --profile $Profile --region $Region ec2 replace-route `
    --route-table-id $RouteTableId `
    --destination-cidr-block $DestinationCidr `
    --vpc-peering-connection-id $PeeringId *> $null

  if ($LASTEXITCODE -ne 0) {
    aws --profile $Profile --region $Region ec2 create-route `
      --route-table-id $RouteTableId `
      --destination-cidr-block $DestinationCidr `
      --vpc-peering-connection-id $PeeringId *> $null

    if ($LASTEXITCODE -ne 0) {
      throw "Failed to create or replace route in table $RouteTableId"
    }
  }
}

function Get-PeeringId {
  param(
    [string]$RequesterVpcId,
    [string]$AccepterVpcId,
    [string]$StatusFilter
  )

  $id = aws --profile $Profile --region $Region ec2 describe-vpc-peering-connections `
    --filters "Name=requester-vpc-info.vpc-id,Values=$RequesterVpcId" "Name=accepter-vpc-info.vpc-id,Values=$AccepterVpcId" "Name=status-code,Values=$StatusFilter" `
    --query "VpcPeeringConnections[0].VpcPeeringConnectionId" --output text

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to query peering from $RequesterVpcId to $AccepterVpcId"
  }

  if (-not $id -or $id -eq "None") {
    return $null
  }

  return $id
}

function Create-Peering {
  param(
    [object]$FromAcc,
    [object]$ToAcc
  )

  if ($WhatIfOnly) {
    $simId = "pcx-WHATIF-{0}-{1}" -f $FromAcc.key, $ToAcc.key
    Write-Host "[WHATIF] Create peering $($FromAcc.key)->$($ToAcc.key)"
    return $simId
  }

  if (-not $ToAcc.vpcId -or -not $ToAcc.accountId) {
    throw "Missing remote data for '$($ToAcc.key)': vpcId/accountId required to create peering"
  }

  $existing = Get-PeeringId -RequesterVpcId $FromAcc.vpcId -AccepterVpcId $ToAcc.vpcId -StatusFilter "active,pending-acceptance"
  if ($existing) {
    return $existing
  }

  $newId = aws --profile $Profile --region $Region ec2 create-vpc-peering-connection `
    --vpc-id $FromAcc.vpcId `
    --peer-vpc-id $ToAcc.vpcId `
    --peer-owner-id $ToAcc.accountId `
    --query "VpcPeeringConnection.VpcPeeringConnectionId" --output text

  if ($LASTEXITCODE -ne 0 -or -not $newId -or $newId -eq "None") {
    throw "Failed to create peering $($FromAcc.key)->$($ToAcc.key)"
  }

  return $newId
}

foreach ($edge in $peerings) {
  $fromKey = [string]$edge.from
  $toKey = [string]$edge.to

  if ($AccountKey -ne $fromKey -and $AccountKey -ne $toKey) {
    continue
  }

  $from = $topology.accounts.$fromKey
  $to = $topology.accounts.$toKey

  if (-not $from -or -not $to) {
    throw "Topology missing account data for edge $fromKey->$toKey"
  }

  $from | Add-Member -NotePropertyName key -NotePropertyValue $fromKey -Force
  $to | Add-Member -NotePropertyName key -NotePropertyValue $toKey -Force

  if ($AccountKey -eq $fromKey) {
    Write-Host "[LOCAL=$AccountKey] Requester edge $fromKey->$toKey"
    $peeringId = Create-Peering -FromAcc $from -ToAcc $to
    Ensure-Route -RouteTableId $local.publicRouteTableId -DestinationCidr $to.vpcCidr -PeeringId $peeringId
    Ensure-Route -RouteTableId $local.privateRouteTableId -DestinationCidr $to.vpcCidr -PeeringId $peeringId
    continue
  }

  Write-Host "[LOCAL=$AccountKey] Accepter edge $fromKey->$toKey"
  if (-not $from.vpcId) {
    if ($WhatIfOnly) {
      Write-Host "[WHATIF] Missing requester vpcId for edge $fromKey->$toKey (fill topology first)"
      continue
    }
    throw "Missing requester vpcId for edge $fromKey->$toKey"
  }

  $pendingId = Get-PeeringId -RequesterVpcId $from.vpcId -AccepterVpcId $to.vpcId -StatusFilter "pending-acceptance,active"

  if (-not $pendingId) {
    if ($WhatIfOnly) {
      Write-Host "[WHATIF] No peering visible yet for $fromKey->$toKey (normal if requester has not created it)"
      continue
    }
    throw "No pending/active peering found for edge $fromKey->$toKey. Requester must create it first."
  }

  if (-not $WhatIfOnly) {
    aws --profile $Profile --region $Region ec2 accept-vpc-peering-connection --vpc-peering-connection-id $pendingId *> $null
    # Ignore accept errors when already active.
  } else {
    Write-Host "[WHATIF] Accept peering $pendingId"
  }

  Ensure-Route -RouteTableId $local.publicRouteTableId -DestinationCidr $from.vpcCidr -PeeringId $pendingId
  Ensure-Route -RouteTableId $local.privateRouteTableId -DestinationCidr $from.vpcCidr -PeeringId $pendingId
}

Write-Host "Local peering actions finished for account '$AccountKey'."
