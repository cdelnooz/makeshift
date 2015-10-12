#
# PYTEST.MK --Rules for running tests with Python's "pytest" framework.
#
# Contents:
# test:           --Run all tests, and save the results to pytest.xml.
# test-pytest[%]: --Run an individual test.
# clean-pytest:   --Cleanup files generated by running tests.
#
# Remarks:
# These rules runs the tests defined by the PYTEST_SRC explicitly.
#

PYTEST_SRC ?= $(PY_SRC)
PYTEST ?= py.test
PYTEST_FLAGS = \
	$(TARGET.PYTEST_FLAGS) $(LOCAL.PYTEST_FLAGS) $(PROJECT.PYTEST_FLAGS) \
	$(ARCH.PYTEST_FLAGS) $(OS.PYTEST_FLAGS)
#
# test: --Run all tests, and save the results to pytest.xml.
#
test:	test-pytest

test-pytest:
	$(PYTEST) $(PYTEST_FLAGS) $(PYTEST_SRC)

#
# test-pytest[%]: --Run an individual test.
#
test[%.py]:
	$(PYTEST) $(PYTEST_FLAGS) $*.py

clean:		clean-pytest
distclean:	clean-pytest

#
# clean-pytest: --Cleanup files generated by running tests.
#
.PHONY:		clean-pytest
clean-pytest:
	$(RM) pytest-tests.xml
