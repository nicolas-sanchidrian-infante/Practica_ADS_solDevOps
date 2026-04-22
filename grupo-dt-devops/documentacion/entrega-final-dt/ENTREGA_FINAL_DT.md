# ENTREGA FINAL — Práctica Integración de Sistemas en AWS (Grupo DT)

## Portada

- **Grupo:** DT
- **Profesor:** Alex
- **Fecha:** 22/04/2026
- **Integrantes:**
  - Alejandro — Alumno A
  - Nicolás — Alumno B
  - Mario — Alumno C
  - Gonzalo — Alumno D
  - Jesús — Alumno E

---

## 1. Objetivo

Diseñar, desplegar e integrar una arquitectura distribuida en AWS, combinando Windows y Linux con un enfoque DevOps completo:

- Infraestructura como código (IaC)
- Automatización CI/CD
- Provisioning con Ansible
- Evidencias de operación para rúbrica

---

## 2. Arquitectura implementada

### 2.1 Distribución por perfiles de alumnos

- **AlejandroA** (`10.0.0.0/16`):
  - Windows DC01 (AD/DNS/NTP)
  - Linux Nginx LB
  - Linux PostgreSQL

- **NicolasB** (`10.1.0.0/16`):
  - Linux Web01 (Nginx + Node)
  - Linux Web02 (Nginx + Node)

- **MarioC**, **GonzaloD**, **JesusE**:
   - perfiles habilitados para operación, validación y automatización del equipo DT.

Ambas VPC quedan integradas por peering + rutas cruzadas.

### 2.2 Reparto por integrantes

- **Alejandro (A):** AD, DNS, NTP y base de políticas.
- **Nicolás (B):** LB + DB.
- **Mario (C):** Web01 y backend.
- **Gonzalo (D):** Web02 y balanceo.
- **Jesús (E):** cliente Windows y validación de dominio/GPO.

---

## 3. Automatización DevOps aplicada

### 3.1 IaC

Plantillas CloudFormation:

- `cloudformation/stack-personal.yaml`
- `cloudformation/stack-ufv.yaml`

Automatizan red, rutas, seguridad y cómputo.

### 3.2 CI/CD

Se habilitan dos vías:

1. **GitHub Actions**
   - `.github/workflows/deploy.yml`
   - `.github/workflows/ansible-provision.yml`

2. **Jenkins**
   - `jenkins/Jenkinsfile-infra`
   - `jenkins/Jenkinsfile-inventory`
   - `jenkins/Jenkinsfile-provision`
   - `jenkins/Jenkinsfile-webdeploy`

### 3.3 Provisioning

Con Ansible:

- Inventario dinámico: `ansible/inventory/aws_inventory.sh`
- Playbooks:
  - `update_inventory.yml`
  - `setup_ad_dns_ntp.yml`
  - `configure_dns_clients.yml`
  - `setup_python_venv.yml`
  - `deploy_app.yml`
  - `update_web.yml`

---

## 4. Flujo de despliegue recomendado

1. `scripts/check-prerequisites.sh`
2. Deploy infraestructura (Jenkins infra o `deploy.yml`)
3. Build/verificación inventario dinámico
4. Provisioning completo (`PLAYBOOK=all`)
5. Actualizaciones incrementales (`webdeploy`)

---

## 5. Cumplimiento de rúbrica

### 5.1 Infraestructura base
- [x] VPC, subredes y rutas
- [x] Security groups por rol (endurecidos por puertos)
- [x] EC2 Linux + Windows
- [x] Enfoque IAM sin uso operativo de root

### 5.2 Componente Windows
- [x] AD DS y DNS automatizables (base)
- [x] NTP para clientes Linux
- [ ] Validación completa en entorno (OU, GPO y cliente unido con evidencias)

### 5.3 Componentes Linux
- [x] Nginx LB
- [x] PostgreSQL + esquema base + backup programado
- [x] Web servers con backend Node
- [x] Despliegue/actualización automatizados

### 5.4 Criterio DevOps / punto extra
- [x] IaC versionada
- [x] Pipeline CI/CD
- [x] Provisioning reproducible
- [x] Peering cross-account automatizado en pipeline de Jenkins

---

## 6. Seguridad y operación

- Principio de mínimo privilegio en IAM.
- Secretos gestionados en Jenkins/GitHub, no en texto plano en pipeline.
- Restricción de CIDR administrativo para SSH/RDP/WinRM.
- Peering entre cuentas con rutas automáticas en ambos sentidos.
- Recuperación mediante `destroy/deploy` + reejecución idempotente de playbooks.

---

## 7. Evidencias a adjuntar (checklist)

## 7.1 Evidencias de infraestructura
- [ ] Captura `stack-personal` en `CREATE_COMPLETE`
- [ ] Captura `stack-ufv` en `CREATE_COMPLETE`
- [ ] Captura recursos (EC2, VPC, subnets, routes, SG)
- [ ] Captura de templates en repositorio

## 7.2 Evidencias de pipelines
- [ ] Ejecución en verde de `deploy.yml` o Jenkins infra
- [ ] Ejecución de provisioning (`Jenkinsfile-provision` / `ansible-provision.yml`)
- [ ] Historial de ejecuciones

## 7.3 Evidencias AD (Alumno A)
- [ ] AD DS operativo
- [ ] DNS operativo
- [ ] NTP operativo
- [ ] OU + grupo + usuarios
- [ ] 2 GPO aplicadas

## 7.4 Evidencias Linux (B, C, D)
- [ ] Nginx LB operativo
- [ ] Balanceo Web01/Web02
- [ ] PostgreSQL operativo
- [ ] Esquema base `academico`
- [ ] `ufvNodeService` en ejecución

## 7.5 Evidencias de integración
- [ ] Conectividad cross-account (peering + rutas)
- [ ] Endpoint web `/`
- [ ] Endpoint API `/profesores`
- [ ] Cliente Windows unido a dominio (si aplica)

## 7.6 Evidencias de control de costes
- [ ] Budget configurado
- [ ] Alertas de coste
- [ ] Evidencia de operación con IAM

---

## 8. Guion de defensa (resumen)

### Apertura (30–45s)
"Somos el Grupo DT. Hemos implementado la práctica en AWS con enfoque DevOps completo: IaC, pipelines automáticos y Ansible, alineado con la guía de Alex y la rúbrica."

### Puntos clave (4–6 min)
1. Arquitectura en dos cuentas y peering.
2. Automatización de infraestructura, despliegue y provisión.
3. Reparto claro de responsabilidades por integrante.
4. Evidencias funcionales de AD, LB, Web y DB.
5. Beneficio: repetibilidad, trazabilidad y menor error manual.

### Cierre (20–30s)
"La solución cumple requisitos técnicos y de integración, y aporta automatización real para el punto extra DevOps."

---

## 9. Preguntas frecuentes del profesor (respuesta corta)

1. **¿Qué aporta DevOps aquí?**
   - Estandariza despliegue, reduce errores manuales y aporta auditoría.

2. **¿Cómo recuperáis tras un fallo?**
   - `destroy/deploy` de stacks + re-provisioning Ansible.

3. **¿Por qué no usar root?**
   - Seguridad y trazabilidad con IAM y mínimo privilegio.

---

## 10. Conclusión

El Grupo DT entrega una implementación en AWS completamente automatizada, alineada con la rúbrica y preparada para operación real de laboratorio. La práctica queda reproducible, mantenible y defendible técnicamente.
