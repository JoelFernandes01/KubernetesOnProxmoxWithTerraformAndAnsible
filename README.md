# Kubernetes On Proxmox With Terraform And Ansible

Configuration and documentation for how to set up Kubernetes on Proxmox with Cloud Init, Ubuntu, TerraForm and Ansible

## Advisory

This set of instructions has been tested on Ubuntu VMs running on Proxmox, and cloned using cloud-init.

**You may be tempted to try LXC on Proxmox but it throws errors on the Kubernetes installation swap memory step.**

You should run them from an Infrastructure as Code staging VM, separate from the Kubernetes cluster, but can be your workstation if you run on Linux natively.

**WSL has some file system limitations that will make this hard with Ansible**

The Terraform files are designed to work with the Ubuntu 24.04 cloud-init image.
You will also need to customise your image as per [https://youtu.be/HbBblJOZs-c](https://youtu.be/HbBblJOZs-c)


## Pre-requisites

You will need the following to be installed and set up:

- Terraform
- Ansible
- sshpass

These can all be installed using:

```
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
```
Verify the hashicorp key using this command as here: [https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
```
gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint
```
Install the key and the rest of the packages:
```
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list


sudo apt-add-repository ppa:ansible/ansible
sudo apt update -y
sudo apt install ansible sshpass terraform -y

```

## SSH Key Setup

Setup the cloud-init image as previously, but an sshkey is required for this configuration so will need to be generated as per [https://developer.hashicorp.com/terraform/tutorials/provision/cloud-init](https://developer.hashicorp.com/terraform/tutorials/provision/cloud-init)

```
ssh-keygen -t rsa -C "your_email@example.com" -f ./tf-cloud-init
```

When prompted, press enter to leave the passphrase blank on this key.

You will need to copy the key into the Terraform files, and will reference it in Ansible and SSH connections.

## Terraform Setup

Terraform will do the heavy listing with creating the VMs for the Kubernetes cluster.
Customise the main.tf with Proxmox Provider:
- pm_api_url.
- pm_user and pm_password or pm_api_token_id and pm_api_token_secret.
- target_node for the k8s-master and k8s-node sections.

You should also set:
- Relevant IP addresses, DNS and Gateway details for your environment.
- VMIDs (these are important as they stop Proxmox trying to re-use the same VMID immediately).
- cloud-init template name.

With these configured, run the following in the terraform subdirectory.
```
terraform init
terraform apply
```

Confirm by typing "yes" and wait for the cloning to complete.

## Ansible Setup
