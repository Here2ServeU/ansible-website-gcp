# Ansible Project for Deploying a Website on Google Cloud

## Project Overview

This project demonstrates how to:
- Set up a controller node and managed nodes on Google Cloud.
- Configure keyless SSH access for secure communication between nodes.
- Use Ansible to deploy a website with a registration form for courses like DevOps, and Cloud
- Perform resource cleanup after deployment.

## Setup Instructions

### Prerequisites

#### 1. Set up Google Cloud CLI and Project
- Install the gcloud CLI.
- Authenticate with Google Cloud:
```bash
gcloud auth login
```

- Set your project:
```bash
gcloud config set project <PROJECT_ID>
```

- Enable required services:
```bash
gcloud services enable compute.googleapis.com
```


#### 2. Create a Bash Script for Cluster Setup

- Create a directory for the project:
```bash
mkdir ansible
cd ansible
nano setup_ansible_cluster.sh
```
- Add the following content:
```bash
#!/bin/bash

# Variables
GCP_REGION="us-central1"
GCP_ZONE="us-central1-a"
NETWORK_NAME="ansible-network"
SUBNET_NAME="ansible-subnet"
FIREWALL_NAME="ansible-firewall"
CONTROLLER_NAME="ansible-controller"
WORKER1_NAME="worker-node-ubuntu"
WORKER2_NAME="worker-node-debian"
CONTROLLER_IMAGE="ubuntu-2204-lts" # Controller OS
WORKER_IMAGE="debian-11"          # Worker OS
INSTANCE_TYPE="e2-medium"
SSH_KEY_NAME="ansible-key"

# Step 1: Create Network and Subnet
echo "Creating VPC network and subnet..."
gcloud compute networks create $NETWORK_NAME --subnet-mode=custom
gcloud compute networks subnets create $SUBNET_NAME \
  --network=$NETWORK_NAME \
  --region=$GCP_REGION \
  --range=10.128.0.0/20

# Step 2: Create Firewall Rules
echo "Creating firewall rules..."
gcloud compute firewall-rules create $FIREWALL_NAME \
  --network=$NETWORK_NAME \
  --allow tcp:22,tcp:80 \
  --source-ranges=0.0.0.0/0

# Step 3: Generate SSH Key
echo "Generating SSH key..."
ssh-keygen -t ed25519 -f ~/.ssh/$SSH_KEY_NAME -q -N ""

# Step 4: Launch Instances
echo "Launching Controller Node..."
gcloud compute instances create $CONTROLLER_NAME \
  --zone=$GCP_ZONE \
  --machine-type=$INSTANCE_TYPE \
  --subnet=$SUBNET_NAME \
  --image-family=$CONTROLLER_IMAGE \
  --image-project=ubuntu-os-cloud \
  --metadata=ssh-keys="$(whoami):$(cat ~/.ssh/${SSH_KEY_NAME}.pub)" \
  --tags=ansible-controller

echo "Launching Worker Nodes..."
gcloud compute instances create $WORKER1_NAME $WORKER2_NAME \
  --zone=$GCP_ZONE \
  --machine-type=$INSTANCE_TYPE \
  --subnet=$SUBNET_NAME \
  --image-family=$WORKER_IMAGE \
  --image-project=debian-cloud \
  --metadata=ssh-keys="$(whoami):$(cat ~/.ssh/${SSH_KEY_NAME}.pub)" \
  --tags=ansible-workers

echo "Cluster setup complete!"
```
- Make the script executable and run it:
```bash
chmod +x setup_ansible_cluster.sh
./setup_ansible_cluster.sh
```
---

## Step 1: Controller Node Setup

### Install Ansible:
#### On the controller node:
```bash
sudo apt update
sudo apt install -y software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
```

#### Set Up Inventory File:
```bash
nano ~/inventory.yml
```
- Add the following content:
```yaml
all:
  hosts:
    worker-node-ubuntu:
      ansible_host=<WORKER1_PUBLIC_IP>
      ansible_user=debian
      ansible_ssh_private_key_file=~/.ssh/ansible-key

    worker-node-debian:
      ansible_host=<WORKER2_PUBLIC_IP>
      ansible_user=debian
      ansible_ssh_private_key_file=~/.ssh/ansible-key
```

#### Test connection:
```bash
ansible -m ping all -i ~/inventory.yml
```
## Step 2: Deploy the Website

### Create Website Content:
```bash
mkdir -p ~/webapp
nano ~/webapp/index.html
```
- Add the HTML provided in your initial script.

- Create Playbook:
```bash
nano ~/deploy_website.yml
```
- Add the following content:
```yaml
---
- name: Deploy Website
  hosts: all
  become: yes
  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present
      when: ansible_facts['os_family'] == 'Debian'

    - name: Copy Website Files
      copy:
        src: ~/webapp/index.html
        dest: /var/www/html/index.html
        owner: www-data
        group: www-data
        mode: '0644'

    - name: Start Nginx
      service:
        name: nginx
        state: started
        enabled: yes
```
### Run the playbook:
```bash
ansible-playbook -i ~/inventory.yml ~/deploy_website.yml
```

## Step 3: Clean Up Resources

### Create a cleanup script:
```bash
nano destroy_ansible_cluster.sh
```
- Add the following content:
```bash
#!/bin/bash

# Variables
GCP_REGION="us-central1"
GCP_ZONE="us-central1-a"
NETWORK_NAME="ansible-network"
FIREWALL_NAME="ansible-firewall"

# Delete instances
echo "Deleting instances..."
gcloud compute instances delete ansible-controller worker-node-ubuntu worker-node-debian --zone=$GCP_ZONE --quiet

# Delete firewall rules
echo "Deleting firewall rules..."
gcloud compute firewall-rules delete $FIREWALL_NAME --quiet

# Delete network and subnet
echo "Deleting network and subnet..."
gcloud compute networks subnets delete ansible-subnet --region=$GCP_REGION --quiet
gcloud compute networks delete $NETWORK_NAME --quiet

echo "Cleanup complete!"
```
- Make it executable:
```bash
chmod +x destroy_ansible_cluster.sh
./destroy_ansible_cluster.sh
```
