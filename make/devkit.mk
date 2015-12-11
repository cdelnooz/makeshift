#
# devkit.mk --Recursive make considered useful.
#
# Contents:
# build:          --The default target
# INSTALL_*:      --Specialised install commands.
# src:            --Make sure the src target can write to the Makefile
# clean:          --Devkit-specific customisations for the "clean" target.
# distclean:      --Remove artefacts that devkit creates/updates.
# +help:          --Output some help text extracted from the included makefiles.
# stddir/%        --Common pattern rules for installing stuff into the "standard" places.
# bindir/archdir: --Rules for installing any executable from archdir.
# system_confdir: --Rules for installing into the local system's "etc" dir.
# %.gz:           --Rules for building compressed/summarised data.
# %.shx:          --Create a file from a shell script output.
#
# Remarks:
# The devkit makefiles together define a build system that extends
# the "standard" targets (as documented by GNU make) with a few extras
# for performing common maintenance functions.  The basic principles
# are:
#
#  * the standard make targets are magically recursive
#  * per-language rules extends standard targets with custom actions
#  * per-system customisations defined in $(OS).mk, $(ARCH).mk
#  * optional per-project customisations defined in $(PROJECT).mk
#  * all system-specific files are saved in the $(archdir) subdirectory
#  * file dependencies are auto-included, and auto-generated by build target.
#  * traditional macros work as expected (e.g. CFLAGS, LDFLAGS)
#
# This file defines variables according to the conventions described
# in the GNU make documentation (c.f. "Makefile Conventions" section).
#
# Note that these directories are not truly faithful to the GNU doc.s,
# in particular I avoid the $(archdir) suffix, for most of the
# installation directories.  This is more useful in practice.
#
# See Also:
# http://www.gnu.org/software/make/manual/make.html#Variables-for-Specifying-Commands).
#
SUBDIRS := $(subst /.,,$(wildcard */.))
DESTDIR ?= /
PREFIX  ?= /usr/local
prefix  ?= $(PREFIX)

DEFAULT_OS := $(shell uname -s | tr A-Z a-z | sed -e 's/-[.0-9]*//')
DEFAULT_ARCH := $(shell uname -m | tr A-Z a-z)

OS      ?= $(DEFAULT_OS)
ARCH    ?= $(DEFAULT_ARCH)
PROJECT ?= default
DEVKIT_HOME ?= /usr/local

# TODO: integrate TODO pattern...
TODO_PATTERN = -e TODO -e FIXME -e REVISIT -e @todo -e @fixme -e @revisit

#
# ECHO is a shell no-op by default, but can be redefined by setting "VERBOSE".
#
ifeq "$(VERBOSE)" "1"
    ECHO = echo
else ifeq "$(VERBOSE)" "color"
    ECHO = colour_echo() { printf '\033[36m%s\033[m\n' "$$*"; }; colour_echo
else
    ECHO = :
endif

#ECHO_TARGET = @+$(ECHO) "++ $$PWD $@ \$$?: $?"
#ECHO_TARGET = @+$(ECHO) "++ $$PWD $@ \$$^: $^"
ECHO_TARGET = @+$(ECHO) "++ $$PWD $@ \$$?: $?"; $(ECHO) "++ $$PWD $@ \$$^: $^"

.SUFFIXES:			# remove default suffix rules

#
# build: --The default target
#
all:	build

#
# INSTALL_*: --Specialised install commands.
#
INSTALL 	  := install -D
INSTALL_PROGRAM   := $(INSTALL) -m 755
INSTALL_FILE      := $(INSTALL) -m 644
INSTALL_DIRECTORY := $(INSTALL) -d

include std-directories.mk

#
# src: --Make sure the src target can write to the Makefile
#
src:			file-writable[Makefile]

#
# clean: --Devkit-specific customisations for the "clean" target.
#
clean:	clean-devkit
.PHONY:	clean-devkit
clean-devkit:
	$(ECHO_TARGET)
	$(RM) core *~ *.bak *.tmp *.out $(OS.AUTO_CLEAN) $(ARCH.AUTO_CLEAN)

#
# distclean: --Remove artefacts that devkit creates/updates.
#
distclean:	clean-devkit distclean-devkit
.PHONY:	distclean-devkit
distclean-devkit:
	$(ECHO_TARGET)
	$(RM) tags TAGS
	$(RM) -r $(OS) $(ARCH) $(archdir)

#
# var[%]:	--Pattern rule to print a make "variable".
#
#+vars:   $(.VARIABLES:%=+var[%])
+var[%]:
	@$(ECHO) "# $(origin $*) variable \"$*\":"
	@echo "$*='$($*)'"
+var[ECHO_TARGET]:
	@echo "# $(origin ECHO_TARGET) variable \"ECHO_TARGET\":"
	@echo "ECHO_TARGET=(unprintable)"

+var[.VARIABLES]:;@: # avoid listing a list of all the variables

#
# +help: --Output some help text extracted from the included makefiles.
#
+help:		;	@mk-help $(MAKEFILE_LIST)
+features:	;	@echo $(.FEATURES)
+dirs:		;	@echo $(.INCLUDE_DIRS)
+files:		;	@echo $(MAKEFILE_LIST)

include recursive-targets.mk valid.mk
include os/$(OS).mk arch/$(ARCH).mk
-include project/$(PROJECT).mk
include lang/mk.mk $(language:%=lang/%.mk) ld.mk
#include vcs/$(VCS).mk

#
# stddir/% --Common pattern rules for installing stuff into the "standard" places.
#
$(bindir)/%:		%;	$(INSTALL_PROGRAM) $? $@
$(sbindir)/%:		%;	$(INSTALL_PROGRAM) $? $@
$(sysconfdir)/%:	%;	$(INSTALL_FILE) $? $@
$(libexecdir)/%:	%;	$(INSTALL_PROGRAM) $? $@
$(libdir)/%:		%;	$(INSTALL_FILE) $? $@
$(datadir)/%:		%;	$(INSTALL_FILE) $? $@
$(sharedstatedir)/%:	%;	$(INSTALL_FILE) $? $@
$(localstatedir)/%:	%;	$(INSTALL_FILE) $? $@
#
# bindir/archdir: --Rules for installing any executable from archdir.
#
$(bindir)/%:		$(archdir)/%;	$(INSTALL_PROGRAM) $? $@
$(libexecdir)/%:	$(archdir)/%;	$(INSTALL_PROGRAM) $? $@
#$(libdir)/%:		$(archdir)/%;	$(INSTALL_FILE) $? $@

#
# system_confdir: --Rules for installing into the local system's "etc" dir.
#
$(system_confdir)/%:	%;	$(INSTALL_FILE) $? $@

#
# %.gz: --Rules for building compressed/summarised data.
#
%.gz:		%;	gzip -9 <$? >$@
%.gpg:		%;	gpg -b -o $? $@
%.sum:		%;	sum $? | sed -e 's/ .*//' >$@
%.md5:		%;	md5sum $? | sed -e 's/ .*//' >$@

#
# %.shx: --Create a file from a shell script output.
#
%:		%.shx;	sh $*.shx > $@
