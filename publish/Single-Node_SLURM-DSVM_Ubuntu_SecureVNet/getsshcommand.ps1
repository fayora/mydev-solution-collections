# This script returns the SSH command to connect to the VM
try {
    $result = "ssh $loginUsername@$privateIPAddress"
}
catch {
    Write-Host "Unable to retrieve the SSH command." $_.Exception.Message
}