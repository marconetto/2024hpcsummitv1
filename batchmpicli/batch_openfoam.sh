#!/usr/bin/env bash

set -x
SKU=Standard_HB120rs_v3
# VMIMAGE=microsoft-dsvm:ubuntu-hpc:2204:latest
VMIMAGE=almalinux:almalinux-hpc:8_6-hpc-gen2:latest
# NODEAGENTSKUID="batch.node.ubuntu 22.04"
NODEAGENTSKUID="batch.node.el 8"
REGION=eastus

STORAGEFILE=data

JSON_POOL=pool_nfs.json
JSON_TASK=task_mpi.json

VNETADDRESS=10.12.0.0

VPNRG=nettovpn2
VPNVNET=nettovpn2vnet1

ADMINUSER=azureuser
DNSZONENAME="privatelink.blob.core.windows.net"

POOLNAME=mpipool
JOBNAME=mpijob

function setup_variables() {

  STORAGEACCOUNT="$RG"sa
  BATCHACCOUNT="$RG"ba
  KEYVAULT="$RG"kv

  VMNAMEPREFIX="$RG"vm
  VMVNETNAME="$RG"VNET
  VMSUBNETNAME="$RG"SUBNET

}

function get_random_code() {

  random_number=$((RANDOM % 9000 + 1000))
  echo "$random_number"
}

function create_resource_group() {

  az group create --location "$REGION" \
    --name "$RG"
}

function create_vnet_subnet() {

  az network vnet create -g "$RG" \
    -n "$VMVNETNAME" \
    --address-prefix "$VNETADDRESS"/16 \
    --subnet-name "$VMSUBNETNAME" \
    --subnet-prefixes "$VNETADDRESS"/24
}

function create_vm() {

  echo "creating $VMNAME for testing"

  vmname="${VMNAMEPREFIX}_"$(get_random_code)

  FILE=/tmp/vmcreate.$$
  cat <<EOF >"$FILE"
#cloud-config

runcmd:
- echo "mounting shared storage on the vm"
- mkdir /nfs
- mount -o sec=sys,vers=3,nolock,proto=tcp  $STORAGEACCOUNT.blob.core.windows.net:/$STORAGEACCOUNT/$STORAGEFILE /nfs/
EOF

  az vm create -n "$vmname" \
    -g "$RG" \
    --image "$VMIMAGE" \
    --size "$SKU" \
    --vnet-name "$VMVNETNAME" \
    --subnet "$VMSUBNETNAME" \
    --public-ip-address "" \
    --admin-username "$ADMINUSER" \
    --generate-ssh-keys \
    --custom-data "$FILE"

  private_ip=$(az vm show -g "$RG" -n "$vmname" -d --query privateIps -otsv)
  echo "Private IP of $vmname: ${private_ip}"
}

function peer_vpn() {

  echo "Peering vpn with created vnet"

  curl https://raw.githubusercontent.com/marconetto/azadventures/main/chapter3/create_peering_vpn.sh -O

  bash ./create_peering_vpn.sh "$VPNRG" "$VPNVNET" "$RG" "$VMVNETNAME"
}

function get_subnetid() {

  subnetid=$(az network vnet subnet show \
    --resource-group "$RG" --vnet-name "$VMVNETNAME" \
    --name "$VMSUBNETNAME" \
    --query "id" -o tsv)

  echo "$subnetid"
}

function create_storage_account_files_nfs() {

  # echo "$STORAGEACCOUNT"
  # az storage account create \
  #   --resource-group "$RG" \
  #   --name "$STORAGEACCOUNT" \
  #   --location "$REGION" \
  #   --kind StorageV2 \
  #   --sku Premium_LRS \
  #   --enable-nfs-v3 true \
  #   --https-only false \
  #   --output none

  az storage account create \
    --resource-group "$RG" \
    --name "$STORAGEACCOUNT" \
    --location "$REGION" \
    --kind BlockBlobStorage \
    --sku Premium_LRS \
    --https-only false \
    --enable-hierarchical-namespace true \
    --enable-nfs-v3 true \
    --default-action Deny

  az network vnet subnet update --resource-group "$RG" \
    --vnet-name "$VMVNETNAME" \
    --name "$VMSUBNETNAME" \
    --service-endpoints Microsoft.Storage

  az storage account network-rule add --resource-group "$RG" \
    --account-name "$STORAGEACCOUNT" \
    --vnet-name "$VMVNETNAME" \
    --subnet "$VMSUBNETNAME"

  # az storage account network-rule add \
  #   --account-name mystor
  #   --resource-group MyResourceGroup \
  #   --vnet-name myVNet \
  #   --subnet mySubnet

  # disable secure transfer is required for nfs support
  #  az storage account update --https-only false \
  #   --name "$STORAGEACCOUNT" --resource-group "$RG"

  az storage container-rm create \
    --storage-account "$STORAGEACCOUNT" \
    --name "$STORAGEFILE" \
    --root-squash NoRootSquash
  # az storage container create \
  #   --storage-account "$STORAGEACCOUNT" \
  #   --enabled-protocol NFS \
  #   --root-squash NoRootSquash \
  #   --name "$STORAGEFILE" \
  #   --quota 100

  storage_account_id=$(az storage account show \
    --resource-group "$RG" --name "$STORAGEACCOUNT" \
    --query "id" -o tsv)

  subnetid=$(get_subnetid)

  endpoint=$(az network private-endpoint create \
    --resource-group "$RG" --name "$STORAGEACCOUNT-PrivateEndpoint" \
    --location "$REGION" \
    --subnet "$subnetid" \
    --private-connection-resource-id "${storage_account_id}" \
    --group-id "blob" \
    --connection-name "$STORAGEACCOUNT-Connection" \
    --query "id" -o tsv)

  dns_zone=$(az network private-dns zone create \
    --resource-group "$RG" \
    --name "$DNSZONENAME" \
    --query "id" -o tsv)

  vnetid=$(az network vnet show \
    --resource-group "$RG" \
    --name "$VMVNETNAME" \
    --query "id" -o tsv)

  az network private-dns link vnet create \
    --resource-group "$RG" \
    --zone-name "$DNSZONENAME" \
    --name "$VMVNETNAME-DnsLink" \
    --virtual-network "$vnetid" \
    --registration-enabled false

  endpoint_nic=$(az network private-endpoint show \
    --ids "$endpoint" \
    --query "networkInterfaces[0].id" -o tsv)

  endpoint_ip=$(az network nic show \
    --ids "${endpoint_nic}" \
    --query "ipConfigurations[0].privateIPAddress" -o tsv)

  az network private-dns record-set a create \
    --resource-group "$RG" \
    --zone-name "$DNSZONENAME" \
    --name "$STORAGEACCOUNT"

  az network private-dns record-set a add-record \
    --resource-group "$RG" \
    --zone-name "$DNSZONENAME" \
    --record-set-name "$STORAGEACCOUNT" \
    --ipv4-address "${endpoint_ip}"

  #az storage share-rm list -g "$RG" \
  #  --storage-account "$STORAGEACCOUNT"

  echo "inside the test VM:"
  echo "sudo mkdir /nfs ; sudo mount -o sec=sys,vers=3,nolock,proto=tcp $STORAGEACCOUNT.blob.core.windows.net:/$STORAGEACCOUNT/$STORAGEFILE /nfs/"
}

function create_keyvault() {

  echo "Creating keyVault"

  az keyvault create --resource-group "$RG" \
    --name "$KEYVAULT" \
    --location "$REGION" \
    --enable-rbac-authorization false \
    --enabled-for-deployment true \
    --enabled-for-disk-encryption true \
    --enabled-for-template-deployment true

  az keyvault set-policy --resource-group "$RG" \
    --name "$KEYVAULT" \
    --spn ddbf3205-c6bd-46ae-8127-60eb93363864 \
    --key-permissions all \
    --secret-permissions all
}

function create_batch_account_with_usersubscription() {

  # Allow Azure Batch to access the subscription (one-time operation).
  subid=$(az account show | jq -r '.id')
  az role assignment create --assignee ddbf3205-c6bd-46ae-8127-60eb93363864 --role contributor --scope "/subscriptions/$subid"

  # az role assignment create --assignee ddbf3205-c6bd-46ae-8127-60eb93363864 --role contributor

  create_keyvault

  # Create the Batch account, referencing the Key Vault either by name (if they
  # exist in the same resource group) or by its full resource ID.
  echo "Creating batchAccount"
  az batch account create --resource-group "$RG" \
    --name "$BATCHACCOUNT" \
    --location "$REGION" \
    --keyvault "$KEYVAULT"
  # --storage-account $STORAGEACCOUNT    # does not support azure fileshare
}

function login_batch_with_usersubcription() {

  # Authenticate directly against the account for further CLI interaction.
  # Batch accounts that allocate pools in the user's subscription must be
  # authenticated via an Azure Active Directory token.
  echo "login into the batch account with user subscription"
  az batch account login \
    --name "$BATCHACCOUNT" \
    --resource-group "$RG"
}

function wrap_commands_in_shell() {
  local commands=("$@")
  local joined_commands

  joined_commands=$(
    IFS=";"
    echo "${commands[*]}"
  )

  echo "/bin/bash -c '${joined_commands}; wait'"
}

function set_start_task_command() {
  local var_name=$1
  local commands

  read -r -d '' commands <<EOF
sleep 60
sudo chown _azbatch:_azbatchgrp /mnt/batch/tasks/fsmounts/data
sudo rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
sudo yum upgrade -y almalinux-release
sudo yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
sudo yum install -y cvmfs
sudo yum install -y https://github.com/EESSI/filesystem-layer/releases/download/latest/cvmfs-config-eessi-latest.noarch.rpm
sudo bash -c  \"echo 'CVMFS_CLIENT_PROFILE=\"single\"' > /etc/cvmfs/default.local\"
sudo bash -c \"echo 'CVMFS_QUOTA_LIMIT=10000' >> /etc/cvmfs/default.local\"
sudo cvmfs_config setup
sudo mount -t cvmfs software.eessi.io /cvmfs/software.eessi.io
sudo mount -t cvmfs pilot.eessi-hpc.org /cvmfs/pilot.eessi-hpc.org
df -Tha
EOF

  IFS=$'\n' read -r -d '' -a commands_array <<<"$commands"

  printf -v "$var_name" "%s" "$(wrap_commands_in_shell "${commands_array[@]}")"
}

function get_node_agent_sku() {

  # TODO: AUTOMATE
  echo "${NODEAGENTSKUID}"
}

function create_pool() {

  # e.g.: VMIMAGE=almalinux:almalinux-hpc:8_6-hpc-gen2:latest
  IFS=':' read -r publisher offer sku version <<<"$VMIMAGE"

  nodeagent_sku_id=$(get_node_agent_sku)
  POOLNAME="$POOLNAME"$(get_random_code)

  set_start_task_command START_TASK

  nfs_share_hostname="${STORAGEACCOUNT}.blob.core.windows.net"
  nfs_fileshare=${STORAGEFILE}
  nfs_share_directory="${STORAGEACCOUNT}/${nfs_fileshare}"
  subnetid=$(get_subnetid)

  cat <<EOF >"$JSON_POOL"
{
  "id": "$POOLNAME",
  "vmSize": "$SKU",
  "virtualMachineConfiguration": {
       "imageReference": {
            "publisher": "$publisher",
            "offer": "$offer",
            "sku": "$sku",
            "version": "$version"
        },
        "nodeAgentSkuId": "$nodeagent_sku_id"
    },
  "targetDedicatedNodes": 2,
  "enableInterNodeCommunication": true,
  "networkConfiguration": {
    "subnetId": "$subnetid",
    "publicIPAddressConfiguration": {
                "provision": "NoPublicIPAddresses"
            }
  },
  "taskSchedulingPolicy": {
    "nodeFillType": "Pack"
  },
  "targetNodeCommunicationMode": "simplified",
  "mountConfiguration": [
      {
          "nfsMountConfiguration": {
              "source": "${nfs_share_hostname}:/${nfs_share_directory}",
              "relativeMountPath": "$STORAGEFILE",
              "mountOptions": "-o sec=sys,vers=3,nolock,proto=tcp"
          }
      }
  ],
  "startTask": {
    "commandLine":"${START_TASK}",
    "userIdentity": {
        "autoUser": {
          "scope":"pool",
          "elevationLevel":"admin"
        }
    },
    "maxTaskRetryCount":1,
    "waitForSuccess":true
  }
}
EOF

  echo "create pool with nfs support"
  echo "json = $JSON_POOL"
  az batch pool create \
    --json-file "$JSON_POOL"
}

function create_job() {

  JOBNAME="$JOBNAME"$(get_random_code)
  az batch job create \
    --id "$JOBNAME" \
    --pool-id "$POOLNAME"
}

function create_run_task() {

  taskid="apprun_"$(get_random_code)

  cat <<EOF >"$JSON_TASK"
{
  "id": "$taskid",
  "displayName": "run-task",
  "commandLine": "/bin/bash -c '\$AZ_BATCH_NODE_MOUNTS_DIR/data/run_app.sh'",
  "environmentSettings": [
    {
      "name": "NODES",
      "value": "2"
    },
    {
      "name": "PPN",
      "value": "60"
    }
  ],
  "userIdentity": {
    "autoUser": {
      "scope": "pool",
      "elevationLevel": "nonadmin"
    }
  },
  "multiInstanceSettings": {
    "coordinationCommandLine": "/bin/bash -c env",
    "numberOfInstances": 2,
    "commonResourceFiles": []
  }
}
EOF

  az batch task create \
    --job-id "$JOBNAME" \
    --json-file "$JSON_TASK"
}

function creat_setup_task() {

  random_number=$(get_random_code)

  app_setup_url="https://raw.githubusercontent.com/Azure/hpcadvisor/main/examples/openfoam/appsetup_openfoam.sh"

  script_name=$(basename "$app_setup_url")

  az batch task create \
    --task-id appsetup_"${random_number}" \
    --job-id "$JOBNAME" \
    --command-line "/bin/bash -c 'cd \$AZ_BATCH_NODE_MOUNTS_DIR/${STORAGERFILE} ; pwd ; curl -sLO ${app_setup_url} ; chmod +x ${script_name} ; ./${script_name}'"
}

usage() {
  echo "Usage: $0 -r <resourcegroup>"
  echo "  -r <resourcegroup>  Resource group"
  exit
}

parse_arguments() {

  while getopts "r:" opt; do
    case ${opt} in
    r)
      option_r=$OPTARG
      ;;

    \?)
      echo "Invalid option: $OPTARG" 1>&2
      usage
      ;;
    :)
      echo "Option -$opt requires an argument." 1>&2
      usage
      ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ -z "${option_r+x}" ]; then
    echo "Missing required options."
    usage
  fi
  RG=$option_r

}

##############################################################################
# MAIN
##############################################################################
parse_arguments "$@"
setup_variables
create_resource_group
create_vnet_subnet
# peer_vpn
create_storage_account_files_nfs
create_vm
create_batch_account_with_usersubscription
login_batch_with_usersubcription
create_pool
create_job
creat_setup_task
create_run_task
