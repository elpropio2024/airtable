#!/usr/bin/env bash
# Reintenta crear la instancia ARM gratuita (VM.Standard.A1.Flex) hasta que haya capacidad.
# Se ejecuta en Oracle Cloud Shell (ya trae el CLI "oci" autenticado).
#
# Requisitos previos:
#   1. Una VCN con subred pública (Networking > Virtual cloud networks >
#      Start VCN Wizard > "Create VCN with Internet Connectivity").
#   2. La llave pública subida a Cloud Shell (menú del engranaje > Upload).
#
# Uso:
#   bash reintentar-arm.sh ssh-key-2026-11-02.key.pub
#   OCPUS=1 MEMORIA=6 bash reintentar-arm.sh ssh-key-2026-11-02.key.pub
set -uo pipefail

LLAVE="${1:-}"
OCPUS="${OCPUS:-2}"
MEMORIA="${MEMORIA:-12}"
ESPERA="${ESPERA:-60}"
NOMBRE="${NOMBRE:-n8n}"

if [[ -z "$LLAVE" || ! -f "$LLAVE" ]]; then
  echo "Indica la llave pública: bash reintentar-arm.sh archivo.pub" >&2
  exit 1
fi

C="${OCI_TENANCY:?No se encontró OCI_TENANCY; ejecuta esto en Oracle Cloud Shell}"

echo "==> Buscando dominio de disponibilidad"
AD=$(oci iam availability-domain list --compartment-id "$C" --query 'data[0].name' --raw-output)

echo "==> Buscando subred pública"
SUBNET=$(oci network subnet list --compartment-id "$C" \
  --query 'data[?"prohibit-public-ip-on-vnic"==`false`] | [0].id' --raw-output)
if [[ -z "$SUBNET" || "$SUBNET" == "null" ]]; then
  echo "No hay subred pública. Crea la VCN con el asistente (ver requisitos)." >&2
  exit 1
fi

echo "==> Buscando imagen Ubuntu 24.04 para ARM"
IMAGEN=$(oci compute image list --compartment-id "$C" \
  --operating-system "Canonical Ubuntu" --operating-system-version "24.04" \
  --shape VM.Standard.A1.Flex --sort-by TIMECREATED --sort-order DESC \
  --query 'data[?!contains("display-name", `Minimal`)] | [0].id' --raw-output)
if [[ -z "$IMAGEN" || "$IMAGEN" == "null" ]]; then
  echo "No se encontró la imagen Ubuntu 24.04 aarch64." >&2
  exit 1
fi

echo "AD:      $AD"
echo "Subred:  $SUBNET"
echo "Imagen:  $IMAGEN"
echo "Tamaño:  ${OCPUS} OCPU / ${MEMORIA} GB"
echo

intento=0
while true; do
  intento=$((intento + 1))
  echo "[$(date '+%H:%M:%S')] Intento $intento..."
  salida=$(oci compute instance launch \
    --compartment-id "$C" \
    --availability-domain "$AD" \
    --display-name "$NOMBRE" \
    --shape VM.Standard.A1.Flex \
    --shape-config "{\"ocpus\": $OCPUS, \"memoryInGBs\": $MEMORIA}" \
    --image-id "$IMAGEN" \
    --subnet-id "$SUBNET" \
    --assign-public-ip true \
    --ssh-authorized-keys-file "$LLAVE" \
    --wait-for-state RUNNING 2>&1)
  if echo "$salida" | grep -q '"lifecycle-state": "RUNNING"'; then
    ID=$(echo "$salida" | grep -m1 '"id": "ocid1.instance' | sed 's/.*"\(ocid1[^"]*\)".*/\1/')
    IP=$(oci compute instance list-vnics --instance-id "$ID" \
      --query 'data[0]."public-ip"' --raw-output 2>/dev/null)
    echo
    echo "Instancia creada. IP pública: ${IP:-revisar en la consola}"
    exit 0
  fi
  if echo "$salida" | grep -qi "out of host capacity\|out of capacity"; then
    echo "  Sin capacidad. Reintento en ${ESPERA}s."
  elif echo "$salida" | grep -qi "TooManyRequests"; then
    echo "  Demasiadas solicitudes. Espero el doble."
    sleep "$ESPERA"
  else
    echo "  Error distinto a capacidad; se detiene para revisarlo:"
    echo "$salida" | tail -20
    exit 1
  fi
  sleep "$ESPERA"
done
