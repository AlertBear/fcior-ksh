#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

include $(CTI_ROOT)/Makefiles/Makefile.defs
include $(CTI_SUITE)/Targetdirs

CTI_SUBDIRS    = test02 

.PARALLEL : $(CTI_SUBDIRS)

all clean clobber lint install : $(CTI_SUBDIRS)

clobber:
		$(RM) $(CTI_PROTO)/$(CTI_EXEC)

include $(CTI_ROOT)/Makefiles/Makefile.targ
