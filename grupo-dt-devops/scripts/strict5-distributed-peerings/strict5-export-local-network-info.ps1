param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("A", "B", "C", "D", "E")]
  [string]$AccountKey,

  [Parameter(Mandatory = $true)]
  [string]$Profile,

  [Parameter(Mandatory = $true)]
  [string]$Stack,

  [string]$Region = "eu-south-2",

  [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
  $OutputFile = Join-Path $PSScriptRoot ("exports/{0}.json" -f $AccountKey)
}

$parentDir = Split-Path -Parent $OutputFile
if (-not (Test-Path $parentDir)) {
  New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

function Get-StackOutputValue {
  param(
    [object]$StackObj,
    [string]$OutputKey,
    [switch]$Optional
  )

  $item = $StackObj.Stacks[0].Outputs | Where-Object { $_.OutputKey -eq $OutputKey } | Select-Object -First 1
  if (-not $item -and -not $Optional) {
    throw "Output '$OutputKey' not found in stack '$Stack'"
  }

  if (-not $item) {
    return $null
  }

  return $item.OutputValue
}

$stackObj = aws --profile $Profile --region $Region cloudformation describe-stacks --stack-name $Stack --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
  throw "Failed to read stack '$Stack' using profile '$Profile'"
}

$accountId = aws --profile $Profile --region $Region sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) {
  throw "Failed to read account id for profile '$Profile'"
}

$result = [ordered]@{
  accountKey = $AccountKey
  profile = $Profile
  stack = $Stack
  region = $Region
  accountId = $accountId
  vpcId = Get-StackOutputValue -StackObj $stackObj -OutputKey "VpcId"
  vpcCidr = Get-StackOutputValue -StackObj $stackObj -OutputKey "VpcCidr"
  publicRouteTableId = Get-StackOutputValue -StackObj $stackObj -OutputKey "RouteTableId"
  privateRouteTableId = Get-StackOutputValue -StackObj $stackObj -OutputKey "PrivateRouteTableId" -Optional
}

$result | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputFile -Encoding UTF8
Write-Host "Export created: $OutputFile"
