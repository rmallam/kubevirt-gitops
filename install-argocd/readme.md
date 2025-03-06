to add managed clusters to argocd, All the resources should be created in the argocd namespace only.
oc apply -f managedclustersetbinding.yaml -n openshift-gitops
oc apply -f placement.yaml -n openshift-gitops
oc apply -f gitopscluster.yaml -n openshift-gitops -o yaml

