# Open Cluster Managment Demo

Welcome to your first taste of Open Cluster Management (OCM).  We have collected a number of assets in this directory of our repo to get your feet wet with OCM.  Here you will find some basic instructions for how to utilize the contained assets to do the following:

- Provision a "managed cluster" OCP cluster using OCM (sometimes referred to as a "spoke cluster")
- Load a number of governance policies into your OCM instance
- Load an application via a subscription into your OCM
- Deploy an application onto your managed cluster(s) using a subscription and placement rules


We'll keep it brief and to the point in here... for our full documentation you should refer to our [doc site](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/1.0/).

In here you'll find three sub-directories:

- __spoke__ - contains yaml definitions to provision a "spoke" cluster on AWS using OCM
- __policies__ - contains yaml definitions to create a channel in OCM that will load all the policy definitions from a github repo
- __app__ - contains yaml definitions to create a bookinfo application
  - includes multiple channels which are repository definitions for GitHub and Helm repos
  - includes placement rule definitions to identify which managed cluster(s) should be targeted for application deployments
  - includes subscription definitions to facilitate an application's use of channels and a placement rules to deploy the application onto your managed cluster

Each sub-directory above contains a seperate README.md explaining the specific steps necessary for their contained assets.

## Let's get started
You're going to need to have an OCP cluster with OCM already deployed (see the [README.md](../README.md) in the root of this repo for details on how to deploy OCM).

### Step 1
You've gotta have something to manage... [Provision a "spoke" cluster using OCM](./spoke/README.md)

### Step 2
Now we're getting to the good stuff... [Add applications, channels, subscriptions, and placement rules to your OCM](./app/README.md)

### Step 3
You ever wanted to be a governor?  Well now is you're opportunity... [Import policies into your OCM](./policies/README.md)

### Step 4
Hey you didn't think all this was completely free did you?  You owe us some feedback... create some [product issues](https://github.com/open-cluster-management/deploy/issues) or maybe some [doc issues](https://github.com/open-cluster-management/rhacm-docs/issues/new).  We want to hear from you.  If you just have questions you can find us on Slack ([#forum-acm](https://coreos.slack.com/archives/CTDEY6EEA)).

