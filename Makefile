SHELL_FILES = \
	bin/xcind-compose \
	bin/xcind-config \
	bin/xcind-proxy \
	lib/xcind/xcind-app-env-lib.bash \
	lib/xcind/xcind-lib.bash \
	lib/xcind/xcind-proxy-lib.bash \
	lib/xcind/xcind-workspace-lib.bash \
	test/test-xcind.sh \
	test/test-xcind-proxy.sh \
	install.sh \
	uninstall.sh

.PHONY: test format shfmt shellcheck lint check

test:
	bash test/test-xcind.sh
	bash test/test-xcind-proxy.sh

format:
	shfmt --write .

shfmt:
	shfmt --diff .

shellcheck:
	shellcheck $(SHELL_FILES)

lint: shfmt shellcheck

check: lint test
