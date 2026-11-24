# Changelog

Newest first. Each entry says what changed for someone playing. The version is the join
scripts' (`$joinVersion` in join-roe-os.cmd, `JOIN_VERSION` in join-roe-os.py); a server can ask for a newer
one (`roe_server set join-min-version`). The server's own changes are in its repository's
CHANGELOG.md.

## Unreleased

- The administrator prompt for the firewall rules comes up in front again. It was started without
  a window to belong to (from the window's hidden PowerShell), so Windows could leave it behind
  other windows or as a flashing button in the taskbar, and players saw no prompt. Now it belongs
  to the join window (or the console), which comes to the front first; the step runs in a normal
  window. When Windows does not ask or the prompt is declined, join-roe-os.cmd says so ("Windows
  did not ask for administrator rights: right-click join-roe-os.cmd > Run as administrator once")
  and offers to try again. The same in with-steam/join-roe-os.cmd.
- with-steam/join-roe-os.cmd: the join script with Start through Steam (the version before its
  removal) for players whose virus scanner does not flag it; the main join-roe-os.cmd stays without it.
- Steam's Play button can open the join window again, set up by hand: the launch option
  `"<path>\join-roe-os.cmd" --window %command%` (README, "Start it from Steam"). `--window` with
  more after it now opens the window; the window ignores Steam's game command and starts the game
  itself. join-roe-os.cmd does not touch Steam's settings.
- Start through Steam is removed from join-roe-os.cmd, for virus scanners: no `steam-setup`, no
  **Set up starting through Steam** section in the window, no changes to Steam's settings
  (localconfig.vdf), no closing or starting of Steam. The window's PowerShell starts hidden
  (`-WindowStyle Hidden`, as the old join-gui.cmd did), so no console waits in the taskbar next to
  the window. If you had set it up, remove the line from Steam's launch
  options (Ring of Elysium > Properties > General) and start join-roe-os.cmd yourself.
  separate-files/ is gone: the single file passes the scanners now. On Linux,
  `python3 join-roe-os.py --steam-setup` stays.
- For virus scanners that still flag join-roe-os.cmd: **separate-files/** has the same thing as
  three plain files, `join-roe-os-window.cmd` (the window), `join-roe-os.cmd` (window or console,
  as the single file) and `join-roe-os.ps1` (the PowerShell code). Download all three into one
  folder and start join-roe-os-window.cmd. Same features, accounts and settings; Start through
  Steam from there names join-roe-os-window.cmd (Set up once more after switching).
- The join scripts are renamed: **join-roe-os.cmd** (was join.cmd) and **join-roe-os.py** (was
  join.py). Old copies keep working against the server, with the same saved accounts, keys,
  settings and Steam profile (`%APPDATA%\roe-join`, `~/.config/roe-join`). Start through Steam
  set up with the old name still counts as ours: the window shows it as set up for another copy,
  and **Set up** (or `steam-setup`) replaces the line with one for the new file. After
  downloading join-roe-os.cmd (and setting up Steam again, if you use it) you can delete
  join.cmd.

- join.cmd starts PowerShell in a plainer way, so that virus scanners take it less often for
  malware: it runs a `.ps1` copy of itself (`%APPDATA%\roe-join\run-*.ps1`, removed again
  later) with `-ExecutionPolicy RemoteSigned` instead of reading its own text with
  `-ExecutionPolicy Bypass -WindowStyle Hidden`, and the firewall step as administrator reads the
  rules from a data file instead of running generated script text. Everything works as before.
- Started through Steam, no empty console window stays open while the game runs: the window
  hides the console it was started from (also in Windows Terminal, the default terminal on
  Windows 11, which before only minimized it, or not at all). Steam still sees the game running
  until it exits.

## 1.0 (2026-11-20)

- A region that is down (it takes no new match, the game greys it out) shows as offline: the
  window's server line has "NA (normal): offline" in grey on its own line, join.cmd's console and
  join.py print it the same way in "On the server now". It needs a server from 2026-11-20 on; older
  servers show every region with its numbers as before.
- The window's voice chat box (and the box for Steam's auto start) only toggles on a click on the
  box itself, no longer on its text or the empty space next to it. Space still toggles it.
- Start through Steam has its own section in the window, **Set up starting through Steam**
  (folded at first, no longer under **Advanced**). It says what it does and shows the launch
  option line to paste into Steam by hand (**Copy** button; Steam: Ring of Elysium > Properties >
  General > Launch options), then the automatic way below.
- Start through Steam from the window: **Set up Start through Steam** puts it into
  Steam with the server and account selected in the window. If Steam is open, it asks to close it
  and offers to start it again afterwards. Steam's Play button then opens join.cmd's window (no
  console), which starts the game after 3 seconds (Cancel stops it; a box turns that off, then it
  waits for Play) and closes itself when the game exits. The window shows whether it is on and for
  which server and account; pressing the button again takes the newly selected ones, **Turn it
  off** removes it. Set up with the console's `join.cmd steam-setup` before? That keeps working;
  the button switches it to the window.
- Start through Steam: Steam's Play button (with its overlay and playtime) can start the game
  through join.cmd. `join.cmd steam-setup` shows the launch option line (`"<path>\join.cmd"
  %command%`) and, while Steam is closed, puts it into Steam for you (a backup of Steam's
  localconfig.vdf is kept next to it; only that one setting changes). Started by Steam, join.cmd
  logs in with the server and account you used last (or the ones given once with
  `join.cmd -Server <address> -Name <name> steam-setup`) and starts the game, DirectX 12 too when
  that was your last choice. `join.cmd steam-setup off` removes it. On Linux the same with
  `python3 join.py --steam-setup`: Steam then starts join.py, which uses Steam's own Proton.
- Admin accounts: a server can now mark an account as admin (a GM that may also change the
  server's technical settings). join.cmd's window shows **Open the admin page** for such an
  account too, and `join.py --admin` takes it like a GM's.

## 1.0 (2026-11-19)

- Game files changed by other launchers: before the game starts, join.cmd (window and console)
  and join.py check the files other launchers and lobby patchers change (the game's .sfc
  archives, the lobby caches, GCloudVoice.dll) against the Steam install and look for files they
  add (proxy DLLs such as dinput8.dll, data_exp.vfs). When one differs they name it and say to
  verify the game files in Steam (Ring of Elysium > Properties > Installed Files > Verify
  integrity of game files) or to delete the added file, then to start again; the game starts
  only with "Start the game anyway". Only the first start hashes the files (about a second), later
  ones use the saved hashes. `--skip-file-check` leaves the check out.
- One file for Windows: **join.cmd** is the window now. Double-click it and the window opens
  (servers, accounts, game folder, voice chat, Play); started in a command prompt with arguments
  (`join.cmd -Server x`, `join.cmd firewall`, `join.cmd export`, `join.cmd admin`) or without any,
  it works in the prompt as before. `join.cmd --console` forces the console (for example from
  PowerShell), `join.cmd --window` the window. Both use the same steps and settings.
  join-gui.cmd is gone: double-click join.cmd for the window (delete an old join-gui.cmd and its
  shortcuts).
- The first start offers **ROE-OS (roe-os.de)** as the server: in the window it is selected, in
  the console menu (and in join.py's) Enter takes it, so a new player only picks the account and
  plays. Other servers are added as before; roe-os.de stays in the list.
- join.cmd's window: pick the Ring of Elysium folder itself and tick **DirectX 12** for the DX12
  version (its XVersion folder); an XVersion folder picked directly is recognised. It says which
  version is missing in the folder. The full folder is saved as before, so the console agrees.
- GM accounts: the server's admin page (bot settings, matchmaking, status, the log of GM
  actions) opens in the browser without a password: `join.cmd admin`, `python3 join.py --admin`,
  or in the window **Advanced > Open the admin page** (shown only for an account with GM rights
  on the selected server). The scripts ask the server for a one-time login link that works for
  one minute.
- The player counts per region (STATS) are asked at most every 10 seconds per server, to keep
  the server's load low.
- The voice DLL (`voice/GCloudVoice.dll`) is built locally and committed by hand; the GitHub
  Actions workflow no longer runs on push and starts only by hand.
- The window: **Advanced > Open the admin page** works while the game runs (it has its own
  worker; before, it was disabled during the game). `join.cmd admin` next to a running game no
  longer checks the voice DLL first.

## 0.9 (2026-11-19)

Licensed under GPL-3.0 (`LICENSE`).

The first version in its own repository (before, the files were part of the server's
repository, which keeps their history).

- join-gui.cmd: join a server in a window (servers with who plays in each region, accounts, game
  folder, voice chat, Play; firewall rules, account backup and the log under Advanced). It needs
  join.cmd next to it and uses its functions.
- join.cmd (Windows console) and join.py (Linux, Steam with Proton or GE-Proton): game folder and
  version check, the servers joined before, accounts with a secret key per account
  (`%APPDATA%\roe-join`, `~/.config/roe-join`), export and import of every account into one file,
  the server's name and players per region (every region with its numbers after the login and
  every 30 s while the game runs), a version check against the server.
- join.cmd's firewall rules: the game may reach only the servers joined and the addresses the
  server lists, with a check that the rules are there and that no block rule of another program
  names the game.
- Voice chat, on by default (asked once): our GCloudVoice.dll goes into the game folder while the
  game runs and the original is put back afterwards (kept in `roe-join-backup` in the game
  folder). The DLL is looked for next to the script, then in its `voice` folder, then asked for.
- voice/: the replacement GCloudVoice.dll (Opus, the server's voice relay over UDP 10101), with a
  test that drives it the way the game does and tests of its platform-independent core.
