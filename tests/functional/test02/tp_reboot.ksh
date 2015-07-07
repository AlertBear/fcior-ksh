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

tp1()
{
	cti_report "FC-IOR functional test02 TP1: reboot"
	# Get the vars
	nprd=$NPRD_A
	iod=$iod
	password=$SOURCE_DOMAIN_PASSWORD
}
