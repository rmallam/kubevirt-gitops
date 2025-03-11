# 🚀 KubeVirt GitOps

<div align="center">

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![OpenShift](https://img.shields.io/badge/OpenShift-4.10+-red.svg)](https://www.openshift.com/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-Powered-green.svg)](https://argoproj.github.io/cd/)

<img src="https://raw.githubusercontent.com/kubevirt/community/main/logo/KubeVirt_icon.png" alt="KubeVirt Logo" width="200"/>

**A GitOps approach to managing KubeVirt virtualization on OpenShift clusters**

</div>

---

## 📋 Overview

This repository contains automation scripts and configuration for setting up a GitOps workflow using Argo CD (OpenShift GitOps) to manage KubeVirt resources. The project provides a declarative approach to managing virtual machines and related resources on OpenShift.

## ✅ Prerequisites

- An OpenShift cluster 4.10+ with cluster-admin access
- `oc` command-line tool installed and configured
- Basic understanding of GitOps principles and Argo CD

## 🚦 Quick Start

### 1. Install Argo CD (OpenShift GitOps)

Run the installation script:

```bash
# Make the script executable
chmod +x install-argo.sh

# Run the script
./install-argo.sh
```

## 🔒 How to use private git repo with ArgoCD

If your repo is private, run the following command to add the GitHub token to ArgoCD:

```bash
SERVER_URL=$(oc get routes openshift-gitops-server -n openshift-gitops -o jsonpath='{.status.ingress[0].host}')
ADMIN_PASSWD=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)
argocd login --username admin --password ${ADMIN_PASSWD} ${SERVER_URL} --grpc-web
argocd repo add https://github.com/rmallam/kubevirt-gitops --username rmallam --password gitpat #replace this with the right git token
```

## 📦 Install Operator

Apply the infra-appset.yaml to deploy operators:

```bash
oc apply -f argo-apps/infra-appset.yaml
```

## 📝 Additional Notes for AWS Virtualization

### ROSA (Red Hat OpenShift Service on AWS)

Adding a baremetal machinepool for ROSA to run virtualization workloads:

```bash
rosa create machinepools -c $(rosa list clusters | awk -F " " '{print $2}' | grep -v NAME) --instance-type c6i.metal --name virt-pool --replicas 3
```

### EFS (Elastic File System)

Create an EFS filesystem named "pythontest" using the AWS CLI:

```bash
# Get your VPC ID where the ROSA cluster is running
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*rosa*" --query "Vpcs[0].VpcId" --output text)

# Create a security group for the EFS filesystem
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name EFS-pythontest-SG \
  --description "Security group for EFS pythontest" \
  --vpc-id $VPC_ID \
  --output text --query 'GroupId')

# Allow inbound NFS traffic from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 2049 \
  --cidr 0.0.0.0/0

# Create the EFS filesystem
EFS_ID=$(aws efs create-file-system \
  --creation-token pythontest \
  --tags Key=Name,Value=pythontest \
  --encrypted \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --output text --query 'FileSystemId')

echo "Created EFS filesystem with ID: $EFS_ID"

# Create mount targets in all subnets of the VPC
for SUBNET_ID in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text); do
  aws efs create-mount-target \
    --file-system-id $EFS_ID \
    --subnet-id $SUBNET_ID \
    --security-groups $SECURITY_GROUP_ID
done

echo "EFS filesystem 'pythontest' ($EFS_ID) has been created and configured."
```

Use this EFS filesystem with the same VPC as your ROSA cluster. The security group is configured to accept connections from anywhere, which is convenient for testing but should be restricted in production environments.

## 🏷️ Node Labeling for Disaster Recovery

Choose one or more nodes for DR sites and label them as DR:

```bash
oc label node ip-10-0-47-96.us-east-2.compute.internal site=dr
```

Choose one or more nodes for primary sites and label them as primary:

```bash
oc label node ip-10-0-47-116.us-east-2.compute.internal site=primary
```

---

<div align="center">
<p>Made with ❤️ for the OpenShift & KubeVirt community</p>
</div>