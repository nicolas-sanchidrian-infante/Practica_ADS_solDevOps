# Bitacora Tecnica - Alumno B (LB + DB)

## 1. Objetivo

Documentar los pasos ejecutados para desplegar y configurar la parte del Alumno B:

- Load Balancer Linux con Nginx.
- Servidor de base de datos PostgreSQL.
- Validaciones de conectividad, operacion y backup.

## 2. Contexto del despliegue

- Stack CloudFormation: `dt-b-lb-db`
- Region: `eu-south-2`
- Perfil AWS CLI: `NicolasB`
- Plantilla: `cloudformation/strict-5/stack-B-lb-db.yaml`
- Email de budget usado en parametros: `9300911@alumnos.ufv.es`

## 3. Pasos previos ejecutados

### 3.1 Configuracion de AWS CLI

Se configuro el perfil y se valido identidad:

```powershell
aws configure --profile NicolasB
aws sts get-caller-identity --profile NicolasB
```

### 3.2 Key pair para EC2

Se creo key pair en cuenta/región y se guardo el PEM:

```powershell
aws ec2 create-key-pair --profile NicolasB --region eu-south-2 --key-name partB-key --query "KeyMaterial" --output text > C:\Users\nsanc\Downloads\partB-key.pem
```

## 4. Despliegue de infraestructura B (CloudFormation)

Comando de despliegue utilizado:

```powershell
aws cloudformation deploy --profile NicolasB --region eu-south-2 --stack-name dt-b-lb-db --template-file cloudformation/strict-5/stack-B-lb-db.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides KeyPairName=partB-key AdminCidr=195.57.190.10/32 BudgetEmail=9300911@alumnos.ufv.es AmiLinux=/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id
```

### 4.1 Incidencias encontradas y resolucion

1. Parametro SSM AMI por defecto no existente en la cuenta/región:
   - Error: ruta `.../ebs-gp3/ami-id` no resolvia.
   - Solucion: usar `.../ebs-gp2/ami-id`.

2. Tipo `AWS::Budgets::Budget` no reconocido por CloudFormation en este entorno:
   - Error: `Unrecognized resource types: [AWS::Budgets::Budget]`.
   - Solucion aplicada: retirar recurso `MonthlyBudget` de la plantilla `stack-B-lb-db.yaml` para completar despliegue.

## 5. Salidas obtenidas del stack B

Comando de consulta:

```powershell
aws cloudformation describe-stacks --profile NicolasB --region eu-south-2 --stack-name dt-b-lb-db --query "Stacks[0].Outputs" --output table
```

Valores relevantes:

- `LBEip`: `51.48.226.94`
- `DBEip`: `15.216.168.241`
- `LBInstanceId`: `i-0f44658be5b545d8e`
- `DBInstanceId`: `i-055ddfa789e95e8ee`

## 6. Correccion de clave PEM para SSH en Windows

### 6.1 Problema detectado

Error SSH:

- `Load key ... invalid format`

Diagnostico:

- El archivo PEM original se guardo en UTF-16 (BOM `FF FE`).

### 6.2 Solucion aplicada

Se genero copia en ASCII:

```powershell
$src='C:\Users\nsanc\Downloads\partB-key.pem'
$dst='C:\Users\nsanc\Downloads\partB-key-fixed.pem'
Get-Content -Path $src -Raw | Set-Content -Path $dst -Encoding ascii
```

## 7. Acceso SSH validado

### 7.1 LB

```powershell
ssh -i "C:\Users\nsanc\Downloads\partB-key-fixed.pem" ubuntu@51.48.226.94
```

### 7.2 DB

```powershell
ssh -i "C:\Users\nsanc\Downloads\partB-key-fixed.pem" ubuntu@15.216.168.241
```

## 8. Configuracion del LB (Nginx)

### 8.1 Instalacion y servicio

```bash
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 8.2 Configuracion aplicada

Se creo `dt-lb.conf` en `/etc/nginx/sites-available/` (ruta correcta en Ubuntu) y se activo en `sites-enabled`.

```bash
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
sudo tee /etc/nginx/sites-available/dt-lb.conf > /dev/null <<'EOF'
upstream ufv_profesores {
    server 10.30.1.10:80;
}

upstream ufv_alumnos {
    server 10.40.1.10:80;
}

upstream ufv_practicas {
    server 10.50.1.10:80;
}

server {
    listen 80;
    server_name _;

    location / {
        return 200 'LB OK\n';
        add_header Content-Type text/plain;
    }

    location /profesores/ {
        proxy_pass http://ufv_profesores/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /alumnos/ {
        proxy_pass http://ufv_alumnos/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /practicas/ {
        proxy_pass http://ufv_practicas/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/dt-lb.conf /etc/nginx/sites-enabled/dt-lb.conf
sudo nginx -t
sudo systemctl restart nginx
```

### 8.3 Validacion LB

```bash
ls -l /etc/nginx/sites-enabled/ | grep dt-lb.conf
curl http://51.48.226.94/
```

Resultado esperado confirmado: `LB OK`.

## 9. Configuracion de DB (PostgreSQL)

### 9.1 Instalacion

```bash
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

### 9.2 Creacion de roles y base de datos

Se usaron variables en shell:

```bash
READ_PASS='PassRead123!'
WRITE_PASS='PassWrite123!'
```

Bloque ejecutado para roles:

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='backend_read') THEN
    CREATE ROLE backend_read LOGIN PASSWORD '${READ_PASS}';
  ELSE
    ALTER ROLE backend_read WITH LOGIN PASSWORD '${READ_PASS}';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='backend_write') THEN
    CREATE ROLE backend_write LOGIN PASSWORD '${WRITE_PASS}';
  ELSE
    ALTER ROLE backend_write WITH LOGIN PASSWORD '${WRITE_PASS}';
  END IF;
END
\$\$;
SQL
```

Bloque para DB y permisos de conexion:

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
SELECT 'CREATE DATABASE "DB_UFV"'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='DB_UFV')\gexec

GRANT CONNECT ON DATABASE "DB_UFV" TO backend_read, backend_write;
SQL
```

### 9.3 Esquema y tablas

Se creo esquema `academico` dentro de `DB_UFV`, con tablas:

- `academico.asignaturas`
- `academico.alumnos`
- `academico.inscripciones`
- `academico.practicas`
- `academico.entregas`

Se insertaron datos semilla:

- Asignatura: `Administracion de Sistemas`
- Alumno demo: `alumno.demo@ufv.es`

### 9.4 Permisos

Aplicados:

- `backend_read`: SELECT
- `backend_write`: SELECT/INSERT/UPDATE/DELETE
- Default privileges en esquema `academico`

## 10. Backup de la base de datos

Comando usado:

```bash
sudo mkdir -p /var/backups/postgresql
sudo bash -c 'sudo -u postgres pg_dump "DB_UFV" > /var/backups/postgresql/DB_UFV_$(date +%F_%H%M%S).sql'
```

Validacion:

```bash
ls -lh /var/backups/postgresql/
```

Resultado confirmado: archivo de backup creado (`DB_UFV_*.sql`).

## 11. Estado final

- Infraestructura B desplegada y operativa.
- LB Nginx configurado y respondiendo `LB OK`.
- PostgreSQL instalado, base `DB_UFV` creada, esquema `academico` cargado y permisos aplicados.
- Backup generado correctamente.

## 12. Pendiente para cierre E2E de equipo

- Reemplazar IPs placeholder de upstreams en LB por IPs privadas reales de C/D/E.
- Validar rutas finales:
  - `/profesores/`
  - `/alumnos/`
  - `/practicas/`
- Ejecutar/integrar peering y rutas cross-account entre todos los alumnos.
