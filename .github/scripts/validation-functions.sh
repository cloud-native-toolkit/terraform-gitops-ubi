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
  echo ""
  echo "******************************"
  echo "Validating: namespace=${NS}, layer=${GITOPS_LAYER}, server=${GITOPS_SERVER_NAME}, type=${GITOPS_TYPE}, component=${GITOPS_COMPONENT_NAME}"
  echo "******************************"
  if [[ ! -f "argocd/${GITOPS_LAYER}/cluster/${GITOPS_SERVER_NAME}/${GITOPS_TYPE}/${NS}-${GITOPS_COMPONENT_NAME}.yaml" ]]; then
    echo "ArgoCD config missing - argocd/${GITOPS_LAYER}/cluster/${GITOPS_SERVER_NAME}/${GITOPS_TYPE}/${NS}-${GITOPS_COMPONENT_NAME}.yaml" >&2
    exit 1
  fi
  echo ""
  echo "******************************"
  echo "Printing argocd/${GITOPS_LAYER}/cluster/${GITOPS_SERVER_NAME}/${GITOPS_TYPE}/${NS}-${GITOPS_COMPONENT_NAME}.yaml"
  cat "argocd/${GITOPS_LAYER}/cluster/${GITOPS_SERVER_NAME}/${GITOPS_TYPE}/${NS}-${GITOPS_COMPONENT_NAME}.yaml"
  echo "******************************"
  if [[ ! -f "payload/${GITOPS_LAYER}/namespace/${NS}/${GITOPS_COMPONENT_NAME}/${PAYLOAD_FILE}" ]]; then
    echo "Application values not found - payload/${GITOPS_LAYER}/namespace/${NS}/${GITOPS_COMPONENT_NAME}/${PAYLOAD_FILE}" >&2
    exit 1
  fi
  echo ""
  echo "******************************"
  echo "Printing payload/${GITOPS_LAYER}/namespace/${NS}/${GITOPS_COMPONENT_NAME}/${PAYLOAD_FILE}"
  cat "payload/${GITOPS_LAYER}/namespace/${NS}/${GITOPS_COMPONENT_NAME}/${PAYLOAD_FILE}"
  echo "******************************"
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
    sleep 30
  fi

  echo "******************************"
  echo "Ubi namespaces:"
  kubectl get namespaces | grep "ubi"
  echo ""
  echo "******************************"
  echo "Component name: ${COMPONENT_NAME}"
  echo ""
  echo "******************************"
  echo "Ubi pods:"
  kubectl get pods --all-namespaces | grep ubi
  echo "-----------------------------"
  echo ""
  echo "******************************"
  echo "UBI deployments: "
  echo ""

  GITOPS_TYPE=deployment
  NAME="ubi-helm-ubi-helm"
    count=0
    until kubectl get "${GITOPS_TYPE}" "${NAME}" -n "${NS}" 1> /dev/null 2> /dev/null || [[ $count -gt 20 ]]; do
      echo "------($count)---------------"
      echo "Verify all deployments containing UBI"
      kubectl get deployments --all-namespaces | grep ubi
      echo "-----------------------------"
      echo "Verify all namespaces containing UBI"
      kubectl get namespaces | grep "ubi"
      echo "-----------------------------"
      echo "Waiting for ${GITOPS_TYPE}/${NAME} in ${NS}"
      count=$((count + 1))
      sleep 30
    done

  echo ""
  echo "******************************"
  echo "Argo CD - Applications --all-namespaces: "
  echo ""
  kubectl get applications --all-namespaces 
  kubectl get applications --all-namespaces | grep ubi-helm
  
  echo ""
  echo "******************************"
  echo "Verify if a UBI pod exists: "    
  POD=$(kubectl get -n "${NS}" pods | grep "${COMPONENT_NAME}" | head -n 1 | awk '{print $1;}')    
  echo "Pod: ${POD}"
  if [[ ${POD} == "" ]] ; then
      echo "Error: No pod found for ${COMPONENT_NAME} in ${NS}"
      exit 1
  else 
      echo "Execute command in pod ${POD}" 
      RESULT_1=$(kubectl exec -n "${NS}" "${POD}" --container "${COMPONENT_NAME}" -- ls)
      RESULT_2=$(echo $RESULT_1 | grep bin)
      if [[ ${RESULT_2} == "bin" ]] ; then
         echo "Success UBI pod is running and accessable" 
      else
         echo "Error: UBI pod is running but to accessable" 
         exit 1
      fi
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

  echo "******************************"
  echo ""
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

  echo "******************************"
  echo ""
  echo "Done checking for resource: ${NS}/${GITOPS_TYPE}/${NAME}"
}
