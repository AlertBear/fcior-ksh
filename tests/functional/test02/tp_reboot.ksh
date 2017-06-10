#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

############################################################################
#
#__stc_assertion_start
#
# ID:
#       functional/test_02/tp_reboot
#
# DESCRIPTION:
#       Reboot one root domain, IO domain with two VFs from this single root domain
#       is alive during the period and the two VFs is still ONLINE after the period
#
# STRATEGY:
#       - Create two VFs from a single domain.
#       - Allocated these two VFs to the IO domain.
#       - Reboot root domain by "reboot" in this domain.
#       - During reboot root domain,IO domain should be alive.
#       - During reboot, check VFs state by "hotplug list" in IO domain,
#         should be "OFFLINE". Check the logical path from VF, should be None.
#       - During reboot, check VFs state by "hotplug list" in IO domain,
#         should be "ONLINE".
#       - After reboot, check VFs state by "hotplug list" in IO domain,
#         both should be "ONLINE"
#
# TESTABILITY: implicit
#
# AUTHOR: daijie.x.guo@oracle.com
# 
# REVIEWERS:
# 
# TEST AUTOMATION LEVEL: automated
# 
# CODING_STATUS:  COMPLETED 
# 
# __stc_assertion_end
#
################################################################################

tp_reboot()
{
	info_print_report "FC-IOR functional test02 TP1: reboot"

	# Get the vars
	nprd=$NPRD_A
    nprd_password=$NPRD_A_PASSWORD
	iod=$iod
    iod_ip=$IOD_IP

    nprd_port=$(get_domain_port $nprd)

    operation="reboot"
    timeout=300

    reboot_domain.exp $nprd_port $nprd_password > /dev/null &
    sleep 10

    check_ior $iod $TST_VFS $VFS_INFO_LOG $operation $timeout
    if [[ $? == 0 ]];then
        cti_pass "FC-IOR functional test02 TP1: Pass"
    elif [[ $? == 1 ]];then
        cti_fail "FC_IOR functional test02 TP1: Fail"
    else
        cti_unresolved "FC-IOR functional test02 TP1: Unresolved"
    fi            
}
