#!/bin/bash -e

ACTION="$${1:-}"

create_lvm() {
    # create lvm
    echo "[INFO] running: lvcreate -V ${lvm_size} --thin -n ${lvm_name} ${lvm_pool}"
    if ! lvcreate -V ${lvm_size} --thin -n ${lvm_name} ${lvm_pool}; then
	echo "lvm creation failed"
	exit 1
    fi
}

destroy_lvm() {
    echo "[INFO] running: lvremove -fy /dev/mapper/$${VG_NAME}-${lvm_name}"
    if ! lvremove -fy /dev/mapper/$${VG_NAME}-${lvm_name}; then
	echo "lvm volume '/dev/mapper/$${VG_NAME}-${lvm_name}' not removed"
	exit 1
    fi
}

create_iscsi_target() {
    # create iscsi target definition
    echo "[INFO] creating: /etc/tgt/conf.d/$${STORAGE_NAME}.conf"
    cat > /etc/tgt/conf.d/$${STORAGE_NAME}.conf <<EOF
<target ${iqn}:${lvm_name}>
	backing-store /dev/mapper/$${VG_NAME}-${lvm_name}
</target>
EOF

    # check if it was created successfully
    if [[ ! -f /etc/tgt/conf.d/$${STORAGE_NAME}.conf ]]; then
	echo "iscsi target file '$${STORAGE_NAME}.conf' was not created"
	exit 1
    fi
}

destroy_iscsi_target() {
    # remove iscsi target definition
    echo "[INFO] running: rm -f /etc/tgt/conf.d/$${STORAGE_NAME}.conf"
    if ! rm -f /etc/tgt/conf.d/$${STORAGE_NAME}.conf; then
	echo "iscsi target file '$${STORAGE_NAME}.conf' was not removed"
	exit 1
    fi
}

disconnect_iscsi_clients() {
    # create an array of proxmox node IPs
    declare -a proxmox_nodes=(%{for node in proxmox_nodes ~} "${node}" %{ endfor ~})

    # loop over all node IPs and disconnect from the iscsi target
    for node in "$${proxmox_nodes[@]}"; do
	echo "[INFO] running: ssh $${node} -i ~/.ssh/id_iscsiadm iscsiadm -m node -T ${iqn}:$${STORAGE_NAME} -p ${iscsi_host}:${iscsi_port} -u"
	if ! ssh $${node} -i ~/.ssh/id_iscsiadm iscsiadm -m node -T ${iqn}:$${STORAGE_NAME} -p ${iscsi_host}:${iscsi_port} -u; then
	    echo "couldn't disconnect $${node} from ${iqn}:$${STORAGE_NAME}"
	    exit 1
	fi
    done
}

create_pve_storage() {
    # create storage in PVE
    echo "[INFO] running: pvesm add iscsi $${STORAGE_NAME} -portal ${iscsi_host}:${iscsi_port} --target ${iqn}:$${STORAGE_NAME}"
    if ! pvesm add iscsi $${STORAGE_NAME} -portal ${iscsi_host}:${iscsi_port} --target ${iqn}:$${STORAGE_NAME}; then
	echo "couldn't add storage '$${STORAGE_NAME}' to PVE"
	exit 1
    fi
}

destroy_pve_storage() {
    # delete storage from PVE
    echo "[INFO] running: pvesm remove $${STORAGE_NAME}"
    if ! pvesm remove "$${STORAGE_NAME}" ; then
	echo "couldn't remove storage '$${STORAGE_NAME}' from PVE"
	exit 1
    fi
}

reload_tgt() {
    # reload tgt daemon
    echo "[INFO] running: /usr/sbin/tgt-admin --update ALL -c /etc/tgt/targets.conf"
    if ! /usr/sbin/tgt-admin --update ALL -c /etc/tgt/targets.conf; then
	echo "couldn't reload tgt"
	exit 1
    fi
}

main() {
    VG_NAME=$(echo "${lvm_pool}" | cut -d '/' -f1)
    STORAGE_NAME="cloudinit-${lvm_name}"

    if [ "$${ACTION}" == "create" ]; then
	create_lvm
	create_iscsi_target
	reload_tgt
	create_pve_storage
    elif [ "$${ACTION}" == "destroy" ]; then
	destroy_pve_storage
	disconnect_iscsi_clients
	destroy_iscsi_target
	reload_tgt
	destroy_lvm
    fi
}

# run main function
main
