#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-south-2}"
PROFILE_A="${AWS_PROFILE_A:-AlejandroA}"
PROFILE_B="${AWS_PROFILE_B:-NicolasB}"
PROFILE_C="${AWS_PROFILE_C:-MarioC}"
PROFILE_D="${AWS_PROFILE_D:-GonzaloD}"
PROFILE_E="${AWS_PROFILE_E:-JesusE}"

build_hosts() {
  local profile="$1"
  aws ec2 describe-instances \
    --profile "$profile" \
    --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].{name:Tags[?Key==`Name`]|[0].Value,public_ip:PublicIpAddress,private_ip:PrivateIpAddress,platform:Platform}' \
    --output json
}

PROFILE_A_JSON=$(build_hosts "$PROFILE_A")
PROFILE_B_JSON=$(build_hosts "$PROFILE_B")
PROFILE_C_JSON=$(build_hosts "$PROFILE_C")
PROFILE_D_JSON=$(build_hosts "$PROFILE_D")
PROFILE_E_JSON=$(build_hosts "$PROFILE_E")

PROFILE_A_JSON="$PROFILE_A_JSON" PROFILE_B_JSON="$PROFILE_B_JSON" PROFILE_C_JSON="$PROFILE_C_JSON" PROFILE_D_JSON="$PROFILE_D_JSON" PROFILE_E_JSON="$PROFILE_E_JSON" python3 - <<'PY'
import json, os

all_hosts = []
for key in ('PROFILE_A_JSON', 'PROFILE_B_JSON', 'PROFILE_C_JSON', 'PROFILE_D_JSON', 'PROFILE_E_JSON'):
    all_hosts.extend(json.loads(os.environ[key]))

inv = {
    '_meta': {'hostvars': {}},
    'linux_personal': {'hosts': []},
    'linux_ufv': {'hosts': []},
    'windows_personal': {'hosts': []},
    'windows_clients': {'hosts': []},
    'windows': {'children': ['windows_personal', 'windows_clients']},
    'nginx': {'hosts': []},
    'postgres': {'hosts': []},
    'linux': {'children': ['linux_personal', 'linux_ufv']},
}

def add_host(group, host_key, ip, user='ansible', password='Airbusds2026', is_windows=False):
    inv[group]['hosts'].append(host_key)
    inv['_meta']['hostvars'][host_key] = {
        'ansible_host': ip,
        'ansible_user': user,
        'ansible_password': password,
    }
    if is_windows:
        inv['_meta']['hostvars'][host_key].update({
            'ansible_connection': 'winrm',
            'ansible_winrm_transport': 'basic',
            'ansible_port': 5985,
            'ansible_winrm_server_cert_validation': 'ignore'
        })
    else:
        inv['_meta']['hostvars'][host_key].update({
            'ansible_connection': 'ssh',
            'ansible_become': True,
            'ansible_become_method': 'sudo'
        })

for item in all_hosts:
    name = item.get('name') or ''
    ip = item.get('public_ip')
    if not ip:
        continue
    if 'WIN-CLIENT' in name:
        add_host('windows_clients', name or ip, ip, is_windows=True)
    elif 'DC' in name or 'AD' in name or item.get('platform') == 'windows':
        add_host('windows_personal', name or ip, ip, is_windows=True)
    else:
        if 'UFV' in name or 'Web' in name:
            add_host('linux_ufv', name or ip, ip)
        else:
            add_host('linux_personal', name or ip, ip)
        if 'LB' in name or 'Nginx' in name:
            inv['nginx']['hosts'].append(name or ip)
        if 'Postgre' in name or 'DB' in name:
            inv['postgres']['hosts'].append(name or ip)

print(json.dumps(inv, indent=2))
PY
