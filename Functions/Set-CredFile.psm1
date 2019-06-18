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
        [string]$Path = $([system.io.path]::GetTempPath()+"f5-cred.xml"),
        [string]$Username,
        [string]$Password,
        [switch]$Force
    )

    if($VerbosePreference -ne "SilentlyContinue"){
        $Verbose = $true
    } else {
        $Verbose = $false
    }

    Write-Verbose "Using credential file: $Path"

    #If username and password specified as arguments
    if(! ([string]::IsNullOrEmpty($Username))){
        Write-Verbose "Using username: $Username"
        if([string]::IsNullOrEmpty($Password)){
            $Password = Read-Host -AsSecureString "Password"
        }
        $secureStringPwd = $Password | ConvertTo-SecureString -AsPlainText -Force 
        $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $secureStringPwd
        $Credential | Export-CliXml -Path $Path -Verbose:$Verbose
        Write-Verbose "Exported credential to $Path"
        return $Credential
    }

    #Try to import the credentials from xml file
    $Credential = [System.Management.Automation.PSCredential]::Empty
    if(!($Force)){
        try{
            $Credential = Import-CliXml -Path $Path -Verbose:$Verbose
            Write-Verbose "Successfully imported credential (Username: $($Cred.UserName))"
        }catch{
            Write-Warning "Unable to import credential"
        }
    }

    #If unable to import existing creds, we create new one
    if($Credential -eq [System.Management.Automation.PSCredential]::Empty){
        Write-Verbose "Creating credential file..."
        try {
            $Credential = Get-Credential
        } catch {
            Write-Warning "Failed to create credential file"
            return $Credential
        }
        if($Credential -eq [System.Management.Automation.PSCredential]::Empty){
            Write-Warning "Failed to create credential file"
        } else {
            $Credential | Export-CliXml -Path $Path -Verbose:$Verbose
            Write-Verbose "Exported cred file to $Path"
        }
    }

    return $Credential
}