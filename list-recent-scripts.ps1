Get-ChildItem -Path "C:\code\setuplab" -Filter "*.ps1" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 10 | 
    Format-Table Name, LastWriteTime -AutoSize