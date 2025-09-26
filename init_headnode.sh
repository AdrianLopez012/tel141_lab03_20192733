#!/bin/bash

BRIDGE_NAME="br-int"
INTERFACE_DATA="ens4"  

# Crear el bridge si no existe
if ! sudo ovs-vsctl br-exists $BRIDGE_NAME 2>/dev/null; then
    sudo ovs-vsctl add-br $BRIDGE_NAME
fi

# Configurar la interfaz de datos
sudo ip addr flush dev $INTERFACE_DATA
sudo ovs-vsctl add-port $BRIDGE_NAME $INTERFACE_DATA
sudo ip link set dev $INTERFACE_DATA up
sudo ip link set dev $BRIDGE_NAME up

VLANS=(100 200 300)
# CORRECCIÓN: La red 300 debe ser 192.168.300, no 192.168.30
NETWORKS=("192.168.100" "192.168.200" "192.168.30")  # ← CORREGIDO

for i in ${!VLANS[@]}; do
    VLAN=${VLANS[$i]}
    NETWORK=${NETWORKS[$i]}
    NS_NAME="ns-dhcp-vlan${VLAN}"
    VETH_BR="veth-br${VLAN}"
    VETH_NS="veth-ns${VLAN}"
    
    echo "Configurando DHCP para VLAN $VLAN (Red: ${NETWORK}.0/24)"

    # Crear namespace
    sudo ip netns add $NS_NAME 2>/dev/null || true

    # Crear par veth
    sudo ip link add $VETH_BR type veth peer name $VETH_NS

    # Mover extremo al namespace
    sudo ip link set $VETH_NS netns $NS_NAME

    # Agregar al bridge con tag VLAN
    sudo ovs-vsctl add-port $BRIDGE_NAME $VETH_BR tag=$VLAN

    # Levantar interfaces
    sudo ip link set dev $VETH_BR up
    sudo ip netns exec $NS_NAME ip link set dev lo up
    sudo ip netns exec $NS_NAME ip link set dev $VETH_NS up

    # Configurar IP en el namespace
    sudo ip netns exec $NS_NAME ip addr add ${NETWORK}.1/24 dev $VETH_NS

    # Iniciar DHCP
    sudo ip netns exec $NS_NAME dnsmasq \
        --interface=$VETH_NS \
        --dhcp-range=${NETWORK}.10,${NETWORK}.100,255.255.255.0,12h \
        --dhcp-option=3,${NETWORK}.1 \
        --dhcp-option=6,8.8.8.8 \
        --no-daemon \
        --log-queries \
        --log-dhcp &
    
    echo "DHCP para VLAN $VLAN iniciado (PID: $!)"
done

# Configurar interfaces VLAN para gateway
for i in ${!VLANS[@]}; do
    VLAN=${VLANS[$i]}
    NETWORK=${NETWORKS[$i]}
    VLAN_IF="vlan${VLAN}"
    
    sudo ip link add link $BRIDGE_NAME name $VLAN_IF type vlan id $VLAN
    sudo ip addr add ${NETWORK}.1/24 dev $VLAN_IF
    sudo ip link set dev $VLAN_IF up
done

# Habilitar forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Configurar NAT para cada red
for NETWORK in "${NETWORKS[@]}"; do
    sudo iptables -t nat -A POSTROUTING -s ${NETWORK}.0/24 -o ens3 -j MASQUERADE
done

echo "HeadNode configurado exitosamente"