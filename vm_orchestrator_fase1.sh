#!/bin/bash

WORKER1_IP="10.0.10.2"
WORKER2_IP="10.0.10.3"  
WORKER3_IP="10.0.10.4"
OFS_IP="10.0.10.5"
SSH_USER="ubuntu"
SSH_PASS="adrianlopez"

run_remote() {
    local host_ip=$1
    shift
    echo "[${host_ip}] Ejecutando: $@"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$host_ip "echo '$SSH_PASS' | sudo -S bash -c '$@'"
}

copy_to_remote() {
    local host_ip=$1
    local file=$2
    echo "Copiando $file a $host_ip..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no $file $SSH_USER@$host_ip:/tmp/
}

echo ""
echo "========================================="
echo "Configurar OFS"
echo "========================================="
copy_to_remote "$OFS_IP" "init_ofs.sh"
# Usar parámetros: nombre bridge y puertos (excluyendo ens3)
run_remote "$OFS_IP" "chmod +x /tmp/init_ofs.sh && /tmp/init_ofs.sh br-ofs ens4 ens5 ens6"

echo ""
echo "========================================="
echo "Configurar HeadNode"
echo "========================================="
chmod +x init_headnode.sh
./init_headnode.sh

echo ""
echo "========================================="
echo "Configurar Workers"
echo "========================================="
for ip in $WORKER1_IP $WORKER2_IP $WORKER3_IP; do
    echo "Configurando Worker $ip..."
    copy_to_remote "$ip" "init_worker.sh"
    copy_to_remote "$ip" "vm_create.sh"
    # Usar parámetros correctos: nombre bridge e interfaz
    run_remote "$ip" "chmod +x /tmp/*.sh && /tmp/init_worker.sh br-int ens4"
done

echo ""
echo "========================================="
echo "Crear VMs"
echo "========================================="

# Worker1 - VMs en VLANs 100, 200, 300 (agregando parámetro bridge)
run_remote "$WORKER1_IP" "/tmp/vm_create.sh vm1 100 5901 br-int"
run_remote "$WORKER1_IP" "/tmp/vm_create.sh vm2 200 5902 br-int"
run_remote "$WORKER1_IP" "/tmp/vm_create.sh vm3 300 5903 br-int"

# Worker2 - VMs en VLANs 100, 200, 300
run_remote "$WORKER2_IP" "/tmp/vm_create.sh vm4 100 5901 br-int"
run_remote "$WORKER2_IP" "/tmp/vm_create.sh vm5 200 5902 br-int"
run_remote "$WORKER2_IP" "/tmp/vm_create.sh vm6 300 5903 br-int"

# Worker3 - VMs en VLANs 100, 200, 300
run_remote "$WORKER3_IP" "/tmp/vm_create.sh vm7 100 5901 br-int"
run_remote "$WORKER3_IP" "/tmp/vm_create.sh vm8 200 5902 br-int"
run_remote "$WORKER3_IP" "/tmp/vm_create.sh vm9 300 5903 br-int"

echo ""
echo "========================================="
echo "Orquestación completada"
echo "========================================="