#!/usr/bin/ksh -p

function info_print
{
    print "INFO : $@"
}

function info_print_report
{
   print "INFO : $@"
   cti_report "INFO : $@"
}

function error_print
{
    print "ERROR: $@"
}

function error_print_report
{
   print "ERROR: $@"
   cti_report "ERROR: $@"
}

function warn_print
{
    print "WARN : $@"
}

function warn_print_report
{
   print "WARN : $@"
   cti_report "WARN : $@"
}

function exec_cmd
{
    typeset cmd=$1
    typeset templog=$(mktemp)
    ${cmd} 2>${templog}
    if [[ $? != 0 ]];then
        typeset error_reason=`cat ${templog}`
        print "Execute \"${cmd}\" failed:\n $error_reason"
        return 1
    fi
    return 0
}

function exec_rshcmd
{
    typeset rmt_host=$1
    typeset rmt_cmd=$2
    typeset templog=$(mktemp)
    ping $rmt_host > /dev/null 2>&1
    if [[ $? -ne 0 ]];then
        print "Remote host ${rmt_host} is not pingable"
        return 3
    fi
    rsh -n ${rmt_host} "${rmt_cmd} 2>&1;echo \$?" > ${templog} 2>&1 
    if [[ $? != 0 ]];then
        print "Failed to rlogin ${rmt_host}"
        return 2
    else
        typeset exec_rshcmd_ret=`cat ${templog}|tail -1`
        if [[ $exec_rshcmd_ret != 0 ]];then
            typeset error_reason=`cat ${templog}|sed '$d'`
            print "Remote execute ${rmt_cmd} failed:\n${error_reason}" 
            return 1
        fi
    fi
    return 0
}

function exec_cmd_output
{
    typeset cmd=$1
    typeset templog=$(mktemp)
    typeset output=`${cmd} 2>${templog}`
    if [[ $? != 0 ]];then
        typeset error_reason=`cat ${templog}`
        print "Execute \"${cmd}\" failed:\n ${error_reason}"
        return 1
    else
        print $output
    fi
}

function exec_rshcmd_output
{
    typeset rmt_host=$1
    typeset rshcmd=$2
    typeset templog=$(mktemp)
    ping ${rmt_host} > /dev/null 2>&1
    if [[ $? != 0]];then
        print "Remote host ${rmt_host} is not pingable"
        return 2
    fi
    rsh -n ${rmt_host} "${rshcmd} 2>&1; echo \$?" > ${templog} 2>&1
    if [[ $? != 0 ]];then
        print "Remote host ${rmt_host} could not be able to rlogin"
        return 3
    else
        typeset exec_rshcmd_ret=`cat ${templog}|tail -1`
        if [[ ${exec_rshcmd_ret} != 0 ]];then
            typeset error_reason=`cat ${templog} | sed '$d'` 
            print "Remote execute failed in ${rmt_host}:\n${error_reason}"
            return 1 
        fi
        cat ${templog}|sed '$d'
    fi
    return 0
}

function is_domain_alive
{
    typeset ip=$1
    typeset timeout_value=${2:-300}
           
    SECONDS=0
    while (( SECONDS < $timeout_value ))
    do
        ping $ip 2>&1 >/dev/null && break
    done
    (( SECONDS >= $timeout_value )) && { print timeout waiting for guest domain to become alive; return 1; }

    SECONDS=0
    while (( SECONDS < 120 ))
    do
        exec_rshcmd $ip pwd >/dev/null && break
        print -n $?
        sleep 1
    done
    (( SECONDS >= 120 )) && { print timeout waiting for guest domain to become rsh-able; return 1; }
    return 0
}

function domain_exists
{
    ldm list $1 > /dev/null 2>&1
    return $?    
}

function get_domain_status
{
    status=$(ldm list $1|grep $1|awk '{print $1}')
    echo ${status}
}

function check_iod_runmode
{
    iod=$1 
    iod_ip=$2
    #check domain whether exists     
    if ! $(domain_exists $iod);then
        error_print_report "$iod not exists"     
        return 1
    fi
    # check domain if active
    if [[ $(get_domain_status $iod) != "active" ]];then
        error_print_report "$iod is not active"
        return 1
    fi
    # check domain if MPxIO enabled
    sysv=$(exec_rshcmd_output $iod "uname -r")
    if [[ "$sysv" == "5.12" ]];then
        exec_rshcmd $iod "test -f /etc/driver/drv/fp.conf"           
        [ $? -ne 0 ] && return 0
    fi
    is_mpxio=$(exec_rshcmd_output $iod "sed -n '/^mpxio-disable=.*;$/p' /etc/driver/drv/fp.conf")
    echo $is_mpxio|grep no
    if [ $? -ne 0 ];then
        exec_rshcmd $iod "sed '/^mpxio-disable=.*;$/s/yes/no/' /etc/driver/drv/fp.conf > /etc/driver/drv/fp.conf.new" 
        exec_rshcmd $iod "rm /etc/driver/drv/fp.conf"
        exec_rshcmd $iod "mv /etc/driver/drv/fp.conf.new /etc/driver/drv/fp.conf"
    fi
    sleep 3
    exec_rshcmd $iod "reboot"
    sleep 120
    is_domain_alive $iod 600
    [ $? -ne 0 ] && {error_print_report "Failed to enable MPxIO in $iod"; return 1}
}

function check_root_domain_runmode
{
    nprd=$1
    # check domain whether exists
    if ! $(domain_exists $nprd);then
        error_print_report "$nprd not exists"
        return 1
    fi
    # check domain if active
    if [[ $(get_domain_status $nprd) != "active" ]];then
        error_print_report "$nprd is not active"
        return 1
    fi
    # check domain falure-policy
    failure_policy_equation=$(ldm list-bindings $nprd | grep failure-policy)
    failure_policy=$(echo $failure_policy_equation |cut -d'=' -f2)
    if [[ $failure_policy != "ignore" ]];then
        print "$nprd faliure-policy is $failure_policy, setting to ignore" 
    fi
    ldm set-domain failure-policy=ignore $nprd
    [ $? -ne 0 ] && return 1
	return 0
}

function check_pf_support_ior
{
    pf=$1
    class=$(ldm list-io -l -p $pf|cut -d'|' -f7|cut -d'=' -f2)
    if [[ $class != 'FIBRECHANNEL' ]];then
        error_print_report "$pf is not a FC port"        
        return 1
    fi
}

function list_all_vfs_on_pf
{
    pf=$1
    tmpfile=$(mktemp)
    i=0
    ldm list-io -p $pf|grep type=VF > $tmpfile
    if [ $? -eq 0 ];then
        while read ndev ualias nstatus ndomain ntype nbus;do
           alias=''  
           eval $ualias
           vf_array[$i]=$alias
           (( i++ ))
        done < $tmpfile
        echo $vf_array
    else
        return 0
    fi
}

function check_pf_whether_created_vf
{
    pf=$1
    ldm list-io -p $pf|grep type=VF
    return $?
}

function get_domain_status
{
    domain=$1
    state=''
    state_equation=$(ldm list -p $domain|tail -1|cut -d'|' -f3)
    eval $state_equation
    echo $state
}

function get_domain_port
{
    domain=$1
    cons=''
    cons_equation=$(ldm list -p $domain|tail -1|cut -d'|' -f5)
    eval $cons_equation
    echo $cons
}

function get_volume_of_domain
{
    i=0
    vdisk_num=$(ldm list-bindings $1|grep VDISK|wc -l)    
    vdsdev_array=$(ldm list-bindings -p fc|grep VDISK|gawk -F'[|=@]' '{print $5}')
    for vdsdev in ${vdsdev_array};do
        volume=$(ldm list-services -p|grep ${vdsdev}|awk -F'|' '{print $4}'|awk -F'=' '{print $2}') 
        volume_array[$i]=${volume#'/dev/zvol/dsk/'}
        (( i++ ))
    done
    echo ${volume_array}
}

function remove_vf_from_domain
{
    vf=$1
    domain=$2
    ldm rm-io $vf $domain
    return $?
}

function destroy_all_vfs_on_pf
{
    pf=$1
    vf_array=$(list_all_vfs_on_pf $pf)
    for vf in ${vf_array[@]};do
        domain=''
        domain_equation=$(ldm list-io -p|grep $vf|cut -d'|' -f5)
        eval $domain_equation
        remove_vf_from_domain $vf $domain
        [ $? -ne 0 ] && return 1
    done
    ldm destroy-vf -n max $pf
    return $? 
}

function create_vf_in_dynamic_mode
{
    pf=$1

    created_vf_str=$(ldm create-vf $pf)
    new_vf=$(echo $created_vf_str | cut -d':' -f2)
    echo $new_vf
}

function create_vf_in_manual_mode
{
    pf=$1
    port_wwn=$2
    node_wwn=$3

    create_vf_str=$(ldm create-vf port-wwn=$port_wwn node-wwn=$node_wwn $pf)
    new_vf=$(echo $created_vf_str | cut -d':' -f2)
    echo $new_vf
}

function allocate_vf_to_domain
{
    vf=$1
    domain=$2
    
    ldm add-io $vf $domain
    return $?
}

function reboot_domain_expect
{
    domain=$1
    password=$2

    port=$(get_domain_port $domain)
    reboot_domain $port $password
    return $?
}

function offline_vf_in_domain
{
    vf=$1
    domain=$2

    exec_rshcmd $domain "hotplug offline $1"
    return $?
}

function online_vf_in_domain
{
    vf=$1
    domain=$2

    exec_rshcmd $domain "hotplug online $1"
    return $?
}

function check_vdbench_exists
{
    domain=$1
    vdbench_path=$2

    exec_rshcmd $domain "test -d $vdbench_path"
    return $?
}

function check_io_workload_exists
{
    domain=$1

    exec_rshcmd $domain "test -f run_io.sh"
    return $?
}

function distribute_io_workload_to_domain
{
    domain=$1
    retv=0 
    exec_rshcmd $domain "touch run_io.sh"
    [ $? -ne 0 ] && return 1

    cmd1="while true"
    cmd2="do"
    cmd3="mkfile 500m /ior_pool/fs/fcior_test"
    cmd4="sleep 1"
    cmd5="mv /ior_pool/fs/fcior_test /export/home/"
    cmd6="sleep 1"
    cmd7="rm -f /ior_pool/fs/fcior_test"
    cmd8="sleep 1"
    cmd9="mv /export/home/fcior_test /ior_pool/fs/"
    cmd10="sleep 1"
    cmd11="rm -f /ior_pool/fs/fcior_test"
    cmd12="sleep 1"
    cmd13="done"
    for (( i=1; i<14; i++ ))
    do
        exec_rshcmd $domain "echo 'cmd$i' >> run_io.sh"
        [ $? -ne 0 ] && ((retv++))
    done
    exec_rshcmd $domain "chmod +x run_io.sh"
    return $retv
}

function get_vf_hotplug_dev
{
    vf=$1

    vf_info=$(ldm list-io -p|grep $vf)
    hotplug_dev=$(echo $vf_info|gawk -F'[|=]' '{print $2}')
    echo /$hotplug_dev
}

function get_vf_logical_path
{
    vf=$1
    domain=$2

    logical_path=""
    vf_hotplug_dev=$(get_vf_hotplug_dev $vf)
    logical_paths=$(exec_rshcmd_output $domain "luxadm probe|grep Path|awk -F: '{print $2}'")
    for logical_path_item in $logical_paths
    do
        exec_rshcmd $domain "prtconf -v $logical_path_item|grep pci|grep $vf_hotplug_dev"
        [ $? -eq 0 ] && {logical_path=$logical_path_item; break}    
    done
    echo $logical_path
}

function check_vf_io_workload_on
{
    vf=$1
    domain=$2

    logical_path=$(get_vf_logical_path $vf $domain)
    disk=${logical_path##\/}
    disk=${disk%s2}

    iodata=$(exec_rshcmd_output $domain \
        "iostat -xn $disk 5 2|grep $disk|awk 'NR==2{print $3,$4}")
    kr=$(echo $iodata|cut -f1)
    kw=$(echo $iodata|cut -f2)
    if (( $kr + $kw > 0 ));then
        return 0
    else
        return 1
    fi
}

function run_io_workload_on_vf
{
    vf=$1
    domain=$2

    logical_path=$(get_vf_logical_path $vf $domain)
    disk=${logical_path##\/}
    disk=${disk%s2}

    exec_rshcmd $domain "zpool create -f ior_pool $disk"
    [ $? -ne 0 ] && return 1
    exec_rshcmd $domain "zfs create ior_pool/fs "
    [ $? -ne 0 ] && return 1
    exec_rshcmd $domain "~/run_io.sh &"
    [ $? -ne 0 ] && return 1
    if (( $(check_vf_io_workload_on $vf $domain) != 0 ));then
        return 1 
    else    
        return 0
    fi
}

function run_vdbench_on_vf
{
    vf=$1
    domain=$2

    logical_path=$(get_vf_logical_path $vf $domain)
    disk=${logical_path##\/}
    disk=${disk%s2}

    test -d vdbench > /dev/null 2>&1
    if [ $? -ne 0 ];then
        ip_addr=$(exec_rshcmd_output $domain "ipadm show-addr net0|tail -1|awk '{print $4}'|cut -d'/' -f1")
        rcp -r /export/home/vdbench root@ip_addr:~/  
        [ $? -ne 0 ] && return 1
    fi
    exec_rshcmd $domain "rm -f ~/vdbench/ior.*"
    exec_rshcmd $domain "sed '/c0t0d0sx/s/c0t0d0sx/$disk/' ~/vdbench/example1 > ~/vdbench/ior.cfg.test"
    [ $? -ne 0 ] && return 1
    exec_rshcmd $domain "sed 's/elapsed=10/elapsed=3600/' ~/vdbench/ior.cfg.test > ~/vdbench/ior.cfg"
    [ $? -ne 0 ] && return 1
    exec_rshcmd $domain "~/vdbench/vdbench -f ~/vdbench/ior.cfg > /dev/null 2>&1 &"
    [ $? -ne 0 ] && return 1
    if (( $(check_vf_io_workload_on $vf $domain) != 0 ));then
        return 1 
    else    
        return 0
    fi
}

function get_vf_hotplug_path_port_status
{
	vf=$1
	domain=$2

	hotplug_dev=$(get_vf_hotplug_dev $vf)
	hotplug_dev_format=${hotplug_dev//\//\\\/}
	hotplug_dev_num=$(exec_rshcmd_output $domain "hotplug list -lv|sed -n '/^$hotplug_dev_format$/='")
	hotplug_path_port_status_num=$((hotplug_dev_num - 1))
	hotplug_path_port_status=$(exec_rshcmd_output $domain "hotplug list -lv|sed -n '${hotplug_path_port_status_num}p'")
	echo $hotplug_path_port_status
}

function get_vf_hotplug_path_port
{
	vf=$1
	domain=$2

	hotplug_path_port_status=$(get_vf_hotplug_path_port_status $vf $domain)
	hotplug_path_port=$(echo $hotplug_path_port_status|awk '{print $1 " " substr($2,2,length($2)-2)}')
	echo $hotplug_path_port
}

function get_vf_hotplug_path
{
	vf=$1
	domain=$2

	hotplug_path_port_status=$(get_vf_hotplug_path_port_status $vf $domain)
	hotplug_path=$(echo $hotplug_path_port_status|awk '{print $1}')
	echo $hotplug_path
}

function get_vf_hotplug_port
{
	vf=$1
	domain=$2

	hotplug_path_port_status=$(get_vf_hotplug_path_port_status $vf $domain)
	hotplug_port_str=$(echo $hotplug_path_port_status|awk '{print $2}')
	hotplug_port=${hotplug_port:2:7}
	echo $hotplug_port
}


function get_vf_hotplug_status
{
	vf=$1
	domain=$2

	hotplug_path_port_status=$(get_vf_hotplug_path_port_status $vf $domain)
	hotplug_status=$(echo $hotplug_path_port_status|awk '{print $3}')
	echo $hotplug_status
}

function save_domain_hotplug_list
{
	domain=$1
	file=$2

	touch $file 
	if [ $? -ne 0 ];then
		return 1
	fi
	hotplug_list_info=$(exec_rshcmd_output $domain "hotplug list -lv > $file")
	return $?
}

function get_vf_hotplug_status_from_file
{
	hotplug_dev=$1
	file=$2
	
	hotplug_dev_format=${hotplug_dev//\//\\\/}
	hotplug_dev_num=$(sed -n '/^$hotplug_dev_format$/=' $file)
	hotplug_status_num=$((hotplug_dev_num - 1))
	hotplug_status=$(sed -n '${hotplug_status_num}p' $file|awk '{print $3}')
	echo $hotplug_status
}

function get_hotplug_status_from_file
{
	dev_list=$1
	domain=$2


}
