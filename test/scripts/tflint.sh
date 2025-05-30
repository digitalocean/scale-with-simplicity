#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${SCRIPT_DIR}/.tflint.hcl"
tflint --init
tflint --config "${CONFIG_PATH}" --recursive