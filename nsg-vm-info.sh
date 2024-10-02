#!/bin/bash

# Fetch all NSG information with associated NICs and VMs
nsg_info=$(az network nsg list --query "[].{NSGName:name, ResourceGroup:resourceGroup, NICs:networkInterfaces}" -o json)

# Prepare header
output="ResourceGroup\tVMName\tNSGName\tPublicIP\n"
output+="------------------------\t--------------------\t------------------------------\t----------------\n"

# Iterate through NSG info
for nsg in $(echo "${nsg_info}" | jq -c '.[]'); do
    nsg_name=$(echo "${nsg}" | jq -r '.NSGName')
    resource_group=$(echo "${nsg}" | jq -r '.ResourceGroup')
    nic_list=$(echo "${nsg}" | jq -c '.NICs')

    # If NSG has associated NICs
    if [[ "$nic_list" != "null" && "$nic_list" != "[]" ]]; then
        for nic in $(echo "${nic_list}" | jq -r '.[] | @base64'); do
            _jq() {
                printf "%s" "${nic}" | base64 --decode | jq -r "${1}" | tr -d '\n'
            }

            nic_id=$(_jq '.id')

            # Suppress errors for the following commands
            vm_id=$(az network nic show --ids "$nic_id" --query "virtualMachine.id" -o tsv 2>/dev/null)

            # Get VM name from the VM ID if it exists
            if [ -z "$vm_id" ]; then
                vm_name="Not Assigned"
            else
                vm_name=$(az vm show --ids "$vm_id" --query "name" -o tsv 2>/dev/null)
            fi

            # Fetch the public IP associated with the NIC, if available
            public_ip_id=$(az network nic show --ids "$nic_id" --query "ipConfigurations[0].publicIPAddress.id" -o tsv 2>/dev/null)
            if [ -z "$public_ip_id" ]; then
                public_ip="Not Assigned"
            else
                public_ip=$(az network public-ip show --ids "$public_ip_id" --query "ipAddress" -o tsv 2>/dev/null)
            fi

            # Append the results to the output
            output+="${resource_group}\t${vm_name}\t${nsg_name}\t${public_ip}\n"
        done
    else
        # If NSG is not associated with any NICs, no VM or public IP is available
        output+="${resource_group}\tNo VM Associated\t${nsg_name}\tNo Public IP\n"
    fi
done

# Print the output in a formatted grid
echo -e "$output" | column -t -s $'\t'
