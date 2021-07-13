
# Deploy the _open-cluster-management_ project

### Welcome!

You might be asking yourself, "What is Open Cluster Management?", well it is the _open-cluster-management_ project. View the _open-cluster-management_ architecture diagram:

![Architecture diagram](images/arch.jpg)

>The GitHub org and project are currently distinct from the SaaS offering named "Red Hat OpenShift Cluster Manager" but will ultimately co-exist/share technology as needed. Core technology, such as [Hive](https://github.com/openshift/hive) is already shared between the two offerings.

Kubernetes provides a platform to deploy and manage containers in a standard, consistent control plane. However, as application workloads move from development to production, they often require multiple fit-for-purpose Kubernetes clusters to support DevOps pipelines. Users such as administrators and site reliability engineers (SREs), face challenges as they work across a range of environments, including multiple data centers, private clouds, and public clouds that run Kubernetes clusters. The _open-cluster-management_ project provides the tools and capabilities to address these common challenges.

_open-cluster-management_ provides end-to-end visibility and control to manage your Kubernetes environment. Take control of your application modernization program with management capabilities for cluster creation, application lifecycle, and provide security and compliance for all of them across data centers and hybrid cloud environments. Clusters and applications are all visible and managed from a single console with built-in security policies. Run your operations where Red Hat OpenShift runs, and manage any Kubernetes cluster in your fleet.

With the _open-cluster-management_ project, you can complete the following functionality tasks:

  - Work across a range of environments, including multiple data centers, private clouds and public clouds that run Kubernetes clusters.
  - Easily create Kubernetes clusters and offer cluster lifecycle management in a single console.
  - Enforce policies at the target clusters using Kubernetes-supported custom resource definitions.
  - Deploy and maintain day-two operations of business applications distributed across your cluster landscape.

## Let's get started...

You can find our _work-in-progress_ documentation [here](https://github.com/open-cluster-management/rhacm-docs/blob/2.0_stage/README.md). Please read through the docs to find out how you can use the _open-cluster-management_ project. Submit an issue for any problems you may find, or clarifications you might suggest by [opening an issue](https://github.com/open-cluster-management/rhacm-docs/issues/new).

You can find information on how to contribute to this project and our docs project in our [CONTRIBUTING.md](CONTRIBUTING.md) doc.

#### Prereqs

You must meet the following requirements to install the _open-cluster-management_ project:

- An OpenShift Container Platform (OCP) 4.3+ cluster available
  - You must have a default storage class defined
- `oc` (ver. 4.3+) & `kubectl` (ver. 1.16+) configured to connect to your OCP cluster
- `oc` is connected with adequate permissions to create new namespaces in your OCP cluster.
- The following utilities **required**:
  - `sed`
    - On **macOS** install using: `brew install gnu-sed`
  - `jq`
    - On **macOS** install using: `brew install jq`
- The following utilities are **optional**:
  - `watch`
    - On **macOS** install using: `brew install watch`

#### Repo Structure and Organization
This repo contains the 3 directories:
  - `prereqs` - YAML definitions for prerequisite objects (namespaces and pull-secrets)
  - `acm-operator` - YAML definitions for setting up a `CatalogSource` for our operator
  - `multiclusterhub` -  YAML definitions for creating an instance of `MultiClusterHub`

Each of the three directories contains a `kustomization.yaml` file that will apply the YAML definitions to your OCP instance with the following command: `kubectl apply -k`.

There are __helper__ scripts in the root of this repo:
  - `start.sh` - takes the edge off having to manually edit YAML files
  - `uninstall.sh` - we're not perfect yet; includes additional scripting to ensure we clean up our mess on your OCP cluster.

You have two choices of installation:
  - [the easy way](#deploy-using-the-startsh-script-the-easy-way) - using the provided `start.sh` script which will assist you through the process.
  - [the hard way](#the-hard-way) - instructions to deploy _open-cluster-management_ with only `oc` commands.

Either way you choose to go, you are going to need a `pull-secret`. We are still in early development stage, and yes we do plan to open source all of our code but... lawyers, gotta do some more due diligence before we can open up to the world. <!--do we want to share info about the lawyer responsibility or was this a personal quick note?--> In the mean time, you must gain access to our built images residing in our private [Quay environment](https://quay.io/open-cluster-management). Please follow the instructions [Prepare to deploy Open Cluster Management Instance](#prepare-to-deploy-open-cluster-management-instance-only-do-once) to get your `pull-secret` setup.

## Prepare to deploy Open Cluster Management Instance (only do once)

1. Clone this repo locally
    ```bash
    git clone https://github.com/open-cluster-management/deploy.git
    ```

2. Generate your pull-secret:
   - ensure you have access to the quay org ([open-cluster-management](https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags))
     - to request access to [open-cluster-management](https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags) in quay.io please contact the ACM CICD team via email at [acm-contact@redhat.com](mailto:acm-contact@redhat.com) or, if you have access to Red Hat CoreOS Slack you can contact us on our Slack Channel [#forum-acm-devops](https://coreos.slack.com/archives/CSZLMKPS5)).
   - go to [https://quay.io/user/tpouyer?tab=settings](https://quay.io/user/tpouyer?tab=settings) replacing `tpouyer` with your username
   - click on `Generate Encrypted Password`
   - enter your quay.io password
   - select `Kubernetes Secret` from left-hand menu
   - click on `Download tpouyer-secret.yaml` except `tpouyer` will be your username
   - :exclamation: **save secret file in the `prereqs` directory as `pull-secret.yaml`**
   - :exclamation: **edit `pull-secret.yaml` file and change the name to `multiclusterhub-operator-pull-secret`**
      ```bash
      apiVersion: v1
      kind: Secret
      metadata:
        name: multiclusterhub-operator-pull-secret
      ...
      ```

## Deploy using the ./start.sh script (the easy way)

We've added a very simple `start.sh` script to make your life easier.

First, you need to `export KUBECONFIG=/path/to/some/cluster/kubeconfig` (or do an `oc login` that will set it for you), `deploy` will install to the cluster pointed to by the current KUBECONFIG!

_Optionally_ `export DEBUG=true` for additional debugging output for 2.1+ releases.

### Running start.sh

1. Run the `start.sh` script. You have the following options (use one at a time) when you run the command:

```
-t modify the YAML but exit before apply the resources
--silent, skip all prompting, uses the previous configuration
--watch, will monitor the main Red Hat ACM pod deployments for up to 10min
--search, will activate search as part of the deployment.

$ ./start.sh --watch --search
```

2. When prompted for the SNAPSHOT tag, either press `Enter` to use the previous tag, or provide a new SNAPSHOT tag.
    - UPSTREAM snapshot tags - https://quay.io/repository/open-cluster-management/acm-custom-registry?tab=tags
    - DOWNSTREAM snapshot tag - https://quay.io/repository/acm-d/acm-custom-registry?tab=tags

  For example, your SNAPSHOT tag might resemble the following information:
  ```bash
2.0.5-SNAPSHOT-2020-10-26-21-38-29
  ```
  NOTE: To change the default SNAPSHOT tag, edit `snapshot.ver`, which contains a single line that specifies the SNAPSHOT tag.  This method of updating the default SNAPSHOT tag is useful when using the `--silent` option.
2. Depending on your script Option choice, `open-cluster-management` will be deployed or deploying. For 2.0 releases of open-cluster-management and below, use 'watch oc -n open-cluster-management get pods' to view the progress.  For 2.1+ releases of open-cluster-management, you can monitor the status fields of the multiclusterhub object created in the `open-cluster-management` namespace (namespace will differ if TARGET_NAMESPACE is set).

3. The script provides you with the `Open Cluster Management` URL.

Note: This script can be run multiple times and will attempt to continue where it left off. It is also good practice to run the `uninstall.sh` script if you have a failure and have installed multiple times.


## Deploying Downstream Builds SNAPSHOTS for Product Quality Engineering

To deploy a downstream build from `quay.io/acm-d`, you need to `export COMPOSITE_BUNDLE=true` and ensure that your OCP cluster meets two conditions:
1. The cluster must have an ImageContentSourcePolicy as follows (**Caution**: if you modify this on a running cluster, it will cause a rolling restart of all nodes).  To apply the ImageContentSourcePolicy, run `oc apply -f icsp.yaml` with `icsp.yaml` containing the following:

**2.0+**
```
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: rhacm-repo
spec:
  repositoryDigestMirrors:
  - mirrors:
    - quay.io:443/acm-d
    source: registry.redhat.io/rhacm2
  - mirrors:
    - registry.redhat.io/openshift4/ose-oauth-proxy
    source: registry.access.redhat.com/openshift4/ose-oauth-proxy
```

2. Ensure that the main pull secret for your OpenShift cluster has pull access to `quay.io/acm-d` in an entry for `quay.io:443`.  Your main pull secret should look something like this (**Caution**: if you apply this on a pre-existing cluster, it will cause a rolling restart of all nodes).  You have to edit the pull secret to include the section detailed below via the oc cli: `oc edit secret/pull-secret -n openshift-config`, OpenShift console, or [bootstrap repo](https://github.com/open-cluster-management/bootstrap#how-to-use) at cluster create time:
    <pre>
    {
      "auths": {
        <b>"quay.io": {
          "auth": "ENCODED SECRET",
          "email": ""
        }</b>
      }
    }
    </pre>
    Your final `OPENSHIFT_INSTALL_PULL_SECRET` should look like (bolded part is what you should add, also pretty printed):
    <pre>
    {
      "auths": {
        "cloud.openshift.com": {
          "auth": "ENCODED SECRET",
          "email": "email@address.com"
        },
        "quay.io": {
          "auth": "ENCODED SECRET",
          "email": "email@address.com"
        },
        "registry.connect.redhat.com": {
          "auth": "ENCODED SECRET",
          "email": "email@address.com"
        },
        "registry.redhat.io": {
          "auth": "ENCODED SECRET",
          "email": ""
        },
        <b>"quay.io:443": {
          "auth": "ENCODED SECRET",
          "email": ""
        }</b>
      }
    }
    </pre>


**If you're deploying a downstream build,** then set the following:

**NOTE: You should only use a downstream build if you're doing QE on the final product builds.**

```bash
export COMPOSITE_BUNDLE=true
export CUSTOM_REGISTRY_REPO="quay.io:443/acm-d"
export QUAY_TOKEN=<a quay token with quay.io:443 as the auth domain>
./start.sh --watch
```

In order to get this QUAY_TOKEN, go to your quay.io "Account Settings" page by selecting your username/icon in the top right corner of the page, then "Generate Encrypted Password".  Choose "Kubernetes Secret" and copy just secret text that follows `.dockerconfigjson:`, `export DOCKER_CONFIG=` this value.

If you copy the value of `.dockerconfigjson`, you can simplify setting the `QUAY_TOKEN` as follows:

```bash
export DOCKER_CONFIG=<The value after .dockerconfigjson from the quay.io>
export QUAY_TOKEN=$(echo $DOCKER_CONFIG | base64 -d | sed "s/quay\.io/quay\.io:443/g" | base64)
```

(On Linux, use `export QUAY_TOKEN=$(echo $DOCKER_CONFIG | base64 -d | sed "s/quay\.io/quay\.io:443/g" | base64 -w 0)` to ensure that there are no line breaks in the base64 encoded token)

### Enable search later
Use the following command to enable search
```bash
oc set env deploy search-operator DEPLOY_REDISGRAPH="true" -n INSTALL_NAMESPACE
```

## To Delete a MultiClusterHub Instance (the easy way)

1. Run the `uninstall.sh` script in the root of this repo.


## To Delete the multiclusterhub-operator (the easy way)

1. Run the `clean-clusters.sh` script, and enter `DESTROY` to delete any Hive deployments and detach all imported clusters.
2. Run the `uninstall.sh` script in the root of this repo.

### Troubleshooting
1. If uninstall hangs on the helmRelease delete, you can run this command to move it along.  This is distructive and can result in orphaned objects.
```bash
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.apps.open-cluster-management.io $helmrelease --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; done
```

#### the hard way
<details><summary>Click if you dare</summary>
<p>

## Manually deploy using `kubectl` commands

1. Create the prereq objects by applying the yaml definitions contained in the `prereqs` dir:
  ```bash
  kubectl apply --openapi-patch=true -k prereqs/
  ```

2. Update the `kustomization.yaml` file in the `acm-operator` dir to set `newTag`
  You can find a snapshot tag by viewing the list of tags available [here](https://quay.io/open-cluster-management/acm-custom-registry) Use a tag that has the word `SNAPSHOT` in it.
  For downstream deploys, make sure to set `newName` differently, usually to `acm-d`.
    ```bash
    namespace: open-cluster-management

    images:
      - name: acm-custom-registry
        newName: quay.io/open-cluster-management/acm-custom-registry
        newTag: 1.0.0-SNAPSHOT-2020-05-04-17-43-49
    ```

3. Create the `multiclusterhub-operator` objects by applying the yaml definitions contained in the `acm-operator` dir:
    ```bash
    kubectl apply -k acm-operator/
    ```

4. Wait for subscription to be healthy:
    ```bash
    oc get subscription.operators.coreos.com acm-operator-subscription --namespace open-cluster-management -o yaml
    ...
    status:
      catalogHealth:
      - catalogSourceRef:
          apiVersion: operators.coreos.com/v1alpha1
          kind: CatalogSource
          name: acm-operator-subscription
          namespace: open-cluster-management
          resourceVersion: "1123089"
          uid: f6da232b-e7c1-4fc6-958a-6fb1777e728c
        healthy: true
        ...
    ```

5. Once the `open-cluster-management` CatalogSource is healthy you can deploy the `example-multiclusterhub-cr.yaml`
    ```bash
    apiVersion: operator.open-cluster-management.io/v1
    kind: MultiClusterHub
    metadata:
      name: multiclusterhub
      namespace: open-cluster-management
    spec:
      imagePullSecret: multiclusterhub-operator-pull-secret
    ```

6. Create the `example-multiclusterhub` objects by applying the yaml definitions contained in the `multiclusterhub` dir:
    ```bash
    kubectl apply -k multiclusterhub/
    ```
## To Delete a MultiClusterHub Instance

1. Delete the `example-multiclusterhub` objects by deleting the yaml definitions contained in the `multiclusterhub` dir:
    ```bash
    kubectl delete -k multiclusterhub/
    ```

2. Not all objects are currently being cleaned up by the `multiclusterhub-operator` upon deletion of a `multiclusterhub` instance... you can ensure all objects are cleaned up by executing the `uninstall.sh` script in the `multiclusterhub` dir:
    ```bash
    ./multiclusterhub/uninstall.sh
    ```

After completing the steps above you can redeploy the `multiclusterhub` instance by simply running:
    ```bash
    kubectl apply -k multiclusterhub/
    ```

## To Delete the multiclusterhub-operator

1. Delete the `multiclusterhub-operator` objects by deleting the yaml definitions contained in the `acm-operator` dir:
    ```bash
    kubectl delete -k acm-operator/
    ```

2. Not all objects are currently being cleaned up by the `multiclusterhub-operator` upon deletion. You can ensure all objects are cleaned up by executing the `uninstall.sh` script in the `acm-operator` dir:
    ```bash
    ./acm-operator/uninstall.sh
    ```

After completing the steps above you can redeploy the `multiclusterhub-operator` by simply running:
    ```bash
    kubectl apply -k acm-operator/
    ```
</p>
</details>

# Enabling Bare metal and VMware consoles
These consoles are enabled by default
# Enabling Bare metal consoles
To work with bare metal, two flags need to be flipped activated
## console-header
Run the following command to enable the bare metal assets on the navigation menu
```bash
oc -n open-cluster-management patch deploy console-header -p '{"spec":{"template":{"spec":{"containers":[{"name":"console-header","env":
[{"name": "featureFlags_baremetal","value":"true"}]}]}}}}'
```
## console-ui
Run the following commands to enable the bare metal button on the create cluster page
```bash
DEPLOY_NAME=`oc -n open-cluster-management get deploy -o name | grep consoleui`
oc -n open-cluster-management patch ${DEPLOY_NAME} -p '{"spec":{"template":{"spec":{"containers":[{"name":"hcm-ui","env":
[{"name": "featureFlags_baremetal","value":"true"}]}]}}}}'

```
## Disable Baremetal consoles
Repeat the commands above, but change `"value":"true"` to `"value":"false"`


# Upgrade
You can test the upgrade process with `downstream` builds only, using this repo. To test upgrade follow the instructions below:

1. Export environment variables needed for `downstream` deployment:  
```
   export CUSTOM_REGISTRY_REPO=quay.io/acm-d
   export DOWNSTREAM=true
```  
2. Apply ImageContentSourcePolicy to redirect `registry.redhat.io/rhacm2` to `quay.io:443/acm-d`
```
   oc apply -k addons/downstream
```  
3. In order to perform an `upgrade` you need to install a previously GA'd version of ACM. To do that you will need to set the following variables:
```
   export MODE=Manual     # MODE is set to Manual so that we can specify a previous version to install
   export STARTING_VERSION=2.x.x  # Where 2.x.x is a previously GA'd version of ACM i.e. `STARTING_VERSION=2.0.4`
```
4. Run the `start.sh` script  
```
   ./start.sh --watch
```

Once the installation is complete you can then attempt to upgrade the ACM instance by running the `upgrade.sh` script. You will need to set additional variables in your environment to tell the upgrade script what you want it to do:
1. Export environment variables needed by the `upgrade.sh` script
```
   export NEXT_VERSION=2.x.x      # Where 2.x.x is some value greater than the version you previously defined in the STARTING_VERSION=2.x.x
```
2. Now run the upgrade process:
```
   ./upgrade.sh
```
