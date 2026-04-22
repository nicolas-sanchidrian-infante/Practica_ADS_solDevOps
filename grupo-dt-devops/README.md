# Grupo DT — Práctica AWS en formato DevOps

Proyecto automatizado para la práctica de **Integración de Sistemas en AWS** siguiendo la solución de Alex y la rúbrica.

## Integrantes
- Alejandro — Alumno A (AD / Windows DC)
- Nicolás — Alumno B (LB + DB)
- Mario — Alumno C (Web server 1)
- Gonzalo — Alumno D (Web server 2)
- Jesús — Alumno E (Windows Client)

## Estructura
- `cloudformation/`: infraestructura AWS (2 cuentas y peering)
- `jenkins/`: pipelines Jenkins
- `ansible/`: inventario dinámico y playbooks
- `ufv-app/`: app web, nginx y Node.js
- `scripts/`: utilidades de bootstrap y validación
- `.github/workflows/`: CI/CD para GitHub Actions
- `docs/`: guía de operación y evidencias

## Flujo DevOps recomendado
1. Desplegar infraestructura (`Jenkinsfile-infra` o workflow `deploy.yml`)
2. Generar inventario dinámico (`Jenkinsfile-inventory`)
3. Configurar AD + DNS + NTP + Linux (`Jenkinsfile-provision`)
4. Desplegar/actualizar app (`Jenkinsfile-webdeploy`)

## Requisitos mínimos
- AWS CLI configurado con 5 perfiles: `AlejandroA`, `NicolasB`, `MarioC`, `GonzaloD`, `JesusE`
- Jenkins + Java 17 en nodo de control Ubuntu
- Ansible + colecciones necesarias
- Llaves SSH y credenciales WinRM

## Nota de seguridad
No subas credenciales reales al repositorio. Usa variables de entorno y secretos de Jenkins/GitHub Actions.
