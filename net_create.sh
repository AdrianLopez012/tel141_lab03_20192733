#!/bin/bash

# Script para crear un Network Namespace con DHCP y conectarlo a OvS con VLAN

if [ $# -lt 5 ]; then
    echo "Uso: $0 <nombreNS> <nombreOvS> <vlanID> <rangoDHCP> <defaultGateway>"
    echo ""
    echo "Ejemplo: $0 ns-dhcp-vlan100 br-int 100 192.168.100.10,192.168.100.100 192.168.100.1/24"
    exit 1
fi

NS_NAME=$1
OVS_NAME=$2
VLAN_ID=$3
DHCP_RANGE=$4
GATEWAY_IP=$5

# Extraer red base del gateway (ej: 192.168.100.1/24 -> 192.168.100)
NETWORK_BASE=$(echo $GATEWAY_IP | cut -d'.' -f1-3)
NETMASK=$(echo $GATEWAY_IP | cut -d'/' -f2)

# Nombres de interfaces veth
VETH_BR="veth-br${VLAN_ID}"
VETH_NS="veth-ns${VLAN_ID}"

echo "======================================"
echo "  Creando Network Namespace con DHCP  "
echo "======================================"
echo "Namespace: $NS_NAME"
echo "OvS: $OVS_NAME"
echo "VLAN ID: $VLAN_ID"
echo "Rango DHCP: $DHCP_RANGE"
echo "Gateway: $GATEWAY_IP"
echo ""

# Verificar que el OvS existe
if ! sudo ovs-vsctl br-exists $OVS_NAME 2>/dev/null; then
    echo "Error: El bridge OvS '$OVS_NAME' no existe."
    exit 1
fi

# 1. Crear Network Namespace
echo "[1/6] Creando network namespace: $NS_NAME"
sudo ip netns add $NS_NAME 2>/dev/null || echo "  - Namespace ya existe, continuando..."

# 2. Crear par de interfaces veth
echo "[2/6] Creando par veth: $VETH_BR <--> $VETH_NS"
sudo ip link delete $VETH_BR 2>/dev/null || true
sudo ip link add $VETH_BR type veth peer name $VETH_NS

# 3. Mover un extremo al namespace
echo "[3/6] Moviendo $VETH_NS al namespace $NS_NAME"
sudo ip link set $VETH_NS netns $NS_NAME

# 4. Conectar el otro extremo al OvS con VLAN tag
echo "[4/6] Conectando $VETH_BR a $OVS_NAME con VLAN tag $VLAN_ID"
sudo ovs-vsctl --may-exist add-port $OVS_NAME $VETH_BR tag=$VLAN_ID

# 5. Activar interfaces y asignar IP al namespace
echo "[5/6] Configurando interfaces..."
sudo ip link set dev $VETH_BR up
sudo ip netns exec $NS_NAME ip link set dev lo up
sudo ip netns exec $NS_NAME ip link set dev $VETH_NS up
sudo ip netns exec $NS_NAME ip addr add $GATEWAY_IP dev $VETH_NS

# 6. Crear interfaz interna en OvS para el gateway
echo "[6/6] Creando interfaz interna vlan${VLAN_ID} en $OVS_NAME"
VLAN_IF="vlan${VLAN_ID}"

# Verificar si la interfaz VLAN ya existe
if ip link show $VLAN_IF &>/dev/null; then
    echo "  - Interfaz $VLAN_IF ya existe, eliminando..."
    sudo ip link delete $VLAN_IF 2>/dev/null
fi

# Crear interfaz VLAN interna al OvS
sudo ip link add link $OVS_NAME name $VLAN_IF type vlan id $VLAN_ID
sudo ip addr add $GATEWAY_IP dev $VLAN_IF
sudo ip link set dev $VLAN_IF up

echo ""
echo "[DHCP] Iniciando servidor dnsmasq en namespace..."

# Matar cualquier dnsmasq previo en el namespace
sudo ip netns exec $NS_NAME pkill dnsmasq 2>/dev/null || true

# Parsear rango DHCP (formato: 192.168.100.10,192.168.100.100)
DHCP_START=$(echo $DHCP_RANGE | cut -d',' -f1)
DHCP_END=$(echo $DHCP_RANGE | cut -d',' -f2)

# Iniciar dnsmasq en el namespace
sudo ip netns exec $NS_NAME dnsmasq \
    --interface=$VETH_NS \
    --bind-interfaces \
    --dhcp-range=$DHCP_START,$DHCP_END,255.255.255.0,12h \
    --dhcp-option=3,$(echo $GATEWAY_IP | cut -d'/' -f1) \
    --dhcp-option=6,8.8.8.8,8.8.4.4 \
    --no-daemon \
    --log-queries \
    --log-dhcp &

DNSMASQ_PID=$!

echo "✓ dnsmasq iniciado con PID: $DNSMASQ_PID"
echo ""
echo "======================================"
echo "       Configuración Completada       "
echo "======================================"
echo "Namespace: $NS_NAME"
echo "VLAN ID: $VLAN_ID"
echo "Gateway: $(echo $GATEWAY_IP | cut -d'/' -f1)"
echo "Rango DHCP: $DHCP_START - $DHCP_END"
echo "Interfaz OvS: $VETH_BR (tag=$VLAN_ID)"
echo "Interfaz Gateway: $VLAN_IF"
echo ""
echo "Verificación:"
sudo ovs-vsctl show | grep -A3 $VETH_BR
echo ""
