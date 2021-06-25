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
    if ! lvcreate -V ${LVM_SIZE} --thin -n ${LVM_NAME} ${LVM_POOL}; then
	echo "lvm creation failed"
	exit 1
    fi
}

destroy_lvm() {
    if ! lvremove -fy /dev/mapper/${VG_NAME}-${LVM_NAME}; then
	echo "lvm volume '/dev/mapper/${VG_NAME}-${LVM_NAME}' not removed"
	exit 1
    fi
}

create_iscsi_target() {
    # create iscsi target definition
    cat > /etc/tgt/conf.d/${LVM_NAME}.conf <<EOF
<target ${IQN}:${LVM_NAME}>
	backing-store /dev/mapper/${VG_NAME}-${LVM_NAME}
</target>
EOF

    # check if it was created successfully
    if [[ ! -f /etc/tgt/conf.d/${LVM_NAME}.conf ]]; then
	echo "iscsi target file '${LVM_NAME}.conf' was not created"
	exit 1
    fi
}

destroy_iscsi_target() {
    # remove iscsi target definition
    if ! rm -f /etc/tgt/conf.d/${LVM_NAME}.conf; then
	echo "iscsi target file '${LVM_NAME}.conf' was not removed"
	exit 1
    fi
}

disconnect_iscsi_clients() {
    # read in array of node IPs from external file
    source /tmp/pve-nodes.sh

    # loop over all node IPs and disconnect from the iscsi target
    for node in "${proxmox_nodes[@]}"; do
	if ! ssh ${node} -i ~/.ssh/id_iscsiadm iscsiadm -m node -T ${IQN}:${LVM_NAME} -p ${ISCSI_HOST}:${ISCSI_PORT} -u; then
	    echo "couldn't disconnect ${node} from ${IQN}:${LVM_NAME}"
	    exit 1
	fi
    done
}

create_pve_storage() {
    # create storage in PVE
    if ! pvesm add iscsi ${LVM_NAME} -portal ${ISCSI_HOST}:${ISCSI_PORT} --target ${IQN}:${LVM_NAME}; then
	echo "couldn't add storage '${LVM_NAME}' to PVE"
	exit 1
    fi
}

destroy_pve_storage() {
    # delete storage from PVE
    if ! pvesm remove "${LVM_NAME}" ; then
	echo "couldn't remove storage '${LVM_NAME}' from PVE"
	exit 1
    fi
}

reload_tgt() {
    # reload tgt daemon
    if ! /usr/sbin/tgt-admin --update ALL -c /etc/tgt/targets.conf; then
	echo "couldn't reload tgt"
	exit 1
    fi
}

main() {
    validate_vars

    VG_NAME=$(echo "${LVM_POOL}" | cut -d '/' -f1)

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
