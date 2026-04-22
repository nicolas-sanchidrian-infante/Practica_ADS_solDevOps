# Despliegue completo paso a paso (Grupo DT)

> Guía práctica para desplegar toda la solución en AWS + Jenkins + Ansible.
> 
> **Objetivo:** que cualquier miembro del equipo pueda desplegar sin perderse.

---

## 0) Qué vas a desplegar

Arquitectura en cuentas individuales de 5 alumnos (modelo DT):

- **AlejandroA** (`10.0.0.0/16`): AD (Windows), LB (Nginx), DB (PostgreSQL)
- **NicolasB** (`10.1.0.0/16`): Web01 y Web02 (Nginx + Node)
- **MarioC**: perfil adicional de equipo (automatización/validación)
- **GonzaloD**: perfil adicional de equipo (automatización/validación)
- **JesusE**: perfil adicional de equipo (automatización/validación)

Automatización:

- IaC: `cloudformation/stack-personal.yaml`, `cloudformation/stack-ufv.yaml`
- Pipeline infra + peering: `jenkins/Jenkinsfile-infra`
- Provisioning: playbooks en `ansible/playbooks/`

---

## 1) Prerrequisitos (obligatorio)

En el nodo de control (Ubuntu recomendado):

- AWS CLI instalado
- Ansible instalado
- Python 3 disponible
- Jenkins funcionando (si usarás Jenkins)
- Repositorio `grupo-dt-devops` clonado

### 1.1 Perfiles AWS

Debes tener configurados cinco perfiles en `~/.aws/credentials` y `~/.aws/config`:

- `AlejandroA`
- `NicolasB`
- `MarioC`
- `GonzaloD`
- `JesusE`

### 1.2 Key Pairs

Asegúrate de tener key pair en ambas cuentas (por ejemplo `aws` y `aws_ufv`).

### 1.3 Verificación rápida

Desde la carpeta del proyecto:

- Ejecuta `scripts/check-prerequisites.sh`
- Si falla, no sigas hasta corregirlo.

---

## 2) Preparar Jenkins (camino recomendado)

Esta es la vía más completa porque ya incluye peering cross-account en el pipeline de infra.

### 2.1 Crear jobs

Crea los 4 jobs Jenkins usando el script o manualmente:

1. `AWS-UFV-CloudFormation-Deploy`
2. `AWS-UFV-Ansible-Inventory-Build`
3. `AWS-UFV-Ansible-App-Deploy`
4. `AWS-UFV-Ansible-Web-Deploy`

Referencias de pipeline:

- `jenkins/Jenkinsfile-infra`
- `jenkins/Jenkinsfile-inventory`
- `jenkins/Jenkinsfile-provision`
- `jenkins/Jenkinsfile-webdeploy`

---

## 3) Despliegue de infraestructura (job 1)

Lanza el job `AWS-UFV-CloudFormation-Deploy` con:

- `ACTION=deploy`
- `AWS_REGION=eu-south-2` (o la que uséis)
- key pairs correctas
- `ADMIN_CIDR` (ideal: tu IP `/32`)

### 3.1 Qué hace automáticamente

- Despliega `stack-personal`
- Despliega `stack-ufv`
- Crea/acepta peering entre cuentas
- Inserta rutas en ambas VPC

### 3.2 Resultado esperado

- Ambas stacks en `CREATE_COMPLETE`
- VPC peering en `active`
- Rutas cruzadas presentes

---

## 4) Construir inventario y conectividad (job 2)

Lanza `AWS-UFV-Ansible-Inventory-Build`.

### 4.1 Qué valida

- Hosts detectados en grupos:
  - `linux_personal`
  - `linux_ufv`
  - `windows_personal`
  - `postgres`
  - `nginx`
- Ping Linux OK
- WinRM a Windows OK

Si WinRM falla, corrígelo antes de continuar.

---

## 5) Provisioning de servicios (job 3)

Lanza `AWS-UFV-Ansible-App-Deploy`.

### 5.1 Opción recomendada

Ejecutar con `PLAYBOOK=all`.

### 5.2 Qué se configura

- AD/DNS/NTP base en Windows
- DNS/NTP en Linux apuntando a AD
- PostgreSQL + DB + esquema base + backup cron
- Nginx LB + Nginx UFV
- Node.js + `ufvNodeService`

---

## 6) Actualizaciones de aplicación (job 4)

Cuando ya está todo desplegado, para cambios de app:

- Lanzar `AWS-UFV-Ansible-Web-Deploy`

Esto actualiza estáticos y backend sin recrear infraestructura.

---

## 7) Validación funcional final (check rápido)

Haz esta validación mínima:

1. AWS: stacks completas en ambas cuentas.
2. AWS: peering `active` + rutas cruzadas.
3. AWS: EIPs asignadas (AD/LB/DB/Web01/Web02).
4. Ansible: inventario dinámico correcto.
5. AD: dominio/DNS/NTP base operativos.
6. DB: `academico` y tabla base presentes.
7. Web: endpoint `/` responde.
8. API: endpoint `/profesores` responde.

---

## 8) Modo destrucción (para ahorrar coste)

Cuando terminéis pruebas:

- Ejecutar job infra con `ACTION=destroy`.

Esto elimina stacks (y en el pipeline también intenta limpiar peering).

---

## 9) Problemas típicos y solución rápida

### 9.1 Stack en rollback

- Revisar Events de CloudFormation
- Corregir parámetro (AMI, key pair, CIDR, permisos IAM)
- Reintentar deploy

### 9.2 No conecta Ansible a Windows

- Revisar WinRM (5985/5986)
- Revisar credenciales y transporte winrm
- Comprobar SG y ruta

### 9.3 No conecta Web ↔ DB

- Revisar SG de DB (5432)
- Revisar rutas/peering
- Revisar servicio PostgreSQL activo

### 9.4 API no responde

- Revisar `ufvNodeService`
- Revisar `nginx` en UFV y LB
- Revisar logs de systemd

---

## 10) Orden recomendado para demo al profesor (5 minutos)

1. Enseñar pipeline infra en verde.
2. Enseñar peering + rutas en AWS.
3. Enseñar inventario dinámico.
4. Enseñar AD base + DB + backup.
5. Abrir `/` y `/profesores` desde la EIP del LB.

---

## 11) Archivos clave que debes tener a mano

- Infra: `cloudformation/stack-personal.yaml`, `cloudformation/stack-ufv.yaml`
- CI/CD: `jenkins/Jenkinsfile-infra`
- Provisioning: `ansible/playbooks/setup_ad_dns_ntp.yml`, `ansible/playbooks/deploy_app.yml`
- Entrega: `documentacion/entrega-final-dt/ENTREGA_FINAL_DT.md`

---

## 12) Nota importante

Si algo no funciona a la primera, no significa que el diseño esté mal: normalmente son parámetros, credenciales, WinRM o reglas de red.

El flujo correcto siempre es:

**infra → inventario → provisioning → validación funcional**
