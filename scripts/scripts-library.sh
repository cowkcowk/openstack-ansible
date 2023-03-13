#!/usr/bin/env bash

## Vars ----------------------------------------------------------------------
LINE='----------------------------------------------------------------------'

# The vars used to prepare the Ansible runtime venv
PIP_COMMAND="/opt/ansible-runtime/bin/pip"

## Functions -----------------------------------------------------------------
# Build ansible-runtime venv
function build_ansible_runtime_venv {
    # All distros have a python-virtualenv > 13.
    # - Centos 8 Stream has 15.1, which holds pip 9.0.1, setuptools 28.8, wheel 0.29
    # - openSUSE 42.3 has 13.1.2, which holds pip 7.1.2, setuptools 18.2, wheel 0.24.
    #   See also: https://build.opensuse.org/package/show/openSUSE%3ALeap%3A42.3/python-virtualenv
    # - Ubuntu Xenial has 15.0.1, holding pip 8.1.1, setuptools 20.3, wheel 0.29
    #   See also: https://packages.ubuntu.com/xenial/python-virtualenv

    ${PYTHON_EXEC_PATH} -m venv /opt/ansible-runtime --clear

    # The vars used to prepare the Ansible runtime venv
    PIP_OPTS+=" --constraint global-requirement-pins.txt"

    # When executing the installation, we want to specify all our options on the CLI,
    # making sure to completely ignore any config already on the host. This is to
    # prevent the repo server's extra constraints being applied, which include
    # a different version of Ansible to the one we want to install. As such, we
    # use --isolated so that the config file is ignored.

    # Upgrade pip setuptools and wheel to the appropriate version
    ${PIP_COMMAND} install --isolated ${PIP_OPTS} --constraint ${TOX_CONSTRAINTS_FILE} --upgrade pip setuptools wheel

    # Install ansible and the other required packages
    ${PIP_COMMAND} install --isolated ${PIP_OPTS} --constraint ${TOX_CONSTRAINTS_FILE} -r requirements.txt ${ANSIBLE_PACKAGE}

    # Install our osa_toolkit code from the current checkout
    $PIP_COMMAND install -e .

    # If we are in openstack-CI, install systemd-python for the log collection python script
    if [[ -e /etc/ci/mirror_info.sh ]]; then
      ${PIP_COMMAND} install --isolated ${PIP_OPTS} systemd-python
    fi
}

# Determine the distribution we are running on, so that we can configure it
# appropriately.
function determine_distro {
    source /etc/os-release 2>/dev/null
    export DISTRO_ID="${ID}"
    export DISTRO_NAME="${NAME}"
    export DISTRO_VERSION_ID=${VERSION_ID}
}

function ssh_key_create {
  # Ensure that the ssh key exists and is an authorized_key
  key_path="${HOME}/.ssh"
  key_file="${key_path}/id_rsa"

  # Ensure that the .ssh directory exists and has the right mode
  if [ ! -d ${key_path} ]; then
    mkdir -p ${key_path}
    chmod 700 ${key_path}
  fi

  # Ensure a full keypair exists
  if [ ! -f "${key_file}" -o ! -f "${key_file}.pub" ]; then

    # Regenrate public key if private key exists
    if [ -f "${key_file}" ]; then
      ssh-keygen -f ${key_file} -y > ${key_file}.pub
    fi

    # Delete public key if private key missing
    if [ ! -f "${key_file}" ]; then
      rm -f ${key_file}.pub
    fi

    # Regenerate keypair if both keys missing
    if [ ! -f "${key_file}" -a ! -f "${key_file}.pub" ]; then
      ssh-keygen -t rsa -f ${key_file} -N ''
    fi

  fi

  # Ensure that the public key is included in the authorized_keys
  # for the default root directory and the current home directory
  key_content=$(cat "${key_file}.pub")
  if ! grep -q "${key_content}" ${key_path}/authorized_keys; then
    echo "${key_content}" | tee -a ${key_path}/authorized_keys
  fi
}

function print_info {
  PROC_NAME="- [ $@ ] -"
  printf "\n%s%s\n" "$PROC_NAME" "${LINE:${#PROC_NAME}}"
}

function info_block {
  echo "${LINE}"
  print_info "$@"
  echo "${LINE}"
}
