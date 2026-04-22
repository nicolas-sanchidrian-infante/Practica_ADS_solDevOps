# Evidencias para la rúbrica — Grupo DT

## Evidencias mínimas técnicas
1. `cloudformation/stack-personal.yaml` y `cloudformation/stack-ufv.yaml` en repositorio.
2. Captura Jenkins/GitHub Actions ejecutando `deploy` en verde.
3. Captura de ambas stacks en `CREATE_COMPLETE`.
4. Captura de inventario dinámico de Ansible con todos los nodos.
5. Captura de AD funcional (usuarios, OU, GPO aplicada).
6. Captura de LB sirviendo estáticos y de endpoint `/profesores`.
7. Captura de PostgreSQL con tablas del esquema `academico`.
8. Captura de pruebas de conectividad cross-account por peering.

## Orden recomendado de ejecución
1. `scripts/check-prerequisites.sh`
2. `AWS-UFV-CloudFormation-Deploy` (deploy)
3. `AWS-UFV-Ansible-Inventory-Build`
4. `AWS-UFV-Ansible-App-Deploy` con `PLAYBOOK=all`
5. `AWS-UFV-Ansible-Web-Deploy` para cambios iterativos

## Criterios de cierre
- Infra desplegada sin errores en ambas cuentas.
- Playbooks idempotentes (segunda ejecución sin cambios críticos).
- Evidencias documentadas y validadas por el equipo.
