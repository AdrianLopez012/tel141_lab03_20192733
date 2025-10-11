#!/bin/bash

BRIDGE_NAME=${1:-br-ofs} 
shift 

if [ $# -eq 0 ]; then
    set -- ens4 ens5 ens6
fi

echo "Configurando OFS con bridge $BRIDGE_NAME"
sudo ovs-vsctl add-br $BRIDGE_NAME 2>/dev/null || true
for IFACE in "$@"; do
    if ip link show $IFACE &>/dev/null; then
        echo "Configurando interfaz $IFACE"
        sudo ip addr flush dev $IFACE
        sudo ovs-vsctl add-port $BRIDGE_NAME $IFACE 2>/dev/null || true
        sudo ip link set dev $IFACE up
    else
        echo "Advertencia: Interfaz $IFACE no encontrada"
    fi
done

sudo ip link set dev $BRIDGE_NAME up
echo "OFS configurado como switch trunk"
sudo ovs-vsctl show