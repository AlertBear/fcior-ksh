#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

include $(CTI_ROOT)/Makefiles/Makefile.defs
include $(CTI_SUITE)/Targetdirs

_CTI_SRCS:sh    = ls *.ksh
CTI_SRCS        = $(_CTI_SRCS)
CTI_TARGET      = $(CTI_SRCS:%.ksh=%)
CTI_INSTOBJS    = $(CTI_TARGET:%=$(CTI_PROTO)/$(CTI_EXEC)/%)

include $(CTI_ROOT)/Makefiles/Makefile.tests

all : $(CTI_TARGET)
 
clean :
		$(RM) $(CTI_MACH64) $(CTI_TARGET)

clobber : clean
		$(RM) $(CTI_PROTO)/$(CTI_EXEC)

all clean clobber install : $(CTI_SUBDIRS)

include $(CTI_ROOT)/Makefiles/Makefile.targ
