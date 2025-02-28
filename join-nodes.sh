#!/bin/bash
set -e

# Variables - modify these as needed
MASTER_NODE="192.168.5.230"
WORKER_NODES=("192.168.5.231" "192.168.5.232" "192.168.5.233")
SSH_USER="user"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i tf-cloud-init"
LOCAL_KUBE_DIR="$HOME/.kube"
LOCAL_KUBE_CONFIG="$LOCAL_KUBE_DIR/config"

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
for cmd in ssh sshpass; do
  if ! command_exists $cmd; then
    echo "Error: Required command '$cmd' not found. Please install it and try again."
    exit 1
  fi
done

echo "=== Kubernetes Node Join Script ==="
echo ""

# Function to check if node is already in the cluster
check_node_exists() {
  local node_name=$1
  local node_check=$(ssh $SSH_OPTIONS $SSH_USER@$MASTER_NODE "sudo kubectl get nodes -o wide | grep -w $node_name || echo 'NotFound'")
  
  if [[ $node_check != *"NotFound"* ]]; then
    echo "Node $node_name is already part of the cluster with status:"
    echo "$node_check"
    return 0  # Node exists
  else
    return 1  # Node does not exist
  fi
}

# Function to check if kubelet is active on the worker node
check_kubelet_active() {
  local node=$1
  local kubelet_status=$(ssh $SSH_OPTIONS $SSH_USER@$node "sudo systemctl is-active kubelet || echo 'inactive'")
  
  if [[ $kubelet_status == "active" ]]; then
    echo "Kubelet is already active on $node. Node may be part of a cluster."
    return 0  # Kubelet is active
  else
    echo "Kubelet is not active on $node."
    return 1  # Kubelet is not active
  fi
}

# Get join command from master node
echo "Retrieving join command from master node..."
JOIN_COMMAND=$(ssh $SSH_OPTIONS $SSH_USER@$MASTER_NODE "sudo kubeadm token create --print-join-command")

if [ -z "$JOIN_COMMAND" ]; then
  echo "Error: Failed to retrieve join command from master node."
  exit 1
fi

echo "Retrieved join command successfully."
echo ""

# Join each worker node to the cluster
for node in "${WORKER_NODES[@]}"; do
  echo "Processing node $node..."
  
  # Check if node is reachable
  if ! ssh $SSH_OPTIONS $SSH_USER@$node "exit" >/dev/null 2>&1; then
    echo "Warning: Cannot connect to $node. Skipping..."
    continue
  fi
  
  # Check if node is already part of the cluster
  if check_node_exists $node; then
    echo "Skipping join process for $node."
    continue
  fi
  
  # Check if kubelet is active on the node
  if check_kubelet_active $node; then
    echo "Kubelet is active but node is not in cluster. Resetting Kubernetes on $node..."
    ssh $SSH_OPTIONS $SSH_USER@$node "sudo kubeadm reset -f"
    echo "Reset completed on $node."
  fi
  
  # Run join command on the worker node
  echo "Joining $node to the cluster..."
  ssh $SSH_OPTIONS $SSH_USER@$node "sudo $JOIN_COMMAND"
  
  if [ $? -eq 0 ]; then
    echo "Successfully joined $node to the cluster!"
    
    # Verify the node was actually added
    sleep 10  # Give some time for node to register
    if check_node_exists $node; then
      echo "Verified $node is now part of the cluster."
    else
      echo "Warning: $node was not found in the cluster after join command."
    fi
  else
    echo "Failed to join $node to the cluster."
  fi
  
  echo ""
done

# Verify final cluster status
echo "Final cluster status:"
ssh $SSH_OPTIONS $SSH_USER@$MASTER_NODE "sudo kubectl get nodes -o wide"

echo ""
echo "=== Copying Kubernetes admin config to local machine ==="

# Create local .kube directory if it doesn't exist
if [ ! -d "$LOCAL_KUBE_DIR" ]; then
  echo "Creating local directory $LOCAL_KUBE_DIR..."
  mkdir -p "$LOCAL_KUBE_DIR"
fi

# Backup existing config if it exists
if [ -f "$LOCAL_KUBE_CONFIG" ]; then
  echo "Backing up existing kubectl config to ${LOCAL_KUBE_CONFIG}.bak..."
  cp "$LOCAL_KUBE_CONFIG" "${LOCAL_KUBE_CONFIG}.bak"
fi

# Create a temporary file on the master node with correct permissions
echo "Creating a temporary copy of admin.conf with correct permissions..."
ssh $SSH_OPTIONS $SSH_USER@$MASTER_NODE "sudo cp /etc/kubernetes/admin.conf /tmp/k8s-admin.conf && sudo chmod 644 /tmp/k8s-admin.conf && sudo chown $SSH_USER:$SSH_USER /tmp/k8s-admin.conf"

# Copy the temporary admin.conf from master to local machine
echo "Copying Kubernetes admin config from $MASTER_NODE to local machine..."
scp $SSH_OPTIONS $SSH_USER@$MASTER_NODE:"/tmp/k8s-admin.conf" "$LOCAL_KUBE_CONFIG"

# Clean up the temporary file
ssh $SSH_OPTIONS $SSH_USER@$MASTER_NODE "rm /tmp/k8s-admin.conf"

if [ -f "$LOCAL_KUBE_CONFIG" ]; then
  echo "Successfully copied admin.conf to $LOCAL_KUBE_CONFIG"
  chmod 600 "$LOCAL_KUBE_CONFIG"
  echo "You can now run kubectl commands from your local machine."
  
  # Test the connection
  if command_exists kubectl; then
    echo "Testing connection to cluster..."
    kubectl --kubeconfig="$LOCAL_KUBE_CONFIG" get nodes
  else
    echo "kubectl not found. Please install it to manage your cluster from this machine."
  fi
else
  echo "Failed to copy admin.conf from master node."
fi

echo ""
echo "=== Node join process completed ==="
