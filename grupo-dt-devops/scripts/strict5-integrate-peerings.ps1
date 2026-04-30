param(
  [string]$Region = "eu-south-2",
  [switch]$WhatIfOnly
)

$ErrorActionPreference = "Stop"

# Profiles and stack names for strict 5-account deployment.
$accounts = @{
  A = @{ Profile = "AlejandroA"; Stack = "dt-a-ad-client" }
  B = @{ Profile = "NicolasB";   Stack = "dt-b-lb-db" }
  C = @{ Profile = "MarioC";     Stack = "dt-c-web-u1" }
  D = @{ Profile = "GonzaloD";   Stack = "dt-gonzalo-web-alumnos" }
  E = @{ Profile = "JesusE";     Stack = "dt-e-web-u3" }
}

# Required peering edges for this architecture.
# - A<->B: AD <-> LB/DB
# - A<->C/D/E: AD DNS/NTP for web VPCs
# - B<->C/D/E: LB/DB connectivity for web VPCs
$peerings = @(
  @{ From = "A"; To = "B" },
  @{ From = "A"; To = "C" },
  @{ From = "A"; To = "D" },
  @{ From = "A"; To = "E" },
  @{ From = "B"; To = "C" },
  @{ From = "B"; To = "D" },
  @{ From = "B"; To = "E" }
)

function Invoke-AwsJson {
  param(
    [string]$Profile,
    [string[]]$AwsArgs
  )

  $cmd = @("--profile", $Profile, "--region", $Region) + $AwsArgs
  $out = aws @cmd
  if ($LASTEXITCODE -ne 0) {
    throw "AWS CLI command failed for profile ${Profile}: aws $($cmd -join ' ')"
  }
  if ([string]::IsNullOrWhiteSpace($out)) {
    return $null
  }
  return ($out | ConvertFrom-Json)
}

function Get-StackOutputValue {
  param(
    [string]$Profile,
    [string]$Stack,
    [string]$OutputKey
  )

  $stackObj = Invoke-AwsJson -Profile $Profile -AwsArgs @(
    "cloudformation", "describe-stacks",
    "--stack-name", $Stack,
    "--output", "json"
  )

  $value = $stackObj.Stacks[0].Outputs | Where-Object { $_.OutputKey -eq $OutputKey } | Select-Object -First 1 -ExpandProperty OutputValue
  if (-not $value) {
    throw "Output '$OutputKey' not found in stack '$Stack' for profile '$Profile'"
  }
  return $value
}

function Ensure-Route {
  param(
    [string]$Profile,
    [string]$RouteTableId,
    [string]$DestinationCidr,
    [string]$PeeringId
  )

  if (-not $RouteTableId -or $RouteTableId -eq "None") {
    return
  }

  if ($WhatIfOnly) {
    Write-Host "[WHATIF] Route in $RouteTableId ($Profile): $DestinationCidr -> $PeeringId"
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
      throw "Failed to create/replace route in table $RouteTableId for profile $Profile"
    }
  }
}

function Get-OrCreate-Peering {
  param(
    [string]$RequesterProfile,
    [string]$RequesterVpcId,
    [string]$AccepterProfile,
    [string]$AccepterVpcId,
    [string]$AccepterAccountId
  )

  $existingId = aws --profile $RequesterProfile --region $Region ec2 describe-vpc-peering-connections `
    --filters "Name=requester-vpc-info.vpc-id,Values=$RequesterVpcId" "Name=accepter-vpc-info.vpc-id,Values=$AccepterVpcId" "Name=status-code,Values=active,pending-acceptance" `
    --query "VpcPeeringConnections[0].VpcPeeringConnectionId" --output text

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to query VPC peering connections for $RequesterProfile"
  }

  if ($existingId -and $existingId -ne "None") {
    return $existingId
  }

  if ($WhatIfOnly) {
    $synthetic = "pcx-WHATIF-$RequesterProfile-$AccepterProfile"
    Write-Host "[WHATIF] Create peering: $RequesterVpcId ($RequesterProfile) -> $AccepterVpcId ($AccepterProfile)"
    return $synthetic
  }

  $newId = aws --profile $RequesterProfile --region $Region ec2 create-vpc-peering-connection `
    --vpc-id $RequesterVpcId `
    --peer-vpc-id $AccepterVpcId `
    --peer-owner-id $AccepterAccountId `
    --query "VpcPeeringConnection.VpcPeeringConnectionId" --output text

  if ($LASTEXITCODE -ne 0 -or -not $newId -or $newId -eq "None") {
    throw "Failed to create peering between $RequesterVpcId and $AccepterVpcId"
  }

  return $newId
}

# Load required outputs for each account.
foreach ($key in $accounts.Keys) {
  $acc = $accounts[$key]
  $profile = $acc.Profile
  $stack = $acc.Stack

  Write-Host "Loading stack outputs for $key ($profile / $stack)..."

  $acc.VpcId = Get-StackOutputValue -Profile $profile -Stack $stack -OutputKey "VpcId"
  $acc.VpcCidr = Get-StackOutputValue -Profile $profile -Stack $stack -OutputKey "VpcCidr"
  $acc.PublicRouteTableId = Get-StackOutputValue -Profile $profile -Stack $stack -OutputKey "RouteTableId"

  try {
    $acc.PrivateRouteTableId = Get-StackOutputValue -Profile $profile -Stack $stack -OutputKey "PrivateRouteTableId"
  } catch {
    $acc.PrivateRouteTableId = $null
  }

  $acc.AccountId = aws --profile $profile --region $Region sts get-caller-identity --query Account --output text
  if ($LASTEXITCODE -ne 0 -or -not $acc.AccountId) {
    throw "Failed to resolve account id for profile $profile"
  }
}

# Create/accept peerings and ensure routes.
foreach ($edge in $peerings) {
  $from = $accounts[$edge.From]
  $to = $accounts[$edge.To]

  Write-Host "Processing peering $($edge.From)<->$($edge.To) ..."

  $peeringId = Get-OrCreate-Peering `
    -RequesterProfile $from.Profile `
    -RequesterVpcId $from.VpcId `
    -AccepterProfile $to.Profile `
    -AccepterVpcId $to.VpcId `
    -AccepterAccountId $to.AccountId

  if (-not $WhatIfOnly) {
    aws --profile $to.Profile --region $Region ec2 accept-vpc-peering-connection --vpc-peering-connection-id $peeringId *> $null
    # Accept may fail if already accepted; ignore gracefully.
  } else {
    Write-Host "[WHATIF] Accept peering $peeringId in profile $($to.Profile)"
  }

  Ensure-Route -Profile $from.Profile -RouteTableId $from.PublicRouteTableId -DestinationCidr $to.VpcCidr -PeeringId $peeringId
  Ensure-Route -Profile $from.Profile -RouteTableId $from.PrivateRouteTableId -DestinationCidr $to.VpcCidr -PeeringId $peeringId

  Ensure-Route -Profile $to.Profile -RouteTableId $to.PublicRouteTableId -DestinationCidr $from.VpcCidr -PeeringId $peeringId
  Ensure-Route -Profile $to.Profile -RouteTableId $to.PrivateRouteTableId -DestinationCidr $from.VpcCidr -PeeringId $peeringId

  Write-Host "OK peering $($edge.From)<->$($edge.To) using $peeringId"
}

Write-Host "Integration finished."
