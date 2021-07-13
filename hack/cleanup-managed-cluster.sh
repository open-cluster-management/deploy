#!/bin/bash
###############################################################################
# Copyright (c) 2020 Red Hat, Inc.
###############################################################################

if [ -z "${OPERATOR_NAMESPACE}" ]; then
	OPERATOR_NAMESPACE="open-cluster-management-agent-addon"
fi

if [ -z "${KLUSTERLET_NAMESPACE}" ]; then
	KLUSTERLET_NAMESPACE="open-cluster-management-agent"
fi

KUBECTL=oc

# Force delete klusterlet
echo "attempt to delete klusterlet"
${KUBECTL} delete klusterlet klusterlet --timeout=60s
${KUBECTL} delete namespace ${KLUSTERLET_NAMESPACE} --wait=false
echo "force removing klusterlet"
${KUBECTL} patch klusterlet klusterlet --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
echo "removing klusterlet crd"
${KUBECTL} delete crd klusterlets.operator.open-cluster-management.io --timeout=30s

# Force delete all component CRDs if they still exist
component_crds=(
	applicationmanagers.agent.open-cluster-management.io
	certpolicycontrollers.agent.open-cluster-management.io
	iampolicycontrollers.agent.open-cluster-management.io
	policycontrollers.agent.open-cluster-management.io
	searchcollectors.agent.open-cluster-management.io
	workmanagers.agent.open-cluster-management.io
	appliedmanifestworks.work.open-cluster-management.io
	klusterlets.operator.open-cluster-management.io
)

for crd in "${component_crds[@]}"; do
	echo "force delete all CustomResourceDefinition ${crd} resources..."
	for resource in `${KUBECTL} get ${crd} -o name -n ${OPERATOR_NAMESPACE}`; do
		echo "attempt to delete ${crd} resource ${resource}..."
		${KUBECTL} delete ${resource} -n ${OPERATOR_NAMESPACE} --timeout=30s
		echo "force remove ${crd} resource ${resource}..."
		${KUBECTL} patch ${resource} -n ${OPERATOR_NAMESPACE} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
	done
	echo "force delete all CustomResourceDefinition ${crd} resources..."
	${KUBECTL} delete crd ${crd}
done

${KUBECTL} delete namespace ${OPERATOR_NAMESPACE}
