function Set-F5Node {

    <#
        .SYNOPSIS
            Interactive function to put pools members down or up
        .EXAMPLE
            Set-F5Node node1 -Up -Sync
        .EXAMPLE
            Set-F5Node -Sync
        .LINK
            https://github.com/jorioux/F5-LTM-Helper
    #>

    param(
        [Parameter(Mandatory = $false,ValueFromPipeline = $true)]
        [string]$Name,
        [switch]$Up,
        [switch]$Down,
        [string]$Pool,
        [switch]$Sync,
        [switch]$Force
    )

    if($VerbosePreference -ne "SilentlyContinue"){
        $Verbose = $true
    } else {
        $Verbose = $false
    }

    if($Up -and $Down){
        Write-Warning "Specify either Up or Down, not both"
        return
    }

    $Session = Connect-F5 -Verbose:$Verbose

    if($null -eq $Session){
        return
    }

    $Pools = Get-Pool -F5Session $Session | Where-Object {$_.fullPath -like "*$Pool*"} | Select-Object -ExpandProperty fullPath

    $Pools | ForEach-Object {
        $PoolName = $_
        $MemberName = ""
        $Confirm = $false
        write-host -foregroundcolor white "`nPool: $PoolName"
        Get-PoolMember -PoolName $PoolName -F5Session $Session | Where-Object {$_.name -like "*$($Name)*"} | ForEach-Object {
                $MemberName = $_.name
                write-host -NoNewLine "`tCurrent status for $MemberName : "
                if($_.state -eq 'up'){
                    write-host -NoNewLine -foregroundcolor green $($_.state)
                } else {
                    write-host -NoNewLine -foregroundcolor red $($_.state)
                }
                $curconns = (Get-PoolMemberStats -PoolName $PoolName -Name $MemberName -F5Session $Session)."serverside.curConns".value
                write-host " ($curconns connections)"
        }

        if($MemberName -eq ""){
            write-host -foregroundcolor yellow "`tNo match for '$Name'"
        } else {

            #Enable Pool Member
            if($Up -and ($Force -or $($Confirm = read-host "`tENABLE $MemberName ? (y/n) "; $Confirm) -eq "y")){
                write-host -NoNewLine -foregroundcolor cyan "`tEnabling $MemberName..."
                $output = Enable-PoolMember -PoolName $PoolName -Name $MemberName -F5Session $Session

            #Disable Pool Member
            } elseif($Down -and ($Force -or $($Confirm = read-host "`tDISABLE $MemberName ? (y/n) "; $Confirm) -eq "y")){
                write-host -NoNewLine -foregroundcolor cyan "`tDisabling $MemberName..."
                $output = Disable-PoolMember -PoolName $PoolName -Name $MemberName -Force -F5Session $Session
            }

            if(($Up -or $Down) -and ($Force -or $Confirm -eq 'y')) {
                sleep 1
                if($output -eq 'True'){
                    write-host -foregroundcolor green "OK"
                } else {
                    write-host -foregroundcolor red "Fail"
                }
                
                write-host -NoNewLine "`tNew status for $MemberName : "
                $NewState = $((Get-PoolMember -Name $MemberName -PoolName $PoolName -F5Session $Session).State)
                write-host -ForegroundColor $(if($NewState -eq 'up'){"Green"}else{"Red"}) $NewState
            }
        }
    }

    #Sync Device to Group
    if($Sync -and ($Force -or $($Confirm = read-host "`nSYNC $($Session.Name) to group ? (y/n) "; $Confirm) -eq "y") -and $(Get-F5Status -F5Session $Session) -eq 'ACTIVE'){
        write-host -NoNewLine -foregroundcolor white "Syncing device to group..."
        $output = Sync-DeviceToGroup -GroupName syncgroup -F5Session $Session
        if($output -eq 'True'){
            write-host -foregroundcolor green "OK"
        } else {
            write-host -foregroundcolor red "FAIL"
        }
    }

}