#!/bin/bash

# Script para inicializar el HeadNode según especificaciones Fase 2

if [ $# -lt 2 ]; then
    echo "Uso: $0 <nombreOvS> <interfaz1> [interfaz2] [interfaz3] ..."
    echo ""
    echo "Ejemplo: $0 br-int ens4"
    echo "         $0 br-int ens4 ens5"
    echo ""
    echo "⚠️  IMPORTANTE: NO incluir ens3 (interfaz de management/internet)"
    exit 1
fi

OVS_NAME=$1
shift
INTERFACES=("$@")

echo "======================================"
echo "   Inicializando HeadNode (Fase 2)   "
echo "======================================"
echo "OvS: $OVS_NAME"
echo "Interfaces a conectar: ${INTERFACES[@]}"
echo ""

# Verificar que ens3 NO esté en la lista
for iface in "${INTERFACES[@]}"; do
    if [ "$iface" == "ens3" ]; then
        echo "❌ ERROR CRÍTICO: Intentando conectar ens3 al OvS"
        echo "   ens3 es la interfaz de management/internet y NO debe tocarse"
        echo "   Esto cortaría toda la conectividad del nodo"
        exit 1
    fi
done

# 1. Crear OvS si no existe
echo "[1/3] Creando OvS '$OVS_NAME' (si no existe)..."
if sudo ovs-vsctl br-exists $OVS_NAME 2>/dev/null; then
    echo "  ✓ OvS '$OVS_NAME' ya existe"
else
    sudo ovs-vsctl add-br $OVS_NAME
    echo "  ✓ OvS '$OVS_NAME' creado"
fi

# Activar el bridge
sudo ip link set dev $OVS_NAME up
echo "  ✓ OvS activado"

# 2. Conectar interfaces al OvS
echo ""
echo "[2/3] Conectando interfaces al OvS..."
for iface in "${INTERFACES[@]}"; do
    if ! ip link show $iface &>/dev/null; then
        echo "  ⚠️  Interfaz $iface no encontrada, saltando..."
        continue
    fi

    echo "  - Conectando $iface a $OVS_NAME"
    sudo ip addr flush dev $iface
    sudo ovs-vsctl --may-exist add-port $OVS_NAME $iface
    sudo ip link set dev $iface up
    echo "    ✓ $iface conectado"
done

# 3. Configurar IPv4 Forwarding
echo ""
echo "[3/3] Configurando IPv4 Forwarding e iptables..."
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
echo "  ✓ IPv4 Forwarding habilitado"

# Cambiar política FORWARD de ACCEPT a DROP
CURRENT_POLICY=$(sudo iptables -L FORWARD -n | head -1 | grep -o '(policy [A-Z]*' | awk '{print $2}' | tr -d ')')
if [ "$CURRENT_POLICY" != "DROP" ]; then
    sudo iptables -P FORWARD DROP
    echo "  ✓ iptables FORWARD chain: ACCEPT -> DROP"
else
    echo "  ✓ iptables FORWARD chain ya está en DROP"
fi

echo ""
echo "======================================"
echo "    HeadNode Inicializado (Fase 2)   "
echo "======================================"
echo ""
echo "Configuración:"
echo "  - OvS: $OVS_NAME"
echo "  - Interfaces conectadas: ${INTERFACES[@]}"
echo "  - IPv4 Forwarding: HABILITADO"
echo "  - iptables FORWARD: DROP (por defecto)"
echo ""
echo "Estado del OvS:"
sudo ovs-vsctl show
echo ""
echo "Próximos pasos:"
echo "  1. Crear namespaces DHCP con: ./net_create.sh"
echo "  2. Configurar NAT por VLAN con: ./internet_connectivity.sh"
echo ""
