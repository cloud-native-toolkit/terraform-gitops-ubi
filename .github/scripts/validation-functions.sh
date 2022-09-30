#!/usr/bin/env bash
echo "******************************"
echo " validate functions script"
echo "******************************"
echo ""

validate_gitops_content () {
  echo "******************************"
  echo " validate functions 'validate_gitops_content'"
  echo "******************************"
  echo ""

  local NS="$1"
  local GITOPS_LAYER="$2"
  local GITOPS_SERVER_NAME="$3"
  local GITOPS_TYPE="$4"
  local GITOPS_COMPONENT_NAME="$5"
  local PAYLOAD_FILE="${6:-values.yaml}"

  echo "Validating: namespace=${NS}, layer=${GITOPS_LAYER}, server=${GITOPS_SERVER_NAME}, type=${GITOPS_TYPE}, component=${GITOPS_COMPONENT_NAME}"

  if [[ ! -f "argocd/${GITOPS_LAYER}/cluster/${GITOPS_SERVER_NAME}/${GITOPS_TYPE}/${NS}-${GITOPS_COMPONENT_NAME}.yaml" ]]; then
    echo "ArgoCD config missing - argocd/${GITOPS_LAYER}/cluster/${GITOPS_SERVER_NAME}/${GITOPS_TYPE}/${NS}-${GITOPS_COMPONENT_NAME}.yaml" >&2
    exit 1
  fi

  echo "Printing argocd/${GITOPS_LAYER}/cluster/${GITOPS_SERVER_NAME}/${GITOPS_TYPE}/${NS}-${GITOPS_COMPONENT_NAME}.yaml"
  cat "argocd/${GITOPS_LAYER}/cluster/${GITOPS_SERVER_NAME}/${GITOPS_TYPE}/${NS}-${GITOPS_COMPONENT_NAME}.yaml"

  if [[ ! -f "payload/${GITOPS_LAYER}/namespace/${NS}/${GITOPS_COMPONENT_NAME}/${PAYLOAD_FILE}" ]]; then
    echo "Application values not found - payload/${GITOPS_LAYER}/namespace/${NS}/${GITOPS_COMPONENT_NAME}/${PAYLOAD_FILE}" >&2
    exit 1
  fi

  echo "Printing payload/${GITOPS_LAYER}/namespace/${NS}/${GITOPS_COMPONENT_NAME}/${PAYLOAD_FILE}"
  cat "payload/${GITOPS_LAYER}/namespace/${NS}/${GITOPS_COMPONENT_NAME}/${PAYLOAD_FILE}"
}

check_k8s_namespace () {
  echo "******************************"
  echo " validate functions 'check_k8s_namespace'"
  echo "******************************"
  echo ""

  local NS="$1"

  count=0
  until kubectl get namespace "${NS}" 1> /dev/null 2> /dev/null || [[ $count -eq 20 ]]; do
    echo "Waiting for namespace: ${NS}"
    count=$((count + 1))
    sleep 15
  done

  if [[ $count -eq 20 ]]; then
    echo "Timed out waiting for namespace: ${NS}" >&2
    exit 1
  else
    echo "Found namespace: ${NS}. Sleeping for 30 seconds to wait for everything to settle down"
    sleep 30
  fi
}

check_k8s_pod () {
  echo "******************************"
  echo " validate functions 'check_k8s_pod'"
  echo "******************************"
  echo ""

  local NS="$1"
  local COMPONENT_NAME="$2"

  count=0
  until kubectl get namespace "${NS}" 1> /dev/null 2> /dev/null || [[ $count -eq 20 ]]; do
    echo "Waiting for namespace: ${NS}"
    count=$((count + 1))
    sleep 15
  done
  
  kubectl get pods -n "${NS}"
  if [[ $count -eq 20 ]]; then
    echo "Timed out waiting for namespace: ${NS}" >&2
    exit 1
  else
    echo "Found namespace: ${NS}. Sleeping for 30 seconds to wait for everything to settle down"
    echo "Component name: ${COMPONENT_NAME}"
    kubectl get pods -n "${NS}"
    
    POD=$(kubectl get -n "${NS}" pods | grep "${COMPONENT_NAME}" | head -n 1 | awk '{print $1;}')
    
    if [[ $POD == "" ]] ; then
      echo "No pod found for ${COMPONENT_NAME} in ${NS}"
    else     
      kubectl exec -n "${NS}" "${POD}" --container "${COMPONENT_NAME}" -- ls
    fi
    sleep 30
  fi
}

check_k8s_resource () {
  echo "******************************"
  echo " validate functions 'check_k8s_resource'"
  echo "******************************"
  echo ""

  local NS="$1"
  local GITOPS_TYPE="$2"
  local NAME="$3"

  echo "Checking for resource: ${NS}/${GITOPS_TYPE}/${NAME}"

  count=0
  until kubectl get "${GITOPS_TYPE}" "${NAME}" -n "${NS}" 1> /dev/null 2> /dev/null || [[ $count -gt 20 ]]; do
    echo "Waiting for ${GITOPS_TYPE}/${NAME} in ${NS}"
    count=$((count + 1))
    sleep 30
  done

  if [[ $count -gt 20 ]]; then
    echo "Timed out waiting for ${GITOPS_TYPE}/${NAME}" >&2
    kubectl get "${GITOPS_TYPE}" -n "${NS}"
    exit 1
  fi

  kubectl get "${GITOPS_TYPE}" "${NAME}" -n "${NS}" -o yaml

  if [[ "${GITOPS_TYPE}" =~ deployment|statefulset|daemonset ]]; then
    kubectl rollout status "${GITOPS_TYPE}" "${NAME}" -n "${NS}" || exit 1
  elif [[ "${GITOPS_TYPE}" == "job" ]]; then
    kubectl wait --for=condition=complete "job/${NAME}" -n "${NS}" || exit 1
  fi

  echo "Done checking for resource: ${NS}/${GITOPS_TYPE}/${NAME}"
}