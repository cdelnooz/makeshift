#
# MD.MK --Rules for dealing with markdown files via pandoc.
#
# Contents:
# %.pdf:          --Create a PDF document from a markdown file.
# build:          --Create PDF documents from markdown.
# clean-md:       --Clean up output
# src-md:         --Update MD_SRC macro.
# todo-md:        --Report unfinished work in markdown files.
# +version:       --Report details of tools used by markdown.
#
# Remarks:
# The md module uses pandoc as the underlying transformation engine
# and is configured to use markdown+raw_attributes.
#
 The `src` target will update the makefile with the following macros:
#
# * MD_SRC --a list of the CommonMark/github-flavoured ".md" files
#
# See Also:
# http://pandoc.org
#
.PHONY: $(recursive-targets:%=%-md)


ifdef autosrc
    LOCAL_MD_SRC := $(wildcard *.md)

    MD_SRC ?= $(LOCAL_MD_SRC)
endif

MD ?= pandoc
MD_PDF ?= lualatex

PRINT_pandoc_VERSION = $(MD) --version
PRINT_lualatex_VERSION = $(MD_PDF) --version

ALL_MDFLAGS ?= -f markdown+raw_attribute \
    $(OS.MDFLAGS) $(ARCH.MDFLAGS) $(PROJECT.MDFLAGS) \
    $(LOCAL.MDFLAGS) $(TARGET.MDFLAGS) $(MDFLAGS)

ALL_MDDEPSFLAGS ?= $(PROJECT.MDDEPSFLAGS) $(LOCAL.MDDEPSFLAGS)

#
# $(archdir)/%.pdf:%.md --build a PDF document from a markdown file.
#
$(archdir)/%.pdf: %.md $(gendir)/%.d | $(archdir) $(gendir)
	$(ECHO_TARGET)
	$(Q)$(MDDEPS) -t "$@" $(ALL_MDDEPSFLAGS) "$<" > $(gendir)/$*.d
	$(MD) $(ALL_MDFLAGS) --pdf-engine=$(MD_PDF) -o $@ $<

MD_TRG = $(MD_SRC:%.md=$(archdir)/%.pdf)

DEPFILES = $(MD_SRC:%.md=$(gendir)/%.d)
$(DEPFILES):

include $(wildcard $(DEPFILES))

#
# $(archdir)/%.tex:%md --generate a latex document from a markdown file
#
$(archdir)/%.tex: %.md | $(archdir)
	$(ECHO_TARGET)
	$(Q)$(MDDEPS) -t "$@" $(ALL_MDDEPSFLAGS) "$<" > $(gendir)/$*.d
	$(MD) $(ALL_MDFLAGS) -t latex -o $@ $<

#
# build: --Create PDF documents from markdown.
#
build: build-md
build-md: $(MD_TRG)


#
# clean-md: --Clean up markdown's derived files.
#
distclean:	clean-md
clean:	clean-md
clean-md:
	$(ECHO_TARGET)
	$(RM) $(MD_SRC:%.md=$(archdir)/%.pdf)
	$(RM) $(DEPFILES)

#
# src-md: --Update MD_SRC, MMD_SRC macros.
#
src:	src-md
src-md:
	$(ECHO_TARGET)
	$(Q)$(MK-FILELIST) -f $(MAKEFILE) -qn MD_SRC *.md

#
# todo-md: --Report unfinished work in markdown files.
#
todo:	todo-md
todo-md:
	$(ECHO_TARGET)
	@$(GREP) $(TODO_PATTERN) $(MD_SRC) $(MMD_SRC) /dev/null ||:
#
# +version: --Report details of tools used by markdown.
#
+version: cmd-version[$(MD)] cmd-version[$(MD_PDF)]
