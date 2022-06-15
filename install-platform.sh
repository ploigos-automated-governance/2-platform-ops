#!/bin/bash
set -eu -o pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

VERBOSE=false # Set to "true" to have this script output debug information including the commands it is running.
SONARQUBE_STORAGE_DESIRED=100Gi
MAX_RETRIES=30
RETRY_WAIT=30

if [ "${VERBOSE}" ]; then set +x; fi

# Create the k8s resources. Try until they are all created successfully (CRDs may take time to exist, etc.)
STATUS=1
i=0
while [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; do
    ((i=i+1))
    set +e
    oc apply -k ${SCRIPT_DIR}/components/
    STATUS=$?
    set -e
    if [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; then
        echo "Waiting for resource dependencies to be created. Attempting to create remaining resources in ${RETRY_WAIT} seconds. Retry ${i} of ${MAX_RETRIES}."
        sleep ${RETRY_WAIT}
    fi
done
if [ "${STATUS}" != 0 ]; then
    echo "Resource creation failed! Check output for errors."
    exit 1
fi

# Delete LimitRanges for created namespaces if they exist
oc delete limitrange --all -n devsecops
oc delete limitrange --all -n sigstore

# Increase size of SonarQube PVC if needed. Requires restarting the sonarqube pod.
echo "Setting SonarQube PVC Size"
echo "... Waiting for PVC to be created"
STATUS=1
i=0
SONARQUBE_PVC_NAME=nexus-sonatype-nexus-data
while [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; do
  ((i=i+1))
  set +e
  oc get pvc "${SONARQUBE_PVC_NAME}" -n devsecops -o name
  STATUS=$?
  set -e
  if [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; then
      echo "... Waiting for SonarQube PVC to be created. Checking again in ${RETRY_WAIT} seconds. Retry ${i} of ${MAX_RETRIES}."
      sleep ${RETRY_WAIT}
  fi
done
SONARQUBE_STORAGE=$(oc get pvc ${SONARQUBE_PVC_NAME} -n devsecops -o yaml | yq .spec.resources.requests.storage)
if [ ${SONARQUBE_STORAGE} != ${SONARQUBE_STORAGE_DESIRED} ]; then
    echo "... Updating pvc size to ${SONARQUBE_STORAGE_DESIRED}"
    sleep 10 # Apparently this fails if you do it immediately after resource creation
    oc patch pvc nexus-sonatype-nexus-data -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}' -n devsecops
    echo "... Restarting sonarqube Pod"
    oc delete po -l app=sonatype-nexus -n devsecops
    echo "Sonarqube PVC Resized to ${SONARQUBE_STORAGE_DESIRED}"
else
  echo "SonarQube PVC is already sized correctly"
fi

echo "Waiting for Gitea route to be created"
STATUS=1
i=0
GITEA_ROUTE_NAME=gitea
while [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; do
  ((i=i+1))
  set +e
  oc get route "${GITEA_ROUTE_NAME}" -n devsecops -o name
  STATUS=$?
  set -e
  if [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; then
      echo "... Waiting for Gitea Route to be created. Checking again in ${RETRY_WAIT} seconds. Retry ${i} of ${MAX_RETRIES}."
      sleep ${RETRY_WAIT}
  fi
done

echo "Installation Successful!"
