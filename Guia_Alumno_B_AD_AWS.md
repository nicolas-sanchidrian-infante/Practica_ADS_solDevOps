# Guía Completa — Práctica Integración de Sistemas en AWS
### Alumno B — Componentes Linux: Load Balancer y Database Server

---

## ¿Cuál es tu papel?

Según la **rúbrica**, el Alumno B se encarga de los **componentes Linux** de la práctica, especialmente:

- **Linux servicio web (Load Balancer / LB)**
- **Linux Database Server (DB Server)**

Tu trabajo no es montar el Active Directory Windows, sino dejar operativos los servidores Linux que consumen ese AD para hora, red y conectividad.

---

# FASE 0 — Preparación de la cuenta AWS

## Paso 0 — Crear usuario IAM

### ¿Por qué?
La rúbrica exige una **cuenta AWS individual por alumno** y un **usuario IAM** en lugar de usar root.

### Qué debes hacer
Si empiezas desde cero:
- crear un usuario IAM de trabajo
- darle permisos de administración o los mínimos necesarios según os haya indicado el profesor
- activar MFA si está disponible

### Qué debe quedar listo
- usuario IAM funcional
- root reservado para tareas excepcionales

---

## Paso 1 — Configurar Budget

### ¿Por qué?
La práctica requiere control de costes.

### Qué debes crear
- un Budget mensual
- alertas por correo al 85% y 100%

### Ejemplo de configuración
- nombre: `presupuesto-lab`
- límite: el que os haya indicado el profesor, por ejemplo 10 USD/mes

---

# FASE 1 — Infraestructura base común

## Paso 2 — Tener claros los datos del sistema AD

Antes de desplegar Linux, necesitas los datos del controlador de dominio que montó el Alumno A:

| Dato | Valor |
|---|---|
| Dominio | `ufv.local` |
| IP privada del AD | `10.0.13.217` |
| DNS del dominio | `10.0.13.217` |
| Servidor NTP | `10.0.13.217` |
| Recursos compartidos / backend | los que os haya dado el equipo |

> Si el AD usa otra IP o dominio, sustitúyelos por los reales.

---

## Paso 3 — Crear o usar la VPC y las subredes

### ¿Por qué?
La rúbrica pide una **VPC con subred pública y privada**, rutas correctas y seguridad por mínimo privilegio.

### Qué debes tener
- una subred pública para LB
- una subred privada para DB si así lo habéis diseñado
- rutas al Internet Gateway si necesita salida a Internet
- Security Groups separados por función

---

# FASE 2 — Linux Load Balancer (LB)

## Paso 4 — Lanzar la instancia Linux del LB

### Qué debe ser
Un servidor Linux para actuar como **reverse proxy** con Nginx.

### Recomendación
- distro: Ubuntu Server 22.04 o la que uséis en clase
- nombre: `LB01` o similar
- red: subred pública
- Elastic IP: sí, para que sea accesible desde fuera

### Security Group del LB
Abre solo lo necesario:
- **22/TCP** desde tu IP para administración
- **80/TCP** desde Internet o desde el cliente externo si procede
- **443/TCP** si vais a usar HTTPS

---

## Paso 5 — Configurar NTP en el LB

### ¿Por qué?
La rúbrica pide que los servidores Linux sincronizen la hora con el AD de Windows.

### Qué debes hacer
Configurar el cliente NTP para usar como referencia el servidor AD:
- `10.0.13.217`

### Ejemplo con `chrony`
```bash
sudo apt update
sudo apt install -y chrony
sudo sed -i 's/^pool /#pool /' /etc/chrony/chrony.conf
echo 'server 10.0.13.217 iburst' | sudo tee -a /etc/chrony/chrony.conf
sudo systemctl restart chrony
chronyc sources
```

> Si vuestra distro usa otro servicio NTP, aplica el equivalente.

---

## Paso 6 — Instalar y configurar Nginx

### ¿Qué debe hacer?
El LB debe funcionar como **reverse proxy** y balanceador hacia los web servers.

### Qué debes instalar
```bash
sudo apt update
sudo apt install -y nginx
```

### Qué debes configurar
- upstreams hacia los web servers
- locations separadas para cada función de la aplicación
- proxy hacia el backend correspondiente

### Ejemplo conceptual
- `/` → web server principal
- `/app1` → backend 1
- `/app2` → backend 2

### Qué comprobar
- que Nginx responde
- que las rutas redirigen correctamente
- que el balanceo funciona si hay varios web servers

---

## Paso 7 — Verificar reglas de red del LB

### Debe permitir
- entrada externa a **80/443**
- conexión desde los web servers al LB si el diseño lo requiere
- administración solo desde tu IP

### Qué debes evidenciar
- que el LB no expone puertos innecesarios
- que solo acepta el tráfico necesario

---

# FASE 3 — Linux Database Server

## Paso 8 — Lanzar la instancia Linux de la base de datos

### Qué debe ser
Un servidor Linux independiente para alojar **PostgreSQL**.

### Recomendación
- distro: Ubuntu Server 22.04 o la que uséis en clase
- nombre: `DB01` o similar
- red: subred privada si es posible
- Elastic IP: sí, si la práctica lo pide o si necesitáis administración fija

### Security Group de DB
Abre solo lo necesario:
- **22/TCP** desde tu IP para administración
- **5432/TCP** solo desde los web servers

---

## Paso 9 — Configurar NTP en el DB Server

### ¿Por qué?
La base de datos también debe sincronizar la hora con el AD.

### Qué debes hacer
Usar el mismo servidor NTP del dominio:
- `10.0.13.217`

### Verificación
Comprueba que el servicio NTP esté activo y que la hora del servidor coincida con la del dominio.

---

## Paso 10 — Instalar PostgreSQL

### Qué debes conseguir
Una instancia PostgreSQL funcional y accesible por los web servers.

### Ejemplo de instalación
```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
```

### Qué configurar después
- usuarios y contraseñas
- permisos por aplicación o funcionalidad
- acceso remoto solo desde los web servers

---

## Paso 11 — Crear la estructura de base de datos

### ¿Qué pide la rúbrica?
La base de datos debe ser coherente con las funcionalidades de la aplicación web.

### Qué deberías dejar preparado
- base de datos principal
- roles o usuarios por aplicación/finalidad
- permisos bien delimitados

### Qué comprobar
- poder conectar desde el web server
- poder ejecutar consultas básicas

---

## Paso 12 — Configurar backups automáticos

### ¿Por qué?
La rúbrica exige un **backup automatizado funcional y recuperable**.

### Qué debes hacer
- crear un script de copia
- programarlo con cron
- guardar las copias en una ubicación segura

### Qué debes demostrar
- que el backup se genera solo
- que puede restaurarse si hace falta

---

# FASE 4 — Comprobaciones y evidencias

## Paso 13 — Verificar conectividad entre componentes

### Debes comprobar
- LB accesible desde fuera
- LB con salida correcta hacia los web servers
- DB accesible solo desde los web servers
- sincronización de hora correcta con el AD

---

## Paso 14 — Revisar que la seguridad está bien aplicada

### Criterio de la rúbrica
Se valora el **mínimo privilegio**.

### Qué evitar
- abrir SSH o RDP a todo Internet sin necesidad
- exponer PostgreSQL al exterior
- dejar Nginx con puertos innecesarios

---

# Checklist rápido del alumno B

- [ ] Crear usuario IAM
- [ ] Configurar Budget
- [ ] Tener claros los datos del AD
- [ ] Crear/usar la VPC y subredes
- [ ] Crear instancia Linux del LB
- [ ] Asignar Elastic IP al LB
- [ ] Configurar NTP en el LB
- [ ] Instalar y configurar Nginx
- [ ] Crear instancia Linux de DB
- [ ] Asignar Elastic IP a DB si procede
- [ ] Configurar NTP en DB
- [ ] Instalar PostgreSQL
- [ ] Crear usuarios/permisos de BD
- [ ] Configurar backups automáticos
- [ ] Verificar conectividad y seguridad
- [ ] Guardar capturas de evidencia

---

# Resumen final

El alumno B, según la rúbrica, se ocupa de los **componentes Linux**:

- **Load Balancer (LB)** con Nginx, NTP y seguridad correcta
- **Database Server** con PostgreSQL, NTP, permisos y backups

La idea es que ambos servidores Linux queden integrados con la infraestructura de AWS y preparados para trabajar con el AD de Windows del alumno A.
