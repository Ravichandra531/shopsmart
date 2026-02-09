#!/bin/bash

KEY_NAME="vockey"
SG_NAME="launch-wizard-1"
INSTANCE_NAME="Terminal-EC2"

echo "Creating key pair..."
aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --query "KeyMaterial" \
  --output text > ${KEY_NAME}.pem

chmod 400 ${KEY_NAME}.pem

echo "Getting default VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query "Vpcs[0].VpcId" \
  --output text)

echo "Creating security group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name $SG_NAME \
  --description "Allow SSH" \
  --vpc-id $VPC_ID \
  --query "GroupId" \
  --output text)

echo "Allowing SSH access..."
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "Fetching latest Amazon Linux AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query "Images | sort_by(@, &CreationDate)[-1].ImageId" \
  --output text)

echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --associate-public-ip-address \
  --count 1 \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo ""
echo "INSTANCE READY"
echo "Public IP: $PUBLIC_IP"
echo "SSH using:"
echo "ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
