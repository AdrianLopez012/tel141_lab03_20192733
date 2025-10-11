#!/bin/bash

# Orquestador Fase 2: Configuración de DHCP, Gateways y NAT en HeadNode

echo "======================================"
echo "  VM Orchestrator - FASE 2           "
echo "======================================"
echo "Configurando DHCP, Gateways y NAT"
echo ""

OVS_NAME="br-int"
INTERFACE_DATA="ens4"

# Verificar que los scripts necesarios existen
REQUIRED_SCRIPTS=("init_headnode_fase2.sh" "net_create.sh" "internet_connectivity.sh")
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "❌ Error: Script '$script' no encontrado"
        exit 1
    fi
    chmod +x "$script"
done

echo "[FASE 2-1] Inicializando HeadNode con OvS..."
echo ""
./init_headnode_fase2.sh $OVS_NAME $INTERFACE_DATA

echo ""
echo "======================================"
echo "[FASE 2-2] Configurando VLANs con DHCP"
echo "======================================"
echo ""

# Configuración de las 3 VLANs
# VLAN 100: 192.168.100.0/24
echo "--- VLAN 100 ---"
./net_create.sh ns-dhcp-vlan100 $OVS_NAME 100 "192.168.100.10,192.168.100.100" "192.168.100.1/24"
sleep 2

# VLAN 200: 192.168.200.0/24
echo ""
echo "--- VLAN 200 ---"
./net_create.sh ns-dhcp-vlan200 $OVS_NAME 200 "192.168.200.10,192.168.200.100" "192.168.200.1/24"
sleep 2

# VLAN 300: 192.168.30.0/24 (no 300 porque IPv4 max es 255)
echo ""
echo "--- VLAN 300 ---"
./net_create.sh ns-dhcp-vlan300 $OVS_NAME 300 "192.168.30.10,192.168.30.100" "192.168.30.1/24"
sleep 2

echo ""
echo "======================================"
echo "[FASE 2-3] Configurando Acceso a Internet"
echo "======================================"
echo ""

# Configurar NAT/PAT para cada VLAN
echo "--- Configurando NAT para VLAN 100 ---"
./internet_connectivity.sh 100
echo ""

echo "--- Configurando NAT para VLAN 200 ---"
./internet_connectivity.sh 200
echo ""

echo "--- Configurando NAT para VLAN 300 ---"
./internet_connectivity.sh 300
echo ""

echo "======================================"
echo "     FASE 2 COMPLETADA               "
echo "======================================"
echo ""
echo "Resumen de configuración:"
echo ""
echo "VLANs configuradas:"
echo "  - VLAN 100: 192.168.100.0/24 (GW: .1, DHCP: .10-.100)"
echo "  - VLAN 200: 192.168.200.0/24 (GW: .1, DHCP: .10-.100)"
echo "  - VLAN 300: 192.168.30.0/24  (GW: .1, DHCP: .10-.100)"
echo ""
echo "Servicios activos:"
echo "  - Namespaces DHCP: $(sudo ip netns list | grep ns-dhcp | wc -l)"
echo "  - Interfaces VLAN: $(ip link show | grep -c 'vlan[0-9]' || echo 0)"
echo ""
echo "Verificación de conectividad:"
echo "  - IPv4 Forwarding: $(sysctl net.ipv4.ip_forward | awk '{print $3}')"
echo "  - Reglas NAT activas: $(sudo iptables -t nat -L POSTROUTING -n | grep MASQUERADE | wc -l)"
echo ""
echo "Para verificar DHCP en un namespace:"
echo "  sudo ip netns exec ns-dhcp-vlan100 ps aux | grep dnsmasq"
echo ""
echo "Para verificar OvS:"
echo "  sudo ovs-vsctl show"
echo ""
