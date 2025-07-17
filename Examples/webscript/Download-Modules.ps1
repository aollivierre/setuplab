
function Download-Modules {
    param (
        [array]$scriptDetails  # Array of script details, including URLs
    )

    $processList = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

    foreach ($scriptDetail in $scriptDetails) {
        $process = Invoke-WebScript -url $scriptDetail.Url
        if ($process) {
            $processList.Add($process)
        }
    }

    # Optionally wait for all processes to complete
    foreach ($process in $processList) {
        $process.WaitForExit()
    }
}