# Guía Completa — Práctica Active Directory en AWS
### Alumno A — Controlador de Dominio (AD)

---

## ¿Qué hemos hecho y por qué?

Esta práctica consiste en montar una infraestructura real en la nube de Amazon (AWS) con:
- Un servidor Windows que actúa como "jefe" de la red (Controlador de Dominio con Active Directory)
- Varios servidores Linux conectados a él
- Todo comunicado de forma segura

Tú eres el **Alumno A**, responsable del servidor Windows que gestiona los usuarios, contraseñas, políticas y DNS de toda la red.

---

# Despliegue automático con CloudFormation (Alumno A)

Para automatizar toda la infraestructura del Alumno A, se incluye la plantilla:
`cloudformation-alumno-a.yml`

Esta plantilla crea:
- VPC, subredes públicas y privadas
- Internet Gateway y tablas de rutas
- Security Group con puertos de AD
- Instancia Windows Server 2022 para el DC
- Elastic IP asociada a la instancia

## Parámetros recomendados (según la práctica)

| Parámetro | Valor |
|---|---|
| Región | `eu-north-1` |
| VPC CIDR | `10.0.0.0/16` |
| Subred pública 1 | `10.0.1.0/24` |
| Subred pública 2 | `10.0.2.0/24` |
| Subred privada 1 | `10.0.11.0/24` |
| Subred privada 2 | `10.0.12.0/24` |
| Key Pair | `clave-ad` |
| Tipo instancia | `t3.micro` |

> **Importante:** ajusta `RdpCidr` con tu IP pública (formato `x.x.x.x/32`).
> Si lo dejas en `0.0.0.0/0`, el puerto 3389 queda abierto a todo Internet.

## Cómo lanzar el stack

1. AWS Console → **CloudFormation** → **Create stack**.
2. “Upload a template file” y selecciona `cloudformation-alumno-a.yml`.
3. Rellena los parámetros (usa los valores anteriores).
4. Espera a que el stack termine en estado **CREATE_COMPLETE**.

Cuando finalice, tendrás el **Controlador de Dominio** con **Elastic IP** listo para conectarte por RDP y continuar con los pasos de instalación de AD, DNS, DHCP, NTP y GPOs.

---

# FASE 1 — Preparación de AWS

## ¿Qué es AWS?

AWS (Amazon Web Services) es una plataforma de servidores en la nube. En lugar de tener un ordenador físico, alquilas uno virtual que está en un centro de datos de Amazon. Pagas solo por lo que usas.

---

## Paso 1 — Crear usuario IAM

### ¿Por qué?
AWS tiene dos tipos de acceso:
- **Root**: el dueño de la cuenta, tiene acceso total y es peligroso usarlo en el día a día
- **IAM (Identity and Access Management)**: usuarios con permisos controlados

La buena práctica de seguridad es **nunca usar root** para trabajar. Si alguien roba las credenciales root, pierde el control total de la cuenta. Con un usuario IAM, el daño es limitado.

### Qué hicimos:
1. Entramos en AWS con la cuenta root
2. Creamos un usuario llamado `admin-lab`
3. Le dimos permisos de `AdministratorAccess`
4. A partir de ahí trabajamos siempre con `admin-lab`, nunca con root

---

## Paso 2 — Configurar Budget (control de costes)

### ¿Por qué?
AWS cobra por uso. Si te olvidas una instancia encendida, puedes llevarte una sorpresa en la factura. El Budget es una alarma que te avisa por email cuando el gasto supera un límite.

### Qué hicimos:
- Creamos un presupuesto llamado `presupuesto-lab` con límite de **$10/mes**
- Configuramos alertas al 85% y 100% del límite

---

## Paso 3 — Crear la VPC

### ¿Qué es una VPC?
Una VPC (Virtual Private Cloud) es tu **red privada virtual** dentro de AWS. Es como si tuvieras tu propio router y red local, pero en la nube. Sin VPC, tus servidores no pueden comunicarse entre sí de forma privada.

### ¿Qué son las subredes?
Dentro de la VPC dividimos la red en subredes:
- **Subred pública**: los servidores de aquí son accesibles desde internet (Load Balancer, AD)
- **Subred privada**: los servidores de aquí solo son accesibles desde dentro de la VPC (Base de datos)

### ¿Qué es el Internet Gateway?
Es la "puerta de salida" de tu VPC hacia internet. Sin él, ningún servidor puede comunicarse con el exterior.

### Qué hicimos:
Creamos una VPC llamada `vpc-practica` con:
- **CIDR**: `10.0.0.0/16` → esto significa que podemos tener IPs desde `10.0.0.1` hasta `10.0.255.254`
- 2 subredes públicas
- 2 subredes privadas
- 1 Internet Gateway (creado automáticamente)
- Tablas de rutas (creadas automáticamente)

---

## Paso 4 — Crear el Security Group del AD

### ¿Qué es un Security Group?
Es un **firewall virtual** que controla qué tráfico puede entrar y salir de una instancia. Por defecto, todo está bloqueado. Tienes que abrir explícitamente cada puerto que necesites.

### ¿Qué es un puerto?
Los puertos son como "puertas" de un edificio. Cada servicio usa una puerta diferente:
- Puerto 3389 → RDP (escritorio remoto de Windows)
- Puerto 53 → DNS (resolución de nombres)
- Puerto 88 → Kerberos (autenticación de Active Directory)
- Puerto 389 → LDAP (directorio de usuarios)
- Puerto 67/68 → DHCP (asignación automática de IPs)
- Puerto 123 → NTP (sincronización de hora)

### Qué hicimos:
Creamos el Security Group `sg-windows-ad` con estas reglas de entrada:

| Puerto | Protocolo | Origen | Para qué sirve |
|--------|-----------|--------|----------------|
| 3389 | TCP | Mi IP | Conectarnos por Escritorio Remoto |
| 53 | TCP+UDP | 10.0.0.0/16 | DNS — resolución de nombres |
| 88 | TCP+UDP | 10.0.0.0/16 | Kerberos — autenticación AD |
| 389 | TCP | 10.0.0.0/16 | LDAP — consultar el directorio |
| 67-68 | UDP | 10.0.0.0/16 | DHCP — dar IPs automáticamente |
| 123 | UDP | 10.0.0.0/16 | NTP — sincronizar la hora |

> `10.0.0.0/16` significa "cualquier IP dentro de nuestra VPC"

---

# FASE 2 — Servidor Windows (Active Directory)

## Paso 5 — Lanzar la instancia EC2

### ¿Qué es una instancia EC2?
EC2 (Elastic Compute Cloud) es el servicio de AWS para **servidores virtuales**. Cada servidor virtual se llama "instancia". Puedes elegir el sistema operativo, la RAM, la CPU, etc.

### ¿Qué es el Free Tier?
AWS ofrece 12 meses gratis para instancias `t2.micro` o `t3.micro`. Son pequeñas pero suficientes para el laboratorio.

### ¿Qué es un par de claves (.pem)?
En lugar de contraseña, AWS usa un archivo `.pem` (clave privada) para autenticarte. Con ese archivo puedes descifrar la contraseña del servidor. Es como una llave física — si la pierdes, no puedes entrar.

### Qué hicimos:
- Creamos una instancia llamada `AD-DC01`
- Sistema operativo: **Windows Server 2022**
- Tipo: `t2.micro` (Free Tier)
- Red: VPC `vpc-practica`, subred pública
- Creamos el par de claves `clave-ad.pem` y lo guardamos

---

## Paso 6 — Asignar Elastic IP

### ¿Qué es una Elastic IP?
Cuando reinicias una instancia en AWS, la IP pública cambia. Esto es un problema porque los clientes Linux necesitan saber siempre la misma dirección del AD.

Una **Elastic IP** es una IP pública **fija** que siempre apunta a tu instancia aunque la reinicies.

> ⚠️ Las Elastic IPs son gratuitas mientras están asociadas a una instancia encendida. Si la desasocías o apagas la instancia, empiezan a cobrar ~$0.005/hora.

### Qué hicimos:
- Creamos una Elastic IP en EC2 → Direcciones IP elásticas
- La asociamos a la instancia `AD-DC01`

---

## Paso 7 — Conectarse por RDP

### ¿Qué es RDP?
RDP (Remote Desktop Protocol) es el protocolo de Windows para conectarse a un escritorio remoto. Es como TeamViewer pero nativo de Windows.

### ¿Cómo obtuvimos la contraseña?
AWS cifra la contraseña del Administrator con tu clave `.pem`. Para obtenerla:
1. EC2 → Instancias → Conectar → Cliente RDP → Obtener contraseña
2. Subimos el archivo `clave-ad.pem`
3. AWS descifró y nos mostró la contraseña

### Problema que tuvimos:
Windows intentaba entrar como `MicrosoftAccount\Administrador` en lugar de como usuario local.

### Solución:
Usar `.\Administrator` como nombre de usuario. El `.\` le indica a Windows que use la cuenta **local de la máquina**, no una cuenta Microsoft.

---

## Paso 8 — Cambiar nombre del servidor

### ¿Por qué?
El nombre por defecto que pone AWS es algo como `EC2AMAZ-XXXXXXX`. Necesitamos un nombre claro y profesional. Además, el nombre del servidor forma parte del dominio (`DC01.ufv.local`), así que hay que cambiarlo **antes** de instalar el AD.

### Comando ejecutado:
```powershell
Rename-Computer -NewName "DC01" -Force -Restart
```

**Desglose del comando:**
- `Rename-Computer` → cmdlet de PowerShell para cambiar el nombre del equipo
- `-NewName "DC01"` → el nuevo nombre que queremos
- `-Force` → no pide confirmación
- `-Restart` → reinicia automáticamente para aplicar el cambio

---

## Paso 9 — Configurar DNS del adaptador de red

### ¿Por qué el servidor necesita apuntar a sí mismo como DNS?
Cuando instalamos Active Directory, el AD necesita un servidor DNS para funcionar. El propio AD instalará su propio DNS. Por eso configuramos que el adaptador de red use `127.0.0.1` (que significa "yo mismo") como servidor DNS. Así cuando el AD busque `ufv.local`, lo encontrará en su propio DNS.

### Comandos ejecutados:

```powershell
# Ver qué adaptadores de red tiene el servidor
Get-NetAdapter
```
> Nos mostró que el adaptador se llama **"Ethernet 3"**

```powershell
# Configurar el DNS del adaptador para que apunte a sí mismo
Set-DnsClientServerAddress -InterfaceAlias "Ethernet 3" -ServerAddresses @("127.0.0.1")
```

**Desglose:**
- `Set-DnsClientServerAddress` → configura los servidores DNS del adaptador
- `-InterfaceAlias "Ethernet 3"` → en qué adaptador aplicarlo
- `-ServerAddresses @("127.0.0.1")` → la lista de servidores DNS (127.0.0.1 = yo mismo)

```powershell
# Verificar que se aplicó correctamente
Get-DnsClientServerAddress -InterfaceAlias "Ethernet 3"
```

---

## Paso 10 — Instalar Active Directory Domain Services (AD DS)

### ¿Qué es Active Directory?
Active Directory (AD) es el sistema de Microsoft para gestionar usuarios, equipos y políticas en una red empresarial. Es como una base de datos central que dice:
- Qué usuarios existen
- Qué contraseñas tienen
- A qué equipos pueden acceder
- Qué reglas (GPOs) se aplican

### ¿Qué es un dominio?
Un dominio es el nombre de tu red gestionada por AD. Nosotros usamos `ufv.local`. El `.local` indica que es una red interna (no accesible desde internet).

### ¿Qué es un bosque?
Un bosque es la estructura más alta del AD. Contiene uno o más dominios. En nuestro caso tenemos un bosque con un solo dominio (`ufv.local`).

### ¿Qué es DSRM?
DSRM (Directory Services Restore Mode) es un modo especial de arranque para recuperar el AD si algo falla. Necesita su propia contraseña separada de la del Administrador.

### Comandos ejecutados:

```powershell
# Instalar el rol de Active Directory Domain Services
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
```

**Desglose:**
- `Install-WindowsFeature` → instala roles y características de Windows Server
- `-Name AD-Domain-Services` → el rol que queremos instalar
- `-IncludeManagementTools` → instala también las herramientas de administración gráfica

```powershell
# Importar el módulo de despliegue de AD
Import-Module ADDSDeployment

# Crear la contraseña de recuperación (DSRM) de forma segura
$DSRMPassword = ConvertTo-SecureString -String "Admin1234!" -AsPlainText -Force

# Crear el bosque y promover el servidor a Controlador de Dominio
Install-ADDSForest -DomainName "ufv.local" `
                   -DomainNetbiosName "UFV" `
                   -ForestMode "WinThreshold" `
                   -DomainMode "WinThreshold" `
                   -SafeModeAdministratorPassword $DSRMPassword `
                   -InstallDns:$true `
                   -Force `
                   -NoRebootOnCompletion:$false
```

**Desglose:**
- `Install-ADDSForest` → crea un nuevo bosque de AD (instalación desde cero)
- `-DomainName "ufv.local"` → nombre completo del dominio
- `-DomainNetbiosName "UFV"` → nombre corto del dominio (usado en login como `UFV\usuario`)
- `-ForestMode "WinThreshold"` → nivel funcional del bosque (Windows Server 2016+)
- `-DomainMode "WinThreshold"` → nivel funcional del dominio
- `-SafeModeAdministratorPassword` → contraseña del modo de recuperación DSRM
- `-InstallDns:$true` → instala también el servidor DNS automáticamente
- `-Force` → no pide confirmación
- `-NoRebootOnCompletion:$false` → reinicia automáticamente al terminar

> Tras el reinicio, el login cambia a `UFV\Administrator`

---

## Paso 11 — Configurar DNS

### ¿Qué son los forwarders DNS?
Cuando un cliente pregunta al DNS por `google.com`, nuestro AD no lo sabe (solo conoce `ufv.local`). Los **forwarders** son servidores DNS externos a los que "reenvía" las preguntas que no sabe responder. Usamos `1.1.1.1` (Cloudflare) y `8.8.8.8` (Google).

### ¿Qué es una zona de búsqueda inversa?
El DNS normal hace: `nombre → IP` (ej: `DC01.ufv.local → 10.0.13.217`)
La zona inversa hace lo contrario: `IP → nombre` (ej: `10.0.13.217 → DC01.ufv.local`)
Es útil para diagnóstico y algunos servicios de red.

### Comandos ejecutados:

```powershell
# Configurar forwarders DNS (servidores externos para nombres de internet)
Set-DnsServerForwarder -IPAddress "1.1.1.1", "8.8.8.8"
```

```powershell
# Crear zona de búsqueda inversa para nuestra red
Add-DnsServerPrimaryZone -NetworkID "10.0.0.0/24" -ReplicationScope "Domain"
```

**Desglose:**
- `-NetworkID "10.0.0.0/24"` → el rango de red para el que creamos la zona inversa
- `-ReplicationScope "Domain"` → se replica a todos los DCs del dominio

```powershell
# Ver todas las zonas DNS creadas
Get-DnsServerZone | Select-Object ZoneName, ZoneType
```

---

## Paso 12 — Instalar y configurar DHCP

### ¿Qué es DHCP?
DHCP (Dynamic Host Configuration Protocol) es el servicio que **asigna IPs automáticamente** a los dispositivos cuando se conectan a la red. Sin DHCP, tendrías que configurar manualmente la IP de cada servidor Linux.

Cuando el Alumno B una su Windows al dominio, recibirá su IP automáticamente del DHCP de nuestro AD.

### ¿Qué es un ámbito?
Un ámbito (scope) es el rango de IPs que el DHCP puede repartir. Nosotros definimos de `10.0.13.100` a `10.0.13.150`, es decir, puede dar hasta 51 IPs diferentes.

### ¿Por qué excluimos la IP del servidor?
La IP `10.0.13.217` es la de nuestro propio servidor AD. Si el DHCP la diera a otro cliente, habría conflicto. Por eso la excluimos del rango.

### Comandos ejecutados:

```powershell
# Instalar el rol DHCP
Install-WindowsFeature -Name DHCP -IncludeManagementTools
```

```powershell
# Autorizar el servidor DHCP en el dominio (necesario para que funcione en un AD)
Add-DhcpServerInDC -DnsName "DC01.ufv.local"
```

```powershell
# Crear el ámbito de IPs que repartirá el DHCP
Add-DhcpServerV4Scope -Name "UFV-Private" `
                      -StartRange 10.0.13.100 `
                      -EndRange 10.0.13.150 `
                      -SubnetMask 255.255.255.0 `
                      -State Active
```

**Desglose:**
- `-StartRange` y `-EndRange` → rango de IPs que puede repartir
- `-SubnetMask 255.255.255.0` → máscara de red /24
- `-State Active` → activo desde el momento de creación

```powershell
# Configurar opciones: qué información adicional da el DHCP junto con la IP
Set-DhcpServerV4OptionValue -ScopeId 10.0.13.0 `
                            -DnsServer 10.0.13.217 `
                            -Router 10.0.13.1 `
                            -DnsDomain "ufv.local"
```

**Desglose:**
- `-DnsServer 10.0.13.217` → le dice al cliente que use nuestro AD como DNS
- `-Router 10.0.13.1` → puerta de enlace (gateway)
- `-DnsDomain "ufv.local"` → el dominio al que pertenece

```powershell
# Excluir la IP del servidor del rango (para no dársela a un cliente)
Add-DhcpServerV4ExclusionRange -ScopeId 10.0.13.0 -StartRange 10.0.13.217 -EndRange 10.0.13.217
```

```powershell
# Verificar que el ámbito está activo
Get-DhcpServerV4Scope
```

---

## Paso 13 — Configurar NTP (servidor de hora)

### ¿Por qué es importante la hora en Active Directory?
Active Directory usa Kerberos para autenticar usuarios. Kerberos es muy estricto con la hora: si un cliente tiene más de 5 minutos de diferencia con el servidor, **rechaza la autenticación**. Por eso todos los servidores Linux tienen que sincronizar la hora con nuestro AD.

### ¿Qué es NTP?
NTP (Network Time Protocol) es el protocolo para sincronizar la hora en red. Usa el puerto UDP 123.

### Comandos ejecutados:

```powershell
# Configurar Windows como servidor NTP, sincronizando con servidores públicos
w32tm /config /manualpeerlist:"pool.ntp.org" /syncfromflags:manual /reliable:YES /update
```

**Desglose:**
- `w32tm` → herramienta de configuración del servicio de tiempo de Windows
- `/manualpeerlist:"pool.ntp.org"` → se sincroniza con los servidores públicos de NTP
- `/reliable:YES` → marca este servidor como fuente fiable de tiempo para los clientes
- `/update` → aplica los cambios

```powershell
# Reiniciar el servicio de tiempo
Restart-Service W32Time
```

```powershell
# Verificar que el servicio funciona
w32tm /query /status
```

```powershell
# Abrir el puerto 123 UDP en el firewall de Windows para que los clientes puedan conectarse
New-NetFirewallRule -Name "NTP-UDP" -DisplayName "NTP Server UDP 123" `
                    -Direction Inbound -Protocol UDP -LocalPort 123 `
                    -Action Allow
```

**Desglose:**
- `-Direction Inbound` → tráfico entrante
- `-Protocol UDP` → protocolo UDP
- `-LocalPort 123` → puerto NTP
- `-Action Allow` → permitir el tráfico

---

## Paso 14 — Crear recurso CIFS (carpeta compartida)

### ¿Qué es CIFS?
CIFS (Common Internet File System) es el protocolo de Windows para compartir carpetas en red. Es lo que usas cuando accedes a `\\servidor\carpeta` en Windows, o cuando montas una carpeta de red en Linux.

### ¿Para qué lo necesitamos?
La GPO 2 va a mapear automáticamente una unidad de red en los clientes cuando un usuario inicia sesión. Esa unidad apuntará a esta carpeta compartida.

### Comandos ejecutados:

```powershell
# Crear la carpeta física en el disco
New-Item -Path "C:\Compartido" -ItemType Directory
```

```powershell
# Compartirla en red con permisos para todos los usuarios del dominio
New-SmbShare -Name "Compartido" `
             -Path "C:\Compartido" `
             -FullAccess "UFV\Domain Users"
```

**Desglose:**
- `New-SmbShare` → crea un recurso compartido de red
- `-Name "Compartido"` → nombre del recurso (así aparece en la ruta `\\DC01\Compartido`)
- `-Path "C:\Compartido"` → carpeta física que se comparte
- `-FullAccess "UFV\Domain Users"` → todos los usuarios del dominio tienen acceso total

```powershell
# Verificar que el recurso existe
Get-SmbShare -Name "Compartido"

# Verificar que es accesible por ruta UNC
Test-Path "\\DC01\Compartido"
```

> La ruta UNC `\\DC01\Compartido` es la que usaremos en la GPO para mapear la unidad de red.

---

## Paso 15 — Crear OUs, Grupos y Usuarios

### ¿Qué son las OUs (Unidades Organizativas)?
Las OUs son como carpetas dentro del Active Directory para organizar los objetos (usuarios, equipos, grupos). Permiten aplicar políticas (GPOs) de forma selectiva.

Creamos dos OUs:
- `UFV_Users` → para los usuarios
- `UFV_Computers` → para los equipos que se unan al dominio

### ¿Qué es un grupo de seguridad?
Un grupo de seguridad agrupa usuarios para aplicarles permisos o políticas de forma colectiva. En lugar de aplicar una GPO a cada usuario uno por uno, la aplicas al grupo.

### Comandos ejecutados:

```powershell
# Importar el módulo de Active Directory
Import-Module ActiveDirectory

# Crear la OU para usuarios
New-ADOrganizationalUnit -Name "UFV_Users" -Path "DC=UFV,DC=local"

# Crear la OU para equipos
New-ADOrganizationalUnit -Name "UFV_Computers" -Path "DC=UFV,DC=local"
```

**Desglose de `-Path "DC=UFV,DC=local"`:**
- Esta es la ruta en formato LDAP del dominio `ufv.local`
- `DC=UFV` → componente del dominio "UFV"
- `DC=local` → componente del dominio "local"

```powershell
# Crear el grupo de seguridad dentro de la OU de usuarios
New-ADGroup -Name "users_ufv" `
            -GroupScope Global `
            -GroupCategory Security `
            -Path "OU=UFV_Users,DC=UFV,DC=local"
```

**Desglose:**
- `-GroupScope Global` → el grupo es visible en todo el dominio
- `-GroupCategory Security` → tipo seguridad (para permisos y GPOs), no distribución (para email)

```powershell
# Crear contraseña segura para los usuarios
$pass = ConvertTo-SecureString "Usuario1234!" -AsPlainText -Force

# Crear usuario1
New-ADUser -Name "user1" `
           -SamAccountName "user1" `
           -UserPrincipalName "user1@ufv.local" `
           -Path "OU=UFV_Users,DC=UFV,DC=local" `
           -AccountPassword $pass `
           -Enabled $true

# Crear usuario2
New-ADUser -Name "user2" `
           -SamAccountName "user2" `
           -UserPrincipalName "user2@ufv.local" `
           -Path "OU=UFV_Users,DC=UFV,DC=local" `
           -AccountPassword $pass `
           -Enabled $true
```

**Desglose:**
- `-SamAccountName` → nombre de login corto (ej: `UFV\user1`)
- `-UserPrincipalName` → nombre de login en formato email (ej: `user1@ufv.local`)
- `-Enabled $true` → la cuenta está activa desde el principio

```powershell
# Añadir ambos usuarios al grupo
Add-ADGroupMember -Identity "users_ufv" -Members "user1","user2"

# Verificar que están en el grupo
Get-ADGroupMember -Identity "users_ufv"
```

---

## Paso 16 — Crear las GPOs (Políticas de Grupo)

### ¿Qué son las GPOs?
Las GPOs (Group Policy Objects) son reglas que se aplican automáticamente a usuarios o equipos del dominio. Pueden hacer cosas como:
- Bloquear el botón de apagado
- Mapear una unidad de red automáticamente
- Instalar software
- Configurar el fondo de pantalla

Son la herramienta más potente del AD para administrar una red de forma centralizada.

### GPO 1 — Impedir apagar la máquina

#### ¿Por qué?
En entornos empresariales, los usuarios normales no deben poder apagar o reiniciar los equipos. Eso lo hace solo el administrador. Esta GPO elimina las opciones de apagado, reinicio, suspensión e hibernación del menú de inicio.

#### Comandos ejecutados:

```powershell
# Instalar la consola de administración de GPOs (GPMC)
Install-WindowsFeature -Name GPMC

# Crear la GPO vacía
New-GPO -Name "GPO_NoShutdown"

# Configurar la restricción en el registro de Windows
# HKCU = HKEY_CURRENT_USER (aplica al usuario, no al equipo)
# NoClose = 1 significa "deshabilitar el botón de apagado"
Set-GPRegistryValue -Name "GPO_NoShutdown" `
                    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
                    -ValueName "NoClose" `
                    -Type DWord `
                    -Value 1

# Vincular la GPO a la OU de usuarios (para que se aplique a los usuarios de esa OU)
New-GPLink -Name "GPO_NoShutdown" -Target "OU=UFV_Users,DC=UFV,DC=local"
```

### GPO 2 — Mapear unidad de red automáticamente

#### ¿Por qué?
Cuando un usuario del dominio inicia sesión, queremos que automáticamente se le conecte la unidad `Z:` apuntando a la carpeta compartida `\\DC01\Compartido`. Así tienen acceso a los recursos compartidos sin tener que hacerlo manualmente.

#### Comandos ejecutados:

```powershell
# Crear la GPO vacía
New-GPO -Name "GPO_NetworkDrive"

# Configurar la ruta de red (UNC) para la unidad Z:
Set-GPRegistryValue -Name "GPO_NetworkDrive" `
                    -Key "HKCU\Network\Z" `
                    -ValueName "RemotePath" `
                    -Type String `
                    -Value "\\DC01\Compartido"

Set-GPRegistryValue -Name "GPO_NetworkDrive" `
                    -Key "HKCU\Network\Z" `
                    -ValueName "ConnectFlags" `
                    -Type DWord `
                    -Value 0

# Vincular la GPO a la OU de usuarios
New-GPLink -Name "GPO_NetworkDrive" -Target "OU=UFV_Users,DC=UFV,DC=local"
```

### Filtrar las GPOs para que solo apliquen al grupo `users_ufv`

#### ¿Por qué filtrar?
Sin filtro, estas GPOs se aplicarían a **todos los usuarios** de la OU, incluyendo el Administrator. No queremos que el Administrador no pueda apagar la máquina. Solo queremos que aplique a los usuarios normales del grupo `users_ufv`.

```powershell
# GPO_NoShutdown: dar permisos de aplicación al grupo users_ufv
Set-GPPermission -Name "GPO_NoShutdown" -TargetName "users_ufv" -TargetType Group -PermissionLevel GpoApply

# Quitar permiso de aplicación a "Authenticated Users" (todos los usuarios autenticados)
# Mantenemos solo lectura para que puedan leer la GPO pero no todos la apliquen
Set-GPPermission -Name "GPO_NoShutdown" -TargetName "Authenticated Users" -TargetType Group -PermissionLevel GpoRead

# Lo mismo para GPO_NetworkDrive
Set-GPPermission -Name "GPO_NetworkDrive" -TargetName "users_ufv" -TargetType Group -PermissionLevel GpoApply
Set-GPPermission -Name "GPO_NetworkDrive" -TargetName "Authenticated Users" -TargetType Group -PermissionLevel GpoRead
```

**Desglose de permisos:**
- `GpoApply` → la GPO se aplica a este grupo (la reciben y la cumplen)
- `GpoRead` → pueden leer la GPO pero no se les aplica

---

## Paso 17 — Verificación final

### Comando de verificación completa:

```powershell
Write-Host "=== SERVICIOS ===" -ForegroundColor Cyan
Get-Service NTDS, DNS, DHCPServer, W32Time | Select-Object Name, Status

Write-Host "=== DOMINIO ===" -ForegroundColor Cyan
Get-ADDomain | Select-Object DNSRoot, NetBIOSName

Write-Host "=== OUs ===" -ForegroundColor Cyan
Get-ADOrganizationalUnit -Filter * | Select-Object Name

Write-Host "=== USUARIOS EN GRUPO ===" -ForegroundColor Cyan
Get-ADGroupMember -Identity "users_ufv" | Select-Object Name

Write-Host "=== DHCP ===" -ForegroundColor Cyan
Get-DhcpServerV4Scope | Select-Object Name, ScopeId, State

Write-Host "=== GPOs ===" -ForegroundColor Cyan
Get-GPO -All | Select-Object DisplayName, GpoStatus

Write-Host "=== CARPETA COMPARTIDA ===" -ForegroundColor Cyan
Get-SmbShare -Name "Compartido"
```

### ¿Qué debe aparecer en cada sección?

| Sección | Resultado esperado |
|---|---|
| NTDS | Running |
| DNS | Running |
| DHCPServer | Running |
| W32Time | Running |
| DNSRoot | ufv.local |
| OUs | UFV_Users, UFV_Computers |
| Usuarios | user1, user2 |
| DHCP | UFV-Private, Active |
| GPOs | GPO_NoShutdown, GPO_NetworkDrive |
| Compartida | Compartido |

---

# Resumen de lo que tenemos

| Componente | Estado | Detalle |
|---|---|---|
| Usuario IAM | ✅ | `admin-lab` con AdministratorAccess |
| Budget | ✅ | `presupuesto-lab` $10/mes |
| VPC | ✅ | `vpc-practica` 10.0.0.0/16 |
| Security Group | ✅ | `sg-windows-ad` con puertos AD abiertos |
| Instancia EC2 | ✅ | `AD-DC01` Windows Server 2022 |
| Elastic IP | ✅ | IP fija asignada |
| Nombre servidor | ✅ | `DC01` |
| Active Directory | ✅ | Dominio `ufv.local` |
| DNS | ✅ | Zonas + forwarders 1.1.1.1 / 8.8.8.8 |
| DHCP | ✅ | Ámbito UFV-Private 10.0.13.100-150 |
| NTP | ✅ | Puerto 123 UDP abierto |
| CIFS | ✅ | `\\DC01\Compartido` |
| OUs | ✅ | UFV_Users, UFV_Computers |
| Grupo | ✅ | `users_ufv` |
| Usuarios | ✅ | `user1`, `user2` |
| GPO_NoShutdown | ✅ | Aplicada a users_ufv |
| GPO_NetworkDrive | ✅ | Unidad Z: → \\DC01\Compartido |

---

# Datos importantes para compartir con el equipo

El **Alumno B** (cliente Windows) y los **alumnos Linux** necesitarán estos datos:

| Dato | Valor |
|---|---|
| Dominio | `ufv.local` |
| IP privada del AD | `10.0.13.217` |
| Elastic IP del AD | *(la que te asignó AWS)* |
| DNS del dominio | `10.0.13.217` |
| Usuario admin | `UFV\Administrator` |
| Usuario de prueba | `user1` / contraseña: `Usuario1234!` |
| Carpeta compartida | `\\DC01\Compartido` |
| Servidor NTP | `10.0.13.217` (puerto UDP 123) |
