SHELL := /usr/bin/env bash

.PHONY: install check check-local sync logs backup dots dots-local validate reload update outputs

install:
	./install.sh

check:
	./post-install-check.sh

check-local:
	./check-local.sh

sync:
	./sync.sh

logs:
	./logs.sh

backup:
	./backup.sh

dots:
	./bootstrap-dotfiles.sh

dots-local:
	./bootstrap-dotfiles.sh --local

validate:
	niri validate

reload:
	niri msg action reload-config || true

update:
	./update.sh

outputs:
	./deploy-outputs.sh
