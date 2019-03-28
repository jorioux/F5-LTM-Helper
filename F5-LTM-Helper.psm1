#Check if F5-LTM module is installed
if (!(Get-Command Get-F5Status -ErrorAction SilentlyContinue)){
    Write-Warning 'You must install the "F5-LTM" module'
    Write-Warning '--> Install-Module F5-LTM'
}