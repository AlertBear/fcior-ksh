#!/usr/bin/ksh -p
#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

tet_startup=startup
tet_cleanup=cleanup

test_list="
	tp_reboot \
	tp_panic \
"

startup()
{
	info_print_report "FC-IOR functional test02: In startup"

    # Get the vars 
    nprd1=$NPRD_A
    iod=$IOD
    iod_ip=$IOD_IP
    pf=$PF_A
	password=$IOD_PASSWORD

	# Get test vfs of pf
	for i in {0..1};do
		vf=$(eval echo ${pf}.VF$i)
        vf_array[$i]=$vf
    done
    
    # Check the vfs whether exist and be allocated
    info_print_report "Checking the test vfs whether exist..."
    for vf in ${vf_array[*]};do
        check_vf_exists_bound $vf
        if [ $? -ne 0 ];then
            error_print_report "$vf not exists or could not be removed" 
            cti_deleteall "$vf not exists or could not be removed" 
        fi
    done

    # Allocate vfs 
	for vf in ${vf_array[*]};do
		info_print_report "Allocting $vf to $iod"
		allocate_vf_to_domain $vf $iod
		if [ $? -ne 0 ];then
			error_print_report "Failed to allocate $vf to $pf" 
			cti_deleteall "Failed to allocate $vf to $pf"
			return 1
		else
			info_print_report "Done"
		fi
	done

	# Reboot io domain
	info_print_report "Rebooting $iod..."
	ldm stop -r $iod > /dev/null
    sleep 120
    is_domain_alive $iod_ip
	if [ $? -ne 0 ];then
		error_print_report "Failed to reboot $iod"
		cti_deleteall "Failed to reboot $iod"
		return 1
	else
		info_print_report "Done"
	fi

    # Get the test vfs info 
    ALL_VFS=(${vf_array[*]}) # All the vfs used in this test case
    TST_VFS=(${vf_array[*]}) # The vfs status need to be tested

    TEMP_LOGDIR=$CTI_LOGDIR/tmp
    TST_TEMP_LOGDIR=$TEMP_LOGDIR/func_02
    mkdir -p $TST_TEMP_LOGDIR
    VFS_INFO_LOG=$TST_TEMP_LOGDIR/vfs.info
    touch $VFS_INFO_LOG

    info_print_report "Getting all vfs info..."
    get_vfs_info "${TST_VFS[*]}" $iod_ip $VFS_INFO_LOG
	if [ $? -ne 0 ];then
		error_print_report "Failed to get all vfs info"
		cti_deleteall "Failed to get all vfs info"
		return 1
	else
		info_print_report "Done"
	fi
}

cleanup()
{
	info_print_report "FC-IOR functional test02: In cleanup"

    # Get the vars 
    nprd1=$NPRD_A
    iod=$iod
    pf=$PF_A

	# Get test vfs of pf
	for i in {0..1};do
		vf=$(eval echo ${pf}.VF$i)
        vf_array[$i]=$vf
    done

	# Remove the vfs used in this test cases
	for vf in ${vf_array[*]};do
        domain=""
        domain_equation=$(ldm list-io -p|grep $vf|cut -d'|' -f5)
        eval $domain_equation
        if [ -n $domain ];then
	        info_print_report "Removing $vf from $iod..."
            ldm rm-io $vf $domain  
	        if [ $? -ne 0 ];then
		        warn_print_report "Failed"
	        else
		        info_print_report "Done"
	        fi
        fi
    done

    # Remove the temporary files
    rm -rf $TST_TEMP_LOGDIR
}


. ./tp_reboot
. ./tp_panic

. ${CTI_SUITE}/lib/libcommon.ksh
. ${CTI_SUITE}/lib/reboot_domain.exp
. ${CTI_SUITE}/lib/panic_domain.exp
. ${TET_ROOT:?}/common/lib/ctilib.ksh
