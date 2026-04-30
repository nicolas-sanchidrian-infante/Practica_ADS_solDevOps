param(
  [string]$Region = "eu-south-2",
  [string]$TopologyFile = "",
  [switch]$WhatIfOnly
)

& "$PSScriptRoot/strict5-apply-peerings-local.ps1" -AccountKey A -Profile "AlejandroA" -Region $Region -TopologyFile $TopologyFile -WhatIfOnly:$WhatIfOnly
