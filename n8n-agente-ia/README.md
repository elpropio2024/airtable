# Agente de IA con n8n, costo cero

Primer agente: un chat en español con memoria de conversación y una herramienta (calculadora).
Todo corre gratis:

| Pieza | Opción gratuita | Límite a tener en cuenta |
|---|---|---|
| n8n | Edición Community autoalojada en tu PC con Docker | Tu PC debe estar encendido para que funcione |
| Modelo de IA | API de Google Gemini, plan gratuito (Google AI Studio) | Cuota diaria y por minuto; Google puede usar los datos del plan gratis para mejorar sus productos, así que no metas datos sensibles |
| Alternativa 100 % local | Ollama en tu PC | Necesita buena RAM (8 GB mínimo, 16 GB recomendable) y responde más lento |

---

## Paso 1. Instalar Docker

- Windows / Mac: instala **Docker Desktop** desde https://www.docker.com/products/docker-desktop/ y ábrelo.
- Linux: `curl -fsSL https://get.docker.com | sh`

Comprueba en una terminal:

```bash
docker --version
```

## Paso 2. Levantar n8n

Desde esta carpeta (`n8n-agente-ia`):

```bash
docker compose up -d
```

Abre http://localhost:5678, crea la cuenta de administrador (es local, no se paga nada).
n8n te ofrecerá activar funciones gratis con una licencia por correo; acéptalo, no cuesta.

Para apagarlo: `docker compose down`. Los flujos se conservan en el volumen `n8n_data`.

## Paso 3. Conseguir la API key gratuita de Gemini

1. Entra a https://aistudio.google.com/apikey con tu cuenta de Google.
2. Pulsa **Create API key** y cópiala.
3. No hace falta tarjeta de crédito para el plan gratuito.

## Paso 4. Importar el agente

1. En n8n: **Create workflow** → menú `⋯` arriba a la derecha → **Import from File**.
2. Elige `workflows/agente-basico.json`.
3. Verás 5 nodos:
   - **Chat**: la ventana donde escribes.
   - **Agente IA**: decide qué responder y cuándo usar herramientas. Aquí está el mensaje de sistema (las instrucciones del agente).
   - **Google Gemini**: el modelo.
   - **Memoria**: recuerda los últimos 10 mensajes.
   - **Calculadora**: herramienta que el agente puede usar.

## Paso 5. Conectar la credencial

1. Doble clic en el nodo **Google Gemini**.
2. En *Credential* → **Create new credential** → pega la API key → **Save**.
3. En *Model*, abre la lista y elige un modelo **Flash** (por ejemplo `gemini-2.5-flash`). Si el que viene en el archivo ya no aparece, toma el Flash más reciente: es el que tiene cuota gratuita más amplia.

## Paso 6. Probar

1. Pulsa **Open chat** (abajo, en el lienzo).
2. Prueba:
   - `Hola, me llamo Luis` y luego `¿Cómo me llamo?` → comprueba la memoria.
   - `¿Cuánto es 1234 * 5,7 + 89?` → en el panel de ejecución verás que llamó a la Calculadora.
3. Guarda el flujo (**Ctrl + S**).

Si quieres un enlace de chat para otras personas: en el nodo **Chat** activa *Make Chat Publicly Available* y **activa** el flujo (interruptor *Active*). Ojo: con n8n en tu PC, ese enlace solo funciona en tu red local.

---

## Opción sin internet: Ollama en lugar de Gemini

1. Instala Ollama: https://ollama.com/download
2. Descarga un modelo que soporte herramientas:
   ```bash
   ollama pull qwen2.5:7b
   ```
3. En n8n borra el nodo **Google Gemini** y añade **Ollama Chat Model** conectado al Agente.
4. Credencial de Ollama → *Base URL*: `http://host.docker.internal:11434`
   (en Linux, si no conecta, usa la IP de tu máquina y arranca Ollama con `OLLAMA_HOST=0.0.0.0`).

## Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| No abre localhost:5678 | Docker no está corriendo, o el puerto 5678 está ocupado. Revisa `docker compose logs n8n` |
| Error 429 en Gemini | Pasaste la cuota gratuita por minuto o por día. Espera o cambia a un modelo Flash-Lite |
| El agente no usa la calculadora | Modelos pequeños a veces la ignoran. Refuerza la instrucción en el mensaje de sistema |
| Ollama "connection refused" | La URL `localhost` dentro de Docker apunta al contenedor, no a tu PC. Usa `host.docker.internal` |

## Siguientes pasos posibles

- Conectar el agente a **Telegram** (bot gratis) en vez del chat de n8n.
- Darle una herramienta que lea/escriba en **Airtable** o **Google Sheets**.
- Pasar n8n a un servidor gratuito (por ejemplo Oracle Cloud Free Tier) para que funcione 24/7 sin tu PC.
