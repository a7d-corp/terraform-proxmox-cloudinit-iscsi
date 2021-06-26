#!/bin/bash -e

ACTION="${1:-}"
ISCSI_HOST="${2:-}"
ISCSI_PORT="${3:-}"
IQN="${4:-}"
LVM_POOL="${5:-}"
LVM_NAME="${6:-}"
LVM_SIZE="${7:-}"

USAGE="${0} create/destroy ISCSI_HOST ISCSI_PORT IQN LVM_POOL LVM_NAME SIZE"

validate_vars() {
    if [[ -z "${ISCSI_HOST}" ]]; then
	echo "${USAGE}"
	exit 1
    fi

    if [[ -z "${ISCSI_PORT}" ]]; then
	echo "${USAGE}"
	exit 1
    fi

    if [[ -z "${IQN}" ]]; then
	echo "${USAGE}"
	exit 1
    fi

    if [[ -z "${LVM_POOL}" ]]; then
	echo "${USAGE}"
	exit 1
    fi

    if [[ -z "${LVM_NAME}" ]]; then
	echo "${USAGE}"
	exit 1
    fi

    if [[ -z "${LVM_SIZE}" && "${ACTION}" == "create" ]]; then
	echo "${USAGE}"
	exit 1
    fi
}

create_lvm() {
    # create lvm
    echo "[INFO] running: lvcreate -V ${lvm_size} --thin -n ${lvm_name} ${lvm_pool}"
    if ! lvcreate -V ${lvm_size} --thin -n ${lvm_name} ${lvm_pool}; then
	echo "lvm creation failed"
	exit 1
    fi
}

destroy_lvm() {
    echo "[INFO] running: lvremove -fy /dev/mapper/${VG_NAME}-${lvm_name}"
    if ! lvremove -fy /dev/mapper/${VG_NAME}-${lvm_name}; then
	echo "lvm volume '/dev/mapper/${VG_NAME}-${lvm_name}' not removed"
	exit 1
    fi
}

create_iscsi_target() {
    # create iscsi target definition
    echo "[INFO] creating: /etc/tgt/conf.d/${lvm_name}.conf"
    cat > /etc/tgt/conf.d/${lvm_name}.conf <<EOF
<target ${iqn}:${lvm_name}>
	backing-store /dev/mapper/${VG_NAME}-${lvm_name}
</target>
EOF

    # check if it was created successfully
    if [[ ! -f /etc/tgt/conf.d/${lvm_name}.conf ]]; then
	echo "iscsi target file '${lvm_name}.conf' was not created"
	exit 1
    fi
}

destroy_iscsi_target() {
    # remove iscsi target definition
    echo "[INFO] running: rm -f /etc/tgt/conf.d/${lvm_name}.conf"
    if ! rm -f /etc/tgt/conf.d/${lvm_name}.conf; then
	echo "iscsi target file '${lvm_name}.conf' was not removed"
	exit 1
    fi
}

disconnect_iscsi_clients() {
    # create an array of proxmox node IPs
    declare -a proxmox_nodes=(%{for node in proxmox_nodes ~} "${node}" %{ endfor ~})

    # loop over all node IPs and disconnect from the iscsi target
    for node in "${proxmox_nodes[@]}"; do
	echo "[INFO] running: ssh ${node} -i ~/.ssh/id_iscsiadm iscsiadm -m node -T ${iqn}:${lvm_name} -p ${iscsi_host}:${iscsi_port} -u"
	if ! ssh ${node} -i ~/.ssh/id_iscsiadm iscsiadm -m node -T ${iqn}:${lvm_name} -p ${iscsi_host}:${iscsi_port} -u; then
	    echo "couldn't disconnect ${node} from ${iqn}:${lvm_name}"
	    exit 1
	fi
    done
}

create_pve_storage() {
    # create storage in PVE
    echo "[INFO] running: pvesm add iscsi ${lvm_name} -portal ${iscsi_host}:${iscsi_port} --target ${iqn}:${lvm_name}"
    if ! pvesm add iscsi ${lvm_name} -portal ${iscsi_host}:${iscsi_port} --target ${iqn}:${lvm_name}; then
	echo "couldn't add storage '${lvm_name}' to PVE"
	exit 1
    fi
}

destroy_pve_storage() {
    # delete storage from PVE
    echo "[INFO] running: pvesm remove ${lvm_name}"
    if ! pvesm remove "${lvm_name}" ; then
	echo "couldn't remove storage '${lvm_name}' from PVE"
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
    validate_vars

    VG_NAME=$(echo "${lvm_pool}" | cut -d '/' -f1)

    if [ "${ACTION}" == "create" ]; then
	create_lvm
	create_iscsi_target
	reload_tgt
	create_pve_storage
    elif [ "${ACTION}" == "destroy" ]; then
	destroy_pve_storage
	disconnect_iscsi_clients
	destroy_iscsi_target
	reload_tgt
	destroy_lvm
    fi
}
# run main function
main
