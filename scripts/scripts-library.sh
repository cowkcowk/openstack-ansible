#!/usr/bin/env bash

## Functions -----------------------------------------------------------------
# Build ansible-runtime venv
function build_ansible_runtime_venv {
  ${PYTHON_EXEC_PATH} -m venv /opt/ansible-runtime --clear

  
}