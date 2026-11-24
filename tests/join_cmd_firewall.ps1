# join-roe-os.cmd's firewall functions (the ADDRESSES answer, the blocked ranges, the trusted servers and
# when the rules change): parses Source (join-roe-os.cmd copied to a .ps1), loads its top-level functions
# and prints OK or FAIL lines. Nothing touches the real firewall.
param([string]$Source, [string]$Base)
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { foreach ($e in $errors) { "FAIL parse: $e" }; exit 2 }
foreach ($f in @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })) {
    . ([ScriptBlock]::Create($f.Extent.Text))
}
function Check([string]$Name, [bool]$Ok) { if ($Ok) { "OK $Name" } else { "FAIL $Name" } }
function Text($List) { return (@($List) -join ',') }
# True when Address lies in one of the "low-high" ranges.
function Test-Blocked([string[]]$Ranges, [string]$Address) {
    $six = $Address -match ':'
    $number = { param($a) if ($six) { ConvertTo-Number6 $a } else { ConvertTo-Number6 ('::ffff:' + $a) } }
    $n = & $number $Address
    foreach ($r in $Ranges) {
        $low, $high = $r.Split('-')
        if (($low -match ':') -ne $six) { continue }
        if ([string]::CompareOrdinal($n, (& $number $low)) -ge 0 -and [string]::CompareOrdinal($n, (& $number $high)) -le 0) { return $true }
    }
    return $false
}

# The answer: canonical addresses, each once; loopback and words that are no address skipped.
$list = Get-ServerAddresses 'OK 203.0.113.5 2001:DB8:0::1 ttl=60 127.0.0.1 ::1 ::ffff:198.51.100.7 1.2.3 01.2.3.4 203.0.113.5 :: 224.0.0.1 host.example'
Check 'addresses parsed' ((Text $list) -ceq '203.0.113.5,2001:db8::1,198.51.100.7')
$empty = Get-ServerAddresses 'OK'
Check 'empty list is a list' ($null -ne $empty -and $empty.Count -eq 0)
Check 'no OK no list' ($null -eq (Get-ServerAddresses 'INVALID') -and $null -eq (Get-ServerAddresses '') -and $null -eq (Get-ServerAddresses 'LIMIT') -and $null -eq (Get-ServerAddresses $null))
$many = Get-ServerAddresses ('OK ' + ((0..99 | ForEach-Object { "10.0.$([int][Math]::Floor($_ / 250)).$($_ % 250 + 1)" }) -join ' '))
Check 'at most 64' ($many.Count -eq 64)
$one = Get-ServerAddresses 'OK 203.0.113.5'
Check 'one stays a list' ($one -is [array] -and $one.Count -eq 1)

# Blocked ranges: everything but this computer and the trusted addresses, IPv4, IPv6 and NAT64;
# remote addresses only.
$ranges = @(Get-BlockedRanges @('203.0.113.5', '2001:db8::1'))
Check 'trusted not blocked' (-not (Test-Blocked $ranges '203.0.113.5') -and -not (Test-Blocked $ranges '2001:db8::1') -and -not (Test-Blocked $ranges '64:ff9b::cb00:7105'))
Check 'loopback not blocked' (-not (Test-Blocked $ranges '127.0.0.1') -and -not (Test-Blocked $ranges '127.255.0.9') -and -not (Test-Blocked $ranges '::1'))
Check 'others blocked' ((Test-Blocked $ranges '203.0.113.4') -and (Test-Blocked $ranges '203.0.113.6') -and (Test-Blocked $ranges '8.8.8.8') -and (Test-Blocked $ranges '255.255.255.255') -and
    (Test-Blocked $ranges '0.0.0.1') -and (Test-Blocked $ranges '2001:db8::') -and (Test-Blocked $ranges '2001:db8::2') -and (Test-Blocked $ranges '::2') -and
    (Test-Blocked $ranges '64:ff9b::cb00:7104') -and (Test-Blocked $ranges 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff'))
$plain = @(Get-BlockedRanges @('203.0.113.5'))
Check 'ipv4 only' ((Text ($plain | Where-Object { $_ -notmatch ':' })) -ceq '0.0.0.0-126.255.255.255,128.0.0.0-203.0.113.4,203.0.113.6-255.255.255.255' -and
    (Test-Blocked $plain '2001:db8::1') -and -not (Test-Blocked $plain '64:ff9b::cb00:7105'))
$none = @(Get-BlockedRanges @())
Check 'nothing trusted' ((Text $none) -ceq '0.0.0.0-126.255.255.255,128.0.0.0-255.255.255.255,0:0:0:0:0:0:0:2-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff')

# The rules name their servers, IPv6 too; another description trusts nothing.
$rule = { param($Description, $Enabled = 'True') [pscustomobject]@{ Name = 'r'; Description = $Description; Enabled = $Enabled } }
Check 'trusted read' ((Text (Get-TrustedServers @((& $rule 'servers 203.0.113.5 2001:db8::1'), (& $rule 'servers 203.0.113.5 2001:db8::1')))) -ceq '203.0.113.5,2001:db8::1')
Check 'other description' ((Get-TrustedServers @(& $rule 'server 1.2.3.4')).Count -eq 0)
Check 'mixed rules ignored' ((Get-TrustedServers @((& $rule 'servers 1.2.3.4'), (& $rule 'servers 5.6.7.8'))).Count -eq 0)

# The update: this server and its list added, what it no longer lists dropped, other servers kept.
Check 'first join' ((Text (Get-TrustedUpdate @() @('203.0.113.5') @('198.51.100.7') @() @())) -ceq '198.51.100.7,203.0.113.5')
Check 'new listed' ((Text (Get-TrustedUpdate @('198.51.100.7', '203.0.113.5') @('203.0.113.5') @('198.51.100.7', '2001:db8::9') @('198.51.100.7') @())) -ceq '198.51.100.7,2001:db8::9,203.0.113.5')
Check 'no longer listed' ((Text (Get-TrustedUpdate @('192.0.2.1', '198.51.100.7', '203.0.113.5') @('203.0.113.5') @() @('198.51.100.7') @())) -ceq '192.0.2.1,203.0.113.5')
Check 'other server keeps it' ((Text (Get-TrustedUpdate @('198.51.100.7', '203.0.113.5') @('203.0.113.5') @() @('198.51.100.7') @('198.51.100.7'))) -ceq '198.51.100.7,203.0.113.5')
Check 'no list drops nothing' ((Text (Get-TrustedUpdate @('192.0.2.1', '198.51.100.7') @('203.0.113.5') $null @('198.51.100.7') @())) -ceq '192.0.2.1,198.51.100.7,203.0.113.5')
Check 'own address never dropped' ((Text (Get-TrustedUpdate @('203.0.113.5') @('203.0.113.5') @() @('203.0.113.5') @())) -ceq '203.0.113.5')
Check 'local server' ((Get-TrustedUpdate @() @() $null @() @()).Count -eq 0)
# A domain that moved: its old address goes (also without a list), unless another server needs it.
Check 'domain moved' ((Text (Get-TrustedUpdate @('192.0.2.1', '203.0.113.5') @('203.0.113.6') $null @() @() @('203.0.113.5'))) -ceq '192.0.2.1,203.0.113.6' -and
    (Text (Get-TrustedUpdate @('203.0.113.5') @('203.0.113.6') $null @() @('203.0.113.5') @('203.0.113.5'))) -ceq '203.0.113.5,203.0.113.6')

# Approval only when the rules change: same set (any order) is current; added, dropped, a rule
# off or a program without its rule is not.
$own = @((& $rule 'servers 198.51.100.7 203.0.113.5'), (& $rule 'servers 198.51.100.7 203.0.113.5'))
Check 'unchanged: no prompt' (Test-RulesCurrent $own 2 @('203.0.113.5', '198.51.100.7'))
Check 'added: prompt' (-not (Test-RulesCurrent $own 2 @('198.51.100.7', '203.0.113.5', '2001:db8::9')))
Check 'dropped: prompt' (-not (Test-RulesCurrent $own 2 @('203.0.113.5')))
Check 'rule off or missing: prompt' (-not (Test-RulesCurrent @((& $rule 'servers 198.51.100.7 203.0.113.5'), (& $rule 'servers 198.51.100.7 203.0.113.5' 'False')) 2 @('198.51.100.7', '203.0.113.5')) -and
    -not (Test-RulesCurrent $own 3 @('198.51.100.7', '203.0.113.5')) -and -not (Test-RulesCurrent @() 0 @()))

# The saved lists: kept per server through use and the settings file, other servers' needs.
$settings = '{"servers":[{"address":"a.example","last_used":30,"addresses":["198.51.100.7","bad"],"ips":["203.0.113.5"]},{"address":"192.0.2.1:8001","last_used":20},{"address":"c.example","last_used":10,"addresses":["2001:DB8::9"]}]}' | ConvertFrom-Json
$servers = @(Read-Servers $settings)
Check 'saved lists read' ((Text $servers[0].addresses) -ceq '198.51.100.7' -and (Text $servers[0].ips) -ceq '203.0.113.5' -and (Text $servers[2].addresses) -ceq '2001:db8::9' -and $servers[1].addresses.Count -eq 0)
$servers = @(Add-ServerUse $servers 'c.example' 99)
Check 'use keeps lists' ($servers[0].address -eq 'c.example' -and (Text $servers[0].addresses) -ceq '2001:db8::9')
Check 'kept by others' ((Text (Get-KeptAddresses $servers 'c.example')) -ceq '192.0.2.1,198.51.100.7,203.0.113.5')
Set-ServerAddresses $servers 'c.example' ([string[]]@()) @('198.51.100.20')
$back = @(Read-Servers (([pscustomobject]@{ servers = @($servers) } | ConvertTo-Json -Depth 4) | ConvertFrom-Json))
Check 'empty list saved' ($back[0].address -eq 'c.example' -and $back[0].addresses.Count -eq 0 -and (Text $back[0].ips) -ceq '198.51.100.20' -and (Text $back[1].addresses) -ceq '198.51.100.7')
Set-ServerAddresses $back 'a.example' $null $null
Check 'no answer keeps the list' ((Text $back[1].addresses) -ceq '198.51.100.7' -and (Text $back[1].ips) -ceq '203.0.113.5')
# A domain is saved as typed (case too) and keeps its resolved addresses for the next join.
$servers = @(Add-ServerUse $back 'Play.Example.org' 120)
Set-ServerAddresses $servers 'play.example.org' ([string[]]@('198.51.100.30')) ([string[]]@('203.0.113.40'))
$back = @(Read-Servers (([pscustomobject]@{ servers = @($servers) } | ConvertTo-Json -Depth 4) | ConvertFrom-Json))
Check 'domain saved as typed' ($back[0].address -ceq 'Play.Example.org' -and (Text $back[0].ips) -ceq '203.0.113.40' -and (Text $back[0].addresses) -ceq '198.51.100.30' -and
    (Get-KeptAddresses $back 'c.example') -contains '203.0.113.40')

# After the step: each program needs its enabled rule for exactly the trusted servers, and no
# block rule of another program may name it.
$games = @('C:\Game\Europa_Client.exe', 'C:\Game\Other.exe')
$active = { param($Program, $Description = 'servers 198.51.100.7 203.0.113.5', $Enabled = 'True') [pscustomobject]@{ Program = $Program; Description = $Description; Enabled = $Enabled } }
$right = @((& $active 'C:\Game\Europa_Client.exe'), (& $active 'c:\game\other.exe'))
$trust = @('203.0.113.5', '198.51.100.7')
Check 'rules in place: no problem' ((@(Get-RuleProblems $games $right $trust @())).Count -eq 0)
$p = @(Get-RuleProblems $games @() $trust @())
Check 'declined prompt: rules missing' ($p.Count -eq 1 -and $p[0] -match '^no join-roe-os.cmd rule for 2 of 2')
$p = @(Get-RuleProblems $games @((& $active 'C:\Game\Europa_Client.exe' 'servers 198.51.100.7'), (& $active 'C:\Game\Other.exe' -Enabled 'False')) $trust @())
Check 'rule off or old servers' ($p.Count -eq 2 -and $p[0] -match 'is off for 1' -and $p[1] -match 'trust other servers')
$block = [pscustomobject]@{ Name = '{x}'; DisplayName = 'europa_client.exe'; Program = 'C:\Game\Europa_Client.exe'; Direction = 'Inbound'; Local = $true }
$policy = [pscustomobject]@{ Name = '{y}'; DisplayName = 'Corp block'; Program = 'C:\Game\Europa_Client.exe'; Direction = 'Outbound'; Local = $false }
$p = @(Get-RuleProblems $games $right $trust @($block, $policy))
Check 'block rules of others' ($p.Count -eq 2 -and $p[0] -match '^a local rule blocks Europa_Client.exe \(Inbound\)' -and $p[1] -match 'policy or security product')
Check 'rules off: only block rules count' ((@(Get-RuleProblems $games $null $null @())).Count -eq 0 -and (@(Get-RuleProblems $games $null $null @($block))).Count -eq 1)
# What happened and what to do.
Check 'notes' ((Get-ElevationNote $null) -eq '' -and (Get-ElevationNote ([pscustomobject]@{ Reason = 'done' })) -eq '' -and
    (Get-ElevationNote ([pscustomobject]@{ Reason = 'declined' })) -match '^Windows did not ask for administrator rights, or the prompt was declined: right-click join-roe-os\.cmd > Run as administrator once' -and
    (Get-ElevationNote ([pscustomobject]@{ Reason = 'not-admin' })) -match '^Windows did not ask for administrator rights \(User Account Control.*Run as administrator once' -and
    (Get-ElevationNote ([pscustomobject]@{ Reason = 'no-start'; Detail = 'no shell' })) -match '^Windows did not ask for administrator rights \(no shell\): right-click' -and
    (Get-ElevationNote ([pscustomobject]@{ Reason = 'failed'; Detail = 'Access is denied.' })) -match 'failed: Access is denied')
$advice = @(Get-FirewallAdvice 'C:\Downloads\join-roe-os.cmd' @() $false)
Check 'advice: run as administrator' (($advice -join "`n") -match 'Right-click join-roe-os.cmd > Run as administrator' -and ($advice -join "`n") -match '"C:\\Downloads\\join-roe-os.cmd"' -and ($advice -join "`n") -notmatch 'policy')
$advice = @(Get-FirewallAdvice 'C:\Downloads\join-roe-os.cmd' @($policy) $true)
Check 'advice: elevated, policy rule' (($advice -join "`n") -match 'already runs as administrator' -and ($advice -join "`n") -match 'policy or security product' -and ($advice -join "`n") -notmatch 'Right-click')
# The step itself, without a prompt: a .ps1 copy of join-roe-os.cmd with -FirewallStep; run directly it
# finds no administrator rights (as with User Account Control off on a standard account) unless the
# test runs elevated; a declined prompt.
$env:ROE_JOIN_SELF = $Source
$admin = Test-Administrator
$nothing = [pscustomobject]@{ Create = @(); Remove = @('ROE2022-test-none') }
$direct = Invoke-Elevated $nothing $true
Check 'direct step' ($(if ($admin) { $direct.Ok -and $direct.Reason -eq 'done' } else { -not $direct.Ok -and $direct.Reason -eq 'not-admin' }))
# The separate files: the step is a copy of join-roe-os.ps1 (ROE_JOIN_CODE), not of the launcher.
$env:ROE_JOIN_SELF = Join-Path $Base 'join-roe-os.cmd'
$env:ROE_JOIN_CODE = $Source
$split = Invoke-Elevated $nothing $true
Check 'direct step: separate files' ($(if ($admin) { $split.Ok -and $split.Reason -eq 'done' } else { -not $split.Ok -and $split.Reason -eq 'not-admin' }))
Remove-Item Env:\ROE_JOIN_CODE
$env:ROE_JOIN_SELF = $Source
if ($admin) {
    $failed = Invoke-Elevated ([pscustomobject]@{ Create = @([pscustomobject]@{ Name = 'ROE2022-test-bad'; Group = 'ROE2022-test'; Description = 'x'; Program = 'C:\x.exe'; RemoteAddress = @('no address') }); Remove = @() }) $true
    Check 'failed step' (-not $failed.Ok -and $failed.Reason -eq 'failed' -and $failed.Detail)
} else { Check 'failed step (needs an elevated test run)' $true }
# The elevated start: powershell.exe through the shell as administrator, in a normal window, with the
# prompt's window passed on (ErrorDialog: .NET hands ShellExecuteEx the window only then, and
# Start-Process never does), the step's files quoted.
$start = New-ElevatedStart '-NoProfile -File "C:\a b\s.ps1"' ([IntPtr]1234)
Check 'elevated start' ($start.FileName -eq 'powershell.exe' -and $start.Verb -eq 'runas' -and $start.UseShellExecute -and "$($start.WindowStyle)" -eq 'Normal' -and
    $start.ErrorDialog -and $start.ErrorDialogParentHandle -eq [IntPtr]1234 -and $start.Arguments -eq '-NoProfile -File "C:\a b\s.ps1"')
# The prompt's window: the join window's when it set one, else this console's (or none).
$sync = @{ Owner = [IntPtr]4321 }
$owner = Get-PromptOwner
$sync = $null
Check 'prompt owner' ($owner -eq [IntPtr]4321 -and (Get-PromptOwner) -is [IntPtr] -and (Get-PromptOwner) -eq [Diagnostics.Process]::GetCurrentProcess().MainWindowHandle)
$global:Started = New-Object Collections.ArrayList
$global:Asked = New-Object Collections.ArrayList
function Ask([string]$Question, [string]$Default) { [void]$global:Asked.Add($Question); return $global:Answers[$global:Asked.Count - 1] }
# A failing start as .NET reports it (MethodInvocationException around the Win32Exception).
$global:Answers = @('n')
function Start-Elevated([string]$Arguments) { [void]$global:Started.Add($Arguments); throw (New-Object Management.Automation.MethodInvocationException 'Exception calling "Start"', (New-Object ComponentModel.Win32Exception 1223)) }
$declined = Invoke-Elevated $nothing $false
Check 'declined: asked once, not retried' ($declined.Reason -eq 'declined' -and -not $declined.Ok -and $global:Started.Count -eq 1 -and $global:Asked.Count -eq 1 -and
    $global:Asked[0] -match '^Windows did not ask for administrator rights, or the prompt was declined: right-click join-roe-os\.cmd > Run as administrator once.* Try again\? \(y/n\)$' -and
    $global:Started[0] -match '^-NoProfile -ExecutionPolicy RemoteSigned -File "[^"]+\\firewall-step-[0-9a-f]{32}\.ps1" -FirewallStep "[^"]+\\firewall-step-[0-9a-f]{32}\.json"$')
$global:Started.Clear(); $global:Asked.Clear(); $global:Answers = @('y', 'n')
function Start-Elevated([string]$Arguments) { [void]$global:Started.Add($Arguments); throw (New-Object Management.Automation.MethodInvocationException 'Exception calling "Start"', (New-Object ComponentModel.Win32Exception 2)) }
$broken = Invoke-Elevated $nothing $false
Check 'not started: retried, the error named' ($broken.Reason -eq 'no-start' -and $global:Started.Count -eq 2 -and $global:Asked.Count -eq 2 -and $broken.Detail -eq (New-Object ComponentModel.Win32Exception 2).Message -and
    $global:Asked[1] -like "Windows did not ask for administrator rights ($($broken.Detail)): right-click*Try again? (y/n)")
# Declined, then accepted on the second try: the step's exit code counts.
$global:Started.Clear(); $global:Asked.Clear(); $global:Answers = @('y')
function Start-Elevated([string]$Arguments) {
    [void]$global:Started.Add($Arguments)
    if ($global:Started.Count -eq 1) { throw (New-Object Management.Automation.MethodInvocationException 'canceled', (New-Object ComponentModel.Win32Exception 1223)) }
    return 0
}
$retried = Invoke-Elevated $nothing $false
Check 'retry then done' ($retried.Ok -and $retried.Reason -eq 'done' -and $global:Started.Count -eq 2 -and $global:Asked.Count -eq 1 -and $global:Started[0] -eq $global:Started[1])
function Start-Elevated([string]$Arguments) { return 3 }
Check 'ran without rights: no retry' ((Invoke-Elevated $nothing $false).Reason -eq 'not-admin' -and $global:Asked.Count -eq 1)
# In the window the step first brings the window to the front (a front event), then starts.
$sync = [hashtable]::Synchronized(@{ Events = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]' })
function Start-Elevated([string]$Arguments) { return 0 }
$windowStep = Invoke-Elevated $nothing $false
$event = $null
Check 'window: front first' ($windowStep.Ok -and $sync.Events.TryDequeue([ref]$event) -and $event.Kind -eq 'front')
$sync = $null
Remove-Item Function:\Start-Elevated, Function:\Ask
Check 'step files removed' (-not @(Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'roe-join') -Filter 'firewall-step-*' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-1) }).Count)

# The rules themselves: one per program, the servers in the description, addresses only (no
# ports or protocols), the old rules removed after the new ones exist.
$global:Plan = $null
function Invoke-Elevated($Plan) { $global:Plan = ConvertTo-Json -InputObject $Plan -Depth 5 | ConvertFrom-Json; return [pscustomobject]@{ Ok = $true; Reason = 'done'; Detail = '' } }
$folder = [pscustomobject]@{ Group = 'ROE2022-join-abc'; Own = @([pscustomobject]@{ Name = 'old-1' }); Other = @([pscustomobject]@{ Name = '{x}'; Local = $true }) }
$ok = (Set-FolderRules @('C:\Game\Europa_Client.exe', 'C:\Game\Other.exe') $folder @('198.51.100.7', '2001:db8::9')).Ok
$new = @($global:Plan.Create)
Check 'foreign block rule removed' (@($global:Plan.Remove) -contains '{x}')
Check 'rules by address' ($ok -and $new.Count -eq 2 -and $new[1].Program -eq 'C:\Game\Other.exe' -and $new[0].Group -eq 'ROE2022-join-abc' -and $new[0].Name -like 'ROE2022-join-abc-*-0' -and
    $new[0].Description -eq 'servers 198.51.100.7 2001:db8::9' -and @($new[0].RemoteAddress).Count -gt 1 -and (Test-Blocked @($new[0].RemoteAddress) '203.0.113.5') -and
    -not (Test-Blocked @($new[0].RemoteAddress) '198.51.100.7') -and @($global:Plan.Remove) -contains 'old-1')

# The firewall step as a function: with the real firewall replaced, which rules it sets and what it
# leaves to check.
$global:Set = $null
function Get-GamePrograms([string]$Client) { return @('C:\Game\Europa_Client.exe') }
function Get-FolderRules([string]$Client, [string[]]$Programs) { return $global:Folder }
function Get-RunningGame([string[]]$Programs) { return @() }
function Get-FirewallProblems { return @() }
function Get-OtherFirewalls { return @() }
function Test-Administrator { return $false }
function Set-FolderRules([string[]]$Programs, $Folder, [string[]]$Trusted) { $global:Set = $Trusted; return $global:Step }
function Write-Host { }
$servers = @([pscustomobject]@{ address = 'play.example'; last_used = 1; name = ''; addresses = [string[]]@('198.51.100.9'); ips = [string[]]@() })
$global:Folder = [pscustomobject]@{ Group = 'g'; Own = @(); Other = @(); Fixed = @() }
$global:Step = [pscustomobject]@{ Ok = $true; Reason = 'done'; Detail = '' }
$r = Update-Firewall 'C:\Game' $servers 'play.example' @('203.0.113.5') @('198.51.100.7') $true
Check 'rules set' ((Text $global:Set) -eq '198.51.100.7,203.0.113.5' -and $r.Check.RulesOn -and (Text $r.Check.Wanted) -eq '198.51.100.7,203.0.113.5' -and $r.Check.Step.Ok -and
    (Text $servers[0].addresses) -eq '198.51.100.7' -and (Text $servers[0].ips) -eq '203.0.113.5')
$servers[0].addresses = [string[]]@('198.51.100.9'); $servers[0].ips = [string[]]@()
$global:Step = [pscustomobject]@{ Ok = $false; Reason = 'declined'; Detail = '' }
$r = Update-Firewall 'C:\Game' $servers 'play.example' @('203.0.113.5') @('198.51.100.7') $true
Check 'declined keeps the list' ($r.Check.Step.Reason -eq 'declined' -and (Text $servers[0].addresses) -eq '198.51.100.9' -and -not @($servers[0].ips).Count)
$global:Set = $null
$r = Update-Firewall 'C:\Game' $servers 'play.example' @('203.0.113.5') $null $false
Check 'rules off: nothing to do' ($null -eq $global:Set -and $null -eq $r.Check -and (Text $servers[0].ips) -eq '203.0.113.5')
$global:Folder = [pscustomobject]@{ Group = 'g'; Own = @(); Other = @(); Fixed = @([pscustomobject]@{ Name = 'p'; Local = $false }) }
$r = Update-Firewall 'C:\Game' $servers 'play.example' @('203.0.113.5') $null $false
Check 'rules off: a policy rule is checked' ($null -ne $r.Check -and -not $r.Check.RulesOn -and $null -eq $r.Check.Wanted)
Remove-Item Function:\Write-Host
