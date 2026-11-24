# ROE-OS Client

Play **Ring of Elysium** (the last version, from 2022) on community servers, with no closed
source launcher. Everything here is plain, readable scripts: open them, or paste them into any AI
and ask what they do.

## :video_game: How to play (Windows)

**You need:** Ring of Elysium from Steam, and this file in a folder of your choice (e.g. your
desktop). Open the link and click the download arrow at the top right ("Download raw file"):

- [join-roe-os.cmd](https://github.com/mschnati/roe-os-client/blob/main/join-roe-os.cmd): the window you start
- Optional, for voice chat: [GCloudVoice.dll](https://github.com/mschnati/roe-os-client/raw/main/voice/GCloudVoice.dll), same folder

**Then:**

1. Double-click **join-roe-os.cmd**. If Windows warns you: **More info > Run anyway**.
2. The server **ROE-OS (roe-os.de)** is already selected, and you see how many people play in
   each region and how many wait for each mode (solo, duo, squad, FPP), refreshed while the window
   is open. Another server: **Add server** and enter its address. The language is at the top right.
3. **Create a new account** (first time) or pick yours.
4. **Game folder:** click **Browse** and pick the Ring of Elysium folder, usually
   `C:\Program Files (x86)\Steam\steamapps\common\Ring of Elysium`. Tick **DirectX 12** to play
   the DX12 version.
5. Click **Play**. The first time, Windows asks for administrator approval for the firewall
   rules: click **Yes**. Leave the window open while you play.

Everything is saved, so next time it's just **Play**.


> [!IMPORTANT]
> **Played with other launchers before?** Many of them change your game files without asking. join-roe-os.cmd checks this before every start: if it says your game files were changed, verify them in Steam (**Ring of Elysium > Properties > Installed Files > Verify integrity of game files**) and start again.

**Still can't connect?** Check out the [Firewall](#shield-firewall) section.

### Start it from Steam (optional)

Steam's **Play** button can open the join window instead of the normal game launcher, like this your friends can see it and you can increase your hours played.

For that you need the launcher in the [with-steam](https://github.com/mschnati/roe-os-client/blob/main/with-steam/join-roe-os.cmd) folder.

Its not the main client because Kaspersky doesnt like it and flags it.

## :globe_with_meridians: Our Server

### roe-os.de
- 64 tick with very performant architecture for good hit reg
- Choose Region Europe for normal matches, on german servers
- Region Asia for a custom developed **Duel** game mode, on german servers
- Region America is ready to go online and let you play on NA servers, as soon as it makes sense with the player numbers

## :bust_in_silhouette: Your account

- **Name:** a new account gets a name like `newaccount1234`. You choose your real name in the
  game, and you can change it there later.
- **It's yours:** your account is tied to a secret key saved on your PC. Nobody else can log in
  as you, and there is no password to forget. Don't share it.
- **Another PC:** in the window, **Advanced > Export accounts**, copy the file over, then
  **Import accounts** there.
- **Lost your key?** Ask the server's host to reset your name.

## :microphone: Voice chat

On by default, if **GCloudVoice.dll** is next to join-roe-os.cmd (or you pick its folder). The game's
own voice servers are gone; this DLL replaces them. It's only put into the game folder while you
play: the game's original file is saved and put back when the game closes.

**Don't** copy the DLL into the game folder yourself. Else you lose your original file.

## :shield: Firewall

The script adds Windows Firewall rules so the game can only talk to the servers you joined and
your own PC, nothing else on the internet. That's why it asks for administrator approval. Else the game will keep sending analytics data to Tencent.

**Game can't connect?** Right-click **join-roe-os.cmd > Run as administrator** and try again. If it
still fails, the window tells you why under **Details**. Its probably because another launcher you used set some weird firewall settings.

## :penguin: Linux

Download [join-roe-os.py](https://github.com/mschnati/roe-os-client/blob/main/join-roe-os.py) and run
`python3 join-roe-os.py` in a terminal. It finds the game in Steam and starts it with Proton. Same
servers, accounts and voice chat as on Windows (no firewall step). Steam's Play button can start it
too: `python3 join-roe-os.py --steam-setup`.

## :gear: Server admins (GM accounts)

If the server's host made your account a GM, the window shows **Advanced > Open the admin
page** for it: your browser opens the server's admin page (bots, matchmaking, status), logged in
as that account. No password: the link works once, for one minute.

## More

- **Console version:** the same join-roe-os.cmd, started in a command prompt (with or without
  arguments, or `join-roe-os.cmd --console`), has commands and options for advanced users.
- **Details, building and testing:** [DEVELOPMENT.md](DEVELOPMENT.md)
- **Changes:** [CHANGELOG.md](CHANGELOG.md)
- **The server:** [ring-of-elysium-open-source](https://github.com/mschnati/ring-of-elysium-open-source)

An unofficial fan project. It contains no game files and changes nothing in your game folder
except the voice DLL while you play. License: GPL-3.0 ([LICENSE](LICENSE)); the voice DLL
contains Opus (BSD, [third_party/LICENSE.opus](third_party/LICENSE.opus)).
