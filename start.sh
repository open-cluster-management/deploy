#!/bin/bash

# Copyright 2020, 2021 Red Hat Inc.

#Command Line param's
# ./start.sh -t, this exits after modifying the files but not apply any of the yaml
# ./start.sh --silent, this skips any questions, using the local files to apply the snapshot and secret
# ./start.sh --watch, this monitors for status during the main deploy of Red Hat ACM

# CONSTANTS
TOTAL_POD_COUNT_1X=35
TOTAL_POD_COUNT_2X=55
POLL_DURATION_21X=1500

# Global Variables with Defaults
TARGET_NAMESPACE=${TARGET_NAMESPACE:-"open-cluster-management"}
COMPOSITE_BUNDLE=${COMPOSITE_BUNDLE:-"true"}
DOWNSTREAM=${DOWNSTREAM:-"false"}
CUSTOM_REGISTRY_REPO=${CUSTOM_REGISTRY_REPO:-"quay.io/open-cluster-management"}
QUAY_TOKEN=${QUAY_TOKEN:-"UNSET"}
MODE=${MODE:-"Automatic"}
STARTING_VERSION=${STARTING_VERSION:-"2.1.0"}

# build starting csv variable from $STARTING_VERSION
STARTING_CSV="advanced-cluster-management.v${STARTING_VERSION}"
function waitForInstallPlan() {
    version=$1
    for i in `seq 1 10`; do
        oc get installplan -n ${TARGET_NAMESPACE} | grep "$version"
        if [ $? -eq 0 ]; then
          break
        fi
        echo 'waiting for installplan to show'
        sleep 10
    done
}

function waitForPod() {
    FOUND=1
    MINUTE=0
    podName=$1
    ignore=$2
    running="\([0-9]\+\)\/\1"
    printf "\n#####\nWait for ${podName} to reach running state (4min).\n"
    while [ ${FOUND} -eq 1 ]; do
        # Wait up to 4min, should only take about 20-30s
        if [ $MINUTE -gt 240 ]; then
            echo "Timeout waiting for the ${podName}. Try cleaning up using the uninstall scripts before running again."
            echo "List of current pods:"
            oc -n ${TARGET_NAMESPACE} get pods
            echo
            echo "You should see ${podName}, multiclusterhub-repo, and multicloud-operators-subscription pods"
            exit 1
        fi
        if [ "$ignore" == "" ]; then
            operatorPod=`oc -n ${TARGET_NAMESPACE} get pods | grep ${podName}`
        else
            operatorPod=`oc -n ${TARGET_NAMESPACE} get pods | grep ${podName} | grep -v ${ignore}`
        fi
        if [[ $(echo $operatorPod | grep "${running}") ]]; then
            echo "* ${podName} is running"
            break
        elif [ "$operatorPod" == "" ]; then
            operatorPod="Waiting"
        fi
        echo "* STATUS: $operatorPod"
        sleep 3
        (( MINUTE = MINUTE + 3 ))
    done
}

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

# if using --watch option on mac make sure watch is installed
if [[ " $@ " =~ " --watch " ]]; then
    if [ ! -x "$(command -v watch)" ]; then
        echo "ERROR: watch required, but not found."
        if [ "${OS}" == "darwin" ]; then
            echo "Perform \"brew install watch\" and try again."
        fi
        exit 1
    fi
fi

#This is needed for the deploy
echo "* Testing connection"
HOST_URL=`oc -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'`
if [ $? -ne 0 ]; then
    echo "ERROR: Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 2
fi
#Shorten to the basedomain
HOST_URL=${HOST_URL/apps./}
echo "* Using baseDomain: ${HOST_URL}"
VER=`oc version | grep "Client Version:"`
echo "* oc CLI ${VER}"

if ! [[ $VER =~ .*[4-9]\.[3-9]\..* ]]; then
    echo "oc cli version 4.3 or greater required. Please visit https://access.redhat.com/downloads/content/290/ver=4.3/rhel---8/4.3.9/x86_64/product-software."
    exit 1
fi

if [ ! -f ./prereqs/pull-secret.yaml ]; then
    echo "SECURITY NOTICE: The encrypted dockerconfigjson is stored in ./prereqs/pull-secret.yaml. If you want to change the value, delete the file and run start.sh"
    if [[ "$QUAY_TOKEN" == "UNSET" ]]; then
        echo "Enter the encrypted .dockerconfigjson"
        read -r QUAY_TOKEN
    fi
    echo "Writing .prereqs/pull-secret.yaml"
cat <<EOF > ./prereqs/pull-secret.yaml
apiVersion: v1
data:
  .dockerconfigjson: ${QUAY_TOKEN}
kind: Secret
metadata:
  name: multiclusterhub-operator-pull-secret
type: kubernetes.io/dockerconfigjson
EOF

fi

DEFAULT_SNAPSHOT="MUST_PROVIDE_SNAPSHOT"
if [ -f ./snapshot.ver ]; then
    DEFAULT_SNAPSHOT=`cat ./snapshot.ver`
elif [[ " $@ " =~ " --silent " ]]; then
    echo "ERROR: Silent mode will not work when ./snapshot.ver is missing"
    exit 1
fi

if [[ " $@ " =~ " --silent " ]]; then
    echo "* Silent mode"
else
    printf "Find snapshot tags @ https://quay.io/repository/open-cluster-management/acm-custom-registry?tab=tags\nEnter SNAPSHOT TAG: (Press ENTER for default: ${DEFAULT_SNAPSHOT})\n"
    read -r SNAPSHOT_CHOICE
    if [ "${SNAPSHOT_CHOICE}" != "" ]; then
        DEFAULT_SNAPSHOT=${SNAPSHOT_CHOICE}
        printf "${DEFAULT_SNAPSHOT}" > ./snapshot.ver
    fi
fi
if [ "${DEFAULT_SNAPSHOT}" == "MUST_PROVIDE_SNAPSHOT" ]; then
    echo "ERROR: Please specify a valid snapshot tag to continue."
    exit 2
fi
SNAPSHOT_PREFIX=${DEFAULT_SNAPSHOT%%\-*}

# If the user sets the COMPOSITE_BUNDLE flag to "true", then set to the `acm` variants of variables, otherwise the multicluster-hub version.  
if [[ "$COMPOSITE_BUNDLE" == "true" ]]; then OPERATOR_DIRECTORY="acm-operator"; else OPERATOR_DIRECTORY="multicluster-hub-operator"; fi;
if [[ "$COMPOSITE_BUNDLE" == "true" ]]; then CUSTOM_REGISTRY_IMAGE="acm-custom-registry"; else CUSTOM_REGISTRY_IMAGE="multicluster-hub-custom-registry"; fi;

# Set the subscription channel if the variable wasn't defined as input, defaulted to snapshot-<release-version>
if [ -z "$SUBSCRIPTION_CHANNEL" ]; then
    SUBSCRIPTION_CHANNEL_VERSION=$(echo ${SNAPSHOT_PREFIX} | ${SED} -nr "s/v{0,1}([0-9]+\.[0-9]+)\.{0,1}[0-9]*.*/\1/p")
    if [[ "$COMPOSITE_BUNDLE" == "true" ]]; then 
        SUBSCRIPTION_CHANNEL_PREFIX="release"; 
    else 
        SUBSCRIPTION_CHANNEL_PREFIX="snapshot";
    fi;

    SUBSCRIPTION_CHANNEL="${SUBSCRIPTION_CHANNEL_PREFIX}-${SUBSCRIPTION_CHANNEL_VERSION}"

    if [[ ! ( $SUBSCRIPTION_CHANNEL_VERSION =~ [0-9]+\.[0-9]+ ) ]]; then
        echo "Failed to detect SUBSCRIPTION_CHANNEL, we detected ${SUBSCRIPTION_CHANNEL} which doesn't seem correct.  Try exporting SUBSCRIPTION_CHANNEL and rerunning."
        exit 1
    fi
fi

echo "* Downstream: ${DOWNSTREAM}   Release Version: $SNAPSHOT_PREFIX"
echo "* Composite Bundle: $COMPOSITE_BUNDLE   Image Registry (CUSTOM_REGISTRY_REPO): $CUSTOM_REGISTRY_REPO"
if [[ (! $SNAPSHOT_PREFIX == *.*.*) && ("$DOWNSTREAM" != "true") ]]; then
    echo "ERROR: invalid SNAPSHOT format... snapshot must begin with 'X.0.0-' not '$SNAPSHOT_PREFIX', if DOWNSTREAM isn't set"
    exit 1
fi

# Change our expected pod count based on what version snapshot we detect, defaulting to 1.0 (smallest number of pods as of writing)
if [[ $DEFAULT_SNAPSHOT == 1.0* ]]; then
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_1X}
elif [[ $DEFAULT_SNAPSHOT =~ v{0,1}2\.[0-9]+\.[0-9]+.* ]]; then
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_2X}
else
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_1X}
    echo "Snapshot doesn't contain a version number we recognize, looking for the 1.X release pod count of ${TOTAL_POD_COUNT} if wait is selected."
fi

printf "* Using: ${DEFAULT_SNAPSHOT}\n\n"

echo "* Applying SNAPSHOT to multiclusterhub-operator subscription"
${SED} -i "s/newTag: .*$/newTag: ${DEFAULT_SNAPSHOT}/g" ./$OPERATOR_DIRECTORY/kustomization.yaml
echo "* Applying CUSTOM_REGISTRY_REPO to multiclusterhub-operator subscription"
${SED} -i "s|newName: .*$|newName: ${CUSTOM_REGISTRY_REPO}/${CUSTOM_REGISTRY_IMAGE}|g" ./$OPERATOR_DIRECTORY/kustomization.yaml
echo "* Applying SUBSCRIPTION_CHANNEL to multiclusterhub-operator subscription"
${SED} -i "s|channel: .*$|channel: ${SUBSCRIPTION_CHANNEL}|g" ./$OPERATOR_DIRECTORY/subscription.yaml
echo "* Applying MODE to multiclusterhub-operator subscription"
${SED} -i "s|installPlanApproval: .*$|installPlanApproval: ${MODE}|g" ./$OPERATOR_DIRECTORY/subscription.yaml
if [[ "$MODE" == "Automatic" ]]; then
    # Issue 7436 - If Downstream RC snapshot, remove leading 'v' from prefix name
    CLEAN_RC_PREFIX=$(echo ${SNAPSHOT_PREFIX} | ${SED} 's/v//')
    STARTING_CSV="advanced-cluster-management.v${CLEAN_RC_PREFIX}"
    echo "* Applying STARTING_CSV to multiclusterhub-operator-subscription ($STARTING_CSV)"
    ${SED} -i "s|startingCSV: .*$|startingCSV: ${STARTING_CSV}|g" ./$OPERATOR_DIRECTORY/subscription.yaml
elif [[ "$MODE" == "Manual" ]]; then
    echo "* Applying STARTING_CSV to multiclusterhub-operator subscription ($STARTING_CSV)"
    ${SED} -i "s|startingCSV: .*$|startingCSV: ${STARTING_CSV}|g" ./$OPERATOR_DIRECTORY/subscription.yaml
    CHANNEL_VERSION=$(echo ${STARTING_VERSION} | ${SED} -nr "s/v{0,1}([0-9]+\.[0-9]+)\.{0,1}[0-9]*.*/\1/p")
    echo "* Applying channel 'release-${CHANNEL_VERSION}' to multiclusterhub-operator subscription"
    ${SED} -i "s|channel: .*$|channel: release-${CHANNEL_VERSION}|g" ./$OPERATOR_DIRECTORY/subscription.yaml
else
    echo "* Invalid MODE... Must be one of Automatic|Manual but found ${MODE}."
    exit -1
fi
echo "* Applying multicluster-hub-cr values"
${SED} -i "s/example-multiclusterhub/multiclusterhub/" ./multiclusterhub/example-multiclusterhub-cr.yaml
if [[ -d applied-mch ]]; then rm -rf applied-mch; fi;
cp -r multiclusterhub applied-mch
if [[ "$DOWNSTREAM" != "true" ]]; then
    ${SED} -i "s|__ANNOTATION__|{}|g" ./applied-mch/example-multiclusterhub-cr.yaml
else
    ${SED} -i "s|__ANNOTATION__|\n    \"mch-imageRepository\": \"${CUSTOM_REGISTRY_REPO}\"|g" ./applied-mch/example-multiclusterhub-cr.yaml
fi

if [[ " $@ " =~ " -t " ]]; then
    echo "* Test mode, see yaml files for updates"
    exit 0
fi

printf "\n##### Creating the $TARGET_NAMESPACE namespace\n"
kubectl create ns $TARGET_NAMESPACE

seconds=0
while [ -z $(kubectl get sa -n $TARGET_NAMESPACE -o name default) ]; do
    echo "--- waiting for namespace: $TARGET_NAMESPACE to create with default service account ---"
    sleep 10
    (( seconds=seconds+10 ))
    if [ "$seconds" -gt 60 ]; then
        echo "--- waited 60 seconds for namespace: $TARGET_NAMESPACE but it never came up with default service account, exiting ---"
        exit 1;
    fi
done;

if [[ "$COMPOSITE_BUNDLE" != "true" ]]; then
    printf "\n##### Applying community operator subscriptions\n"
    oc apply -k community-subscriptions/ -n ${TARGET_NAMESPACE}
fi

printf "\n##### Applying prerequisites\n"
kubectl apply --openapi-patch=true -k prereqs/ -n ${TARGET_NAMESPACE}

printf "\n##### Allow secrets time to propagate #####\n"
sleep 60

printf "\n##### Applying $OPERATOR_DIRECTORY subscription #####\n"
if [[ "${TARGET_NAMESPACE}" != "open-cluster-management" ]]; then
    TMP_OP_DIR="operator_tmp"
    printf "* Creating temporary directory ${TMP_OP_DIR}/ to customize namespace\n"
    if [[ -d ${TMP_OP_DIR}/ ]]; then rm -rf ${TMP_OP_DIR}/; fi;
    mkdir ${TMP_OP_DIR}/
    cp ${OPERATOR_DIRECTORY}/*.yaml ${TMP_OP_DIR}/
    ${SED} -i "s/\.open-cluster-management\./.${TARGET_NAMESPACE}./" ${TMP_OP_DIR}/catalog-source.yaml
    ${SED} -i "s/^  - open-cluster-management$/  - ${TARGET_NAMESPACE}/" ${TMP_OP_DIR}/operator-group.yaml
    ${SED} -i "s/^  sourceNamespace: open-cluster-management$/  sourceNamespace: ${TARGET_NAMESPACE}/" ${TMP_OP_DIR}/subscription.yaml
    kubectl apply -k $TMP_OP_DIR/ -n ${TARGET_NAMESPACE}
    printf "* Removing temporary directory ${TMP_OP_DIR}/\n"
    rm -rf ${TMP_OP_DIR}/
else
    kubectl apply -k $OPERATOR_DIRECTORY/ -n ${TARGET_NAMESPACE}
fi

if [[ "$MODE" == "Manual" ]]; then
    # wait for install plan to be available
    waitForInstallPlan ${STARTING_CSV}

    # identify plan and approve it
    INSTALL_PLAN=$(oc get InstallPlan -n ${TARGET_NAMESPACE} | grep ${STARTING_CSV} | awk '{print $1;}')
    oc patch InstallPlan $INSTALL_PLAN -n ${TARGET_NAMESPACE} --type "json" -p '[{"op":"replace","path":"/spec/approved","value":true}]'
fi

waitForPod "multiclusterhub-operator" "${CUSTOM_REGISTRY_IMAGE}"
printf "\n* Beginning deploy...\n"


echo "* Applying the multiclusterhub-operator to install Red Hat Advanced Cluster Management for Kubernetes"
kubectl apply -k applied-mch -n ${TARGET_NAMESPACE}
waitForPod "multicluster-operators-application" ""

COMPLETE=1
if [[ " $@ " =~ " --watch " ]]; then
    if [[ $DEFAULT_SNAPSHOT =~ v{0,1}2\.[1-9][0-9]*\.[0-9]+.* ]]; then
        echo ""
        echo "#####"
        mch_status=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.phase') 2> /dev/null
        acc=0
        while [[ "$mch_status" != "Running" && $acc -le $POLL_DURATION_21X ]]; do
            echo "Waited $acc/$POLL_DURATION_21X seconds for MCH to reach Ready Status.  Current Status: $mch_status"
            CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
            if [[ "$CONSOLE_URL" != "" ]]; then
                echo "Detected ACM Console URL: https://${CONSOLE_URL}"
            fi;
            if [[ "$DEBUG" == "true" ]]; then
                echo "#####"
                component_list=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.components')
                printf "%-30s\t%-10s\t%-30s\t%-30s\n" "COMPONENT" "STATUS" "TYPE" "REASON"
                for status_item in $(echo $component_list | jq -r 'keys | .[]'); do
                    component=$(echo $component_list | jq -r --arg ITEM_NAME "$status_item" '.[$ITEM_NAME]')
                    component_status="$(echo $component | jq -r '.status')";
                    type="$(echo $component | jq -r '.type')";
                    reason="$(echo $component | jq -r '.reason')";
                    message="$(echo $component | jq -r '.message')";
                    printf "%-30s\t%-10s\t%-30s\t%-30s\n" "$status_item" "$component_status" "$type" "$reason"
                done
            fi
            echo ""
            acc=$((acc+30))
            sleep 30
            mch_status=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.phase') 2> /dev/null
        done;
        if [[ "$mch_status" != "Running" ]]; then
            COMPLETE=1
        else
            COMPLETE=0
            echo "MCH reached Running status after $acc seconds."
            CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
            if [[ "$CONSOLE_URL" != "" ]]; then
                echo "Detected ACM Console URL: https://${CONSOLE_URL}"
            fi;
            echo ""
        fi
    else
        for i in {1..90}; do
            clear
            oc -n ${TARGET_NAMESPACE} get pods
            CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
            whatsLeft=`oc -n ${TARGET_NAMESPACE} get pods | grep -v -e "Completed" -e "1/1     Running" -e "2/2     Running" -e "3/3     Running" -e "4/4     Running" -e "READY   STATUS" | wc -l`
            RUNNING_PODS=$(oc -n ${TARGET_NAMESPACE} get pods | grep -v -e "Completed" | tail -n +2 | wc -l | tr -d '[:space:]')
            if [ "https://$CONSOLE_URL" == "https://multicloud-console.apps.${HOST_URL}" ] && [ ${whatsLeft} -eq 0 ]; then
                if [ $RUNNING_PODS -ge ${TOTAL_POD_COUNT} ]; then
                    COMPLETE=0
                    break
                fi
            fi
            echo
            echo "Number of expected Pods : $RUNNING_PODS/$TOTAL_POD_COUNT"
            echo "Pods still NOT running  : ${whatsLeft}"
            echo "Detected ACM Console URL: https://${CONSOLE_URL}"
            sleep 10
        done
    fi
    if [ $COMPLETE -eq 1 ]; then
        if [[ $DEFAULT_SNAPSHOT =~ v{0,1}2\.[1-9][0-9]*\.[0-9]+.* ]]; then
            mch_status=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.phase')
            echo "MCH is in the following state: $mch_status"
            echo "The full MCH status is as follows:"
            component_list=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.components')
            printf "%-30s\t%-10s\t%-30s\t%-30s\n" "COMPONENT" "STATUS" "TYPE" "REASON"
            for status_item in $(echo $component_list | jq -r 'keys | .[]'); do
                component=$(echo $component_list | jq -r --arg ITEM_NAME "$status_item" '.[$ITEM_NAME]')
                component_status="$(echo $component | jq -r '.status')";
                type="$(echo $component | jq -r '.type')";
                reason="$(echo $component | jq -r '.reason')";
                message="$(echo $component | jq -r '.message')";
                printf "%-30s\t%-10s\t%-30s\t%-30s\n" "$status_item" "$component_status" "$type" "$reason"
            done
            echo ""
        else
            echo "At least one pod failed to start..."
            oc -n ${TARGET_NAMESPACE} get pods | grep -v -e "Completed" -e "1/1     Running" -e "2/2     Running" -e "3/3     Running" -e "4/4     Running"
        fi
        exit 1
    else
        echo "#####"
        echo "* Red Hat ACM URL: https://$CONSOLE_URL"
        echo "#####"
    fi
    echo "Done!"
    exit $COMPLETE
fi

# if using --search option make sure we install redis graph
if [[ " $@ " =~ " --search " ]]; then
    oc set env deploy search-operator DEPLOY_REDISGRAPH="true" -n ${TARGET_NAMESPACE}
fi

echo "#####"
echo "* Red Hat ACM URL: https://multicloud-console.apps.${HOST_URL}"
echo "#####"
if [ "${OS}" == "darwin" ]; then
    if [ ! -x "$(command -v watch)" ]; then
       echo "NOTE: watch executable not found.  Perform \"brew install watch\" to use the command above or use \"./start.sh --watch\" "
    fi
else
  echo "Deploying, for 2.1+ releases monitor monitor the status of the multiclusterhub created in the ${TARGET_NAMESPACE} namespace, for 2.0 releases use \"watch oc -n ${TARGET_NAMESPACE} get pods\" to monitor progress. Expect around ${TOTAL_POD_COUNT} pods."
fi

