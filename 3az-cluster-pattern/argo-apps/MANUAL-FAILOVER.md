# Manual Failover Configuration with ApplicationSets

This document explains how to implement a manual failover approach with ApplicationSets in ArgoCD and ACM for disaster recovery scenarios.

## Overview

Instead of using automatic failover, this approach allows operators to explicitly control which cluster receives deployments by updating a ConfigMap. This is useful when you want to verify conditions before switching deployments between clusters.

## Implementation

### 1. Create a ConfigMap to Control Deployment Target

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: failover-target-config
  namespace: openshift-gitops
data:
  # Set to "primary" for normal operations, "local" for failover
  active-site: "primary"
```

### 2. Configure ApplicationSet with ConfigMap Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: virtualmachines-stretch-application-set
  namespace: openshift-gitops
spec:
  generators:
    # Get the active site from ConfigMap
    - configMap:
        name: failover-target-config
        namespace: openshift-gitops
    # Use a matrix generator to combine ConfigMap value with cluster info
    - matrix:
        generators:
          - configMap:
              name: failover-target-config
              namespace: openshift-gitops
          - clusters:
              selector:
                matchLabels:
                  site-type: '{{active-site}}' # Match clusters with label matching the active site
  template:
    metadata:
      name: 'virtualmachines-{{name}}'
    spec:
      project: multiaz
      source:
        helm:
          releaseName: multiaz-{{name}}
          valueFiles:
          - values-common.yaml
          - values-{{active-site}}.yaml
        repoURL: https://github.com/rmallam/kubevirt-gitops.git
        targetRevision: restructure
        path: '3az-cluster-pattern/helm/stretchtest'
      destination:
        server: '{{server}}'
        namespace: drtest
      syncPolicy:
        syncOptions:
          - Validate=true
          - CreateNamespace=true
```

### 3. Label Your Clusters

```bash
# Label primary cluster
kubectl label managedclusters primary-cluster site-type=primary -n open-cluster-management

# Label local (DR) cluster 
kubectl label managedclusters local-cluster site-type=local -n open-cluster-management
```

## Performing a Manual Failover

To perform a manual failover when the primary cluster becomes unavailable:

1. Update the ConfigMap to switch to local cluster:

```bash
kubectl patch configmap failover-target-config -n openshift-gitops --type=merge -p '{"data":{"active-site":"local"}}'
```

2. ArgoCD will detect the change and redeploy to the local cluster.

3. To switch back to the primary cluster when it becomes available:

```bash
kubectl patch configmap failover-target-config -n openshift-gitops --type=merge -p '{"data":{"active-site":"primary"}}'
```

## Alternative: Single-Cluster Selection Approach

For an even simpler approach that directly specifies the target cluster:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: virtualmachines-stretch-application-set
  namespace: openshift-gitops
spec:
  generators:
    - configMap:
        name: failover-target-config
        namespace: openshift-gitops
  template:
    metadata:
      name: 'virtualmachines-{{active-site}}'
    spec:
      project: multiaz
      source:
        helm:
          releaseName: multiaz-{{active-site}}
          valueFiles:
          - values-common.yaml
          - values-{{active-site == "primary" && "primary" || "dr"}}.yaml
        repoURL: https://github.com/rmallam/kubevirt-gitops.git
        targetRevision: restructure
        path: '3az-cluster-pattern/helm/stretchtest'
      destination:
        # Use conditional to select the appropriate cluster
        server: '{{ active-site == "primary" && "https://api.primary-cluster:6443" || "https://kubernetes.default.svc" }}'
        namespace: drtest
      syncPolicy:
        syncOptions:
          - Validate=true
          - CreateNamespace=true
```

With this approach, the ConfigMap data would directly specify which site to deploy to (primary or local), and the template would use conditional values to select the appropriate cluster server URL.

## Shell Script to Perform Failover

You can create a simple shell script to perform the failover:

```bash
#!/bin/bash

# manual-failover.sh
# Usage: ./manual-failover.sh [primary|local]

if [ "$1" != "primary" ] && [ "$1" != "local" ]; then
  echo "Usage: ./manual-failover.sh [primary|local]"
  exit 1
fi

echo "Switching deployment target to $1 cluster..."
kubectl patch configmap failover-target-config -n openshift-gitops --type=merge -p "{\"data\":{\"active-site\":\"$1\"}}"

echo "Checking ApplicationSet status..."
kubectl get applications -n openshift-gitops -l app.kubernetes.io/instance=virtualmachines-stretch-application-set -o name | \
  xargs -I{} kubectl patch {} -n openshift-gitops --type=merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

echo "Failover to $1 cluster initiated!"
```

This script allows you to easily switch between primary and local clusters when needed.