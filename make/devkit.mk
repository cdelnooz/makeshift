#
# devkit.mk --Recursive make considered useful.
#
# Contents:
# DEVKIT_VERSION:    --define the version of devkit that's running.
# PWD:               --Force reset of PWD
# OS:                --Set OS macro by interpolating "uname -s".
# ARCH:              --Set ARCH macro by interpolating "uname -m".
# VERBOSE:           --Control how (+how much, how colourful) echo's output is.
# ECHO_TARGET:       --Common macro for logging in devkit targets.
# no-implicit-rules: --Disable the archaic Makefile rules.
# build:             --The default target
# install-all:       --Install all language-specific items.
# package:           --By default, (successfully) do no packaging.
# src:               --Make sure the src target can write to the Makefile.
# clean:             --Devkit-specific customisations for the "clean" target.
# distclean:         --Remove artefacts that devkit creates/updates.
# +help:             --Output some help text extracted from the included makefiles.
# stddir/%           --Common pattern rules for installing stuff into the "standard" places.
# bindir/archdir:    --Rules for installing any executable from archdir.
# system_confdir:    --Rules for installing into the local system's "etc" dir.
# %.gz:              --Rules for building compressed/summarised data.
# %.pdf:             --Convert a PostScript file to PDF.
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
nullstring :=
space := $(nullstring) # end of the line
MAKEFILE := $(firstword $(MAKEFILE_LIST))
#
# DEVKIT_VERSION: --define the version of devkit that's running.
#
DEVKIT_HOME ?= /usr/local
DEVKIT_VERSION ?= local
DEVKIT_RELEASE ?= latest
-include version.mk

SUBDIRS := $(subst /,,$(sort $(dir $(wildcard */*[mM]akefile*))))

#
# define a target-specific tmpdir, for those targets that need it.
#
tmpdir = tmp-$(notdir $@)

#
# PWD: --Force reset of PWD
#
# REVISIT: needed for indirect makes invoked by packages
#
PWD := $(shell echo $$PWD)

#
# OS: --Set OS macro by interpolating "uname -s".
#
ifndef OS
    OS := $(shell uname -s | tr A-Z a-z | sed -e 's/-[.0-9]*//')
endif
export OS

#
# ARCH: --Set ARCH macro by interpolating "uname -m".
#
ifndef ARCH
    ARCH := $(shell uname -m | tr A-Z a-z)
endif
export ARCH

PROJECT ?= default
LOCAL	:= $(subst lib,,$(notdir $(PWD)))

#
# Patterns matched by the "todo" target
#
TODO_KEYWORDS = TODO FIXME REVISIT @todo @fixme @revisit
TODO_PATTERN = $(TODO_KEYWORDS:%=-e %)

#
# VERBOSE: --Control how (+how much, how colourful) echo's output is.
#
ifeq "$(VERBOSE)" "color"
    ECHO = colour_echo() { printf '\033[36m++ $(CURDIR) $@: \033[33m%s\033[m\n' "$$*"; }; colour_echo
else ifneq "$(VERBOSE)" ""
    ECHO = echo '++ $(CURDIR) $@: '
else
    ECHO = :
endif

#
# ECHO_TARGET: --Common macro for logging in devkit targets.
#
#ECHO_TARGET = @+$(ECHO) "\$$?: $?"
#ECHO_TARGET = @+$(ECHO) "\$$^: $^"
ECHO_TARGET = @+$(ECHO) "\$$?: $?"; $(ECHO) "\$$^: $^"
#ECHO_TARGET = @+$(ECHO) "changed(\$$?): $?"; $(ECHO) "$@ dependants(\$$^): $^"

#
# no-implicit-rules: --Disable the archaic Makefile rules.
#
# Remarks:
# It's tempting to set Make's default settings like so:
#
#     MAKEFLAGS += --no-builtin-rules --no-print-directory
#
# ...and this will work, as long as all the recursive makes are
# using devkit.  However, if a leaf make is *not* using devkit,
# it's probably relying on some of those builtin rules, and will
# fail badly.
#
.SUFFIXES:

#
# build: --The default target
#
all:	build

include $(VARIANT:%=variant/%.mk) os/$(OS).mk arch/$(ARCH).mk
include project/$(PROJECT).mk
#include vcs/$(VCS).mk

#
# Define DESTDIR, prefix if that hasn't happened already.
#
DESTDIR ?= /
PREFIX  ?= /usr/local
prefix  ?= $(PREFIX)

include std-directories.mk
include recursive-targets.mk valid.mk
include lang/mk.mk $(language:%=lang/%.mk) ld.mk

#
# install-all: --Install all language-specific items.
#
# Remarks:
# Devkit doesn't have any action for the install target, because
# it often makes good sense *not* to install everything that's built
# (e.g. if it's just a local build utility, or it's part of something
# bigger, etc.)
#
install-all: $(language:%=install-%)
uninstall-all: $(language:%=uninstall-%)

#
# package: --By default, (successfully) do no packaging.
#
# Remarks:
# This target exists so that the parent directory can do
# "package" recursively, delegating to the children directories.
# Unless overridden in the child makefile, it will execute
# this target (thus stopping the recursion).
#
package:; $(ECHO_TARGET)

#
# src: --Make sure the src target can write to the Makefile.
#
src:			| file-writable[$(MAKEFILE)]

#
# clean: --Devkit-specific customisations for the "clean" target.
#
clean:	clean-devkit
.PHONY:	clean-devkit
clean-devkit:
	$(ECHO_TARGET)
	$(RM) *~ *.bak *.tmp *.out $(OS.AUTO_CLEAN) $(ARCH.AUTO_CLEAN)  $(PROJECT.AUTO_CLEAN)

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
	@$(ECHO) "# $(origin $*) $(flavor $*) variable \"$*\":"
	@echo "$*='$($*)'"

+var[ECHO_TARGET]:
	@echo "# $(origin ECHO_TARGET) $(flavour ECHO_TARGET) variable \"ECHO_TARGET\":"
	@echo "ECHO_TARGET=(unprintable)"

+var[.VARIABLES]:;@: # avoid listing a list of all the variables

#
# +help: --Output some help text extracted from the included makefiles.
#
+help:			;	@mk-help $(MAKEFILE_LIST)
+features:		;	@echo $(.FEATURES)
+dirs:			;	@echo $(.INCLUDE_DIRS)
+files:			;	@echo $(MAKEFILE_LIST)

#
# stddir/% --Common pattern rules for installing stuff into the "standard" places.
#
# Remarks:
# Most executables are installed via the INSTALL_PROGRAM macro, which
# may "strip" the executable in some contexts (e.g. "make
# install-strip").  Scripting languages will typically have
# language-specific install targets that use INSTALL_SCRIPT to
# override this behaviour.
#
$(archdir):		;	$(MKDIR) $@
$(gendir):		;	$(MKDIR) $@

$(bindir)/%:		%;	$(INSTALL_PROGRAM) $? $@
$(sbindir)/%:		%;	$(INSTALL_PROGRAM) $? $@
$(libexecdir)/%:	%;	$(INSTALL_PROGRAM) $? $@
$(sysconfdir)/%:	%;	$(INSTALL_DATA) $? $@
$(libdir)/%:		%;	$(INSTALL_DATA) $? $@
$(datadir)/%:		%;	$(INSTALL_DATA) $? $@
$(sharedstatedir)/%:	%;	$(INSTALL_DATA) $? $@
$(localstatedir)/%:	%;	$(INSTALL_DATA) $? $@
$(wwwdir)/%:		%;	$(INSTALL_DATA) $? $@
#
# bindir/archdir: --Rules for installing any executable from archdir.
#
$(bindir)/%:		$(archdir)/%;	$(INSTALL_PROGRAM) $? $@
$(libexecdir)/%:	$(archdir)/%;	$(INSTALL_PROGRAM) $? $@
#$(libdir)/%:		$(archdir)/%;	$(INSTALL_DATA) $? $@

#
# system_confdir: --Rules for installing into the local system's "etc" dir.
#
$(system_confdir)/%:	%;	$(INSTALL_DATA) $? $@

#
# %.gz: --Rules for building compressed/summarised data.
#
%.gz:			%;	gzip -9 <$? >$@
%.gpg:			%;	gpg -b -o $? $@
%.sum:			%;	sum $? | sed -e 's/ .*//' >$@
%.md5:			%;	md5sum $? | sed -e 's/ .*//' >$@

#
# %.pdf: --Convert a PostScript file to PDF.
#
%.pdf:	%.ps;	$(PS2PDF) $*.ps
