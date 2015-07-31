#!/usr/bin/ksh -p
#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

. ${CTI_SUITE}/lib/libcommon.ksh
. ${CTI_SUITE}/lib/reboot_domain.exp
. ${CTI_SUITE}/lib/panic_domain.exp

startup()
{

    # Get the vars in the test_config file 
    nprd1=$NPRD_A
    nprd1_password=$NPRD_A_PASSWORD
    nprd2=$NPRD_B
    nprd2_password=$NPRD_B_PASSWORD
    iod=$IOD
    iod_ip=$IOD_IP
	iod_password=$PASSWORD
    pf1=$PF_A
    pf2=$PF_B
    pf1_vf0_port=$PORT_WWN_PF_A_VF0
    pf1_vf0_node=$NODE_WWN_PF_A_VF0
    pf1_vf1_port=$PORT_WWN_PF_A_VF1
    pf1_vf1_node=$NODE_WWN_PF_A_VF1
    pf1_vf2_port=$PORT_WWN_PF_A_VF2
    pf1_vf2_node=$NODE_WWN_PF_A_VF2
    pf2_vf0_port=$PORT_WWN_PF_B_VF0
    pf2_vf0_node=$NODE_WWN_PF_B_VF0
    pf2_vf1_port=$PORT_WWN_PF_B_VF1
    pf2_vf1_node=$NODE_WWN_PF_B_VF1
    pf2_vf2_port=$PORT_WWN_PF_B_VF2
    pf2_vf2_node=$NODE_WWN_PF_B_VF2

    # Check the vars in config file
    pf_array=($pf1 $pf2)
    nprd_array=($nprd1 $nprd2)
    for i in {0 1};do
        ldm list-io -p ${pf_array[$i]} |grep type=PF|grep ${nprd_array[$i]} > \
                /dev/null 2>&1
        if [ $? -ne 0 ];then
            info_print "${pf_array[$i]} is not affiliated to ${nprd_array[$i]}"
            return 1
        fi
    done

    # Check root domain whether support ior test
    for nprd in ${nprd_array[*]};do
	    info_print "Checking $nprd1 whether support ior test"
	    check_root_domain_runmode $nprd1
	    if [ $? -ne 0 ];then
		    error_print "$nprd1 not support ior test"
		    cti_deleteall "$nprd1 not support ior test"
		    return 1
	    else
		    info_print "$nprd1 support ior test"
	    fi
    done

	# Check io domain whether supports ior test
	info_print "Checking $iod whether support ior test"
	check_iod_runmode $iod $iod_ip
	if [ $? -ne 0 ];then
		error_print "$iod not support ior test"
		cti_deleteall "$iod not support ior test"
		return 1
	else
		info_print "$iod support ior test"
	fi		

	# Check PF whether support ior test 
    for pf in ${pf_array[*]};do
	    info_print "Checking $pf whether supports ior test"
	    check_pf_support_ior $pf
	    if [ $? -ne 0 ];then
		    error_print "$pf not support ior test"
		    cti_deleteall "$pf not support ior test"
		    return 1
	    else
		    info_print "$pf support ior test"
	    fi		
    done

	# Check PF whether created vf
    for pf in ${pf_array[*]};do
	    info_print "Checking $pf whether has created vf"
	    check_pf_whether_create_vf $pf
	    if [ $? -ne 0 ];then
		    info_print "$pf has created vf, destroying..."
		    destroy_all_vfs_on_pf $pf
		    if [ $? -ne 0 ];then
			    error_print "Failed to destroy all the vfs on $pf"
			    cti_deleteall "Failed to destroy all the vfs on $pf"
			    return 1
		    else
			    info_print "Done"
		    fi			
	    else
		    info_print "No vfs has created on $pf"
	    fi
    done

	# Create vfs on pf
    pf1_port_wwn_array=($pf1_vf0_port $pf1_vf1_port $pf1_vf2_port)
    pf1_node_wwn_array=($pf1_vf0_node $pf1_vf1_node $pf1_vf2_node)
    info_print "Creating vfs on $pf1"
    for i in {0..2};do
	    vf=$(create_vf_in_manual_mode $pf1 ${pf1_port_wwn_array[$i]} \
                $pf1_node_wwn_array[$i]})
	    if [ $? -ne 0 ];then
		    error_print "Failed to create all vfs on $pf1" 
		    cti_deleteall "Failed to create all vfs on $pf1"
		    return 1
	    else
		    info_print "Created $vf"
            vf_array[$i]=$vf
	    fi
    done
    
    pf2_port_wwn_array=($pf2_vf0_port $pf2_vf1_port $pf2_vf2_port)
    pf2_node_wwn_array=($pf2_vf0_node $pf2_vf1_node $pf2_vf2_node)
    info_print "Creating vfs on $pf2"
    for i in {0..2};do
	    vf=$(create_vf_in_manual_mode $pf2 ${pf2_port_wwn_array[$i]} \
                ${pf2_port_wwn_array[$i]})
	    if [ $? -ne 0 ];then
		    error_print "Failed to create all vfs on $pf2" 
		    cti_deleteall "Failed to create all vfs on $pf2"
		    return 1
	    else
		    info_print "Created $vf"
            vf_array[$i]=$vf
	    fi
    done
    return 0
}

startup
