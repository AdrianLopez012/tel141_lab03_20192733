#!/bin/bash

BRIDGE_NAME=${1:-br-int} 
INTERFACE_DATA=${2:-ens4} 

echo "Inicializando Worker en $(hostname) con bridge $BRIDGE_NAME"

if ! sudo ovs-vsctl br-exists $BRIDGE_NAME 2>/dev/null; then
    sudo ovs-vsctl add-br $BRIDGE_NAME
fi

sudo ip addr flush dev $INTERFACE_DATA
sudo ovs-vsctl add-port $BRIDGE_NAME $INTERFACE_DATA
sudo ip link set dev $INTERFACE_DATA up
sudo ip link set dev $BRIDGE_NAME up
echo "Worker inicializado con bridge $BRIDGE_NAME"
sudo ovs-vsctl show