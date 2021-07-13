#!/bin/bash

# Parameters
# -k, --keep-providers Keeping all provider connections that are not in Advanced Cluster Management namespaces.

TARGET_NAMESPACE=${TARGET_NAMESPACE:-open-cluster-management}

KEEP_PROVIDERS=0

# save args to pass to called scripts
args=("$@")

# Parse command line arguments
for arg in "$@"
do
    case $arg in
        -k|--keep-providers)
        KEEP_PROVIDERS=1
        shift
        ;;
        *)
        echo "Unrecognized argument: $1"
        shift
        ;;
    esac
done

# fix sed issue on mac
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
SED="sed"
if [ "${OS}" == "darwin" ]; then
    SED="gsed"
    if [ ! -x "$(command -v ${SED})"  ]; then
       echo "ERROR: $SED required, but not found."
       echo "Perform \"brew install gnu-sed\" and try again."
       exit 1
    fi
fi

# Make sure `oc login` has been done and `oc` command is working
echo "Testing connection"
oc version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 1
fi

VER=$(oc version | grep "Client Version:")

if ! [[ $VER =~ .*[4-9]\.[3-9]\..* ]]; then
    echo "oc cli version 4.3 or greater required. Please visit https://access.redhat.com/downloads/content/290/ver=4.3/rhel---8/4.3.9/x86_64/product-software."
    exit 1
fi

printf "\n"
echo "This script will uninstall Open Cluster Management from the current OpenShift target cluster in namespace ${TARGET_NAMESPACE}:"
printf "\n"
oc cluster-info | head -n 1 | awk '{print $NF}'
printf "\n"

./clean-clusters.sh "$args"

TMP_MCH_DIR="mch-uninstall-tmp"
if [[ -d ${TMP_MCH_DIR} ]]; then rm -rf ${TMP_MCH_DIR}; fi;
cp -r multiclusterhub ${TMP_MCH_DIR}
${SED} -i "s|__ANNOTATION__|{}|g" ./${TMP_MCH_DIR}/example-multiclusterhub-cr.yaml
kubectl delete -k ${TMP_MCH_DIR}/ -n ${TARGET_NAMESPACE}
rm -rf ${TMP_MCH_DIR}
echo "Sleeping for 200 seconds to allow resources to finalize ..."
sleep 200

kubectl delete -k multicluster-hub-operator/ -n ${TARGET_NAMESPACE}
./multicluster-hub-operator/uninstall.sh

kubectl delete -k acm-operator/ -n ${TARGET_NAMESPACE}
./acm-operator/uninstall.sh

kubectl delete -k community-subscriptions/ -n ${TARGET_NAMESPACE}

echo "Cleaning up the ${TARGET_NAMESPACE} namespace.."
oc delete namespace ${TARGET_NAMESPACE}

exit 0
