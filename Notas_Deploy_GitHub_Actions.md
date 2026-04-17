# Notas rápidas — Deploy con GitHub Actions (punto extra)

## 1) Secrets obligatorios en GitHub
En el repositorio → **Settings → Secrets and variables → Actions**:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`

> Estas credenciales deben pertenecer a un **usuario IAM de despliegue** con permisos para CloudFormation, EC2, VPC y EIP.

---

## 2) Stack names usados por el workflow
El pipeline usa estos nombres (puedes cambiarlos en `.github/workflows/deploy.yml`):
- `alumno-a`
- `alumno-b`

---

## 3) Qué hace el pipeline
1. Despliega la plantilla **Alumno A** (`cloudformation-alumno-a.yml`)
2. Lee los outputs: VPC y subredes
3. Despliega la plantilla **Alumno B** (`cloudformation-alumno-b.yml`) usando esos outputs

---

## 4) Parámetros opcionales recomendados
Si quieres **más seguridad** y cumplir mínimo privilegio:

- Cambia `SshCidr` a tu IP pública `/32`
- Pasa el `WebServerSecurityGroupId` real cuando exista

Para ello puedes editar el workflow y añadir `--parameter-overrides` con esos valores.

---

## 5) Evidencias para el punto extra
- Captura del workflow en verde
- Captura de las stacks en **CREATE_COMPLETE**
- Captura de la plantilla IaC
