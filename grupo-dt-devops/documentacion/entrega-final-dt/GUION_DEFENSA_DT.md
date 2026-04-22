# Guion de defensa — Grupo DT (5–8 minutos)

## 1. Apertura (30-45s)

> "Somos el Grupo DT. Hemos implementado la práctica en AWS con un enfoque DevOps completo: infraestructura como código, pipelines automáticos y configuración con Ansible, siguiendo la guía de Alex y la rúbrica oficial."

## 2. Arquitectura (1-2 min)

- Cinco perfiles AWS de alumnos: `AlejandroA`, `NicolasB`, `MarioC`, `GonzaloD`, `JesusE`.
- En Personal: AD + DNS + NTP, LB Nginx y PostgreSQL.
- En UFV: dos web servers Linux con Nginx + Node.
- Integración por VPC peering y rutas cruzadas.

## 3. Automatización (2 min)

- IaC con CloudFormation (`stack-personal.yaml`, `stack-ufv.yaml`).
- CI/CD con GitHub Actions y Jenkinsfiles.
- Provisioning con Ansible (inventario dinámico + playbooks).
- Flujo repetible: deploy → inventario → provisioning → web update.

## 4. Reparto del equipo (1 min)

- Alejandro: AD, DNS, NTP, políticas.
- Nicolás: LB y DB.
- Mario: Web01 y backend.
- Gonzalo: Web02 y balanceo.
- Jesús: Windows client y validaciones de dominio/GPO.

## 5. Evidencias mostradas (1-2 min)

- Pipelines en verde.
- Stacks `CREATE_COMPLETE`.
- Inventario dinámico con hosts activos.
- Nginx respondiendo y endpoint `/profesores` operativo.
- PostgreSQL y esquema académico activo.
- Evidencias AD/GPO y control de costes.

## 6. Cierre (20-30s)

> "Con esta solución hemos reducido despliegues manuales, aumentado trazabilidad y mejorado la repetibilidad del laboratorio, cumpliendo los objetivos técnicos de integración y el criterio DevOps para el punto extra."

## Preguntas típicas del profesor y respuesta corta

1. **¿Qué valor aporta DevOps aquí?**
   - Menos errores manuales, despliegues repetibles y auditoría completa por commits/runs.

2. **¿Cómo recuperáis ante fallo?**
   - Re-despliegue IaC + re-ejecución Ansible + opción `destroy/deploy` controlada.

3. **¿Por qué no usar root?**
   - Seguridad y principio de mínimo privilegio; trazabilidad por IAM.
