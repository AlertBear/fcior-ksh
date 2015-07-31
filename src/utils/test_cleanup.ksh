#!/usr/bin/ksh -p
#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

. ${CTI_SUITE}/lib/libcommon.ksh
. ${CTI_SUITE}/lib/reboot_domain.exp
. ${CTI_SUITE}/lib/panic_domain.exp

cleanup()
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

	# Check PF whether created vf
    for pf in ${pf_array[*]};do
	    info_print "Removing and destroying the vfs on $pf..."
	    check_pf_whether_create_vf $pf
	    if [ $? -ne 0 ];then
		    destroy_all_vfs_on_pf $pf
		    if [ $? -ne 0 ];then
			    error_print "Failed to destroy all the vfs on $pf"
			    return 1
		    else
			    info_print "Done"
		    fi			
	    else
		    info_print "No vfs needed to be removed from domain and destroyed"
	    fi
    done
}

cleanup
