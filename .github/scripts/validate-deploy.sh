#!/usr/bin/env bash

echo "******************************"
echo " validate deployment script"
echo "******************************"
echo ""

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

GIT_REPO=$(cat git_repo)
GIT_TOKEN=$(cat git_token)

BIN_DIR=$(cat .bin_dir)

export PATH="${BIN_DIR}:${PATH}"

source "${SCRIPT_DIR}/validation-functions.sh"

if ! command -v oc 1> /dev/null 2> /dev/null; then
  echo "oc cli not found" >&2
  exit 1
fi

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

if ! command -v ibmcloud 1> /dev/null 2> /dev/null; then
  echo "ibmcloud cli not found" >&2
  exit 1
fi

export KUBECONFIG=$(cat .kubeconfig)

echo "******************************"
echo " show gitops-output.json content"
echo "******************************"
echo ""
echo "******************************"
ROOT_PATH=$(pwd)
echo "ROOT_PATH: $ROOT_PATH"
cat $ROOT_PATH/gitops-output.json
echo ""
echo "******************************"

NAMESPACE=$(cat .namespace)
echo "NAMESPACE: $NAMESPACE"
COMPONENT_NAME=$(jq -r '.name // "terraform-gitops-ubi"' gitops-output.json)
echo "COMPONENT_NAME: $COMPONENT_NAME"
BRANCH=$(jq -r '.branch // "main"' gitops-output.json)
echo "BRANCH: $BRANCH"
SERVER_NAME=$(jq -r '.server_name // "default"' gitops-output.json)
echo "SERVER_NAME: $SERVER_NAME"
LAYER=$(jq -r '.layer_dir // "2-services"' gitops-output.json)
echo "LAYER: $LAYER"
TYPE=$(jq -r '.type // "base"' gitops-output.json)
echo "TYPE: $TYPE"

mkdir -p .testrepo

git clone https://${GIT_TOKEN}@${GIT_REPO} .testrepo

cd .testrepo || exit 1

find . -name "*"

set -e

echo "******************************"
echo " 1. validate deployment validate_gitops_content"
echo "******************************"
echo ""
validate_gitops_content "${NAMESPACE}" "${LAYER}" "${SERVER_NAME}" "${TYPE}" "${COMPONENT_NAME}" "values.yaml"

echo "******************************"
echo " 2. validate deployment check_k8s_namespace"
echo "******************************"
echo ""
check_k8s_namespace "${NAMESPACE}"

echo "******************************"
echo " 3. validate deployment check_k8s_resource"
echo "******************************"
check_k8s_resource "${NAMESPACE}" "deployment" "${COMPONENT_NAME}"

echo "******************************"
echo " 4. validate deployment check_k8s_pod"
echo "******************************"
check_k8s_pod "${NAMESPACE}" "${COMPONENT_NAME}"

cd ..
rm -rf .testrepo
