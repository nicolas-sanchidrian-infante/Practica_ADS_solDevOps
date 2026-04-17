# Guía detallada — Punto extra por automatización (IaC y DevOps)

Esta guía te explica **qué hacer paso a paso** para obtener el **punto extra** que pide el profesor:

- **+0,5 puntos** si automatizas la infraestructura como código (IaC)
- **+1 punto** si además lo haces con un enfoque DevOps (pipeline de despliegue/CI/CD o automatización completa)

> **Recomendación rápida:**
> Si queréis el punto completo, implementad **IaC + pipeline**. Si vais justos de tiempo, con IaC bien documentado garantizáis los +0,5.

---

## 1) Opción A — +0,5 puntos (IaC básico)

### ✅ Objetivo
Tener **toda la infraestructura** definida y desplegable con código.

### ✅ Qué debe existir
- Un **archivo de infraestructura como código** (CloudFormation o Terraform).
- Evidencias de que **ese archivo despliega**:
  - VPC
  - subredes
  - rutas
  - security groups
  - instancias EC2
  - Elastic IPs
- Si hay componentes por alumno (AD y Linux), podéis tener **2 plantillas separadas** o **1 sola plantilla** combinada.

### ✅ Qué hacer paso a paso

#### Paso 1 — Revisar el YAML actual (CloudFormation)
Ya tenéis `cloudformation-alumno-a.yml` para el Alumno A (Windows AD).

**Lo que debes verificar en ese YAML:**
- VPC y subredes correctas
- Security Group con puertos correctos (RDP + AD)
- Elastic IP para la EC2 Windows

#### Paso 2 — Crear IaC para Alumno B (Linux)
Cread otra plantilla para el Alumno B que incluya:
- instancia Linux **LB** + EIP
- instancia Linux **DB** + EIP
- Security Groups:
  - LB: 22, 80/443
  - DB: 22 y 5432 solo desde web servers

#### Paso 3 — Probar despliegue
Desplegad la plantilla desde CloudFormation y guardad:
- captura de la pila en estado **CREATE_COMPLETE**
- listado de recursos creados

#### Paso 4 — Documentar
En la memoria técnica añadid:
- que la infraestructura se despliega con IaC
- captura de la plantilla
- captura de la pila creada

---

## 2) Opción B — +1 punto (DevOps / Automatización completa)

### ✅ Objetivo
No solo IaC, sino **automatización del despliegue**, por ejemplo:

- pipeline CI/CD
- despliegue desde GitHub Actions
- integración continua

### ✅ Recomendación mínima viable (rápida y aprobable)
Usar **GitHub Actions** para desplegar CloudFormation automáticamente al hacer push.

---

## 3) Implementación recomendada (GitHub Actions + CloudFormation)

### ✅ Resumen
Crear un repositorio con:
- IaC en YAML
- pipeline que despliega automáticamente

---

### Paso 1 — Crear repositorio Git
1. Crear repositorio en GitHub
2. Subir:
   - `cloudformation-alumno-a.yml`
   - `cloudformation-alumno-b.yml` (nuevo)
   - memoria técnica

---

### Paso 2 — Crear usuario IAM para CI/CD
1. Crear un usuario IAM solo para despliegue.
2. Dar permisos mínimos:
   - CloudFormation
   - EC2
   - VPC
   - IAM: PassRole si se usa
3. Generar Access Key y Secret

---

### Paso 3 — Guardar secrets en GitHub
En GitHub → Settings → Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`

---

### Paso 4 — Crear workflow de despliegue automático
En el repo, crear `.github/workflows/deploy.yml` con un flujo que:
1. Se active con cada push a main
2. Lance el deploy de CloudFormation

---

### Paso 5 — Probar el pipeline
1. Hacer push
2. Ver en GitHub Actions que el workflow finaliza en verde
3. Ver en AWS que la stack se crea automáticamente

---

## 4) Evidencias que debes incluir
Para justificar el **punto extra**, adjuntad:

✅ Capturas en la memoria técnica de:
- Plantilla IaC
- Pipeline en GitHub Actions
- Ejecución en verde
- Stack desplegada en AWS

---

## 5) Checklist rápido (para el punto extra)

- [ ] Plantilla IaC para Alumno A lista
- [ ] Plantilla IaC para Alumno B lista
- [ ] Despliegue automático con GitHub Actions
- [ ] Evidencias documentadas

---

## 6) Nota final
Si solo hacéis IaC → **+0,5 puntos**
Si hacéis IaC + pipeline → **+1 punto**

---

Si quieres, puedo generar automáticamente el **`cloudformation-alumno-b.yml`** y el workflow **`deploy.yml`** por vosotros.