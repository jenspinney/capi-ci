#!/bin/bash
set -eu

# ENV
: "${BOSH_URL:?}"
: "${BOSH_CLIENT_SECRET:?}"
: "${CF_ADMIN_PASSWORD:?}"
: "${BOSH_GW_PRIVATE_KEY_CONTENTS:?}"
: "${DEPLOYMENT_TO_BACKUP:=cf}"
: "${DEPLOYMENT_TO_RESTORE:=cf}"
: "${BBR_BUILD_PATH:=/usr/local/bin/bbr}"
: "${BOSH_CLIENT:=admin}"
: "${BOSH_CA_CERT:=""}"
: "${BOSH_GW_USER:="jumpbox"}"
: "${GOPATH:=/go}"

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../../" && pwd )"
drats_src="${workspace_dir}/drats"

drats_dir="${GOPATH}/src/github.com/cloudfoundry-incubator/disaster-recovery-acceptance-tests"
mkdir -p "${drats_dir}"
cp -a "${drats_dir}/." "${drats_dir}"

tmpdir="$( mktemp -d /tmp/run-drats.XXXXXXXXXX )"

ssh_key="${tmpdir}/bosh.pem"
echo "${BOSH_GW_PRIVATE_KEY_CONTENTS}" > "${ssh_key}"
chmod 600 "${ssh_key}"
sshuttle -e "ssh -i "${ssh_key}" -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null'" -r "${BOSH_GW_USER}@${BOSH_URL}" 10.0.0.0/8 &
tunnel_pid="$!"

cleanup() {
  kill "${tunnel_pid}"
  rm -rf "${tmpdir}"
}
trap 'cleanup' EXIT

if [ -n "${BOSH_CA_CERT}" ]; then
  export BOSH_CERT_PATH="${tmpdir}/bosh.ca"
  echo "${BOSH_CA_CERT}" > "${BOSH_CERT_PATH}"
fi

echo "Running DRATs..."
pushd "${drats_dir}" > /dev/null
  ./scripts/run_acceptance_tests.sh
popd > /dev/null

echo "Successfully ran DRATs!"