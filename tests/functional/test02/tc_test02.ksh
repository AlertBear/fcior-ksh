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
	cti_report "FC-IOR functional test02: In startup"
	print "FC-IOR functional test02: In startup"

    # Get the vars 
    nprd1=$NPRD_A
    iod=$IOD
    iod_ip=$IOD_IP
    pf=$PF_A
	password=$PASSWORD

    # Check root domain whether support ior test
	info_print_report "Checking $nprd1 whether support ior test"
	check_root_domain_runmode $nprd1
	if [ $? -ne 0 ];then
		error_print_report "$nprd1 not support ior test"
		cti_deleteall "$nprd1 not support ior test"
		return 1
	else
		info_print_report "$nprd1 support ior test"
	fi

	# Check io domain whether supports ior test
	info_print_report "Checking $iod whether support ior test"
	check_iod_runmode $iod_ip
	if [ $? -ne 0 ];then
		error_print_report "$iod not support ior test"
		cti_deleteall "$iod not support ior test"
		return 1
	else
		info_print_report "$iod support ior test"
	fi		

	# Check PF whether support ior test 
	info_print_report "Checking $pf whether supports ior test"
	check_pf_support_ior $pf
	if [ $? -ne 0 ];then
		error_print_report "$pf not support ior test"
		cti_deleteall "$pf not support ior test"
		return 1
	else
		info_print_report "$pf support ior test"
	fi		

	# Check PF whether created vf
	info_print_report "Checking $pf whether has created vf"
	check_pf_whether_create_vf $pf
	if [ $? -ne 0 ];then
		info_print_report "$pf has created vf, destroying..."
		destroy_all_vfs_on_pf $pf
		if [ $? -ne 0 ];then
			error_print_report "Failed to destroy all the vfs on $pf"
			cti_deleteall "Failed to destroy all the vfs on $pf"
			return 1
		else
			info_print_report "Done"
		fi			
	else
		info_print_report "No vfs has created on $pf"
	fi

	# Create vfs on pf
	info_print_report "Creating vfs on $pf"
	for i in {0 1};do
		vf=$(create_vf_in_dynamic_mode $pf)
		if [ $? -ne 0 ];then
			error_print_report "Failed to create all vfs on $pf" 
			cti_deleteall "Failed to create all vfs on $pf"
			return 1
		else
			info_print_report "Created $vf"
            vf_array[$i]=$vf
		fi
    done
    
    # Allocate vfs 
	for vf in ${vf_array[*]};do
		info_print_report "Allocting $vf to $pf"
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
	iod_port=$(get_domain_port $iod)
	info_print_report "Rebooting $iod..."
	reboot_domain.exp $iod_port $password
	if [ $? -ne 0 ];then
		error_print_report "Failed to reboot $iod"
		cti_deleteall "Failed to reboot $iod"
		return 1
	else
		info_print_report "Done"
	fi
}

cleanup()
{
	cti_report "FC-IOR functional test02: In cleanup"
	print "FC-IOR functional test02: In cleanup"

    # Get the vars 
    nprd1=$NPRD_A
    iod=$iod
    pf=$PF_A

	# Destroying the vfs created in this test cases
	info_print_report "Destroying vfs created in the test case"
	destroy_all_vfs_on_pf $pf	
	if [ $? -ne 0 ];then
		warn_print_report "Failed to destroy the vfs created in this test case"
	else
		info_print_report "Done"
	fi
}


. ./tp_reboot
. ./tp_panic

. ${CTI_SUITE}/lib/libcommon.ksh
. ${CTI_SUITE}/lib/reboot_domain.exp
. ${CTI_SUITE}/lib/panic_domain.exp
. ${TET_ROOT:?}/common/lib/ctilib.ksh
