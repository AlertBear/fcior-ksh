#
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#

include $(CTI_ROOT)/Makefiles/Makefile.defs
include $(CTI_SUITE)/Targetdirs

CTI_SUBDIRS     = src tests

.PARALLEL: $(CTI_SUBDIRS)

all: $(CTI_SUBDIRS) .WAIT

install:   $(CTI_SUBDIRS) install_suite

clean lint:     $(CTI_SUBDIRS)

clobber:   $(CTI_SUBDIRS) remove-directories

include $(CTI_ROOT)/Makefiles/Makefile.targ
include $(CTI_ROOT)/Makefiles/Makefile.suite
