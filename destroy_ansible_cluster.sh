#!/bin/bash

# Variables
GCP_PROJECT_ID="your-project-id" # Replace with your Google Cloud project ID
GCP_REGION="us-central1"
GCP_ZONE="us-central1-a"
NETWORK_NAME="ansible-network"
FIREWALL_NAME="ansible-firewall"

# Step 1: Terminate Compute Instances
echo "Fetching Google Cloud instance names for termination..."
INSTANCE_NAMES=$(gcloud compute instances list \
  --filter="name~'(ansible-controller|worker-node-debian|worker-node-ubuntu)'" \
  --format="value(name)")

if [ -n "$INSTANCE_NAMES" ]; then
  echo "Deleting instances: $INSTANCE_NAMES"
  gcloud compute instances delete $INSTANCE_NAMES --zone=$GCP_ZONE --quiet
  echo "Google Cloud instances terminated."
else
  echo "No Google Cloud instances found to terminate."
fi

# Step 2: Delete Firewall Rule
echo "Deleting firewall rule: $FIREWALL_NAME..."
gcloud compute firewall-rules delete $FIREWALL_NAME --quiet
echo "Firewall rule deleted."

# Step 3: Delete Network
echo "Deleting network: $NETWORK_NAME..."
gcloud compute networks delete $NETWORK_NAME --quiet
echo "Network deleted."

# Step 4: Clean up local Ansible environment
echo "Cleaning up local Ansible environment..."
rm -f ~/inventory.yml 2>/dev/null
rm -f ~/deploy_website.yml 2>/dev/null
rm -rf ~/ansible/ 2>/dev/null

echo "All resources and local files have been cleaned up."
