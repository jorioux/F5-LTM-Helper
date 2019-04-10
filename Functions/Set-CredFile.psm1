Function Set-CredFile {

    <#
        .SYNOPSIS
            Stores credential into an xml file
        .EXAMPLE
            Set-CredFile
        .EXAMPLE
            Set-CredFile -Username admin -Path c:\temp\admin-cred.xml
        .EXAMPLE
            Set-CredFile -Force
        .LINK
            https://github.com/jorioux/F5-LTM-Helper
    #>

    param(
        [Parameter(Mandatory = $false)]
        [string]$Path=$([system.io.path]::GetTempPath()+"cred.xml"),
        [string]$Username,
        [string]$Password,
        [switch]$Force
    )

    if($VerbosePreference -ne "SilentlyContinue"){
        $Verbose = $true
    } else {
        $Verbose = $false
    }

    Write-Verbose "Using cred file: $Path"

    #If username and password specified at arguments
    if(! ([string]::IsNullOrEmpty($Username))){
        Write-Verbose "Using username: $Username"
        if([string]::IsNullOrEmpty($Password)){
            $Password = Read-Host -AsSecureString "Password"
        }
        $secureStringPwd = $Password | ConvertTo-SecureString -AsPlainText -Force 
        $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $secureStringPwd
        $Cred | Export-CliXml -Path $Path -Verbose:$Verbose
        Write-Verbose "Exported credential to $Path"
        return $Cred
    }

    #Try to import the credentials from xml file
    $Cred = $null
    if(!($Force)){
        try{
            $Cred = Import-CliXml -Path $Path -Verbose:$Verbose
            Write-Verbose "`tSuccessfully imported credential (Username: $($Cred.UserName))"
        }catch{
            Write-Warning "`tUnable to import credential"
        }
    }

    #If unable to import existing creds, we create new one
    if($Cred -eq $null){
        Write-Verbose "Creating credential file..."
        try {
            $Cred = Get-Credential
        } catch {
            Write-Warning "`tFailed to create credential file"
            return $Cred
        }
        if($Cred -eq $null){
            Write-Warning "`tFailed to create credential file"
        } else {
            $Cred | Export-CliXml -Path $Path -Verbose:$Verbose
            Write-Verbose "`tExported cred file to $Path"
        }
    }

    return $Cred
}