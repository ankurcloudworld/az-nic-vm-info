#!/bin/bash

# Fetch all NICs information with their associated VM and Public IP
nic_info=$(az network nic list --query "[].{NICName:name, VMId:virtualMachine.id, ResourceGroup:resourceGroup, PublicIPId:ipConfigurations[0].publicIPAddress.id}" -o json)

# Prepare header
output="ResourceGroup\tVMName\tNICName\tPublicIP\n"
output+="------------------------\t--------------------\t------------------------------\t----------------\n"

# Iterate through NIC info
for nic in $(echo "${nic_info}" | jq -c '.[]'); do
    nic_name=$(echo "${nic}" | jq -r '.NICName')
    resource_group=$(echo "${nic}" | jq -r '.ResourceGroup')
    vm_id=$(echo "${nic}" | jq -r '.VMId')
    public_ip_id=$(echo "${nic}" | jq -r '.PublicIPId')

    # Get VM name from the VM ID
    if [ -z "$vm_id" ]; then
        vm_name="Not Assigned"
    else
        vm_name=$(az vm show --ids "$vm_id" --query "name" -o tsv)
    fi

    # Fetch the Public IP address if available
    if [ -z "$public_ip_id" ]; then
        public_ip="Not Assigned"
    else
        public_ip=$(az network public-ip show --ids "$public_ip_id" --query "ipAddress" -o tsv)
    fi

    # Append the results to the output
    output+="${resource_group}\t${vm_name}\t${nic_name}\t${public_ip}\n"
done

# Print the output in a formatted grid
echo -e "$output" | column -t -s $'\t'
