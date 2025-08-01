# Simple remote test
$cred = Get-Credential -UserName "xyz\administrator" -Message "Enter password"
Enter-PSSession -ComputerName 198.18.1.157 -Credential $cred