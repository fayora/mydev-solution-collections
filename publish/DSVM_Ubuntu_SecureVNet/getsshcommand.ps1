# This script returns the SSH command to connect to the VM
try {
    $result = "ssh $loginUsername@$privateIPAddress"
}
catch {
    Write-Host "Unable to get IP address." $_.Exception.Message
}

