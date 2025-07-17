Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | 
    Where-Object { $_.DisplayName -like '*Warp*' } | 
    Select-Object DisplayName, PSChildName, Publisher, DisplayVersion | 
    Format-List