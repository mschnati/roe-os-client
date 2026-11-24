<# : batch part: runs the PowerShell code below from this same file, in a window or in this console
@echo off
setlocal DisableDelayedExpansion
set "ROE_JOIN_SELF=%~f0"
set "ROE_JOIN_ARGS=%*"
set "ROE_JOIN_WINDOW="
set "ROE_JOIN_WAIT="
rem PowerShell runs a script file only when it ends in .ps1: this file's text as one in
rem %APPDATA%\roe-join (type, not copy: copy would take a download's mark along, and PowerShell
rem would refuse it). The script removes older ones.
if not exist "%APPDATA%\roe-join\" mkdir "%APPDATA%\roe-join"
set "ROE_JOIN_PS1=%APPDATA%\roe-join\run-%RANDOM%%TIME:~-2%%RANDOM%.ps1"
type "%~f0" > "%ROE_JOIN_PS1%" || goto :no_script
setlocal EnableDelayedExpansion
rem The window: no arguments and not typed in a command prompt (a double-click, a shortcut and
rem PowerShell run cmd.exe /c "...join-roe-os.cmd"; the cmd.exe of a prompt has no /c), or --window.
rem A copy of cmdcmdline: the dynamic variable itself takes no :old=new.
rem --window with more after it (Steam's launch option "<join-roe-os.cmd>" --window %command%): the window
rem with that command line, and this waits for it, so Steam sees the game running until it exits.
rem The window hides this console itself.
set "ROE_JOIN_LINE=!cmdcmdline!"
if not defined ROE_JOIN_ARGS (
  if /i not "!ROE_JOIN_LINE: /c=!"=="!ROE_JOIN_LINE!" set "ROE_JOIN_WINDOW=1"
) else if /i "!ROE_JOIN_ARGS!"=="--window" (
  set "ROE_JOIN_WINDOW=1"
) else if /i "!ROE_JOIN_ARGS:~0,9!"=="--window " (
  set "ROE_JOIN_WINDOW=1"
  set "ROE_JOIN_WAIT=1"
)
if defined ROE_JOIN_WAIT (
  powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "!ROE_JOIN_PS1!"
  exit /b 0
)
if defined ROE_JOIN_WINDOW (
  start "" /min powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "!ROE_JOIN_PS1!"
  exit /b 0
)
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "!ROE_JOIN_PS1!"
set "ROE_JOIN_EXIT=!ERRORLEVEL!"
if not "!ROE_JOIN_EXIT!"=="0" (
  echo.
  pause
)
exit /b !ROE_JOIN_EXIT!
:no_script
echo join-roe-os.cmd could not write its script into "%APPDATA%\roe-join".
pause
exit /b 1
#>

# Join a Ring of Elysium 2022 server (roe_server) as a player.
#
# This one file is all a player needs besides the game. Double-click it: a window opens with the
# servers (on the first start roe-os.de, "Add server..." for another one) and who plays where on
# the selected one; the accounts on that server ("Create a new account" makes one); the game
# folder (the Ring of Elysium folder, with a DirectX 12 box for its XVersion folder); voice chat;
# and Play. "Set up starting through Steam": Steam's Play button through the window (below). Under
# "Advanced": the firewall rules (on, off, reset, show), the account backup
# (export, import) and the log; for an account with GM rights on the selected server (ROLE) also
# "Open the admin page" (for others it is not shown; the server checks the rights again).
#
# In a command prompt it is the console version: join-roe-os.cmd with the arguments below, or typed
# without any, works in the prompt. join-roe-os.cmd --console forces the console (for example from
# PowerShell, whose .\join-roe-os.cmd counts as a double-click), join-roe-os.cmd --window the window. Both run
# the same functions below and share the settings, accounts and keys (%APPDATA%\roe-join.json,
# %APPDATA%\roe-join\).
#
# The window asks join-roe-os.cmd's questions as dialogs and shows its messages in the status line. The
# network, the firewall step (with the Windows administrator prompt) and the wait for the game run
# in a background runspace, so the window never freezes. What happened is in
# %APPDATA%\roe-join\gui.log ("Open the log", or "Details"). Windows PowerShell 5.1 and .NET
# Framework (WPF) only, as on every Windows 10 and 11.
#
# The console asks for
#   - the game folder (the last one is the default),
#   - the server (arrow keys and Enter; the servers joined before by name and address, the most
#     recently used on top, on the first start roe-os.de; the last entry asks for another address),
#   - the account to play with (arrow keys and Enter; the most recently used on top, the last
#     entry creates a new one),
# then keeps the game from reaching anything but the servers joined so far and the addresses
# each server names for its matches (Windows Firewall, asks for administrator approval only
# when the allowed addresses change), logs in to the server and starts the game. Answers are remembered in %APPDATA%\roe-join.json (the servers with their name and last use
# in "servers"). join-roe-os.cmd -Server <address> joins that server without the menu.
#
# Accounts: a new account gets a secret key from the server. The keys are kept with each
# account's current name in %APPDATA%\roe-join\<server>\accounts.json; copy that folder to play
# with the same accounts on another computer. With first-login on, the server names a new
# account (newaccount and 4 digits, for example newaccount1234) and the game asks for the real
# name; otherwise join-roe-os.cmd asks for it. join-roe-os.cmd -Name <name> picks the saved account of that
# name, or claims the name for a new one, without the menu. The server's certificate is
# remembered on first contact (server.pin there) and a different one is refused.
#
# The firewall rules are optional (asked once). From a command prompt:
#   join-roe-os.cmd firewall          shows the rules, the trusted servers, whether Windows applies them
#                              and where a running game is connected
#   join-roe-os.cmd firewall on|off   rules from the next join on, or none (removes this folder's rules)
#   join-roe-os.cmd firewall reset    removes the rules of every game folder and forgets the servers;
#                              the next join trusts only its own server
# After the step join-roe-os.cmd checks that the rules apply and that no block rule of another program
# names the game (those are removed with the step). When something is wrong (the prompt declined
# or never shown, the step failed, a policy rule) it says what to do and asks before the game
# starts. Run as administrator, it sets the rules without a prompt.
#
# Voice chat (on by default, asked once; join-roe-os.cmd voice on|off changes it): our GCloudVoice.dll
# replaces the game's while the game runs. It comes from voice\ next to this file, or from the
# folder the player gave (asked when it is missing and by join-roe-os.cmd voice on; saved as voice_dll,
# then used without asking). The original is kept with its hash in
# %APPDATA%\roe-join\voice-backup\ and put back when the game exits, or at the next start after a
# crash or a closed window.
#
# Game files: before a join, join-roe-os.cmd checks the files other launchers and lobby patchers change
# (the .sfc archives they append to, the lobby caches, GCloudVoice.dll) against the Steam install
# and looks for files a clean install does not have (proxy DLLs such as dinput8.dll, data_exp.vfs).
# When one differs it says which and how to repair it (Steam's Verify integrity of game files),
# and starts the game only when the player chooses to start anyway. The hashes are kept by size
# and write time in %APPDATA%\roe-join\file-check.json, so only the first start hashes the files.
# join-roe-os.cmd --skip-file-check leaves the check out.
#
# The server can name the oldest version of this script it takes (VERSION); an older one stops
# before the game starts and says where to get the new one.
#
# GM accounts: join-roe-os.cmd admin (with -Server and -Name as for a join) opens the server's admin page in
# the browser with a one-time login link (ROLE, then WEB; the server sends the page's address or
# it is https://admin.<the server's domain>). Other accounts are told they have no GM rights.
#
# Steam: with the launch option "<this file>" %command% Steam's Play button starts join-roe-os.cmd with the
# game's command line; it joins the server and account of join-roe-os.cmd steam-setup (else the last used
# ones) and starts the game itself. join-roe-os.cmd [-Server <address>] [-Name <name>] steam-setup [off]
# prints the line and sets (or removes) it in Steam while Steam is closed. The window's section
# "Set up starting through Steam" shows "<this file>" --window %command% to paste (Copy) and sets
# it (closing Steam first when the player agrees): Steam's Play button then opens the window,
# which joins the server and account saved there and closes itself when the game exits.
#
# Account backup: join-roe-os.cmd export [FILE] writes every server's accounts (their keys), certificate
# pin and name into one file (default roe-join-accounts.json here); join-roe-os.cmd import FILE merges
# one into this computer. join-roe-os.py reads and writes the same file (--export, --import).
#
# Nothing else in the game folder is changed.

# The administrator step of the firewall rules: join-roe-os.cmd starts this file (a .ps1 copy of it) as
# administrator with -FirewallStep and a file that names the rules to create and remove.
param([string]$FirewallStep = '')
$ErrorActionPreference = 'Stop'
# Tested Europa_Client.exe builds of 2022-0.2.989.0 x64: the root folder (DX11) and XVersion (DX12).
$expectedSha = @('2dca9b1e122e21363e14eeeb2372598c773205a907ed8d2b2d54a7229ad6ba18', 'e076dddcab4b48d52b920a84bbee125c8b452900ae90cea2f190f2e3654ff81d')
# This script's version; the server can ask for a newer one (VERSION). The same number as join-roe-os.py's
# and roe_server's (src/lobby/accounts.hpp kJoinScriptVersion).
$joinVersion = '1.0'
$joinUrl = 'https://github.com/mschnati/roe-os-client'
$lobbyPort = 8001
$accountPort = 8002
$settingsPath = Join-Path $env:APPDATA 'roe-join.json'
$joinRoot = Join-Path $env:APPDATA 'roe-join'

# roe-join.json as the console and the window write it.
function Save-JoinSettings([string]$Client, $Firewall, $Voice, $VoiceDll, $Servers) {
    $values = [ordered]@{ client = $Client; firewall = $Firewall; voice = $Voice; voice_dll = $VoiceDll; servers = @($Servers) }
    # The Steam profile (join-roe-os.cmd steam-setup) stays.
    $steam = $null
    try { if (Test-Path -LiteralPath $settingsPath) { $steam = (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).steam } } catch { }
    if ($steam) { $values.steam = $steam }
    [pscustomobject]$values | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}
function Read-Settings {
    if (Test-Path -LiteralPath $settingsPath) {
        try {
            $read = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            $read.PSObject.Properties.Remove('voice_dll_sha256')  # no longer used
            return $read
        } catch { }
    }
    return [pscustomobject]@{ client = ''; firewall = $null; voice = $null }
}
# The separate files (separate-files/, for virus scanners that flag this one file): join-roe-os.ps1
# holds this code, and its launchers set ROE_JOIN_CODE to it and ROE_JOIN_STEAM to
# join-roe-os-window.cmd, which the window's Steam launch option names. In this file: ROE_JOIN_SELF.
function Get-JoinCodePath { if ($env:ROE_JOIN_CODE) { return $env:ROE_JOIN_CODE }; return $env:ROE_JOIN_SELF }
function Get-WindowLauncher { if ($env:ROE_JOIN_STEAM) { return $env:ROE_JOIN_STEAM }; return $env:ROE_JOIN_SELF }
# The files a launch option of this copy may name: the one started, and the window launcher.
function Get-OwnLaunchers { return @(@($env:ROE_JOIN_SELF, $env:ROE_JOIN_STEAM) | Where-Object { $_ } | Select-Object -Unique) }
function Ask([string]$Question, [string]$Default) {
    $suffix = ''
    if ($Default) { $suffix = " [$Default]" }
    $answer = (Read-Host ($Question + $suffix)).Trim().Trim('"')
    if (-not $answer) { return $Default }
    return $answer
}
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($stream)) -replace '-', '').ToLowerInvariant() }
    finally { $stream.Dispose() }
}
function Test-Client([string]$Folder) {
    return $Folder -and (Test-Path -LiteralPath (Join-Path $Folder 'Europa_Client.exe') -PathType Leaf)
}
function ConvertTo-Dotted([uint32]$Number) {
    return '{0}.{1}.{2}.{3}' -f (($Number -shr 24) -band 255), (($Number -shr 16) -band 255), (($Number -shr 8) -band 255), ($Number -band 255)
}
# Everything but this computer and the given addresses (the servers the game may reach), as
# remote address ranges: the rules name no ports, so any port a server uses is allowed.
function Get-BlockedRanges([string[]]$Servers) {
    $allowed = @($Servers | Where-Object { $_ -notmatch ':' } | ForEach-Object {
        $bytes = [Net.IPAddress]::Parse($_).GetAddressBytes()
        [uint32](([uint32]$bytes[0] -shl 24) -bor ([uint32]$bytes[1] -shl 16) -bor ([uint32]$bytes[2] -shl 8) -bor [uint32]$bytes[3])
    } | Sort-Object -Unique)
    $ranges = @()
    foreach ($span in @(@([uint32]0, [uint32]2130706431), @([uint32]2147483648, [uint32]4294967295))) {
        [uint64]$low = $span[0]; [uint64]$high = $span[1]
        foreach ($server in $allowed) {
            if ($server -lt $low -or $server -gt $high) { continue }
            if ($server -gt $low) { $ranges += (ConvertTo-Dotted ([uint32]$low)) + '-' + (ConvertTo-Dotted ([uint32]($server - 1))) }
            $low = [uint64]$server + 1
        }
        if ($low -le $high) { $ranges += (ConvertTo-Dotted ([uint32]$low)) + '-' + (ConvertTo-Dotted ([uint32]$high)) }
    }
    # IPv6: everything but ::1, the IPv6 servers and the IPv4 servers' NAT64 addresses
    # (64:ff9b::a.b.c.d), for networks that reach IPv4 servers only through NAT64. The addresses
    # as 32 hex digits, so text order is number order.
    $open6 = [string[]]@(@($allowed | ForEach-Object { '0064ff9b0000000000000000' + $_.ToString('x8') }) +
        @($Servers | Where-Object { $_ -match ':' } | ForEach-Object { ConvertTo-Number6 $_ }) | Select-Object -Unique)
    [Array]::Sort($open6, [StringComparer]::Ordinal)
    $from = '00000000000000000000000000000002'
    foreach ($open in $open6) {
        if ([string]::CompareOrdinal($open, $from) -lt 0) { continue }
        if ([string]::CompareOrdinal($open, $from) -gt 0) { $ranges += (ConvertTo-Text6 $from) + '-' + (ConvertTo-Text6 (Step-Number6 $open -1)) }
        $from = Step-Number6 $open 1
    }
    if ($from) { $ranges += (ConvertTo-Text6 $from) + '-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff' }
    return $ranges
}
# An IPv6 address as 32 hex digits.
function ConvertTo-Number6([string]$Address) {
    return (-join ([Net.IPAddress]::Parse($Address).GetAddressBytes() | ForEach-Object { $_.ToString('x2') }))
}
# Number (32 hex digits) plus or minus one; '' past ffff...ffff.
function Step-Number6([string]$Number, [int]$By) {
    $bytes = [byte[]](0..15 | ForEach-Object { [Convert]::ToByte($Number.Substring($_ * 2, 2), 16) })
    for ($i = 15; $i -ge 0; $i--) {
        $value = [int]$bytes[$i] + $By
        $bytes[$i] = [byte](($value + 256) % 256)
        if ($value -ge 0 -and $value -le 255) { return (-join ($bytes | ForEach-Object { $_.ToString('x2') })) }
    }
    return ''
}
# All eight groups, no "::" (the firewall reads that too).
function ConvertTo-Text6([string]$Number) {
    return ((0..7 | ForEach-Object { [Convert]::ToInt32($Number.Substring($_ * 4, 4), 16).ToString('x') }) -join ':')
}
# An IPv4 or IPv6 address as text (an IPv4-mapped one as IPv4); $null for anything else, loopback,
# the unspecified, multicast or broadcast address.
function ConvertTo-CanonicalAddress([string]$Word) {
    if ($Word -notmatch '^[0-9a-fA-F.:]{2,45}$') { return $null }
    if ($Word -notmatch ':' -and $Word -notmatch '^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$') { return $null }
    $parsed = $null
    if (-not [Net.IPAddress]::TryParse($Word, [ref]$parsed)) { return $null }
    if ($parsed.IsIPv4MappedToIPv6) { $parsed = $parsed.MapToIPv4() }
    $text = $parsed.ToString()
    if ([Net.IPAddress]::IsLoopback($parsed) -or $parsed.IsIPv6Multicast -or $text -in @('0.0.0.0', '::', '255.255.255.255')) { return $null }
    if ($parsed.AddressFamily -eq 'InterNetwork' -and ($parsed.GetAddressBytes()[0] -band 240) -eq 224) { return $null }
    return $text
}
# The ADDRESSES answer: where else the game goes for this server (its matches on other machines),
# each once, at most 64; $null without an OK (no answer or the limit). Other words are skipped.
function Get-ServerAddresses([string]$Reply) {
    if ($Reply -cne 'OK' -and -not $Reply.StartsWith('OK ', [StringComparison]::Ordinal)) { return $null }
    $found = New-Object System.Collections.ArrayList
    foreach ($word in ($Reply.Substring(2) -split ' ')) {
        $address = ConvertTo-CanonicalAddress $word
        if ($address -and -not $found.Contains($address) -and $found.Count -lt 64) { [void]$found.Add($address) }
    }
    return ,[string[]]@($found)
}
# The trusted servers after a join: the earlier ones (Trusted) with this server's own addresses
# (ServerIps) and the ones it lists (Listed; $null without an answer: nothing is dropped). What
# it listed before (Previous) and lists no more goes, and so do its own earlier addresses
# (PreviousIps: a domain that moved), unless another saved server needs them (Kept).
function Get-TrustedUpdate([string[]]$Trusted, [string[]]$ServerIps, $Listed, [string[]]$Previous, [string[]]$Kept, [string[]]$PreviousIps) {
    $candidates = @($PreviousIps)
    if ($null -ne $Listed) { $candidates += @($Previous) }
    $drop = @($candidates | Where-Object { $_ -and $Listed -notcontains $_ -and $ServerIps -notcontains $_ -and $Kept -notcontains $_ })
    return ,[string[]]@(@($Trusted) + @($ServerIps) + @($Listed) |
        Where-Object { $_ -and $drop -notcontains $_ -and $_ -notlike '127.*' -and $_ -ne '::1' } | Sort-Object -Unique)
}
# What other saved servers need: the addresses they list, their own addresses and an address given
# as IP.
function Get-KeptAddresses($Servers, [string]$Address) {
    $key = Get-ServerFolderName $Address
    $kept = @()
    foreach ($s in @($Servers | Where-Object { $_ -and (Get-ServerFolderName $_.address) -ne $key })) {
        $kept += @($s.addresses) + @($s.ips) + @(ConvertTo-CanonicalAddress ("$($s.address)" -replace ':8001$', ''))
    }
    return ,[string[]]@($kept | Where-Object { $_ } | Sort-Object -Unique)
}
# True when a folder's rules (Own) cover its programs, are on and trust exactly Desired.
function Test-RulesCurrent($Own, [int]$ProgramCount, [string[]]$Desired) {
    $Own = @($Own | Where-Object { $_ })
    if (-not $Own.Count -or $Own.Count -ne $ProgramCount -or @($Own | Where-Object { "$($_.Enabled)" -ne 'True' }).Count) { return $false }
    return (@(Get-TrustedServers $Own | Sort-Object -Unique) -join ' ') -eq (@($Desired | Sort-Object -Unique) -join ' ')
}

# --- Firewall -------------------------------------------------------------------------------
function Get-FirewallGroup([string]$Client) {
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($Client.ToLowerInvariant()))
    return ([BitConverter]::ToString($hash) -replace '-', '').Substring(0, 12)
}
# The executables of a game folder; subfolders with a game of their own (XVersion in the main
# folder) get their own rules.
function Get-GamePrograms([string]$Client) {
    $nested = @(Get-ChildItem -LiteralPath $Client -Recurse -File -Filter 'Europa_Client.exe' | Where-Object { $_.DirectoryName -ne $Client } | ForEach-Object { $_.DirectoryName + '\' })
    return @(Get-ChildItem -LiteralPath $Client -Recurse -File -Filter '*.exe' | ForEach-Object { $_.FullName } |
        Where-Object { $path = $_; -not ($nested | Where-Object { $path.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }) })
}
# The servers named in a folder's rules ("servers a b").
function Get-TrustedServers($Rules) {
    $descriptions = @($Rules | ForEach-Object { $_.Description } | Sort-Object -Unique)
    if ($descriptions.Count -eq 1 -and $descriptions[0] -match '^servers ([0-9a-fA-F.: ]+)$') { return @($Matches[1].Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) }
    return @()
}
# Why Windows would not apply the rules: the firewall service, a profile switched off, or a
# policy that ignores local rules. Empty when they apply.
function Get-FirewallProblems {
    $problems = @()
    $service = Get-Service -Name mpssvc -ErrorAction SilentlyContinue
    if (-not $service -or $service.Status -ne 'Running') { $problems += 'the Windows Firewall service (mpssvc) does not run' }
    foreach ($profile in @(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction SilentlyContinue)) {
        if ("$($profile.Enabled)" -eq 'False') { $problems += "the firewall is off for the $($profile.Name) network profile" }
        if ("$($profile.AllowLocalFirewallRules)" -eq 'False') { $problems += "a policy ignores local rules on the $($profile.Name) profile" }
    }
    return $problems
}
# Game processes from these programs that run now.
function Get-RunningGame([string[]]$Programs) {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and ($Programs -contains $_.Path) })
}
function Assert-GameClosed([string[]]$Programs) {
    $running = @(Get-RunningGame $Programs)
    if ($running.Count) { throw "The game runs ($($running[0].Path)). Close it first: changing the rules now could cut it off from the server." }
}
function Test-Administrator {
    try { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false }
}
# Runs a firewall step as administrator: directly when join-roe-os.cmd runs as one, else through a
# Windows prompt. The step is data (Create: rules with Name, Group, Description, Program and
# RemoteAddress; Remove: rule names) in a file that a .ps1 copy of join-roe-os.cmd reads with
# -FirewallStep (Invoke-FirewallStep). Returns Ok and Reason: done; declined (the prompt said no,
# or Windows denies it on this account); not-admin (it ran without administrator rights, User
# Account Control off on a standard account); failed (Detail: the error); no-start (Windows did
# not start it). A declined or not started prompt is offered again (Ask).
function Invoke-Elevated($Plan, [bool]$Admin = (Test-Administrator)) {
    $folder = Join-Path $env:APPDATA 'roe-join'
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    $id = [Guid]::NewGuid().ToString('N')
    $step = Join-Path $folder "firewall-step-$id.json"
    $script = Join-Path $folder "firewall-step-$id.ps1"
    $log = "$step.log"
    $code = $null
    try {
        Set-Content -LiteralPath $step -Value (ConvertTo-Json -InputObject $Plan -Depth 5) -Encoding UTF8
        # The bytes only: File.Copy would take a download's mark along, and PowerShell would refuse it.
        [IO.File]::WriteAllBytes($script, [IO.File]::ReadAllBytes((Get-JoinCodePath)))
        if ($Admin) {
            & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $script -FirewallStep $step | Out-Host
            $code = $LASTEXITCODE
        } else {
            $arguments = "-NoProfile -ExecutionPolicy RemoteSigned -File `"$script`" -FirewallStep `"$step`""
            while ($null -eq $code) {
                # The window to the front first: Windows shows the prompt in front only for the window in front.
                if ($sync) { $sync.Events.Enqueue([pscustomobject]@{ Kind = 'front'; Data = $null }); Start-Sleep -Milliseconds 300 }
                try { $code = Start-Elevated $arguments }
                catch {
                    $failure = Get-ElevationFailure $_
                    if ((Ask "$(Get-ElevationNote $failure) Try again? (y/n)" 'y') -notmatch '^[yY]') { return $failure }
                }
            }
        }
    } catch {
        return Get-ElevationFailure $_
    } finally {
        Remove-Item -LiteralPath $script, $step -ErrorAction SilentlyContinue
    }
    $detail = ''
    if (Test-Path -LiteralPath $log) { $detail = "$(Get-Content -LiteralPath $log -Raw)".Trim(); Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue }
    if ($code -eq 0) { return [pscustomobject]@{ Ok = $true; Reason = 'done'; Detail = '' } }
    if ($code -eq 3) { return [pscustomobject]@{ Ok = $false; Reason = 'not-admin'; Detail = '' } }
    return [pscustomobject]@{ Ok = $false; Reason = 'failed'; Detail = $detail }
}
# Why the elevated start failed (its error record): declined (the prompt said no) or no-start.
function Get-ElevationFailure($Record) {
    $native = $Record.Exception.InnerException.NativeErrorCode
    if ($null -eq $native) { $native = $Record.Exception.NativeErrorCode }
    $reason = if ($native -eq 1223 -or ($null -eq $native -and $Record.Exception.Message -match 'cancel')) { 'declined' } else { 'no-start' }
    $message = if ($Record.Exception.InnerException) { $Record.Exception.InnerException.Message } else { $Record.Exception.Message }
    return [pscustomobject]@{ Ok = $false; Reason = $reason; Detail = $message }
}
# The window the administrator prompt belongs to: the join window ($sync.Owner, set by the window)
# or this console's. Windows brings the prompt to the front only for a window in front that asks;
# Start-Process names none (and hides any error), so from the window's hidden PowerShell the prompt
# could stay behind other windows or as a button in the taskbar.
function Get-PromptOwner {
    if ($sync -and $sync.Owner) { return [IntPtr]$sync.Owner }
    try { return [Diagnostics.Process]::GetCurrentProcess().MainWindowHandle } catch { return [IntPtr]::Zero }
}
# The elevated start of powershell.exe with Arguments: through the shell with "runas", in a
# normal window, Owner as the prompt's window (.NET passes it on only with ErrorDialog).
function New-ElevatedStart([string]$Arguments, [IntPtr]$Owner) {
    $start = New-Object Diagnostics.ProcessStartInfo 'powershell.exe', $Arguments
    $start.Verb = 'runas'
    $start.UseShellExecute = $true
    $start.WindowStyle = 'Normal'
    $start.ErrorDialog = $true
    $start.ErrorDialogParentHandle = $Owner
    return $start
}
# Starts it, waits for it and returns its exit code.
function Start-Elevated([string]$Arguments) {
    $process = [Diagnostics.Process]::Start((New-ElevatedStart $Arguments (Get-PromptOwner)))
    if (-not $process) { throw 'Windows did not start the step.' }
    try { $process.WaitForExit(); return $process.ExitCode } finally { $process.Dispose() }
}
# The step itself, in the administrator's PowerShell: creates the rules of the file at Path (if one
# fails, the ones it created go again and nothing is removed), then removes the named rules.
# Returns the exit code: 0 done, 1 failed (the error in Path.log), 3 no administrator rights.
function Invoke-FirewallStep([string]$Path) {
    if (-not (Test-Administrator)) { return 3 }
    $created = @()
    try {
        $plan = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        try {
            foreach ($rule in @($plan.Create | Where-Object { $_ })) {
                New-NetFirewallRule -Name $rule.Name -DisplayName $rule.Name -Group $rule.Group -Description $rule.Description -Direction Outbound -Action Block `
                    -Program $rule.Program -RemoteAddress @($rule.RemoteAddress) -Profile Any -Enabled True | Out-Null
                $created += $rule.Name
            }
        } catch {
            foreach ($name in $created) { Remove-NetFirewallRule -Name $name -ErrorAction SilentlyContinue }
            throw
        }
        foreach ($name in @($plan.Remove | Where-Object { $_ })) { Remove-NetFirewallRule -Name $name -ErrorAction SilentlyContinue }
    } catch {
        Set-Content -LiteralPath "$Path.log" -Value "$_"
        return 1
    }
    return 0
}
# What went wrong in the administrator step, in words. Empty when it worked.
function Get-ElevationNote($Result) {
    $runAsOnce = 'right-click join-roe-os.cmd > Run as administrator once (on a standard Windows account this needs an administrator''s password).'
    if (-not $Result -or $Result.Reason -eq 'done') { return '' }
    switch ($Result.Reason) {
        'declined' { return "Windows did not ask for administrator rights, or the prompt was declined: $runAsOnce" }
        'not-admin' { return "Windows did not ask for administrator rights (User Account Control is off or never asks on this account, so the step ran without them): $runAsOnce" }
        'no-start' { return "Windows did not ask for administrator rights ($($Result.Detail)): $runAsOnce" }
    }
    if ($Result.Detail) { return "Changing the firewall rules failed: $($Result.Detail)" }
    return 'Changing the firewall rules failed.'
}
# Enabled block rules of other programs (other launchers, or Windows' own "blocked some
# features" prompt) that name one of these programs. A block rule wins over any allow. Local
# ones can be removed, others (group policy, a security product) only where they come from.
function Get-ForeignBlockRules([string[]]$Programs) {
    $found = @()
    $filters = @(Get-NetFirewallApplicationFilter -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Where-Object {
        $program = [Environment]::ExpandEnvironmentVariables("$($_.Program)")
        $Programs | Where-Object { $_ -ieq $program } })
    foreach ($filter in $filters) {
        foreach ($rule in @($filter | Get-NetFirewallRule -ErrorAction SilentlyContinue)) {
            if ("$($rule.Action)" -ne 'Block' -or "$($rule.Enabled)" -ne 'True' -or "$($rule.Group)" -like 'ROE2022-*') { continue }
            $found += [pscustomobject]@{ Name = $rule.Name; DisplayName = "$($rule.DisplayName)"; Program = [Environment]::ExpandEnvironmentVariables("$($filter.Program)")
                Direction = "$($rule.Direction)"; Local = "$($rule.PolicyStoreSourceType)" -eq 'Local' }
        }
    }
    return $found
}
# Security products other than Windows Firewall that say they run the firewall.
function Get-OtherFirewalls {
    return @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName FirewallProduct -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.displayName)" } | Where-Object { $_ -and $_ -notmatch 'Windows' } | Sort-Object -Unique)
}
# What still keeps the game from the servers after the firewall step: a program without its
# enabled rule for exactly the trusted servers (Own: Program, Enabled, Description; from the
# active store), a block rule of another program (Blocking). Empty when the rules are right.
# Own is $null with the rules off.
function Get-RuleProblems([string[]]$Programs, $Own, [string[]]$Wanted, $Blocking) {
    $problems = @()
    if ($null -ne $Own) {
        $want = @($Wanted | Sort-Object -Unique) -join ' '
        $missing = @(); $off = @(); $stale = @()
        foreach ($program in $Programs) {
            $rules = @($Own | Where-Object { $_ -and $_.Program -ieq $program })
            if (-not $rules.Count) { $missing += $program; continue }
            $on = @($rules | Where-Object { "$($_.Enabled)" -eq 'True' })
            if (-not $on.Count) { $off += $program; continue }
            if (-not @($on | Where-Object { (@(Get-TrustedServers @($_) | Sort-Object -Unique) -join ' ') -eq $want }).Count) { $stale += $program }
        }
        if ($missing.Count) { $problems += "no join-roe-os.cmd rule for $($missing.Count) of $($Programs.Count) game programs (for example $(Split-Path -Leaf $missing[0]))" }
        if ($off.Count) { $problems += "the join-roe-os.cmd rule is off for $($off.Count) game programs" }
        if ($stale.Count) { $problems += "the join-roe-os.cmd rules of $($stale.Count) game programs trust other servers than $($Wanted -join ', ')" }
    }
    foreach ($rule in @($Blocking | Where-Object { $_ })) {
        $where = if ($rule.Local) { 'a local rule' } else { 'a rule of a policy or security product' }
        $leaf = if ("$($rule.Program)") { Split-Path -Leaf "$($rule.Program)" } else { 'the game' }
        $problems += "$where blocks $leaf ($($rule.Direction)): `"$($rule.DisplayName)`""
    }
    return $problems
}
# What to do about it.
function Get-FirewallAdvice([string]$Self, $Blocking, [bool]$Admin) {
    $lines = @()
    if (@($Blocking | Where-Object { $_ -and -not $_.Local }).Count) {
        $lines += 'Remove or turn off the rules of the policy or security product where they come from (or ask who manages this PC).'
    }
    if ($Admin) {
        $lines += 'join-roe-os.cmd already runs as administrator: check the error above, or run "join-roe-os.cmd firewall" to see the rules.'
    } else {
        $lines += 'Right-click join-roe-os.cmd > Run as administrator, or in a command prompt opened with "Run as administrator":'
        $lines += "  `"$Self`""
        $lines += 'On a standard Windows account this needs an administrator''s password.'
    }
    $lines += 'Or turn the rules off with "join-roe-os.cmd firewall off" (then the game can reach the internet).'
    return $lines
}
function Get-RuleNames($Rules) {
    return [string[]]@($Rules | Where-Object { $_ } | ForEach-Object { $_.Name })
}
# A folder's rules of this launcher (Own), and others that block one of its programs (Other):
# the server launcher's for this folder, ones made for another folder, or local block rules of
# other programs. Block rules win, so those would block the server too. Fixed: block rules of a
# policy or security product, which join-roe-os.cmd cannot remove.
function Get-FolderRules([string]$Client, [string[]]$Programs) {
    $id = Get-FirewallGroup $Client
    $group = "ROE2022-join-$id"
    $all = @(Get-NetFirewallRule -Group 'ROE2022-*' -ErrorAction SilentlyContinue)
    $own = @($all | Where-Object { $_.Group -eq $group })
    $other = @($all | Where-Object { $_.Group -ne $group } |
        Where-Object { $_.Group -eq "ROE2022-local-$id" -or ($Programs -contains ($_ | Get-NetFirewallApplicationFilter).Program) })
    $foreign = @(Get-ForeignBlockRules $Programs)
    $other += @($foreign | Where-Object { $_.Local })
    return [pscustomobject]@{ Group = $group; Own = $own; Other = $other; Fixed = @($foreign | Where-Object { -not $_.Local }) }
}
# This folder's rules as Windows applies them (the active store), for Get-RuleProblems.
function Get-ActiveOwnRules([string]$Group) {
    return @(Get-NetFirewallRule -Group $Group -PolicyStore ActiveStore -ErrorAction SilentlyContinue | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Enabled = "$($_.Enabled)"; Description = $_.Description
            Program = [Environment]::ExpandEnvironmentVariables("$(($_ | Get-NetFirewallApplicationFilter).Program)") } })
}
# After the firewall step: whether the rules really apply and nothing else blocks the game.
# Problems (empty when all is right) and Blocking (the block rules, for Get-FirewallAdvice).
# Wanted: the trusted servers; RulesOn false: only block rules count.
function Get-FirewallCheck([string]$Client, [string[]]$Programs, [string[]]$Wanted, [bool]$RulesOn) {
    $folder = Get-FolderRules $Client $Programs
    $own = if ($RulesOn) { @(Get-ActiveOwnRules $folder.Group) } else { $null }
    # Other: foreign block rules (with Local) and rules of play.cmd or another folder; with the
    # rules off, this folder's own ones block too.
    $left = @($folder.Other) + @(if (-not $RulesOn) { $folder.Own })
    $blocking = @($folder.Fixed) + @($left | Where-Object { $_ } | ForEach-Object {
        if ($null -ne $_.Local) { $_ }
        else { [pscustomobject]@{ DisplayName = "$($_.DisplayName)"; Program = "$(($_ | Get-NetFirewallApplicationFilter).Program)"; Direction = "$($_.Direction)"; Local = $true } } })
    return [pscustomobject]@{ Problems = @(Get-RuleProblems $Programs $own $Wanted $blocking); Blocking = $blocking }
}
# The check above; when something is wrong, says what happened and what to do and asks whether to
# start anyway (throws when not).
function Confirm-FirewallState([string]$Client, [string[]]$Programs, [string[]]$Wanted, [bool]$RulesOn, $Step) {
    $check = Get-FirewallCheck $Client $Programs $Wanted $RulesOn
    $problems = @($check.Problems)
    $blocking = $check.Blocking
    if (-not $problems.Count) { return }
    Write-Host ''
    Write-Host 'The firewall rules are not as they should be, so the game may not reach the server:' -ForegroundColor Yellow
    $note = Get-ElevationNote $Step
    if ($note) { Write-Host $note -ForegroundColor Yellow }
    foreach ($problem in @($problems | Select-Object -First 5)) { Write-Host "  - $problem" -ForegroundColor Yellow }
    if ($problems.Count -gt 5) { Write-Host "  - and $($problems.Count - 5) more (join-roe-os.cmd firewall shows them)" -ForegroundColor Yellow }
    foreach ($line in (Get-FirewallAdvice $env:ROE_JOIN_SELF $blocking (Test-Administrator))) { Write-Host $line }
    if ((Ask 'Start the game anyway? (y/n)' 'n') -notmatch '^[yY]') { throw 'Cancelled: the firewall rules are not in place.' }
}
# Firewall: the setting (true on, false off, $null not asked yet).
function Show-Firewall([string]$Client, $Firewall) {
    $problems = @(Get-FirewallProblems)
    if ($problems.Count) { Write-Host ('Windows does not apply firewall rules: ' + ($problems -join '; ') + '.') -ForegroundColor Yellow }
    else { Write-Host 'Windows Firewall runs and applies local rules.' }
    $join = @(Get-NetFirewallRule -Group 'ROE2022-join-*' -ErrorAction SilentlyContinue)
    $local = @(Get-NetFirewallRule -Group 'ROE2022-local-*' -ErrorAction SilentlyContinue)
    Write-Host ("Rules of join-roe-os.cmd: $($join.Count) for $(@($join | ForEach-Object { $_.Group } | Sort-Object -Unique).Count) game folders; " +
        "of the server launcher: $($local.Count).")
    if (Test-Client $Client) {
        $programs = Get-GamePrograms $Client
        $folder = Get-FolderRules $Client $programs
        $trusted = @(Get-TrustedServers $folder.Own)
        $names = if ($trusted.Count) { $trusted -join ', ' } else { 'none' }
        Write-Host "This game folder ($Client): $($folder.Own.Count) rules for $($programs.Count) programs, trusted servers: $names."
        $active = @(Get-NetFirewallRule -Group $folder.Group -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Where-Object { "$($_.Enabled)" -eq 'True' })
        if ($folder.Own.Count -and $active.Count -lt $folder.Own.Count) { Write-Host "Only $($active.Count) of them are active." -ForegroundColor Yellow }
        if ($folder.Other.Count) { Write-Host "$($folder.Other.Count) other rules block programs of this folder; the next join removes them." }
        foreach ($rule in $folder.Fixed) { Write-Host "A rule of a policy or security product blocks $(Split-Path -Leaf $rule.Program): `"$($rule.DisplayName)`" (remove it where it comes from)." -ForegroundColor Yellow }
        foreach ($product in (Get-OtherFirewalls)) { Write-Host "$product says it runs the firewall: allow the game there too." }
        foreach ($process in (Get-RunningGame $programs)) {
            $remote = @(Get-NetTCPConnection -OwningProcess $process.Id -ErrorAction SilentlyContinue |
                Where-Object { $_.RemoteAddress -notin @('0.0.0.0', '::', '127.0.0.1', '::1') } |
                ForEach-Object { "$($_.RemoteAddress):$($_.RemotePort) ($($_.State))" } | Sort-Object -Unique)
            $list = if ($remote.Count) { $remote -join ', ' } else { 'none' }
            Write-Host "Running: $($process.Path) (process $($process.Id)), TCP connections: $list."
        }
    }
    $state = if ($null -eq $Firewall) { 'not asked yet' } elseif ($Firewall) { 'on' } else { 'off' }
    Write-Host "join-roe-os.cmd creates rules: $state. Commands: join-roe-os.cmd firewall on | off | reset"
}
# The rules that let a folder's programs reach only this computer and the trusted servers. The
# new rules are created before the old ones go; if that fails, the new ones are removed again
# and the old ones stay.
function Set-FolderRules([string[]]$Programs, $Folder, [string[]]$Trusted) {
    $wanted = 'servers ' + ($Trusted -join ' ')
    $ranges = [string[]]@(Get-BlockedRanges $Trusted)
    $generation = [DateTime]::UtcNow.ToString('yyMMddHHmmss')
    $create = @()
    for ($index = 0; $index -lt $Programs.Count; $index++) {
        $create += [pscustomobject]@{ Name = "$($Folder.Group)-$generation-$index"; Group = $Folder.Group; Description = $wanted; Program = $Programs[$index]; RemoteAddress = $ranges }
    }
    return Invoke-Elevated ([pscustomobject]@{ Create = $create; Remove = (Get-RuleNames (@($Folder.Own) + @($Folder.Other))) })
}
function Remove-Rules($Rules, [string]$What) {
    $Rules = @($Rules | Where-Object { $_ })
    if (-not $Rules.Count) { Write-Host "No firewall rules $What."; return }
    $prompt = if (Test-Administrator) { '' } else { ' (a Windows prompt appears; not in front: click the flashing shield in the taskbar)' }
    Write-Host "Removing $($Rules.Count) firewall rules $What$prompt."
    $step = Invoke-Elevated ([pscustomobject]@{ Create = @(); Remove = (Get-RuleNames $Rules) })
    if (-not $step.Ok) { throw ('The firewall rules were not removed. ' + (Get-ElevationNote $step)) }
    Write-Host 'Removed.'
}

# --- Account backup -------------------------------------------------------------------------
# One JSON file with every server's accounts (names, keys, last use), certificate pin, address and
# name, the same for join-roe-os.cmd and join-roe-os.py: {"format": "roe-join-accounts", "version": 1,
# "servers": [{"address", "name", "pin", "accounts": [{"name", "token", "last_used"}]}]}.
$backupFormat = 'roe-join-accounts'
$backupWarning = 'The file holds your account keys: anyone who has it can play as you. Keep it private.'
# A saved server address fit for a folder name: no path, at most 255 characters.
function Test-BackupAddress([string]$Address) { return $Address -and $Address.Length -le 255 -and $Address -match '^[A-Za-z0-9._:\[\]-]+$' -and $Address -notmatch '^\.+$' }
# The backup of every server in Root (the roe-join folder) and the settings' servers.
function Get-AccountBackup([string]$Root, $Settings) {
    $rows = @()
    foreach ($s in @(Read-Servers $Settings)) {
        $folder = Join-Path $Root (Get-ServerFolderName $s.address)
        $pinPath = Join-Path $folder 'server.pin'
        $pin = if (Test-Path -LiteralPath $pinPath) { (Get-Content -LiteralPath $pinPath -Raw).Trim() } else { '' }
        $saved = Read-Accounts $folder
        $accounts = @($saved | ForEach-Object { [pscustomobject]@{ name = $_.name; token = $_.token; last_used = [int64]$_.last_used } })
        if (-not $accounts.Count -and -not $pin) { continue }
        $rows += [pscustomobject]@{ address = $s.address; name = "$($s.name)"; pin = $pin; accounts = $accounts }
    }
    return [pscustomobject]@{ format = $backupFormat; version = 1; servers = $rows }
}
function Export-Accounts([string]$Root, $Settings, [string]$File) {
    $backup = Get-AccountBackup $Root $Settings
    $json = ConvertTo-Json -Depth 6 -InputObject $backup
    [IO.File]::WriteAllText($File, $json, (New-Object Text.UTF8Encoding $false))
    $count = 0; foreach ($s in $backup.servers) { $count += @($s.accounts).Count }
    return [pscustomobject]@{ Servers = @($backup.servers).Count; Accounts = $count }
}
# Merges a backup into Root: new accounts are added, one already there (same key or name) keeps
# whichever was used last; a different certificate pin is replaced only when the player says so
# (else that server is skipped). Returns the settings' servers list with the new servers, and
# what was done.
function Import-Accounts([string]$Root, $Settings, [string]$File) {
    $backup = Get-Content -LiteralPath $File -Raw -Encoding UTF8 | ConvertFrom-Json
    if ("$($backup.format)" -ne $backupFormat -or -not ($backup.version -is [int] -or $backup.version -is [long]) -or [int64]$backup.version -lt 1) {
        throw "$File is no account backup of join-roe-os.cmd or join-roe-os.py."
    }
    $servers = @(Read-Servers $Settings)
    $result = [pscustomobject]@{ Servers = $servers; Added = 0; Updated = 0; Skipped = @() }
    foreach ($s in @($backup.servers)) {
        $address = "$($s.address)".Trim()
        if (-not (Test-BackupAddress $address)) { continue }
        $folder = Join-Path $Root (Get-ServerFolderName $address)
        $pin = "$($s.pin)".Trim().ToLowerInvariant()
        if ($pin -and $pin -notmatch '^[0-9a-f]{64}$') { $pin = '' }
        $pinPath = Join-Path $folder 'server.pin'
        if ($pin -and (Test-Path -LiteralPath $pinPath)) {
            $mine = (Get-Content -LiteralPath $pinPath -Raw).Trim()
            if ($mine -ne $pin) {
                Write-Host "The backup has another server certificate for $address than this computer ($mine)."
                Write-Host 'Replace it only if the server was set up again; otherwise someone may be in between.'
                if ((Ask "Take the backup's certificate and accounts for $address? (y/n)" 'n') -notmatch '^[yY]') { $result.Skipped += $address; continue }
            }
        }
        $list = Read-Accounts $folder
        $changed = $false
        foreach ($a in @($s.accounts)) {
            if (-not $a -or "$($a.token)" -cnotmatch '^[0-9a-f]{64}$') { continue }
            $name = "$($a.name)"
            if (-not $name -or $name.Length -gt 24 -or $name -match '[\x00-\x1f]') { $name = '?' }
            $last = [int64]0
            try { $last = [int64]$a.last_used } catch { }
            $new = [pscustomobject]@{ name = $name; token = "$($a.token)"; last_used = $last }
            $same = @($list | Where-Object { $_.token -ceq $new.token -or ($name -ne '?' -and $_.name -eq $name) })
            if (-not $same.Count) { [void]$list.Add($new); $result.Added++; $changed = $true; continue }
            if ($same[0].last_used -lt $last) {
                $list[$list.IndexOf($same[0])] = $new; $result.Updated++; $changed = $true
            }
        }
        if ($changed) { Save-Accounts $folder $list | Out-Null }
        if ($pin) { New-Item -ItemType Directory -Force -Path $folder | Out-Null; Set-Content -LiteralPath $pinPath -Value $pin -Encoding ASCII }
        $key = Get-ServerFolderName $address
        $entry = @($result.Servers | Where-Object { (Get-ServerFolderName $_.address) -eq $key })
        $name = Get-CleanServerName "$($s.name)"
        if (-not $entry.Count) {
            $used = [int64]0; foreach ($a in $list) { if ($a.last_used -gt $used) { $used = $a.last_used } }
            $result.Servers = @($result.Servers) + @([pscustomobject]@{ address = $address; last_used = $used; name = $name; addresses = [string[]]@(); ips = [string[]]@() })
        } elseif ($name -and -not "$($entry[0].name)") {
            $entry[0] | Add-Member -NotePropertyName name -NotePropertyValue $name -Force
        }
    }
    return $result
}

# --- Voice chat -----------------------------------------------------------------------------
$voiceFile = 'GCloudVoice.dll'
$voiceBackupName = 'roe-join-backup'  # in the game folder: the original DLL
$joinFolder = Split-Path -Parent "$env:ROE_JOIN_SELF"
$voiceSource = Join-Path $joinFolder 'voice'
# Where our DLL is looked for without asking: next to join-roe-os.cmd, then in its voice folder.
function Get-DefaultVoiceDll {
    foreach ($folder in @(@($joinFolder, $voiceSource) | Where-Object { $_ })) {
        $candidate = Join-Path $folder $voiceFile
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return Join-Path $(if ($joinFolder) { $joinFolder } else { $voiceSource }) $voiceFile
}
$voiceDownload = 'https://github.com/mschnati/roe-os-client/raw/main/voice/GCloudVoice.dll'
$voiceBackups = Join-Path (Join-Path $env:APPDATA 'roe-join') 'voice-backup'
$verifyHint = 'Steam: Ring of Elysium > Properties > Installed Files > Verify integrity of game files'
function Get-VoiceBackupFolder([string]$Client) { return Join-Path $voiceBackups (Get-FirewallGroup $Client) }
# The original DLL is kept in the game folder (roe-join-backup\GCloudVoice.dll), where players find
# it; the record with the hashes stays in %APPDATA%.
function Get-VoiceOriginal([string]$Client) { return Join-Path (Join-Path $Client $voiceBackupName) $voiceFile }
function Write-VoiceReadme([string]$Client) {
    $text = "The game's original $voiceFile, saved by join-roe-os.cmd before it put in the one for voice chat.`r`n" +
        "join-roe-os.cmd puts it back when the game exits. To do it by hand: copy $voiceFile from this folder into`r`n$Client`r`n" +
        "(replace the file there). Or in Steam: Ring of Elysium > Properties > Installed Files > Verify integrity of game files.`r`n"
    try { Set-Content -LiteralPath (Join-Path (Join-Path $Client $voiceBackupName) 'README.txt') -Value $text -Encoding ASCII -NoNewline } catch { }
}
function Test-GameRunning([string]$Client) {
    $exe = Join-Path $Client 'Europa_Client.exe'
    return [bool]@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }).Count
}
# Copies Source over Target through a temporary file: '' when Target then has the hash, else why not.
function Copy-Checked([string]$Source, [string]$Target, [string]$Hash) {
    $temp = $Target + '.roe-join'
    try {
        [IO.File]::Copy($Source, $temp, $true)
        if ((Get-Sha256 $temp) -ne $Hash) { throw 'the copy differs' }
        if (Test-Path -LiteralPath $Target) { [IO.File]::Replace($temp, $Target, [NullString]::Value) } else { [IO.File]::Move($temp, $Target) }
        return ''
    } catch {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        return $_.Exception.Message
    }
}
function Read-VoiceRecord([string]$Folder) {
    try { return Get-Content -LiteralPath (Join-Path $Folder 'backup.json') -Raw | ConvertFrom-Json } catch { return $null }
}
# Puts the original DLL back where ours is in place. False when it could not.
function Restore-Voice([string]$Client, [int]$Wait = 0) {
    $folder = Get-VoiceBackupFolder $Client
    $record = Read-VoiceRecord $folder
    if (-not $record) { return $true }
    $target = Join-Path $Client $voiceFile
    # No DLL at all (deleted by hand): the game cannot start without one, so the original goes back.
    $missing = -not (Test-Path -LiteralPath $target -PathType Leaf)
    if ($missing) { $current = $record.installed } else { try { $current = Get-Sha256 $target } catch {
        Write-Host "Voice chat: cannot read $target ($($_.Exception.Message)). Close the game and start join-roe-os.cmd again, or: $verifyHint." -ForegroundColor Yellow
        return $false
    } }
    if ($current -ne $record.installed) { return $true }  # the original is back, or Steam replaced the file
    $deadline = (Get-Date).AddSeconds($Wait)
    while (Test-GameRunning $Client) {
        if ((Get-Date) -ge $deadline) {
            Write-Host "Voice chat: the game in $Client runs; its original $voiceFile is put back at the next start."
            return $false
        }
        Start-Sleep -Seconds 1
    }
    $saved = Get-VoiceOriginal $Client
    $good = $false
    try { $good = (Get-Sha256 $saved) -eq $record.original } catch { }
    if (-not $good) {
        Write-Host "Voice chat: the backup of the original $voiceFile ($saved) is missing or damaged, so $target is still ours. To get the original back: $verifyHint." -ForegroundColor Yellow
        return $false
    }
    $problem = ''
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        $problem = Copy-Checked $saved $target $record.original
        if (-not $problem) { Write-Host "Voice chat: the original $voiceFile is back in $Client."; return $true }
        Start-Sleep -Seconds 1
    }
    Write-Host "Voice chat: could not put the original $voiceFile back in $Client ($problem). Close the game and start join-roe-os.cmd again (it puts it back first), or: $verifyHint." -ForegroundColor Yellow
    return $false
}
# At every start: the original back wherever ours was left (a crash or a closed window).
function Restore-AllVoice {
    foreach ($file in @(Get-ChildItem -LiteralPath $voiceBackups -Filter 'backup.json' -Recurse -File -ErrorAction SilentlyContinue)) {
        $record = Read-VoiceRecord $file.DirectoryName
        if ($record -and $record.folder) { Restore-Voice $record.folder | Out-Null }
    }
}
# A 64-bit (x64) Windows DLL: MZ, PE, machine 0x8664, the DLL flag.
function Test-Dll64([byte[]]$Bytes) {
    if ($Bytes.Length -lt 64 -or $Bytes[0] -ne 0x4D -or $Bytes[1] -ne 0x5A) { return $false }
    $pe = [BitConverter]::ToInt32($Bytes, 0x3c)
    if ($pe -lt 0 -or $pe + 24 -gt $Bytes.Length) { return $false }
    return [BitConverter]::ToUInt32($Bytes, $pe) -eq 0x4550 -and [BitConverter]::ToUInt16($Bytes, $pe + 4) -eq 0x8664 -and ([BitConverter]::ToUInt16($Bytes, $pe + 22) -band 0x2000) -ne 0
}
# Why Dll cannot be our voice DLL for Client, '' when it can. Without Client: only the file itself.
function Get-VoiceDllProblem([string]$Dll, [string]$Client) {
    if (-not $Dll -or -not (Test-Path -LiteralPath $Dll -PathType Leaf)) { return "$Dll is not found" }
    if (Test-Client (Split-Path -Parent $Dll)) { return "$Dll is in a game folder; use ours from the server package" }
    try { $bytes = [IO.File]::ReadAllBytes($Dll) } catch { return "cannot read $Dll ($($_.Exception.Message))" }
    if (-not (Test-Dll64 $bytes)) { return "$Dll is not a 64-bit Windows DLL" }
    if (-not [Text.Encoding]::ASCII.GetString($bytes).Contains('GetVoiceEngine')) { return "$Dll has no GetVoiceEngine, so it is no $voiceFile" }
    if (-not $Client) { return '' }
    $hash = Get-Sha256 $Dll
    $original = "$Dll is the game's original $voiceFile, not ours"
    $record = Read-VoiceRecord (Get-VoiceBackupFolder $Client)
    if ($record -and $hash -eq $record.original) { return $original }
    # The game's own file, unless we put it there.
    $current = $null
    try { $current = Get-Sha256 (Join-Path $Client $voiceFile) } catch { }
    if ($hash -eq $current -and -not ($record -and $hash -eq $record.installed)) { return $original }
    return ''
}
# An answer to the DLL question as a full path: a folder means its GCloudVoice.dll.
function Resolve-VoiceDll([string]$Answer) {
    $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Answer.Trim().Trim('"').Trim("'"))
    if (Test-Path -LiteralPath $path -PathType Container) { $path = Join-Path $path $voiceFile }
    return $path
}
# Our DLL and its hash, asking for its folder where needed: @{ Dll (its full path once found);
# Asked (Dll was answered); Hash ($null: no voice this time) }.
function Select-VoiceDll([string]$Dll, [string]$Client, [bool]$AskPath) {
    # The saved DLL, or when it is gone (or none is saved) the one next to join-roe-os.cmd.
    if (-not $Dll -or -not (Test-Path -LiteralPath $Dll -PathType Leaf)) { $Dll = Get-DefaultVoiceDll }
    $result = @{ Dll = $Dll; Asked = $false; Hash = $null }
    $offer = ''
    if ($AskPath) {
        if (Test-Path -LiteralPath $Dll -PathType Leaf) { $offer = $Dll }
    } else {
        $problem = Get-VoiceDllProblem $Dll $Client
        if ($problem) {
            if (-not (Test-Path -LiteralPath $Dll -PathType Leaf)) { Write-Host "Voice chat: our $voiceFile is not at $Dll." -ForegroundColor Yellow }
            else { Write-Host "Voice chat: $problem." -ForegroundColor Yellow }
            $AskPath = $true
        }
    }
    if ($AskPath) { Write-Host "Our $voiceFile is a separate download: $voiceDownload (or the voice folder of the server package)." }
    while ($AskPath) {
        $answer = Ask "Folder with our $voiceFile (or the file itself; Enter: no voice this time)" $offer
        if (-not $answer) { Write-Host 'Voice chat: no DLL chosen, so none is used this time.'; return $result }
        $path = Resolve-VoiceDll $answer
        $problem = Get-VoiceDllProblem $path $Client
        if (-not $problem) { $result.Dll = $path; $result.Asked = $true; break }
        Write-Host "Voice chat: $problem." -ForegroundColor Yellow
        $offer = ''
    }
    $result.Dll = [IO.Path]::GetFullPath($result.Dll)
    $result.Hash = Get-Sha256 $result.Dll
    return $result
}
# --- Voice chat prompt (begin) ---
# Voice chat for this start: @{ Voice (to save: $true, $false, or $null to ask again next start);
# Dll (to save as voice_dll); Pick (Select-VoiceDll's answer, $null: no voice) }. On by default:
# asked once (Enter: yes). A yes with a DLL found (saved, then used without asking) and a no are
# kept; a yes without a DLL asks again next start. Option: join-roe-os.cmd voice on|off ('on' asks for
# the DLL again).
function Get-VoiceChoice($Voice, [string]$Dll, [string]$Client, [string]$Option) {
    $asked = $false
    if ($Option) { $Voice = $Option -eq 'on' }
    elseif ($null -eq $Voice) {
        Write-Host ''
        Write-Host "Voice chat needs our $voiceFile in the game folder while the game runs (the original is put back afterwards)."
        $Voice = (Ask 'Use voice chat? (y/n)' 'y') -match '^[yY]'
        $asked = $true
        Write-Host 'Change it later with: join-roe-os.cmd voice on | off'
    }
    if (-not $Voice) { return @{ Voice = $false; Dll = $Dll; Pick = $null } }
    $pick = Select-VoiceDll $Dll $Client ($Option -eq 'on')
    if (-not $pick.Hash) {
        $again = if ($asked) { $null } else { $true }
        return @{ Voice = $again; Dll = $Dll; Pick = $null }
    }
    return @{ Voice = $true; Dll = $pick.Dll; Pick = $pick }
}
# --- Voice chat prompt (end) ---
# Backs up the game's DLL and puts ours (Ours; Expected: its hash when it was chosen, so a file
# changed since is not used) in. True when ours is in place.
function Install-Voice([string]$Client, [string]$Ours, [string]$Expected) {
    $actual = $null
    try { $actual = Get-Sha256 $Ours } catch { }
    if (-not $Expected) { $Expected = $actual }
    if (-not $Expected -or $actual -ne $Expected) {
        Write-Host "Voice chat: $Ours is missing or changed since it was chosen, so it is not used. Starting without voice chat." -ForegroundColor Yellow
        return $false
    }
    $problem = Get-VoiceDllProblem $Ours $Client
    if ($problem) { Write-Host "Voice chat: $problem; starting without voice chat." -ForegroundColor Yellow; return $false }
    $target = Join-Path $Client $voiceFile
    if (Test-GameRunning $Client) { Write-Host "Voice chat: the game in $Client runs already; its $voiceFile stays as it is."; return $false }
    $folder = Get-VoiceBackupFolder $Client
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        # The game's DLL is gone: ours goes in. A good backup of the original stays and comes back
        # when the game exits; without one ours stays (the game cannot start without a GCloudVoice.dll).
        $record = Read-VoiceRecord $folder
        $good = $false
        try { $good = $record -and (Get-Sha256 (Get-VoiceOriginal $Client)) -eq $record.original } catch { }
        if ($good -and $record.installed -ne $expected) {
            try {
                $temp = Join-Path $folder 'backup.json.tmp'
                [pscustomobject]@{ folder = $Client; original = $record.original; installed = $expected } | ConvertTo-Json | Set-Content -LiteralPath $temp -Encoding UTF8
                Move-Item -LiteralPath $temp -Destination (Join-Path $folder 'backup.json') -Force
            } catch { $good = $false }
        }
        $problem = Copy-Checked $ours $target $expected
        if ($problem) { Write-Host "Voice chat: could not put our $voiceFile into $Client ($problem); starting without voice chat." -ForegroundColor Yellow; return $false }
        if ($good) { Write-Host "Voice chat: on ($voiceFile was missing in $Client). The original is saved in $(Split-Path (Get-VoiceOriginal $Client)) and put back when the game exits." }
        else { Write-Host "Voice chat: on ($voiceFile was missing in $Client and there is no backup of the original, so ours stays there. To get the original: $verifyHint)." -ForegroundColor Yellow }
        return $true
    }
    $current = Get-Sha256 $target
    if ($current -eq $expected) {
        # Ours is never backed up, so a second start keeps the original's backup.
        $record = Read-VoiceRecord $folder
        $good = $false
        try { $good = $record -and $record.installed -eq $expected -and (Get-Sha256 (Get-VoiceOriginal $Client)) -eq $record.original } catch { }
        if (-not $good) { Write-Host "Voice chat: our $voiceFile is in $Client already, but there is no good backup of the original. To get the original back later: $verifyHint." -ForegroundColor Yellow }
        return $true
    }
    $problem = ''
    try { New-Item -ItemType Directory -Force -Path $folder | Out-Null } catch { $problem = $_.Exception.Message }
    $original = Join-Path (Join-Path $Client $voiceBackupName) $voiceFile
    if (-not $problem) { try { New-Item -ItemType Directory -Force -Path (Split-Path $original) | Out-Null } catch { $problem = $_.Exception.Message } }
    if (-not $problem) { $problem = Copy-Checked $target $original $current }
    if (-not $problem) { Write-VoiceReadme $Client }
    if (-not $problem) {
        try {
            $temp = Join-Path $folder 'backup.json.tmp'
            [pscustomobject]@{ folder = $Client; original = $current; installed = $expected } | ConvertTo-Json | Set-Content -LiteralPath $temp -Encoding UTF8
            Move-Item -LiteralPath $temp -Destination (Join-Path $folder 'backup.json') -Force
        } catch { $problem = $_.Exception.Message }
    }
    if ($problem) { Write-Host "Voice chat: could not back up $target ($problem); starting without voice chat." -ForegroundColor Yellow; return $false }
    $problem = Copy-Checked $ours $target $expected
    if ($problem) { Write-Host "Voice chat: could not put our $voiceFile into $Client ($problem); starting without voice chat." -ForegroundColor Yellow; return $false }
    Write-Host "Voice chat: on. The game's original $voiceFile is saved in $(Split-Path $original) and put back when the game exits (to do it by hand: copy it from there into $Client)."
    return $true
}

# --- Game files changed by other launchers ---------------------------------------------------
# Other launchers and lobby patchers change files of the Ring of Elysium folder (an XVersion
# folder uses its parent's): blocks appended to the .sfc archives (menus, lobby banners and
# images, chat texts, the intro video, the DirectX 12 notice) and the lobby room's caches. Their
# size and SHA-256 in the Steam install of 2022-0.2.989.0. Only these are hashed (about 290 MB,
# once: the hashes are kept by size and write time in %APPDATA%\roe-join\file-check.json).
$originalFiles = @(
    @{ Path = 'SFC\Common.sfc'; Size = 24781543; Sha = '8c220227044411b0282ca08196f68f78183bfe692b1ffdfa6bb9ed41868d0e35' },
    @{ Path = 'SFC\TableBin.sfc'; Size = 29917290; Sha = 'd665fec68ce52352fcd9f232d3447fafec35a079beb91f514e612733ca1cd288' },
    @{ Path = 'SFC\UI.sfc'; Size = 145656512; Sha = 'c6ea81c7bce90f9fd370b3f1fe6dce303279ce3b263573ad9b29c874675b07a2' },
    @{ Path = 'data_dyn.sfc'; Size = 2432544; Sha = '644861de1b3be6b16af2549ceae66a20f258dea057299c989cff4f3c9fae4cf9' },
    @{ Path = 'data_org_dyn.sfc'; Size = 2432544; Sha = '644861de1b3be6b16af2549ceae66a20f258dea057299c989cff4f3c9fae4cf9' },
    @{ Path = 'Cache\otherbin.sfc'; Size = 82786448; Sha = 'fdf4844a879acc383242b4264661e6c7700ff2e564b0a2cd57fa5aa9f07b91e3' },
    @{ Path = 'Cache\Data\world\ActorCreationScreen\ActorCreationScreen.sfc'; Size = 1210287; Sha = 'c60273c83ae486fc854bd6848a263c65c2871c2b6d7e5452269e4c059d99626d' }
)
# The game's own GCloudVoice.dll: the main folder's and XVersion's (both signed by Tencent). Ours
# (the voice backup record's "installed") is expected while voice chat is on.
$originalVoiceSha = @('1444509a07c560b4f72539cc80b5fe980770566bb7d35f203db9251e850c27ef', 'bc174a98d8899728ec51de63553c7c4a368ccd2d6729f012a2349e69335d9bd4')
# Files a clean install does not have: a lobby patcher's overlay archive and DLLs that Windows
# loads into the game in place of its system DLLs (none of these names is part of the game).
$addedFiles = @('data_exp.vfs', 'dinput8.dll', 'dinput.dll', 'version.dll', 'winmm.dll', 'winhttp.dll', 'wininet.dll',
    'dxgi.dll', 'd3d9.dll', 'd3d10.dll', 'd3d11.dll', 'd3d12.dll', 'ddraw.dll', 'dsound.dll', 'xinput1_3.dll', 'xinput1_4.dll',
    'xinput9_1_0.dll', 'opengl32.dll', 'iphlpapi.dll', 'ws2_32.dll', 'wsock32.dll', 'hid.dll', 'msimg32.dll')
$fileCheckPath = Join-Path $joinRoot 'file-check.json'
function Read-FileCheckCache {
    $cache = @{ Files = @{}; Changed = $false }
    try {
        $read = Get-Content -LiteralPath $fileCheckPath -Raw | ConvertFrom-Json
        foreach ($p in $read.files.PSObject.Properties) { $cache.Files[$p.Name] = $p.Value }
    } catch { }
    return $cache
}
function Save-FileCheckCache($Cache) {
    if (-not $Cache.Changed) { return }
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fileCheckPath) | Out-Null
        [pscustomobject]@{ files = $Cache.Files } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $fileCheckPath -Encoding UTF8
    } catch { }
}
# A file's SHA-256 (Info: its IO.FileInfo), from Cache while its size and write time are the same.
function Get-CachedSha([IO.FileInfo]$Info, $Cache) {
    $key = $Info.FullName.ToLowerInvariant()
    $time = $Info.LastWriteTimeUtc.Ticks
    $entry = $Cache.Files[$key]
    if ($entry -and [int64]$entry.size -eq $Info.Length -and [int64]$entry.time -eq $time -and "$($entry.sha256)") { return "$($entry.sha256)" }
    $sha = Get-Sha256 $Info.FullName
    $Cache.Files[$key] = [pscustomobject]@{ size = $Info.Length; time = $time; sha256 = $sha }
    $Cache.Changed = $true
    return $sha
}
# The Ring of Elysium folder of a game folder: an XVersion folder's parent.
function Get-GameBase([string]$Client) {
    $trimmed = $Client.TrimEnd('\', '/')
    if ([IO.Path]::GetFileName($trimmed) -eq 'XVersion' -and (Split-Path -Parent $trimmed)) { return Split-Path -Parent $trimmed }
    return $trimmed
}
# What differs from the original install for the game folder Client: 'X changed', 'X missing' and
# 'X added', X below the Ring of Elysium folder. Empty when all is original.
function Get-ChangedGameFiles([string]$Client) {
    $base = Get-GameBase $Client
    $own = if ($base -ne $Client.TrimEnd('\', '/')) { 'XVersion\' } else { '' }
    $cache = Read-FileCheckCache
    $found = New-Object Collections.ArrayList
    foreach ($file in $originalFiles) {
        $info = New-Object IO.FileInfo (Join-Path $base $file.Path)
        if (-not $info.Exists) { [void]$found.Add("$($file.Path) missing") }
        elseif ($info.Length -ne $file.Size -or (Get-CachedSha $info $cache) -ne $file.Sha) { [void]$found.Add("$($file.Path) changed") }
    }
    $info = New-Object IO.FileInfo (Join-Path $Client $voiceFile)
    if (-not $info.Exists) { [void]$found.Add("$own$voiceFile missing") }
    else {
        $sha = Get-CachedSha $info $cache
        $record = Read-VoiceRecord (Get-VoiceBackupFolder $Client)
        if ($originalVoiceSha -notcontains $sha -and -not ($record -and $sha -eq "$($record.installed)")) { [void]$found.Add("$own$voiceFile changed") }
    }
    foreach ($folder in @(@($Client.TrimEnd('\', '/'), $base) | Select-Object -Unique)) {
        $prefix = if ($folder -ne $base) { 'XVersion\' } else { '' }
        foreach ($name in $addedFiles) { if (Test-Path -LiteralPath (Join-Path $folder $name) -PathType Leaf) { [void]$found.Add("$prefix$name added") } }
    }
    Save-FileCheckCache $cache
    return [string[]]$found.ToArray()
}
# The message for Get-ChangedGameFiles' list, as lines.
function Get-GameFilesText([string[]]$Found, [string]$Client) {
    $names = @($Found | Select-Object -First 4) -join ', '
    if ($Found.Count -gt 4) { $names += ", and $($Found.Count - 4) more" }
    $lines = @("Your game files were changed by another launcher ($names), so the game may not work with this server.")
    if (@($Found | Where-Object { $_ -notlike '* added' }).Count) { $lines += "Verify them in $verifyHint." }
    $added = @($Found | Where-Object { $_ -like '* added' } | ForEach-Object { $_ -replace ' added$', '' })
    if ($added.Count) { $lines += "Delete $($added -join ', ') in $(Get-GameBase $Client) (not part of the game; Steam's check leaves them)." }
    $lines += 'Then start again.'
    return $lines
}
# Before a join: when the game files are not the original ones, says so and asks whether to start
# anyway (no: the join stops). Skip: --skip-file-check.
function Confirm-GameFiles([string]$Client, [bool]$Skip) {
    if ($Skip) { Write-Host 'Game file check skipped (--skip-file-check).'; return }
    $found = @(Get-ChangedGameFiles $Client)
    if (-not $found.Count) { return }
    foreach ($line in (Get-GameFilesText $found $Client)) { Write-Host $line -ForegroundColor Yellow }
    if ((Ask 'Start the game anyway? (y/n)' 'n') -notmatch '^[yY]') { throw 'Cancelled: the game files are not the original ones. Verify them in Steam, then start again.' }
}

# One request to the account service (TLS). Nothing when the service does not answer (a server
# without accounts). Refuses a server whose certificate differs from the one seen first.
function Invoke-Account([string]$Ip, [string]$Folder, [string]$Line) {
    $tcp = New-Object Net.Sockets.TcpClient
    try {
        $pending = $tcp.BeginConnect($Ip, $accountPort, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(5000) -or -not $tcp.Connected) { return $null }
        $tcp.EndConnect($pending)
        $seen = @{}
        $check = { param($sender, $certificate, $chain, $errors)
            $seen['pin'] = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($certificate.GetRawCertData())) -replace '-', '').ToLowerInvariant()
            return $true }.GetNewClosure()
        $ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, [Net.Security.RemoteCertificateValidationCallback]$check)
        $ssl.ReadTimeout = 5000
        $ssl.WriteTimeout = 5000
        $ssl.AuthenticateAsClient('roe_server', $null, [Security.Authentication.SslProtocols]::Tls12, $false)
        $pinPath = Join-Path $Folder 'server.pin'
        if (Test-Path -LiteralPath $pinPath) {
            if ((Get-Content -LiteralPath $pinPath -Raw).Trim() -ne $seen['pin']) {
                throw ("The server's certificate is not the one seen on the first join. Someone may be in between, or the server " +
                    "was set up again. If the server admin confirms a new certificate, delete $pinPath and start again.")
            }
        } else {
            New-Item -ItemType Directory -Force -Path $Folder | Out-Null
            Set-Content -LiteralPath $pinPath -Value $seen['pin'] -Encoding ASCII
            Write-Host ('First contact; remembered the server certificate ' + $seen['pin'])
        }
        $request = [Text.Encoding]::UTF8.GetBytes("$Line`n")
        $ssl.Write($request, 0, $request.Length)
        $ssl.Flush()
        return (New-Object IO.StreamReader($ssl, [Text.Encoding]::UTF8)).ReadLine()
    } finally {
        $tcp.Close()
    }
}
# STATS at most every 10 s per server (the server allows more; this keeps its load low): a newer
# call within 10 s gets the answer of the last one.
$script:statsCache = @{}
function Get-ServerStats([string]$Ip, [string]$Folder) {
    $now = [DateTime]::UtcNow
    if ($null -eq $script:statsCache) { $script:statsCache = @{} }
    $last = $script:statsCache[$Ip]
    if ($last -and ($now - $last.At).TotalSeconds -lt 10) { return $last.Reply }
    $reply = Invoke-Account $Ip $Folder 'STATS'
    $script:statsCache[$Ip] = @{ At = $now; Reply = $reply }
    return $reply
}
# The searching players per mode of a STATS region (its field after the state: "solo-tpp:2;squad-fpp:1",
# "-" for none): "solo 2, squad FPP 1", in the game's order; unknown modes left out.
function Format-QueueCounts([string]$Field) {
    $counts = @{}
    foreach ($part in $Field.Split(';')) {
        if ($part -cmatch '^(solo|duo|squad|training)-(tpp|fpp):(\d{1,9})$' -and [int]$Matches[3]) { $counts["$($Matches[1])-$($Matches[2])"] = [int]$Matches[3] }
    }
    $shown = @()
    foreach ($mode in @('solo', 'duo', 'squad', 'training')) {
        foreach ($view in @('tpp', 'fpp')) {
            if ($counts["$mode-$view"]) { $shown += "$mode$(if ($view -eq 'fpp') { ' FPP' }) $($counts["$mode-$view"])" }
        }
    }
    return $shown -join ', '
}
# The answer to STATS as one line, a part per region: "EU (normal): 12 online, 3 searching (solo 2,
# squad FPP 1), 2 matches | NA (normal): offline". A region whose state (the field after the name) is
# down takes no new match (the game greys it out). Empty from an older server, the modes only from
# a server that counts them.
function Format-Stats([string]$Reply) {
    if ($Reply -cne 'OK' -and $Reply -cnotmatch '^OK ') { return '' }
    $parts = @()
    foreach ($word in @($Reply.Split(' ', [StringSplitOptions]::RemoveEmptyEntries) | Select-Object -Skip 1)) {
        $fields = $word.Split(',')
        if ($fields.Count -lt 6 -or $fields[0] -notmatch '^\d+$' -or $fields[1] -cnotmatch '^[a-z]{1,12}$' -or @($fields[2..4] | Where-Object { $_ -notmatch '^\d{1,9}$' }).Count) { continue }
        $name = ''
        try { $name = [Uri]::UnescapeDataString($fields[5]) } catch { }
        $name = (($name.ToCharArray() | Where-Object { -not [char]::IsControl($_) }) -join '')
        if ($name.Length -gt 40) { $name = $name.Substring(0, 40) }
        $name = ($name -replace '\s+SERVER$', '').Trim()
        if (-not $name) { $name = "zone $($fields[0])" }
        if ($fields.Count -gt 6 -and $fields[6] -ceq 'down') { $parts += "$name ($($fields[1])): offline"; continue }
        $matchWord = if ([int]$fields[4] -eq 1) { 'match' } else { 'matches' }
        $modes = if ($fields.Count -gt 7) { Format-QueueCounts $fields[7] } else { '' }
        $searching = "$([int]$fields[3]) searching$(if ($modes) { " ($modes)" })"
        $parts += "$name ($($fields[1])): $([int]$fields[2]) online, $searching, $([int]$fields[4]) $matchWord"
    }
    return $parts -join ' | '
}
# The answer to INFO: what runs on the server now (counts only, no names).
function Format-ServerInfo([string]$Reply) {
    $values = @{}
    $queues = @()
    foreach ($pair in ($Reply.Substring(3) -split ' ')) {
        if ($pair -match '^queue\.([^=]+)=(\d+),(\d+)$') { $queues += "$($Matches[1]) $($Matches[2]) for up to $($Matches[3]) s" }
        elseif ($pair -match '^([a-z_]+)=(\d+)$') { $values[$Matches[1]] = [int]$Matches[2] }
    }
    $players = [int]$values['players']; $matches = [int]$values['matches']
    $text = "On the server now: $players player$(if ($players -ne 1) { 's' }) online, $matches match$(if ($matches -ne 1) { 'es' }) running, $([int]$values['waiting']) searching"
    if ($queues.Count) { $text += ' (' + ($queues -join ', ') + ')' }
    $text += '.'
    if ($values['restarting']) { $text += ' It restarts for an update soon; new searches are refused until then.' }
    return $text
}
function Ask-Name([string]$Default) {
    while ($true) {
        $answer = Ask 'Your name (1 to 24 characters)' $Default
        if ($answer -and $answer.Length -le 24 -and $answer -notmatch '[\x00-\x1f]') { return $answer }
        Write-Host 'That name is empty, too long or has control characters.'
        $Default = ''
    }
}

# The account menu: one key moves the selection (wraps around) or chooses it (Enter).
function Step-Menu([int]$Index, [string]$Key, [int]$Count) {
    switch ($Key) {
        'Enter' { return @($Index, $true) }
        'UpArrow' { return @((($Index - 1 + $Count) % $Count), $false) }
        'DownArrow' { return @((($Index + 1) % $Count), $false) }
        'Home' { return @(0, $false) }
        'End' { return @(($Count - 1), $false) }
    }
    return @($Index, $false)
}
function Show-Menu([string[]]$Entries, [int]$Index, [bool]$First) {
    if (-not $First) { [Console]::SetCursorPosition(0, [Math]::Max(0, [Console]::CursorTop - $Entries.Count)) }
    $width = ($Entries | Measure-Object -Property Length -Maximum).Maximum + 2
    for ($i = 0; $i -lt $Entries.Count; $i++) {
        if ($i -eq $Index) { Write-Host ('> ' + $Entries[$i]).PadRight($width) -ForegroundColor Black -BackgroundColor Gray }
        else { Write-Host ('  ' + $Entries[$i]).PadRight($width) }
    }
}
function Select-MenuWithKeys([string[]]$Entries, [scriptblock]$ReadKey, [scriptblock]$Draw, [int]$Index = 0) {
    $first = $true
    while ($true) {
        & $Draw $Entries $Index $first
        $first = $false
        $step = Step-Menu $Index (& $ReadKey) $Entries.Count
        $Index = $step[0]
        if ($step[1]) { return $Index }
    }
}
# Without a key reader (redirected input): a numbered list and a typed number.
function Select-Numbered([string[]]$Entries) {
    for ($i = 0; $i -lt $Entries.Count; $i++) { Write-Host "  $($i + 1). $($Entries[$i])" }
    while ($true) {
        $answer = Ask 'Number' '1'
        if ($answer -match '^\d+$' -and [int]$answer -ge 1 -and [int]$answer -le $Entries.Count) { return [int]$answer - 1 }
        Write-Host "Enter a number from 1 to $($Entries.Count)."
    }
}
function Select-Menu([string[]]$Entries) {
    $keys = $false
    try { $keys = -not [Console]::IsInputRedirected -and $Host.Name -eq 'ConsoleHost' } catch { }
    if ($keys) {
        Write-Host '(arrow keys, then Enter)'
        try { [Console]::CursorVisible = $false } catch { }
        try {
            return Select-MenuWithKeys $Entries { [Console]::ReadKey($true).Key.ToString() } { param($e, $i, $f) Show-Menu $e $i $f }
        } catch [InvalidOperationException], [IO.IOException] {
        } finally {
            try { [Console]::CursorVisible = $true } catch { }
        }
    }
    return Select-Numbered $Entries
}

# Options before a command: -Server <address> and -Name <name> (a name with spaces in quotes, or
# last). Returns @{ Server; Name; Command (the rest) }.
function Read-Arguments([string]$Text) {
    $result = @{ Server = ''; Name = ''; Command = $Text.Trim() }
    while ($result.Command -match '^-(Server|Name)\s+("([^"]*)"|(\S+))\s*(.*)$') {
        $value = if ($Matches[3] -or $Matches[2] -eq '""') { $Matches[3] } else { $Matches[4] }
        $option = $Matches[1]
        $rest = $Matches[5]
        if ($option -eq 'Name' -and $rest -and $rest -notmatch '^-Server\s') { $value = "$value $rest"; $rest = '' }  # -Name Anna Lee
        $result[$option] = $value.Trim()
        $result.Command = $rest.Trim()
    }
    return $result
}

# Servers joined before (the settings' "servers"), the most recently used first:
# @{ address; last_used; name; addresses; ips }.
function Get-ServerFolderName([string]$Address) { return $Address.ToLowerInvariant() -replace '[^a-z0-9._-]', '_' }
function Read-Servers($Settings) {
    $found = [ordered]@{}
    foreach ($s in @($Settings.servers)) {
        if (-not $s -or -not "$($s.address)".Trim()) { continue }
        $key = Get-ServerFolderName "$($s.address)".Trim()
        $last = [int64]0
        try { $last = [int64]$s.last_used } catch { }
        if (-not $found.Contains($key)) {
            $found[$key] = [pscustomobject]@{ address = "$($s.address)".Trim(); last_used = $last; name = (Get-CleanServerName "$($s.name)")
                addresses = (Get-CleanAddresses $s.addresses); ips = (Get-CleanAddresses $s.ips) }
        }
    }
    return @($found.Values | Sort-Object -Property last_used -Descending)
}
# The servers to offer: the saved ones, else (the first start) the default list, so a new player
# only picks one and plays.
function Get-OfferedServers($Settings) {
    $saved = @(Read-Servers $Settings)
    if ($saved.Count) { return $saved }
    $defaultServers = @(@{ address = 'roe-os.de'; name = 'ROE-OS' })
    return @($defaultServers | ForEach-Object { [pscustomobject]@{ address = $_.address; last_used = [int64]0; name = $_.name; addresses = [string[]]@(); ips = [string[]]@() } })
}
# The list with Address used now, on top (its saved name kept).
function Add-ServerUse($Servers, [string]$Address, [int64]$Now = 0) {
    if (-not $Now) { $Now = Get-UnixTime }
    $key = Get-ServerFolderName $Address
    $old = @($Servers | Where-Object { $_ -and (Get-ServerFolderName $_.address) -eq $key })
    $name = if ($old.Count) { "$($old[0].name)" } else { '' }
    $addresses = [string[]]@(); $ips = [string[]]@()
    if ($old.Count) { $addresses = Get-CleanAddresses $old[0].addresses; $ips = Get-CleanAddresses $old[0].ips }
    $entry = [pscustomobject]@{ address = $Address; last_used = $Now; name = $name; addresses = $addresses; ips = $ips }
    return @(@($entry) + @($Servers | Where-Object { $_ -and (Get-ServerFolderName $_.address) -ne $key }))
}
# A saved address list as canonical addresses (anything else dropped).
function Get-CleanAddresses($List) {
    return ,[string[]]@(@($List) | ForEach-Object { ConvertTo-CanonicalAddress "$_" } | Where-Object { $_ } | Sort-Object -Unique)
}
# The saved lists of Address: what it lists (Listed) and its own addresses (Ips); $null keeps one.
function Set-ServerAddresses($Servers, [string]$Address, $Listed, $Ips) {
    $key = Get-ServerFolderName $Address
    foreach ($s in @($Servers | Where-Object { $_ -and (Get-ServerFolderName $_.address) -eq $key })) {
        if ($null -ne $Listed) { $s | Add-Member -NotePropertyName addresses -NotePropertyValue (Get-CleanAddresses $Listed) -Force }
        if ($null -ne $Ips) { $s | Add-Member -NotePropertyName ips -NotePropertyValue (Get-CleanAddresses $Ips) -Force }
    }
}
# A server name fit to show: no control characters, at most 40 characters.
function Get-CleanServerName([string]$Text) {
    $text = $Text -replace '[\p{C}\p{Zl}\p{Zp}]', ''
    if ($text.Length -gt 40) { $text = $text.Substring(0, 40); if ([char]::IsHighSurrogate($text[39])) { $text = $text.Substring(0, 39) } }
    return $text.Trim()
}
# A dotted version ("0.9") as four numbers; $null when it is no version.
function ConvertTo-VersionKey([string]$Version) {
    if ($Version -notmatch '^\d{1,6}(\.\d{1,6}){0,3}$') { return $null }
    $parts = @($Version.Split('.') | ForEach-Object { [int]$_ }) + @(0, 0, 0)
    return ,[int[]]$parts[0..3]
}
# -1, 0 or 1 as version A is older, the same or newer than B.
function Compare-Version([string]$A, [string]$B) {
    $x = ConvertTo-VersionKey $A; $y = ConvertTo-VersionKey $B
    for ($i = 0; $i -lt 4; $i++) { if ($x[$i] -ne $y[$i]) { if ($x[$i] -lt $y[$i]) { return -1 }; return 1 } }
    return 0
}
# The VERSION answer: min, current (as text, '0' when missing) and url; $null without an OK.
function Get-ScriptVersions([string]$Reply) {
    if (-not $Reply.StartsWith('OK ', [StringComparison]::Ordinal)) { return $null }
    $values = @{}
    foreach ($pair in ($Reply.Substring(3) -split ' ')) { if ($pair -match '^([a-z_]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] } }
    $found = @{ min = '0'; current = '0'; url = $joinUrl }
    foreach ($key in 'min', 'current') { if (ConvertTo-VersionKey "$($values[$key])") { $found[$key] = "$($values[$key])" } }
    $url = ''
    try { $url = [Uri]::UnescapeDataString("$($values['url'])") -replace '[\p{C}\s]', '' } catch { }
    if ($url.Length -gt 200) { $url = $url.Substring(0, 200) }
    if ($url -match '^https?://.') { $found.url = $url }
    return $found
}
# Throws when this script is older than the server needs; a line when a newer one exists, else $null.
# Script: the name the lines give this script.
function Get-VersionNotice([string]$Reply, [string]$Have = $joinVersion, [string]$Script = 'join-roe-os.cmd') {
    $versions = Get-ScriptVersions $Reply
    if (-not $versions) { return $null }
    if ((Compare-Version $Have $versions.min) -lt 0) {
        throw ("This $Script is version $Have; the server needs version $($versions.min) or newer. " +
            "Download the new $Script from $($versions.url) and start it again.")
    }
    if ((Compare-Version $Have $versions.current) -lt 0) { return "A newer $Script (version $($versions.current)) is at $($versions.url); this one (version $Have) still works." }
    return $null
}
# The server name in an INFO answer, '' for none.
function Get-InfoServerName([string]$Reply) {
    if ($Reply -notmatch '(^| )name=(\S*)$') { return '' }
    return Get-CleanServerName ([Uri]::UnescapeDataString($Matches[2]))
}
# The saved name of Address set to Name ('' removes it); true when it changed.
function Set-ServerName($Servers, [string]$Address, [string]$Name) {
    $key = Get-ServerFolderName $Address
    foreach ($s in @($Servers | Where-Object { $_ -and (Get-ServerFolderName $_.address) -eq $key })) {
        if ("$($s.name)" -cne $Name) { $s | Add-Member -NotePropertyName name -NotePropertyValue $Name -Force; return $true }
    }
    return $false
}
function Get-ServerLabel($Entry) { if ("$($Entry.name)") { return "$($Entry.name) ($($Entry.address))" }; return $Entry.address }
# The server address: Given (-Server), else the menu of saved servers; the first start asks.
function Select-Server($Servers, [string]$Given) {
    if ($Given) { return $Given }
    $question = 'Server address (IP or domain)'
    $Servers = @($Servers | Where-Object { $_ })
    if (-not $Servers.Count) { return Ask $question '' }
    Write-Host 'Server:'
    $index = Select-Menu (@($Servers | ForEach-Object { Get-ServerLabel $_ }) + @('Enter another server (IP or domain)'))
    if ($index -lt $Servers.Count) { return $Servers[$index].address }
    return Ask $question ''
}

# Saved accounts of a server (accounts.json in its folder): name, key and last use (unix
# seconds), the most recently used first.
function Read-Accounts([string]$Folder) {
    $list = @()
    $path = Join-Path $Folder 'accounts.json'
    if (Test-Path -LiteralPath $path) {
        try {
            foreach ($a in @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).accounts)) {
                # No key: a name for a server without an account service (play.cmd's own server).
                if (-not $a -or ("$($a.token)" -cnotmatch '^[0-9a-f]{64}$' -and ("$($a.token)" -or -not $a.name))) { continue }
                $name = if ($a.name) { "$($a.name)" } else { '?' }
                $list += [pscustomobject]@{ name = $name; token = "$($a.token)"; last_used = [int64]$a.last_used }
            }
        } catch { }
    }
    $sorted = New-Object System.Collections.ArrayList
    foreach ($a in @($list | Sort-Object -Property last_used -Descending)) { [void]$sorted.Add($a) }
    return ,$sorted
}
function Save-Accounts([string]$Folder, $Accounts) {
    New-Item -ItemType Directory -Force -Path $Folder | Out-Null
    $path = Join-Path $Folder 'accounts.json'
    $rows = @($Accounts | ForEach-Object { [pscustomobject]@{ name = $_.name; token = $_.token; last_used = $_.last_used } })
    $json = ConvertTo-Json -Depth 4 -InputObject ([pscustomobject]@{ accounts = $rows })
    [IO.File]::WriteAllText($path, $json, (New-Object Text.UTF8Encoding $false))
    return $path
}
function Get-UnixTime { return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
# The saved account to log in with, or nothing for a new one. -Name picks without the menu.
function Select-Account($Accounts, [string]$Name) {
    if ($Name) {
        foreach ($a in $Accounts) { if ($a.name -eq $Name) { return $a } }  # case ignored
        return $null
    }
    if (-not $Accounts.Count) { return $null }
    Write-Host 'Account:'
    $index = Select-Menu (@($Accounts | ForEach-Object { $_.name }) + @('Create a new account'))
    if ($index -lt $Accounts.Count) { return $Accounts[$index] }
    return $null
}
# The current names from the server (renamed in the game); true when one changed.
function Update-AccountNames([string]$Ip, [string]$Folder, $Accounts) {
    $changed = $false
    foreach ($a in @($Accounts | Where-Object { $_.token })) {
        $reply = Invoke-Account $Ip $Folder "NAME $($a.token)"
        if ($null -eq $reply -or ($reply -notlike 'OK *' -and $reply -ne 'DENIED')) { break }  # no answer or the limit
        if ($reply -like 'OK ?*' -and $reply.Substring(3) -cne $a.name) { $a.name = $reply.Substring(3); $changed = $true }
    }
    return $changed
}
function Stop-Refused([string]$Reply, [string]$Name) {
    if ($Reply -eq 'LIMIT') { throw 'Too many attempts from this address. Try again in a few minutes.' }
    if ($Reply -eq 'BANNED') {
        $who = if ($Name) { "The name $Name or your address" } else { 'Your address' }
        throw "$who is banned on this server. Ask the server admin if you think this is a mistake."
    }
    throw "The account service answered: $Reply"
}
# A new account, saved; nothing when the server has no account service. Without a name the
# server names it (first-login on: the game asks for the real one); else the player picks it.
function New-Account([string]$Ip, [string]$Folder, $Accounts, [string]$Name) {
    if (-not $Name) {
        $reply = Invoke-Account $Ip $Folder 'NEW'
        if ($null -eq $reply) { return $null }
        if ($reply -cmatch '^OK ([0-9a-f]{64}) (.+)$') {
            $entry = [pscustomobject]@{ name = $Matches[2]; token = $Matches[1]; last_used = (Get-UnixTime) }
            $Accounts.Insert(0, $entry)
            $path = Save-Accounts $Folder $Accounts
            Write-Host "New account created; you choose its name in the game. Its key is saved in $path"
            return $entry
        }
        if ($reply -ne 'NAME-REQUIRED') { Stop-Refused $reply '' }
        $Name = Ask-Name ''
    }
    while ($true) {
        $reply = Invoke-Account $Ip $Folder "CLAIM $Name"
        if ($null -eq $reply) { return $null }
        if ($reply -cmatch '^OK ([0-9a-f]{64})$') {
            $entry = [pscustomobject]@{ name = $Name; token = $Matches[1]; last_used = (Get-UnixTime) }
            $Accounts.Insert(0, $entry)
            $path = Save-Accounts $Folder $Accounts
            Write-Host "The name $Name is yours on this server. Its key is saved in $path"
            return $entry
        }
        if ($reply -ne 'TAKEN' -and $reply -ne 'INVALID') { Stop-Refused $reply $Name }
        Write-Host "The name $Name is taken on this server or not allowed. Choose another one."
        $Name = Ask-Name ''
    }
}
# A server without an account service takes a plain name: kept in accounts.json without a key,
# so the menu offers it next time.
function Save-PlainName([string]$Folder, $Accounts, [string]$Name) {
    $entry = $null
    foreach ($a in $Accounts) { if (-not $a.token -and $a.name -eq $Name) { $entry = $a } }
    if (-not $entry) { $entry = [pscustomobject]@{ name = $Name; token = ''; last_used = 0 }; $Accounts.Insert(0, $entry) }
    $entry.last_used = Get-UnixTime
    $sorted = @($Accounts | Sort-Object -Property last_used -Descending)
    $Accounts.Clear()
    foreach ($a in $sorted) { [void]$Accounts.Add($a) }
    Save-Accounts $Folder $Accounts | Out-Null
    return [pscustomobject]@{ Uid = $null; Name = $Name }
}
# Logs in: Uid is the one-time ticket the game passes on as its -uid (nothing: the server has
# no account service), Name the account's current name.
function Invoke-Login([string]$Ip, [string]$Folder, $Accounts, $Entry, [string]$Name) {
    if ($Entry -and -not $Entry.token) {
        # A saved name without a key: an account under that name once the server has a service.
        $named = $Entry
        $Entry = New-Account $Ip $Folder $Accounts $named.name
        if ($Entry) { $Accounts.Remove($named); Save-Accounts $Folder $Accounts | Out-Null }
        else { return Save-PlainName $Folder $Accounts $named.name }
    }
    if (-not $Entry) {
        $Entry = New-Account $Ip $Folder $Accounts $Name
        if (-not $Entry) {
            if (-not $Name) { $Name = Ask-Name '' }
            return Save-PlainName $Folder $Accounts $Name
        }
    }
    $reclaimed = $false
    while ($true) {
        $reply = Invoke-Account $Ip $Folder "LOGIN2 $($Entry.token)"
        if ($null -eq $reply) { return [pscustomobject]@{ Uid = $null; Name = $Entry.name } }
        if ($reply -eq 'DENIED' -and -not $reclaimed) {
            # A name the admin released can be claimed again (it keeps its picks and statistics).
            $claim = Invoke-Account $Ip $Folder "CLAIM $($Entry.name)"
            if ($claim -cnotmatch '^OK ([0-9a-f]{64})$') {
                throw "The server does not accept the saved key for $($Entry.name). If it was lost, ask the server admin to run: roe_server account reset `"$($Entry.name)`""
            }
            $Entry.token = $Matches[1]
            Save-Accounts $Folder $Accounts | Out-Null
            $reclaimed = $true
            continue
        }
        if ($reply -cmatch '^OK ([0-9]+) (.+)$') {
            $uid = $Matches[1]
            $Entry.name = $Matches[2]
            $Entry.last_used = Get-UnixTime
            $sorted = @($Accounts | Sort-Object -Property last_used -Descending)
            $Accounts.Clear()
            foreach ($a in $sorted) { [void]$Accounts.Add($a) }
            Save-Accounts $Folder $Accounts | Out-Null
            Write-Host "Logged in as $($Entry.name)"
            return [pscustomobject]@{ Uid = $uid; Name = $Entry.name }
        }
        Stop-Refused $reply $Entry.name
    }
}

# --- Joining: the steps of a join, for the console and the window -----------------------------
# The game folder as a full path; throws when it has no Europa_Client.exe or another build.
function Get-GameFolder([string]$Folder) {
    if (-not (Test-Client $Folder)) { throw "No Europa_Client.exe in: $Folder" }
    $Folder = (Resolve-Path -LiteralPath $Folder).Path
    if ($expectedSha -notcontains (Get-Sha256 (Join-Path $Folder 'Europa_Client.exe'))) {
        throw 'This is a different game build. The server needs 2022-0.2.989.0 x64: the Europa_Client.exe of the main game folder or of XVersion.'
    }
    return $Folder
}
# The host of a server address. The game only connects to lobby port 8001, so a second server
# needs its own address.
function Get-ServerHost([string]$Server) {
    if ($Server -match '^(.+):(\d{1,5})$') {
        if ([int]$Matches[2] -ne 8001) { throw "The game only connects to port 8001. Enter the server address without :$($Matches[2]) (a second server runs on its own address)." }
        return $Matches[1]
    }
    return $Server
}
# The IPv4 addresses of a host. A domain is resolved again at every join (it is saved as typed);
# it may have several: the game uses the first, the rules allow all.
function Resolve-ServerIps([string]$HostName) {
    $address = $null
    if ([Net.IPAddress]::TryParse($HostName, [ref]$address) -and $address.AddressFamily -eq 'InterNetwork') { return ,[string[]]@($address.ToString()) }
    $ips = @([Net.Dns]::GetHostAddresses($HostName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | ForEach-Object { $_.ToString() })
    if (-not $ips.Count) { throw "Cannot resolve $HostName to an IPv4 address." }
    return ,[string[]]$ips
}
# What runs on the server now, for the line after the login and while the game runs: every
# region with its numbers (STATS), the INFO line only from a server without STATS; INFO's
# restart notice either way.
function Format-ServerNow([string]$Info, [string]$Stats) {
    $regions = Format-Stats $Stats
    if (-not $regions) { return Format-ServerInfo $Info }
    $text = "On the server now: $regions."
    if ($Info -match '(^| )restarting=[1-9]') { $text += ' It restarts for an update soon; new searches are refused until then.' }
    return $text
}
# Where a server's accounts and certificate pin are kept.
function Get-AccountFolder([string]$Server) { return Join-Path $joinRoot (Get-ServerFolderName $Server) }
# The server's name (INFO), whether this script is new enough (VERSION: TooOld the reason to stop,
# Notice a newer one), where else the game goes for it (ADDRESSES without ServerIps; $null: no
# answer, or Addresses false) and who plays where (STATS: Regions). Info is $null from a server
# without an account service, which answers none of them.
function Connect-Server([string]$Ip, [string]$Folder, [string[]]$ServerIps, [bool]$Addresses = $true, [string]$Script = 'join-roe-os.cmd') {
    $result = [pscustomobject]@{ Info = $null; Name = ''; TooOld = ''; Notice = $null; Listed = $null; Regions = '' }
    $result.Info = Invoke-Account $Ip $Folder 'INFO'
    if (-not $result.Info) { return $result }
    if ($result.Info -match '^OK ') { $result.Name = Get-InfoServerName $result.Info }
    $versionReply = $null
    try { $versionReply = Invoke-Account $Ip $Folder 'VERSION' } catch { }
    try { $result.Notice = Get-VersionNotice $versionReply $joinVersion $Script } catch { $result.TooOld = $_.Exception.Message }
    if ($result.TooOld) { return $result }
    if ($Addresses) {
        $listed = $null
        try { $listed = Get-ServerAddresses (Invoke-Account $Ip $Folder 'ADDRESSES') } catch { }
        if ($null -ne $listed) { $result.Listed = [string[]]@($listed | Where-Object { $ServerIps -notcontains $_ }) }
    }
    try { $result.Regions = Format-Stats (Get-ServerStats $Ip $Folder) } catch { }
    return $result
}
# The firewall step (Firewall: the rules on). The game may talk to this computer and to the
# servers joined so far and the addresses they list, nothing else. The rules name addresses only,
# no ports or protocols, so the voice relay (UDP 10101 on the same server) and any match port are
# allowed too. Saves into ServerList what Server lists (Listed) and its addresses once the rules
# took them. Returns Programs and Check: the arguments for Confirm-FirewallState (Wanted, RulesOn,
# Step: the administrator step's result) or $null when there is nothing to check.
function Update-Firewall([string]$Client, $ServerList, [string]$Server, [string[]]$ServerIps, $Listed, [bool]$Firewall) {
    $programs = Get-GamePrograms $Client
    $folder = Get-FolderRules $Client $programs
    # This computer (127.0.0.0/8) is always allowed by every rule set (ours and play.cmd's), so a
    # local server needs no change; a second game on this PC starts while the first one runs.
    $remoteIps = @($ServerIps | Where-Object { $_ -notlike '127.*' })
    $localOnly = -not $remoteIps.Count
    $addressesDone = $true  # false when the rules could not take the list: it is not saved then
    $check = $null
    if (-not $Firewall) {
        if (($folder.Own.Count -or $folder.Other.Count) -and $localOnly -and @(Get-RunningGame $programs).Count) {
            Write-Host 'The game runs already; rules for this folder stay as they are (they allow this computer).'
        } elseif ($folder.Own.Count -or $folder.Other.Count) {
            # Rules made while they were on (or play.cmd's) would block a server not trusted then.
            Assert-GameClosed $programs
            Write-Host ''
            Write-Host 'Firewall rules are off, but rules for this game folder are left that may block the server.'
            try { Remove-Rules (@($folder.Own) + @($folder.Other)) "for $Client" } catch { Write-Host $_.Exception.Message }
            $check = [pscustomobject]@{ Wanted = $null; RulesOn = $false; Step = $null }
        } elseif ($folder.Fixed.Count) {
            $check = [pscustomobject]@{ Wanted = $null; RulesOn = $false; Step = $null }
        }
    } else {
        # Servers used before stay trusted: the rules name them ("servers a b"). This server's
        # addresses and its list are added, what it listed before and no longer lists goes.
        $trusted = @(Get-TrustedServers $folder.Own)
        $mine = @($ServerList | Where-Object { (Get-ServerFolderName $_.address) -eq (Get-ServerFolderName $Server) })
        $previous = @($mine | ForEach-Object { $_.addresses })
        $previousIps = @($mine | ForEach-Object { $_.ips })
        $wanted = Get-TrustedUpdate $trusted $remoteIps $Listed $previous (Get-KeptAddresses $ServerList $Server) $previousIps
        $current = Test-RulesCurrent $folder.Own $programs.Count $wanted
        $step = $null
        if ((-not $current -or $folder.Other.Count) -and $localOnly -and @(Get-RunningGame $programs).Count) {
            Write-Host 'The game runs already (play.cmd?); the firewall rules stay as they are: they allow this computer.'
            $addressesDone = $false
        } elseif (-not $current -or $folder.Other.Count) {
            Assert-GameClosed $programs
            $gone = @($trusted | Where-Object { $wanted -notcontains $_ })
            Write-Host ''
            Write-Host "Firewall: the game will be allowed to reach only this computer and $($wanted -join ', ')."
            if ($gone.Count) { Write-Host "No longer listed by the server: $($gone -join ', ')." }
            $others = @($folder.Other | Where-Object { $_.Local })
            if ($others.Count) { Write-Host "Block rules of other programs for this game are removed: $(@($others | ForEach-Object { '"' + $_.DisplayName + '"' }) -join ', ')." }
            if (Test-Administrator) { Write-Host 'Running as administrator: the rules are set now.' }
            else { Write-Host 'Administrator approval is needed for that (a Windows prompt appears; not in front: click the flashing shield in the taskbar).' }
            $step = Set-FolderRules $programs $folder $wanted
            if (-not $step.Ok) { $addressesDone = $false }
        }
        $problems = @(Get-FirewallProblems)
        if ($problems.Count) { Write-Host ('Warning: Windows does not apply the firewall rules: ' + ($problems -join '; ') + '.') -ForegroundColor Yellow }
        foreach ($product in (Get-OtherFirewalls)) { Write-Host "$product says it runs the firewall: if the game cannot connect, allow it there for $($wanted -join ', ')." -ForegroundColor Yellow }
        if (-not $problems.Count -and -not ($localOnly -and @(Get-RunningGame $programs).Count)) {
            # Checked every time: a declined or silently failed prompt, rules turned off, and block
            # rules of other programs all leave the game cut off from the server.
            $check = [pscustomobject]@{ Wanted = $wanted; RulesOn = $true; Step = $step }
        }
    }
    $keep = $null; $keepIps = $null  # saved only once the rules (if on) took them
    if ($addressesDone) { $keep = $Listed; $keepIps = [string[]]@($remoteIps) }
    Set-ServerAddresses $ServerList $Server $keep $keepIps
    return [pscustomobject]@{ Programs = $programs; Check = $check }
}
# Removes every rule of join-roe-os.cmd and the server launcher.
function Reset-AllRules {
    $all = @(Get-NetFirewallRule -Group 'ROE2022-*' -ErrorAction SilentlyContinue)
    Assert-GameClosed @($all | ForEach-Object { ($_ | Get-NetFirewallApplicationFilter).Program } | Sort-Object -Unique)
    Remove-Rules $all 'of join-roe-os.cmd and the server launcher'
    Write-Host 'The next join creates new rules that trust only its own server.'
}
# Removes the rules of a game folder (and other rules that block its programs).
function Remove-FolderRules([string]$Client) {
    if (-not (Test-Client $Client)) { return }
    $programs = Get-GamePrograms $Client
    $folder = Get-FolderRules $Client $programs
    Assert-GameClosed $programs
    Remove-Rules (@($folder.Own) + @($folder.Other)) "for $Client"
}
# A server without an account service takes the name on the lobby port for the next client from
# this address.
function Register-LobbyName([string]$Ip, [string]$Name) {
    $tcp = New-Object Net.Sockets.TcpClient
    try {
        $pending = $tcp.BeginConnect($Ip, $lobbyPort, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(5000) -or -not $tcp.Connected) {
            throw "No server answers at ${Ip}:$lobbyPort. Check the address, that the server runs with -Bind 0.0.0.0, and the host's firewall (TCP $lobbyPort and $accountPort, UDP 18001, and the ports above it on a server with several maps or match processes)."
        }
        $tcp.EndConnect($pending)
        $stream = $tcp.GetStream()
        $stream.ReadTimeout = 5000
        $request = [Text.Encoding]::UTF8.GetBytes("ROE-NAME $Name`n")
        $stream.Write($request, 0, $request.Length)
        $buffer = New-Object byte[] 128
        $reply = ''
        try { $reply = [Text.Encoding]::UTF8.GetString($buffer, 0, $stream.Read($buffer, 0, $buffer.Length)).Trim() } catch { }
        if ($reply -eq 'OK') { Write-Host "Name registered: $Name" }
        elseif ($reply) { Write-Host "The server did not accept the name ($reply). You will play under the default name." }
        else { Write-Host 'This server does not take names. You will play under the default name.' }
    } finally {
        $tcp.Close()
    }
}
# Logs in with Entry (Select-Account's answer; $null: a new account, named Name if given). Servers
# with accounts hand out a one-time ticket that the game passes on as its -uid; a server without an
# account service gets the name on the lobby port (Register-LobbyName). Returns Uid ('1' without
# accounts), Name (the account's current name) and Accounts (the server has an account service).
function Connect-Account([string]$Ip, [string]$Folder, $Accounts, $Entry, [string]$Name) {
    $login = Invoke-Login $Ip $Folder $Accounts $Entry $Name
    $service = $null -ne $login.Uid
    if (-not $service) { Register-LobbyName $Ip $login.Name }
    $uid = if ($service) { $login.Uid } else { '1' }
    return [pscustomobject]@{ Uid = $uid; Name = $login.Name; Accounts = $service }
}
# --- The admin page (GM accounts) ------------------------------------------------------------
# An account's role on the server from the answer to ROLE: 'admin', 'gm', 'player', or '' (an
# unknown key, an older server without ROLE, no answer). The window shows "Open the admin page"
# for gm and admin (an admin is a GM that may also change the server's technical settings).
function Get-AccountRole([string]$Reply) {
    if ($Reply -ceq 'OK admin') { return 'admin' }
    if ($Reply -ceq 'OK gm') { return 'gm' }
    if ($Reply -ceq 'OK player') { return 'player' }
    return ''
}
# A domain (not an IP address): its admin page is https://admin.<domain> unless the server names another.
function Test-DomainHost([string]$HostName) {
    $address = $null
    if ([Net.IPAddress]::TryParse($HostName, [ref]$address)) { return $false }
    return $HostName -match '^[A-Za-z0-9-]{1,63}(\.[A-Za-z0-9-]{1,63})+$'
}
# The admin page's one-time login link from the answer to WEB (Url), or why there is none (Problem).
function Get-AdminLink([string]$Reply, [string]$HostName) {
    $result = [pscustomobject]@{ Url = ''; Problem = '' }
    if ($Reply -ceq 'DENIED') { $result.Problem = 'This account has no GM rights on this server.'; return $result }
    if (-not $Reply -or $Reply -ceq 'NONE' -or $Reply -ceq 'INVALID') { $result.Problem = 'This server has no admin page.'; return $result }
    if ($Reply -ceq 'LIMIT') { $result.Problem = 'Too many attempts from this address. Try again in a minute.'; return $result }
    if ($Reply -ceq 'BANNED') { $result.Problem = 'This account or your address is banned on this server.'; return $result }
    if ($Reply -cnotmatch '^OK ([0-9a-f]{64}) (\S+)') { $result.Problem = "The account service answered: $Reply"; return $result }
    $ticket = $Matches[1]
    $base = $Matches[2]
    if ($base -ceq '-') {
        if (-not (Test-DomainHost $HostName)) {
            $result.Problem = 'This server has no admin page address (its admin can set one: roe_server set admin-url URL).'
            return $result
        }
        $base = "https://admin.$($HostName.ToLowerInvariant())"
    } else {
        try { $base = [Uri]::UnescapeDataString($base) } catch { $base = '' }
        if ($base -notmatch '^https?://[!-~]+$' -or $base.Length -gt 200) { $result.Problem = 'The server names no valid admin page address.'; return $result }
        $base = $base.TrimEnd('/')
    }
    $result.Url = "$base/login?ticket=$ticket"
    return $result
}
# Asks the server for the admin page's login link of a saved account (Entry): its role first, so
# a player's account never asks for a ticket.
function Request-AdminLink([string]$Ip, [string]$Folder, [string]$HostName, $Entry) {
    if (-not $Entry -or -not $Entry.token) { return [pscustomobject]@{ Url = ''; Problem = 'Choose a saved account of this server (one with a key).' } }
    if ((Get-AccountRole (Invoke-Account $Ip $Folder "ROLE $($Entry.token)")) -eq 'player') {
        return [pscustomobject]@{ Url = ''; Problem = 'This account has no GM rights on this server.' }
    }
    return Get-AdminLink (Invoke-Account $Ip $Folder "WEB $($Entry.token)") $HostName
}

# Our voice DLL in (VoicePick: Get-VoiceChoice's Pick, $null: no voice), then the game, connected
# to the server. Returns Process and VoiceOn: when true, Restore-Voice once the game exits.
function Start-Game([string]$Client, [string]$Uid, [string]$Ip, $VoicePick, [string[]]$Extra = @()) {
    Write-Host ''
    Write-Host 'Starting the game.'
    $voiceOn = $false
    if ($VoicePick -and $VoicePick.Hash) { $voiceOn = Install-Voice $Client $VoicePick.Dll $VoicePick.Hash }
    try {
        $gameArgs = @('-language=en', '-garena', "-uid=$Uid", "-server=${Ip}:$lobbyPort") + @($Extra | Where-Object { $_ } | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } })
        $game = Start-Process -FilePath (Join-Path $Client 'Europa_Client.exe') -WorkingDirectory $Client -PassThru -ArgumentList $gameArgs
    } catch {
        if ($voiceOn) { Restore-Voice $Client 15 | Out-Null }
        throw
    }
    return [pscustomobject]@{ Process = $game; VoiceOn = $voiceOn }
}

# --- Started through Steam (launch options) ---------------------------------------------------
# Steam's launch option "<this file>" %command% runs join-roe-os.cmd with the game's own command line:
# Steam's launch entry for Ring of Elysium, "<game folder>\SLauncher.exe" -steam -maintenance.
# join-roe-os.cmd then joins without menus (the server and account of join-roe-os.cmd steam-setup, else the last
# used ones) and starts Europa_Client.exe of that folder (or its XVersion when that was the last
# game folder) with our arguments instead of the launcher; what the player wrote after %command%
# is passed on. join-roe-os.cmd steam-setup prints the line and can write it into Steam's localconfig.vdf
# (only while Steam is closed: Steam writes the file back when it exits).
$steamAppId = '755790'
$steamExes = @('SLauncher.exe', 'Europa_Client.exe')
$steamLauncherArgs = @('-steam', '-maintenance')
$steamId64Base = [int64]76561197960265728
$launchPath = @('UserLocalConfigStore', 'Software', 'Valve', 'Steam', 'apps')
# The words of a command line: blanks split, double quotes group (and are dropped).
function Split-CommandLine([string]$Text) {
    $words = New-Object Collections.ArrayList
    $word = New-Object Text.StringBuilder
    $quoted = $false
    $has = $false
    foreach ($c in "$Text".ToCharArray()) {
        if ($c -eq [char]'"') { $quoted = -not $quoted; $has = $true; continue }
        if (-not $quoted -and [char]::IsWhiteSpace($c)) {
            if ($has) { [void]$words.Add($word.ToString()); [void]$word.Clear(); $has = $false }
            continue
        }
        [void]$word.Append($c)
        $has = $true
    }
    if ($has) { [void]$words.Add($word.ToString()) }
    return ,([string[]]$words.ToArray([string]))
}
# The game in Steam's command line: Folder (of its exe), Before (our options in front of it, as
# text) and Extra (what follows Steam's own arguments); $null when there is none.
function Find-SteamGame([string]$Text) {
    $words = Split-CommandLine $Text
    for ($i = 0; $i -lt $words.Count; $i++) {
        if ($steamExes -notcontains (($words[$i] -split '[\\/]')[-1])) { continue }
        $before = @(); if ($i -gt 0) { $before = @($words[0..($i - 1)]) }
        $after = @(); if ($i + 1 -lt $words.Count) { $after = @($words[($i + 1)..($words.Count - 1)]) }
        $quotedBefore = @($before | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } })
        return [pscustomobject]@{ Folder = (Split-Path -Parent $words[$i]); Before = ($quotedBefore -join ' ')
            Extra = [string[]]@($after | Where-Object { $steamLauncherArgs -notcontains $_ }) }
    }
    return $null
}
# The game folder to start: the saved one when it is Steam's folder or its XVersion (DX12), else Steam's.
function Get-SteamClient([string]$Folder, [string]$Saved) {
    $base = [IO.Path]::GetFullPath($Folder).TrimEnd('\')
    if ($Saved) {
        $chosen = ''
        try { $chosen = [IO.Path]::GetFullPath($Saved).TrimEnd('\') } catch { }
        if (($chosen -eq $base -or $chosen -eq (Join-Path $base 'XVersion')) -and (Test-Client $chosen)) { return $chosen }
    }
    return $base
}
# The account in the Steam profile: the start of its key's SHA-256 (not the key).
function Get-AccountId([string]$Token) {
    if (-not $Token) { return '' }
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::ASCII.GetBytes($Token))
    return ([BitConverter]::ToString($hash) -replace '-', '').Substring(0, 16).ToLowerInvariant()
}
# The server a start from Steam takes without asking: -Server, the profile, else the last used one;
# '' when none is known (then the menu asks).
function Get-SteamServer($Settings, [string]$Given) {
    if ($Given) { return $Given }
    if ("$($Settings.steam.server)".Trim()) { return "$($Settings.steam.server)".Trim() }
    $saved = @(Read-Servers $Settings)
    if ($saved.Count) { return $saved[0].address }
    return ''
}
# The account a start from Steam takes: the profile's on its server, else the most recently used one
# ($null: a new account). Found false: the profile's account is gone (then the menu asks).
function Get-SteamAccount($Settings, [string]$Server, $Accounts) {
    $wanted = "$($Settings.steam.account)"
    if ($wanted -and (Get-ServerFolderName "$($Settings.steam.server)") -eq (Get-ServerFolderName $Server)) {
        foreach ($a in $Accounts) { if ($a.token -and (Get-AccountId $a.token) -eq $wanted) { return [pscustomobject]@{ Found = $true; Entry = $a } } }
        return [pscustomobject]@{ Found = $false; Entry = $null }
    }
    $entry = $null
    if ($Accounts.Count) { $entry = $Accounts[0] }
    return [pscustomobject]@{ Found = $true; Entry = $entry }
}

# A minimal text VDF (KeyValues) reader that keeps where each key and block is, so an edit changes
# only that key's text and leaves the rest of the file as it is. A block: Key, Start, Open, Close,
# End, Children; a pair: Key, Start, Value, ValueStart, End (Children $null). Throws when damaged.
function Read-Vdf([string]$Text) {
    $root = [pscustomobject]@{ Key = ''; Start = 0; Open = -1; Close = $Text.Length; End = $Text.Length; Children = (New-Object Collections.ArrayList); Value = $null }
    $stack = New-Object Collections.ArrayList
    [void]$stack.Add($root)
    $key = $null
    $keyStart = 0
    $last = 0
    if ($Text.Length -and $Text[0] -eq [char]0xFEFF) { $last = 1 }  # a byte order mark
    $tokens = New-Object Text.RegularExpressions.Regex('"((?:[^"\\]|\\.)*)"|//[^\n]*|\[[^\]\n]*\]|[{}]|[^\s{}"]+')
    foreach ($m in $tokens.Matches($Text, $last)) {
        if ($Text.Substring($last, $m.Index - $last).Trim()) { throw "unexpected text at $last" }
        $last = $m.Index + $m.Length
        $word = $m.Value
        if ($word.StartsWith('//', [StringComparison]::Ordinal) -or $word[0] -eq [char]'[') { continue }  # a comment or a condition such as [$WIN32]
        $top = $stack[$stack.Count - 1]
        if ($word -eq '{') {
            if ($null -eq $key) { throw "a block without a name at $($m.Index)" }
            $node = [pscustomobject]@{ Key = $key; Start = $keyStart; Open = $m.Index; Close = -1; End = -1; Children = (New-Object Collections.ArrayList); Value = $null }
            [void]$top.Children.Add($node)
            [void]$stack.Add($node)
            $key = $null
        } elseif ($word -eq '}') {
            if ($null -ne $key -or $stack.Count -eq 1) { throw "unexpected } at $($m.Index)" }
            $top.Close = $m.Index
            $top.End = $last
            $stack.RemoveAt($stack.Count - 1)
        } else {
            if ($m.Groups[1].Success) {
                $word = $m.Groups[1].Value
                if ($word.Contains('\')) {
                    $word = [regex]::Replace($word, '\\(.)', { param($e) switch -CaseSensitive ($e.Groups[1].Value) { 'n' { "`n" } 't' { "`t" } '\' { '\' } '"' { '"' } default { $e.Value } } })
                }
            }
            if ($null -eq $key) { $key = $word; $keyStart = $m.Index }
            else {
                [void]$top.Children.Add([pscustomobject]@{ Key = $key; Start = $keyStart; Value = $word; ValueStart = $m.Index; End = $last; Children = $null })
                $key = $null
            }
        }
    }
    if ($Text.Substring($last).Trim() -or $null -ne $key -or $stack.Count -ne 1) { throw 'the file ends inside a block' }
    return $root
}
function Get-VdfBlock($Node, [string]$Key) {
    foreach ($c in $Node.Children) { if ($null -ne $c.Children -and $c.Key -eq $Key) { return $c } }  # case ignored
    return $null
}
function Get-VdfPair($Node, [string]$Key) {
    foreach ($c in $Node.Children) { if ($null -eq $c.Children -and $c.Key -eq $Key) { return $c } }
    return $null
}
function ConvertTo-VdfText([string]$Value) { return $Value.Replace('\', '\\').Replace('"', '\"') }
# The game's block in a localconfig.vdf text, $null when it has none.
function Get-VdfApp([string]$Text, [string]$App = $steamAppId) {
    $node = Read-Vdf $Text
    foreach ($key in @($launchPath + $App)) { if ($node) { $node = Get-VdfBlock $node $key } }
    return $node
}
# The game's launch options in a localconfig.vdf text; $null when it has none.
function Get-LaunchOptions([string]$Text, [string]$App = $steamAppId) {
    $node = Get-VdfApp $Text $App
    if (-not $node) { return $null }
    $pair = Get-VdfPair $node 'LaunchOptions'
    if ($pair) { return $pair.Value }
    return $null
}
# Text with UserLocalConfigStore > Software > Valve > Steam > apps > App > LaunchOptions set to
# Value ($null: removed); everything else stays. Missing blocks below UserLocalConfigStore are added.
function Set-LaunchOptions([string]$Text, $Value, [string]$App = $steamAppId) {
    $node = Read-Vdf $Text
    $keys = @($launchPath + $App)
    $missing = @()
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $child = Get-VdfBlock $node $keys[$i]
        if (-not $child) { $missing = @($keys[$i..($keys.Count - 1)]); break }
        $node = $child
    }
    if (-not $missing.Count) {
        $pair = Get-VdfPair $node 'LaunchOptions'
        if ($pair -and $null -eq $Value) {
            $begin = 0
            if ($pair.Start -gt 0) { $begin = $Text.LastIndexOf([char]10, $pair.Start - 1) + 1 }
            $finish = $Text.IndexOf([char]10, $pair.End)
            $finish = if ($finish -lt 0) { $Text.Length } else { $finish + 1 }
            if (-not $Text.Substring($begin, $pair.Start - $begin).Trim() -and -not $Text.Substring($pair.End, $finish - $pair.End).Trim()) {
                return $Text.Substring(0, $begin) + $Text.Substring($finish)  # its own line
            }
            return $Text.Substring(0, $pair.Start) + $Text.Substring($pair.End)
        }
        if ($pair) { return $Text.Substring(0, $pair.ValueStart) + '"' + (ConvertTo-VdfText $Value) + '"' + $Text.Substring($pair.End) }
    }
    if ($null -eq $Value) { return $Text }
    if ($missing.Count -and $missing[0] -eq $keys[0]) { throw 'no UserLocalConfigStore block' }
    $newline = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $close = $node.Close
    $begin = 0
    if ($close -gt 0) { $begin = $Text.LastIndexOf([char]10, $close - 1) + 1 }
    $indent = [regex]::Match($Text.Substring($begin), '^[ \t]*').Value
    if ($Text.Substring($begin, $close - $begin).Trim()) { $at = $close; $before = $newline; $after = $indent }  # "}" after other text
    else { $at = $begin; $before = ''; $after = '' }
    $lines = New-Object Collections.ArrayList
    $depth = $indent + "`t"
    foreach ($key in $missing) { [void]$lines.Add("$depth`"$(ConvertTo-VdfText $key)`""); [void]$lines.Add("$depth{"); $depth += "`t" }
    [void]$lines.Add("$depth`"LaunchOptions`"`t`t`"$(ConvertTo-VdfText $Value)`"")
    foreach ($key in $missing) { $depth = $depth.Substring(0, $depth.Length - 1); [void]$lines.Add("$depth}") }
    return $Text.Substring(0, $at) + $before + ($lines -join $newline) + $newline + $after + $Text.Substring($at)
}
# Steam's folder: the registry's, else the usual place.
function Get-SteamFolder {
    foreach ($place in @(@('HKCU:\Software\Valve\Steam', 'SteamPath'), @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'InstallPath'), @('HKLM:\SOFTWARE\Valve\Steam', 'InstallPath'))) {
        try {
            $path = (Get-ItemProperty -LiteralPath $place[0] -ErrorAction Stop).($place[1])
            if ($path -and (Test-Path -LiteralPath $path -PathType Container)) { return [IO.Path]::GetFullPath($path.Replace('/', '\')) }
        } catch { }
    }
    return Join-Path ${env:ProgramFiles(x86)} 'Steam'
}
function Test-SteamRunning { return [bool](Get-Process -Name 'steam' -ErrorAction SilentlyContinue) }
# The Steam users of Steam's folder with a localconfig.vdf: Id, Path, Owns (the file has the game's
# block: the user played it), Name and Recent (from loginusers.vdf), the most recently logged in first.
function Get-SteamUsers([string]$Steam, [string]$App = $steamAppId) {
    $logins = @{}
    try {
        $users = Get-VdfBlock (Read-Vdf ([IO.File]::ReadAllText((Join-Path $Steam 'config\loginusers.vdf')))) 'users'
        foreach ($entry in @($users.Children)) {
            if ($null -eq $entry.Children -or $entry.Key -notmatch '^\d+$') { continue }
            $values = @{}
            foreach ($c in $entry.Children) { if ($null -eq $c.Children) { $values[$c.Key.ToLowerInvariant()] = $c.Value } }
            $recent = [int64]0
            try { $recent = [int64]$values['timestamp'] } catch { }
            if ($values['mostrecent'] -eq '1') { $recent = [Math]::Max($recent, 1) * 2 }  # Steam's own mark of the last login
            $logins["$([int64]$entry.Key - $steamId64Base)"] = @("$($values['personaname'])", $recent)
        }
    } catch { }
    $found = @()
    foreach ($folder in @(Get-ChildItem -LiteralPath (Join-Path $Steam 'userdata') -Directory -ErrorAction SilentlyContinue)) {
        $path = Join-Path $folder.FullName 'config\localconfig.vdf'
        if ($folder.Name -notmatch '^\d+$' -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $owns = $false
        try { $owns = $null -ne (Get-VdfApp ([IO.File]::ReadAllText($path)) $App) } catch { }
        $login = $logins[$folder.Name]
        if (-not $login) { $login = @('', [int64]0) }
        $found += [pscustomobject]@{ Id = $folder.Name; Path = $path; Owns = $owns; Name = $login[0]; Recent = $login[1] }
    }
    return @($found | Sort-Object -Property Recent -Descending)
}
# The Steam user whose launch options to set: the only one that played the game, else asked.
function Select-SteamUser($Users) {
    $owners = @($Users | Where-Object { $_.Owns })
    if (-not $owners.Count) { $owners = @($Users) }
    if ($owners.Count -eq 1) { return $owners[0] }
    Write-Host 'Steam user (the one you play Ring of Elysium with):'
    return $owners[(Select-Menu @($owners | ForEach-Object { if ($_.Name) { "$($_.Name) ($($_.Id))" } else { $_.Id } }))]
}
# Sets the launch options in a localconfig.vdf ($null: removes them) after a backup next to it.
# Returns the backup's path, '' when nothing changed.
function Write-LaunchOptions([string]$Path, $Value, [string]$App = $steamAppId) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $utf8 = New-Object Text.UTF8Encoding($false, $true)
    try { $text = $utf8.GetString($bytes) } catch { throw "$Path is not UTF-8 text; set the launch options in Steam yourself." }
    try { $changed = Set-LaunchOptions $text $Value $App } catch { throw "Could not read $Path ($($_.Exception.Message)); set the launch options in Steam yourself." }
    if ($changed -ceq $text) { return '' }
    $backup = "$Path.$((Get-Date).ToString('yyyyMMdd-HHmmss')).roe-join.bak"
    [IO.File]::WriteAllBytes($backup, $bytes)
    $temp = "$Path.roe-join.tmp"
    [IO.File]::WriteAllBytes($temp, $utf8.GetBytes($changed))
    Move-Item -LiteralPath $temp -Destination $Path -Force
    return $backup
}
# The launch option: the console form (steam-setup), with -Window the window's ("<this file>" --window %command%;
# of the separate files join-roe-os-window.cmd).
function Get-SteamLaunchLine([string]$Self = $env:ROE_JOIN_SELF, [switch]$Window) {
    if ($Window) {
        if (-not $PSBoundParameters.ContainsKey('Self')) { $Self = Get-WindowLauncher }
        return "`"$Self`" --window %command%"
    }
    return "`"$Self`" %command%"
}
# Ours: a line naming join-roe-os.cmd, join-roe-os-window.cmd (the separate files) or join-roe-os.py, or the old
# join.cmd or join.py (set up before the rename).
function Test-OurLaunchOptions([string]$Launch) { return [bool]($Launch -and $Launch -match 'join(-roe-os(-window)?)?\.(cmd|py)\b') }
# join-roe-os.cmd [-Server <address>] [-Name <name>] steam-setup [off]: the Steam profile and the launch
# option line, written into Steam when the player wants (Steam closed). Steam: Get-SteamFolder's.
function Invoke-SteamSetup($Settings, [bool]$Off, [string]$Server, [string]$Name, [string]$Steam = (Get-SteamFolder)) {
    $line = Get-SteamLaunchLine
    if ($Off -or -not ($Server -or $Name)) {
        $Settings.PSObject.Properties.Remove('steam')
        if (-not $Off) { Write-Host 'Started from Steam, join-roe-os.cmd joins the server and account you used last (-Server and -Name fix them).' }
    } else {
        $Server = Get-SteamServer $Settings $Server
        if (-not $Server) { throw 'A server is needed: join-roe-os.cmd -Server <address> steam-setup' }
        $steamProfile = [pscustomobject]@{ server = $Server; account = '' }
        if ($Name) {
            $entry = @(Read-Accounts (Get-AccountFolder $Server) | Where-Object { $_.token -and $_.name -eq $Name })[0]
            if (-not $entry) { throw "No saved account named $Name for $Server. Join once with it first." }
            $steamProfile.account = Get-AccountId $entry.token
        }
        $Settings | Add-Member -NotePropertyName steam -NotePropertyValue $steamProfile -Force
        Write-Host ("Started from Steam, join-roe-os.cmd joins $Server" + $(if ($Name) { " as $Name." } else { ' with its last used account.' }))
    }
    $Settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    $yourself = if ($Off) { 'remove the line in Steam yourself.' } else { 'paste the line into Steam yourself.' }
    if (-not $Off) {
        Write-Host 'Steam launch option (Ring of Elysium > Properties > General > Launch options):'
        Write-Host "  $line"
    }
    $users = @(Get-SteamUsers $Steam)
    if (-not $users.Count) { Write-Host "No Steam user folder in ${Steam}: $yourself"; return }
    $what = if ($Off) { 'Remove it from Steam now' } else { 'Set it in Steam now' }
    if ((Ask "$what? (y/n)" 'y') -notmatch '^[yY]') { return }
    if (Test-SteamRunning) { throw "Steam is running: it writes its settings back when it exits, so the change would be lost. Exit Steam (Steam > Exit), then run this again. Or $yourself" }
    $user = Select-SteamUser $users
    $old = Get-LaunchOptions ([IO.File]::ReadAllText($user.Path))
    if ($Off -and $null -ne $old -and -not (Test-OurLaunchOptions $old)) { Write-Host "The launch options in Steam are not ours, so they stay: $old"; return }
    if (-not $Off -and $old -and $old -cne $line) { Write-Host "Replacing the launch options: $old" }
    $backup = Write-LaunchOptions $user.Path $(if ($Off) { $null } else { $line })
    if (-not $backup) { Write-Host $(if ($Off) { 'Nothing to change in Steam.' } else { 'Steam has this line already.' }); return }
    Write-Host ("$(if ($Off) { 'Removed from' } else { 'Set in' }) Steam ($($user.Path); the old file is $(Split-Path -Leaf $backup)). Start Steam and press Play.")
}

# --- Start through Steam in the window ---------------------------------------------------------
# The window's Set up button writes the launch option "<this file>" --window %command%: Steam then
# opens the window (the batch part waits for it, so Steam sees the game running until it exits),
# which joins the Steam profile's server and account. Another server or account for Steam changes
# only the profile, not Steam.

# The window started by Steam: the game in the command line after --window ($null: not by Steam).
function Find-WindowSteamGame([string]$Text) { return Find-SteamGame (("$Text" -replace '^\s*--window(?=\s|$)', '').Trim()) }
# What the game's launch options in Steam are for this join-roe-os.cmd (Self: its files, Get-OwnLaunchers): off (none), other (not
# ours), window (ours, opens the window), console (ours, steam-setup's console form) or moved
# (ours, but another copy: in another place, or the old join.cmd).
function Get-LaunchState($Launch, [string[]]$Self = @(Get-OwnLaunchers)) {
    if (-not "$Launch".Trim()) { return 'off' }
    if (-not (Test-OurLaunchOptions "$Launch")) { return 'other' }
    $words = Split-CommandLine "$Launch"
    $path = ''
    try { $path = [IO.Path]::GetFullPath($words[0]) } catch { }
    $mine = @(foreach ($file in @($Self | Where-Object { $_ })) { try { [IO.Path]::GetFullPath($file) } catch { } })
    if (-not $path -or $mine -notcontains $path) { return 'moved' }
    if ($words -contains '--window') { return 'window' }
    return 'console'
}
# The Steam users whose launch options the window sets: every one that played the game, else the
# most recently logged in one.
function Get-SteamTargets($Users) {
    $owners = @($Users | Where-Object { $_.Owns })
    if ($owners.Count) { return $owners }
    return @($Users | Select-Object -First 1)
}
# Start through Steam now, for the window: State (nosteam, or the strongest of its users': window,
# console, moved, other, off) and Options (that user's launch options).
function Get-SteamSetupState([string]$Steam = (Get-SteamFolder), [string[]]$Self = @(Get-OwnLaunchers)) {
    $result = [pscustomobject]@{ State = 'nosteam'; Options = '' }
    $users = @(Get-SteamUsers $Steam)
    if (-not $users.Count) { return $result }
    $rank = @{ off = 0; other = 1; moved = 2; console = 3; window = 4 }
    $result.State = 'off'
    foreach ($user in @(Get-SteamTargets $users)) {
        $options = $null
        try { $options = Get-LaunchOptions ([IO.File]::ReadAllText($user.Path)) } catch { }
        $state = Get-LaunchState $options $Self
        if ($rank[$state] -gt $rank[$result.State]) { $result.State = $state; $result.Options = "$options" }
    }
    return $result
}
function Get-SteamExe([string]$Steam) {
    $exe = Join-Path $Steam 'steam.exe'
    if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }
    return ''
}
# Closes Steam as its own Exit does (steam.exe -shutdown, else steam://exit) and waits up to
# Seconds; true once it is closed.
function Stop-Steam([string]$Steam = (Get-SteamFolder), [int]$Seconds = 60) {
    if (-not (Test-SteamRunning)) { return $true }
    $exe = Get-SteamExe $Steam
    if ($exe) { Start-Process -FilePath $exe -ArgumentList '-shutdown' } else { Start-Process -FilePath 'steam://exit' }
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if (-not (Test-SteamRunning)) { Start-Sleep -Milliseconds 500; return $true }
    }
    return $false
}
function Start-Steam([string]$Steam = (Get-SteamFolder)) {
    $exe = Get-SteamExe $Steam
    if ($exe) { Start-Process -FilePath $exe } else { Start-Process -FilePath 'steam://open/main' }
}
# The window's Set up (Off: Turn off) in Steam: closes Steam first when CloseSteam, then sets the
# window's launch option for Get-SteamTargets' users (Off: removes ours). Other launch options stay
# unless Replace: then Done is false and Other has them. Closed: Steam was closed here.
function Invoke-SteamWrite([bool]$Off, [bool]$CloseSteam, [bool]$Replace, [string]$Steam = (Get-SteamFolder)) {
    $result = [pscustomobject]@{ Done = $false; Other = ''; Closed = $false }
    if ($CloseSteam -and (Test-SteamRunning)) {
        Write-Host 'Closing Steam ...'
        if (-not (Stop-Steam $Steam)) { throw 'Steam did not close. Close it yourself (Steam > Exit) and try again.' }
        $result.Closed = $true
    }
    if (Test-SteamRunning) { throw 'Steam is open. Close it (Steam > Exit) and try again.' }
    $users = @(Get-SteamUsers $Steam)
    if (-not $users.Count) { throw 'Steam was not found on this PC. Start Steam and log in once, then try again.' }
    $line = Get-SteamLaunchLine -Window
    $changes = @()
    foreach ($user in @(Get-SteamTargets $users)) {
        $old = $null
        try { $old = Get-LaunchOptions ([IO.File]::ReadAllText($user.Path)) } catch { throw "Could not read Steam's settings: $($_.Exception.Message)" }
        $ours = Test-OurLaunchOptions "$old"
        if ($Off) { if ($ours) { $changes += [pscustomobject]@{ User = $user; Value = $null } }; continue }
        if ("$old".Trim() -and -not $ours -and -not $Replace) { $result.Other = "$old"; return $result }
        $changes += [pscustomobject]@{ User = $user; Value = $line }
    }
    foreach ($change in $changes) { Write-LaunchOptions $change.User.Path $change.Value | Out-Null }
    $result.Done = $true
    return $result
}
# The Steam profile in roe-join.json with some values changed: server and account (Get-AccountId;
# '' for both: the last used ones), auto_start (false: the window waits for Play).
function Set-SteamProfile([hashtable]$Values) {
    $settings = Read-Settings
    $steamProfile = [ordered]@{ server = "$($settings.steam.server)"; account = "$($settings.steam.account)" }
    if ($settings.steam -and $null -ne $settings.steam.auto_start) { $steamProfile.auto_start = [bool]$settings.steam.auto_start }
    foreach ($key in @($Values.Keys)) { $steamProfile[$key] = $Values[$key] }
    $settings | Add-Member -NotePropertyName steam -NotePropertyValue ([pscustomobject]$steamProfile) -Force
    $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}
# Whether the window started by Steam joins at once (the default) or waits for Play.
function Test-SteamAutoStart($Settings) { return -not ($Settings.steam -and $Settings.steam.auto_start -eq $false) }
# Where Steam's Play button joins, in words: "on <server> as <name>".
function Get-SteamProfileText($Settings) {
    $server = "$($Settings.steam.server)".Trim()
    if (-not $server) { return 'on the server and with the account you used last' }
    $wanted = "$($Settings.steam.account)"
    if (-not $wanted) { return "on $server with the account you used last there" }
    foreach ($a in (Read-Accounts (Get-AccountFolder $server))) {
        if ($a.token -and (Get-AccountId $a.token) -eq $wanted) { return "on $server as $($a.name)" }
    }
    return "on $server, but its account is gone: choose one and press the button again"
}
# The window's line about Start through Steam (State from Get-SteamSetupState): Text and Level.
function Get-GuiSteamText([string]$State, $Settings) {
    switch ($State) {
        'window' { return [pscustomobject]@{ Text = "On: Steam's Play button starts the game $(Get-SteamProfileText $Settings)."; Level = 'info' } }
        'console' { return [pscustomobject]@{ Text = 'On, with a console window instead of this one. Press Set up to get this window.'; Level = 'warn' } }
        'moved' { return [pscustomobject]@{ Text = 'On, but for another copy (another folder, or the old join.cmd). Press Set up to use this one.'; Level = 'warn' } }
        'other' { return [pscustomobject]@{ Text = 'Off. Steam has other launch options for Ring of Elysium; Set up asks before it replaces them.'; Level = 'muted' } }
        'nosteam' { return [pscustomobject]@{ Text = 'Off. Steam was not found on this PC.'; Level = 'muted' } }
        'off' { return [pscustomobject]@{ Text = 'Off.'; Level = 'muted' } }
    }
    return [pscustomobject]@{ Text = 'Checking Steam ...'; Level = 'muted' }
}
# The line while the window started by Steam counts down.
function Get-SteamCountdownText([int]$Seconds, [string]$Server, [string]$Account) {
    $who = if ($Account) { " as $Account" } else { ' with a new account' }
    return "Started by Steam: the game starts in $Seconds s on $Server$who."
}

# === The window ===============================================================================
# join-roe-os.cmd without arguments (a double-click) or with --window. The functions above do the work;
# the ones below add only the window.

# The code both runspaces of the window load: this file's settings, constants and functions
# (without its main part), then Write-GuiHost and Read-GuiAnswer as Write-Host and Ask, so the
# console's output and questions go to the window.
function Get-JoinCode([string]$Path) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($Path), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "$(Split-Path -Leaf $Path) is damaged (line $($errors[0].Extent.StartLineNumber): $($errors[0].Message)). Download it again." }
    $parts = @()
    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -is [Management.Automation.Language.FunctionDefinitionAst] -or $statement -is [Management.Automation.Language.AssignmentStatementAst]) { $parts += $statement.Extent.Text }
    }
    $parts += "function Write-Host {$(${function:Write-GuiHost})}"
    $parts += "function Ask {$(${function:Read-GuiAnswer})}"
    return $parts -join "`n"
}

# --- Between the worker and the window -------------------------------------------------------
# The worker never touches the window: it puts events into $sync.Events (line, ask, stats, game,
# done) and the window takes them out ten times a second.
function Send-GuiEvent([string]$Kind, $Data) { $sync.Events.Enqueue([pscustomobject]@{ Kind = $Kind; Data = $Data }) }
# Write-Host in the window: a line in the status, the details and the log (yellow and red ones as warnings).
function Write-GuiHost {
    param([Parameter(Position = 0, ValueFromRemainingArguments = $true)][object[]]$Object, [object]$ForegroundColor, [object]$BackgroundColor, [switch]$NoNewline, [object]$Separator)
    $text = "$(@($Object) -join ' ')".Trim()
    if (-not $text) { return }
    $level = if ("$ForegroundColor" -in @('Red', 'Yellow')) { 'warn' } else { 'info' }
    Send-GuiEvent 'line' ([pscustomobject]@{ Text = $text; Level = $level })
}
# Ask in the window: a dialog, which the worker waits for. Cancel stops the step.
function Read-GuiAnswer {
    param([string]$Question, [string]$Default)
    $request = [pscustomobject]@{ Question = $Question; Default = $Default; Answer = $null; Cancelled = $false; Done = (New-Object Threading.ManualResetEventSlim $false) }
    Send-GuiEvent 'ask' $request
    $request.Done.Wait()
    if ($request.Cancelled) { throw 'Cancelled.' }
    $answer = "$($request.Answer)".Trim().Trim('"')
    if (-not $answer) { return $Default }
    return $answer
}
function Get-ErrorMessage($Record) {
    $exception = if ($Record -is [Management.Automation.ErrorRecord]) { $Record.Exception } else { $Record }
    while ($exception -is [Management.Automation.MethodInvocationException] -and $exception.InnerException) { $exception = $exception.InnerException }
    return "$($exception.Message)"
}
# Runs one piece of work in the worker and reports it (done: Ok, Result, Message, Details).
# Event: 'done' for the worker, 'side-done' for the side worker (the admin page).
function Invoke-Work([string]$Command, [hashtable]$Arguments, [string]$Event = 'done') {
    $done = [pscustomobject]@{ Ok = $true; Result = $null; Message = ''; Details = '' }
    try { $done.Result = & $Command @Arguments }
    catch { $done.Ok = $false; $done.Message = Get-ErrorMessage $_; $done.Details = "$($_ | Out-String)$($_.ScriptStackTrace)".Trim() }
    Send-GuiEvent $Event $done
}

# --- Work in the background --------------------------------------------------------------------
# The selected server: its name, version and who plays where; refreshes the names of its saved
# accounts (renamed in the game) and their roles (Roles: key -> admin, gm or player, ROLE).
function Invoke-ServerJob([string]$Server) {
    $ips = Resolve-ServerIps (Get-ServerHost $Server)
    $folder = Get-AccountFolder $Server
    $contact = Connect-Server $ips[0] $folder $ips $false
    $roles = @{}
    if ($contact.Info -match '^OK ' -and -not $contact.TooOld) {
        $accounts = Read-Accounts $folder
        if ($accounts.Count -and (Update-AccountNames $ips[0] $folder $accounts)) { Save-Accounts $folder $accounts | Out-Null }
        foreach ($a in @($accounts | Where-Object { $_.token })) {
            $role = ''
            try { $role = Get-AccountRole (Invoke-Account $ips[0] $folder "ROLE $($a.token)") } catch { }
            if ($role) { $roles[$a.token] = $role }
        }
    }
    return [pscustomobject]@{ Server = $Server; Contact = $contact; Roles = $roles }
}
# The region table again (Update-GuiStats): the server's STATS as Format-Stats shows it.
function Invoke-StatsJob([string]$Server) {
    $ip = (Resolve-ServerIps (Get-ServerHost $Server))[0]
    return [pscustomobject]@{ Server = $Server; Regions = (Format-Stats (Get-ServerStats $ip (Get-AccountFolder $Server))) }
}
# Advanced > Open the admin page: the login link of the account (Token) in the browser.
function Invoke-AdminJob([string]$Server, [string]$Token) {
    $hostName = Get-ServerHost $Server
    $ip = (Resolve-ServerIps $hostName)[0]
    $folder = Get-AccountFolder $Server
    $link = Request-AdminLink $ip $folder $hostName ([pscustomobject]@{ token = $Token })
    if ($link.Problem) { throw $link.Problem }
    Start-Process $link.Url
    return $link.Url
}
# A game folder as the window shows it: the Ring of Elysium folder (Base) and whether it is its
# XVersion folder (Dx12). A saved or picked XVersion folder is its parent with DirectX 12.
function Split-GameFolder([string]$Folder) {
    $trimmed = "$Folder".TrimEnd('\', '/')
    if ($trimmed -and [IO.Path]::GetFileName($trimmed) -eq 'XVersion') {
        $parent = Split-Path -Parent $trimmed
        if ($parent) { return [pscustomobject]@{ Base = $parent; Dx12 = $true } }
    }
    return [pscustomobject]@{ Base = $trimmed; Dx12 = $false }
}
# The folder the game starts from (Folder, '' when it has no Europa_Client.exe) and what is
# missing (Problem): the XVersion folder with DirectX 12, the folder itself without.
function Get-GameFolderChoice([string]$Base, [bool]$Dx12) {
    $result = [pscustomobject]@{ Folder = ''; Problem = '' }
    if (-not $Base) { $result.Problem = 'Choose the Ring of Elysium folder with Browse...'; return $result }
    $folder = if ($Dx12) { Join-Path $Base 'XVersion' } else { $Base }
    if (Test-Client $folder) { $result.Folder = $folder; return $result }
    if ($Dx12) {
        $result.Problem = "No DirectX 12 version found in ${Base} (no XVersion\Europa_Client.exe): uncheck DirectX 12."
    } elseif (Test-Client (Join-Path $Base 'XVersion')) {
        $result.Problem = "No DirectX 11 version found in ${Base} (no Europa_Client.exe): tick DirectX 12 to play its XVersion folder."
    } else {
        $result.Problem = "No Europa_Client.exe in ${Base}: choose the Ring of Elysium folder (usually C:\Program Files (x86)\Steam\steamapps\common\Ring of Elysium)."
    }
    return $result
}
# Whether the admin page's part shows for an account (Entry) of the server: only with GM rights
# there, as a GM or an admin (Roles from Invoke-ServerJob of that server).
function Test-ShowAdmin($Roles, $Entry) {
    return [bool]($Roles -and $Entry -and $Entry.token -and ($Roles[$Entry.token] -eq 'gm' -or $Roles[$Entry.token] -eq 'admin'))
}
# Play: the same steps as the console's main part, with the window's answers. Token and AccountName:
# the saved account (New: a new one); UseVoice false: no voice chat this time; Extra: started by
# Steam, what follows Steam's own arguments. Returns once the game has exited and the original
# voice DLL is back.
function Invoke-PlayJob([string]$Client, [string]$Server, [string]$Token, [string]$AccountName, [bool]$New, [bool]$UseVoice, [string[]]$Extra = @()) {
    $settings = Read-Settings
    $client = Get-GameFolder $Client
    Confirm-GameFiles $client $false
    $hostName = Get-ServerHost $Server
    $firewall = $settings.firewall
    $voice = $settings.voice
    $voiceDll = $settings.voice_dll
    $serverList = Add-ServerUse @(Get-OfferedServers $settings) $Server
    $save = { Save-JoinSettings $client $firewall $voice $voiceDll $serverList }
    $voicePick = $null
    if ($UseVoice) {
        $choice = Get-VoiceChoice $true $voiceDll $client ''
        $voiceDll = $choice.Dll
        $voicePick = $choice.Pick
    }
    & $save
    $serverIps = Resolve-ServerIps $hostName
    $serverIp = $serverIps[0]
    Write-Host "Contacting $serverIp ..."
    $folder = Get-AccountFolder $Server
    $contact = Connect-Server $serverIp $folder $serverIps $true
    if ($contact.Info -match '^OK ' -and (Set-ServerName $serverList $Server $contact.Name)) { & $save }
    if ($contact.TooOld) { throw $contact.TooOld }
    if ($contact.Notice) { Write-Host $contact.Notice -ForegroundColor Yellow }
    if ($contact.Regions) { Send-GuiEvent 'stats' ($contact.Regions -replace ' \| ', "`n") }
    $rules = Update-Firewall $client $serverList $Server $serverIps $contact.Listed ([bool]$firewall)
    if ($rules.Check) { Confirm-GuiFirewall $client $rules }
    & $save
    $accounts = Read-Accounts $folder
    $entry = $null
    if (-not $New) {
        $entry = @($accounts | Where-Object { if ($Token) { $_.token -ceq $Token } else { -not $_.token -and $_.name -eq $AccountName } })[0]
        if (-not $entry) { throw "The account $AccountName is no longer saved for this server. Pick another one or create a new account." }
    }
    $login = Connect-Account $serverIp $folder $accounts $entry ''
    & $save
    if ($login.Accounts) {
        $info = $null
        try { $info = Invoke-Account $serverIp $folder 'INFO' } catch { }
        $stats = $null
        try { $stats = Get-ServerStats $serverIp $folder } catch { }
        if ($info -match '^OK ') { Send-GuiEvent 'stats' ((Format-ServerNow $info $stats) -replace ' \| ', "`n") }
    }
    $game = Start-Game $client $login.Uid $serverIp $voicePick @($Extra)
    Send-GuiEvent 'game' $game.VoiceOn
    try {
        # While the game runs: the server's numbers every 30 s.
        while (-not $game.Process.WaitForExit(30000)) {
            if (-not $login.Accounts) { continue }
            $info = $null
            try { $info = Invoke-Account $serverIp $folder 'INFO' } catch { }
            $stats = $null
            try { $stats = Get-ServerStats $serverIp $folder } catch { }
            if ($info -match '^OK ') { Send-GuiEvent 'stats' ("[{0:HH:mm}] {1}" -f (Get-Date), ((Format-ServerNow $info $stats) -replace ' \| ', "`n")) }
        }
    } finally {
        if ($game.VoiceOn) { Restore-Voice $client 15 | Out-Null }
    }
    return $login.Name
}
# What went wrong with the firewall rules and what to do, as lines for the window.
function Get-GuiFirewallText([string[]]$Problems, [string]$Note, $Blocking, [bool]$Admin) {
    $lines = @()
    if ($Note) { $lines += "The firewall rules could not be set. $Note" }
    else { $lines += 'The firewall rules are not as they should be, so the game may not reach the server.' }
    foreach ($problem in @($Problems | Select-Object -First 5)) { $lines += "- $problem" }
    if ($Problems.Count -gt 5) { $lines += "- and $($Problems.Count - 5) more (Advanced > Show the rules)" }
    if (@($Blocking | Where-Object { $_ -and -not $_.Local }).Count) {
        $lines += 'Remove or turn off the rules of the policy or security product where they come from (or ask who manages this PC).'
    }
    if ($Admin) { $lines += 'join-roe-os.cmd already runs as administrator: the details show the error.' }
    else { $lines += 'Right-click join-roe-os.cmd > Run as administrator (on a standard Windows account this needs an administrator''s password).' }
    $lines += 'Or turn the firewall rules off under Advanced (then the game can reach the internet).'
    return $lines
}
# After the firewall step: when the rules are not right, says so and asks whether to start anyway.
function Confirm-GuiFirewall([string]$Client, $Rules) {
    $check = Get-FirewallCheck $Client $Rules.Programs $Rules.Check.Wanted $Rules.Check.RulesOn
    $problems = @($check.Problems)
    if (-not $problems.Count) { return }
    foreach ($line in (Get-GuiFirewallText $problems (Get-ElevationNote $Rules.Check.Step) $check.Blocking (Test-Administrator))) { Write-Host $line -ForegroundColor Yellow }
    if ((Ask 'Start the game anyway? (y/n)' 'n') -notmatch '^[yY]') { throw 'Cancelled: the firewall rules are not in place.' }
}
# The server line under the server list: Text and Level (info, warn, error).
function Get-ServerInfoText($Contact) {
    if (-not $Contact.Info) { return [pscustomobject]@{ Text = 'No answer from the account service: the server may be down, or it has no accounts (then it takes a plain name).'; Level = 'warn' } }
    if ($Contact.TooOld) { return [pscustomobject]@{ Text = $Contact.TooOld; Level = 'error' } }
    if ("$($Contact.Info)" -notmatch '^OK ') { return [pscustomobject]@{ Text = "The account service answered: $($Contact.Info)"; Level = 'warn' } }
    $lines = @()
    if ($Contact.Notice) { $lines += $Contact.Notice }
    if ($Contact.Regions) { $lines += $Contact.Regions -replace ' \| ', "`n" } else { $lines += Format-ServerInfo $Contact.Info }
    $level = if ($Contact.Notice) { 'warn' } else { 'info' }
    return [pscustomobject]@{ Text = $lines -join "`n"; Level = $level }
}
# roe-join.json with some values changed (client, firewall, voice, voice_dll, servers).
function Update-Settings([hashtable]$Values) {
    $settings = Read-Settings
    $all = @{ client = "$($settings.client)"; firewall = $settings.firewall; voice = $settings.voice; voice_dll = $settings.voice_dll; servers = @(Read-Servers $settings) }
    foreach ($key in @($Values.Keys)) { $all[$key] = $Values[$key] }
    Save-JoinSettings $all.client $all.firewall $all.voice $all.voice_dll $all.servers
}
# Our voice DLL: the saved one while it exists, else the one next to the scripts.
function Get-GuiVoiceDll {
    $saved = "$((Read-Settings).voice_dll)"
    if ($saved -and (Test-Path -LiteralPath $saved -PathType Leaf)) { return $saved }
    return Get-DefaultVoiceDll
}

# --- The window --------------------------------------------------------------------------------
# UI strings are loaded once, on the window thread. The catalog uses ASCII JSON escapes
# so the batch/PowerShell file also works with legacy Windows code pages.
function Get-GuiLanguages {
    return (ConvertFrom-Json @'
{
  "en": {
  "Native": "English",
  "Language": "Language",
  "Edition": "2022 edition",
  "Subtitle": "Multiplayer launcher",
  "Server": "Server",
  "AddServer": "Add server...",
  "Account": "Account",
  "NewAccount": "Create a new account",
  "GameFolder": "Game folder",
  "Browse": "Browse...",
  "Voice": "Voice chat",
  "ChooseFolder": "Choose folder...",
  "Advanced": "Advanced settings",
  "Details": "Details",
  "HideDetails": "Hide details",
  "Region": "Region",
  "Online": "Online",
  "Queued": "In queue",
  "Modes": "Queue by mode",
  "Games": "Matches",
  "Offline": "Offline",
  "ServerStatus": "Server status",
  "Play": "Play",
  "Running": "Game running",
  "Joining": "Joining...",
  "Ready": "Choose the server and the account, then Play.",
  "FwOn": "Enable firewall rules",
  "FwOff": "Disable firewall rules",
  "FwReset": "Reset all rules",
  "FwShow": "Show rules",
  "Export": "Export accounts...",
  "Import": "Import accounts...",
  "Log": "Open log",
  "Admin": "Open admin page",
  "BackupHelp": "Export your account keys to use them on another PC. Keep the backup private.",
  "AdminHelp": "This account can manage bots, matchmaking and server status in the browser.",
  "Cancel": "Cancel",
  "Ok": "OK",
  "Address": "Server address (IP or domain)",
  "AddressHelp": "Enter the address from the server host, for example play.example.org.",
  "PlayerName": "Your name (1 to 24 characters)",
  "VoiceOff": "Off",
  "VoiceFileMissing": "DLL missing",
  "VoiceFileInvalid": "DLL unavailable",
  "VoiceAvailable": "Ready",
  "VoiceActive": "Active in game",
  "VoiceSessionOff": "Off for this game",
  "VoiceMissing": "Choose the folder containing {0}, or download it from {1}.",
  "VoiceReady": "The game uses {0} while running. The original file is restored afterwards.",
  "VoiceProblem": "{0} Choose the folder containing the voice file.",
  "LocateGame": "Choose your Ring of Elysium folder in Steam. Select DirectX 12 to use the XVersion folder.",
  "Dx11": "DirectX 11 version.",
  "Dx12": "DirectX 12 \u00b7 {0}",
  "FirewallPending": "Firewall rules will be offered the first time you play.",
  "FirewallOn": "Firewall rules are on.",
  "FirewallOff": "Firewall rules are off.",
  "FirewallHelp": "These rules restrict the game to trusted servers. Changing the allowed addresses requires administrator approval.",
  "AskFirewall": "Restrict the game to this PC and the servers you join? The game also tries to contact the publisher's old servers. Updating these Windows Firewall rules requires administrator approval. You can change this setting in Advanced settings.",
  "ResetConfirm": "Remove the firewall rules created by this launcher and the server launcher for all game folders? If firewall rules are enabled, this launcher will request new rules the next time you join.",
  "WithoutVoice": "Play without voice chat this time?",
  "CloseConfirm": "The launcher is joining or waiting for the game to exit. Close it anyway? If needed, the original voice file will be restored next time.",
  "Contacting": "Contacting {0}...",
  "AddFirst": "Add a server using its IP address or domain.",
  "VoiceFolder": "Choose the folder containing {0}.",
  "AllFiles": "All files",
  "Backup": "Account backup",
  "Checking": "Checking the game in {0}...",
  "FolderVerified": "Game folder: {0} (verified).",
  "ConnectTo": "Joining {0}...",
  "GameExited": "The game has exited.",
  "JoinFailed": "Could not join: {0}",
  "BadAddress": "Invalid IP address or domain: {0}",
  "VoicePath": "Voice file: {0}",
  "NoServerInfo": "No response from the account service. The server may be offline or may accept just a player name.",
  "SteamSetup": "Set up starting through Steam",
  "SteamIntro": "With this, Steam's Play button starts the game on this server with your account, with the Steam overlay and playtime. It opens this window, which joins and closes itself when the game exits.",
  "SteamByHand": "By hand",
  "SteamByHandHelp": "In Steam: Ring of Elysium > Properties > General > Launch options, paste this line. Steam's Play then joins the server and account you used last.",
  "SteamCopy": "Copy",
  "SteamAutomatic": "Automatic",
  "SteamAutomaticHelp": "Set up puts the line into Steam for you, with the server and account selected above. Steam has to be closed for this: join-roe-os.cmd asks, closes it and can start it again.",
  "SteamSet": "Set up Start through Steam",
  "SteamUse": "Use the selected server and account",
  "SteamOff": "Turn it off",
  "SteamAutoStart": "When Steam starts the game, join at once (3 seconds to cancel)"
},
  "da": {
  "Native": "Dansk",
  "Language": "Sprog",
  "Edition": "2022-udgave",
  "Subtitle": "Multiplayer-launcher",
  "Server": "Server",
  "AddServer": "Tilf\u00f8j server...",
  "Account": "Konto",
  "NewAccount": "Opret en ny konto",
  "GameFolder": "Spilmappe",
  "Browse": "Gennemse...",
  "Voice": "Stemmechat",
  "ChooseFolder": "V\u00e6lg mappe...",
  "Advanced": "Avancerede indstillinger",
  "Details": "Detaljer",
  "HideDetails": "Skjul detaljer",
  "Region": "Region",
  "Online": "Online",
  "Queued": "I k\u00f8",
  "Modes": "K\u00f8 pr. tilstand",
  "Games": "Kampe",
  "Offline": "Offline",
  "ServerStatus": "Serverstatus",
  "Play": "Spil",
  "Running": "Spillet k\u00f8rer",
  "Joining": "Tilslutter...",
  "Ready": "V\u00e6lg server og konto, og tryk p\u00e5 Spil.",
  "FwOn": "Aktiv\u00e9r firewallregler",
  "FwOff": "Deaktiv\u00e9r firewallregler",
  "FwReset": "Nulstil alle regler",
  "FwShow": "Vis regler",
  "Export": "Eksport\u00e9r konti...",
  "Import": "Import\u00e9r konti...",
  "Log": "\u00c5bn log",
  "Admin": "\u00c5bn adminsiden",
  "BackupHelp": "Eksport\u00e9r dine konton\u00f8gler for at bruge dem p\u00e5 en anden pc. Hold sikkerhedskopien privat.",
  "AdminHelp": "Denne konto kan administrere bots, matchmaking og serverstatus i browseren.",
  "Cancel": "Annuller",
  "Ok": "OK",
  "Address": "Serveradresse (IP eller dom\u00e6ne)",
  "AddressHelp": "Indtast adressen fra serverens v\u00e6rt, fx play.example.org.",
  "PlayerName": "Dit navn (1 til 24 tegn)",
  "VoiceOff": "Sl\u00e5et fra",
  "VoiceFileMissing": "DLL mangler",
  "VoiceFileInvalid": "DLL kan ikke bruges",
  "VoiceAvailable": "Klar",
  "VoiceActive": "Aktiv i spillet",
  "VoiceSessionOff": "Fra i dette spil",
  "VoiceMissing": "V\u00e6lg mappen med {0}, eller hent filen fra {1}.",
  "VoiceReady": "Spillet bruger {0}, mens det k\u00f8rer. Den originale fil gendannes bagefter.",
  "VoiceProblem": "{0} V\u00e6lg mappen med stemmechatfilen.",
  "LocateGame": "V\u00e6lg din Ring of Elysium-mappe i Steam. V\u00e6lg DirectX 12 for at bruge XVersion-mappen.",
  "Dx11": "DirectX 11-versionen.",
  "Dx12": "DirectX 12 \u00b7 {0}",
  "FirewallPending": "Du bliver spurgt om firewallregler f\u00f8rste gang, du spiller.",
  "FirewallOn": "Firewallregler er sl\u00e5et til.",
  "FirewallOff": "Firewallregler er sl\u00e5et fra.",
  "FirewallHelp": "Reglerne begr\u00e6nser spillets adgang til betroede servere. \u00c6ndring af de tilladte adresser kr\u00e6ver administratorgodkendelse.",
  "AskFirewall": "M\u00e5 spillet kun oprette forbindelse til denne pc og de servere, du spiller p\u00e5? Spillet fors\u00f8ger ogs\u00e5 at kontakte udgiverens gamle servere. \u00c6ndringer af reglerne i Windows Firewall kr\u00e6ver administratorgodkendelse. Du kan \u00e6ndre valget under Avancerede indstillinger.",
  "ResetConfirm": "Vil du fjerne de firewallregler, som denne launcher og serverlauncheren har oprettet for alle spilmapper? Hvis firewallregler er sl\u00e5et til, vil denne launcher anmode om nye regler, n\u00e6ste gang du forbinder til en server.",
  "WithoutVoice": "Vil du spille uden stemmechat denne gang?",
  "CloseConfirm": "Launcheren opretter forbindelse eller venter p\u00e5, at spillet lukker. Vil du lukke alligevel? Den originale stemmechatfil gendannes om n\u00f8dvendigt n\u00e6ste gang.",
  "Contacting": "Kontakter {0}...",
  "AddFirst": "Tilf\u00f8j en server med dens IP-adresse eller dom\u00e6ne.",
  "VoiceFolder": "V\u00e6lg mappen med {0}.",
  "AllFiles": "Alle filer",
  "Backup": "Kontosikkerhedskopi",
  "Checking": "Tjekker spillet i {0}...",
  "FolderVerified": "Spilmappe: {0} (kontrolleret).",
  "ConnectTo": "Opretter forbindelse til {0}...",
  "GameExited": "Spillet er lukket.",
  "JoinFailed": "Kunne ikke oprette forbindelse: {0}",
  "BadAddress": "Ugyldig IP-adresse eller dom\u00e6ne: {0}",
  "VoicePath": "Stemmechatfil: {0}",
  "NoServerInfo": "Intet svar fra kontotjenesten. Serveren kan v\u00e6re offline eller n\u00f8jes med et spillernavn.",
  "SteamSetup": "Start gennem Steam",
  "SteamIntro": "S\u00e5 starter Steams Spil-knap spillet p\u00e5 denne server med din konto, med Steam-overlay og spilletid. Den \u00e5bner dette vindue, som opretter forbindelse og lukker sig selv, n\u00e5r spillet afsluttes.",
  "SteamByHand": "Manuelt",
  "SteamByHandHelp": "I Steam: Ring of Elysium > Egenskaber > Generelt > Startindstillinger, inds\u00e6t denne linje. Steams Spil opretter s\u00e5 forbindelse til den server og konto, du brugte sidst.",
  "SteamCopy": "Kopi\u00e9r",
  "SteamAutomatic": "Automatisk",
  "SteamAutomaticHelp": "Konfigur\u00e9r s\u00e6tter linjen ind i Steam for dig med serveren og kontoen valgt ovenfor. Steam skal v\u00e6re lukket: join-roe-os.cmd sp\u00f8rger, lukker det og kan starte det igen.",
  "SteamSet": "Konfigur\u00e9r start gennem Steam",
  "SteamUse": "Brug den valgte server og konto",
  "SteamOff": "Sl\u00e5 fra",
  "SteamAutoStart": "N\u00e5r Steam starter spillet, opret forbindelse med det samme (3 sekunder til at annullere)"
},
  "de": {
  "Native": "Deutsch",
  "Language": "Sprache",
  "Edition": "Ausgabe 2022",
  "Subtitle": "Multiplayer-Launcher",
  "Server": "Server",
  "AddServer": "Server hinzuf\u00fcgen...",
  "Account": "Konto",
  "NewAccount": "Neues Konto erstellen",
  "GameFolder": "Spielordner",
  "Browse": "Durchsuchen...",
  "Voice": "Sprachchat",
  "ChooseFolder": "Ordner w\u00e4hlen...",
  "Advanced": "Erweiterte Einstellungen",
  "Details": "Details",
  "HideDetails": "Details ausblenden",
  "Region": "Region",
  "Online": "Online",
  "Queued": "In Warteschlange",
  "Modes": "Warteschlange je Modus",
  "Games": "Matches",
  "Offline": "Offline",
  "ServerStatus": "Serverstatus",
  "Play": "Spielen",
  "Running": "Spiel l\u00e4uft",
  "Joining": "Verbinden...",
  "Ready": "Server und Konto w\u00e4hlen, dann auf Spielen klicken.",
  "FwOn": "Firewallregeln aktivieren",
  "FwOff": "Firewallregeln deaktivieren",
  "FwReset": "Alle Regeln zur\u00fccksetzen",
  "FwShow": "Regeln anzeigen",
  "Export": "Konten exportieren...",
  "Import": "Konten importieren...",
  "Log": "Protokoll \u00f6ffnen",
  "Admin": "Adminseite \u00f6ffnen",
  "BackupHelp": "Exportiere deine Kontoschl\u00fcssel f\u00fcr einen anderen PC. Bewahre die Sicherung vertraulich auf.",
  "AdminHelp": "Mit diesem Konto kannst du Bots, Matchmaking und Serverstatus im Browser verwalten.",
  "Cancel": "Abbrechen",
  "Ok": "OK",
  "Address": "Serveradresse (IP oder Domain)",
  "AddressHelp": "Gib die Adresse des Serverbetreibers ein, z. B. play.example.org.",
  "PlayerName": "Dein Name (1 bis 24 Zeichen)",
  "VoiceOff": "Aus",
  "VoiceFileMissing": "DLL fehlt",
  "VoiceFileInvalid": "DLL nicht verwendbar",
  "VoiceAvailable": "Bereit",
  "VoiceActive": "Im Spiel aktiv",
  "VoiceSessionOff": "F\u00fcr dieses Spiel aus",
  "VoiceMissing": "W\u00e4hle den Ordner mit {0} oder lade die Datei hier herunter: {1}.",
  "VoiceReady": "Das Spiel nutzt {0}, solange es l\u00e4uft. Danach wird die Originaldatei wiederhergestellt.",
  "VoiceProblem": "{0} W\u00e4hle den Ordner mit der Sprachdatei.",
  "LocateGame": "W\u00e4hle den Ring-of-Elysium-Ordner in Steam. Aktiviere DirectX 12 f\u00fcr den XVersion-Ordner.",
  "Dx11": "DirectX-11-Version.",
  "Dx12": "DirectX 12 \u00b7 {0}",
  "FirewallPending": "Beim ersten Spielstart wirst du nach Firewallregeln gefragt.",
  "FirewallOn": "Firewallregeln sind aktiviert.",
  "FirewallOff": "Firewallregeln sind deaktiviert.",
  "FirewallHelp": "Die Regeln beschr\u00e4nken das Spiel auf vertrauensw\u00fcrdige Server. F\u00fcr \u00c4nderungen an den erlaubten Adressen sind Administratorrechte n\u00f6tig.",
  "AskFirewall": "Soll das Spiel nur diesen PC und die Server erreichen k\u00f6nnen, auf denen du spielst? Das Spiel versucht auch, die alten Server des Herausgebers zu kontaktieren. \u00c4nderungen an diesen Windows-Firewallregeln erfordern Administratorrechte. Du kannst die Option in den erweiterten Einstellungen \u00e4ndern.",
  "ResetConfirm": "Die Firewallregeln entfernen, die dieser Launcher und der Server-Launcher f\u00fcr alle Spielordner erstellt haben? Wenn die Firewallregeln aktiviert sind, fordert dieser Launcher beim n\u00e4chsten Verbindungsaufbau neue Regeln an.",
  "WithoutVoice": "Diesmal ohne Sprachchat spielen?",
  "CloseConfirm": "Der Launcher verbindet sich oder wartet auf das Spielende. Trotzdem schlie\u00dfen? Die urspr\u00fcngliche Sprachdatei wird bei Bedarf beim n\u00e4chsten Start wiederhergestellt.",
  "Contacting": "Verbinde mit {0}...",
  "AddFirst": "F\u00fcge einen Server \u00fcber seine IP-Adresse oder Domain hinzu.",
  "VoiceFolder": "W\u00e4hle den Ordner mit {0}.",
  "AllFiles": "Alle Dateien",
  "Backup": "Kontosicherung",
  "Checking": "Spiel in {0} wird gepr\u00fcft...",
  "FolderVerified": "Spielordner: {0} (gepr\u00fcft).",
  "ConnectTo": "Verbindung mit {0} wird hergestellt...",
  "GameExited": "Das Spiel wurde beendet.",
  "JoinFailed": "Verbindung fehlgeschlagen: {0}",
  "BadAddress": "Ung\u00fcltige IP-Adresse oder Domain: {0}",
  "VoicePath": "Sprachdatei: {0}",
  "NoServerInfo": "Keine Antwort vom Kontodienst. Der Server ist eventuell offline oder akzeptiert nur einen Spielernamen.",
  "SteamSetup": "\u00dcber Steam starten einrichten",
  "SteamIntro": "Damit startet Steams Spielen-Knopf das Spiel auf diesem Server mit deinem Konto, mit Steam-Overlay und Spielzeit. Er \u00f6ffnet dieses Fenster, das beitritt und sich schlie\u00dft, wenn das Spiel endet.",
  "SteamByHand": "Von Hand",
  "SteamByHandHelp": "In Steam: Ring of Elysium > Eigenschaften > Allgemein > Startoptionen, diese Zeile einf\u00fcgen. Steams Spielen tritt dann dem zuletzt genutzten Server mit dem zuletzt genutzten Konto bei.",
  "SteamCopy": "Kopieren",
  "SteamAutomatic": "Automatisch",
  "SteamAutomaticHelp": "Einrichten tr\u00e4gt die Zeile f\u00fcr dich in Steam ein, mit dem oben gew\u00e4hlten Server und Konto. Steam muss daf\u00fcr geschlossen sein: join-roe-os.cmd fragt, schlie\u00dft es und kann es wieder starten.",
  "SteamSet": "Start \u00fcber Steam einrichten",
  "SteamUse": "Gew\u00e4hlten Server und Konto nutzen",
  "SteamOff": "Ausschalten",
  "SteamAutoStart": "Wenn Steam das Spiel startet, sofort beitreten (3 Sekunden zum Abbrechen)"
},
  "fr": {
  "Native": "Fran\u00e7ais",
  "Language": "Langue",
  "Edition": "\u00c9dition 2022",
  "Subtitle": "Lanceur multijoueur",
  "Server": "Serveur",
  "AddServer": "Ajouter un serveur...",
  "Account": "Compte",
  "NewAccount": "Cr\u00e9er un compte",
  "GameFolder": "Dossier du jeu",
  "Browse": "Parcourir...",
  "Voice": "Chat vocal",
  "ChooseFolder": "Choisir un dossier...",
  "Advanced": "Param\u00e8tres avanc\u00e9s",
  "Details": "D\u00e9tails",
  "HideDetails": "Masquer les d\u00e9tails",
  "Region": "R\u00e9gion",
  "Online": "En ligne",
  "Queued": "En attente",
  "Modes": "Attente par mode",
  "Games": "Parties",
  "Offline": "Hors ligne",
  "ServerStatus": "\u00c9tat du serveur",
  "Play": "Jouer",
  "Running": "Jeu en cours",
  "Joining": "Connexion...",
  "Ready": "Choisissez le serveur et le compte, puis cliquez sur Jouer.",
  "FwOn": "Activer les r\u00e8gles",
  "FwOff": "D\u00e9sactiver les r\u00e8gles",
  "FwReset": "R\u00e9initialiser les r\u00e8gles",
  "FwShow": "Afficher les r\u00e8gles",
  "Export": "Exporter les comptes...",
  "Import": "Importer les comptes...",
  "Log": "Ouvrir le journal",
  "Admin": "Ouvrir l\u2019administration",
  "BackupHelp": "Exportez les cl\u00e9s de vos comptes pour les utiliser sur un autre PC. Gardez cette sauvegarde priv\u00e9e.",
  "AdminHelp": "Ce compte peut g\u00e9rer les bots, le matchmaking et l\u2019\u00e9tat du serveur dans le navigateur.",
  "Cancel": "Annuler",
  "Ok": "OK",
  "Address": "Adresse du serveur (IP ou domaine)",
  "AddressHelp": "Saisissez l\u2019adresse fournie par l\u2019h\u00f4te, par exemple play.example.org.",
  "PlayerName": "Votre nom (1 \u00e0 24 caract\u00e8res)",
  "VoiceOff": "D\u00e9sactiv\u00e9",
  "VoiceFileMissing": "DLL introuvable",
  "VoiceFileInvalid": "DLL inutilisable",
  "VoiceAvailable": "Pr\u00eat",
  "VoiceActive": "Actif en jeu",
  "VoiceSessionOff": "D\u00e9sactiv\u00e9 pour cette partie",
  "VoiceMissing": "Choisissez le dossier contenant {0} ou t\u00e9l\u00e9chargez le fichier depuis {1}.",
  "VoiceReady": "Le jeu utilise {0} pendant la partie. Le fichier d\u2019origine est ensuite restaur\u00e9.",
  "VoiceProblem": "{0} Choisissez le dossier du fichier vocal.",
  "LocateGame": "Choisissez le dossier Ring of Elysium de Steam. Cochez DirectX 12 pour utiliser le dossier XVersion.",
  "Dx11": "Version DirectX 11.",
  "Dx12": "DirectX 12 \u00b7 {0}",
  "FirewallPending": "Les r\u00e8gles du pare-feu seront propos\u00e9es au premier lancement.",
  "FirewallOn": "Les r\u00e8gles du pare-feu sont activ\u00e9es.",
  "FirewallOff": "Les r\u00e8gles du pare-feu sont d\u00e9sactiv\u00e9es.",
  "FirewallHelp": "Ces r\u00e8gles limitent le jeu aux serveurs de confiance. Modifier les adresses autoris\u00e9es n\u00e9cessite des droits administrateur.",
  "AskFirewall": "Limiter les connexions du jeu \u00e0 ce PC et aux serveurs que vous rejoignez ? Le jeu tente aussi de contacter les anciens serveurs de l\u2019\u00e9diteur. La modification de ces r\u00e8gles du pare-feu Windows n\u00e9cessite des droits administrateur. Vous pouvez changer cette option dans les param\u00e8tres avanc\u00e9s.",
  "ResetConfirm": "Supprimer les r\u00e8gles de pare-feu cr\u00e9\u00e9es par ce lanceur et par le lanceur du serveur pour tous les dossiers du jeu ? Si les r\u00e8gles sont activ\u00e9es, ce lanceur demandera de nouvelles r\u00e8gles \u00e0 la prochaine connexion.",
  "WithoutVoice": "Jouer sans chat vocal cette fois-ci ?",
  "CloseConfirm": "Le lanceur se connecte ou attend la fermeture du jeu. Le fermer ? Le fichier vocal d\u2019origine sera restaur\u00e9 au prochain lancement si n\u00e9cessaire.",
  "Contacting": "Connexion \u00e0 {0}...",
  "AddFirst": "Ajoutez un serveur avec son adresse IP ou son domaine.",
  "VoiceFolder": "Choisissez le dossier contenant {0}.",
  "AllFiles": "Tous les fichiers",
  "Backup": "Sauvegarde des comptes",
  "Checking": "V\u00e9rification du jeu dans {0}...",
  "FolderVerified": "Dossier du jeu : {0} (v\u00e9rifi\u00e9).",
  "ConnectTo": "Connexion \u00e0 {0}...",
  "GameExited": "Le jeu est ferm\u00e9.",
  "JoinFailed": "\u00c9chec de la connexion : {0}",
  "BadAddress": "Adresse IP ou domaine non valide : {0}",
  "VoicePath": "Fichier vocal : {0}",
  "NoServerInfo": "Le service de comptes ne r\u00e9pond pas. Le serveur est peut-\u00eatre hors ligne ou accepte un simple nom de joueur.",
  "SteamSetup": "Lancer via Steam",
  "SteamIntro": "Le bouton Jouer de Steam lance alors le jeu sur ce serveur avec votre compte, avec l'overlay Steam et le temps de jeu. Il ouvre cette fen\u00eatre, qui se connecte et se ferme quand le jeu se termine.",
  "SteamByHand": "\u00c0 la main",
  "SteamByHandHelp": "Dans Steam : Ring of Elysium > Propri\u00e9t\u00e9s > G\u00e9n\u00e9ral > Options de lancement, collez cette ligne. Jouer dans Steam rejoint alors le dernier serveur et le dernier compte utilis\u00e9s.",
  "SteamCopy": "Copier",
  "SteamAutomatic": "Automatique",
  "SteamAutomaticHelp": "Configurer place la ligne dans Steam pour vous, avec le serveur et le compte choisis ci-dessus. Steam doit \u00eatre ferm\u00e9 : join-roe-os.cmd demande, le ferme et peut le relancer.",
  "SteamSet": "Configurer le lancement via Steam",
  "SteamUse": "Utiliser le serveur et le compte choisis",
  "SteamOff": "D\u00e9sactiver",
  "SteamAutoStart": "Quand Steam lance le jeu, se connecter tout de suite (3 secondes pour annuler)"
},
  "es": {
  "Native": "Espa\u00f1ol",
  "Language": "Idioma",
  "Edition": "Edici\u00f3n 2022",
  "Subtitle": "Lanzador multijugador",
  "Server": "Servidor",
  "AddServer": "A\u00f1adir servidor...",
  "Account": "Cuenta",
  "NewAccount": "Crear una cuenta",
  "GameFolder": "Carpeta del juego",
  "Browse": "Examinar...",
  "Voice": "Chat de voz",
  "ChooseFolder": "Elegir carpeta...",
  "Advanced": "Ajustes avanzados",
  "Details": "Detalles",
  "HideDetails": "Ocultar detalles",
  "Region": "Regi\u00f3n",
  "Online": "En l\u00ednea",
  "Queued": "En cola",
  "Modes": "Cola por modo",
  "Games": "Partidas",
  "Offline": "Sin conexi\u00f3n",
  "ServerStatus": "Estado del servidor",
  "Play": "Jugar",
  "Running": "Juego en curso",
  "Joining": "Conectando...",
  "Ready": "Elige el servidor y la cuenta y pulsa Jugar.",
  "FwOn": "Activar reglas",
  "FwOff": "Desactivar reglas",
  "FwReset": "Restablecer reglas",
  "FwShow": "Ver reglas",
  "Export": "Exportar cuentas...",
  "Import": "Importar cuentas...",
  "Log": "Abrir registro",
  "Admin": "Abrir administraci\u00f3n",
  "BackupHelp": "Exporta las claves de tus cuentas para usarlas en otro PC. Guarda la copia en privado.",
  "AdminHelp": "Esta cuenta puede gestionar los bots, el emparejamiento y el estado del servidor desde el navegador.",
  "Cancel": "Cancelar",
  "Ok": "Aceptar",
  "Address": "Direcci\u00f3n del servidor (IP o dominio)",
  "AddressHelp": "Introduce la direcci\u00f3n del administrador, por ejemplo play.example.org.",
  "PlayerName": "Tu nombre (de 1 a 24 caracteres)",
  "VoiceOff": "Desactivado",
  "VoiceFileMissing": "Falta la DLL",
  "VoiceFileInvalid": "DLL no v\u00e1lida",
  "VoiceAvailable": "Listo",
  "VoiceActive": "Activo en el juego",
  "VoiceSessionOff": "Desactivado en esta partida",
  "VoiceMissing": "Elige la carpeta que contiene {0} o descarga el archivo desde {1}.",
  "VoiceReady": "El juego usa {0} mientras se ejecuta. Despu\u00e9s se restaura el archivo original.",
  "VoiceProblem": "{0} Elige la carpeta del archivo de voz.",
  "LocateGame": "Elige la carpeta de Ring of Elysium en Steam. Marca DirectX 12 para usar la carpeta XVersion.",
  "Dx11": "Versi\u00f3n de DirectX 11.",
  "Dx12": "DirectX 12 \u00b7 {0}",
  "FirewallPending": "Se te preguntar\u00e1 por las reglas del cortafuegos al jugar por primera vez.",
  "FirewallOn": "Las reglas del cortafuegos est\u00e1n activadas.",
  "FirewallOff": "Las reglas del cortafuegos est\u00e1n desactivadas.",
  "FirewallHelp": "Las reglas limitan el juego a servidores de confianza. Cambiar las direcciones permitidas requiere permisos de administrador.",
  "AskFirewall": "\u00bfLimitar las conexiones del juego a este PC y a los servidores en los que juegas? El juego tambi\u00e9n intenta conectarse a los antiguos servidores del editor. Cambiar estas reglas del Firewall de Windows requiere permisos de administrador. Puedes cambiar esta opci\u00f3n en Ajustes avanzados.",
  "ResetConfirm": "\u00bfEliminar las reglas del cortafuegos que han creado este lanzador y el del servidor para todas las carpetas del juego? Si las reglas est\u00e1n activadas, este lanzador solicitar\u00e1 nuevas reglas la pr\u00f3xima vez que te conectes.",
  "WithoutVoice": "\u00bfJugar sin chat de voz esta vez?",
  "CloseConfirm": "El lanzador se est\u00e1 conectando o espera a que termine el juego. \u00bfCerrarlo de todos modos? El archivo de voz original se restaurar\u00e1 la pr\u00f3xima vez si es necesario.",
  "Contacting": "Conectando con {0}...",
  "AddFirst": "A\u00f1ade un servidor con su direcci\u00f3n IP o dominio.",
  "VoiceFolder": "Elige la carpeta que contiene {0}.",
  "AllFiles": "Todos los archivos",
  "Backup": "Copia de cuentas",
  "Checking": "Comprobando el juego en {0}...",
  "FolderVerified": "Carpeta del juego: {0} (verificada).",
  "ConnectTo": "Conectando con {0}...",
  "GameExited": "El juego se ha cerrado.",
  "JoinFailed": "No se pudo conectar: {0}",
  "BadAddress": "Direcci\u00f3n IP o dominio no v\u00e1lido: {0}",
  "VoicePath": "Archivo de voz: {0}",
  "NoServerInfo": "El servicio de cuentas no responde. El servidor puede estar desconectado o aceptar solo un nombre de jugador.",
  "SteamSetup": "Iniciar desde Steam",
  "SteamIntro": "As\u00ed el bot\u00f3n Jugar de Steam inicia el juego en este servidor con tu cuenta, con el overlay de Steam y el tiempo de juego. Abre esta ventana, que se conecta y se cierra cuando el juego termina.",
  "SteamByHand": "A mano",
  "SteamByHandHelp": "En Steam: Ring of Elysium > Propiedades > General > Opciones de lanzamiento, pega esta l\u00ednea. Jugar en Steam se conecta entonces al \u00faltimo servidor y cuenta que usaste.",
  "SteamCopy": "Copiar",
  "SteamAutomatic": "Autom\u00e1tico",
  "SteamAutomaticHelp": "Configurar pone la l\u00ednea en Steam por ti, con el servidor y la cuenta elegidos arriba. Steam tiene que estar cerrado: join-roe-os.cmd pregunta, lo cierra y puede volver a abrirlo.",
  "SteamSet": "Configurar el inicio desde Steam",
  "SteamUse": "Usar el servidor y la cuenta elegidos",
  "SteamOff": "Desactivar",
  "SteamAutoStart": "Cuando Steam inicie el juego, conectar enseguida (3 segundos para cancelar)"
}
}
'@
    )
}
function Set-GuiTextResources($Window) {
    foreach ($entry in $gui.Strings.PSObject.Properties) {
        $Window.Resources['Ui.' + $entry.Name] = [string]$entry.Value
    }
}
function Set-GuiNote($Control, [string]$Key, [string]$Level = 'info', [object[]]$Values = @()) {
    $format = $gui.Strings.$Key
    if ($Key -eq 'VoiceMissing') {
        # Keep the link at the position chosen by the translation.
        $parts = $format -split '\{1\}', 2
        $link = [Windows.Documents.Hyperlink]::new([Windows.Documents.Run]::new('GitHub'))
        $link.NavigateUri = [uri]$voiceDownload
        $link.ToolTip = $link.NavigateUri.AbsoluteUri
        $link.Foreground = $gui.Window.FindResource('Link')
        $link.Add_Click({
            try { Start-Process -FilePath $this.NavigateUri.AbsoluteUri }
            catch { Show-GuiError $_ }
        })
        $Control.Inlines.Clear()
        $Control.Inlines.Add([Windows.Documents.Run]::new(($parts[0] -f $Values)))
        $Control.Inlines.Add($link)
        $Control.Inlines.Add([Windows.Documents.Run]::new(($parts[1] -f $Values)))
        $Control.Foreground = Get-Brush $Level
    } else {
        Set-Text $Control ($format -f $Values) $Level
    }
    $Control.Tag = @{ Key = $Key; Level = $Level; Values = $Values }
}
function Set-GuiLanguage([string]$Code) {
    $gui.Strings = $gui.Languages.$Code
    Set-GuiTextResources $gui.Window

    $account = $gui.C.AccountBox
    if ($account.Items.Count) {
        # The last item creates an account. Keep the selected account and its server session.
        $selected = $account.SelectedIndex
        $updating = $gui.Updating
        $gui.Updating = $true
        try {
            $account.Items[$account.Items.Count - 1] = $gui.Strings.NewAccount
            $account.SelectedIndex = $selected
        } finally { $gui.Updating = $updating }
    }
    Update-Controls
    foreach ($control in @($gui.C.GameNote, $gui.C.VoiceStatus, $gui.C.VoiceNote, $gui.C.StatusText)) {
        $note = $control.Tag
        if ($note) { Set-GuiNote $control $note.Key $note.Level $note.Values }
    }
    if ($gui.LastStats) { Set-GuiServerStatus $gui.LastStats.Text $gui.LastStats.Level }
    if ($gui.FirewallState) { $gui.C.FirewallText.Text = $gui.Strings.($gui.FirewallState) + ' ' + $gui.Strings.FirewallHelp }
}
function Initialize-GuiLanguage {
    $gui.Languages = Get-GuiLanguages
    $gui.LanguageFile = Join-Path $joinRoot 'ui-language.txt'
    $preferred = [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
    if (Test-Path -LiteralPath $gui.LanguageFile -PathType Leaf) {
        try { $saved = [IO.File]::ReadAllText($gui.LanguageFile).Trim(); if ($gui.Languages.PSObject.Properties[$saved]) { $preferred = $saved } } catch { }
    }
    $codes = @($gui.Languages.PSObject.Properties.Name)
    if ($preferred -notin $codes) { $preferred = 'en' }
    $box = $gui.C.LanguageBox
    foreach ($code in $codes) { [void]$box.Items.Add($gui.Languages.$code.Native) }
    $box.SelectedIndex = [array]::IndexOf($codes, $preferred)
    Set-GuiLanguage $preferred
    $box.Add_SelectionChanged({
        $index = $gui.C.LanguageBox.SelectedIndex
        if ($index -lt 0) { return }
        $code = @($gui.Languages.PSObject.Properties.Name)[$index]
        Set-GuiLanguage $code
        try {
            [void][IO.Directory]::CreateDirectory($joinRoot)
            [IO.File]::WriteAllText($gui.LanguageFile, $code)
        } catch { Write-GuiLog "Could not save the launcher language: $_" }
    })
}

function New-GuiWindow([string]$Xaml) {
    $window = [Windows.Markup.XamlReader]::Parse($Xaml)
    $window.Icon = $window.FindResource('LauncherIcon')
    return $window
}
# Each role pairs the launcher's color with the user's Windows contrast color.
function Get-GuiPalette([bool]$HighContrast) {
    $colors = [ordered]@{
        Ink = '#F2F0EC', 'WindowText'
        Secondary = '#BCB9B2', 'WindowText'
        Canvas = '#141414', 'Window'
        Panel = '#282828', 'Window'
        Field = '#202020', 'Window'
        IconBackground = '#292724', 'Window'
        Line = '#494949', 'WindowText'
        Accent = '#EDC366', 'WindowText'
        OnAccent = '#211A0B', 'Window'
        Hover = '#363636', 'Window'
        Pressed = '#414141', 'Window'
        Action = '#FF983F', 'Highlight'
        ActionText = '#201307', 'HighlightText'
        ActionHover = '#FFB065', 'Highlight'
        ActionPressed = '#DD792B', 'Highlight'
        Focus = '#FFF0C8', 'WindowText'
        Selection = '#805B26', 'Highlight'
        SelectedRow = '#493B26', 'Highlight'
        HighlightedRow = '#51422A', 'Highlight'
        SelectedText = '#F2F0EC', 'HighlightText'
        HoverLine = '#A59A86', 'WindowText'
        CheckOutline = '#888888', 'WindowText'
        MastheadLine = '#514737', 'WindowText'
        Subtitle = '#D2CFC8', 'WindowText'
        Badge = '#3F3726', 'Window'
        BadgeText = '#E9CC8D', 'WindowText'
        Title = '#F4CD7A', 'WindowText'
        LanguageLabel = '#C1BDB6', 'WindowText'
        TableHeader = '#303030', 'Window'
        TableHeading = '#E9C67C', 'WindowText'
        TableRow = '#232323', 'Window'
        TableLine = '#363636', 'WindowText'
        Available = '#E6B954', 'WindowText'
        Unavailable = '#858585', 'GrayText'
        Divider = '#353535', 'WindowText'
        Footer = '#1D1D1D', 'Window'
        Warning = '#FFBB75', 'WindowText'
        Error = '#FFA58A', 'WindowText'
        Link = '#EDC366', 'HotTrack'
    }
    foreach ($role in $colors.Keys) {
        $theme, $system = $colors[$role]
        $color = if ($HighContrast) { "{x:Static SystemColors.${system}Color}" } else { $theme }
        '<SolidColorBrush x:Key="{0}" Color="{1}"/>' -f $role, $color
    }
}
function Get-GuiTheme([bool]$HighContrast) {
    return @"
$((Get-GuiPalette $HighContrast) -join "`n")
    <DrawingImage x:Key="LauncherIcon">
      <DrawingImage.Drawing>
        <DrawingGroup>
          <GeometryDrawing Brush="{StaticResource IconBackground}">
            <GeometryDrawing.Geometry><RectangleGeometry Rect="0,0,32,32" RadiusX="5" RadiusY="5"/></GeometryDrawing.Geometry>
          </GeometryDrawing>
          <GeometryDrawing Brush="{StaticResource Accent}" Geometry="F0 M6,6 L21,6 26,11 26,15 20,20 12,20 12,26 6,26 Z M12,11 L19,11 21,13 19,15 12,15 Z"/>
          <GeometryDrawing Brush="{StaticResource Action}" Geometry="M15,21 L22,21 27,26 20,26 Z"/>
        </DrawingGroup>
      </DrawingImage.Drawing>
    </DrawingImage>
    <Style x:Key="LauncherButton" TargetType="ButtonBase">
      <Setter Property="Background" Value="{StaticResource Panel}"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="13,6"/>
      <Setter Property="MinHeight" Value="34"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ButtonBase">
            <Border CornerRadius="5" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="{StaticResource Hover}"/></Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="{StaticResource Pressed}"/></Trigger>
        <Trigger Property="IsKeyboardFocused" Value="True"><Setter Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
        <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="Button" BasedOn="{StaticResource LauncherButton}"/>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource LauncherButton}">
      <Setter Property="Background" Value="{StaticResource Action}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Action}"/>
      <Setter Property="Foreground" Value="{StaticResource ActionText}"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="{StaticResource ActionHover}"/></Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="{StaticResource ActionPressed}"/></Trigger>
        <Trigger Property="IsKeyboardFocused" Value="True"><Setter Property="BorderBrush" Value="{StaticResource Focus}"/></Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="TextBox">
          <Setter Property="Background" Value="{StaticResource Field}"/>
          <Setter Property="Foreground" Value="{StaticResource Ink}"/>
          <Setter Property="CaretBrush" Value="{StaticResource Accent}"/>
          <Setter Property="SelectionBrush" Value="{StaticResource Selection}"/>
          <Setter Property="SelectionTextBrush" Value="{StaticResource SelectedText}"/>
          <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
          <Setter Property="BorderThickness" Value="1"/>
          <Setter Property="Padding" Value="10,6"/>
          <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="TextBox">
          <Border x:Name="Shell" CornerRadius="5" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}">
            <ScrollViewer x:Name="PART_ContentHost" Focusable="False"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Shell" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
"@
}
function Get-GuiXaml([bool]$HighContrast = [Windows.SystemParameters]::HighContrast) {
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Ring of Elysium Launcher" Width="680" SizeToContent="Height" ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen"
        MaxHeight="{Binding Source={x:Static SystemParameters.WorkArea}, Path=Height}"
        MaxWidth="{Binding Source={x:Static SystemParameters.WorkArea}, Path=Width}"
        Background="{DynamicResource Canvas}" Foreground="{DynamicResource Ink}" FontFamily="Segoe UI" FontSize="13"
        UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
$(Get-GuiTheme $HighContrast)
    <Style x:Key="DetailsToggle" TargetType="ToggleButton" BasedOn="{StaticResource LauncherButton}">
      <Style.Triggers>
        <Trigger Property="IsChecked" Value="True"><Setter Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBoxItem">
        <Border x:Name="Row" Background="Transparent" Padding="{TemplateBinding Padding}" CornerRadius="3">
          <ContentPresenter/>
        </Border>
        <ControlTemplate.Triggers>
            <Trigger Property="IsSelected" Value="True"><Setter TargetName="Row" Property="Background" Value="{StaticResource SelectedRow}"/><Setter Property="Foreground" Value="{StaticResource SelectedText}"/></Trigger>
            <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Row" Property="Background" Value="{StaticResource HighlightedRow}"/><Setter Property="Foreground" Value="{StaticResource SelectedText}"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="MaxDropDownHeight" Value="260"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBox">
        <Grid>
          <ToggleButton Focusable="False" ClickMode="Press" IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
            <ToggleButton.Template><ControlTemplate TargetType="ToggleButton">
              <Border x:Name="Field" Background="{StaticResource Field}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="5"/>
              <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Field" Property="BorderBrush" Value="{StaticResource HoverLine}"/></Trigger>
            <Trigger Property="IsChecked" Value="True"><Setter TargetName="Field" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate></ToggleButton.Template>
          </ToggleButton>
          <TextBlock Margin="11,0,30,0" VerticalAlignment="Center" Text="{TemplateBinding SelectionBoxItem}" TextTrimming="CharacterEllipsis" IsHitTestVisible="False"/>
          <Path Margin="0,0,12,0" VerticalAlignment="Center" HorizontalAlignment="Right" Stroke="{StaticResource Secondary}" StrokeThickness="1.4" Data="M0,0 L4,4 8,0" IsHitTestVisible="False"/>
          <Border x:Name="FocusRing" BorderThickness="1" CornerRadius="5" IsHitTestVisible="False"/>
          <Popup x:Name="PART_Popup" IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom" AllowsTransparency="True" Focusable="False">
            <Border Background="{StaticResource Panel}" MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}" MaxWidth="{Binding Source={x:Static SystemParameters.WorkArea}, Path=Width}"
                    MaxHeight="{TemplateBinding MaxDropDownHeight}" BorderThickness="1" BorderBrush="{StaticResource Line}" CornerRadius="5" Margin="0,3,0,0" Padding="3">
              <ScrollViewer VerticalScrollBarVisibility="Auto" CanContentScroll="True"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/></ScrollViewer>
            </Border>
          </Popup>
        </Grid>
        <ControlTemplate.Triggers>
            <Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="FocusRing" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.50"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox">
        <DockPanel Background="Transparent">
          <Border x:Name="Box" Height="16" Width="16" CornerRadius="3" Background="{StaticResource Field}" BorderBrush="{StaticResource CheckOutline}" BorderThickness="1" VerticalAlignment="Center">
            <Path x:Name="Tick" Visibility="Hidden" Data="M0,4 L3,7 9,0" StrokeThickness="1.7" Stroke="{StaticResource OnAccent}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ContentPresenter Margin="{TemplateBinding Padding}" VerticalAlignment="Center"/>
        </DockPanel>
        <ControlTemplate.Triggers>
            <Trigger Property="IsChecked" Value="True"><Setter TargetName="Tick" Property="Visibility" Value="Visible"/></Trigger>
            <Trigger Property="IsChecked" Value="True"><Setter TargetName="Box" Property="Background" Value="{StaticResource Accent}"/></Trigger>
            <Trigger Property="IsChecked" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource Focus}"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.50"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="Expander">
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Expander">
        <StackPanel>
          <ToggleButton HorizontalAlignment="Left" Content="{TemplateBinding Header}" IsChecked="{Binding IsExpanded, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}" FontWeight="SemiBold" Foreground="{StaticResource Secondary}">
            <ToggleButton.FocusVisualStyle>
              <Style TargetType="Control">
                <Setter Property="Template"><Setter.Value>
                  <ControlTemplate TargetType="Control">
                    <Border Height="1" Margin="16,0,8,3" VerticalAlignment="Bottom" Background="{StaticResource Accent}"/>
                  </ControlTemplate>
                </Setter.Value></Setter>
              </Style>
            </ToggleButton.FocusVisualStyle>
            <ToggleButton.Template><ControlTemplate TargetType="ToggleButton">
              <Border Padding="0,6,8,6" Background="Transparent">
                <StackPanel Orientation="Horizontal">
                  <Path x:Name="Arrow" Data="M0,0 L4,4 0,8" Stroke="{StaticResource Accent}" StrokeThickness="1.5" Margin="2,0,10,0" VerticalAlignment="Center" RenderTransformOrigin="0.5,0.5"/>
                  <ContentPresenter x:Name="Caption"/>
                </StackPanel>
              </Border>
              <ControlTemplate.Triggers>
                <Trigger Property="IsChecked" Value="True"><Setter TargetName="Arrow" Property="RenderTransform"><Setter.Value><RotateTransform Angle="90"/></Setter.Value></Setter></Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate></ToggleButton.Template>
          </ToggleButton>
          <ContentPresenter x:Name="Body" Visibility="Collapsed"/>
        </StackPanel>
        <ControlTemplate.Triggers>
            <Trigger Property="IsExpanded" Value="True"><Setter TargetName="Body" Property="Visibility" Value="Visible"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Label" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,7"/>
    </Style>
  </Window.Resources>
  <ScrollViewer Background="{StaticResource Canvas}" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Focusable="False">
    <StackPanel>
      <Border Background="{StaticResource Field}" BorderBrush="{StaticResource MastheadLine}" BorderThickness="0,0,0,1" Padding="24,18">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel Margin="0,0,16,0" VerticalAlignment="Center">
            <WrapPanel VerticalAlignment="Center">
              <TextBlock Text="{DynamicResource Ui.Subtitle}" FontWeight="SemiBold" FontSize="12" Foreground="{StaticResource Subtitle}" VerticalAlignment="Center"/>
              <Border Background="{StaticResource Badge}" CornerRadius="3" Padding="6,1" Margin="9,0,0,0" VerticalAlignment="Center">
                <TextBlock Text="{DynamicResource Ui.Edition}" FontSize="11" Foreground="{StaticResource BadgeText}"/>
              </Border>
            </WrapPanel>
            <TextBlock Text="Ring of Elysium" FontFamily="Bahnschrift, Segoe UI" FontSize="36" FontWeight="SemiBold"
                       Foreground="{StaticResource Title}" TextWrapping="Wrap" Margin="-1,2,0,-2"/>
          </StackPanel>
          <StackPanel Grid.Column="1" VerticalAlignment="Center" Width="138">
            <TextBlock x:Name="LanguageLabel" Text="{DynamicResource Ui.Language}" FontSize="12" Margin="0,0,0,4" Foreground="{StaticResource LanguageLabel}"/>
            <ComboBox x:Name="LanguageBox" MinHeight="30" AutomationProperties.LabeledBy="{Binding ElementName=LanguageLabel}"/>
          </StackPanel>
        </Grid>
      </Border>
      <StackPanel Margin="24,15,24,11">
        <Border Padding="0,0,0,12">
          <StackPanel>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="1.3*"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <StackPanel>
                <TextBlock Text="{DynamicResource Ui.Server}" Style="{StaticResource Label}"/>
                <DockPanel>
                  <Button x:Name="AddServerButton" DockPanel.Dock="Right" Margin="6,0,0,0" Content="{DynamicResource Ui.AddServer}"/>
                  <ComboBox x:Name="ServerBox" AutomationProperties.Name="{DynamicResource Ui.Server}" ToolTip="{Binding SelectedItem, RelativeSource={RelativeSource Self}}"/>
                </DockPanel>
              </StackPanel>
              <StackPanel Grid.Column="2">
                <TextBlock Text="{DynamicResource Ui.Account}" Style="{StaticResource Label}"/>
                <ComboBox x:Name="AccountBox" AutomationProperties.Name="{DynamicResource Ui.Account}" ToolTip="{Binding SelectedItem, RelativeSource={RelativeSource Self}}"/>
              </StackPanel>
            </Grid>
            <ItemsControl x:Name="RegionTable" Margin="0,10,0,0" Focusable="False" IsTabStop="False"
                         AutomationProperties.Name="{DynamicResource Ui.ServerStatus}">
              <ItemsControl.Resources>
                <Style x:Key="StatCell" TargetType="TextBlock">
                  <Setter Property="Margin" Value="8,0"/>
                  <Setter Property="VerticalAlignment" Value="Center"/>
                  <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
                  <Setter Property="ToolTip" Value="{Binding Text, RelativeSource={RelativeSource Self}}"/>
                </Style>
              </ItemsControl.Resources>
              <ItemsControl.Style>
                <Style TargetType="ItemsControl"><Style.Triggers>
                  <Trigger Property="HasItems" Value="False"><Setter Property="Visibility" Value="Collapsed"/></Trigger>
                </Style.Triggers></Style>
              </ItemsControl.Style>
              <ItemsControl.Template>
                <ControlTemplate TargetType="ItemsControl">
                  <StackPanel>
                    <Grid Height="26" Background="{StaticResource TableHeader}" TextElement.Foreground="{StaticResource TableHeading}"
                          TextElement.FontWeight="SemiBold">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="2*"/><ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/><ColumnDefinition Width="3*"/><ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <TextBlock Grid.Column="0" Style="{StaticResource StatCell}" Text="{DynamicResource Ui.Region}"/>
                      <TextBlock Grid.Column="1" Style="{StaticResource StatCell}" Text="{DynamicResource Ui.Online}"/>
                      <TextBlock Grid.Column="2" Style="{StaticResource StatCell}" Text="{DynamicResource Ui.Queued}"/>
                      <TextBlock Grid.Column="3" Style="{StaticResource StatCell}" Text="{DynamicResource Ui.Modes}"/>
                      <TextBlock Grid.Column="4" Style="{StaticResource StatCell}" Text="{DynamicResource Ui.Games}"/>
                    </Grid>
                    <ItemsPresenter/>
                  </StackPanel>
                </ControlTemplate>
              </ItemsControl.Template>
              <ItemsControl.ItemTemplate>
                <DataTemplate>
                  <Border Height="27" Background="{StaticResource TableRow}" BorderBrush="{StaticResource TableLine}" BorderThickness="0,0,0,1">
                    <Grid x:Name="Row">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="2*"/><ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/><ColumnDefinition Width="3*"/><ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <DockPanel>
                        <Ellipse x:Name="Availability" Width="7" Height="7" Margin="9,0,0,0" VerticalAlignment="Center" Fill="{StaticResource Available}" IsHitTestVisible="False"/>
                        <TextBlock Style="{StaticResource StatCell}" Text="{Binding Region}"/>
                      </DockPanel>
                      <TextBlock Grid.Column="1" Style="{StaticResource StatCell}" Text="{Binding Online}"/>
                      <TextBlock Grid.Column="2" Style="{StaticResource StatCell}" Text="{Binding Queued}"/>
                      <TextBlock Grid.Column="3" Style="{StaticResource StatCell}" Text="{Binding Modes}"/>
                      <TextBlock Grid.Column="4" Style="{StaticResource StatCell}" Text="{Binding Games}"/>
                    </Grid>
                  </Border>
                  <DataTemplate.Triggers>
                    <DataTrigger Binding="{Binding Offline}" Value="True">
                      <Setter TargetName="Row" Property="TextElement.Foreground" Value="{StaticResource Secondary}"/>
                      <Setter TargetName="Availability" Property="Fill" Value="{StaticResource Unavailable}"/>
                    </DataTrigger>
                  </DataTemplate.Triggers>
                </DataTemplate>
              </ItemsControl.ItemTemplate>
            </ItemsControl>
            <TextBlock x:Name="ServerStats" Margin="0,6,0,0" TextWrapping="Wrap">
              <TextBlock.Style>
                <Style TargetType="TextBlock"><Style.Triggers>
                  <Trigger Property="Text" Value=""><Setter Property="Visibility" Value="Collapsed"/></Trigger>
                </Style.Triggers></Style>
              </TextBlock.Style>
            </TextBlock>
            <Border BorderBrush="{StaticResource Divider}" BorderThickness="0,1,0,0" Margin="0,14,0,0" Padding="0,13,0,0">
              <StackPanel>
                <DockPanel Margin="0,0,0,7">
                  <CheckBox x:Name="Dx12Box" DockPanel.Dock="Right" Padding="7,0,0,0" VerticalAlignment="Center" Content="DirectX 12"/>
                  <TextBlock Text="{DynamicResource Ui.GameFolder}" FontWeight="SemiBold"/>
                </DockPanel>
                <DockPanel>
                  <Button x:Name="BrowseButton" DockPanel.Dock="Right" MinWidth="94" Margin="7,0,0,0" Content="{DynamicResource Ui.Browse}"/>
                  <TextBox x:Name="GameBox" IsReadOnly="True" MinHeight="35" AutomationProperties.Name="{DynamicResource Ui.GameFolder}"/>
                </DockPanel>
                <TextBlock x:Name="GameNote" TextWrapping="Wrap" Margin="0,5,0,0"/>
              </StackPanel>
            </Border>
            <Border BorderBrush="{StaticResource Divider}" BorderThickness="0,1,0,0" Margin="0,13,0,0" Padding="0,12,0,0">
              <StackPanel>
                <DockPanel>
                  <Button x:Name="VoiceButton" DockPanel.Dock="Right" Margin="16,0,0,0" VerticalAlignment="Center" Content="{DynamicResource Ui.ChooseFolder}"/>
                  <DockPanel VerticalAlignment="Center">
                    <CheckBox x:Name="VoiceBox" VerticalAlignment="Center" Padding="0" AutomationProperties.Name="{DynamicResource Ui.Voice}"/>
                    <TextBlock x:Name="VoiceLabel" Margin="8,0,0,0" Text="{DynamicResource Ui.Voice}" FontWeight="SemiBold" IsEnabled="{Binding IsEnabled, ElementName=VoiceBox}">
                      <TextBlock.Style><Style TargetType="TextBlock"><Style.Triggers>
                        <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
                      </Style.Triggers></Style></TextBlock.Style>
                    </TextBlock>
                    <TextBlock x:Name="VoiceStatus" Margin="12,0,0,0" TextWrapping="Wrap" VerticalAlignment="Center"/>
                  </DockPanel>
                </DockPanel>
                <TextBlock x:Name="VoiceNote" Margin="0,4,0,0" TextWrapping="Wrap">
                  <TextBlock.Style><Style TargetType="TextBlock"><Style.Triggers>
                    <Trigger Property="Tag" Value="{x:Null}"><Setter Property="Visibility" Value="Collapsed"/></Trigger>
                  </Style.Triggers></Style></TextBlock.Style>
                </TextBlock>
              </StackPanel>
            </Border>
          </StackPanel>
        </Border>
        <Expander x:Name="SteamSetupBox" Margin="0,0,0,10" Header="{DynamicResource Ui.SteamSetup}" IsExpanded="False">
          <StackPanel Margin="0,6,0,0">
            <TextBlock TextWrapping="Wrap" Text="{DynamicResource Ui.SteamIntro}"/>
            <TextBlock Margin="0,8,0,0" FontWeight="SemiBold" Text="{DynamicResource Ui.SteamByHand}"/>
            <TextBlock Margin="0,2,0,0" TextWrapping="Wrap" Text="{DynamicResource Ui.SteamByHandHelp}"/>
            <DockPanel Margin="0,6,0,0">
              <Button x:Name="SteamCopyButton" DockPanel.Dock="Right" Margin="7,0,0,0" Content="{DynamicResource Ui.SteamCopy}"/>
              <TextBox x:Name="SteamLineBox" IsReadOnly="True" FontFamily="Consolas" AutomationProperties.Name="{DynamicResource Ui.SteamByHand}"/>
            </DockPanel>
            <TextBlock Margin="0,10,0,0" FontWeight="SemiBold" Text="{DynamicResource Ui.SteamAutomatic}"/>
            <TextBlock Margin="0,2,0,0" TextWrapping="Wrap" Text="{DynamicResource Ui.SteamAutomaticHelp}"/>
            <TextBlock x:Name="SteamText" Margin="0,4,0,0" TextWrapping="Wrap"/>
            <WrapPanel Margin="0,6,0,0">
              <Button x:Name="SteamSetButton" Margin="0,0,6,6" Content="{DynamicResource Ui.SteamSet}"/>
              <Button x:Name="SteamOffButton" Margin="0,0,6,6" Content="{DynamicResource Ui.SteamOff}" Visibility="Collapsed"/>
            </WrapPanel>
            <DockPanel Margin="0,0,0,6">
              <CheckBox x:Name="SteamAutoBox" VerticalAlignment="Center" Padding="0" AutomationProperties.Name="{DynamicResource Ui.SteamAutoStart}"/>
              <TextBlock x:Name="SteamAutoLabel" Margin="8,0,0,0" TextWrapping="Wrap" Text="{DynamicResource Ui.SteamAutoStart}" IsEnabled="{Binding IsEnabled, ElementName=SteamAutoBox}">
                <TextBlock.Style><Style TargetType="TextBlock"><Style.Triggers>
                  <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
                </Style.Triggers></Style></TextBlock.Style>
              </TextBlock>
            </DockPanel>
          </StackPanel>
        </Expander>
        <Expander x:Name="AdvancedBox" Header="{DynamicResource Ui.Advanced}">
      <StackPanel Margin="0,6,0,0">
        <TextBlock x:Name="FirewallText" TextWrapping="Wrap"/>
        <WrapPanel Margin="0,6,0,0">
          <Button x:Name="FirewallOnButton" Margin="0,0,6,6" Content="{DynamicResource Ui.FwOn}"/>
          <Button x:Name="FirewallOffButton" Margin="0,0,6,6" Content="{DynamicResource Ui.FwOff}"/>
          <Button x:Name="FirewallResetButton" Margin="0,0,6,6" Content="{DynamicResource Ui.FwReset}"/>
          <Button x:Name="FirewallShowButton" Margin="0,0,6,6" Content="{DynamicResource Ui.FwShow}"/>
        </WrapPanel>
        <TextBlock Margin="0,6,0,0" TextWrapping="Wrap" Text="{DynamicResource Ui.BackupHelp}"/>
        <WrapPanel Margin="0,6,0,0">
          <Button x:Name="ExportButton" Margin="0,0,6,6" Content="{DynamicResource Ui.Export}"/>
          <Button x:Name="ImportButton" Margin="0,0,6,6" Content="{DynamicResource Ui.Import}"/>
          <Button x:Name="LogButton" Margin="0,0,6,6" Content="{DynamicResource Ui.Log}"/>
        </WrapPanel>
        <StackPanel x:Name="AdminPanel" Margin="0,6,0,0" Visibility="Collapsed">
          <TextBlock TextWrapping="Wrap" Text="{DynamicResource Ui.AdminHelp}"/>
          <WrapPanel Margin="0,6,0,0">
            <Button x:Name="AdminButton" Margin="0,0,6,6" Content="{DynamicResource Ui.Admin}"/>
          </WrapPanel>
        </StackPanel>
      </StackPanel>
        </Expander>
      </StackPanel>
      <Border BorderBrush="{StaticResource Divider}" BorderThickness="0,1,0,0" Background="{StaticResource Footer}" Padding="24,12">
        <StackPanel>
        <Border x:Name="SteamBar" Margin="0,0,0,10" Padding="10,7" CornerRadius="5" BorderThickness="1" BorderBrush="{StaticResource Accent}" Background="{StaticResource Panel}" Visibility="Collapsed">
          <DockPanel>
            <Button x:Name="SteamCancelButton" DockPanel.Dock="Right" Margin="8,0,0,0" Content="{DynamicResource Ui.Cancel}" Visibility="Collapsed"/>
            <TextBlock x:Name="SteamBarText" VerticalAlignment="Center" TextWrapping="Wrap"/>
          </DockPanel>
        </Border>
        <DockPanel>
          <Button x:Name="PlayButton" Style="{StaticResource Primary}" DockPanel.Dock="Right" MinWidth="124" MinHeight="38" FontSize="15" Content="{DynamicResource Ui.Play}"/>
          <ToggleButton x:Name="DetailsButton" DockPanel.Dock="Right" Margin="0,0,10,0" VerticalAlignment="Center" Padding="10,4" MinHeight="30">
            <ToggleButton.Style>
              <Style TargetType="ToggleButton" BasedOn="{StaticResource DetailsToggle}">
                <Setter Property="Content" Value="{DynamicResource Ui.Details}"/>
                <Style.Triggers>
                  <Trigger Property="IsChecked" Value="True"><Setter Property="Content" Value="{DynamicResource Ui.HideDetails}"/></Trigger>
                </Style.Triggers>
              </Style>
            </ToggleButton.Style>
          </ToggleButton>
                    <TextBlock x:Name="StatusText" VerticalAlignment="Center" Margin="0,0,20,0" TextWrapping="Wrap"/>
        </DockPanel>
        <TextBox x:Name="DetailsBox" Height="134" Margin="0,9,0,0" VerticalContentAlignment="Top"
                 AutomationProperties.Name="{DynamicResource Ui.Details}" IsReadOnly="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto" FontFamily="Consolas">
          <TextBox.Style>
            <Style TargetType="TextBox" BasedOn="{StaticResource {x:Type TextBox}}">
              <Setter Property="Visibility" Value="Collapsed"/>
              <Style.Triggers>
                <DataTrigger Binding="{Binding IsChecked, ElementName=DetailsButton}" Value="True">
                  <Setter Property="Visibility" Value="Visible"/>
                </DataTrigger>
              </Style.Triggers>
            </Style>
          </TextBox.Style>
        </TextBox>
        </StackPanel>
      </Border>
    </StackPanel>
  </ScrollViewer>
</Window>
"@
}
function Get-GuiControlNames {
    return @('LanguageBox', 'ServerBox', 'AddServerButton', 'RegionTable', 'ServerStats', 'AccountBox', 'GameBox', 'BrowseButton', 'Dx12Box', 'GameNote', 'VoiceBox', 'VoiceButton', 'VoiceNote',
        'PlayButton', 'StatusText', 'DetailsButton', 'DetailsBox', 'AdvancedBox', 'FirewallText', 'FirewallOnButton', 'FirewallOffButton', 'FirewallResetButton',
        'FirewallShowButton', 'ExportButton', 'ImportButton', 'LogButton', 'AdminPanel', 'AdminButton', 'VoiceLabel', 'VoiceStatus', 'SteamBar', 'SteamBarText',
        'SteamCancelButton', 'SteamText', 'SteamSetButton', 'SteamOffButton', 'SteamAutoBox', 'SteamSetupBox', 'SteamLineBox', 'SteamCopyButton', 'SteamAutoLabel')
}
function Get-InputXaml([bool]$HighContrast = [Windows.SystemParameters]::HighContrast) {
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Ring of Elysium Launcher" Width="465" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        MaxHeight="{Binding Source={x:Static SystemParameters.WorkArea}, Path=Height}"
        MaxWidth="{Binding Source={x:Static SystemParameters.WorkArea}, Path=Width}"
        Background="{DynamicResource Canvas}" Foreground="{DynamicResource Ink}" FontFamily="Segoe UI" FontSize="13"
        UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
$(Get-GuiTheme $HighContrast)
  </Window.Resources>
  <ScrollViewer Background="{StaticResource Canvas}" VerticalScrollBarVisibility="Auto" Focusable="False">
    <StackPanel>
      <StackPanel Margin="20,19,20,0">
        <TextBlock x:Name="PromptText" FontWeight="SemiBold" FontSize="20" TextWrapping="Wrap"/>
      </StackPanel>
      <StackPanel Margin="20,8,20,18">
        <TextBlock x:Name="ContextText" Margin="0,0,0,7" Foreground="{StaticResource Secondary}" TextWrapping="Wrap"/>
        <TextBox x:Name="AnswerBox" Margin="0,7,0,0" MinHeight="36" AutomationProperties.LabeledBy="{Binding ElementName=PromptText}"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
          <Button x:Name="OkButton" Width="84" Style="{StaticResource Primary}" IsDefault="True" Content="{DynamicResource Ui.Ok}"/>
          <Button Width="84" Margin="8,0,0,0" IsCancel="True" Content="{DynamicResource Ui.Cancel}"/>
        </StackPanel>
      </StackPanel>
    </StackPanel>
  </ScrollViewer>
</Window>
"@
}
function Get-GuiLogPath { return Join-Path (Join-Path $env:APPDATA 'roe-join') 'gui.log' }
function Write-GuiLog([string]$Text) {
    try {
        $path = Get-GuiLogPath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        [IO.File]::AppendAllText($path, ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Text) + "`r`n")
    } catch { }
}
function Get-Brush([string]$Level) {
    $role = switch ($Level) {
        'error' { 'Error' }
        'warn'  { 'Warning' }
        'muted' { 'Secondary' }
        default { 'Ink' }
    }
    return $gui.Window.FindResource($role)
}
function Set-Text($Control, [string]$Text, [string]$Level = 'info') {
    $Control.Tag = $null
    $Control.Text = $Text
    $Control.Foreground = Get-Brush $Level
}
# Render the worker's existing status text. Preserve notices and older servers' INFO replies.
function Set-GuiServerStatus([string]$Text, [string]$Level = 'info') {
    $gui.LastStats = @{ Text = $Text; Level = $Level }
    if ($Text -match '^Contacting (.+) \.\.\.$') { $Text = $gui.Strings.Contacting -f $Matches[1] }
    elseif ($Text -eq 'Add the server the host gave you: Add server... (its IP address or domain).') { $Text = $gui.Strings.AddFirst }
    elseif ($Text -eq 'No answer from the account service: the server may be down, or it has no accounts (then it takes a plain name).') { $Text = $gui.Strings.NoServerInfo }
    $notes = New-Object 'System.Collections.Generic.List[string]'
    $regionPattern = '^(?<region>.+ \([a-z]{1,12}\)): (?:offline|(?<online>\d+) online, (?<queued>\d+) searching(?: \((?<modes>[^)]*)\))?, (?<games>\d+) match(?:es)?)(?:\.(?: (?<notice>.*))?)?$'
    $rows = @(foreach ($line in ($Text -split "\r?\n")) {
        # Periodic game updates prefix the first region with a timestamp and "On the server now:".
        $prefix = [regex]::Match($line, '^(?:\[(?<time>\d{2}:\d{2})\] )?On the server now: ')
        $region = [regex]::Match($line.Substring($prefix.Length), $regionPattern)
        if (-not $region.Success) {
            $notes.Add($line)
            continue
        }
        if ($prefix.Groups['time'].Success) { $notes.Add('[' + $prefix.Groups['time'].Value + ']') }
        if ($region.Groups['notice'].Success) { $notes.Add($region.Groups['notice'].Value) }
        $offline = -not $region.Groups['online'].Success
        [pscustomobject]@{
            Region  = $region.Groups['region'].Value
            Online  = if ($offline) { $gui.Strings.Offline } else { $region.Groups['online'].Value }
            Queued  = if ($offline) { '-' } else { $region.Groups['queued'].Value }
            Modes   = if ($offline) { '-' } else { $region.Groups['modes'].Value }
            Games   = if ($offline) { '-' } else { $region.Groups['games'].Value }
            Offline = $offline
        }
    })
    $gui.C.RegionTable.ItemsSource = $rows
    Set-Text $gui.C.ServerStats ($notes -join "`n") $Level
}
# A line for the player: the status, the details and the log.
function Add-Line([string]$Text, [string]$Level = 'info', [string]$DisplayKey = '', [object[]]$Values = @()) {
    if ($Level -ne 'info') { Write-GuiLog "[$Level] $Text" } else { Write-GuiLog $Text }
    $gui.C.DetailsBox.AppendText("$Text`r`n")
    $gui.C.DetailsBox.ScrollToEnd()
    [void]$gui.Recent.Add($Text)
    while ($gui.Recent.Count -gt 12) { $gui.Recent.RemoveAt(0) }
    if ($DisplayKey) { Set-GuiNote $gui.C.StatusText $DisplayKey $Level $Values }
    else { Set-Text $gui.C.StatusText $Text $Level }
}
function Show-GuiError($Record, [string]$Prefix = '') {
    Write-GuiLog "$($Record | Out-String)$($Record.ScriptStackTrace)".Trim()
    Add-Line ($Prefix + (Get-ErrorMessage $Record)) 'error'
}
function Show-Message([string]$Text, [string]$Buttons = 'OK', [string]$Icon = 'Information', [string]$Default = 'OK') {
    return "$([Windows.MessageBox]::Show($gui.Window, $Text, 'Ring of Elysium Launcher', $Buttons, $Icon, $Default))"
}
# A question with a text field; $null when cancelled.
function Show-InputDialog([string]$Prompt, [string]$Context, [string]$Default) {
    $dialog = New-GuiWindow (Get-InputXaml)
    Set-GuiTextResources $dialog
    if ($Prompt -eq 'Your name (1 to 24 characters)') { $Prompt = $gui.Strings.PlayerName }
    if ($gui.Window -and $gui.Window.IsLoaded) { $dialog.Owner = $gui.Window } else { $dialog.WindowStartupLocation = 'CenterScreen' }
    $contextText = $dialog.FindName('ContextText')
    $contextText.Text = $Context
    if (-not $Context) { $contextText.Visibility = 'Collapsed' }
    $dialog.FindName('PromptText').Text = "${Prompt}:"
    $box = $dialog.FindName('AnswerBox')
    $box.Text = $Default
    $dialog.FindName('OkButton').Add_Click({ [Windows.Window]::GetWindow($this).DialogResult = $true })
    $dialog.Add_ContentRendered({ $box = $this.FindName('AnswerBox'); [void]$box.Focus(); $box.SelectAll() })
    if (-not $dialog.ShowDialog()) { return $null }
    return $box.Text
}
# A question of the worker (join-roe-os.cmd's Ask): yes/no ones as a message box, others with a text field.
function Show-Question($Request) {
    try {
        $context = (@($gui.Recent) | Select-Object -Last 8) -join "`n"
        $gui.Recent.Clear()
        if ($Request.Question -match '^(.*?)\s*\(y/n\)$') {
            $text = (@($context, $Matches[1]) | Where-Object { $_ }) -join "`n`n"
            $default = if ($Request.Default -match '^[yY]') { 'Yes' } else { 'No' }
            $Request.Answer = if ((Show-Message $text 'YesNo' 'Question' $default) -eq 'Yes') { 'y' } else { 'n' }
        } else {
            $answer = Show-InputDialog $Request.Question $context $Request.Default
            if ($null -eq $answer) { $Request.Cancelled = $true } else { $Request.Answer = $answer }
        }
    } catch {
        $Request.Cancelled = $true
        Show-GuiError $_
    } finally {
        $Request.Done.Set()
    }
}
# The events of the worker, on the window's thread.
function Receive-GuiEvents {
    if ($gui.Draining) { return }
    $gui.Draining = $true
    try {
        $item = $null
        while ($sync.Events.TryDequeue([ref]$item)) {
            switch ($item.Kind) {
                'line' { Add-Line $item.Data.Text $item.Data.Level }
                'ask' { Show-Question $item.Data }
                'front' {
                    if ($gui.Window.WindowState -eq 'Minimized') { $gui.Window.WindowState = 'Normal' }
                    [void]$gui.Window.Activate()
                }
                'stats' { Set-GuiServerStatus $item.Data }
                'game' {
                    $gui.GameRunning = $true
                    Update-Controls
                    if ($item.Data) {
                        Set-GuiNote $gui.C.VoiceStatus VoiceActive
                        Add-Line 'Game running. This window puts the original voice DLL back when the game exits.'
                    } else {
                        Set-GuiNote $gui.C.VoiceStatus VoiceSessionOff muted
                        Add-Line 'Game running.'
                    }
                    Set-Text $gui.C.VoiceNote ''
                }
                'done' { Complete-Work $item.Data }
                'side-done' { Complete-SideWork $item.Data }
            }
        }
    } catch {
        Show-GuiError $_
    } finally {
        $gui.Draining = $false
    }
}
# The worker: a runspace with join-roe-os.cmd and this file's functions, for one piece of work at a time.
function New-Worker([string]$Code) {
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = 'MTA'
    $runspace.ThreadOptions = 'ReuseThread'
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('sync', $sync)
    $worker = [powershell]::Create()
    $worker.Runspace = $runspace
    [void]$worker.AddScript($Code).Invoke()
    if ($worker.Streams.Error.Count) { throw "The background part could not load join-roe-os.cmd: $($worker.Streams.Error[0])" }
    $worker.Commands.Clear()
    return $worker
}
# Queues work for the worker; OnDone gets its done event on the window's thread. A newer request
# for the server line replaces one still waiting.
function Start-Work([string]$Command, [hashtable]$Arguments, [scriptblock]$OnDone) {
    if ($Command -eq 'Invoke-ServerJob') { foreach ($queued in @($gui.Queue | Where-Object { $_.Command -eq $Command })) { $gui.Queue.Remove($queued) } }
    [void]$gui.Queue.Add([pscustomobject]@{ Command = $Command; Arguments = $Arguments; OnDone = $OnDone })
    Start-NextWork
}
# Work next to the worker's (which waits for the game while it runs): the admin page. One at a
# time, in a second runspace made at its first use.
function Start-SideWork([string]$Command, [hashtable]$Arguments, [scriptblock]$OnDone) {
    if ($gui.SideJob) { return }
    if (-not $gui.SideWorker) { $gui.SideWorker = New-Worker $gui.Code }
    $gui.SideJob = $Command
    $gui.SideOnDone = $OnDone
    $gui.SideWorker.Commands.Clear()
    [void]$gui.SideWorker.AddCommand('Invoke-Work').AddParameter('Command', $Command).AddParameter('Arguments', $Arguments).AddParameter('Event', 'side-done')
    $gui.SideHandle = $gui.SideWorker.BeginInvoke()
    Update-Controls
}
function Complete-SideWork($Done) {
    try { [void]$gui.SideWorker.EndInvoke($gui.SideHandle) } catch { }
    $gui.SideWorker.Streams.ClearStreams()
    $onDone = $gui.SideOnDone
    $gui.SideJob = $null
    $gui.SideOnDone = $null
    if (-not $Done.Ok -and $Done.Details) { Write-GuiLog $Done.Details }
    try {
        if ($onDone) { & $onDone $Done } elseif (-not $Done.Ok) { Add-Line $Done.Message 'error' }
    } catch { Show-GuiError $_ }
    Update-Controls
}
function Start-NextWork {
    if (-not $gui.Job -and $gui.Queue.Count) {
        $next = $gui.Queue[0]
        $gui.Queue.RemoveAt(0)
        $gui.Job = $next.Command
        $gui.OnDone = $next.OnDone
        $gui.Worker.Commands.Clear()
        [void]$gui.Worker.AddCommand('Invoke-Work').AddParameter('Command', $next.Command).AddParameter('Arguments', $next.Arguments)
        $gui.Handle = $gui.Worker.BeginInvoke()
    }
    Update-Controls
}
function Complete-Work($Done) {
    try { [void]$gui.Worker.EndInvoke($gui.Handle) } catch { }
    $gui.Worker.Streams.ClearStreams()
    $onDone = $gui.OnDone
    $gui.Job = $null
    $gui.OnDone = $null
    if (-not $Done.Ok -and $Done.Details) { Write-GuiLog $Done.Details }
    try {
        if ($onDone) { & $onDone $Done } elseif (-not $Done.Ok) { Add-Line $Done.Message 'error' }
    } catch { Show-GuiError $_ }
    Start-NextWork
}
function Update-Controls {
    $playing = [bool]$gui.Playing
    foreach ($name in @('ServerBox', 'AddServerButton', 'AccountBox', 'BrowseButton', 'Dx12Box', 'VoiceBox', 'VoiceButton', 'FirewallOnButton', 'FirewallOffButton',
            'FirewallResetButton', 'FirewallShowButton', 'ExportButton', 'ImportButton')) { $gui.C[$name].IsEnabled = -not $playing }
    # The admin page also while the game runs: it has a worker of its own (Start-SideWork).
    $gui.C.AdminButton.IsEnabled = -not $gui.SideJob
    # Start through Steam may close Steam: not while joining or playing, not twice at once.
    foreach ($name in @('SteamSetButton', 'SteamOffButton')) { $gui.C[$name].IsEnabled = -not $playing -and -not $gui.SteamBusy }
    $gui.C.PlayButton.IsEnabled = -not $playing
    $gui.C.PlayButton.Content = if ($gui.GameRunning) { $gui.Strings.Running } elseif ($playing) { $gui.Strings.Joining } else { $gui.Strings.Play }
}
function Get-SelectedServer {
    $index = $gui.C.ServerBox.SelectedIndex
    if ($index -ge 0 -and $index -lt @($gui.Servers).Count) { return $gui.Servers[$index].address }
    return ''
}
# The server list from roe-join.json, Select (an address) selected, else the most recent one.
function Update-ServerList([string]$Select) {
    $gui.Updating = $true
    try {
        $gui.Servers = @(Get-OfferedServers (Read-Settings))
        $box = $gui.C.ServerBox
        $box.Items.Clear()
        $index = 0
        for ($i = 0; $i -lt $gui.Servers.Count; $i++) {
            [void]$box.Items.Add((Get-ServerLabel $gui.Servers[$i]))
            if ($Select -and (Get-ServerFolderName $gui.Servers[$i].address) -eq (Get-ServerFolderName $Select)) { $index = $i }
        }
        if ($gui.Servers.Count) { $box.SelectedIndex = $index }
    } finally {
        $gui.Updating = $false
    }
    Update-AccountList
}
# The accounts of the selected server, the most recent first, and "Create a new account".
function Update-AccountList {
    $gui.Updating = $true
    try {
        $server = Get-SelectedServer
        $gui.Accounts = if ($server) { Read-Accounts (Get-AccountFolder $server) } else { New-Object Collections.ArrayList }
        $box = $gui.C.AccountBox
        $box.Items.Clear()
        foreach ($account in $gui.Accounts) { [void]$box.Items.Add($account.name) }
        [void]$box.Items.Add($gui.Strings.NewAccount)
        $box.SelectedIndex = 0
    } finally {
        $gui.Updating = $false
    }
    Update-AdminPanel
}
# The selected account's saved entry, or $null for "Create a new account".
function Get-SelectedAccount {
    $index = $gui.C.AccountBox.SelectedIndex
    if ($index -ge 0 -and $index -lt @($gui.Accounts).Count) { return $gui.Accounts[$index] }
    return $null
}
# The admin page's part under Advanced: there only for an account with GM rights on the selected server.
function Update-AdminPanel {
    $roles = if ($gui.RolesServer -and $gui.RolesServer -eq (Get-SelectedServer)) { $gui.Roles } else { $null }
    $gui.C.AdminPanel.Visibility = if (Test-ShowAdmin $roles (Get-SelectedAccount)) { 'Visible' } else { 'Collapsed' }
}
function Open-GuiAdmin {
    $server = Get-SelectedServer
    $entry = Get-SelectedAccount
    if (-not $server -or -not $entry -or -not $entry.token -or $gui.SideJob) { return }
    Add-Line "Opening the admin page for $($entry.name) ..."
    Start-SideWork 'Invoke-AdminJob' @{ Server = $server; Token = "$($entry.token)" } {
        param($done)
        if ($done.Ok) { Add-Line 'The admin page is open in your browser (its login link works once, for one minute).' } else { Add-Line "Could not open the admin page: $($done.Message)" 'error' }
    }
}
function Request-ServerInfo {
    $server = Get-SelectedServer
    if (-not $server) { Set-GuiServerStatus 'Add the server the host gave you: Add server... (its IP address or domain).' 'muted'; return }
    Set-GuiServerStatus "Contacting $server ..." 'muted'
    Start-Work 'Invoke-ServerJob' @{ Server = $server } { param($done) Show-ServerInfo $done }
}
function Show-ServerInfo($Done) {
    if (-not $Done.Ok) { Set-GuiServerStatus $Done.Message 'error'; return }
    $server = $Done.Result.Server
    if ((Get-SelectedServer) -ne $server) { return }  # another one was selected meanwhile; its request follows
    $contact = $Done.Result.Contact
    $gui.Contact = $contact
    $gui.ContactServer = $server
    $gui.Roles = $Done.Result.Roles
    $gui.RolesServer = $server
    if ($contact.Name -and -not $gui.Playing) {
        $servers = @(Get-OfferedServers (Read-Settings))
        if (Set-ServerName $servers $server $contact.Name) { Update-Settings @{ servers = $servers }; Update-ServerList $server }
    }
    $line = Get-ServerInfoText $contact
    Set-GuiServerStatus $line.Text $line.Level
    if (-not $gui.Playing) {
        $index = $gui.C.AccountBox.SelectedIndex
        Update-AccountList
        if ($index -lt $gui.C.AccountBox.Items.Count) { $gui.C.AccountBox.SelectedIndex = $index }
    }
    Update-AdminPanel
}
# While the window is open (Start-Gui's timer): the region table of the selected server again, from a
# server that answered STATS, only while the worker has nothing else to do and no game is joined or
# runs (the play step sends the numbers itself then). Get-ServerStats asks at most every 10 s.
function Update-GuiStats {
    $server = Get-SelectedServer
    if (-not $server -or -not $gui.Contact -or -not $gui.Contact.Regions -or $gui.ContactServer -ne $server) { return }
    if ($gui.Playing -or $gui.Job -or $gui.Queue.Count) { return }
    Start-Work 'Invoke-StatsJob' @{ Server = $server } { param($done) Show-GuiStats $done }
}
# The refreshed table, with the server line's notices (Get-ServerInfoText); a failed or empty answer
# keeps the table as it is.
function Show-GuiStats($Done) {
    if (-not $Done.Ok -or -not $Done.Result.Regions -or $gui.Playing) { return }
    if ($Done.Result.Server -ne (Get-SelectedServer) -or $Done.Result.Server -ne $gui.ContactServer) { return }
    $gui.Contact.Regions = $Done.Result.Regions
    $line = Get-ServerInfoText $gui.Contact
    Set-GuiServerStatus $line.Text $line.Level
}
# The game folder: the Ring of Elysium folder (GameBase) and the DirectX 12 box (Dx12: its XVersion
# folder). Client is the resulting folder when it has Europa_Client.exe, else ''.
function Update-GameFolder {
    $gui.Updating = $true
    try { $gui.C.Dx12Box.IsChecked = [bool]$gui.Dx12 } finally { $gui.Updating = $false }
    $gui.C.GameBox.Text = $gui.GameBase
    $choice = Get-GameFolderChoice $gui.GameBase ([bool]$gui.Dx12)
    $gui.Client = $choice.Folder
    if (-not $gui.GameBase) {
        Set-GuiNote $gui.C.GameNote LocateGame warn
    } elseif ($choice.Problem) {
        Set-Text $gui.C.GameNote $choice.Problem 'warn'
    } else {
        if ($gui.Dx12) { Set-GuiNote $gui.C.GameNote Dx12 muted @($choice.Folder) }
        else { Set-GuiNote $gui.C.GameNote Dx11 muted }
    }
}
# Checks the game build of the chosen folder in the background and saves it (roe-join.json
# "client": the full folder, as join-roe-os.cmd keeps it).
function Save-GuiGameFolder {
    if (-not $gui.Client) { Add-Line (Get-GameFolderChoice $gui.GameBase ([bool]$gui.Dx12)).Problem 'error'; return }
    $folder = $gui.Client
    Add-Line "Checking the game in $folder ..." info Checking @($folder)
    Start-Work 'Get-GameFolder' @{ Folder = $folder } {
        param($done)
        if (-not $done.Ok) { Add-Line $done.Message 'error'; return }
        $split = Split-GameFolder $done.Result
        $gui.GameBase = $split.Base
        $gui.Dx12 = $split.Dx12
        Update-Settings @{ client = $done.Result }
        Update-GameFolder
        Update-Voice
        Add-Line "Game folder: $($done.Result) (the tested version)." info FolderVerified @($done.Result)
    }
}
function Update-Voice {
    $gui.Updating = $true
    try { $gui.C.VoiceBox.IsChecked = (Read-Settings).voice -ne $false } finally { $gui.Updating = $false }
    if (-not $gui.C.VoiceBox.IsChecked) {
        Set-GuiNote $gui.C.VoiceStatus VoiceOff muted
        Set-Text $gui.C.VoiceNote ''
        $gui.C.VoiceButton.Visibility = 'Collapsed'
        return
    }
    $gui.C.VoiceButton.Visibility = 'Visible'
    $dll = Get-GuiVoiceDll
    if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) {
        Set-GuiNote $gui.C.VoiceStatus VoiceFileMissing warn
        Set-GuiNote $gui.C.VoiceNote VoiceMissing warn @($voiceFile)
        return
    }
    $problem = Get-VoiceDllProblem $dll $(if (Test-Client $gui.Client) { $gui.Client } else { '' })
    if ($problem) {
        Set-GuiNote $gui.C.VoiceStatus VoiceFileInvalid warn
        Set-GuiNote $gui.C.VoiceNote VoiceProblem warn @($problem)
    } else {
        Set-GuiNote $gui.C.VoiceStatus VoiceAvailable
        Set-GuiNote $gui.C.VoiceNote VoiceReady muted @($dll)
    }
}
function Update-FirewallText {
    $firewall = (Read-Settings).firewall
    $gui.FirewallState = if ($null -eq $firewall) { 'FirewallPending' } elseif ($firewall) { 'FirewallOn' } else { 'FirewallOff' }
    $gui.C.FirewallText.Text = $gui.Strings.($gui.FirewallState) + ' ' + $gui.Strings.FirewallHelp
}
# A folder picker; '' when cancelled.
function Select-Folder([string]$Description, [string]$Start) {
    $owner = [Windows.Interop.WindowInteropHelper]::new($gui.Window).EnsureHandle()
    $dialog = [Windows.Forms.FolderBrowserDialog]::new()
    $dialogOwner = [Windows.Forms.NativeWindow]::new()
    try {
        $dialogOwner.AssignHandle($owner)
        $dialog.Description = $Description
        $dialog.ShowNewFolderButton = $false
        if ([IO.Directory]::Exists($Start)) { $dialog.SelectedPath = $Start }
        if ($dialog.ShowDialog($dialogOwner) -eq [Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
        return ''
    } finally {
        $dialogOwner.ReleaseHandle()
        $dialog.Dispose()
    }
}
function Select-GameFolder {
    $path = Select-Folder $gui.Strings.LocateGame $gui.GameBase
    if (-not $path) { return }
    # An XVersion folder picked directly: the folder above it, with DirectX 12.
    $split = Split-GameFolder $path
    $gui.GameBase = $split.Base
    if ($split.Dx12) { $gui.Dx12 = $true }
    Update-GameFolder
    Save-GuiGameFolder
}
function Set-GuiDx12 {
    $gui.Dx12 = [bool]$gui.C.Dx12Box.IsChecked
    Update-GameFolder
    if ($gui.GameBase) { Save-GuiGameFolder }
}
function Select-VoiceFolder {
    $start = Split-Path -Parent (Get-GuiVoiceDll)
    $path = Select-Folder ($gui.Strings.VoiceFolder -f $voiceFile) $start
    if (-not $path) { return }
    $dll = Resolve-VoiceDll $path
    $problem = Get-VoiceDllProblem $dll $(if (Test-Client $gui.Client) { $gui.Client } else { '' })
    if ($problem) { Add-Line "Voice chat: $problem." 'error'; return }
    Update-Settings @{ voice_dll = [IO.Path]::GetFullPath($dll); voice = $true }
    Update-Voice
    Add-Line "Voice chat: our $voiceFile is $dll." info VoicePath @($dll)
}
function Add-GuiServer {
    $address = Show-InputDialog $gui.Strings.Address $gui.Strings.AddressHelp ''
    if ($null -eq $address) { return }
    $address = $address.Trim()
    if (-not $address) { return }
    if (-not (Test-BackupAddress $address)) { Add-Line "That is no IP address or domain: $address" error BadAddress @($address); return }
    try { [void](Get-ServerHost $address) } catch { Show-GuiError $_; return }
    Update-Settings @{ servers = @(Add-ServerUse @(Get-OfferedServers (Read-Settings)) $address) }
    Update-ServerList $address
    Request-ServerInfo
}
function Start-Play {
    if ($gui.CountdownTimer) { Stop-SteamCountdown '' }
    $server = Get-SelectedServer
    if (-not $server) { Add-Line 'Add the server first: Add server...' 'error'; return }
    if (-not (Test-Client $gui.Client)) {
        $problem = if ($gui.GameBase) { (Get-GameFolderChoice $gui.GameBase ([bool]$gui.Dx12)).Problem } else { '' }
        Add-Line $(if ($problem) { $problem } else { 'Choose the game folder first: Browse...' }) 'error'
        return
    }
    if ($null -eq (Read-Settings).firewall) {
        $answer = Show-Message $gui.Strings.AskFirewall 'YesNo' 'Question' 'Yes'
        Update-Settings @{ firewall = $answer -eq 'Yes' }
        Update-FirewallText
    }
    $voiceOn = [bool]$gui.C.VoiceBox.IsChecked
    $useVoice = $voiceOn
    if ($voiceOn) {
        $problem = Get-VoiceDllProblem (Get-GuiVoiceDll) $gui.Client
        if ($problem) {
            if ((Show-Message ("$problem`n`n" + $gui.Strings.WithoutVoice) 'YesNo' 'Question' 'Yes') -ne 'Yes') { return }
            $useVoice = $false
        }
    }
    Update-Settings @{ voice = $voiceOn }
    $entry = Get-SelectedAccount
    $gui.Playing = $true
    Add-Line "Joining $server ..." info ConnectTo @($server)
    $extra = [string[]]@()
    if ($gui.SteamGame) {
        $extra = [string[]]@($gui.SteamGame.Extra)
        Set-Text $gui.C.SteamBarText 'Started by Steam: this window closes itself when the game exits.'
    }
    Start-Work 'Invoke-PlayJob' @{ Client = $gui.Client; Server = $server; Token = "$($entry.token)"; AccountName = "$($entry.name)"; New = ($null -eq $entry); UseVoice = $useVoice; Extra = $extra } {
        param($done)
        $gui.Playing = $false
        $gui.GameRunning = $false
        # Started by Steam: the window goes with the game, so Steam's "Playing" ends too.
        if ($done.Ok -and $gui.SteamGame) { Write-GuiLog 'The game has exited (started by Steam): closing the window.'; $gui.Window.Close(); return }
        if ($gui.SteamGame) { Set-Text $gui.C.SteamBarText 'Started by Steam: press Play to try again.' }
        if ($done.Ok) { Add-Line 'The game has exited.' info GameExited } else { Add-Line "Could not join: $($done.Message)" error JoinFailed @($done.Message) }
        Update-ServerList (Get-SelectedServer)
        Update-FirewallText
        Update-Voice
    }
}
# --- Start through Steam -----------------------------------------------------------------------
# Set up starting through Steam: the launch option line to paste (Copy), the state in Steam
# (checked in the worker), Set up (the selected server and account as the Steam profile, and the
# launch option in Steam), Turn off.
function Update-SteamPanel {
    $settings = Read-Settings
    $gui.C.SteamLineBox.Text = Get-SteamLaunchLine -Window
    $state = "$($gui.SteamState)"
    $line = Get-GuiSteamText $state $settings
    Set-Text $gui.C.SteamText $line.Text $line.Level
    $gui.C.SteamSetButton.SetResourceReference([Windows.Controls.ContentControl]::ContentProperty, $(if ($state -eq 'window') { 'Ui.SteamUse' } else { 'Ui.SteamSet' }))
    $gui.C.SteamOffButton.Visibility = if ($state -in @('window', 'console', 'moved')) { 'Visible' } else { 'Collapsed' }
    $gui.Updating = $true
    try { $gui.C.SteamAutoBox.IsChecked = Test-SteamAutoStart $settings } finally { $gui.Updating = $false }
}
# Copy: the launch option line to the clipboard (the window runs in STA).
function Set-GuiClipboard([string]$Text) { [Windows.Clipboard]::SetText($Text) }
function Copy-SteamLine {
    $line = Get-SteamLaunchLine -Window
    try { Set-GuiClipboard $line; Add-Line "Copied: $line. Paste it into Steam's launch options." }
    catch { Add-Line "Could not copy ($(Get-ErrorMessage $_)): select the line and press Ctrl+C." 'warn' }
}
function Request-SteamState {
    Start-Work 'Get-SteamSetupState' @{} {
        param($done)
        $gui.SteamState = if ($done.Ok) { $done.Result.State } else { 'nosteam' }
        Update-SteamPanel
    }
}
function Set-GuiSteam([bool]$Off) {
    $state = "$($gui.SteamState)"
    if (-not $state) { Add-Line 'Still checking Steam: try again in a moment.' 'warn'; return }
    if (-not $Off) {
        $server = Get-SelectedServer
        if (-not $server) { Add-Line 'Add the server first: Add server...' 'error'; return }
        $entry = Get-SelectedAccount
        Set-SteamProfile @{ server = $server; account = $(if ($entry -and $entry.token) { Get-AccountId "$($entry.token)" } else { '' }) }
        # Already on: only the server and account change, Steam stays as it is.
        if ($state -eq 'window') {
            Update-SteamPanel
            Add-Line "Start through Steam: Steam's Play button now starts the game $(Get-SteamProfileText (Read-Settings))."
            return
        }
    }
    $close = $false
    if (Test-SteamRunning) {
        $what = if ($Off) { 'turn Start through Steam off' } else { 'set up Start through Steam' }
        $answer = Show-Message ("Steam has to be closed to $what (it saves its own settings when it closes and would undo the change).`n`n" +
            'Close Steam now? join-roe-os.cmd can start it again afterwards.') 'YesNo' 'Question' 'Yes'
        if ($answer -ne 'Yes') { Add-Line 'Start through Steam: nothing changed (Steam stays open).' 'warn'; return }
        $close = $true
    }
    Start-GuiSteamWrite $Off $close $false
}
function Start-GuiSteamWrite([bool]$Off, [bool]$Close, [bool]$Replace) {
    $gui.SteamBusy = $true
    $gui.SteamOff = $Off
    Start-Work 'Invoke-SteamWrite' @{ Off = $Off; CloseSteam = $Close; Replace = $Replace } { param($done) Complete-GuiSteamWrite $done }
}
function Complete-GuiSteamWrite($Done) {
    $gui.SteamBusy = $false
    if (-not $Done.Ok) { Add-Line "Start through Steam: $($Done.Message)" 'error' }
    else {
        if ($Done.Result.Closed) { $gui.SteamClosed = $true }
        if (-not $Done.Result.Done) {
            $answer = Show-Message ("Steam has other launch options for Ring of Elysium:`n`n$($Done.Result.Other)`n`nReplace them?") 'YesNo' 'Question' 'No'
            if ($answer -eq 'Yes') { Start-GuiSteamWrite $false $false $true; return }
            Add-Line 'Start through Steam: nothing changed (Steam keeps its launch options).' 'warn'
        } elseif ($gui.SteamOff) {
            Set-SteamProfile @{ server = ''; account = '' }
            Add-Line "Start through Steam is off: Steam's Play button starts the game as before."
        } else {
            Add-Line "Start through Steam is on: Steam's Play button starts the game $(Get-SteamProfileText (Read-Settings))."
        }
    }
    if ($gui.SteamClosed) {
        $gui.SteamClosed = $false
        if ((Show-Message 'Start Steam again?' 'YesNo' 'Question' 'Yes') -eq 'Yes') {
            try { Start-Steam } catch { Add-Line "Could not start Steam: $(Get-ErrorMessage $_)" 'error' }
        }
    }
    $gui.SteamState = ''
    Update-SteamPanel
    Request-SteamState
}
# Started by Steam: the window with the Steam profile's server and account (else the last used
# ones) and Steam's game folder; then the countdown, or a wait for Play.
function Initialize-SteamStart($Settings) {
    $client = Get-SteamClient $gui.SteamGame.Folder "$($Settings.client)"
    $split = Split-GameFolder $client
    $gui.GameBase = $split.Base
    $gui.Dx12 = $split.Dx12
    Update-GameFolder
    $server = Get-SteamServer $Settings ''
    Update-ServerList $server
    $gui.Window.Title = 'Ring of Elysium Launcher: started by Steam'
    $gui.C.SteamBar.Visibility = 'Visible'
    if (-not (Get-SelectedServer)) { Set-Text $gui.C.SteamBarText 'Started by Steam: add the server, then press Play.' 'warn'; return }
    $pick = Get-SteamAccount $Settings (Get-SelectedServer) $gui.Accounts
    if (-not $pick.Found) { Set-Text $gui.C.SteamBarText 'Started by Steam: the account saved for Steam is gone. Choose one and press Play.' 'warn'; return }
    $index = if ($pick.Entry) { [array]::IndexOf(@($gui.Accounts), $pick.Entry) } else { @($gui.Accounts).Count }
    if ($index -ge 0) { $gui.C.AccountBox.SelectedIndex = $index }
    if (-not $gui.Client) { Set-Text $gui.C.SteamBarText 'Started by Steam: the game folder has a problem (see above), so press Play once it is fixed.' 'warn'; return }
    if (-not (Test-SteamAutoStart $Settings)) { Set-Text $gui.C.SteamBarText 'Started by Steam: press Play when you are ready.'; return }
    Start-SteamCountdown 3
}
function Start-SteamCountdown([int]$Seconds) {
    $gui.Countdown = $Seconds
    $gui.C.SteamCancelButton.Visibility = 'Visible'
    Show-SteamCountdown
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({ try { Step-SteamCountdown } catch { Show-GuiError $_ } })
    $gui.CountdownTimer = $timer
    $timer.Start()
}
function Show-SteamCountdown {
    $entry = Get-SelectedAccount
    Set-Text $gui.C.SteamBarText (Get-SteamCountdownText $gui.Countdown (Get-SelectedServer) "$($entry.name)")
}
function Step-SteamCountdown {
    $gui.Countdown--
    if ($gui.Countdown -gt 0) { Show-SteamCountdown; return }
    Stop-SteamCountdown ''
    if (-not $gui.Playing) { Start-Play }
}
# Text: the bar's new line ('' keeps it).
function Stop-SteamCountdown([string]$Text) {
    if ($gui.CountdownTimer) { $gui.CountdownTimer.Stop(); $gui.CountdownTimer = $null }
    $gui.C.SteamCancelButton.Visibility = 'Collapsed'
    if ($Text) { Set-Text $gui.C.SteamBarText $Text }
}

function Set-GuiFirewall([string]$Action) {
    $client = if (Test-Client $gui.Client) { $gui.Client } else { '' }
    switch ($Action) {
        'on' {
            Update-Settings @{ firewall = $true }
            Add-Line 'Firewall rules on: the next Play sets them.'
        }
        'off' {
            Update-Settings @{ firewall = $false }
            Start-Work 'Remove-FolderRules' @{ Client = $client } {
                param($done)
                if ($done.Ok) { Add-Line 'Firewall rules off: join-roe-os.cmd no longer sets them (the game can reach the internet).' } else { Add-Line $done.Message 'error' }
            }
        }
        'reset' {
            if ((Show-Message $gui.Strings.ResetConfirm 'YesNo' 'Question' 'No') -ne 'Yes') { return }
            Start-Work 'Reset-AllRules' @{} $null
        }
        'show' {
            $gui.C.DetailsButton.IsChecked = $true
            Start-Work 'Show-Firewall' @{ Client = $client; Firewall = (Read-Settings).firewall } $null
        }
    }
    Update-FirewallText
}
function Export-GuiAccounts {
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.FileName = 'roe-join-accounts.json'
    $dialog.Filter = "$($gui.Strings.Backup) (*.json)|*.json|$($gui.Strings.AllFiles) (*.*)|*.*"
    if ($dialog.ShowDialog($gui.Window) -ne $true) { return }
    $done = Export-Accounts $joinRoot (Read-Settings) $dialog.FileName
    Add-Line "Saved $($done.Accounts) accounts of $($done.Servers) servers in $($dialog.FileName). On the other PC: Import accounts... (or join-roe-os.cmd import <file>)."
    Add-Line $backupWarning 'warn'
}
function Import-GuiAccounts {
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "$($gui.Strings.Backup) (*.json)|*.json|$($gui.Strings.AllFiles) (*.*)|*.*"
    if ($dialog.ShowDialog($gui.Window) -ne $true) { return }
    Add-Line $backupWarning 'warn'
    Start-Work 'Import-Accounts' @{ Root = $joinRoot; Settings = (Read-Settings); File = $dialog.FileName } {
        param($done)
        if (-not $done.Ok) { Add-Line "Could not import: $($done.Message)" 'error'; return }
        Update-Settings @{ servers = @($done.Result.Servers) }
        $line = "Imported: $($done.Result.Added) new accounts, $($done.Result.Updated) updated (used more recently in the backup)."
        if (@($done.Result.Skipped).Count) { $line += " Skipped (another certificate): $($done.Result.Skipped -join ', ')." }
        Add-Line "$line You may delete the backup file now."
        Update-ServerList (Get-SelectedServer)
        Request-ServerInfo
    }
}
function Show-GuiDetails {
    $box = $gui.C.DetailsBox
    $path = Get-GuiLogPath
    try {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $lines = @(Get-Content -LiteralPath $path -Encoding UTF8 -Tail 80 -ErrorAction Stop)
            if ($lines.Count) { $box.Text = ($lines -join "`r`n") + "`r`n" }
        }
    } catch { } # The current session's in-memory lines are still available.
    if (-not $box.Text.Trim()) { $box.Text = $gui.C.StatusText.Text + "`r`n" }
    $gui.Window.UpdateLayout()
    $box.BringIntoView()
    $box.ScrollToEnd()
}
function Open-GuiLog {
    $path = Get-GuiLogPath
    if (-not (Test-Path -LiteralPath $path)) { Write-GuiLog 'Log opened.' }
    Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$path`""
}
# Control.Event runs Action; an error there becomes a line, never a crash.
function Add-Handler($Control, [string]$Event, [scriptblock]$Action) {
    $Control."Add_$Event"({ try { & $Action } catch { Show-GuiError $_ } }.GetNewClosure())
}
# The buttons and the box of "Set up starting through Steam".
function Register-SteamHandlers {
    Add-Handler $gui.C.SteamCopyButton 'Click' { Copy-SteamLine }
    Add-Handler $gui.C.SteamSetButton 'Click' { Set-GuiSteam $false }
    Add-Handler $gui.C.SteamOffButton 'Click' { Set-GuiSteam $true }
    Add-Handler $gui.C.SteamAutoBox 'Click' { if (-not $gui.Updating) { Set-SteamProfile @{ auto_start = [bool]$gui.C.SteamAutoBox.IsChecked } } }
}
# The console the window was started from out of sight: cmd.exe's when Steam starts join-roe-os.cmd and
# it waits for the window, PowerShell's own after a double-click. A classic console window is
# hidden. Windows Terminal (the default terminal on Windows 11) only minimizes for that, so there
# its window is hidden when it holds just this tab; it closes when the tab ends.
function Hide-ConsoleWindow {
    try {
        if (-not ('RoeJoin.ConsoleWindow' -as [type])) {
            Add-Type -Namespace RoeJoin -Name ConsoleWindow -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
[DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr window, uint relation);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr window, System.Text.StringBuilder name, int size);
'@
        }
        $console = [RoeJoin.ConsoleWindow]::GetConsoleWindow()
        if ($console -eq [IntPtr]::Zero) { return }
        $window = $console
        $class = New-Object Text.StringBuilder 256
        [void][RoeJoin.ConsoleWindow]::GetClassName($console, $class, 256)
        if ("$class" -eq 'PseudoConsoleWindow') {
            $terminal = [RoeJoin.ConsoleWindow]::GetWindow($console, 4)  # GW_OWNER: the terminal's window
            $class = New-Object Text.StringBuilder 256
            [void][RoeJoin.ConsoleWindow]::GetClassName($terminal, $class, 256)
            if ("$class" -eq 'CASCADIA_HOSTING_WINDOW_CLASS') {
                Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
                $tab = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::TabItem)
                $tabs = [Windows.Automation.AutomationElement]::FromHandle($terminal).FindAll([Windows.Automation.TreeScope]::Descendants, $tab).Count
                if ($tabs -eq 1) { $window = $terminal }
            }
        }
        [void][RoeJoin.ConsoleWindow]::ShowWindow($window, 0)  # SW_HIDE
    } catch {
        Write-GuiLog "join-roe-os.cmd could not hide its console window: $($_.Exception.Message)"
    }
}
function Start-Gui([string]$Code) {
    $log = Get-GuiLogPath
    if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).Length -gt 1MB) { Move-Item -LiteralPath $log -Destination ($log -replace '\.log$', '.old.log') -Force }
    Write-GuiLog "join-roe-os.cmd $joinVersion opens its window ($env:ROE_JOIN_SELF)."
    $window = New-GuiWindow (Get-GuiXaml)
    $gui.Window = $window
    # The administrator prompt belongs to this window (Get-PromptOwner).
    $window.Add_SourceInitialized({ $sync.Owner = (New-Object Windows.Interop.WindowInteropHelper $this).Handle })
    $gui.C = @{}
    foreach ($name in (Get-GuiControlNames)) { $gui.C[$name] = $window.FindName($name) }
    $gui.Recent = New-Object Collections.ArrayList
    $gui.Queue = New-Object Collections.ArrayList
    $gui.Job = $null; $gui.Playing = $false; $gui.GameRunning = $false; $gui.Updating = $false; $gui.Draining = $false
    $gui.SideJob = $null; $gui.SideWorker = $null; $gui.Code = $Code
    $gui.Roles = $null; $gui.RolesServer = ''
    $gui.SteamState = ''; $gui.SteamBusy = $false; $gui.SteamClosed = $false; $gui.SteamOff = $false; $gui.CountdownTimer = $null
    # Started by Steam (launch option "<join-roe-os.cmd>" --window %command%): its command line follows --window.
    $gui.SteamGame = Find-WindowSteamGame "$env:ROE_JOIN_ARGS"

    Initialize-GuiLanguage
    $gui.Worker = New-Worker $Code

    $settings = Read-Settings
    $saved = "$($settings.client)"
    if (-not (Test-Client $saved)) {
        $guess = 'C:\Program Files (x86)\Steam\steamapps\common\Ring of Elysium'
        $saved = if (Test-Client $guess) { $guess } else { '' }
    }
    $split = Split-GameFolder $saved
    $gui.GameBase = $split.Base
    $gui.Dx12 = $split.Dx12
    Update-GameFolder
    Update-ServerList ''
    if ($gui.SteamGame) { Initialize-SteamStart $settings }
    Update-Voice
    Update-FirewallText
    Update-SteamPanel
    Update-Controls
    Set-GuiNote $gui.C.StatusText Ready muted

    Add-Handler $gui.C.ServerBox 'SelectionChanged' { if (-not $gui.Updating) { $gui.Roles = $null; $gui.RolesServer = ''; Update-AccountList; Request-ServerInfo } }
    Add-Handler $gui.C.AccountBox 'SelectionChanged' { if (-not $gui.Updating) { Update-AdminPanel } }
    Add-Handler $gui.C.AdminButton 'Click' { Open-GuiAdmin }
    Add-Handler $gui.C.AddServerButton 'Click' { Add-GuiServer }
    Add-Handler $gui.C.BrowseButton 'Click' { Select-GameFolder }
    Add-Handler $gui.C.Dx12Box 'Click' { if (-not $gui.Updating) { Set-GuiDx12 } }
    Add-Handler $gui.C.VoiceBox 'Click' { Update-Settings @{ voice = [bool]$gui.C.VoiceBox.IsChecked }; Update-Voice }
    Add-Handler $gui.C.VoiceButton 'Click' { Select-VoiceFolder }
    # Refresh after the player returns from downloading or moving the DLL.
    Add-Handler $window 'Activated' { if ($gui.Window.IsLoaded -and -not $gui.Playing) { Update-Voice } }
    Add-Handler $gui.C.PlayButton 'Click' { Start-Play }
    Add-Handler $gui.C.DetailsButton 'Checked' { Show-GuiDetails }
    Add-Handler $gui.C.FirewallOnButton 'Click' { Set-GuiFirewall 'on' }
    Add-Handler $gui.C.FirewallOffButton 'Click' { Set-GuiFirewall 'off' }
    Add-Handler $gui.C.FirewallResetButton 'Click' { Set-GuiFirewall 'reset' }
    Add-Handler $gui.C.FirewallShowButton 'Click' { Set-GuiFirewall 'show' }
    Add-Handler $gui.C.ExportButton 'Click' { Export-GuiAccounts }
    Add-Handler $gui.C.ImportButton 'Click' { Import-GuiAccounts }
    Add-Handler $gui.C.LogButton 'Click' { Open-GuiLog }
    Register-SteamHandlers
    Add-Handler $gui.C.SteamCancelButton 'Click' { Stop-SteamCountdown 'Started by Steam: press Play when you are ready.' }
    $window.Add_Closing({
        param($sender, $e)
        if (-not $gui.Playing) { return }
        $answer = Show-Message $gui.Strings.CloseConfirm 'YesNo' 'Warning' 'No'
        if ($answer -ne 'Yes') { $e.Cancel = $true }
    })
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(100)
    $timer.Add_Tick({ Receive-GuiEvents })
    $timer.Start()
    # Who plays and searches where, while the window is open.
    $statsTimer = New-Object Windows.Threading.DispatcherTimer
    $statsTimer.Interval = [TimeSpan]::FromSeconds(15)
    Add-Handler $statsTimer 'Tick' { Update-GuiStats }
    $statsTimer.Start()
    # Our voice DLL left by a crash or a closed window: the original back first.
    Start-Work 'Restore-AllVoice' @{} $null
    Request-ServerInfo
    Request-SteamState
    [void]$window.ShowDialog()
    $timer.Stop()
    $statsTimer.Stop()
    Write-GuiLog 'join-roe-os.cmd closed its window.'
}

# === Main part ================================================================================
if ($FirewallStep) { exit (Invoke-FirewallStep $FirewallStep) }
# join-roe-os.ps1 of the separate files started on its own (Run with PowerShell): as by its join-roe-os.cmd.
if (-not $env:ROE_JOIN_SELF -and (Split-Path -Leaf "$PSCommandPath") -eq 'join-roe-os.ps1') {
    $env:ROE_JOIN_CODE = $PSCommandPath
    $env:ROE_JOIN_SELF = Join-Path (Split-Path -Parent $PSCommandPath) 'join-roe-os.cmd'
    $env:ROE_JOIN_STEAM = Join-Path (Split-Path -Parent $PSCommandPath) 'join-roe-os-window.cmd'
}
# The .ps1 copies the batch part writes (run-*.ps1), once PowerShell has read them.
Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'roe-join') -Filter 'run-*.ps1' -ErrorAction SilentlyContinue |
    Where-Object { $_.CreationTimeUtc -lt [DateTime]::UtcNow.AddMinutes(-10) } | Remove-Item -ErrorAction SilentlyContinue
# The window (ROE_JOIN_WINDOW from the batch part: no arguments, or --window).
if ($env:ROE_JOIN_WINDOW) {
    try {
        Hide-ConsoleWindow
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
        if (-not $env:ROE_JOIN_SELF) { throw 'Start join-roe-os.cmd by double-clicking it.' }
        $sync = [hashtable]::Synchronized(@{ Events = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]' })
        $gui = @{}
        $joinCode = Get-JoinCode (Get-JoinCodePath)
        # This thread has the functions already; only Write-Host and Ask become the window's.
        Set-Item -Path function:Write-Host -Value ${function:Write-GuiHost}
        Set-Item -Path function:Ask -Value ${function:Read-GuiAnswer}
        Start-Gui $joinCode
    } catch {
        $message = Get-ErrorMessage $_
        Write-GuiLog "join-roe-os.cmd could not start its window: $message`r`n$($_ | Out-String)$($_.ScriptStackTrace)"
        try { [void][Windows.MessageBox]::Show("join-roe-os.cmd could not start its window: $message`n`nDetails: $(Get-GuiLogPath)", 'Ring of Elysium Launcher', 'OK', 'Error') } catch { }
    }
    [Environment]::Exit(0)
}

# The console.
$failed = 'Could not join: '
try {
    $settings = Read-Settings
    # --console: this console even without other arguments (the batch part takes --window).
    $argText = ("$env:ROE_JOIN_ARGS" -replace '(^|\s)--console(?=\s|$)', ' ').Trim()
    # --skip-file-check: no check of the game files (for players who changed them on purpose).
    $skipFileCheck = $argText -match '(^|\s)--skip-file-check(?=\s|$)'
    $argText = ($argText -replace '(^|\s)--skip-file-check(?=\s|$)', ' ').Trim()
    # Started by Steam ("<join-roe-os.cmd>" %command%): the command line names the game's exe; our options
    # are the ones in front of it.
    $steamGame = Find-SteamGame $argText
    if ($steamGame) { $argText = $steamGame.Before.Trim() }
    $usage = ('Usage: join-roe-os.cmd [--console] [--skip-file-check] [-Server <address>] [-Name <name>] | firewall [on|off|reset] | voice [on|off] | export [FILE] | import FILE' + "`n" +
        'For GM accounts: join-roe-os.cmd [-Server <address>] [-Name <name>] admin (opens the server''s admin page)' + "`n" +
        'Start through Steam: join-roe-os.cmd [-Server <address>] [-Name <name>] steam-setup [off] (the launch option line, set in Steam if you want)' + "`n" +
        'The window: join-roe-os.cmd without arguments, or join-roe-os.cmd --window')
    $arguments = Read-Arguments $argText
    # Ours left by a crash or a closed window: the original back first. Not for "admin", which
    # runs next to a game this script started (its join puts the DLL back when the game exits).
    if ($arguments.Command -ne 'admin') { Restore-AllVoice }
    $command = $arguments.Command
    $givenName = $arguments.Name
    $givenServer = $arguments.Server
    if ($argText -match '(^|\s)-Name(\s|$)' -and (-not $givenName -or $givenName.Length -gt 24 -or $givenName -match '[\x00-\x1f]')) {
        throw 'The name must be 1 to 24 characters without control characters.'
    }
    if ($command -and $command -ne 'admin' -and $command -notmatch '^steam-setup\b' -and ($givenName -or $givenServer)) { throw $usage }
    if ($steamGame -and $command) { throw $usage }
    if ($command -match '^steam-setup(\s+(on|off))?$') {
        Invoke-SteamSetup $settings ("$($Matches[2])" -eq 'off') $givenServer $givenName
        exit 0
    }
    if ($command -match '^voice(\s+(on|off))?$') {
        $set = $Matches[2]
        if ($set) {
            $on = $set.ToLowerInvariant() -eq 'on'
            $settings | Add-Member -NotePropertyName voice -NotePropertyValue $on -Force
            if ($on) {
                # Asks for the DLL again (Enter keeps it) and checks it now, so the next start does not ask.
                $client = if (Test-Client $settings.client) { $settings.client } else { '' }
                $picked = Select-VoiceDll $settings.voice_dll $client $true
                if ($picked.Hash) { $settings | Add-Member -NotePropertyName voice_dll -NotePropertyValue $picked.Dll -Force }
            }
            $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
        }
        $state = if ($null -eq $settings.voice) { 'not asked yet' } elseif ($settings.voice) { 'on' } else { 'off' }
        $dll = if ($settings.voice_dll -and (Test-Path -LiteralPath $settings.voice_dll -PathType Leaf)) { $settings.voice_dll } else { Get-DefaultVoiceDll }
        $found = if (Test-Path -LiteralPath $dll -PathType Leaf) { 'found' } else { 'missing (it comes with the server package)' }
        Write-Host "Voice chat: $state. Our ${voiceFile}: $dll ($found). Commands: join-roe-os.cmd voice on | off (on also asks for the DLL)"
        exit 0
    }
    if ($command -match '^(export|import)(\s+(.*))?$') {
        $action = $Matches[1].ToLowerInvariant()
        $file = "$($Matches[3])".Trim().Trim('"')
        if ($action -eq 'export') {
            if (-not $file) { $file = Join-Path (Get-Location).Path 'roe-join-accounts.json' }
            $file = [IO.Path]::GetFullPath($file)
            if ((Test-Path -LiteralPath $file) -and (Ask "$file exists. Overwrite it? (y/n)" 'n') -notmatch '^[yY]') { throw 'Cancelled.' }
            $done = Export-Accounts $joinRoot $settings $file
            Write-Host "Saved $($done.Accounts) accounts of $($done.Servers) servers in $file."
            Write-Host $backupWarning -ForegroundColor Yellow
            Write-Host 'On the other computer: join-roe-os.cmd import <file> (or python3 join-roe-os.py --import <file>).'
            exit 0
        }
        if (-not $file) { throw 'Usage: join-roe-os.cmd import FILE' }
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "No file: $file" }
        Write-Host $backupWarning -ForegroundColor Yellow
        $done = Import-Accounts $joinRoot $settings $file
        $settings | Add-Member -NotePropertyName servers -NotePropertyValue @($done.Servers) -Force
        $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
        Write-Host "Imported: $($done.Added) new accounts, $($done.Updated) updated (used more recently in the backup)."
        if ($done.Skipped.Count) { Write-Host "Skipped (another certificate): $($done.Skipped -join ', ')." }
        Write-Host 'You may delete the backup file now.'
        exit 0
    }
    if ($command -eq 'admin') {
        # The admin page (GM accounts): the server and the account as for a join, then the browser.
        $failed = 'Could not open the admin page: '
        $serverList = @(Get-OfferedServers $settings)
        $server = "$(Select-Server $serverList $givenServer)".Trim()
        if (-not $server) { throw 'A server address is needed.' }
        $hostName = Get-ServerHost $server
        $serverIp = (Resolve-ServerIps $hostName)[0]
        $folder = Get-AccountFolder $server
        $keyed = New-Object Collections.ArrayList
        foreach ($a in (Read-Accounts $folder)) { if ($a.token) { [void]$keyed.Add($a) } }
        if (-not $keyed.Count) { throw 'No saved account of this server. Join it once with your GM account first.' }
        $entry = Select-Account $keyed $givenName
        if (-not $entry) { throw $(if ($givenName) { "No saved account named $givenName for this server." } else { 'Choose a saved account: the admin page is for existing GM accounts.' }) }
        $link = Request-AdminLink $serverIp $folder $hostName $entry
        if ($link.Problem) { throw $link.Problem }
        Write-Host "Opening the admin page for $($entry.name) in your browser (the link works once, for one minute)."
        Start-Process $link.Url
        exit 0
    }
    if ($command) {
        if ($command -notmatch '^firewall(\s+(on|off|reset|status))?$') { throw $usage }
        $action = if ($Matches[2]) { $Matches[2].ToLowerInvariant() } else { 'status' }
        $client = $settings.client
        if ($action -eq 'status') { Show-Firewall $client $settings.firewall; exit 0 }
        if ($action -eq 'reset') { Reset-AllRules; exit 0 }
        $settings | Add-Member -NotePropertyName firewall -NotePropertyValue ($action -eq 'on') -Force
        $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
        if ($action -eq 'on') { Write-Host 'Firewall rules on: the next join creates them.'; exit 0 }
        Remove-FolderRules $client
        Write-Host 'Firewall rules off: join-roe-os.cmd no longer creates them (the game can reach the internet).'
        exit 0
    }
    Write-Host ('Ring of Elysium 2022: join a server' + $(if ($steamGame) { ' (started by Steam)' } else { '' }))
    Write-Host ''

    # 1. The game.
    # Always asked (Enter keeps the last one): a second game folder, for example XVersion,
    # lets a second player join from the same PC. Started by Steam: Steam's folder.
    if ($steamGame) {
        $client = Get-GameFolder (Get-SteamClient $steamGame.Folder "$($settings.client)")
    } else {
        $guess = $settings.client
        if (-not (Test-Client $guess)) { $guess = 'C:\Program Files (x86)\Steam\steamapps\common\Ring of Elysium' }
        if (-not (Test-Client $guess)) { $guess = '' }
        $client = Get-GameFolder (Ask 'Game folder (the one with Europa_Client.exe)' $guess)
    }
    Confirm-GameFiles $client $skipFileCheck

    # 2. Server and name.
    $serverList = @(Get-OfferedServers $settings)
    $given = if ($steamGame) { Get-SteamServer $settings $givenServer } else { $givenServer }
    $server = "$(Select-Server $serverList $given)".Trim()
    if (-not $server) { throw 'A server address is needed.' }
    $hostName = Get-ServerHost $server
    $firewall = $settings.firewall
    $voice = $settings.voice
    $voiceDll = $settings.voice_dll
    $serverList = Add-ServerUse $serverList $server
    function Save-Settings { Save-JoinSettings $client $firewall $voice $voiceDll $serverList }
    $voiceChoice = Get-VoiceChoice $voice $voiceDll $client ''
    $voice = $voiceChoice.Voice
    $voiceDll = $voiceChoice.Dll
    $voicePick = $voiceChoice.Pick
    Save-Settings
    $serverIps = Resolve-ServerIps $hostName
    $serverIp = $serverIps[0]

    # The server's name, version, where else the game goes for it and who plays where, before the
    # firewall rules. A server without an account service answers none.
    Write-Host ''
    Write-Host "Contacting ${serverIp} ..."
    $folder = Get-AccountFolder $server
    $contact = Connect-Server $serverIp $folder $serverIps
    if ($contact.Info -match '^OK ') {
        if (Set-ServerName $serverList $server $contact.Name) { Save-Settings }
        if ("$($serverList[0].name)") { Write-Host "Connected to $(Get-ServerLabel $serverList[0])" }
    }
    # Too old for the server: stop before the game starts.
    if ($contact.TooOld) { throw $contact.TooOld }
    if ($contact.Notice) { Write-Host $contact.Notice -ForegroundColor Yellow }
    if ($contact.Regions) { Write-Host $contact.Regions }

    # 3. Firewall (optional, asked once).
    if ($null -eq $firewall) {
        Write-Host ''
        Write-Host 'join-roe-os.cmd can add Windows Firewall rules so the game reaches only the servers you join'
        Write-Host '(it also tries the publisher''s old servers). That needs administrator approval when the allowed addresses change.'
        $firewall = (Ask 'Add the firewall rules? (y/n)' 'y') -match '^[yY]'
        Save-Settings
        Write-Host 'Change it later with: join-roe-os.cmd firewall on | off | reset'
    }
    $rules = Update-Firewall $client $serverList $server $serverIps $contact.Listed $firewall
    if ($rules.Check) { Confirm-FirewallState $client $rules.Programs $rules.Check.Wanted $rules.Check.RulesOn $rules.Check.Step }
    Save-Settings

    # 4. Log in.
    $accountList = Read-Accounts $folder
    if ($accountList.Count -and -not $givenName -and (Update-AccountNames $serverIp $folder $accountList)) { Save-Accounts $folder $accountList | Out-Null }
    if ($steamGame -and -not $givenName) {
        $steamPick = Get-SteamAccount $settings $server $accountList
        if (-not $steamPick.Found) { Write-Host 'The account join-roe-os.cmd steam-setup saved for Steam starts is no longer there. Choose one:' }
        $entry = if ($steamPick.Found) { $steamPick.Entry } else { Select-Account $accountList '' }
    } else {
        $entry = Select-Account $accountList $givenName
    }
    $login = Connect-Account $serverIp $folder $accountList $entry $givenName
    Save-Settings
    if ($login.Accounts) {
        $info = $null
        try { $info = Invoke-Account $serverIp $folder 'INFO' } catch { }
        $stats = $null
        try { $stats = Get-ServerStats $serverIp $folder } catch { }
        if ($info -match '^OK ') { Write-Host (Format-ServerNow $info $stats) }
    }

    # 5. The game (started by Steam: with what the player wrote after %command%).
    $extra = @()
    if ($steamGame) { $extra = @($steamGame.Extra) }
    $game = Start-Game $client $login.Uid $serverIp $voicePick $extra
    try {
        # While the game runs: the server's numbers every 30 s, in the window title and on one line
        # here that is written over each time.
        $width = 0
        while (-not $game.Process.WaitForExit(30000)) {
            if (-not $login.Accounts) { continue }
            $info = $null
            try { $info = Invoke-Account $serverIp $folder 'INFO' } catch { }
            if ($info -notmatch '^OK ') { continue }
            $stats = $null
            try { $stats = Get-ServerStats $serverIp $folder } catch { }
            $line = Format-ServerNow $info $stats
            try { $Host.UI.RawUI.WindowTitle = "Ring of Elysium: $line" } catch { }
            $text = "[{0:HH:mm}] {1}" -f (Get-Date), $line
            if (-not $width) { Write-Host '' }  # set apart from the lines above
            Write-Host ("`r" + $text.PadRight($width)) -NoNewline -ForegroundColor Cyan
            $width = [Math]::Max($width, $text.Length)
        }
        if ($width) { Write-Host '' }
    } finally {
        if ($game.VoiceOn) { Restore-Voice $client 15 | Out-Null }
    }
    exit 0
} catch {
    Write-Host ''
    Write-Host ($failed + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
