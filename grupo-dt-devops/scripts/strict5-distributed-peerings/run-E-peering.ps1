param(
  [string]$Region = "eu-south-2",
  [string]$TopologyFile = "",
  [switch]$WhatIfOnly
)

& "$PSScriptRoot/strict5-apply-peerings-local.ps1" -AccountKey E -Profile "JesusE" -Region $Region -TopologyFile $TopologyFile -WhatIfOnly:$WhatIfOnly
