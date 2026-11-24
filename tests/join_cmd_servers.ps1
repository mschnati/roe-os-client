# join-roe-os.cmd's server functions (menu, the servers list, -Server) in the
# folder Base: parses Source (join-roe-os.cmd copied to a .ps1), loads its top-level functions and prints
# OK or FAIL lines.
param([string]$Source, [string]$Base)
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { foreach ($e in $errors) { "FAIL parse: $e" }; exit 2 }
foreach ($f in @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })) {
    . ([ScriptBlock]::Create($f.Extent.Text))
}
$global:Answers = New-Object System.Collections.Queue
$global:Asked = New-Object System.Collections.ArrayList
function Ask([string]$Question, [string]$Default) {
    [void]$global:Asked.Add(@($Question, $Default))
    if (-not $global:Answers.Count) { throw "not expected: $Question" }
    $answer = $global:Answers.Dequeue()
    if (-not $answer) { return $Default }
    return $answer
}
function Answer([string[]]$List) { $global:Answers.Clear(); $global:Asked.Clear(); foreach ($a in $List) { $global:Answers.Enqueue($a) } }
function Check([string]$Name, [bool]$Ok) { if ($Ok) { "OK $Name" } else { "FAIL $Name" } }
function Addresses($List) { return (@($List | ForEach-Object { $_.address }) -join ',') }
$t1 = 'a' * 64

# Menu order: the settings' list by last use, each address once.
$root = Join-Path $Base 'roe-join'
$settings = '{"servers":[{"address":"b.example","last_used":20},{"address":"a.example","last_used":30},{"address":"c.example","last_used":25},{"bad":1},{"address":"A.example","last_used":99}]}' | ConvertFrom-Json
$list = @(Read-Servers $settings)
Check 'order' ((Addresses $list) -eq 'a.example,c.example,b.example')
# The numbered fallback (input redirected): the last entry asks for another address.
Answer @('4', 'd.example')
Check 'another address' ((Select-Server $list '') -eq 'd.example' -and $global:Asked.Count -eq 2 -and $global:Asked[1][0] -like 'Server address*' -and -not $global:Asked[1][1])
Answer @('2')
Check 'saved picked' ((Select-Server $list '') -eq 'c.example')
Answer @('')
Check 'enter takes the first' ((Select-Server $list '') -eq 'a.example')
# -Server skips the menu; the first start asks for the address.
Answer @()
Check 'server option' ((Select-Server $list '5.6.7.8') -eq '5.6.7.8' -and $global:Asked.Count -eq 0)
Check 'no saved servers' (@(Read-Servers ([pscustomobject]@{ client = '' })).Count -eq 0)
Answer @('1.2.3.4')
Check 'first start asks' ((Select-Server @() '') -eq '1.2.3.4' -and $global:Asked.Count -eq 1)
# The first start offers the default list (roe-os.de): Enter takes it; saved servers replace it.
$offered = @(Get-OfferedServers ([pscustomobject]@{ client = '' }))
Check 'first start offers roe-os.de' ($offered.Count -eq 1 -and (Get-ServerLabel $offered[0]) -ceq 'ROE-OS (roe-os.de)' -and $offered[0].last_used -eq 0)
Answer @('')
Check 'first start: Enter takes it' ((Select-Server $offered '') -eq 'roe-os.de' -and $global:Asked.Count -eq 1)
Check 'saved servers offered' ((Addresses @(Get-OfferedServers $settings)) -eq 'a.example,c.example,b.example')

# The use is remembered: on top with its time, once (case ignored); it survives the settings file.
$list = Add-ServerUse $list 'C.example' 99
Check 'remembered' ((Addresses $list) -eq 'C.example,a.example,b.example' -and $list[0].last_used -eq 99)
$json = [pscustomobject]@{ servers = @($list) } | ConvertTo-Json -Depth 4
$back = @(Read-Servers ($json | ConvertFrom-Json))
Check 'round trip' ((Addresses $back) -eq 'C.example,a.example,b.example')
$one = @(Add-ServerUse @() 'solo.example' 5)
$back = @(Read-Servers (([pscustomobject]@{ servers = $one } | ConvertTo-Json -Depth 4) | ConvertFrom-Json))
Check 'one server round trip' ($back.Count -eq 1 -and $back[0].address -eq 'solo.example' -and $back[0].last_used -eq 5)

# Server names: from INFO, saved, shown in the menu, updated, removed.
Check 'info name' ((Get-InfoServerName 'OK players=1 matches=0 waiting=0 restarting=0 name=Europa%20EU%20%C3%A9') -ceq "Europa EU $([char]0xe9)")
Check 'info empty name' ((Get-InfoServerName 'OK players=1 matches=0 waiting=0 restarting=0 name=') -ceq '')
Check 'no name field' ((Get-InfoServerName 'OK players=1 matches=0 waiting=0 restarting=0') -ceq '')
Check 'name cleaned' ((Get-InfoServerName ('OK name=a%0Ab%1B' + ('%41' * 50))) -ceq ('ab' + ('A' * 38)))
Check 'counts unchanged' ((Format-ServerInfo 'OK players=2 matches=1 waiting=0 restarting=0 name=players%3D9') -like 'On the server now: 2 players online, 1 match running*')
$settings = '{"servers":[{"address":"a.example","last_used":30,"name":"Europa"},{"address":"b.example","last_used":20},{"address":"c.example","last_used":10,"name":"bad\u0007"}]}' | ConvertFrom-Json
$list = @(Read-Servers $settings)
Check 'menu labels' ((@($list | ForEach-Object { Get-ServerLabel $_ }) -join ',') -ceq 'Europa (a.example),b.example,bad (c.example)')
$list = @(Add-ServerUse $list 'A.example' 99)
Check 'use keeps name' ($list[0].address -eq 'A.example' -and $list[0].name -ceq 'Europa' -and $list.Count -eq 3)
Check 'same name' (-not (Set-ServerName $list 'A.example' 'Europa'))
Check 'name updated' ((Set-ServerName $list 'A.example' 'Europa EU') -and (Get-ServerLabel $list[0]) -ceq 'Europa EU (A.example)')
Check 'name removed' ((Set-ServerName $list 'b.example' 'Dione') -and (Set-ServerName $list 'A.example' '') -and (@($list | ForEach-Object { Get-ServerLabel $_ }) -join ',') -ceq 'A.example,Dione (b.example),bad (c.example)')
$json = [pscustomobject]@{ servers = @($list) } | ConvertTo-Json -Depth 4
$back = @(Read-Servers ($json | ConvertFrom-Json))
Check 'names round trip' ((@($back | ForEach-Object { Get-ServerLabel $_ }) -join ',') -ceq 'A.example,Dione (b.example),bad (c.example)')
Answer @('2')
Check 'menu picks address' ((Select-Server $back '') -eq 'b.example')

# A server folder without an entry in the list is no saved server.
$a = New-Object System.Collections.ArrayList
[void]$a.Add([pscustomobject]@{ name = 'A'; token = $t1; last_used = 50 })
Save-Accounts (Join-Path $root 'old.example') $a | Out-Null
Check 'folders are no list' (@(Read-Servers ([pscustomobject]@{ client = '' })).Count -eq 0)

# -Server and -Name before the menu.
$r = Read-Arguments '-Server 1.2.3.4 -Name "Anna Lee"'
Check 'server and name' ($r.Server -eq '1.2.3.4' -and $r.Name -eq 'Anna Lee' -and -not $r.Command)
$r = Read-Arguments '-Name Anna Lee'
Check 'name with spaces' ($r.Name -eq 'Anna Lee' -and -not $r.Server -and -not $r.Command)
$r = Read-Arguments 'firewall on'
Check 'command stays' ($r.Command -eq 'firewall on' -and -not $r.Server -and -not $r.Name)

# The script version (VERSION): no OK means no check, below min stops, below current a line.
foreach ($line in @(Get-Content -LiteralPath $Source | Where-Object { $_ -match '^\$join(Version|Url) = ' })) { Invoke-Expression $line }
$github = 'url=https%3A%2F%2Fgithub.com%2Fmschnati%2Froe-os-client'
Check 'script version' ((ConvertTo-VersionKey $joinVersion) -and (Compare-Version '0.9' '0.10') -eq -1 -and (Compare-Version '1' '1.0.0') -eq 0 -and $null -eq (ConvertTo-VersionKey '1.') -and $joinUrl -ceq 'https://github.com/mschnati/roe-os-client')
Check 'no OK no check' ($null -eq (Get-VersionNotice 'INVALID' '0.9') -and $null -eq (Get-VersionNotice '' '0.9') -and $null -eq (Get-VersionNotice 'LIMIT' '0.9'))
Check 'current' ($null -eq (Get-VersionNotice "OK min=0 current=0.9 $github" '0.9') -and $null -eq (Get-VersionNotice "OK min=0.9 current=0.9.0 $github later=x" '0.9') -and
    $null -eq (Get-VersionNotice "OK min=bad current=x $github" '0.9'))
Check 'newer exists' ((Get-VersionNotice "OK min=0.9 current=0.10 $github" '0.9') -ceq 'A newer join-roe-os.cmd (version 0.10) is at https://github.com/mschnati/roe-os-client; this one (version 0.9) still works.')
$stop = ''
try { Get-VersionNotice 'OK min=1.0 current=1.0 url=https%3A%2F%2Fexample.org%2Froe' '0.9' | Out-Null } catch { $stop = $_.Exception.Message }
Check 'too old stops' ($stop -ceq 'This join-roe-os.cmd is version 0.9; the server needs version 1.0 or newer. Download the new join-roe-os.cmd from https://example.org/roe and start it again.')
$stop = ''
try { Get-VersionNotice 'OK min=1 current=1 url=javascript%3Ax%0A' '0.9' | Out-Null } catch { $stop = $_.Exception.Message }
Check 'bad url replaced' ($stop -like '*from https://github.com/mschnati/roe-os-client and*')
# STATS: a part per region; broken words skipped; an older server or LIMIT shows nothing.
Check 'region stats' ((Format-Stats 'OK 7,normal,12,3,2,EU%20SERVER 6,duel,2,0,1,AS%20SERVER,later 5,normal,x,0,0,NA%20SERVER 9,odd') -ceq 'EU (normal): 12 online, 3 searching, 2 matches | AS (duel): 2 online, 0 searching, 1 match')
Check 'region without a name' ((Format-Stats 'OK 5,normal,0,0,0,%0A') -ceq 'zone 5 (normal): 0 online, 0 searching, 0 matches')
Check 'region offline' ((Format-Stats 'OK 7,normal,1,0,0,EU%20SERVER,up 5,normal,2,1,0,NA%20SERVER,down 6,duel,0,0,0,AS%20SERVER,later') -ceq 'EU (normal): 1 online, 0 searching, 0 matches | NA (normal): offline | AS (duel): 0 online, 0 searching, 0 matches')
Check 'region modes' ((Format-Stats 'OK 7,normal,9,6,1,EU%20SERVER,up,squad-fpp:1;solo-tpp:2;duo-tpp:0;arcade-tpp:5;solo-fpp:x;training-tpp:3 5,normal,0,0,0,NA%20SERVER,up,-') -ceq
    'EU (normal): 9 online, 6 searching (solo 2, squad FPP 1, training 3), 1 match | NA (normal): 0 online, 0 searching, 0 matches')
Check 'older server shows nothing' ((Format-Stats 'OK') -eq '' -and (Format-Stats 'INVALID') -eq '' -and (Format-Stats 'LIMIT') -eq '' -and (Format-Stats $null) -eq '')
# The line after the login and while the game runs: every region (the live server's reply), INFO only without STATS.
$live = 'OK 7,normal,0,0,0,EU%20SERVER 6,duel,0,0,0,AS%20SERVER'
Check 'now: every region' ((Format-ServerNow 'OK players=0 matches=0 waiting=0 restarting=0 name=ROE-OS' $live) -ceq 'On the server now: EU (normal): 0 online, 0 searching, 0 matches | AS (duel): 0 online, 0 searching, 0 matches.')
Check 'now: restart notice' ((Format-ServerNow 'OK players=1 restarting=1' $live) -like '*0 matches. It restarts for an update soon*')
Check 'now: older server' ((Format-ServerNow 'OK players=2 matches=1 waiting=0 restarting=0' 'INVALID') -like 'On the server now: 2 players online, 1 match running*' -and (Format-ServerNow 'OK players=2' $null) -like 'On the server now: 2 players*')

# The steps of a join as functions (the console and the window): the host, the addresses, the folder.
$stop = ''
try { Get-ServerHost 'play.example:8002' | Out-Null } catch { $stop = $_.Exception.Message }
Check 'server host' ((Get-ServerHost 'play.example:8001') -eq 'play.example' -and (Get-ServerHost '203.0.113.5') -eq '203.0.113.5' -and $stop -like '*only connects to port 8001*:8002*')
$ips = Resolve-ServerIps '203.0.113.5'
Check 'ip as given' ($ips -is [array] -and $ips.Count -eq 1 -and $ips[0] -eq '203.0.113.5')
$joinRoot = $root
Check 'account folder' ((Get-AccountFolder 'Play.Example:8001') -eq (Join-Path $root 'play.example_8001'))
# Contacting the server: name, version, its list without its own addresses, the regions.
$global:Replies = @{}
$global:Sent = New-Object System.Collections.ArrayList
function Invoke-Account([string]$Ip, [string]$Folder, [string]$Line) { [void]$global:Sent.Add($Line); return $global:Replies[$Line] }
$global:Replies = @{ 'INFO' = 'OK players=1 name=Europa%20One'; 'VERSION' = "OK min=0 current=0.9 $github"; 'ADDRESSES' = 'OK 203.0.113.5 198.51.100.7'; 'STATS' = 'OK 7,normal,1,0,0,EU' }
$c = Connect-Server '203.0.113.5' $root @('203.0.113.5')
Check 'contact' ($c.Name -eq 'Europa One' -and -not $c.TooOld -and $null -eq $c.Notice -and (@($c.Listed) -join ',') -eq '198.51.100.7' -and $c.Regions -like 'EU (normal): 1 online*')
# STATS again within 10 s: the last answer, not a new request.
$global:Sent.Clear()
$c = Connect-Server '203.0.113.5' $root @('203.0.113.5')
Check 'stats at most every 10 s' ($global:Sent -notcontains 'STATS' -and $c.Regions -like 'EU (normal): 1 online*')
$script:statsCache = $null
$global:Sent.Clear()
$c = Connect-Server '203.0.113.5' $root @('203.0.113.5') $false
Check 'contact without addresses' ($null -eq $c.Listed -and $global:Sent -notcontains 'ADDRESSES' -and $global:Sent -contains 'STATS')
$global:Replies['VERSION'] = 'OK min=9.0 current=9.0 url=https%3A%2F%2Fexample.org%2Froe'
$global:Sent.Clear()
$c = Connect-Server '203.0.113.5' $root @('203.0.113.5') $true
Check 'too old' ($c.TooOld -like 'This join-roe-os.cmd is version *Download the new join-roe-os.cmd from https://example.org/roe*' -and $global:Sent -notcontains 'ADDRESSES')
$global:Replies = @{}
$c = Connect-Server '203.0.113.5' $root @('203.0.113.5')
Check 'no account service' ($null -eq $c.Info -and $null -eq $c.Listed -and -not $c.Regions -and -not $c.Name)
# roe-join.json as both scripts write it.
$settingsPath = Join-Path $Base 'roe-join.json'
Save-JoinSettings 'C:\Game' $true $null $null @([pscustomobject]@{ address = 'a.example'; last_used = 5; name = 'A'; addresses = [string[]]@(); ips = [string[]]@() })
$read = Read-Settings
Check 'settings saved' ($read.client -eq 'C:\Game' -and $read.firewall -eq $true -and $null -eq $read.voice -and @($read.servers).Count -eq 1 -and $read.servers[0].address -eq 'a.example')
