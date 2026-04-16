SHELL_FILES = \
	bin/xcind-compose \
	bin/xcind-config \
	bin/xcind-proxy \
	bin/xcind-workspace \
	lib/xcind/xcind-app-lib.bash \
	lib/xcind/xcind-app-env-lib.bash \
	lib/xcind/xcind-assigned-lib.bash \
	lib/xcind/xcind-bootstrap.bash \
	lib/xcind/xcind-completion-bash.bash \
	lib/xcind/xcind-completion-zsh.bash \
	lib/xcind/xcind-host-gateway-lib.bash \
	lib/xcind/xcind-lib.bash \
	lib/xcind/xcind-naming-lib.bash \
	lib/xcind/xcind-proxy-lib.bash \
	lib/xcind/xcind-registry-lib.bash \
	lib/xcind/xcind-workspace-lib.bash \
	test/test-xcind.sh \
	test/test-xcind-proxy.sh \
	test/lib/assert.sh \
	test/lib/setup.sh \
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
