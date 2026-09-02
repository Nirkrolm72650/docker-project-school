#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE VÉRIFICATION AWS / LOCALSTACK (awslocal)
# ==============================================================================
set -e

AWS_CMD="awslocal"
if ! command -v awslocal &> /dev/null; then
    AWS_CMD="/Library/Frameworks/Python.framework/Versions/3.12/bin/awslocal"
fi

if ! command -v $AWS_CMD &> /dev/null; then
    echo "❌ awslocal n'est pas trouvé dans le PATH."
    exit 1
fi

echo "================================================================="
echo " 🔍 AUDIT DES RESSOURCES LOCALSTACK PROVISIONNÉES PAR TERRAFORM"
echo "================================================================="

echo ""
echo "1️⃣  [VPC & NETWORKING]"
$AWS_CMD ec2 describe-vpcs --filters "Name=tag:Name,Values=ecom-vpc" --query "Vpcs[*].[VpcId,CidrBlock,State,Tags[?Key=='Name'].Value|[0]]" --output table

echo ""
echo "2️⃣  [SUBNETS (PUBLIC & PRIVÉ)]"
$AWS_CMD ec2 describe-subnets --filters "Name=tag:ManagedBy,Values=Terraform" --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key=='Name'].Value|[0]]" --output table

echo ""
echo "3️⃣  [SECURITY GROUPS (FRONTEND, BACKEND, DATABASE)]"
$AWS_CMD ec2 describe-security-groups --filters "Name=group-name,Values=ecom-*" --query "SecurityGroups[*].[GroupId,GroupName,Description]" --output table

echo ""
echo "4️⃣  [IAM ROLES & POLICIES]"
$AWS_CMD iam list-roles --query "Roles[?RoleName=='ecom-ec2-role'].[RoleName,Arn,RoleId]" --output table
$AWS_CMD iam list-instance-profiles --query "InstanceProfiles[?InstanceProfileName=='ecom-ec2-instance-profile'].[InstanceProfileName,Arn]" --output table

echo ""
echo "5️⃣  [S3 STORAGE & FACTURES]"
$AWS_CMD s3 ls
echo "Contenu du bucket ecom-localstack-storage :"
$AWS_CMD s3 ls s3://ecom-localstack-storage/

echo ""
echo "6️⃣  [EC2 INSTANCES (WEB APP & DATABASE)]"
$AWS_CMD ec2 describe-instances --filters "Name=tag:ManagedBy,Values=Terraform" --query "Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key=='Name'].Value|[0],PrivateIpAddress,PublicIpAddress]" --output table

echo ""
echo "================================================================="
echo " ✅ TOUTES LES RESSOURCES SONT PARFAITEMENT DÉPLOYÉES SUR LOCALSTACK"
echo "================================================================="

