$root = if ($root -eq $null) { "https://github.com/microsoft/MSUS-Security-Research/blob/main/POC" } else { $root }
$failures = 0
$workspace_name = if ($workspace_name -eq $null) { read-host "POC Name" + "-" + [GUID]::NewGuid().Guid.substring(0,4) } else { $workspace_name }
$resourceGroup_name = if ($resourceGroup_name -eq $null) { "$workspace_name-rg" } else { $resourceGroup_name }
$poc_result = az deployment sub create --template-uri "$root/startpoc.json" --location eastus --parameters workspace_name=$workspace_name,resourceGroup_name=$resourceGroup_name,root=$root
$poc_result_state = ($poc_result | convertfrom-json).properties.provisioningState
 if($poc_result2_state -eq "Succeeded"){write-host "Logic App deployment $poc_result_state"}else{write-host "--Logic App deployment $poc_result_state"; $failures++}
$poc_result2 = az deployment sub create --template-uri "$root/roleassignment.json" --parameters workspace_name=$workspace_name --location eastus
$poc_result2_state = ($poc_result2 | convertfrom-json).properties.provisioningState
 if($poc_result2_state -eq "Succeeded"){write-host "Role assignment $poc_result2_state"}else{write-host "--Role assignment $poc_result2_state"; $failures++}
connect-azuread
$directory = get-azureaddomain | ?{ $_ -match '(.*?).onmicrosoft.com' -and $_ -notmatch '.*?\..*?.onmicrosoft.com' } | where AuthenticationType -eq Managed | select -ExpandProperty Name -first 1
$u = "$workspace_name@$directory"
$p = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes([System.GUID]::NewGuid().Guid))
$user = az ad user create --user-principal-name $u --password $p --display-name "VSOC Analyst $workspace_name"
$user_state = ($user | convertfrom-json).userPrincipalName
$currentUserId = az ad signed-in-user show --query objectId
 if($user_state){write-host "Virtual SOC analyst $user_state Created";}else{write-host "--Virtual SOC analyst Failed"; $failures++}
$poc_result3 = az deployment group create --template-uri "$root/kvdeploy.json" --parameters workspace_name=$workspace_name userId=$currentUserId --resource-group "$workspace_name-rg"
$poc_result3_state = ($poc_result3 | convertfrom-json).properties.provisioningState
 if($poc_result3_state -eq "Succeeded"){write-host "Key Vault deployment $poc_result3_state"}else{write-host "--Key Vault deployment $poc_result3_state"; $failures++}
$kvs = az keyvault secret set --vault-name "$workspace_name-kv" --name "$workspace_name-vsoc" --value $p
 if($kvs){write-host "Key vault VSOC set Succeeded";}else{write-host "--Key vault vsoc set Failed"; $failures++}
$kvs = $null
$p = $null
if($failures -eq 0){write-host "$workspace_name deployment Completed"}else{write-host "$workspace_name deployment Completed with Failures ($failures)"}