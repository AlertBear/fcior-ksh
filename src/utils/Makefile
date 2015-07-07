#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

include $(CTI_ROOT)/Makefiles/Makefile.defs
include $(CTI_SUITE)/Targetdirs
 
CTI_SRCS:sh     = ls *.ksh
CTI_TARGET      = $(CTI_SRCS:%.ksh=$(CTI_SUITE_BIN)/%)

all install     : $(CTI_SUITE_BIN) $(CTI_TARGET)

clean   :
		$(RM) $(CTI_SUITE_BIN) $(CTI_MACH64) $(CTI_TARGET)

clobber : clean
		$(RM) $(CTI_PROTO)/bin
                   
include ${CTI_ROOT}/Makefiles/Makefile.targ
