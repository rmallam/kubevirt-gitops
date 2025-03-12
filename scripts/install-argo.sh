#!/bin/bash

# Script to install and configure ArgoCD (OpenShift GitOps)
# Author: Rakesh Kumar Mallam

set -e  # Exit immediately if a command exits with non-zero status

# Colors for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for logging messages
log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}[$timestamp]${NC} $1"
}

# Function to log errors
error() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${RED}[$timestamp ERROR]${NC} $1" >&2
}

# Function to log warnings
warn() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}[$timestamp WARNING]${NC} $1"
}

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        error "Required command '$1' not found. Please install it and try again."
        exit 1
    fi
}

# Function to display ArgoCD access information
display_argo_info() {
    log "Retrieving ArgoCD access information..."
    
    # Get the ArgoCD route
    local argo_route
    argo_route=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [[ -z "$argo_route" ]]; then
        warn "Could not retrieve ArgoCD route. It may not be ready yet or may have a different name."
    else
        # Get the admin password
        local admin_password
        admin_password=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' 2>/dev/null | base64 -d)
        
        if [[ -z "$admin_password" ]]; then
            warn "Could not retrieve admin password. The secret name might be different."
            echo -e "\n${BLUE}=== ArgoCD Access Information ===${NC}"
            echo -e "ArgoCD URL: ${YELLOW}https://$argo_route${NC}"
            echo -e "Username: ${YELLOW}admin${NC}"
            echo -e "Password: ${YELLOW}<could not be retrieved automatically>${NC}"
        else
            echo -e "\n${BLUE}=== ArgoCD Access Information ===${NC}"
            echo -e "ArgoCD URL: ${YELLOW}https://$argo_route${NC}"
            echo -e "Username: ${YELLOW}admin${NC}"
            echo -e "Password: ${YELLOW}$admin_password${NC}"
        fi
    fi
}

# Main execution function
install_argo() 
{
    log "Starting OpenShift GitOps installation"
    
    # Step 1: Apply installation files
    log "Applying installation files from 'install-argocd/' directory"
    oc apply -f install-argocd/ --recursive || { error "Failed to apply installation files"; exit 1; }
    
    # Step 2: Wait for subscription to be ready
    log "Waiting for OpenShift GitOps operator subscription to be ready"
    if ! oc --insecure-skip-tls-verify=true -n openshift-gitops wait --for=jsonpath='{.status.state}'=AtLatestKnown subscription/openshift-gitops-operator --timeout=300s; then
        error "Timeout waiting for GitOps operator subscription"
        exit 1
    fi
    
    # Step 3: Wait for GitOps to initialize (sleep)
    log "Allowing time for GitOps resources to initialize (90 seconds)"
    sleep 90
    
    # Step 4: Wait for application controller pod to be ready
    log "Waiting for Argo CD application controller pod to be ready"
    if ! oc --insecure-skip-tls-verify=true -n openshift-gitops wait --for=condition=Ready pod -l app.kubernetes.io/name=openshift-gitops-application-controller --timeout=300s; then
        error "Timeout waiting for Argo CD application controller pod"
        exit 1
    fi
    
    # Step 5: Add cluster role to service account
    log "Adding cluster-admin role to Argo CD application controller"
    oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller || { 
        error "Failed to add cluster role to service account"
        exit 1
    }
    
    # Step 6: Wait for ApplicationSet CRD to be established
    log "Waiting for ApplicationSet CRD to be established"
    if ! oc --insecure-skip-tls-verify=true wait --for=condition=Established crd applicationsets.argoproj.io --timeout=300s; then
        error "Timeout waiting for ApplicationSet CRD to be established"
        exit 1
    fi
    
    log "OpenShift GitOps installation completed successfully!"
    
    # Display ArgoCD access information
    display_argo_info
}

# Check for required commands
check_command "oc"

# Execute the installation
install_argo