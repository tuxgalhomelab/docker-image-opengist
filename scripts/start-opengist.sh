#!/usr/bin/env bash
set -E -e -o pipefail

opengist_config="/data/opengist/config/config.yml"

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

setup_opengist_config() {
    echo "Checking for existing Opengist config ..."
    echo

    if [ -f "${opengist_config:?}" ]; then
        echo "Existing Opengist configuration \"${opengist_config:?}\" found"
    else
        echo "Generating Opengist configuration at ${opengist_config:?}"
        mkdir -p "$(dirname "${opengist_config:?}")"
        cat << EOF > ${opengist_config:?}
log-level: info
log-output: stdout
opengist-home: /data/opengist/data
db-filename: opengist.db
index.enabled: true
index.dirname: opengist.index
sqlite.journal-mode: WAL
http.host: 0.0.0.0
http.port: 6157
http.git-enabled: true
ssh.git-enabled: false
EOF
    fi

    echo
    echo
}

start_opengist() {
    echo "Starting Opengist ..."
    echo

    exec opengist --config ${opengist_config:?}
}

set_umask
setup_opengist_config
start_opengist
