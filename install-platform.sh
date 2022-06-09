#!/bin/bash
set -eux -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Script configuration
SONARQUBE_STORAGE_DESIRED=100Gi
MAX_RETRIES=10
RETRY_WAIT=30

# Create the k8s resources. Try until they are all created succesfully (CRDs may take time to exist, etc.)
STATUS=1
i=0
while [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; do
    ((i=i+1))
    echo $i
    set +e
    oc apply -k ${SCRIPT_DIR}/components/
    STATUS=$?
    set -e
    if [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; then
        echo Not all resources were created. Waiting ${RETRY_WAIT} seconds for CRDs dependencies be created. Retry #${i} of ${MAX_RETRIES}.
        sleep ${RETRY_WAIT}
    fi
done
if [ "${STATUS}" != 0 ]; then
    echo "Resource creation failed! Check output for errors."
    exit 1
fi

# Increase size of SonarQube PVC if needed. Requires restarting the sonarqube pod.
SONARQUBE_STORAGE=$(oc get pvc nexus-sonatype-nexus-data -o yaml | yq .spec.resources.requests.storage)
if [ ${SONARQUBE_STORAGE} != ${SONARQUBE_STORAGE_DESIRED} ]; then
    oc patch pvc nexus-sonatype-nexus-data -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}' -n devsecops
    oc delete po -l app=sonatype-nexus -n devsecops
fi

echo "INSTALL SUCCESSFUL"

