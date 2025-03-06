install argocd in the cluster using the 

```
oc apply -f install/ --recursive 
oc --insecure-skip-tls-verify=true  -n openshift-gitops wait --for=jsonpath='{.status.state}'=AtLatestKnown subscription/openshift-gitops-operator --timeout=300s 
sleep 90
oc --insecure-skip-tls-verify=true -n openshift-gitops wait --for=condition=Ready pod -l app.kubernetes.io/name=openshift-gitops-application-controller --timeout=300s
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller
oc --insecure-skip-tls-verify=true wait --for=condition=Established  crd applicationsets.argoproj.io --timeout=300s
          
```
## private repo
if your repo is private, Run the following command to add the github token to argocd.
```
SERVER_URL=$(oc get routes openshift-gitops-server -n openshift-gitops -o jsonpath='{.status.ingress[0].host}')
ADMIN_PASSWD=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)
argocd login --username admin --password ${ADMIN_PASSWD} ${SERVER_URL} --grpc-web
argocd repo add https://github.com/rmallam/gitops-openshift --username rmallam --password gitpat
```

## aws virt
### ROSA

adding a baremetal machinepool for rosa to run virt workloads
```
  rosa create machinepools -c ` rosa list clusters | awk -F " " '{print $2}' | grep -v NAME` --instance-type c6i.metal --name virt-pool --replicas 3
```