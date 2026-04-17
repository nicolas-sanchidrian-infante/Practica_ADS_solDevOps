¡Claro que sí! He estructurado y formateado el contenido de tu archivo de texto en un documento Markdown limpio y organizado. He utilizado encabezados, listas y bloques de código para que la información sea mucho más fácil de leer y seguir durante tus prácticas de laboratorio.

Aquí tienes tu guía transformada:

---

Instalación y Configuración de Active Directory 

## Objetivos del Laboratorio

* Configurar una red privada para el dominio asignando una IP estática al servidor.


* Configurar un adaptador de red para la comunicación interna del dominio.


* Establecer el servidor DNS local para la resolución de nombres.


* Cambiar el nombre del servidor (opcional pero recomendado) para una identificación clara, por ejemplo, DC01.


* Instalar el rol de Active Directory Domain Services (AD DS) y promover el servidor a Controlador de Dominio.


* Crear un nuevo bosque con un dominio, como `ufv.local`.


* Configurar los niveles funcionales del bosque y del dominio.


* Establecer la contraseña del modo de restauración de servicios de directorio (DSRM).


* Verificar las zonas DNS creadas automáticamente y configurar forwarders para la resolución de nombres externos.


* Crear una zona de búsqueda inversa para la red privada.


* Instalar el rol de DHCP y autorizar el servidor en el dominio.


* Crear un ámbito de direcciones IP para la red privada, excluyendo direcciones IP estáticas.


* Configurar opciones de DHCP como la puerta de enlace, el servidor DNS y el dominio.


* Generalizar el sistema cliente con sysprep si es necesario.


* Unir el cliente al dominio creado.


* Crear Unidades Organizativas (OUs) para organizar usuarios y computadoras, por ejemplo, `UFV_Users` y `UFV_Computers`.


* Crear un grupo de seguridad global, por ejemplo, `users_ufv`, para gestionar permisos.


* Agregar usuarios existentes al grupo para aplicar políticas de grupo.


* Crear una GPO para deshabilitar los comandos de apagado, reinicio, suspensión e hibernación en el menú Inicio.


* Configurar la GPO mediante plantillas administrativas.


* Vincular la GPO a la OU de usuarios.


* Filtrar la aplicación de la GPO por el grupo de seguridad `users_ufv` y eliminar el permiso de aplicación para usuarios autenticados.


* Comprobar la correcta aplicación de permisos y enlaces de GPOs.



---

## 1. Configuración de Red 

### Interfaz Gráfica (GUI)

* Abrir "Conexiones de red" mediante `ncpa.cpl` e identificar el adaptador "Ethernet 2", que será la red privada.


* Configurar IPv4 con la IP `10.0.0.200` y la máscara `255.255.255.0`.


* Establecer la puerta de enlace en `10.0.0.1` (si hay un router, si no, dejar en blanco).


* Configurar los DNS con `127.0.0.1` y `10.0.0.200`.


* Cambiar el nombre del adaptador a "UFV-Private" haciendo clic derecho y seleccionando "Cambiar nombre".



### Interfaz de Línea de Comandos (CLI)

```powershell
# Identificar el adaptador de red privado (Ethernet 2)
$privateAdapter = Get-NetAdapter -Name "Ethernet 2"

# Verificar que el adaptador existe y está activo
if (-not $privateAdapter) {
    Write-Host "El adaptador Ethernet 2 no fue encontrado." -ForegroundColor Red
    exit
}

# Renombrar el adaptador para fácil identificación
Rename-NetAdapter -Name $privateAdapter.Name -NewName "UFV-Private"

# Deshabilitar DHCP en el adaptador privado (para que no obtenga IP automática)
Set-NetIPInterface -InterfaceAlias "UFV-Private" -Dhcp Disabled

# Asignar IP estática, máscara y puerta de enlace
New-NetIPAddress -InterfaceAlias "UFV-Private" `
                 -IPAddress 10.0.0.200 `
                 -PrefixLength 24 `
                 -DefaultGateway 10.0.0.1

# Configurar los servidores DNS: primero el propio servidor (loopback) y luego su IP
Set-DnsClientServerAddress -InterfaceAlias "UFV-Private" `
                           -ServerAddresses @("127.0.0.1", "10.0.0.200")

# Verificar la configuración
Get-NetIPConfiguration -InterfaceAlias "UFV-Private"

```



---

## 2. Cambiar Nombre del Servidor 

### Interfaz Gráfica (GUI)

* Abrir "System Properties" con `sysdm.cpl`, ir a la pestaña "Computer Name" y hacer clic en "Change".


* Escribir el nuevo nombre, por ejemplo, `DC01`, aceptar y reiniciar.



### Interfaz de Línea de Comandos (CLI)

```powershell
# Cambiar el nombre del equipo a DC01
Rename-Computer -NewName "DC01" -Force -Restart

# Nota: Después del reinicio, continúa con los siguientes pasos.

```



---

## 3. Instalar Active Directory y Promover a Controlador de Dominio 

### Interfaz Gráfica (GUI)

* Abrir "Server Manager", hacer clic en "Add roles and features", seleccionar "Role-based or feature-based installation" y elegir el servidor actual.


* Marcar "Active Directory Domain Services", hacer clic en "Add Features" y seguir el asistente hasta instalar.


* Hacer clic en el botón de notificación y seleccionar "Promote this server to a domain controller".


* Seleccionar "Add a new forest" y escribir `ufv.local`.


* Configurar el nivel funcional del bosque y dominio (Windows Server 2016 o 2019) y especificar la contraseña de DSRM.


* El servidor DNS se instalará automáticamente; seguir el asistente y reiniciar al finalizar.



### Interfaz de Línea de Comandos (CLI)

```powershell
# Instalar el rol de Active Directory Domain Services
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Importar el módulo de implementación de AD
Import-Module ADDSDeployment

# Crear una contraseña segura para el modo de restauración de servicios de directorio (DSRM)
$DSRMPassword = ConvertTo-SecureString -String "TuContraseñaSegura" -AsPlainText -Force

# Promover el servidor a controlador de dominio, creando un nuevo bosque
Install-ADDSForest -DomainName "ufv.local" `
                   -DomainNetbiosName "UFV" `
                   -ForestMode "WinThreshold" `
                   -DomainMode "WinThreshold" `
                   -SafeModeAdministratorPassword $DSRMPassword `
                   -InstallDns:$true `
                   -Force `
                   -NoRebootOnCompletion:$true

# Después de la instalación, es necesario reiniciar
Restart-Computer -Force

```



---

## 4. Configuración de DNS 

### Interfaz Gráfica (GUI)

* Abrir "DNS Manager" (`dnsmgmt.msc`), expandir el servidor y verificar las zonas creadas, que deberían ser `ufv.local` y `_msdcs.ufv.local`.


* Configurar forwarders haciendo clic derecho en el servidor, ir a "Properties", pestaña "Forwarders", clic en "Edit" y agregar los DNS forwarders, como `1.1.1.1` y `8.8.8.8`.


* Para crear una zona de búsqueda inversa, hacer clic derecho en "Reverse Lookup Zones", "New Zone", seleccionar "Primary zone", elegir replicación en todo el dominio y "IPv4 Reverse Lookup Zone", introduciendo el Network ID `10.0.0`.



### Interfaz de Línea de Comandos (CLI)

```powershell
# Configurar forwarders DNS (para resolución de nombres externos)
Set-DnsServerForwarder -IPAddress "1.1.1.1", "8.8.8.8"

# Crear zona de búsqueda inversa para la red 10.0.0.0/24
Add-DnsServerPrimaryZone -NetworkID "10.0.0.0/24" -ReplicationScope "Domain"

# Verificar las zonas DNS
Get-DnsServerZone

# Crear registros DNS adicionales si es necesario (por ejemplo, para el servidor web)
Add-DnsServerResourceRecordA -Name "www" -ZoneName "ufv.local" -IPv4Address "10.0.0.200" -CreatePtr

```



---

## 5. Instalar y Configurar DHCP 

### Interfaz Gráfica (GUI)

* En "Server Manager", hacer clic en "Add roles and features", seleccionar "Role-based or feature-based installation", elegir el servidor actual y marcar "DHCP Server".


* Tras la instalación, hacer clic en las notificaciones del Server Manager y seleccionar "Complete DHCP configuration", siguiendo el asistente con las credenciales por defecto.


* Abrir "DHCP Manager" (`dhcpmgmt.msc`), expandir el servidor, hacer clic derecho en IPv4 y seleccionar "New Scope".


* Nombrar el ámbito como `UFV-Private`, con rango IP de `10.0.0.100` a `10.0.0.150` y máscara `255.255.255.0`.


* Excluir la IP `10.0.0.200` y cualquier otra estática.


* Establecer la duración de concesión en 8 días y configurar las opciones (Router: `10.0.0.1`, DNS: `10.0.0.200`, Dominio: `ufv.local`), activando el ámbito al final.



### Interfaz de Línea de Comandos (CLI)

```powershell
# Instalar el rol de DHCP
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Autorizar el servidor DHCP en el dominio
Add-DhcpServerInDC -DnsName "$env:COMPUTERNAME.ufv.local"

# Configurar el ámbito de DHCP
Add-DhcpServerV4Scope -Name "UFV-Private" `
                      -StartRange 10.0.0.100 `
                      -EndRange 10.0.0.150 `
                      -SubnetMask 255.255.255.0 `
                      -State Active

# Excluir direcciones IP (por ejemplo, la IP del servidor y otras estáticas)
Add-DhcpServerV4ExclusionRange -ScopeId 10.0.0.0 -StartRange 10.0.0.200 -EndRange 10.0.0.200

# Configurar las opciones del ámbito
Set-DhcpServerV4OptionValue -ScopeId 10.0.0.0 `
                            -DnsServer 10.0.0.200 `
                            -Router 10.0.0.1 `
                            -DnsDomain "ufv.local"

# Configurar el servidor DHCP para que actualice los registros DNS de los clientes
Set-DhcpServerV4DnsSetting -DynamicUpdates "Always" -DeleteDnsRRonLeaseExpiry $true

# Reiniciar el servicio DHCP
Restart-Service DHCPServer

# Verificar el ámbito creado
Get-DhcpServerV4Scope

```



---

## 6. Unir Cliente al Dominio (Lado del Cliente) 

### Interfaz de Línea de Comandos (CLI)

```powershell
# 1. Ejecutar sysprep para generalizar el sistema
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown

# 2. Después del reinicio, ejecutar este comando para unirse al dominio
Add-Computer -DomainName "ufv.local" -Credential UFV\Administrator -Force -Restart

```



---

## 7. Crear Unidades Organizativas (OUs) 

### Interfaz Gráfica (GUI)

* Abrir "Server Manager", ir a "Tools" y seleccionar "Active Directory Users and Computers".


* Hacer clic derecho en el dominio, ir a "New" y seleccionar "Organizational Unit".


* Nombrar la OU como `UFV_Computers` para las computadoras y crear otra llamada `UFV_Users` para los usuarios.



### Interfaz de Línea de Comandos (CLI)

```powershell
# Importar el módulo de ActiveDirectory
Import-Module ActiveDirectory

# Crear la OU para computadoras
New-ADOrganizationalUnit -Name "UFV_Computers" -Path "DC=UFV,DC=local"

# Crear la OU para usuarios
New-ADOrganizationalUnit -Name "UFV_Users" -Path "DC=UFV,DC=local"

```



---

## 8. Crear Grupos 

### Interfaz Gráfica (GUI)

* En "Active Directory Users and Computers", ir a la OU donde se creará el grupo, como `UFV_Users` o en la raíz.


* Hacer clic derecho, seleccionar "New" y luego "Group".


* Crear un grupo de seguridad global llamado `users_ufv`.



### Interfaz de Línea de Comandos (CLI)

```powershell
# Crear el grupo users_ufv en la OU UFV_Users
New-ADGroup -Name "users_ufv" -GroupScope Global -GroupCategory Security -Path "OU=UFV_Users,DC=UFV,DC=local"

```



---

## 9. Mover Usuarios al Grupo "users_ufv" 

### Interfaz Gráfica (GUI)

* Navegar a los usuarios que se desean agregar.


* Hacer clic derecho en el usuario, seleccionar "Add to a group", escribir `users_ufv`, hacer clic en "Check Names" y aceptar.



### Interfaz de Línea de Comandos (CLI)

```powershell
# Agregar un usuario existente al grupo
Add-ADGroupMember -Identity "users_ufv" -Members "user1"

```



---

## 10. Crear y Configurar Políticas de Grupo (GPOs) 

### Interfaz Gráfica (GUI)

* En "Server Manager", ir a "Tools" y seleccionar "Group Policy Management".


* Hacer clic derecho en "Group Policy Objects" y seleccionar "New".


* Nombrar la política como `GPO_NoShutdown` y hacer clic en OK.


* Hacer clic derecho en la nueva GPO y seleccionar "Edit".


* Navegar a: `User Configuration -> Policies -> Administrative Templates -> Start Menu and Taskbar`.


* Buscar y hacer doble clic en la opción que elimina y previene el acceso a los comandos de apagado, reinicio, suspensión e hibernación, seleccionar "Enabled" y aceptar.



### Interfaz de Línea de Comandos (CLI)

```powershell
Install-WindowsFeature -Name GPMC
New-GPO -Name "GPO_NoShutdown"
Set-GPRegistryValue -Name "GPO_NoShutdown" -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoClose" -Type DWord -Value 1

```



---

## 11. Vincular GPOs a la OU y Filtrar por Grupo 

### Interfaz Gráfica (GUI)

* En "Group Policy Management", navegar a la OU que contiene los usuarios (las GPOs de configuración de usuario deben vincularse a una OU de usuarios o a la raíz con filtrado).


* Para aplicarlas a la OU `UFV_Users`, hacer clic derecho en ella y seleccionar "Link an Existing GPO".


* Seleccionar la política `GPO_NoShutdown`.


* Para filtrar por el grupo `users_ufv`, hacer clic en la GPO vinculada, ir a la pestaña "Scope", sección "Security Filtering", eliminar "Authenticated Users" y agregar el grupo `users_ufv`.


* 
*Nota*: Asegurar que los usuarios tienen permisos de lectura y aplicación ("Read" y "Apply Group Policy") en la GPO; al agregar el grupo, por defecto tendrán estos permisos.



### Interfaz de Línea de Comandos (CLI)

```powershell
New-GPLink -Name "GPO_NoShutdown" -Target "OU=UFV_Users,DC=UFV,DC=local"
$gpo1 = Get-GPO -Name "GPO_NoShutdown"
# Obtener el GUID del grupo "users_ufv"
$group = Get-ADGroup -Identity "users_ufv"	
Set-GPPermission -Name "GPO_NoShutdown" -TargetName $group.SamAccountName -TargetType Group -PermissionLevel GpoApply	
Set-GPPermission -Name "GPO_NoShutdown" -TargetName "Authenticated Users" -TargetType Group -PermissionLevel GpoRead	

```



---

## 12. Comprobaciones (Checks) 

### Interfaz Gráfica (GUI)

1. 
**Red**: Abrir "Conexiones de red" (`ncpa.cpl`) y verificar que "UFV-Private" tiene la IP `10.0.0.200`, máscara `255.255.255.0`, y DNS `127.0.0.1` y `10.0.0.200`.


2. 
**Active Directory**: En el "Server Manager", verificar que el rol "AD DS" está instalado y en ejecución. En "Active Directory Users and Computers", verificar la existencia de las OUs y el grupo `users_ufv`.


3. 
**DNS**: En el "DNS Manager", verificar las zonas `ufv.local` y la zona inversa, además de los forwarders configurados (`1.1.1.1` y `8.8.8.8`).


4. 
**DHCP**: En el "DHCP Manager", comprobar que el ámbito "UFV-Private" está activo y verificar sus opciones (gateway `10.0.0.1`, DNS `10.0.0.200`, dominio `ufv.local`).


5. 
**GPOs**: En "Group Policy Management", verificar que la GPO está vinculada a `UFV_Users`, que el grupo `users_ufv` tiene permisos de aplicación y que la política de restricción del menú Inicio está habilitada.


6. 
**Cliente**: En el cliente, abrir "System Properties" y comprobar que el dominio es `ufv.local`. Iniciar sesión con un usuario del dominio y verificar que el menú Inicio no muestra las opciones de apagado.



### Interfaz de Línea de Comandos (CLI)

```powershell
# 1. Configuración de red
Get-NetIPConfiguration -InterfaceAlias "UFV-Private"

# 2. Active Directory
Get-Service NTDS
Get-ADOrganizationalUnit -Filter * -SearchBase "DC=UFV,DC=local" | Select-Object Name
Get-ADGroup "users_ufv"

# 3. DNS
Get-Service DNS
Get-DnsServerZone | Where-Object {$_.ZoneType -eq "Primary"}
Get-DnsServerForwarder

# 4. DHCP
Get-Service DHCPServer
Get-DhcpServerV4Scope

# 5. GPOs
Get-GPO -Name "GPO_NoShutdown"
Get-GPInheritance -Target "OU=UFV_Users,DC=UFV,DC=local"
Get-GPPermission -Name "GPO_NoShutdown" -All | Select-Object Trustee, Permission

# 6. Cliente (si se tiene acceso, desde el cliente)
systeminfo | findstr /C:"Domain"
gpresult /r | findstr "GPO_NoShutdown"
reg query "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v NoClose

```

