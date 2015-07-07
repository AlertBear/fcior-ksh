#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

include $(CTI_ROOT)/Makefiles/Makefile.defs
include $(CTI_SUITE)/Targetdirs

CTI_SUBDIRS    = ksh expect

.PARALLEL : $(CTI_SUBDIRS)

all install : $(CTI_SUBDIRS)

clean clobber lint : $(CTI_SUBDIRS)

include $(CTI_ROOT)/Makefiles/Makefile.targ
