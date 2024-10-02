#!/bin/bash

# Fetch all NSG information with associated NICs
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

            # Check if the NIC is attached to a VM
            vm_id=$(az network nic show --ids "$nic_id" --query "virtualMachine.id" -o tsv 2>/dev/null)

            # Proceed only if NIC is attached to a VM
            if [ -n "$vm_id" ]; then
                # Get VM name from the VM ID
                vm_name=$(az vm show --ids "$vm_id" --query "name" -o tsv 2>/dev/null)

                # Fetch the public IP associated with the NIC, if available
                public_ip_id=$(az network nic show --ids "$nic_id" --query "ipConfigurations[0].publicIPAddress.id" -o tsv 2>/dev/null)
                if [ -z "$public_ip_id" ]; then
                    public_ip="Not Assigned"
                else
                    public_ip=$(az network public-ip show --ids "$public_ip_id" --query "ipAddress" -o tsv 2>/dev/null)
                fi

                # Append the results to the output
                output+="${resource_group}\t${vm_name}\t${nsg_name}\t${public_ip}\n"
            fi
        done
    fi
done

# Print the output in a formatted grid
echo -e "$output" | column -t -s $'\t'
