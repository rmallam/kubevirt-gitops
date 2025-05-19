# ApplicationSet Configuration for Multi-Cluster Deployment with ACM

This document provides guidance on configuring ApplicationSets to work with Advanced Cluster Management (ACM) for different multi-cluster deployment scenarios.

## Basic ApplicationSet Structure

The current ApplicationSet uses a simple list generator to create applications for primary and secondary sites:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: virtualmachines-stretch-application-set
  namespace: openshift-gitops
spec:
  generators:
    - list:
        elements:
          - name: primary-site
            valueFile: values-primary.yaml
            namespace: drtest
          - name: secondary-site
            valueFile: values-dr.yaml
            namespace: drtest
  template:
    metadata:
      name: '{{name}}'
    spec:
      project: multiaz
      source:
        helm:
          releaseName: multiaz-{{name}}
          valueFiles:
          - values-common.yaml
          - '{{valueFile}}'
        repoURL: https://github.com/rmallam/kubevirt-gitops.git
        targetRevision: restructure
        path: '3az-cluster-pattern/helm/stretchtest'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        syncOptions:
          - Validate=true
          - CreateNamespace=true
```

## Using ApplicationSets with ACM for Multiple Clusters

To deploy across multiple clusters managed by ACM, you can replace the list generator with the clusters generator:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: virtualmachines-stretch-application-set
  namespace: openshift-gitops
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            # Add specific labels to target certain clusters
            # For example: environment: production
        values:
          valueFile: values-{{name == "local-cluster" && "primary" || "dr"}}.yaml
  template:
    metadata:
      name: '{{name}}-site'
    spec:
      project: multiaz
      source:
        helm:
          releaseName: multiaz-{{name}}
          valueFiles:
          - values-common.yaml
          - '{{valueFile}}'
        repoURL: https://github.com/rmallam/kubevirt-gitops.git
        targetRevision: restructure
        path: '3az-cluster-pattern/helm/stretchtest'
      destination:
        server: '{{server}}'  # Uses the cluster URL from the generator
        namespace: drtest
      syncPolicy:
        syncOptions:
          - Validate=true
          - CreateNamespace=true
```

## Primary Cluster with Local Failover

For deployments that should prefer a primary cluster but fail over to local when the primary is unavailable, use the clusterDecisionResource generator:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: virtualmachines-stretch-application-set
  namespace: openshift-gitops
spec:
  generators:
    - clusterDecisionResource:
        configMapRef: primary-cluster-cm
        labelSelector:
          matchLabels:
            cluster-role: primary-with-failover
        requeueAfterSeconds: 180
        values:
          valueFile: values-{{metadata.labels.environment == "primary" && "primary" || "dr"}}.yaml
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
          - '{{valueFile}}'
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

### Required Additional Resources

1. **Placement Configuration**:

```yaml
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: primary-cluster-placement
  namespace: openshift-gitops
  labels:
    cluster-role: primary-with-failover
spec:
  prioritizerPolicy:
    mode: Exact
    configurations:
      - scoreCoordinate:
          type: BuiltIn
          builtIn: ResourceAllocatableCPU
        weight: 2
  predicates:
    - requiredClusterSelector:
        labelSelector:
          matchExpressions:
            - key: environment
              operator: In
              values:
                - primary
                - local # Include local as fallback
```

2. **Cluster Labeling**:
   - Primary cluster should have label: `environment: primary`
   - Local/failover cluster should have: `environment: local`

## Best Practices

1. Use appropriate labels to clearly identify cluster roles
2. Set an appropriate requeueAfterSeconds value for failover scenarios
3. Use conditional valueFile selection based on cluster metadata
4. Test failover scenarios thoroughly to ensure proper application deployment