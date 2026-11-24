# join-roe-os.cmd's window without a window on screen: it loads join-roe-os.cmd (Source, copied to a .ps1) the
# way the window does at its start, its windows parse, the worker runspace takes work and asks questions
# through the event queue, and its server and play steps work against a fake account service.
# Prints OK or FAIL lines.
param([string]$Source, [string]$Base)
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { foreach ($e in $errors) { "FAIL parse: $e" }; exit 2 }
'OK parse'
foreach ($f in @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })) {
    . ([ScriptBlock]::Create($f.Extent.Text))
}
function Check([string]$Name, [bool]$Ok) { if ($Ok) { "OK $Name" } else { "FAIL $Name" } }
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$sync = [hashtable]::Synchronized(@{ Events = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]' })
$gui = @{}
function Next-Event([int]$Seconds = 20) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    $item = $null
    while ((Get-Date) -lt $deadline) { if ($sync.Events.TryDequeue([ref]$item)) { return $item }; Start-Sleep -Milliseconds 20 }
    return $null
}

# join-roe-os.cmd without its main part (the console's and the window's), Write-Host and Ask replaced.
$damaged = Join-Path $Base 'damaged.ps1'
Set-Content -LiteralPath $damaged -Value 'function Broken {'
$stop = ''
try { Get-JoinCode $damaged | Out-Null } catch { $stop = $_.Exception.Message }
Check 'damaged file' ($stop -like 'damaged.ps1 is damaged (line 1*Download it again.')
$code = Get-JoinCode $Source
Check 'join code' ($code -match 'function Invoke-Login' -and $code -match '\$expectedSha = ' -and $code -match 'function Start-Gui' -and $code -notmatch 'Ring of Elysium 2022: join a server''' -and
    $code -notmatch 'Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms' -and $code -notmatch 'ROE_JOIN_WINDOW' -and
    $code.IndexOf('function Ask(') -ge 0 -and $code.LastIndexOf('function Ask {') -gt $code.IndexOf('function Ask(') -and $code.LastIndexOf('function Write-Host {') -gt 0)
$env:ROE_JOIN_SELF = Join-Path $Base 'join-roe-os.cmd'
. ([ScriptBlock]::Create($code))
Check 'loaded' ($joinVersion -and (Get-Command Connect-Server -CommandType Function) -and (Get-Command Write-Host).CommandType -eq 'Function')

# join-roe-os.cmd's messages become events.
Write-Host 'Voice chat: on.'
Write-Host 'It failed.' -ForegroundColor Yellow
Write-Host ''
$first = Next-Event 1; $second = Next-Event 1
Check 'lines' ($first.Kind -eq 'line' -and $first.Data.Text -eq 'Voice chat: on.' -and $first.Data.Level -eq 'info' -and $second.Data.Level -eq 'warn' -and $null -eq (Next-Event 0))

# The windows parse and have every control.
$contrastWindow = [Windows.Markup.XamlReader]::Parse((Get-GuiXaml $true))
$contrastDialog = [Windows.Markup.XamlReader]::Parse((Get-InputXaml $true))
$gui.Window = $contrastWindow
$play = $contrastWindow.FindName('PlayButton')
$status = $contrastWindow.FindName('StatusText')
Set-Text $status 'Test warning' warn
Check 'Windows contrast colors in both windows and status messages' ($contrastDialog.Background.Color -eq [Windows.SystemColors]::WindowColor -and
    $contrastWindow.Foreground.Color -eq [Windows.SystemColors]::WindowTextColor -and $play.Background.Color -eq [Windows.SystemColors]::HighlightColor -and
    $play.Foreground.Color -eq [Windows.SystemColors]::HighlightTextColor -and $status.Foreground.Color -eq [Windows.SystemColors]::WindowTextColor)
$window = [Windows.Markup.XamlReader]::Parse((Get-GuiXaml))
$gui.C = @{}
foreach ($name in (Get-GuiControlNames)) { $gui.C[$name] = $window.FindName($name) }
Check 'main window' (@($gui.C.Values | Where-Object { $null -eq $_ }).Count -eq 0 -and $gui.C.Count -eq (Get-GuiControlNames).Count)
# Before the administrator prompt the worker brings the window to the front (the prompt comes up in
# front only for the window in front), out of the taskbar when minimized.
$gui.Window = $window
$window.WindowState = 'Minimized'
$sync.Events.Enqueue([pscustomobject]@{ Kind = 'front'; Data = $null })
Receive-GuiEvents
Check 'front event' ("$($window.WindowState)" -eq 'Normal' -and $sync.Events.IsEmpty)
$gui.Window = $null
$gui.Window = $window
$gui.Languages = Get-GuiLanguages
Set-GuiLanguage 'en'
Set-GuiServerStatus "[12:00] On the server now: EU (normal): 1 online, 0 searching, 2 matches`nNA (normal): offline."
$table = $gui.C.RegionTable
$eu, $na = $table.ItemsSource
Check 'server table: no modes, offline' ($eu.Modes -ceq '' -and $na.Modes -ceq '-' -and $na.Queued -ceq '-')
Set-GuiServerStatus (Get-ServerInfoText ([pscustomobject]@{ Info = 'OK players=3'; TooOld = ''; Notice = $null
    Regions = (Format-Stats 'OK 7,normal,3,3,0,EU%20SERVER,up,solo-tpp:2;squad-fpp:1') })).Text
Check 'server table: modes' ($table.Items.Count -eq 1 -and $table.Items[0].Queued -ceq '3' -and $table.Items[0].Modes -ceq 'solo 2, squad FPP 1' -and $table.Items[0].Games -ceq '0' -and
    $gui.C.ServerStats.Text -ceq '')
Set-GuiServerStatus "[12:00] On the server now: EU (normal): 1 online, 0 searching, 2 matches`nNA (normal): offline."
$eu, $na = $table.ItemsSource
Check 'server table: read-only region counts and offline state' ($table.Items.Count -eq 2 -and $table -isnot [Windows.Controls.Primitives.Selector] -and
    -not $table.Focusable -and -not $table.IsTabStop -and $eu.Region -eq 'EU (normal)' -and $eu.Online -eq '1' -and $eu.Queued -eq '0' -and
    $eu.Games -eq '2' -and -not $eu.Offline -and $na.Region -eq 'NA (normal)' -and $na.Offline -and $na.Online -eq 'Offline' -and $gui.C.ServerStats.Text -eq '[12:00]')
Set-GuiLanguage 'fr'
Check 'language switch refreshes the current status' ($table.Items[1].Online -ceq 'Hors ligne' -and $gui.C.VoiceLabel.Text -ceq 'Chat vocal')
Set-GuiLanguage 'en'
Set-GuiServerStatus 'Contacting x ...' 'muted'
Check 'server table: plain text again' ($table.Items.Count -eq 0 -and $table.Visibility -eq 'Collapsed' -and $gui.C.ServerStats.Text -ceq 'Contacting x...')
# The voice chat box toggles only on the box: no content, its label a separate TextBlock, and a hit
# on the label or the empty row lands outside the box (laid out without showing the window).
function Get-Ancestors($Element, [switch]$Visual) {
    $list = New-Object System.Collections.ArrayList
    $parent = $Element
    while ($null -ne $parent) {
        $parent = if ($Visual) { [Windows.Media.VisualTreeHelper]::GetParent($parent) } else { [Windows.LogicalTreeHelper]::GetParent($parent) }
        if ($null -ne $parent) { [void]$list.Add($parent) }
    }
    return ,$list
}
function Test-HitsVoiceBox([double]$X, [double]$Y) {
    $hit = [Windows.Media.VisualTreeHelper]::HitTest($root, [Windows.Point]::new($X, $Y))
    if (-not $hit) { return $false }
    return [object]::ReferenceEquals($hit.VisualHit, $gui.C.VoiceBox) -or (Get-Ancestors $hit.VisualHit -Visual).Contains($gui.C.VoiceBox)
}
$root = $window.Content
$root.Measure([Windows.Size]::new(532, [double]::PositiveInfinity))
$root.Arrange([Windows.Rect]::new(0, 0, 532, $root.DesiredSize.Height))
$root.UpdateLayout()
$box = $gui.C.VoiceBox.TranslatePoint([Windows.Point]::new(0, 0), $root)
$label = $gui.C.VoiceLabel.TranslatePoint([Windows.Point]::new(0, 0), $root)
$button = $gui.C.VoiceButton.TranslatePoint([Windows.Point]::new(0, 0), $root)
$middle = $box.Y + $gui.C.VoiceBox.ActualHeight / 2
$labelMiddle = $label.Y + $gui.C.VoiceLabel.ActualHeight / 2
Check 'check box: only the box' ($null -eq $gui.C.VoiceBox.Content -and $gui.C.VoiceLabel.Text -eq 'Voice chat' -and $gui.C.VoiceBox.ActualWidth -gt 0 -and $gui.C.VoiceBox.ActualWidth -lt 30 -and
    (Test-HitsVoiceBox ($box.X + $gui.C.VoiceBox.ActualWidth / 2) $middle) -and -not (Test-HitsVoiceBox ($label.X + 3) $labelMiddle) -and
    -not (Test-HitsVoiceBox ($button.X - 10) $middle) -and $label.X -ge ($box.X + $gui.C.VoiceBox.ActualWidth))
Check 'no Steam part' ((Get-GuiXaml) -notmatch 'Steam[A-Z]' -and -not $gui.C.AdvancedBox.IsExpanded -and
    (Get-Ancestors $gui.C.AdminButton).Contains($gui.C.AdvancedBox) -and -not (Get-Ancestors $gui.C.PlayButton).Contains($gui.C.AdvancedBox))
$dialog = [Windows.Markup.XamlReader]::Parse((Get-InputXaml))
Check 'input dialog' ($dialog.FindName('AnswerBox') -and $dialog.FindName('OkButton') -and $dialog.FindName('PromptText'))
# While the game runs the admin page still opens (its own worker); not twice at once.
$gui.Playing = $true; $gui.GameRunning = $true; $gui.SideJob = $null
Update-Controls
$ok = $gui.C.AdminButton.IsEnabled -and -not $gui.C.PlayButton.IsEnabled -and -not $gui.C.AccountBox.IsEnabled -and "$($gui.C.PlayButton.Content)" -eq 'Game running'
$gui.SideJob = 'Invoke-AdminJob'
Update-Controls
Check 'admin while playing' ($ok -and -not $gui.C.AdminButton.IsEnabled)
$gui.Playing = $false; $gui.GameRunning = $false; $gui.SideJob = $null
# The admin page's part: hidden until the selected account is a GM on the selected server.
Check 'admin part hidden' ("$($gui.C.AdminPanel.Visibility)" -eq 'Collapsed')
$ga = 'a' * 64; $gb = 'b' * 64
$gui.Servers = @([pscustomobject]@{ address = 'a.example' })
[void]$gui.C.ServerBox.Items.Add('a.example')
$gui.C.ServerBox.SelectedIndex = 0
$gui.Accounts = @([pscustomobject]@{ name = 'Anna'; token = $ga }, [pscustomobject]@{ name = 'Ben'; token = $gb })
foreach ($n in @('Anna', 'Ben', 'Create a new account')) { [void]$gui.C.AccountBox.Items.Add($n) }
$gui.C.AccountBox.SelectedIndex = 0
$gui.Roles = @{ $ga = 'gm'; $gb = 'player' }
$gui.RolesServer = 'a.example'
Update-AdminPanel
$shown = "$($gui.C.AdminPanel.Visibility)"
$gui.C.AccountBox.SelectedIndex = 1
Update-AdminPanel
$player = "$($gui.C.AdminPanel.Visibility)"
$gui.C.AccountBox.SelectedIndex = 2
Update-AdminPanel
$new = "$($gui.C.AdminPanel.Visibility)"
$gui.C.AccountBox.SelectedIndex = 0
$gui.RolesServer = 'b.example'
Update-AdminPanel
$other = "$($gui.C.AdminPanel.Visibility)"
Check 'admin part: GM only' ($shown -eq 'Visible' -and $player -eq 'Collapsed' -and $new -eq 'Collapsed' -and $other -eq 'Collapsed')
Check 'admin shown' ((Test-ShowAdmin @{ $ga = 'gm' } ([pscustomobject]@{ token = $ga })) -and -not (Test-ShowAdmin @{ $ga = 'player' } ([pscustomobject]@{ token = $ga })) -and
    (Test-ShowAdmin @{ $ga = 'admin' } ([pscustomobject]@{ token = $ga })) -and
    -not (Test-ShowAdmin $null ([pscustomobject]@{ token = $ga })) -and -not (Test-ShowAdmin @{ $ga = 'gm' } $null) -and -not (Test-ShowAdmin @{ '' = 'gm' } ([pscustomobject]@{ token = '' })))
$gui.Servers = @(); $gui.Accounts = @(); $gui.Roles = $null; $gui.RolesServer = ''

# The game folder: the Ring of Elysium folder and the DirectX 12 box (its XVersion folder).
$both = Join-Path $Base 'roe-both'; $dx11 = Join-Path $Base 'roe-dx11'; $dx12 = Join-Path $Base 'roe-dx12'
foreach ($f in @((Join-Path $both 'Europa_Client.exe'), (Join-Path $both 'XVersion\Europa_Client.exe'), (Join-Path $dx11 'Europa_Client.exe'), (Join-Path $dx12 'XVersion\Europa_Client.exe'))) {
    New-Item -ItemType File -Force -Path $f | Out-Null
}
$s1 = Split-GameFolder (Join-Path $both 'XVersion'); $s2 = Split-GameFolder "$both\"; $s3 = Split-GameFolder ''
Check 'game folder: split' ($s1.Base -eq $both -and $s1.Dx12 -and $s2.Base -eq $both -and -not $s2.Dx12 -and $s3.Base -eq '' -and -not $s3.Dx12)
$c1 = Get-GameFolderChoice $both $true; $c2 = Get-GameFolderChoice $both $false
Check 'game folder: both versions' ($c1.Folder -eq (Join-Path $both 'XVersion') -and -not $c1.Problem -and $c2.Folder -eq $both -and -not $c2.Problem)
$c3 = Get-GameFolderChoice $dx11 $true; $c4 = Get-GameFolderChoice $dx12 $false; $c5 = Get-GameFolderChoice (Join-Path $Base 'nothing') $false
Check 'game folder: what is missing' (-not $c3.Folder -and $c3.Problem -like "No DirectX 12 version found in $dx11*uncheck DirectX 12." -and
    -not $c4.Folder -and $c4.Problem -like "No DirectX 11 version found in $dx12*tick DirectX 12*" -and -not $c5.Folder -and $c5.Problem -like 'No Europa_Client.exe in *')
$gui.GameBase = $dx12; $gui.Dx12 = $true
Update-GameFolder
$ok = $gui.Client -eq (Join-Path $dx12 'XVersion') -and $gui.C.Dx12Box.IsChecked -and $gui.C.GameBox.Text -eq $dx12
$gui.Dx12 = $false
Update-GameFolder
Check 'game folder: the window' ($ok -and $gui.Client -eq '' -and -not $gui.C.Dx12Box.IsChecked -and $gui.C.GameNote.Text -like 'No DirectX 11 version found*')
$gui.GameBase = ''; $gui.Dx12 = $false; $gui.Client = ''
$gui.C.ServerBox.Items.Clear(); $gui.C.AccountBox.Items.Clear()

# The worker: work in the background, its questions answered here.
$worker = New-Worker $code
[void]$worker.AddCommand('Invoke-Work').AddParameter('Command', 'Get-ServerHost').AddParameter('Arguments', @{ Server = 'play.example:8001' })
$handle = $worker.BeginInvoke()
$done = Next-Event
[void]$worker.EndInvoke($handle)
Check 'worker work' ($done.Kind -eq 'done' -and $done.Data.Ok -and $done.Data.Result -eq 'play.example')
$worker.Commands.Clear()
[void]$worker.AddCommand('Invoke-Work').AddParameter('Command', 'Get-ServerHost').AddParameter('Arguments', @{ Server = 'play.example:8001' }).AddParameter('Event', 'side-done')
$handle = $worker.BeginInvoke()
$done = Next-Event
[void]$worker.EndInvoke($handle)
Check 'side worker event' ($done.Kind -eq 'side-done' -and $done.Data.Ok -and $done.Data.Result -eq 'play.example')
$worker.Commands.Clear()
[void]$worker.AddCommand('Invoke-Work').AddParameter('Command', 'Get-ServerHost').AddParameter('Arguments', @{ Server = 'play.example:9' })
$handle = $worker.BeginInvoke()
$done = Next-Event
[void]$worker.EndInvoke($handle)
Check 'worker error' ($done.Kind -eq 'done' -and -not $done.Data.Ok -and $done.Data.Message -like 'The game only connects to port 8001*' -and $done.Data.Details)
$worker.Commands.Clear()
[void]$worker.AddCommand('Invoke-Work').AddParameter('Command', 'Ask-Name').AddParameter('Arguments', @{ Default = '' })
$handle = $worker.BeginInvoke()
$ask = Next-Event
$ask.Data.Answer = 'Zoe'
$ask.Data.Done.Set()
$done = Next-Event
[void]$worker.EndInvoke($handle)
Check 'worker asks' ($ask.Kind -eq 'ask' -and $ask.Data.Question -like 'Your name*' -and $done.Data.Ok -and $done.Data.Result -eq 'Zoe')
$worker.Commands.Clear()
[void]$worker.AddCommand('Invoke-Work').AddParameter('Command', 'Ask-Name').AddParameter('Arguments', @{ Default = '' })
$handle = $worker.BeginInvoke()
$ask = Next-Event
$ask.Data.Cancelled = $true
$ask.Data.Done.Set()
$done = Next-Event
[void]$worker.EndInvoke($handle)
Check 'cancel stops' (-not $done.Data.Ok -and $done.Data.Message -eq 'Cancelled.')
$worker.Runspace.Dispose()
$worker.Dispose()

# The firewall text and the server line.
$text = (Get-GuiFirewallText @('no join-roe-os.cmd rule for 2 of 2 game programs') (Get-ElevationNote ([pscustomobject]@{ Ok = $false; Reason = 'declined'; Detail = '' })) @() $false) -join "`n"
Check 'firewall text' ($text -like 'The firewall rules could not be set. Windows did not ask for administrator rights, or the prompt was declined: right-click*' -and $text -match 'Right-click join-roe-os\.cmd > Run as administrator' -and
    $text -match 'off under Advanced' -and $text -match '- no join-roe-os\.cmd rule')
$text = (Get-GuiFirewallText @(1..7 | ForEach-Object { "problem $_" }) '' @([pscustomobject]@{ Local = $false }) $true) -join "`n"
Check 'firewall text: policy, admin' ($text -like 'The firewall rules are not as they should be*' -and $text -match 'and 2 more' -and $text -match 'policy or security product' -and $text -notmatch 'Right-click')
$line = Get-ServerInfoText ([pscustomobject]@{ Info = 'OK players=2'; TooOld = ''; Notice = $null; Regions = 'EU (normal): 2 online, 0 searching, 0 matches | AS (duel): 0 online, 0 searching, 0 matches' })
Check 'server line' ($line.Level -eq 'info' -and $line.Text -eq "EU (normal): 2 online, 0 searching, 0 matches`nAS (duel): 0 online, 0 searching, 0 matches")
$line = Get-ServerInfoText ([pscustomobject]@{ Info = 'OK players=2 matches=1 waiting=0'; TooOld = ''; Notice = 'A newer join-roe-os.cmd'; Regions = '' })
Check 'server line: older server' ($line.Level -eq 'warn' -and $line.Text -like "A newer join-roe-os.cmd`nOn the server now: 2 players online, 1 match running*")
Check 'server line: no service, too old' ((Get-ServerInfoText ([pscustomobject]@{ Info = $null })).Text -like 'No answer from the account service*' -and
    (Get-ServerInfoText ([pscustomobject]@{ Info = 'OK'; TooOld = 'This join-roe-os.cmd is version 0.9' })).Level -eq 'error')

# Settings: changed values, the others kept.
$settingsPath = Join-Path $Base 'roe-join.json'
$joinRoot = Join-Path $Base 'roe-join'
Save-JoinSettings 'C:\Game' $true $false 'C:\voice\GCloudVoice.dll' @([pscustomobject]@{ address = 'a.example'; last_used = 5; name = ''; addresses = [string[]]@(); ips = [string[]]@() })
Update-Settings @{ voice = $true }
$read = Read-Settings
Check 'settings changed' ($read.voice -eq $true -and $read.firewall -eq $true -and $read.client -eq 'C:\Game' -and $read.voice_dll -eq 'C:\voice\GCloudVoice.dll' -and $read.servers[0].address -eq 'a.example')

Update-Settings @{ voice_dll = ''; voice = $true }
Update-Voice
Check 'voice: missing file has a visible download link' ($gui.C.VoiceStatus.Text -eq 'DLL missing' -and $gui.C.VoiceNote.Visibility -eq 'Visible' -and
    @($gui.C.VoiceNote.Inlines | Where-Object { $_ -is [Windows.Documents.Hyperlink] }).Count -eq 1)
Update-Settings @{ voice_dll = $settingsPath }
Update-Voice
Check 'voice: existing unusable file' ($gui.C.VoiceStatus.Text -eq 'DLL unavailable' -and $gui.C.VoiceNote.Text -like '*64-bit*')
Update-Settings @{ voice_dll = (Join-Path $Base 'valid-voice.dll') }
Update-Voice
Check 'voice: validated file is ready before launch' ($gui.C.VoiceStatus.Text -eq 'Ready' -and $gui.C.VoiceNote.Text -like '*valid-voice.dll*')
Update-Settings @{ voice = $false }
Update-Voice
Check 'voice: turned off with a valid file' ($gui.C.VoiceStatus.Text -eq 'Off' -and $gui.C.VoiceNote.Visibility -eq 'Collapsed')
# The first start (no saved servers): roe-os.de selected; a server added keeps it in the list.
Save-JoinSettings '' $null $null $null @()
Update-ServerList ''
$first = @($gui.C.ServerBox.Items) -join ','
$selected = Get-SelectedServer
$gui.Servers = @(Add-ServerUse @(Get-OfferedServers (Read-Settings)) 'b.example' 7)
Check 'first start: roe-os.de' ($first -eq 'ROE-OS (roe-os.de)' -and $selected -eq 'roe-os.de' -and $gui.C.AccountBox.Items.Count -eq 1 -and
    (@($gui.Servers | ForEach-Object { $_.address }) -join ',') -eq 'b.example,roe-os.de' -and $gui.Servers[1].name -eq 'ROE-OS')
$gui.Servers = @(); $gui.C.ServerBox.Items.Clear(); $gui.C.AccountBox.Items.Clear()

# The server step against a fake account service: name, regions, renamed accounts.
$global:Replies = @{}
$global:Sent = New-Object System.Collections.ArrayList
function Invoke-Account([string]$Ip, [string]$Folder, [string]$Line) { [void]$global:Sent.Add($Line); return $global:Replies[$Line] }
$t1 = 'a' * 64; $t2 = 'b' * 64
$folder = Get-AccountFolder '127.0.0.5'
Save-Accounts $folder ([System.Collections.ArrayList]@([pscustomobject]@{ name = 'newaccount1234'; token = $t1; last_used = 9 })) | Out-Null
$global:Replies = @{ 'INFO' = 'OK players=1 name=Test%20Server'; 'VERSION' = 'OK min=0 current=0'; 'STATS' = 'OK 7,normal,1,0,0,EU'; "NAME $t1" = 'OK Anna' }
$r = Invoke-ServerJob '127.0.0.5'
Check 'server step' ($r.Contact.Name -eq 'Test Server' -and $r.Contact.Regions -like 'EU (normal)*' -and $global:Sent -notcontains 'ADDRESSES' -and (Read-Accounts $folder)[0].name -eq 'Anna')
Check 'server step: no role' ($global:Sent -contains "ROLE $t1" -and $r.Roles.Count -eq 0)
$global:Replies["ROLE $t1"] = 'OK gm'
$r = Invoke-ServerJob '127.0.0.5'
Check 'server step: roles' ($r.Roles[$t1] -eq 'gm' -and $r.Roles.Count -eq 1)
# The region table's refresh: STATS alone, as the server line shows it.
$statsCache = @{}
$global:Sent.Clear()
$global:Replies['STATS'] = 'OK 7,normal,4,3,0,EU%20SERVER,up,solo-tpp:3'
$r = Invoke-StatsJob '127.0.0.5'
Check 'stats job' ($r.Server -eq '127.0.0.5' -and $r.Regions -ceq 'EU (normal): 4 online, 3 searching (solo 3), 0 matches' -and ($global:Sent -join ',') -eq 'STATS')
# Open the admin page: the link of the server's address in the browser; refused for a player.
function Start-Process { param([Parameter(Position = 0)]$FilePath) $global:Opened = "$FilePath" }
$global:Replies["WEB $t1"] = "OK $('c' * 64) https%3A%2F%2Fadmin.example.org"
$url = Invoke-AdminJob '127.0.0.5' $t1
Check 'admin job' ($url -eq "https://admin.example.org/login?ticket=$('c' * 64)" -and $global:Opened -eq $url)
$global:Replies["ROLE $t1"] = 'OK player'
$stop = ''
try { Invoke-AdminJob '127.0.0.5' $t1 | Out-Null } catch { $stop = $_.Exception.Message }
Check 'admin job: no GM' ($stop -eq 'This account has no GM rights on this server.')

# The play step with the game and the firewall replaced: the saved account by its key, the server's
# name saved, the game event, the voice DLL left alone without voice.
function Get-GameFolder([string]$Folder) { return $Folder }
function Confirm-GameFiles([string]$Client, [bool]$Skip) { $global:FilesChecked = @($Client, $Skip) }
function Update-Firewall([string]$Client, $ServerList, [string]$Server, [string[]]$ServerIps, $Listed, [bool]$Firewall) {
    $global:Firewall = @($Server, (@($Listed) -join ','), $Firewall)
    Set-ServerAddresses $ServerList $Server $Listed ([string[]]@())
    return [pscustomobject]@{ Programs = @(); Check = $null }
}
function Start-Game([string]$Client, [string]$Uid, [string]$Ip, $VoicePick) {
    $global:Started = @($Client, $Uid, $Ip, $VoicePick)
    $process = [pscustomobject]@{}
    $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($ms) $true }
    return [pscustomobject]@{ Process = $process; VoiceOn = $false }
}
Save-Accounts $folder ([System.Collections.ArrayList]@([pscustomobject]@{ name = 'Anna'; token = $t1; last_used = 9 }, [pscustomobject]@{ name = 'Ben'; token = $t2; last_used = 8 })) | Out-Null
$global:Replies = @{ 'INFO' = 'OK players=1 name=Test%20Server'; 'VERSION' = 'OK min=0 current=0'; 'ADDRESSES' = 'OK 198.51.100.7'; 'STATS' = 'OK'; "LOGIN2 $t2" = 'OK 77 Ben' }
Save-JoinSettings 'C:\Game' $false $true $null @()
$name = Invoke-PlayJob (Join-Path $Base 'game') '127.0.0.5' $t2 'Ben' $false $false
$events = @(); $item = $null
while ($sync.Events.TryDequeue([ref]$item)) { $events += $item }
$read = Read-Settings
Check 'play step' ($name -eq 'Ben' -and $global:FilesChecked[0] -eq (Join-Path $Base 'game') -and $global:FilesChecked[1] -eq $false -and$global:Started[1] -eq '77' -and $global:Started[2] -eq '127.0.0.5' -and $null -eq $global:Started[3] -and
    $global:Firewall[1] -eq '198.51.100.7' -and $global:Firewall[2] -eq $false -and @($events | Where-Object { $_.Kind -eq 'game' -and $_.Data -eq $false }).Count -eq 1)
Check 'play saves' ($read.servers[0].address -eq '127.0.0.5' -and $read.servers[0].name -eq 'Test Server' -and $read.voice -eq $true -and
    (@($read.servers[0].addresses) -join ',') -eq '198.51.100.7' -and (Read-Accounts $folder)[0].name -eq 'Ben')
$stop = ''
try { Invoke-PlayJob (Join-Path $Base 'game') '127.0.0.5' ('c' * 64) 'Gone' $false $false | Out-Null } catch { $stop = $_.Exception.Message }
Check 'play: account gone' ($stop -like 'The account Gone is no longer saved for this server*')
$global:Replies['VERSION'] = 'OK min=9 current=9'
$stop = ''
try { Invoke-PlayJob (Join-Path $Base 'game') '127.0.0.5' $t2 'Ben' $false $false | Out-Null } catch { $stop = $_.Exception.Message }
Check 'play: too old' ($stop -like 'This join-roe-os.cmd is version*Download the new join-roe-os.cmd*')
$global:Replies['VERSION'] = 'OK min=0 current=0'
$item = $null
while ($sync.Events.TryDequeue([ref]$item)) { }

# Play in the window (dialogs and work replaced): the selected account and game folder go to the
# play step; the window stays open after the game.
function Write-GuiLog([string]$Text) { }
$global:Shown = New-Object System.Collections.ArrayList
function Show-Message { param($Text, $Buttons, $Icon, $Default) [void]$global:Shown.Add("$Text"); return 'No' }
$global:Work = New-Object System.Collections.ArrayList
function Start-Work([string]$Command, [hashtable]$Arguments, [scriptblock]$OnDone) { [void]$global:Work.Add([pscustomobject]@{ Command = $Command; Arguments = $Arguments; OnDone = $OnDone }) }
$gui.Window = $window
$gui.Recent = New-Object System.Collections.ArrayList
$gui.Playing = $false; $gui.GameRunning = $false
Update-Settings @{ client = (Join-Path $both 'XVersion'); firewall = $false }
$split = Split-GameFolder (Join-Path $both 'XVersion')
$gui.GameBase = $split.Base; $gui.Dx12 = $split.Dx12
Update-GameFolder
Update-ServerList '127.0.0.5'
$gui.C.AccountBox.SelectedIndex = [array]::IndexOf(@($gui.Accounts | ForEach-Object { $_.name }), 'Anna')
$gui.C.VoiceBox.IsChecked = $false
# While the window is open: the selected server's table again (STATS), its notice kept; not while a
# game is joined, other work waits or the server answered no STATS; an answer for another server or
# an empty one changes nothing.
$gui.Queue = New-Object System.Collections.ArrayList
$gui.Job = $null
$gui.Contact = [pscustomobject]@{ Info = 'OK players=1'; TooOld = ''; Notice = 'A newer join-roe-os.cmd is out.'; Regions = 'EU (normal): 1 online, 0 searching, 0 matches' }
$gui.ContactServer = Get-SelectedServer
Update-GuiStats
$w = $global:Work[$global:Work.Count - 1]
Check 'refresh: stats job' ($global:Work.Count -eq 1 -and $w.Command -eq 'Invoke-StatsJob' -and $w.Arguments.Server -eq '127.0.0.5')
& $w.OnDone ([pscustomobject]@{ Ok = $true; Result = [pscustomobject]@{ Server = '127.0.0.5'; Regions = 'EU (normal): 4 online, 3 searching (solo 3), 0 matches' } })
$row = $gui.C.RegionTable.Items[0]
Check 'refresh: table and notice' ($row.Online -ceq '4' -and $row.Queued -ceq '3' -and $row.Modes -ceq 'solo 3' -and $gui.C.ServerStats.Text -ceq 'A newer join-roe-os.cmd is out.')
& $w.OnDone ([pscustomobject]@{ Ok = $true; Result = [pscustomobject]@{ Server = 'b.example'; Regions = 'EU (normal): 9 online, 0 searching, 0 matches' } })
& $w.OnDone ([pscustomobject]@{ Ok = $true; Result = [pscustomobject]@{ Server = '127.0.0.5'; Regions = '' } })
& $w.OnDone ([pscustomobject]@{ Ok = $false; Message = 'no answer' })
Check 'refresh: other server, empty or failed kept' ($gui.C.RegionTable.Items[0].Online -ceq '4')
$gui.Playing = $true; Update-GuiStats; $gui.Playing = $false
[void]$gui.Queue.Add('waiting'); Update-GuiStats; $gui.Queue.Clear()
$gui.ContactServer = 'b.example'; Update-GuiStats; $gui.ContactServer = '127.0.0.5'
$gui.Contact.Regions = ''; Update-GuiStats
Check 'refresh: not while joining, busy, for another server or without STATS' ($global:Work.Count -eq 1)
$global:Work.Clear()
Start-Play
$w = $global:Work[0]
Check 'play: the selected account' ($w.Command -eq 'Invoke-PlayJob' -and $w.Arguments.Token -ceq $t1 -and $w.Arguments.Client -eq (Join-Path $both 'XVersion') -and
    -not $w.Arguments.UseVoice -and -not $w.Arguments.ContainsKey('Extra') -and $gui.Playing -and -not $global:Shown.Count)
$global:Closing = $false
$window.Add_Closing({ $global:Closing = $true })
Send-GuiEvent 'game' $false
Receive-GuiEvents
Check 'voice: skipped for the running game' ($gui.C.VoiceStatus.Text -eq 'Off for this game')
Send-GuiEvent 'game' $true
Receive-GuiEvents
Set-GuiLanguage 'da'
Check 'voice: active session follows the language switch' ($gui.C.VoiceStatus.Text -eq 'Aktiv i spillet')
Set-GuiLanguage 'en'
& $w.OnDone ([pscustomobject]@{ Ok = $true; Result = 'Anna' })
Check 'game exit: the window stays' (-not $global:Closing -and -not $gui.Playing -and $gui.C.StatusText.Text -eq 'The game has exited.' -and $gui.C.VoiceStatus.Text -eq 'Off')
