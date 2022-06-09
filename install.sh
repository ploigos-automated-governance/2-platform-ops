#!/bin/bash
set -ux -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Create the k8s resources. Try until they are all created succesfully (CRDs may take time to exist, etc.)
STATUS=1
i=0
MAX_RETRIES=3
RETRY_WAIT=10
while [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; do
    ((i=i+1))
    echo $i
    oc apply -k ${SCRIPT_DIR}/components/
    STATUS=$?
    if [ "${STATUS}" != 0 ] && [ $i -lt "${MAX_RETRIES}" ]; then
        echo Not all resources were created. Waiting ${RETRY_WAIT} seconds for CRDs dependencies be created. ${i} retries left.
        sleep ${RETRY_WAIT}
    fi
done

if [ "${STATUS}" == 0 ]; then
    echo "INSTALL SUCCESSFUL"
else
    echo "INSTALL FAILED! Check output for errors."
    exit 1
fi

