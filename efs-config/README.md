# EFS Integration with OpenShift

This guide explains the requirements for mounting an AWS EFS filesystem on an OpenShift cluster.

## Prerequisites

1. An OpenShift cluster running in AWS
2. AWS EFS filesystem already provisioned
3. Proper networking connectivity between OpenShift nodes and EFS
4. IAM permissions for the OpenShift nodes to access EFS
5. Security groups configured to allow NFS traffic (TCP port 2049)
