#!/bin/bash

# Variables
GCP_PROJECT_ID="your-project-id" # Replace with your Google Cloud project ID
GCP_REGION="us-central1"
GCP_ZONE="us-central1-a"
NETWORK_NAME="ansible-network"
SUBNET_NAME="ansible-subnet"
FIREWALL_NAME="ansible-firewall"
CONTROLLER_NAME="ansible-controller"
WORKER1_NAME="worker-node-debian"
WORKER2_NAME="worker-node-ubuntu"
CONTROLLER_IMAGE="ubuntu-2204-lts" # Controller OS
WORKER_IMAGE="debian-11"          # Worker OS
INSTANCE_TYPE="e2-medium"
SSH_KEY_NAME="ansible-key"

# Step 1: Set Up Google Cloud CLI
gcloud config set project $GCP_PROJECT_ID

# Step 2: Create Network and Subnet
echo "Creating VPC network and subnet..."
gcloud compute networks create $NETWORK_NAME --subnet-mode=custom
gcloud compute networks subnets create $SUBNET_NAME \
  --network=$NETWORK_NAME \
  --region=$GCP_REGION \
  --range=10.128.0.0/20

# Step 3: Create Firewall Rules
echo "Creating firewall rules..."
gcloud compute firewall-rules create $FIREWALL_NAME \
  --network=$NETWORK_NAME \
  --allow tcp:22,tcp:80 \
  --source-ranges=0.0.0.0/0

# Step 4: Generate SSH Key
echo "Generating SSH key..."
ssh-keygen -t ed25519 -f ~/.ssh/$SSH_KEY_NAME -q -N ""

# Step 5: Launch Controller Node
echo "Launching Controller Node..."
gcloud compute instances create $CONTROLLER_NAME \
  --zone=$GCP_ZONE \
  --machine-type=$INSTANCE_TYPE \
  --subnet=$SUBNET_NAME \
  --image-family=$CONTROLLER_IMAGE \
  --image-project=ubuntu-os-cloud \
  --metadata=ssh-keys="$(whoami):$(cat ~/.ssh/${SSH_KEY_NAME}.pub)" \
  --tags=ansible-controller

# Step 6: Launch Worker Nodes
echo "Launching Worker Nodes..."
gcloud compute instances create $WORKER1_NAME \
  --zone=$GCP_ZONE \
  --machine-type=$INSTANCE_TYPE \
  --subnet=$SUBNET_NAME \
  --image-family=$WORKER_IMAGE \
  --image-project=debian-cloud \
  --metadata=ssh-keys="$(whoami):$(cat ~/.ssh/${SSH_KEY_NAME}.pub)" \
  --tags=ansible-workers

gcloud compute instances create $WORKER2_NAME \
  --zone=$GCP_ZONE \
  --machine-type=$INSTANCE_TYPE \
  --subnet=$SUBNET_NAME \
  --image-family=$CONTROLLER_IMAGE \
  --image-project=ubuntu-os-cloud \
  --metadata=ssh-keys="$(whoami):$(cat ~/.ssh/${SSH_KEY_NAME}.pub)" \
  --tags=ansible-workers

# Step 7: Fetch Public IPs of Instances
echo "Fetching Public IP Addresses..."
gcloud compute instances list --filter="name=($CONTROLLER_NAME $WORKER1_NAME $WORKER2_NAME)" \
  --format="table[box](name, networkInterfaces[0].accessConfigs[0].natIP)"

echo "Ansible cluster setup is complete!"
