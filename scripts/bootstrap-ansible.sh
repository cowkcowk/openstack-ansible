#!/usr/bin/env bash

## Shell Opts ----------------------------------------------------------------
set -e -u -x

## Vars ----------------------------------------------------------------------
# The Ansible version used for testing
export ANSIBLE_PACKAGE=${ANSIBLE_PACKAGE:-"ansible-core==2.13.4"}

# Use pip opts to add options to the pip install command.
# This can be used to tell it which index to use, etc.
export PIP_OPTS=${PIP_OPTS:-""}

## Functions -----------------------------------------------------------------
info_block "Checking for required libraries." 2> /dev/null ||
    source scripts/scripts-library.sh


## Main ----------------------------------------------------------------------
info_block "Bootstrapping System with Ansible"

# Create the ssh dir if needed
ssh_key_create

# Determine the distribution which the host is running on
determine_distro

# Obtain the SHA of the upper-constraints to use for the ansible runtime venv
TOX_CONSTRAINTS_SHA=$(awk '/requirements_git_install_branch:/ {print $2}' playbooks/defaults/repo_packages/openstack_services.yml)

# if we are in CI, grab the u-c file from the locally cached repo, otherwise download
TOX_CONSTRAINTS_PATH="/opt/ansible-runtime-constraints-${TOX_CONSTRAINTS_SHA}.txt"
if [[ -z "${ZUUL_SRC_PATH+defined}" || ! -d "${ZUUL_SRC_PATH:-''}" ]]; then
  wget ${TOX_CONSTRAINTS_FILE:-"https://opendev.org/openstack/requirements/raw/${TOX_CONSTRAINTS_SHA}/upper-constraints.txt"} -O ${TOX_CONSTRAINTS_PATH}
else
  git --git-dir=${ZUUL_SRC_PATH}/opendev.org/openstack/requirements/.git show ${TOX_CONSTRAINTS_SHA}:upper-constraints.txt > ${TOX_CONSTRAINTS_PATH}
fi

export TOX_CONSTRAINTS_FILE="file://${TOX_CONSTRAINTS_PATH}"

PYTHON_EXEC_PATH="${PYTHON_EXEC_PATH:-$(which python3)}"


# Ensure that Ansible binaries run from the venv

# Ensure wrapper tool is executable
chmod +x /usr/local/bin/openstack-ansible

echo "openstack-ansible wrapper created."

echo "System is bootstrapped and ready for use."
