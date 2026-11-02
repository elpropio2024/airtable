# n8n en Oracle Cloud (Always Free)

Resultado: n8n disponible 24/7 en `https://tuagente.duckdns.org`, con HTTPS, sin pagar.

## 1. Crear la cuenta

1. Entra a https://www.oracle.com/cloud/free/ → **Start for free**.
2. **Home Region**: es la decisión más importante, no se puede cambiar y los recursos gratuitos ARM solo existen ahí.
   Las cercanas a Colombia son *Colombia Central (Bogotá)*, *Brazil East (São Paulo)* y *US East (Ashburn)*.
   La disponibilidad de servidores ARM gratis varía por región y por época; si una no tiene capacidad, no hay forma de mover la cuenta.
3. Te piden tarjeta. Hacen una retención de verificación que se devuelve; el plan gratuito no cobra.

### Recomendado: pasar a "Pay As You Go"

En *Billing → Upgrade and Manage Payment* puedes pasar la cuenta a Pay As You Go.
Lo que está dentro de Always Free sigue siendo gratis, y ganas dos cosas:

- Oracle deja de apagar instancias gratuitas por "poco uso" (lo hace con cuentas Free cuando el CPU pasa 7 días casi sin uso).
- Suele haber más disponibilidad para crear el servidor ARM.

El riesgo: si creas algo que **no** es Always Free, te lo cobran. Para evitar sustos crea un presupuesto con alerta:
*Billing → Budgets → Create Budget* con 1 USD y alerta al 1 %.

## 2. Crear el servidor

*Menú → Compute → Instances → Create instance*

| Campo | Valor |
|---|---|
| Name | `n8n` |
| Image | **Canonical Ubuntu 24.04** (no la versión *Minimal*) |
| Shape | *Change shape* → **Ampere** → `VM.Standard.A1.Flex` → **2 OCPU, 12 GB** de memoria (el gratis llega a 4 OCPU / 24 GB) |
| Networking | *Create new virtual cloud network* y *Create new public subnet*. Marca **Assign a public IPv4 address** |
| SSH keys | **Generate a key pair for me** → descarga la **llave privada** y guárdala bien; sin ella no puedes entrar |
| Boot volume | Deja el tamaño por defecto (el gratis permite hasta 200 GB en total) |

Pulsa **Create**. Si sale *Out of capacity for shape VM.Standard.A1.Flex*: prueba otro *Availability Domain*, baja a 1 OCPU / 6 GB, o reintenta en otro horario.

Cuando quede en verde (*Running*), copia la **Public IP address**.

## 3. Abrir los puertos 80 y 443 en Oracle

*Instance → Networking → Subnet → Security → Security List (Default) → Add Ingress Rules*. Agrega dos reglas:

| Source CIDR | IP Protocol | Destination Port |
|---|---|---|
| `0.0.0.0/0` | TCP | `80` |
| `0.0.0.0/0` | TCP | `443` |

(El puerto 22 de SSH ya viene abierto.)

## 4. Subdominio gratis en DuckDNS

1. Entra a https://www.duckdns.org con tu cuenta de Google.
2. Crea un subdominio, por ejemplo `tuagente`.
3. En el campo *current ip* pon la IP pública del servidor y pulsa **update ip**.

La IP de la instancia no cambia mientras no la borres, así que esto se hace una sola vez.

## 5. Entrar por SSH

En tu computador (Windows con PowerShell, Mac o Linux), desde la carpeta donde guardaste la llave:

```bash
ssh -i ssh-key-XXXX.key ubuntu@IP_PUBLICA
```

- Mac/Linux: si dice *permissions are too open*, ejecuta antes `chmod 600 ssh-key-XXXX.key`.
- Windows: si dice lo mismo, clic derecho en la llave → Propiedades → Seguridad → deja solo a tu usuario con permiso de lectura.

Las imágenes de Oracle ya vienen con acceso SSH solo por llave (sin contraseña).

## 6. Instalar n8n

En el servidor:

```bash
git clone -b claude/gracious-goldberg-ahr0oo https://github.com/elpropio2024/airtable.git
cd airtable/n8n-agente-ia/oracle
sudo bash preparar-servidor.sh
nano .env            # cambia DOMINIO por tu subdominio de DuckDNS
docker compose up -d
```

El script actualiza Ubuntu, abre 80/443 en el firewall interno de la imagen de Oracle e instala Docker.
Caddy saca el certificado HTTPS solo en el primer arranque (tarda uno o dos minutos).

Abre `https://tuagente.duckdns.org`, crea la cuenta de administrador de n8n (**contraseña fuerte**: este n8n está en internet) e importa `../workflows/agente-basico.json` como en la guía principal.

## 7. Dejar que Claude trabaje en el servidor (opcional)

```bash
curl -fsSL https://claude.ai/install.sh | bash
mkdir -p ~/agente && cd ~/agente
sudo apt install -y tmux && tmux new -s claude
claude remote-control
```

Inicia sesión con tu cuenta de Claude, sal de tmux con `Ctrl+B` y luego `D`, y avisa en la conversación.

## Mantenimiento

| Tarea | Comando (en `airtable/n8n-agente-ia/oracle`) |
|---|---|
| Actualizar n8n | `docker compose pull && docker compose up -d` |
| Ver errores | `docker compose logs -f n8n` o `docker compose logs -f caddy` |
| Respaldo de flujos | Desde n8n: *Workflows → seleccionar → Download*. Hazlo antes de cada actualización |

## Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| El navegador no carga la página | Falta la regla 80/443 del paso 3, o DuckDNS tiene otra IP |
| Caddy muestra error de certificado en los logs | Igual que arriba: Let's Encrypt necesita llegar al puerto 80 desde internet |
| `Out of capacity` al crear la instancia | Falta de servidores ARM libres en tu región; ver paso 2 |
| `permission denied` al usar docker | Cierra la sesión SSH y vuelve a entrar después del script |
