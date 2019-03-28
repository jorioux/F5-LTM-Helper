function Set-F5Node {

    param(
        [Parameter(Mandatory = $false,ValueFromPipeline = $true)]
        [string]$Name,
        [switch]$Up,
        [switch]$Down,
        [switch]$Sync
    )

    if($Up -and $Down){
        write-host -foregroundcolor yellow "Specify either Up or Down, not both"
        return
    }

    $Session = Connect-F5

    if($Session -eq $null){
        return
    }

    #Edit the pools here
    $Pools = @('endeca_pool','eway_http_http2','eway_https_http2')

    $Pools | %{
        $PoolName = $_
        $MemberName = ""
        $Confirm = $false
        write-host -foregroundcolor white "`nPool: $PoolName"
        Get-PoolMember -PoolName $PoolName -F5Session $Session | %{
            if($_.name -like "*$($Name)*"){
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
        }

        if($MemberName -eq ""){
            write-host -foregroundcolor yellow "`tNo match for '$Name'"
        } else {

            if($Up){
                write-host -nonewline -foregroundcolor green "`tENABLE "
                if($($Confirm = read-host "$MemberName ? (y/n) "; $Confirm) -eq "y"){
                    write-host -NoNewLine -foregroundcolor cyan "`tEnabling $MemberName..."
                    $output = Enable-PoolMember -PoolName $PoolName -Name $MemberName -F5Session $Session
                }
            } elseif($Down){
                write-host -nonewline -foregroundcolor red "`tDISABLE "
                if($($Confirm = read-host "$MemberName ? (y/n) "; $Confirm) -eq "y"){
                    write-host -NoNewLine -foregroundcolor cyan "`tDisabling $MemberName..."
                    $output = Disable-PoolMember -PoolName $PoolName -Name $MemberName -Force -F5Session $Session
                }
            }
            if(($Up -or $Down) -and ($Confirm -eq 'y')) {
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

    if($Sync){
        if($(Get-F5Status -F5Session $Session) -eq 'ACTIVE'){
            write-host -NoNewLine -foregroundcolor cyan "`nSYNC $($Session.Name) to group ? "
            if($(read-host "(y/n) ") -eq "y"){
                write-host -NoNewLine -foregroundcolor white "`tSyncing device to group..."
                $output = Sync-DeviceToGroup -GroupName syncgroup -F5Session $Session
                if($output -eq 'True'){
                    write-host -foregroundcolor green "OK"
                } else {
                    write-host -foregroundcolor red "FAIL"
                }
            }
        }
        
    }

}