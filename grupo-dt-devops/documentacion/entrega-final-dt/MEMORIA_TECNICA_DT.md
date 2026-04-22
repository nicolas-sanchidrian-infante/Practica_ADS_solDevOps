# Memoria Técnica — Integración de Sistemas en AWS (Grupo DT)

## 1. Datos generales

- **Asignatura:** Administración de Sistemas / Integración de Sistemas
- **Grupo:** DT
- **Profesor:** Alex
- **Integrantes:**
  - Alejandro — Alumno A (Windows AD)
  - Nicolás — Alumno B (Linux LB + DB)
  - Mario — Alumno C (Web server 1)
  - Gonzalo — Alumno D (Web server 2)
  - Jesús — Alumno E (Windows client)

## 2. Objetivo de la práctica

Diseñar, desplegar e integrar una arquitectura distribuida en AWS con enfoque DevOps, incluyendo:

1. Infraestructura como código (IaC).
2. Automatización del despliegue (pipeline).
3. Integración de Windows (AD) y Linux.
4. Operación reproducible con Ansible.
5. Evidencias trazables para rúbrica.

## 3. Arquitectura implementada

### 3.1 Perfiles y red

Se trabaja con cinco perfiles de alumnos:

- `AlejandroA`: VPC `10.0.0.0/16`
- `NicolasB`: VPC `10.1.0.0/16`
- `MarioC`: perfil de operación/validación
- `GonzaloD`: perfil de operación/validación
- `JesusE`: perfil de operación/validación

Topología funcional:

- **Cuenta Personal:**
  - DC01 Windows (AD/DNS/NTP)
  - Nginx Load Balancer
  - PostgreSQL
- **Cuenta UFV:**
  - WebServer 1 (Nginx + Node.js)
  - WebServer 2 (Nginx + Node.js)

Comunicación intercuenta mediante peering y rutas cruzadas.

### 3.2 Asignación por integrantes

- **Alejandro (A):** Controlador de dominio AD, DNS, NTP, directivas base.
- **Nicolás (B):** Servidores Linux de balanceo y base de datos.
- **Mario (C):** WebServer 1, despliegue app y validación backend.
- **Gonzalo (D):** WebServer 2, redundancia y pruebas de balanceo.
- **Jesús (E):** Cliente Windows unido a dominio y validación GPO.

## 4. Enfoque DevOps aplicado

### 4.1 Infraestructura como código

Se usan plantillas CloudFormation:

- `cloudformation/stack-personal.yaml`
- `cloudformation/stack-ufv.yaml`

Con ellas se automatiza:

- VPC, subredes, rutas, gateway.
- Security groups.
- EC2 Linux y Windows.
- Salidas (outputs) para integraciones.

### 4.2 Automatización CI/CD

Se implementan dos vías:

1. **GitHub Actions**
   - `.github/workflows/deploy.yml`
   - `.github/workflows/ansible-provision.yml`

2. **Jenkins**
   - `jenkins/Jenkinsfile-infra`
   - `jenkins/Jenkinsfile-inventory`
   - `jenkins/Jenkinsfile-provision`
   - `jenkins/Jenkinsfile-webdeploy`

Esto permite despliegue repetible, auditable y versionado.

### 4.3 Configuración automática con Ansible

Estructura en `ansible/`:

- Inventario dinámico: `inventory/aws_inventory.sh`
- Playbooks:
  - `update_inventory.yml`
  - `setup_ad_dns_ntp.yml`
  - `configure_dns_clients.yml`
  - `setup_python_venv.yml`
  - `deploy_app.yml`
  - `update_web.yml`

## 5. Flujo operativo de despliegue

Orden recomendado de ejecución:

1. Verificación de prerequisitos (`scripts/check-prerequisites.sh`).
2. Despliegue IaC en ambas cuentas (`infra`).
3. Construcción/verificación inventario dinámico.
4. Provisioning completo (`PLAYBOOK=all`).
5. Actualizaciones incrementales (`webdeploy`).

## 6. Seguridad y buenas prácticas

- Uso de usuarios IAM (sin operar con root).
- Uso de secretos en Jenkins/GitHub (sin hardcodear credenciales en workflows).
- Restricción de CIDR administrativo en SSH/RDP/WinRM.
- Segmentación por security groups y roles.
- Trazabilidad total en repositorio Git.

## 7. Base de datos y aplicación

### 7.1 PostgreSQL

- Motor en servidor Linux dedicado.
- Base `academico` con esquema académico.
- Acceso permitido desde capa web.

### 7.2 Capa web

- Nginx en LB para frontend y reverse proxy.
- Node.js para API académica (`/profesores`).
- Despliegue y actualización automatizados por playbooks.

## 8. Cumplimiento de rúbrica

### 8.1 Infraestructura base

- [x] VPC, subredes y rutas
- [x] Security groups
- [x] EC2 Linux + Windows
- [x] IAM orientado a mínimo privilegio

### 8.2 Componente Windows

- [x] Rol AD y DNS configurables por automatización
- [x] NTP para sincronización de clientes Linux
- [x] Integración de cliente Windows (escenario contemplado)

### 8.3 Componentes Linux

- [x] LB con Nginx
- [x] DB con PostgreSQL
- [x] Web servers y backend Node
- [x] Sincronización/actualización automática

### 8.4 DevOps / Punto extra

- [x] IaC declarativa versionada
- [x] Pipeline CI/CD automatizado
- [x] Provisioning automatizado

## 9. Plan de recuperación y operación

- Destrucción de stacks automatizable (`ACTION=destroy`).
- Redeploy completo desde plantillas y pipelines.
- Reejecución idempotente de playbooks.
- Evidencias y procedimientos incluidos en documentación.

## 10. Conclusión

El grupo DT implementa una práctica completamente automatizada en formato DevOps, con trazabilidad, repetibilidad y alineación con la rúbrica. La solución permite desplegar, configurar y mantener la arquitectura de forma industrial, reduciendo errores manuales y mejorando tiempos de entrega.
