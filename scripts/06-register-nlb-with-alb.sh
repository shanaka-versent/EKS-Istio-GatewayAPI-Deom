#!/bin/bash
# MTKC POC EKS - Register Internal NLB with ALB Target Group
# @author Shanaka Jayasundera - shanakaj@gmail.com
#
# This script registers the Internal NLB (created by Istio Gateway) with the
# ALB target group so traffic flows: Internet -> ALB -> Internal NLB -> Istio Gateway
#
# Prerequisites:
# - AWS CLI configured with appropriate credentials
# - kubectl configured to access the EKS cluster
# - Terraform has been applied
# - ArgoCD apps have synced (Istio Gateway created the NLB)
#
# Usage: ./06-register-nlb-with-alb.sh [--force]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
REGION="${AWS_REGION:-ap-southeast-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        exit 1
    fi

    # Test AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or expired"
        exit 1
    fi

    log_info "All prerequisites met"
}

# Get Terraform outputs
get_terraform_outputs() {
    log_info "Getting Terraform outputs..."

    cd "${TERRAFORM_DIR}"

    # Get cluster name
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null) || {
        log_error "Failed to get EKS cluster name from Terraform"
        exit 1
    }

    # Get target group ARN
    TARGET_GROUP_ARN=$(terraform output -raw alb_target_group_arn 2>/dev/null) || {
        log_error "Failed to get ALB target group ARN from Terraform"
        exit 1
    }

    # Determine target port based on enable_https
    HTTPS_ENABLED=$(terraform output -raw https_enabled 2>/dev/null) || HTTPS_ENABLED="false"
    if [ "$HTTPS_ENABLED" = "true" ]; then
        TARGET_PORT=443
    else
        TARGET_PORT=80
    fi

    log_info "Cluster: ${CLUSTER_NAME}"
    log_info "Target Group: ${TARGET_GROUP_ARN}"
    log_info "Target Port: ${TARGET_PORT}"

    cd - > /dev/null
}

# Get the Internal NLB IP
get_nlb_ip() {
    log_info "Getting Internal NLB IP from Istio Gateway..."

    # Update kubeconfig
    aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}" --quiet

    # Wait for Gateway to be ready
    log_info "Waiting for Istio Gateway to be ready..."
    for i in {1..30}; do
        GATEWAY_STATUS=$(kubectl get gateway -n istio-ingress mtkc-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null) || true
        if [ "$GATEWAY_STATUS" = "True" ]; then
            log_info "Gateway is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Timeout waiting for Gateway to be ready"
            exit 1
        fi
        echo -n "."
        sleep 10
    done

    # Get the NLB hostname
    NLB_HOSTNAME=$(kubectl get gateway -n istio-ingress mtkc-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null) || {
        log_error "Failed to get NLB hostname from Gateway status"
        exit 1
    }

    if [ -z "$NLB_HOSTNAME" ]; then
        log_error "NLB hostname is empty"
        exit 1
    fi

    log_info "NLB Hostname: ${NLB_HOSTNAME}"

    # Resolve NLB hostname to IP(s)
    log_info "Resolving NLB hostname to IP addresses..."
    NLB_IPS=$(dig +short "${NLB_HOSTNAME}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -5)

    if [ -z "$NLB_IPS" ]; then
        log_error "Failed to resolve NLB hostname to IP addresses"
        exit 1
    fi

    log_info "NLB IPs: $(echo $NLB_IPS | tr '\n' ' ')"
}

# Get currently registered targets
get_registered_targets() {
    REGISTERED_TARGETS=$(aws elbv2 describe-target-health \
        --target-group-arn "${TARGET_GROUP_ARN}" \
        --region "${REGION}" \
        --query 'TargetHealthDescriptions[*].Target.Id' \
        --output text 2>/dev/null) || REGISTERED_TARGETS=""
}

# Register NLB IPs with ALB target group
register_targets() {
    log_info "Registering NLB IPs with ALB target group..."

    get_registered_targets

    for IP in $NLB_IPS; do
        if echo "$REGISTERED_TARGETS" | grep -q "$IP"; then
            log_info "IP ${IP} is already registered, skipping"
        else
            log_info "Registering IP ${IP}:${TARGET_PORT}..."
            aws elbv2 register-targets \
                --target-group-arn "${TARGET_GROUP_ARN}" \
                --targets "Id=${IP},Port=${TARGET_PORT}" \
                --region "${REGION}"
            log_info "Registered ${IP}:${TARGET_PORT}"
        fi
    done
}

# Deregister old targets that are no longer valid
cleanup_old_targets() {
    log_info "Checking for stale targets to deregister..."

    get_registered_targets

    for TARGET in $REGISTERED_TARGETS; do
        if ! echo "$NLB_IPS" | grep -q "$TARGET"; then
            log_warn "Deregistering stale target: ${TARGET}"
            aws elbv2 deregister-targets \
                --target-group-arn "${TARGET_GROUP_ARN}" \
                --targets "Id=${TARGET},Port=${TARGET_PORT}" \
                --region "${REGION}" 2>/dev/null || true
        fi
    done
}

# Verify target health
verify_targets() {
    log_info "Verifying target health..."

    sleep 5  # Wait for registration to take effect

    aws elbv2 describe-target-health \
        --target-group-arn "${TARGET_GROUP_ARN}" \
        --region "${REGION}" \
        --query 'TargetHealthDescriptions[*].{IP:Target.Id,Port:Target.Port,State:TargetHealth.State}' \
        --output table
}

# Main
main() {
    log_info "Starting NLB registration with ALB target group..."

    check_prerequisites
    get_terraform_outputs
    get_nlb_ip

    if [ "$1" = "--force" ]; then
        cleanup_old_targets
    fi

    register_targets
    verify_targets

    log_info "NLB registration complete!"
    log_info ""
    log_info "Test your deployment:"
    log_info "  curl http://\$(terraform -chdir=${TERRAFORM_DIR} output -raw alb_dns_name)/healthz/ready"
    log_info "  curl http://\$(terraform -chdir=${TERRAFORM_DIR} output -raw alb_dns_name)/app1"
    log_info "  curl http://\$(terraform -chdir=${TERRAFORM_DIR} output -raw alb_dns_name)/app2"
}

main "$@"
