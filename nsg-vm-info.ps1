$nsg_info = az network nsg list --query "[].{NSGName:name, ResourceGroup:resourceGroup, NICs:networkInterfaces}" -o json | ConvertFrom-Json

$output = @()


foreach ($nsg in $nsg_info) {
    $nsg_name = $nsg.NSGName
    $resource_group = $nsg.ResourceGroup
    $nic_list = $nsg.NICs

    
    if ($nic_list -ne $null -and $nic_list.Count -gt 0) {
        foreach ($nic in $nic_list) {
            $nic_id = $nic.id

            # Check if the NIC is attached to a VM
            $vm_id = az network nic show --ids $nic_id --query "virtualMachine.id" -o tsv 2>$null

            
            if (-not [string]::IsNullOrEmpty($vm_id)) {
                # Get VM name from the VM ID
                $vm_name = az vm show --ids $vm_id --query "name" -o tsv 2>$null

                
                $public_ip_id = az network nic show --ids $nic_id --query "ipConfigurations[0].publicIPAddress.id" -o tsv 2>$null
                if (-not [string]::IsNullOrEmpty($public_ip_id)) {
                    $public_ip = az network public-ip show --ids $public_ip_id --query "ipAddress" -o tsv 2>$null
                } else {
                    $public_ip = "Not Assigned"
                }

                $output += [pscustomobject]@{
                    ResourceGroup = $resource_group
                    VMName        = $vm_name
                    NSGName       = $nsg_name
                    PublicIP      = $public_ip
                }
            }
        }
    }
}

# Print the output in a formatted table
$output | Format-Table -AutoSize
