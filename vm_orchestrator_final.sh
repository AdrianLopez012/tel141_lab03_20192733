#!/bin/bash

# Orquestador Final: Integra Fase 1 y Fase 2

echo "========================================="
echo "  VM ORCHESTRATOR - DESPLIEGUE COMPLETO "
echo "========================================="
echo ""
echo "Este script desplegará la infraestructura completa:"
echo "  - Fase 1: OFS, Workers y 9 VMs"
echo "  - Fase 2: HeadNode con DHCP, Gateways y NAT"
echo ""
read -p "¿Continuar con el despliegue? (s/N): " confirm

if [[ ! "$confirm" =~ ^[sS]$ ]]; then
    echo "Despliegue cancelado."
    exit 0
fi

# Verificar que los scripts existen
if [ ! -f "vm_orchestrator_fase1.sh" ]; then
    echo "❌ Error: vm_orchestrator_fase1.sh no encontrado"
    exit 1
fi

if [ ! -f "vm_orchestrator_fase2.sh" ]; then
    echo "❌ Error: vm_orchestrator_fase2.sh no encontrado"
    exit 1
fi

# Hacer los scripts ejecutables
chmod +x vm_orchestrator_fase1.sh
chmod +x vm_orchestrator_fase2.sh

echo ""
echo "========================================="
echo "          INICIANDO FASE 1              "
echo "========================================="
echo "Configurando OFS, Workers y creando VMs"
echo ""

./vm_orchestrator_fase1.sh

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Error en Fase 1. Abortando despliegue."
    exit 1
fi

echo ""
echo "✓ Fase 1 completada exitosamente"
echo ""
echo "Esperando 5 segundos antes de iniciar Fase 2..."
sleep 5

echo ""
echo "========================================="
echo "          INICIANDO FASE 2              "
echo "========================================="
echo "Configurando HeadNode: DHCP, Gateways, NAT"
echo ""

./vm_orchestrator_fase2.sh

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Error en Fase 2. La infraestructura está parcialmente desplegada."
    echo "   Las VMs están creadas pero puede que no tengan DHCP/Internet"
    exit 1
fi

echo ""
echo "========================================="
echo "    DESPLIEGUE COMPLETO FINALIZADO      "
echo "========================================="
echo ""
echo "Resumen de la infraestructura:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OFS (10.0.10.5)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Bridge: br-ofs"
echo "  Interfaces: ens4, ens5, ens6"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HeadNode (local)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Bridge: br-int"
echo "  VLANs configuradas:"
echo "    - VLAN 100: 192.168.100.0/24 (GW: .1)"
echo "    - VLAN 200: 192.168.200.0/24 (GW: .1)"
echo "    - VLAN 300: 192.168.30.0/24  (GW: .1)"
echo "  Servicios:"
echo "    - DHCP activo en 3 namespaces"
echo "    - NAT/PAT configurado hacia ens3"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Workers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Worker 1 (10.0.10.2): vm1, vm2, vm3"
echo "  Worker 2 (10.0.10.3): vm4, vm5, vm6"
echo "  Worker 3 (10.0.10.4): vm7, vm8, vm9"
echo ""
echo "  Distribución por VLAN:"
echo "    - VLAN 100: vm1, vm4, vm7"
echo "    - VLAN 200: vm2, vm5, vm8"
echo "    - VLAN 300: vm3, vm6, vm9"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Acceso VNC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Worker 1: vncviewer 10.0.10.2:5901-5903"
echo "  Worker 2: vncviewer 10.0.10.3:5901-5903"
echo "  Worker 3: vncviewer 10.0.10.4:5901-5903"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Comandos útiles de verificación:"
echo ""
echo "  # Ver estado OvS en HeadNode"
echo "  sudo ovs-vsctl show"
echo ""
echo "  # Ver procesos DHCP"
echo "  sudo ip netns list"
echo "  sudo ip netns exec ns-dhcp-vlan100 ps aux | grep dnsmasq"
echo ""
echo "  # Ver reglas NAT"
echo "  sudo iptables -t nat -L POSTROUTING -n -v"
echo ""
echo "  # Ver VMs corriendo"
echo "  ps aux | grep qemu-system"
echo ""
echo "  # Verificar conectividad desde una VM"
echo "  # (Conectar vía VNC y hacer ping a 8.8.8.8)"
echo ""
echo "Para limpiar todo en caso de emergencia:"
echo "  ./cleanup_emergency.sh"
echo ""
