# $keepFile = 'True'

try {
    # Use String from the output of the ARM script
    $result = "$mlStudioLink"

}
catch {

    Write-Host "Unable to get URL." $_.Exception.Message

}