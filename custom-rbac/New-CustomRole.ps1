# Sign in to authenticate Azure Resource Manager cmdlet requests
Add-AzureRmAccount

# Get the subscription that the role will be assignable within
$SubscriptionId = $(Get-AzureRmSubscription).Id

# Use the Network Contributor role as a template
$role = Get-AzureRmRoleDefinition "Network Contributor"

# Modify the role to suit a custom CloudAcademy Network Contributor role
$role.Id = $null
$role.Name = "CloudAcademy Network Contributor"
$role.Description = "Can view and modify NSG’s but cannot view Effective Security Rules"
$role.Actions.Clear()
$role.Actions.Add("Microsoft.Authorization/*/read")
$role.Actions.Add("Microsoft.Insights/alertRules/*")
$role.Actions.Add("Microsoft.Network/*/read")
$role.Actions.Add("Microsoft.Compute/virtualMachines/*/read")
$role.Actions.Add("Microsoft.Resources/subscriptions/resourceGroups/read")
$role.Actions.Add("Microsoft.Support/*")
# You will see later what happens as a result of the following action not being added
#$role.Actions.Add("Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action")

# This role is only assignable within your subscription
$role.AssignableScopes.Clear()
$role.AssignableScopes.Add("/subscriptions/" + $SubscriptionId)

# Create the role
New-AzureRmRoleDefinition -Role $role