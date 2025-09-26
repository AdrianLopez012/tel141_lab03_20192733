#!/bin/bash
# Crea una VM en un Worker específico (Fase 1)
# Uso: ./vm_create.sh <nombreVM> <vlanID> <puertoVNC> [nombreOvS]
# Mantengo el orden de parámetros que ya usa tu orquestador:
#   VM_NAME, VLAN_ID, VNC_PORT, BRIDGE_NAME

set -e

VM_NAME=$1
VLAN_ID=$2
VNC_PORT=$3
BRIDGE_NAME=${4:-br-int}  # por defecto br-int

if [ $# -lt 3 ]; then
    echo "Uso: $0 <nombreVM> <vlanID> <puertoVNC> [nombreOvS]"
    exit 1
fi

echo "Creando VM $VM_NAME en $(hostname) usando bridge $BRIDGE_NAME (VLAN $VLAN_ID, VNC $VNC_PORT)"

# Asegurar que el bridge existe y está UP (idempotente)
sudo ovs-vsctl --may-exist add-br "$BRIDGE_NAME"
sudo ip link set dev "$BRIDGE_NAME" up

# Descargar imagen si no existe
if [ ! -f cirros-0.5.1-x86_64-disk.img ]; then
    wget -c https://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
fi

# Preparar nombre TAP
TAP_NAME="tap-${VM_NAME}"

# Limpiar restos previos (idempotente)
sudo ovs-vsctl --if-exists del-port "$BRIDGE_NAME" "$TAP_NAME"
sudo ip tuntap del dev "$TAP_NAME" mode tap 2>/dev/null || true

# Crear TAP y subirla
sudo ip tuntap add mode tap name "$TAP_NAME"
sudo ip link set dev "$TAP_NAME" up

# Conectar TAP al OvS con la VLAN
sudo ovs-vsctl --may-exist add-port "$BRIDGE_NAME" "$TAP_NAME" tag="$VLAN_ID"

# Generar MAC única (OUI QEMU 52:54:00 + hash VM_NAME+hostname)
OUI="52:54:00"
HEX=$(echo -n "${VM_NAME}$(hostname)" | md5sum | awk '{print $1}')
MAC_ADDR="${OUI}:$(echo ${HEX:0:2}:${HEX:2:2}:${HEX:4:2})"
echo "Usando MAC $MAC_ADDR para $VM_NAME"

# Calcular display de VNC a partir del puerto
VNC_DISPLAY=$((VNC_PORT - 5900))
if [ $VNC_DISPLAY -lt 0 ]; then VNC_DISPLAY=1; fi

# Lanzar VM
sudo qemu-system-x86_64 \
    -name "$VM_NAME" \
    -enable-kvm \
    -m 256 \
    -vnc 0.0.0.0:${VNC_DISPLAY} \
    -netdev tap,id="$TAP_NAME",ifname="$TAP_NAME",script=no,downscript=no \
    -device e1000,netdev="$TAP_NAME",mac="$MAC_ADDR" \
    -drive file=cirros-0.5.1-x86_64-disk.img,format=qcow2 \
    -snapshot \
    -daemonize

echo "VM $VM_NAME creada - VNC $VNC_PORT (:${VNC_DISPLAY}), VLAN $VLAN_ID, MAC $MAC_ADDR"
