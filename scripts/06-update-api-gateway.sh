#!/bin/bash
# MTKC POC EKS - Configure ACK API Gateway Resources
# @author Shanaka Jayasundera - shanakaj@gmail.com
#
# This script configures the ACK API Gateway CRDs with actual values
# Similar to Azure Service Operator pattern in AKS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
API_GW_CONFIG="$PROJECT_DIR/k8s/api-gateway/api-gateway-config.yaml"
ACK_ARGOCD_APP="$PROJECT_DIR/argocd/apps/09-ack-apigatewayv2.yaml"

echo "=== Configuring ACK API Gateway Resources ==="

# Check if API Gateway is enabled
API_GATEWAY_ENABLED=$(terraform -chdir="$PROJECT_DIR/terraform" output -raw api_gateway_enabled 2>/dev/null || echo "false")

if [ "$API_GATEWAY_ENABLED" != "true" ]; then
    echo "API Gateway is not enabled. Skipping..."
    echo "To enable, set enable_api_gateway = true in terraform.tfvars"
    exit 0
fi

# Get values from Terraform
echo "Getting values from Terraform..."
REGION=$(terraform -chdir="$PROJECT_DIR/terraform" output -raw region 2>/dev/null || echo "ap-southeast-2")
VPC_ID=$(terraform -chdir="$PROJECT_DIR/terraform" output -raw vpc_id)
PRIVATE_SUBNETS=$(terraform -chdir="$PROJECT_DIR/terraform" output -json private_subnet_ids | jq -r '.[]')
ACK_ROLE_ARN=$(terraform -chdir="$PROJECT_DIR/terraform" output -raw ack_apigatewayv2_role_arn)

echo "Region: $REGION"
echo "VPC ID: $VPC_ID"
echo "ACK Role ARN: $ACK_ROLE_ARN"

# Get Internal NLB DNS name
echo "Getting Internal NLB DNS name..."
INTERNAL_NLB_DNS=$(kubectl get svc -n istio-ingress -l istio.io/gateway-name=mtkc-gateway \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$INTERNAL_NLB_DNS" ]; then
    echo "WARNING: Internal NLB not found yet. Using placeholder."
    echo "Ensure the Istio Gateway is deployed first."
    INTERNAL_NLB_DNS="INTERNAL_NLB_NOT_READY"
fi

echo "Internal NLB DNS: $INTERNAL_NLB_DNS"

# Create/Get security group for VPC Link
echo "Creating security group for VPC Link..."
SG_NAME="${VPC_ID}-apigw-vpc-link"
EXISTING_SG=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$SG_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_SG" == "None" ] || [ -z "$EXISTING_SG" ]; then
    echo "Creating new security group..."
    SG_ID=$(aws ec2 create-security-group \
        --region "$REGION" \
        --group-name "$SG_NAME" \
        --description "Security group for API Gateway VPC Link" \
        --vpc-id "$VPC_ID" \
        --query "GroupId" \
        --output text)

    # Add egress rules
    aws ec2 authorize-security-group-egress \
        --region "$REGION" \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 80 \
        --cidr 10.0.0.0/16 2>/dev/null || true

    aws ec2 authorize-security-group-egress \
        --region "$REGION" \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 443 \
        --cidr 10.0.0.0/16 2>/dev/null || true

    echo "Created security group: $SG_ID"
else
    SG_ID="$EXISTING_SG"
    echo "Using existing security group: $SG_ID"
fi

# Update ArgoCD app with ACK role ARN
echo "Updating ArgoCD ACK app with role ARN..."
if [ -f "$ACK_ARGOCD_APP" ]; then
    sed -i.bak "s|REPLACE_WITH_ACK_ROLE_ARN|$ACK_ROLE_ARN|g" "$ACK_ARGOCD_APP"
    sed -i.bak "s|region: ap-southeast-2|region: $REGION|g" "$ACK_ARGOCD_APP"
    rm -f "${ACK_ARGOCD_APP}.bak"
    echo "Updated: $ACK_ARGOCD_APP"
fi

# Update API Gateway config with actual values
echo "Updating API Gateway CRD configuration..."
if [ -f "$API_GW_CONFIG" ]; then
    # Convert subnets to array format for YAML
    SUBNET_ARRAY=""
    for subnet in $PRIVATE_SUBNETS; do
        SUBNET_ARRAY="$SUBNET_ARRAY    - \"$subnet\"\n"
    done

    # Update subnet IDs
    FIRST_SUBNET=$(echo "$PRIVATE_SUBNETS" | head -1)
    SECOND_SUBNET=$(echo "$PRIVATE_SUBNETS" | tail -1)

    sed -i.bak "s|REPLACE_WITH_PRIVATE_SUBNET_1|$FIRST_SUBNET|g" "$API_GW_CONFIG"
    sed -i.bak "s|REPLACE_WITH_PRIVATE_SUBNET_2|$SECOND_SUBNET|g" "$API_GW_CONFIG"
    sed -i.bak "s|REPLACE_WITH_SECURITY_GROUP_ID|$SG_ID|g" "$API_GW_CONFIG"
    sed -i.bak "s|REPLACE_WITH_INTERNAL_NLB_DNS|$INTERNAL_NLB_DNS|g" "$API_GW_CONFIG"
    rm -f "${API_GW_CONFIG}.bak"

    echo "Updated: $API_GW_CONFIG"
fi

echo ""
echo "=== ACK API Gateway Configuration Complete ==="
echo ""
echo "Next steps:"
echo "1. Deploy ACK controller (if not already deployed):"
echo "   kubectl apply -f argocd/apps/09-ack-apigatewayv2.yaml"
echo ""
echo "2. Wait for ACK controller to be ready:"
echo "   kubectl get pods -n ack-system"
echo ""
echo "3. Deploy API Gateway configuration:"
echo "   kubectl apply -f argocd/apps/10-api-gateway-config.yaml"
echo ""
echo "4. Check API Gateway resources:"
echo "   kubectl get api,integration,route,stage -n api-services"
echo ""
echo "Configuration values:"
echo "  Region:           $REGION"
echo "  VPC ID:           $VPC_ID"
echo "  Security Group:   $SG_ID"
echo "  ACK Role ARN:     $ACK_ROLE_ARN"
echo "  Internal NLB:     $INTERNAL_NLB_DNS"
echo ""
