param(
  [string]$Region = "eu-south-2",
  [string]$TopologyFile = "",
  [switch]$WhatIfOnly
)

& "$PSScriptRoot/strict5-apply-peerings-local.ps1" -AccountKey B -Profile "NicolasB" -Region $Region -TopologyFile $TopologyFile -WhatIfOnly:$WhatIfOnly
