#!/usr/bin/ksh -p
#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

. ${CTI_SUITE}/lib/libcommon.ksh
. ${CTI_SUITE}/config/test_config

cleanup()
{

    print "-----------------------------"
    info_print "FC-IOR test cleanup"

    # Get the vars in the test_config file 
    pf1=$PF_A
    pf2=$PF_B

	# Check PF whether created vf
    pf_array=($pf1 $pf2)
    for pf in ${pf_array[*]};do
	    info_print "Removing and destroying the vfs on $pf..."
	    check_pf_whether_created_vf $pf
	    if [ $? -eq 0 ];then
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
    print "-----------------------------"
    
    # Remove the temporary files used in the tests
    rm -rf $TEMP_LOGDIR
}

cleanup
