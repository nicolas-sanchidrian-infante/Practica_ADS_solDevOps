# Checklist de evidencias — Entrega Grupo DT

## 1) Evidencias de infraestructura (IaC)

- [ ] Captura de `stack-personal` en `CREATE_COMPLETE`.
- [ ] Captura de `stack-ufv` en `CREATE_COMPLETE`.
- [ ] Captura de recursos creados (EC2, VPC, subnets, route tables, SG).
- [ ] Captura de templates `stack-personal.yaml` y `stack-ufv.yaml` en el repo.

## 2) Evidencias de pipeline DevOps

- [ ] Captura de ejecución en verde de `deploy.yml` (GitHub Actions) **o** Jenkins infra.
- [ ] Captura de ejecución de `Jenkinsfile-provision`/`ansible-provision.yml`.
- [ ] Captura del historial de ejecuciones (para trazabilidad).

## 3) Evidencias de Active Directory (Alumno A)

- [ ] Captura de AD DS instalado y operativo.
- [ ] Captura de DNS activo.
- [ ] Captura de configuración NTP.
- [ ] Captura de OU, grupo y usuarios creados.
- [ ] Captura de al menos 2 GPO aplicadas.

## 4) Evidencias Linux (Alumno B, C, D)

- [ ] Captura de Nginx LB activo.
- [ ] Captura de balanceo hacia Web01/Web02.
- [ ] Captura de PostgreSQL operativo.
- [ ] Captura de estructura básica de BD (`academico`).
- [ ] Captura de Node service (`ufvNodeService`) en ejecución.

## 5) Evidencias de integración

- [ ] Prueba de conectividad cruzada entre cuentas (peering + rutas).
- [ ] Prueba de endpoint web `/` y endpoint API `/profesores`.
- [ ] Prueba de cliente Windows unido al dominio (si aplica en defensa).

## 6) Evidencias de control y costes

- [ ] Captura de presupuesto (AWS Budget) configurado.
- [ ] Captura de alertas de coste (85% / 100% o equivalente).
- [ ] Evidencia de uso de IAM (no root).

## 7) Evidencias para defensa final

- [ ] Diagrama de arquitectura final actualizado.
- [ ] Tabla de reparto de tareas por integrante.
- [ ] Lecciones aprendidas y mejoras futuras.
