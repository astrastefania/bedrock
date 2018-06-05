#!/bin/bash
set -ex
# TODO: document required env vars

. ${BASH_SOURCE%/*}/../docker/bin/set_git_env_vars.sh

if [[ -e ${CONFIG_CHECKOUT:=${BASH_SOURCE%/*}/..config_checkout} ]]; then
    cd ${CONFIG_CHECKOUT}
    git checkout ${CONFIG_BRANCH:=master}
    git pull
else
    git clone --depth=1 -b ${CONFIG_BRANCH:=master} ${CONFIG_REPO} ${CONFIG_CHECKOUT}
    cd ${CONFIG_CHECKOUT}
fi

set -u
sed -ie "s|image: .*|image: ${DEPLOYMENT_DOCKER_IMAGE}|" ${NAMESPACE}/${DEPLOYMENT_YAML:=deploy.yaml}
git add ${NAMESPACE}/${DEPLOYMENT_YAML}
git commit -m "set image to ${DEPLOYMENT_DOCKER_IMAGE}" || echo "nothing new to commit"
git push
DEPLOYMENT_VERSION=$(git rev-parse --short HEAD)

DEPLOYMENT_NAME=$(python3 -c "import yaml; print(yaml.load(open(\"$NAMESPACE/$DEPLOYMENT_YAML\"))['metadata']['name'])")
CHECK_URL=$DEPLOYMENT_LOG_BASE_URL/$NAMESPACE/$DEPLOYMENT_NAME/$DEPLOYMENT_VERSION
attempt_counter=0
max_attempts=60
until $(curl --output /dev/null --silent --head --fail $CHECK_URL); do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
        echo "Deployment incomplete"
        exit 1
    fi
    attempt_counter=$(($attempt_counter+1))
    sleep 10
done
