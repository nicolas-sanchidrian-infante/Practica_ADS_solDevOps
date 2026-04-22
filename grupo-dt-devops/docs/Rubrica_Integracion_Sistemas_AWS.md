# RUBRICA: Integración de Sistemas en AWS

## Indice

1.  OBJETIVO DE LA PRÁCTICA\
2.  SERVICIOS AWS UTILIZADOS\
3.  REQUISITOS PREVIOS\
4.  ESTRUCTURA TÉCNICA DE LA PRÁCTICA\
    4.1 Infraestructura Base\
    4.2 Componente Windows Server -- Active Directory\
    4.3 Componentes Linux\
    4.4 Disaster Recovery Plan (DRP)\
    4.5 Memoria Técnica\
5.  ORGANIZACION DE EQUIPOS\
6.  CRITERIOS DE EVALUACIÓN\
    6.1. PONDERACIÓN GLOBAL\
    6.2. PONDERACIÓN DETALLADA\
7.  CRITERIO DE CALIFICACIÓN FINAL\
    7.1 Condición indispensable de superación\
    7.2 Defensa de la practica\
    7.3 Evaluación de coherencia y veracidad\
    7.4 Cálculo de la nota final\
    7.5 Principio de responsabilidad colectiva\
8.  FECHA DE ENTREGA

------------------------------------------------------------------------

# 1. OBJETIVO DE LA PRÁCTICA

Diseñar, desplegar e integrar una arquitectura distribuida en AWS
utilizando cuentas individuales por alumno, garantizando:

-   Uso coordinado de múltiples sistemas operativos (Windows Server y
    Linux).
-   Integración real entre cuentas AWS diferentes.
-   Aplicación de buenas prácticas de seguridad, red y control de
    costes.
-   Implementación de un Plan de Recuperación ante Desastres (DRP).
-   Documentación técnica profesional.

La práctica evalúa tanto la competencia técnica individual como la
capacidad de integración y coordinación en equipo.

------------------------------------------------------------------------

# 2. SERVICIOS AWS UTILIZADOS

-   IAM (roles, políticas, acceso entre cuentas)
-   VPC, Subnets, Route Tables, Internet Gateway
-   Security Groups
-   EC2 (Windows Server + Linux)
-   S3 (almacenamiento compartido y backups)
-   Budgets (control de costes)

------------------------------------------------------------------------

# 3. REQUISITOS PREVIOS

-   Cuenta AWS individual por alumno.
-   Presupuesto configurado antes de desplegar infraestructura.
-   Usuario IAM creado (NO uso de root).

------------------------------------------------------------------------

# 4. ESTRUCTURA TÉCNICA DE LA PRÁCTICA

## 4.1 Infraestructura Base

Cada alumno debe:

-   Diseñar una VPC con subred pública y privada.
-   Configurar correctamente tablas de rutas.
-   Aplicar principio de mínimo privilegio en Security Groups.
-   Crear roles IAM para acceso seguro a S3 (sin credenciales
    hardcodeadas).
-   Configurar un Budget funcional con alertas.

------------------------------------------------------------------------

## 4.2 Componente Windows Server -- Active Directory

### Windows Server -- Controlador de Dominio (AD)

-   Asignar IP fija (Elastic IP) a la instancia EC2 que actuará como AD.
-   Configuracion de Service Group para permitir conexiones desde todos
    los servidores Linux.
-   Instalación y configuración funcional de Active Directory Domain
    Services (AD DS).
-   Configuración de DNS + DHCP integrado con AD.
-   Configuración de servidor NTP en Windows AD para que los clientes
    Linux puedan sincronizar la hora (puerto UDP 123).
-   Creacion de un recurso CIFS para usarlo en la politica GPO como
    punto de montaje.
-   Creación de OU jerárquicas coherentes con la práctica.
-   Crear al menos un grupo de usuarios, al que se asignarán al menos
    dos usuarios.
-   Implementación de GPOs aplicadas al grupo:
    -   GPO 1: impedir que los usuarios puedan apagar la máquina.
    -   GPO 2: asignar una unidad de red mapeada automáticamente al
        iniciar sesión.
-   Evidencias de que el AD está operativo, accesible desde clientes y
    que las GPOs funcionan correctamente.

### Windows Server -- Cliente del AD

-   Configurar la instancia EC2 como cliente de dominio.
-   Obtener IP y DNS automáticamente mediante DHCP (proporcionado por el
    AD).
-   Unirse correctamente al dominio gestionado por el AD.
-   Comprobación de que puede autenticarse con usuarios del AD.
-   Evidencias de que puede acceder a recursos de red compartidos según
    la política de la práctica.
-   Verificación de que el cliente aplica GPO heredadas del AD
    correctamente.

------------------------------------------------------------------------

## 4.3 Componentes Linux

### Load Balancer

-   Asignar Elastic IP fija a la instancia EC2 del Load Balancer.
-   Creacion de un Service Group para permitir conexion desde un cliente
    externo.
-   Configuracion de cliente NTP con Servicio NTP de Windows AD.
-   Nginx configurado como reverse proxy para redirigir tráfico a los
    distintos Web Servers.
-   Configuración de upstreams funcionales y balanceo operativo.
-   Separación de locations, cada una apuntando a un Web Server distinto
    y a una función diferente de la aplicación web.
-   Configuracion de Service Group para permitir conexiones desde los
    Web Servers.
-   Configuración segura, evitando exposición de puertos innecesarios.

### Database Server

-   La instancia EC2 de la base de datos tiene Elastic IP fija.
-   Configuracion de cliente NTP con Servicio NTP de Windows AD.
-   Configuracion de Service Group para permitir conexiones desde los
    Web Servers.
-   PostgreSQL instalado y funcionando correctamente.
-   Estructura de base de datos coherente con las funcionalidades de la
    aplicación web.
-   Control de accesos configurado (usuarios y permisos por location /
    funcionalidad).
-   Backup automatizado funcional y accesible para restauración.

### Web Servers

-   Asignar Elastic IP fija a la instancia EC2 webserver.
-   Configuracion de cliente NTP con Servicio NTP de Windows AD.
-   Configuracion de Service Group para permitir conexiones desde el LB.
-   Nginx operativo y correctamente estructurado.
-   Cada location corresponde a una funcionalidad concreta de la
    aplicación web y apunta a la base de datos correspondiente.
-   Integración con S3 mediante IAM Role para almacenamiento de archivos
    de la aplicación.
-   Acceso backend funcional hacia la base de datos asociada a cada
    location.

------------------------------------------------------------------------

# 8. FECHA DE ENTREGA

La práctica deberá entregarse durante las dos últimas clases previas al
examen.\
No se aceptarán entregas fuera de plazo salvo justificación previa
aceptada por el profesor.
