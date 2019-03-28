function Connect-F5 {

    param(
        [switch]$Force
    )

    $SessionFile = $([system.io.path]::GetTempPath()+"f5-session.xml")
    $Session = $null

    if($Force) {

        Remove-Item -Path $SessionFile -ErrorAction SilentlyContinue
        
    } elseif(Test-Path($SessionFile)) {

        $Session = Import-CliXml -Path $SessionFile

        $Headers = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.String]"
        $Headers.add('X-F5-Auth-Token',$Session.WebSession.Headers.'X-F5-Auth-Token')
        $Headers.add('Token-Expiration',$Session.WebSession.Headers.'Token-Expiration')
        $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $WebSession.Headers = $Headers
        $Session.WebSession = $WebSession
        $Session = $Session | Add-Member -Name GetLink -MemberType ScriptMethod {
            param($Link)
            $Link -replace 'localhost', $this.Name
        } -PassThru 

        if($(Get-F5Status -F5Session $Session -ErrorAction SilentlyContinue) -eq "ACTIVE"){
            write-host -foregroundcolor white "Connected to active F5: $($Session.Name)"
            return $Session
        } else {
            write-host -foregroundcolor white "Not connected to an ACTIVE F5"
        }
    } else {
        write-host -foregroundcolor white "Creating a new F5 session file"
    }

    $Cred = Set-F5CredFile
    if($Cred -eq $null){
        return $Session
    }

    $F5Names = Set-F5NamesFile
    if($F5Names -eq $null){
        return $Session
    }
    
    $ActiveFound = $false

    #For each F5 name (or ip) in the f5-names.xml file
    $F5Names | %{

        #If the ACTIVE F5 have not been found yet
        if($ActiveFound -ne $true){

            write-host -nonewline "Checking state of $_..."

            #Get session object
            $Session = New-F5Session -LTMName $_ -LTMCredentials $Cred -PassThru -ErrorAction SilentlyContinue

            #If connection failed
            if($Session.LTMVersion -eq '0.0.0.0'){
                write-host -foregroundcolor red "Failed"
                $Session = $null

            #If connection is successful, check if its the ACTIVE F5
            } else {
                $F5Status = Get-F5Status -F5Session $Session -ErrorAction SilentlyContinue
                if($F5Status -eq 'ACTIVE'){
                    write-host -foregroundcolor green $F5Status
                    $Session | Export-CliXml -Path $SessionFile
                    write-host -foreground Magenta "Creating session on active F5: $($Session.Name)"
                    $ActiveFound = $true
                } else {
                    write-host -foregroundcolor yellow $F5Status
                }
            }
        }
    }
    if($Session -eq $null){
        write-host -foregroundcolor red "Cannot find active F5"
        if((read-host "Do you want to enter new F5 credentials ? (y/n)") -eq 'y'){
            Set-F5CredFile -Force
        }
    }
    return $Session
}

Function Set-F5CredFile {
    param(
        [string]$Username,
        [string]$Password,
        [switch]$Force
    )

    $CredFile = $([system.io.path]::GetTempPath()+"f5-cred.xml")

    #If username and password specified at arguments
    if(! ([string]::IsNullOrEmpty($Username))){
        write-host "USername: $Username"
        if([string]::IsNullOrEmpty($Password)){
            $Password = Read-Host -assecurestring "Password: "
        }
        $secureStringPwd = $Password | ConvertTo-SecureString -AsPlainText -Force 
        $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $secureStringPwd
        $Cred | Export-CliXml -Path $CredFile
        return $Cred
    }

    write-host -nonewline "Importing credential..."
    $Cred = $null
    if(!($Force)){
        try{
            $Cred = Import-CliXml -Path $CredFile
            write-host -foregroundcolor green "OK ($($Cred.UserName))"
        }catch{
            write-host -foregroundcolor red "Not found"
    }
        
    }
    if($Cred -eq $null){
        write-host -foregroundcolor cyan "Creating credential file..."
        try {
            $Cred = Get-Credential
        } catch {
            write-host -foregroundcolor red "Failed to create credential file"
            return $Cred
        }
        if($Cred -eq $null){
            write-host -foregroundcolor red "Failed to create credential file"
        } else {
            $Cred | Export-CliXml -Path $CredFile
            write-host -foregroundcolor green "Credential file created"
        }
    }
    return $Cred
}

Function Set-F5NamesFile {

    param(
        [switch]$Force
    )

    $F5NamesFile = $([system.io.path]::GetTempPath()+"f5-names.xml")
    $F5Names = $null

    if(!($Force)){
        write-host -nonewline "Importing F5 names..."
        try{
            $F5Names = Import-CliXml -Path $F5NamesFile
            write-host -foregroundcolor green "OK"
        }catch{
            write-host -foregroundcolor red "Not found"
        }
    }

    if($F5Names -eq $null){
        write-host -foregroundcolor cyan "Creating F5 names file..."
        $F5Names = @()
        do {
            $input = (Read-Host "Enter F5 names")
            if ($input -ne '') {$F5Names += $input}
        }
        until ($input -eq '')
        if($F5Names.count -ne 0){
            $F5Names | Export-CliXml -Path $F5NamesFile
            write-host -foregroundcolor green "F5 names file created"
        } else {
            write-host -foregroundcolor red "Failed to create F5 names file"
        }
    }
    return $F5Names
}