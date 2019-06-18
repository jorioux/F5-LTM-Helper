function Connect-F5 {

    <#
        .SYNOPSIS
            Automatically connects to an active F5
        .EXAMPLE
            Connect-F5
        .LINK
            https://github.com/jorioux/F5-LTM-Helper
    #>

    param(
        [Parameter(Mandatory = $false)]
        [string]$SessionFile = $([system.io.path]::GetTempPath()+"f5-session.xml"),
        [string]$NamesFile = $([system.io.path]::GetTempPath()+"f5-names.xml"),
        [string]$CredFile = $([system.io.path]::GetTempPath()+"f5-cred.xml"),
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,
        [switch]$Force
    )

    if($VerbosePreference -ne "SilentlyContinue"){
        $Verbose = $true
    } else {
        $Verbose = $false
    }

    $Session = $null

    Write-Verbose "Using session file: $SessionFile"

    if($Force) {

        Remove-Item -Path $SessionFile -ErrorAction SilentlyContinue -Verbose:$Verbose
        
    } elseif(Test-Path($SessionFile)) {

        $Session = Import-CliXml -Path $SessionFile -Verbose:$Verbose

        # rehydrating the session object from xml file
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

        # if active F5 have been found, return the session
        if($(Get-F5Status -F5Session $Session -ErrorAction SilentlyContinue -Verbose:$Verbose) -eq "ACTIVE"){
            Write-Verbose "Connected to active F5: $($Session.Name)"
            Write-Verbose $("Session token expiration: "+$Session.WebSession.Headers.'Token-Expiration')
            return $Session
        } else {
            Write-Warning "Not connected to an ACTIVE F5"
        }
    } else {
        Write-Verbose "Creating a new F5 session file"
    }

    # if Credential not specified from parameter, we get it from xml file
    if($Credential -eq [System.Management.Automation.PSCredential]::Empty){
        try{
            $Credential = Set-CredFile -Path $CredFile -Verbose:$Verbose
        } catch {
            return $Session
        }
        if($Credential -eq [System.Management.Automation.PSCredential]::Empty){
            return $Session
        }
    }

    $F5Names = Set-F5NamesFile -Path $NamesFile -Verbose:$Verbose
    if($null -eq $F5Names){
        return $Session
    }
    
    $ActiveFound = $false

    #For each F5 name (or ip) in the f5-names.xml file
    $F5Names | ForEach-Object {

        #If the ACTIVE F5 have not been found yet
        if($ActiveFound -ne $true){

            Write-Verbose "Checking state of $_..."

            #Get session object
            $Session = New-F5Session -LTMName $_ -LTMCredentials $Credential -PassThru -ErrorAction SilentlyContinue -Verbose:$Verbose

            #If connection failed
            if($Session.LTMVersion -eq '0.0.0.0'){
                Write-Warning "Failed to connect to $_"
                $Session = $null

            #If connection is successful, check if its the ACTIVE F5
            } else {
                Write-Verbose "-->`tConnection is successful on $_"
                $F5Status = Get-F5Status -F5Session $Session -ErrorAction SilentlyContinue -Verbose:$Verbose
                if($F5Status -eq 'ACTIVE'){
                    Write-Verbose $("-->`tState of "+$_+": "+$F5Status)
                    $Session | Export-CliXml -Path $SessionFile -Verbose:$Verbose
                    Write-Verbose "Session exported to $SessionFile"
                    $ActiveFound = $true
                } else {
                    Write-Verbose $("-->`tState of "+$_+": "+$F5Status)
                }
            }
        }
    }
    if($null -eq $Session){
        Write-Warning "Cannot find active F5"
        if((read-host "Do you want to enter new F5 credentials ? (y/n)") -eq 'y'){
            Set-CredFile -Force -Verbose:$Verbose
        }
    }
    return $Session
}


Function Set-F5NamesFile {

    param(
        [Parameter(Mandatory = $false)]
        [string]$Path=$([system.io.path]::GetTempPath()+"f5-names.xml"),
        [switch]$Force
    )

    if($VerbosePreference -ne "SilentlyContinue"){
        $Verbose = $true
    } else {
        $Verbose = $false
    }

    $F5Names = $null

    Write-Verbose "Using F5 names file: $Path"

    if(!($Force)){
        try{
            $F5Names = Import-CliXml -Path $Path
            Write-Verbose "`tSuccessfully imported F5 names:"
            $F5Names | ForEach-Object {
                Write-Verbose "-->`t$_"
            }
        }catch{
            Write-Warning "Unable to import F5 names"
            Write-Warning "Enter F5 names (or IPs) below, one per line"
        }
    }

    if($null -eq $F5Names){
        Write-Verbose "Creating F5 names file..."
        $F5Names = @()
        do {
            $input = (Read-Host "F5 names")
            if ($input -ne '') {$F5Names += $input}
        }
        until ($input -eq '')
        if($F5Names.count -ne 0){
            $F5Names | Export-CliXml -Path $Path
            Write-Verbose "F5 names exported to $Path"
        } else {
            Write-Warning "Failed to create F5 names file"
        }
    }
    return $F5Names
}