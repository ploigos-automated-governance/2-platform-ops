#!/bin/bash
set -eu -o pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

VERBOSE=false # Set to "true" to have this script output debug information including the commands it is running.
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

# Delete LimitRanges for created namespaces if they exist
echo "Deleting LimitRanges"
oc delete limitrange --all -n devsecops
oc delete limitrange --all -n sigstore

echo "Installation Successful!"

