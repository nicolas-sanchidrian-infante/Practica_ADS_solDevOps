#!/usr/bin/env bash
set -euo pipefail

echo "[DT] Verificando prerequisitos..."
command -v aws >/dev/null 2>&1 || { echo "Falta aws-cli"; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo "Falta ansible"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Falta python3"; exit 1; }

aws sts get-caller-identity --profile AlejandroA >/dev/null
aws sts get-caller-identity --profile NicolasB >/dev/null
aws sts get-caller-identity --profile MarioC >/dev/null
aws sts get-caller-identity --profile GonzaloD >/dev/null
aws sts get-caller-identity --profile JesusE >/dev/null

echo "[DT] OK: prerequisitos correctos"
