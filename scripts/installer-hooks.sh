#!/bin/bash
# À lancer une fois par clone : active les hooks versionnés de .githooks/.
set -eu
cd "$(git rev-parse --show-toplevel)"
chmod +x .githooks/* scripts/*.sh
git config core.hooksPath .githooks
echo "Hooks activés (core.hooksPath = .githooks) : pre-commit monte la version si besoin, pre-push la contrôle."
