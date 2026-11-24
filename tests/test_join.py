"""join-roe-os.py against fake Steam trees and game folders: roots, libraries, game, prefix, the Proton choice, the voice DLL and the
account and server menus; join-roe-os.cmd's voice DLL, account and server functions through powershell.exe."""
import argparse
import contextlib
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

JOIN = Path(__file__).resolve().parents[1] / 'join-roe-os.py'
spec = importlib.util.spec_from_file_location('join', JOIN)
join = importlib.util.module_from_spec(spec)
spec.loader.exec_module(join)


def touch(path, text=''):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def fake_dll(text, machine=0x8664, flags=0x2022):
    """A minimal PE file: MZ, e_lfanew 0x40, PE, machine, flags, then text."""
    return (b'MZ' + bytes(0x3a) + (0x40).to_bytes(4, 'little') + b'PE\0\0' + machine.to_bytes(2, 'little')
            + bytes(16) + flags.to_bytes(2, 'little') + bytes(8) + text)


def proton(folder, prefix_version=''):
    return touch(folder / 'proton', f'#!/usr/bin/env python3\nCURRENT_PREFIX_VERSION="{prefix_version}"\n')


class FakeSteam(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.home = base / 'home'
        self.root = self.home / '.local/share/Steam'
        self.lib = base / 'games/SteamLibrary'
        (self.root / 'steamapps').mkdir(parents=True)
        (self.home / '.steam').mkdir()
        os.symlink(self.root, self.home / '.steam/steam')   # the same install twice
        touch(self.root / 'steamapps/libraryfolders.vdf',
              f'"libraryfolders"\n{{\n "0"\n {{\n  "path"  "{self.root}"\n }}\n "1"\n {{\n  "path"  "{self.lib}"\n }}\n}}\n')
        self.game = self.lib / 'steamapps/common/Ring of Elysium'
        touch(self.game / 'Europa_Client.exe', 'not the game')
        touch(self.game / 'XVersion/Europa_Client.exe', 'not the game')
        touch(self.lib / 'steamapps/appmanifest_755790.acf', '"AppState"\n{\n "appid" "755790"\n "installdir" "Ring of Elysium"\n}\n')
        self.prefix = self.lib / 'steamapps/compatdata/755790'
        self.tools_dir = self.root / 'compatibilitytools.d'
        proton(self.tools_dir / 'GE-Proton9-20', 'GE-Proton9-20')
        proton(self.tools_dir / 'GE-Proton10-3', 'GE-Proton10-3')
        common = self.root / 'steamapps/common'
        proton(common / 'Proton 9.0', '9.0-102')
        proton(common / 'Proton 8.0', '8.0-104')
        proton(common / 'Proton - Experimental', '9.0-200')

    def tearDown(self):
        self.tmp.cleanup()

    def tools(self):
        roots = join.steam_roots(self.home)
        return join.find_tools(roots, join.libraries(roots), system_tools=())

    def choose(self, version=''):
        tool, why = join.choose_proton(self.tools(), version)
        return tool.name if tool else None

    def test_roots_and_libraries(self):
        roots = join.steam_roots(self.home)
        self.assertEqual(roots, [self.root.resolve()])
        libs = join.libraries(roots)
        self.assertEqual(libs, [(self.root / 'steamapps').resolve(), (self.lib / 'steamapps').resolve()])
        self.assertEqual(join.find_game(libs), str(self.game.resolve()))

    def test_game_library_prefix_and_app_id(self):
        for client in (self.game, self.game / 'XVersion'):
            library, installdir = join.library_of(client)
            self.assertEqual((library, installdir), ((self.lib / 'steamapps').resolve(), 'Ring of Elysium'))
            self.assertEqual(join.app_id(client), '755790')
            self.assertEqual(join.find_prefix(client, [], '755790'), self.prefix.resolve())

    def test_newest_ge_first(self):
        self.assertEqual(self.choose(), 'GE-Proton10-3')

    def test_the_proton_that_ran_the_prefix(self):
        self.assertEqual(self.choose('GE-Proton9-20'), 'GE-Proton9-20')
        self.assertEqual(self.choose('9.0-102'), 'Proton 9.0')
        self.assertEqual(self.choose('GE-Proton7-1'), 'GE-Proton10-3')   # not installed any more

    def test_valve_then_custom(self):
        for name in ('GE-Proton9-20', 'GE-Proton10-3'):
            os.remove(self.tools_dir / name / 'proton')
        self.assertEqual(self.choose(), 'Proton 9.0')   # numbered before Experimental
        proton(self.tools_dir / 'proton-cachyos-9')
        self.assertEqual(self.choose(), 'Proton 9.0')
        for name in ('Proton 9.0', 'Proton 8.0', 'Proton - Experimental'):
            os.remove(self.root / 'steamapps/common' / name / 'proton')
        self.assertEqual(self.choose(), 'proton-cachyos-9')

    def test_natural_sort(self):
        names = ['GE-Proton9-20', 'GE-Proton10-1', 'GE-Proton9-3']
        self.assertEqual(sorted(names, key=join.natural_key), ['GE-Proton9-3', 'GE-Proton9-20', 'GE-Proton10-1'])
        self.assertTrue(join.is_ge('Proton-6.21-GE-2'))
        self.assertFalse(join.is_ge('Proton 9.0'))

    def test_plan(self):
        options = argparse.Namespace(proton=None, compat=None)
        plan = join.plan_start(str(self.game.resolve()), ['-garena'], options, home=self.home, system_tools=())
        self.assertEqual(plan['tool'].name, 'GE-Proton10-3')
        self.assertTrue(plan['init'])
        env = plan['env']
        self.assertEqual(env['STEAM_COMPAT_DATA_PATH'], str(self.prefix.resolve()))
        self.assertEqual(env['STEAM_COMPAT_CLIENT_INSTALL_PATH'], str(self.root.resolve()))
        self.assertEqual(env['PROTON_USE_XALIA'], '0')
        self.assertEqual(env['SteamAppId'], '755790')
        self.assertEqual(plan['command'][1:3], ['run', str(self.game.resolve() / 'Europa_Client.exe')])
        touch(self.prefix / 'version', 'GE-Proton9-20')
        (self.prefix / 'pfx/drive_c/users/steamuser').mkdir(parents=True)
        plan = join.plan_start(str(self.game.resolve()), [], options, home=self.home, system_tools=())
        self.assertEqual(plan['tool'].name, 'GE-Proton9-20')
        self.assertFalse(plan['init'])
        options.proton = str(self.root / 'steamapps/common/Proton 8.0')
        self.assertEqual(join.plan_start(str(self.game), [], options, home=self.home, system_tools=())['tool'].name, 'Proton 8.0')
        options.proton = str(self.home / 'nothing')
        with self.assertRaises(join.Failure):
            join.plan_start(str(self.game), [], options, home=self.home, system_tools=())

    def test_start_creates_the_prefix(self):
        # A stand-in Proton: wineboot makes the prefix, the game run logs its arguments and environment.
        log = Path(self.tmp.name) / 'log'
        fake = touch(Path(self.tmp.name) / 'FakeProton/proton',
                     '#!/bin/sh\n'
                     'if [ "$2" = wineboot ]; then mkdir -p "$STEAM_COMPAT_DATA_PATH/pfx/drive_c/users/steamuser"; exit 0; fi\n'
                     f'echo "$1|$3|$PROTON_USE_XALIA|$SteamGameId|$(pwd)" > "{log}"\n')
        fake.chmod(0o755)
        options = argparse.Namespace(proton=str(fake), compat=str(Path(self.tmp.name) / 'pfx-test'), dry_run=False)
        saved = dict(os.environ)
        os.environ['HOME'] = str(self.home)
        try:
            self.assertEqual(join.start_game(str(self.game.resolve()), ['-garena'], options), 0)
        finally:
            os.environ.clear()
            os.environ.update(saved)
        self.assertTrue(join.prefix_ready(Path(self.tmp.name) / 'pfx-test'))
        self.assertEqual(log.read_text().strip(), f'run|-garena|0|755790|{self.game.resolve()}')

    def test_dry_run(self):
        env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'), ROE_JOIN_DRY_RUN='1')
        env.pop('PROTON', None)
        result = subprocess.run([sys.executable, '-I', str(JOIN), '--game', str(self.game / 'XVersion'),
                                 '--server', '127.0.0.1', '--name', 'Tester'],
                                env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)   # the fake exe is not the tested build
        self.assertIn('Verify integrity', result.stdout)
        self.assertIn('Would log in to 127.0.0.1:8002 as Tester', result.stdout)
        self.assertIn('GE-Proton10-3', result.stdout)
        self.assertIn('Would set PROTON_USE_XALIA=0', result.stdout)
        self.assertIn('Would create the prefix', result.stdout)
        self.assertIn('-server=127.0.0.1:8001', result.stdout)
        self.assertFalse((self.home / '.config').exists())   # nothing written
        self.assertFalse(self.prefix.exists())


class VoiceFolders(unittest.TestCase):
    """Fake game folders with the original GCloudVoice.dll and the package with ours."""
    ORIGINAL = fake_dll(b'GetVoiceEngine original voice dll')
    OURS = fake_dll(b'GetVoiceEngine our voice dll')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.game = base / 'common/Ring of Elysium'
        self.xversion = self.game / 'XVersion'
        for folder in (self.game, self.xversion):
            touch(folder / 'Europa_Client.exe', 'not the game')
            (folder / 'GCloudVoice.dll').write_bytes(self.ORIGINAL + folder.name.encode())
        self.source = base / 'package/voice'
        self.source.mkdir(parents=True)
        (self.source / 'GCloudVoice.dll').write_bytes(self.OURS)
        self.backups = base / 'config/roe-join/voice-backup'
        self.not_running = lambda client: False

    def tearDown(self):
        self.tmp.cleanup()

    def dll(self, folder):
        return (folder / 'GCloudVoice.dll').read_bytes()

    def install(self, folder, running=None):
        return join.voice_install(str(folder), self.backups, self.source / 'GCloudVoice.dll', running=running or self.not_running)


class Voice(VoiceFolders):
    """Our GCloudVoice.dll in fake game folders: install, restore, crash, running game, bad hash."""
    def test_install_and_restore(self):
        self.assertTrue(self.install(self.game))
        self.assertEqual(self.dll(self.game), self.OURS)
        self.assertEqual(self.dll(self.xversion), self.ORIGINAL + b'XVersion')   # only the folder that is started
        saved = self.game / 'roe-join-backup'   # in the game folder, under its own name, with a note
        self.assertEqual((saved / 'GCloudVoice.dll').read_bytes(), self.ORIGINAL + self.game.name.encode())
        self.assertIn('copy GCloudVoice.dll from this folder', (saved / 'README.txt').read_text())
        self.assertFalse((join.voice_backup_dir(self.backups, str(self.game)) / 'GCloudVoice.dll').exists())
        self.assertTrue(join.voice_restore(str(self.game), self.backups, self.not_running))
        self.assertEqual(self.dll(self.game), self.ORIGINAL + self.game.name.encode())
        self.assertFalse(list(self.game.glob('*.roe-join')))

    def test_restore_on_exit(self):
        # A stand-in Proton logs the DLL the game sees; after it exits the original is back.
        log = Path(self.tmp.name) / 'log'
        fake = touch(Path(self.tmp.name) / 'FakeProton/proton', f'#!/bin/sh\ncat GCloudVoice.dll > "{log}"\n')
        fake.chmod(0o755)
        compat = Path(self.tmp.name) / 'pfx'
        (compat / 'pfx/drive_c/users/steamuser').mkdir(parents=True)
        options = argparse.Namespace(proton=str(fake), compat=str(compat), dry_run=False)
        code = join.play(str(self.xversion), [], options, dll=self.source / 'GCloudVoice.dll', backups=self.backups)
        self.assertEqual(code, 0)
        self.assertEqual(log.read_bytes(), self.OURS)
        self.assertEqual(self.dll(self.xversion), self.ORIGINAL + b'XVersion')

    def test_restore_after_a_crash(self):
        self.assertTrue(self.install(self.game))
        # The second start before the restore: ours is in place and is not backed up over the original.
        self.assertTrue(self.install(self.game))
        join.voice_restore_all(self.backups, self.not_running)
        self.assertEqual(self.dll(self.game), self.ORIGINAL + self.game.name.encode())
        join.voice_restore_all(self.backups, self.not_running)   # nothing left to do
        self.assertEqual(self.dll(self.game), self.ORIGINAL + self.game.name.encode())

    def test_skip_while_running(self):
        exe = self.game / 'Europa_Client.exe'
        game = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)', str(exe)])
        try:
            self.assertTrue(join.game_running(str(self.game)))
            self.assertFalse(join.game_running(str(self.xversion)))
            self.assertFalse(self.install(self.game, join.game_running))
            self.assertEqual(self.dll(self.game), self.ORIGINAL + self.game.name.encode())
            self.assertTrue(self.install(self.xversion, join.game_running))   # the second player's folder
            # Ours in a running game stays until it exits.
            (self.game / 'GCloudVoice.dll').write_bytes(self.OURS)
            saved = join.voice_backup_dir(self.backups, str(self.game))
            saved.mkdir(parents=True)
            original = self.game / 'roe-join-backup'
            original.mkdir()
            (original / 'GCloudVoice.dll').write_bytes(self.ORIGINAL)
            touch(saved / 'backup.json', json.dumps({'folder': str(self.game), 'original': join.hashlib.sha256(self.ORIGINAL).hexdigest(),
                                                     'installed': join.hashlib.sha256(self.OURS).hexdigest()}))
            join.voice_restore_all(self.backups, join.game_running)
            self.assertEqual(self.dll(self.game), self.OURS)
            self.assertEqual(self.dll(self.xversion), self.ORIGINAL + b'XVersion')   # not running: restored
        finally:
            game.kill()
            game.wait()
        join.voice_restore_all(self.backups, join.game_running)
        self.assertEqual(self.dll(self.game), self.ORIGINAL)

    def test_changed_or_wrong_dll_refused(self):
        # Changed since it was chosen (another hash), or no DLL of ours at all.
        ours = self.source / 'GCloudVoice.dll'
        self.assertFalse(join.voice_install(str(self.game), self.backups, ours, 'another hash', self.not_running))
        ours.write_bytes(b'something else')
        self.assertFalse(self.install(self.game))
        self.assertEqual(self.dll(self.game), self.ORIGINAL + self.game.name.encode())
        self.assertFalse(self.backups.exists())

    def test_missing_backup(self):
        self.assertTrue(self.install(self.game))
        (self.game / 'roe-join-backup/GCloudVoice.dll').unlink()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertFalse(join.voice_restore(str(self.game), self.backups, self.not_running))
        self.assertIn('Verify integrity of game files', out.getvalue())
        self.assertEqual(self.dll(self.game), self.OURS)


    def test_missing_game_dll_with_backup(self):
        original = self.dll(self.game)
        self.assertTrue(self.install(self.game))
        self.assertTrue(join.voice_restore(str(self.game), self.backups, self.not_running))
        # Deleted by hand: the next start puts the original back from the backup ...
        (self.game / 'GCloudVoice.dll').unlink()
        join.voice_restore_all(self.backups, self.not_running)
        self.assertEqual(self.dll(self.game), original)
        # ... and with voice on ours goes in, the original back on exit.
        (self.game / 'GCloudVoice.dll').unlink()
        self.assertTrue(self.install(self.game))
        self.assertEqual(self.dll(self.game), self.OURS)
        self.assertTrue(join.voice_restore(str(self.game), self.backups, self.not_running))
        self.assertEqual(self.dll(self.game), original)

    def test_missing_game_dll_without_backup(self):
        (self.game / 'GCloudVoice.dll').unlink()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertTrue(self.install(self.game))
        self.assertIn('no backup of the original', out.getvalue())
        self.assertEqual(self.dll(self.game), self.OURS)
        join.voice_restore_all(self.backups, self.not_running)   # ours stays: the game needs a DLL
        self.assertEqual(self.dll(self.game), self.OURS)


class Answers:
    """Stands in for ask(): gives the answers in turn and keeps the questions and their defaults."""
    def __init__(self, *answers):
        self.answers = list(answers)
        self.asked = []

    def __call__(self, question, default=''):
        self.asked.append((question, default))
        if not self.answers:
            raise AssertionError(f'not expected: {question}')
        answer = self.answers.pop(0)
        return answer if answer else default


class VoicePath(VoiceFolders):
    """The saved DLL path, the questions for it and the hash confirmation."""
    def setUp(self):
        super().setUp()
        self.saved_source = join.VOICE_SOURCE
        join.VOICE_SOURCE = Path(self.tmp.name) / 'nowhere'
        self.ours = self.source / 'GCloudVoice.dll'
        self.quiet = contextlib.redirect_stdout(io.StringIO())
        self.out = self.quiet.__enter__()

    def tearDown(self):
        self.quiet.__exit__(None, None, None)
        join.VOICE_SOURCE = self.saved_source
        super().tearDown()

    def setup(self, settings, answers, ask_path=False):
        return join.voice_setup(settings, str(self.game), self.backups, ask_path, answers)

    def test_saved_path_used(self):
        settings = {'voice_dll': str(self.ours)}
        answers = Answers()
        self.assertEqual(self.setup(settings, answers), (self.ours, join.hashlib.sha256(self.OURS).hexdigest()))
        self.assertEqual(answers.asked, [])
        join.VOICE_SOURCE = self.source   # no saved path: voice/ next to the script
        self.assertEqual(self.setup({}, answers)[0], self.ours)

    def test_missing_asks_and_saves(self):
        settings = {'voice_dll': str(Path(self.tmp.name) / 'gone/GCloudVoice.dll')}
        # A wrong answer asks again; the folder in quotes is taken as its GCloudVoice.dll.
        answers = Answers(str(Path(self.tmp.name) / 'nothing'), f'"{self.source}"')
        dll, expected = self.setup(settings, answers)
        self.assertEqual(dll, self.ours.resolve())
        self.assertEqual(settings['voice_dll'], str(self.ours.resolve()))
        self.assertEqual(len(answers.asked), 2)
        self.assertEqual(answers.asked[0][1], '')
        # Nothing entered: no voice this time, the saved path stays.
        settings = {'voice_dll': str(Path(self.tmp.name) / 'gone/GCloudVoice.dll')}
        self.assertEqual(self.setup(settings, Answers('')), (None, None))
        self.assertEqual(settings['voice_dll'], str(Path(self.tmp.name) / 'gone/GCloudVoice.dll'))

    def test_voice_on_asks_again(self):
        settings = {'voice_dll': str(self.ours)}
        answers = Answers('')   # Enter keeps the current one
        self.assertEqual(self.setup(settings, answers, ask_path=True)[0], self.ours.resolve())
        self.assertEqual(answers.asked[0][1], str(self.ours))
        other = Path(self.tmp.name) / 'other'
        other.mkdir()
        (other / 'GCloudVoice.dll').write_bytes(self.OURS)
        answers = Answers(str(other / 'GCloudVoice.dll'))
        self.assertEqual(self.setup(settings, answers, ask_path=True)[0], (other / 'GCloudVoice.dll').resolve())
        self.assertEqual(settings['voice_dll'], str((other / 'GCloudVoice.dll').resolve()))

    def test_voice_choice(self):
        # On by default: a yes (Enter) with the DLL found saves both and is not asked again.
        join.VOICE_SOURCE = self.source
        digest = join.hashlib.sha256(self.OURS).hexdigest()
        settings = {}
        answers = Answers('')
        self.assertEqual(join.voice_choice(settings, str(self.game), self.backups, None, answers), (True, self.ours.resolve(), digest))
        self.assertEqual(answers.asked, [('Use voice chat? (y/n)', 'y')])
        self.assertEqual(settings['voice_dll'], str(self.ours.resolve()))
        settings['voice'] = True
        self.assertEqual(join.voice_choice(settings, str(self.game), self.backups, None, Answers()), (True, self.ours.resolve(), digest))
        # The saved file gone: asks for its folder once more and saves the new path.
        other = Path(self.tmp.name) / 'other'
        other.mkdir()
        (other / 'GCloudVoice.dll').write_bytes(self.OURS)
        self.ours.unlink()
        answers = Answers(str(other))
        self.assertEqual(join.voice_choice(settings, str(self.game), self.backups, None, answers)[:2], (True, (other / 'GCloudVoice.dll').resolve()))
        self.assertTrue(answers.asked[0][0].startswith('Folder with our GCloudVoice.dll'))
        self.assertIn('separate download', self.out.getvalue())
        self.assertEqual(settings['voice_dll'], str((other / 'GCloudVoice.dll').resolve()))
        # A no is saved and not asked again.
        self.assertEqual(join.voice_choice({}, str(self.game), self.backups, None, Answers('n')), (False, None, None))
        self.assertEqual(join.voice_choice({'voice': False}, str(self.game), self.backups, None, Answers()), (False, None, None))
        # A yes without a DLL (nothing entered): no voice now, asked again next start.
        settings = {}
        self.assertEqual(join.voice_choice(settings, str(self.game), self.backups, None, Answers('y', '')), (None, None, None))
        self.assertNotIn('voice_dll', settings)
        # The saved file missing, nothing entered: stays on, no voice now.
        self.assertEqual(join.voice_choice({'voice': True}, str(self.game), self.backups, None, Answers(''))[:2], (True, None))

    def test_dll_next_to_the_script(self):
        # The DLL right next to the script (no voice folder): found without a path question; only
        # the yes/no is asked, once.
        saved = join.SCRIPT_FOLDER
        join.SCRIPT_FOLDER = self.source
        try:
            settings = {}
            answers = Answers('')
            self.assertEqual(join.voice_choice(settings, str(self.game), self.backups, None, answers)[:2], (True, self.ours.resolve()))
            self.assertEqual(answers.asked, [('Use voice chat? (y/n)', 'y')])
            settings['voice'] = True
            answers = Answers()
            self.assertEqual(join.voice_choice(settings, str(self.game), self.backups, None, answers)[:2], (True, self.ours.resolve()))
            self.assertEqual(answers.asked, [])
        finally:
            join.SCRIPT_FOLDER = saved

    def test_original_refused(self):
        # The game's own DLL copied elsewhere: never used.
        copy = Path(self.tmp.name) / 'copy'
        copy.mkdir()
        original = self.ORIGINAL + self.game.name.encode()
        (copy / 'GCloudVoice.dll').write_bytes(original)
        settings = {'voice_dll': str(copy / 'GCloudVoice.dll')}
        self.assertEqual(self.setup(settings, Answers('')), (None, None))
        self.assertIn("the game's original", self.out.getvalue())
        self.assertFalse(join.voice_install(str(self.game), self.backups, copy / 'GCloudVoice.dll',
                                            join.hashlib.sha256(original).hexdigest(), self.not_running))
        self.assertEqual(self.dll(self.game), original)
        # Once ours is in, the backup's original is still refused.
        self.assertTrue(self.install(self.game))
        self.assertIn("the game's original", join.voice_problem(copy / 'GCloudVoice.dll', str(self.game), self.backups))
        self.assertEqual(join.voice_problem(self.ours, str(self.game), self.backups), '')
        # A DLL inside a game folder, a file that is no x64 DLL, and a DLL without GetVoiceEngine.
        self.assertIn('game folder', join.voice_problem(self.xversion / 'GCloudVoice.dll', str(self.game), self.backups))
        for data, why in ((b'GetVoiceEngine', '64-bit'), (fake_dll(b'GetVoiceEngine', machine=0x14c), '64-bit'),
                          (fake_dll(b'GetVoiceEngine', flags=0x22), '64-bit'), (fake_dll(b'nothing'), 'GetVoiceEngine')):
            (copy / 'GCloudVoice.dll').write_bytes(data)
            self.assertIn(why, join.voice_problem(copy / 'GCloudVoice.dll', str(self.game), self.backups))

    def test_dry_run_voice_on(self):
        home = Path(self.tmp.name) / 'home'
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'), ROE_JOIN_DRY_RUN='1')
        env.pop('PROTON', None)
        result = subprocess.run([sys.executable, '-I', str(JOIN), '--game', str(self.game), '--server', '127.0.0.1',
                                 '--name', 'Tester', '--voice', 'on'],
                                env=env, input=f'{self.source}\n', capture_output=True, text=True, timeout=30)
        self.assertIn('Folder with our GCloudVoice.dll', result.stdout, result.stdout + result.stderr)
        self.assertIn(f'Would put our GCloudVoice.dll ({self.ours.resolve()})', result.stdout)
        self.assertFalse((home / '.config').exists())   # nothing written


class FakeService:
    """Stands in for the account service: replies by request line (None: no answer)."""
    def __init__(self, replies):
        self.replies = dict(replies)
        self.sent = []

    def __call__(self, line):
        self.sent.append(line)
        if line not in self.replies:
            raise AssertionError(f'not expected: {line}')
        return self.replies[line]


T1, T2, T3, T4, T5 = 'a' * 64, 'b' * 64, 'c' * 64, 'd' * 64, 'e' * 64


class AdminPage(unittest.TestCase):
    """--admin: the role, then the one-time link; its address from the server or https://admin.<domain>."""
    def test_role_and_link(self):
        self.assertEqual([join.account_role(r) for r in ('OK gm', 'OK player', 'INVALID', None, 'OK GM', 'OK admin', 'OK Admin')],
                         ['gm', 'player', '', '', '', 'admin', ''])
        self.assertTrue(join.domain_host('roe-os.de') and join.domain_host('play.example.org'))
        self.assertFalse(join.domain_host('203.0.113.5') or join.domain_host('::1') or join.domain_host('localhost') or join.domain_host('a b.de'))
        self.assertEqual(join.admin_link(f'OK {T1} -', 'Roe-OS.de'), (f'https://admin.roe-os.de/login?ticket={T1}', None))
        self.assertEqual(join.admin_link(f'OK {T1} https%3A%2F%2Fpanel.example.org%2F', '203.0.113.5'),
                         (f'https://panel.example.org/login?ticket={T1}', None))
        self.assertIn('no admin page address', join.admin_link(f'OK {T1} -', '203.0.113.5')[1])
        self.assertEqual(join.admin_link('DENIED', 'x.de'), (None, 'This account has no GM rights on this server.'))
        for reply in ('NONE', 'INVALID', None):
            self.assertEqual(join.admin_link(reply, 'x.de'), (None, 'This server has no admin page.'))
        self.assertEqual(join.admin_link(f'OK {T1} javascript:alert(1)', 'x.de')[0], None)

    def test_player_asks_no_ticket(self):
        service = FakeService({f'ROLE {T1}': 'OK player'})
        self.assertEqual(join.admin_page(service, {'name': 'Anna', 'token': T1}, 'x.de'), (None, 'This account has no GM rights on this server.'))
        self.assertEqual(service.sent, [f'ROLE {T1}'])
        service = FakeService({f'ROLE {T1}': 'OK gm', f'WEB {T1}': f'OK {T2} -'})
        self.assertEqual(join.admin_page(service, {'name': 'Anna', 'token': T1}, 'x.de'), (f'https://admin.x.de/login?ticket={T2}', None))
        self.assertIn('saved account', join.admin_page(FakeService({}), {'name': 'Anna', 'token': ''}, 'x.de')[1])


class AccountMenu(unittest.TestCase):
    """The saved accounts of a server: menu, accounts.json, login and new accounts."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self.tmp.name) / 'roe-join/1.2.3.4'
        self.quiet = contextlib.redirect_stdout(io.StringIO())
        self.out = self.quiet.__enter__()

    def tearDown(self):
        self.quiet.__exit__(None, None, None)
        self.tmp.cleanup()

    def saved(self):
        return json.loads((self.folder / 'accounts.json').read_text())['accounts']

    def test_menu_steps(self):
        self.assertEqual(join.menu_step(0, 'up', 3), (2, False))   # wraps
        self.assertEqual(join.menu_step(2, 'down', 3), (0, False))
        self.assertEqual(join.menu_step(1, 'home', 3), (0, False))
        self.assertEqual(join.menu_step(0, 'end', 3), (2, False))
        self.assertEqual(join.menu_step(1, 'x', 3), (1, False))
        self.assertEqual(join.menu_step(1, 'enter', 3), (1, True))

    def test_keys_and_numbered_list(self):
        keys = iter(['down', 'down', 'down', 'up', 'enter'])
        drawn = io.StringIO()
        self.assertEqual(join.pick_with_keys(['Anna', 'Bob', join.NEW_ACCOUNT], lambda: next(keys), drawn.write), 2)
        self.assertIn('\033[7m> Create a new account', drawn.getvalue())
        self.assertIn('\033[3A', drawn.getvalue())   # drawn over itself
        self.assertTrue(drawn.getvalue().endswith('\033[?25h'))
        answers = Answers('x', '7', '2')
        self.assertEqual(join.pick_numbered(['Anna', 'Bob', join.NEW_ACCOUNT], answers), 1)
        self.assertEqual(len(answers.asked), 3)
        self.assertEqual(join.pick_numbered(['Anna', join.NEW_ACCOUNT], Answers('')), 0)   # Enter: the first
        self.assertFalse(join.can_read_keys())   # input is not a terminal here

    def test_menu_order_and_new_account_entry(self):
        path = join.save_accounts(self.folder, [{'name': 'Old', 'token': T1, 'last_used': 10},
                                                {'name': 'Recent', 'token': T2, 'last_used': 30},
                                                {'name': 'Middle', 'token': T3, 'last_used': 20}])
        self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
        accounts = join.load_accounts(self.folder)
        shown = []

        def choose(entries):
            shown.append(entries)
            return len(entries) - 1
        self.assertIsNone(join.choose_account(accounts, choose=choose))
        self.assertEqual(shown, [['Recent', 'Middle', 'Old', 'Create a new account']])
        self.assertEqual(join.choose_account(accounts, choose=lambda entries: 1)['token'], T3)
        # --name picks without the menu, case ignored; an unknown one is a new account.
        no_menu = lambda entries: self.fail('menu shown')   # noqa: E731
        self.assertEqual(join.choose_account(accounts, 'recent', choose=no_menu)['token'], T2)
        self.assertIsNone(join.choose_account(accounts, 'Dora', choose=no_menu))
        self.assertIsNone(join.choose_account([], choose=no_menu))   # first start: no menu

    def test_accounts_json_with_byte_order_mark(self):
        # join-roe-os.cmd's file may start with a byte order mark; entries without a valid key and name are skipped.
        self.folder.mkdir(parents=True)
        rows = [{'name': 'Anna', 'token': T1, 'last_used': 1}, {'name': 'Bob', 'token': T2, 'last_used': 2},
                {'name': 'Bad', 'token': 'x', 'last_used': 3}, {'name': 'Dora', 'token': '', 'last_used': 0}, {'token': ''}]
        (self.folder / 'accounts.json').write_bytes(b'\xef\xbb\xbf' + json.dumps({'accounts': rows}).encode())
        self.assertEqual([(a['name'], a['token']) for a in join.load_accounts(self.folder)], [('Bob', T2), ('Anna', T1), ('Dora', '')])

    def test_refresh_names(self):
        accounts = [{'name': 'Anna', 'token': T1, 'last_used': 3}, {'name': 'Bob', 'token': T2, 'last_used': 2},
                    {'name': 'Carl', 'token': T3, 'last_used': 1}]
        service = FakeService({f'NAME {T1}': 'OK Glacier', f'NAME {T2}': 'DENIED', f'NAME {T3}': 'OK Summit'})
        self.assertTrue(join.refresh_names(accounts, service))
        self.assertEqual([a['name'] for a in accounts], ['Glacier', 'Bob', 'Summit'])
        limit = FakeService({f'NAME {T1}': 'LIMIT'})   # the limit: one request, nothing changed
        self.assertFalse(join.refresh_names(accounts, limit))
        self.assertEqual(limit.sent, [f'NAME {T1}'])

    def test_login_answers_the_name(self):
        accounts = [{'name': 'Anna', 'token': T1, 'last_used': 5}, {'name': 'Bob', 'token': T2, 'last_used': 3}]
        service = FakeService({f'LOGIN2 {T2}': 'OK 123456789012 Bobby One'})
        self.assertEqual(join.login(service, self.fail, self.folder, accounts, accounts[1]), ('123456789012', 'Bobby One'))
        self.assertEqual(self.saved()[0]['name'], 'Bobby One')   # renamed, and on top
        anna = next(a for a in accounts if a['name'] == 'Anna')
        # A released name is claimed again with a new key.
        service = FakeService({f'LOGIN2 {T1}': 'DENIED', 'CLAIM Anna': f'OK {T3}', f'LOGIN2 {T3}': 'OK 78 Anna'})
        self.assertEqual(join.login(service, self.fail, self.folder, accounts, anna), ('78', 'Anna'))
        self.assertIn(T3, [a['token'] for a in self.saved()])
        with self.assertRaisesRegex(join.Failure, 'banned'):
            join.login(FakeService({f'LOGIN2 {T3}': 'BANNED'}), self.fail, self.folder, accounts, anna)
        with self.assertRaisesRegex(join.Failure, 'Too many'):
            join.login(FakeService({f'LOGIN2 {T3}': 'LIMIT'}), self.fail, self.folder, accounts, anna)

    def test_new_account(self):
        # First-login on: the server names it, the game asks for the real name.
        accounts = []
        service = FakeService({'NEW': f'OK {T1} newaccount1234', f'LOGIN2 {T1}': 'OK 90 newaccount1234'})
        self.assertEqual(join.login(service, self.fail, self.folder, accounts, None, name_question=Answers()), ('90', 'newaccount1234'))
        self.assertEqual(self.saved()[0]['token'], T1)
        self.assertIn('you choose its name in the game', self.out.getvalue())
        # First-login off: a name is asked for, again when it is taken.
        answers = Answers('Anna', 'Anja')
        service = FakeService({'NEW': 'NAME-REQUIRED', 'CLAIM Anna': 'TAKEN', 'CLAIM Anja': f'OK {T2}', f'LOGIN2 {T2}': 'OK 91 Anja'})
        self.assertEqual(join.login(service, self.fail, self.folder, accounts, None, name_question=answers), ('91', 'Anja'))
        self.assertEqual(len(answers.asked), 2)
        # --name for a new account claims it directly.
        service = FakeService({'CLAIM Carl': f'OK {T4}', f'LOGIN2 {T4}': 'OK 93 Carl'})
        self.assertEqual(join.login(service, self.fail, self.folder, accounts, None, 'Carl', name_question=Answers()), ('93', 'Carl'))
        self.assertEqual(service.sent[0], 'CLAIM Carl')
        self.assertEqual(sorted(a['name'] for a in self.saved()), ['Anja', 'Carl', 'newaccount1234'])
        with self.assertRaisesRegex(join.Failure, 'banned'):
            join.login(FakeService({'NEW': 'BANNED'}), self.fail, self.folder, accounts, None, name_question=Answers())
        # No account service: the name for the next client from this address.
        plain = []
        self.assertEqual(join.login(FakeService({'NEW': None}), plain.append, self.folder, accounts, None,
                                    name_question=Answers('Dora')), ('1', 'Dora'))
        self.assertEqual(plain, ['Dora'])
        # The plain name is saved without a key and offered next time; picking it registers it again.
        saved = join.load_accounts(self.folder)
        dora = [a for a in saved if a['name'] == 'Dora']
        self.assertEqual([a['token'] for a in dora], [''])
        self.assertEqual(join.login(FakeService({'CLAIM Dora': None}), plain.append, self.folder, saved, dora[0],
                                    name_question=Answers()), ('1', 'Dora'))
        self.assertEqual(len([a for a in self.saved() if a['name'] == 'Dora']), 1)
        # Once the server has accounts, the saved name is claimed and gets its key.
        saved = join.load_accounts(self.folder)
        dora = [a for a in saved if a['name'] == 'Dora'][0]
        service = FakeService({'CLAIM Dora': f'OK {T5}', f'LOGIN2 {T5}': 'OK 94 Dora'})
        self.assertEqual(join.login(service, plain.append, self.folder, saved, dora, name_question=Answers()), ('94', 'Dora'))
        self.assertEqual([a['token'] for a in self.saved() if a['name'] == 'Dora'], [T5])

    def test_dry_run_menu(self):
        # Redirected input: the numbered list.
        home = Path(self.tmp.name) / 'home'
        join.save_accounts(home / '.config/roe-join/127.0.0.1', [{'name': 'Anna', 'token': T1, 'last_used': 2},
                                                                 {'name': 'Bob', 'token': T2, 'last_used': 1}])
        game = Path(self.tmp.name) / 'game'
        touch(game / 'Europa_Client.exe', 'not the game')
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'), ROE_JOIN_DRY_RUN='1', PROTON=str(home / 'none'))
        result = subprocess.run([sys.executable, '-I', str(JOIN), '--game', str(game), '--server', '127.0.0.1', '--voice', 'off'],
                                env=env, input='2\n', capture_output=True, text=True, timeout=30)
        self.assertIn('  1. Anna\n  2. Bob\n  3. Create a new account', result.stdout, result.stdout + result.stderr)
        self.assertIn('Would log in to 127.0.0.1:8002 as Bob', result.stdout)


class ServerMenu(unittest.TestCase):
    """The saved servers: menu order, another address, --server and the first start."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / 'roe-join'
        self.quiet = contextlib.redirect_stdout(io.StringIO())
        self.out = self.quiet.__enter__()

    def tearDown(self):
        self.quiet.__exit__(None, None, None)
        self.tmp.cleanup()

    def test_menu_order_and_another_address(self):
        settings = {'servers': [{'address': 'b.example', 'last_used': 20}, {'address': 'a.example', 'last_used': 30},
                                {'address': 'c.example', 'last_used': 25}, {'bad': 1}, {'address': 'A.example', 'last_used': 99}]}
        servers = join.saved_servers(settings)
        self.assertEqual([s['address'] for s in servers], ['a.example', 'c.example', 'b.example'])   # by last use, each once
        shown = []

        def choose(entries):
            shown.append(entries)
            return len(entries) - 1
        answers = Answers('d.example')
        self.assertEqual(join.choose_server(servers, choose=choose, question=answers), 'd.example')
        self.assertEqual(shown, [['a.example', 'c.example', 'b.example', 'Enter another server (IP or domain)']])
        self.assertEqual(answers.asked, [('Server address (IP or domain)', '')])
        self.assertEqual(join.choose_server(servers, choose=lambda entries: 1, question=Answers()), 'c.example')
        servers = join.remember_server(servers, 'C.example', now=99)
        self.assertEqual([(s['address'], s['last_used']) for s in servers],
                         [('C.example', 99), ('a.example', 30), ('b.example', 20)])
        # Folders without an entry in the list are no saved servers.
        join.save_accounts(self.root / 'old.example', [{'name': 'A', 'token': T1, 'last_used': 50}])
        self.assertEqual(join.saved_servers({}), [])

    def test_default_servers(self):
        # The first start offers roe-os.de (Enter takes it); saved servers replace the list; joining
        # another server keeps it.
        offered = join.offered_servers({})
        self.assertEqual(offered, [{'address': 'roe-os.de', 'name': 'ROE-OS', 'last_used': 0}])
        shown = []
        self.assertEqual(join.choose_server(offered, choose=lambda entries: shown.append(entries) or 0, question=Answers()), 'roe-os.de')
        self.assertEqual(shown, [['ROE-OS (roe-os.de)', 'Enter another server (IP or domain)']])
        self.assertEqual([s['address'] for s in join.remember_server(offered, 'b.example', now=5)], ['b.example', 'roe-os.de'])
        self.assertEqual(join.offered_servers({'servers': [{'address': 'a.example', 'last_used': 1}]}), [{'address': 'a.example', 'last_used': 1}])
        self.assertEqual(join.DEFAULT_SERVERS, [{'address': 'roe-os.de', 'name': 'ROE-OS'}])   # offered_servers copies

    def test_server_option_and_first_start(self):
        servers = [{'address': 'a.example', 'last_used': 1}]
        no_menu = lambda entries: self.fail('menu shown')   # noqa: E731
        self.assertEqual(join.choose_server(servers, '5.6.7.8', choose=no_menu, question=Answers()), '5.6.7.8')
        self.assertEqual(join.saved_servers({}), [])
        answers = Answers('1.2.3.4')
        self.assertEqual(join.choose_server([], choose=no_menu, question=answers), '1.2.3.4')
        self.assertEqual(len(answers.asked), 1)

    def test_server_addresses(self):
        # ADDRESSES: canonical, each once, loopback and words that are not addresses skipped.
        self.assertEqual(join.server_addresses('OK 203.0.113.5 2001:DB8:0::1 ttl=60 127.0.0.1 ::1 ::ffff:198.51.100.7 1.2.3 203.0.113.5 :: 224.0.0.1'),
                         ['203.0.113.5', '2001:db8::1', '198.51.100.7'])
        self.assertEqual(join.server_addresses('OK'), [])
        self.assertEqual(len(join.server_addresses('OK ' + ' '.join(f'10.0.{i // 250}.{i % 250 + 1}' for i in range(100)))), 64)
        # No OK (a limit, no answer): None, the saved list stays.
        for reply in ('INVALID', 'LIMIT', None, '', 'OKAY 1.2.3.4'):
            self.assertIsNone(join.server_addresses(reply), reply)

    def test_script_version(self):
        # VERSION: no OK means no check, below min stops, below current one line.
        github = 'url=https%3A%2F%2Fgithub.com%2Fmschnati%2Froe-os-client'
        for reply in ('INVALID', 'LIMIT', None, ''):
            self.assertIsNone(join.version_notice(reply, '0.9'), reply)
        self.assertIsNone(join.version_notice(f'OK min=0 current=0.9 {github}', '0.9'))
        self.assertIsNone(join.version_notice(f'OK min=0.9 current=0.9.0 {github} later=x', '0.9'))
        self.assertIsNone(join.version_notice(f'OK min=bad current=x {github}', '0.9'))
        self.assertEqual(join.version_notice(f'OK min=0.9 current=0.10 {github}', '0.9'),
                         'A newer join-roe-os.py (version 0.10) is at https://github.com/mschnati/roe-os-client; this one (version 0.9) still works.')
        with self.assertRaises(join.Failure) as stop:
            join.version_notice('OK min=1.0 current=1.0 url=https%3A%2F%2Fexample.org%2Froe', '0.9')
        self.assertEqual(str(stop.exception), 'This join-roe-os.py is version 0.9; the server needs version 1.0 or newer. '
                                              'Download the new join-roe-os.py from https://example.org/roe and start it again.')
        with self.assertRaises(join.Failure) as stop:
            join.version_notice('OK min=1 current=1 url=javascript%3Ax%0A', '0.9')
        self.assertIn('from https://github.com/mschnati/roe-os-client and', str(stop.exception))

    def test_domain_entry(self):
        # A domain: offered by the prompt, saved and shown as typed, one folder whatever the case.
        self.assertIn('IP or domain', join.SERVER_QUESTION)
        answers = Answers('Play.Example.org')
        server = join.choose_server([], question=answers)
        self.assertEqual(server, 'Play.Example.org')
        servers = join.remember_server([{'address': 'play.example.org', 'last_used': 1, 'name': 'Europa'}], server, now=5)
        self.assertEqual(servers, [{'address': 'Play.Example.org', 'last_used': 5, 'name': 'Europa'}])
        back = join.saved_servers({'servers': servers})
        self.assertEqual([join.server_label(s) for s in back], ['Europa (Play.Example.org)'])
        self.assertEqual(join.server_folder_name(server), 'play.example.org')

    def test_versions_agree(self):
        # join-roe-os.cmd and join-roe-os.py carry the same version and URL.
        root = JOIN.parent
        cmd = (root / 'join-roe-os.cmd').read_text()
        self.assertEqual(re.search(r"^\$joinVersion = '([0-9.]+)'", cmd, re.M).group(1), join.JOIN_VERSION)
        self.assertIn(f"$joinUrl = '{join.JOIN_URL}'", cmd)
        # The server's too, when this folder is inside the server's repository (client/).
        header = root.parent / 'src/lobby/accounts.hpp'
        if not header.is_file():
            self.skipTest('not inside the server repository')
        header = header.read_text()
        self.assertEqual(join.JOIN_VERSION, re.search(r'kJoinScriptVersion = "([0-9.]+)";', header).group(1))
        self.assertEqual(join.JOIN_URL, re.search(r'kDefaultJoinUrl = "([^"]+)"', header).group(1))

    def test_region_stats(self):
        # STATS: a part per region; broken words skipped; an older server or LIMIT shows nothing.
        reply = 'OK 7,normal,12,3,2,EU%20SERVER 6,duel,2,0,1,AS%20SERVER,later 5,normal,x,0,0,NA%20SERVER 9,odd'
        self.assertEqual(join.format_stats(reply), 'EU (normal): 12 online, 3 searching, 2 matches | AS (duel): 2 online, 0 searching, 1 match')
        self.assertEqual(join.format_stats('OK 5,normal,0,0,0,%0A'), 'zone 5 (normal): 0 online, 0 searching, 0 matches')
        for old in ('OK', 'INVALID', 'LIMIT', '', None):
            self.assertEqual(join.format_stats(old), '')
        # A region's state: down shows offline (no counts), up or anything else the counts.
        states = 'OK 7,normal,1,0,0,EU%20SERVER,up 5,normal,2,1,0,NA%20SERVER,down 6,duel,0,0,0,AS%20SERVER,later'
        self.assertEqual(join.format_stats(states), 'EU (normal): 1 online, 0 searching, 0 matches | NA (normal): offline | '
                                                    'AS (duel): 0 online, 0 searching, 0 matches')
        # The searching players per mode (the field after the state): in the game's order, FPP named,
        # none, unknown or broken parts left out; "-" (nobody searching) shows no modes.
        modes = 'OK 7,normal,9,6,1,EU%20SERVER,up,squad-fpp:1;solo-tpp:2;duo-tpp:0;arcade-tpp:5;solo-fpp:x;training-tpp:3 5,normal,0,0,0,NA%20SERVER,up,-'
        self.assertEqual(join.format_stats(modes), 'EU (normal): 9 online, 6 searching (solo 2, squad FPP 1, training 3), 1 match | '
                                                   'NA (normal): 0 online, 0 searching, 0 matches')
        self.assertEqual(join.format_stats('OK 5,normal,2,1,0,NA%20SERVER,down,solo-tpp:1'), 'NA (normal): offline')
        # The line after the login and while the game runs: every region (the live server's reply),
        # INFO only from a server without STATS, INFO's restart notice either way.
        live = 'OK 7,normal,0,0,0,EU%20SERVER 6,duel,0,0,0,AS%20SERVER'
        self.assertEqual(join.server_now('OK players=0 matches=0 waiting=0 restarting=0 name=ROE-OS', live),
                         'On the server now: EU (normal): 0 online, 0 searching, 0 matches | AS (duel): 0 online, 0 searching, 0 matches.')
        self.assertTrue(join.server_now('OK players=1 restarting=1', live).endswith(
            '0 matches. It restarts for an update soon; new searches are refused until then.'))
        for old in ('INVALID', None):
            self.assertTrue(join.server_now('OK players=2 matches=1 waiting=0 restarting=0', old).startswith(
                'On the server now: 2 players online, 1 match running'))

    def test_server_names(self):
        # The INFO field: decoded, cleaned; an empty or missing one is ''.
        self.assertEqual(join.info_server_name('OK players=1 matches=0 waiting=0 restarting=0 name=Europa%20EU%20%C3%A9'), 'Europa EU \u00e9')
        self.assertEqual(join.info_server_name('OK players=1 matches=0 waiting=0 restarting=0 name='), '')
        self.assertEqual(join.info_server_name('OK players=1 matches=0 waiting=0 restarting=0'), '')
        self.assertEqual(join.info_server_name('OK players=0 name=a%0Ab%1B' + '%41' * 50), 'ab' + 'A' * 38)
        # The counts read as before; a name cannot pass for one.
        self.assertTrue(join.server_info('OK players=2 matches=1 waiting=0 restarting=0 name=players%3D9').startswith(
            'On the server now: 2 players online, 1 match running'))
        # Saved with the server, shown in the menu, updated and removed.
        settings = {'servers': [{'address': 'a.example', 'last_used': 30, 'name': 'Europa'},
                                                       {'address': 'b.example', 'last_used': 20},
                                                       {'address': 'c.example', 'last_used': 10, 'name': 'bad\x07'}]}
        servers = join.saved_servers(settings)
        shown = []
        join.choose_server(servers, choose=lambda entries: shown.append(entries) or 0, question=Answers())
        self.assertEqual(shown, [['Europa (a.example)', 'b.example', 'bad (c.example)', 'Enter another server (IP or domain)']])
        servers = join.remember_server(servers, 'A.example', now=99)
        self.assertEqual(servers[0], {'address': 'A.example', 'last_used': 99, 'name': 'Europa'})
        self.assertFalse(join.name_server(servers, 'A.example', 'Europa'))
        self.assertTrue(join.name_server(servers, 'A.example', 'Europa EU'))
        self.assertEqual(join.server_label(servers[0]), 'Europa EU (A.example)')
        self.assertTrue(join.name_server(servers, 'b.example', 'Dione'))
        self.assertTrue(join.name_server(servers, 'A.example', ''))
        self.assertEqual([join.server_label(s) for s in servers], ['A.example', 'Dione (b.example)', 'bad (c.example)'])
        # Through the settings file and back.
        again = join.saved_servers({'servers': json.loads(json.dumps(servers))})
        self.assertEqual([join.server_label(s) for s in again], ['A.example', 'Dione (b.example)', 'bad (c.example)'])

    def test_dry_run_server_menu(self):
        home = Path(self.tmp.name) / 'home'
        config = home / '.config'
        config.mkdir(parents=True)
        (config / 'roe-join.json').write_text(json.dumps({'servers': [
            {'address': '127.0.0.1', 'last_used': 20}, {'address': '127.0.0.2', 'last_used': 10}]}))
        game = Path(self.tmp.name) / 'game'
        touch(game / 'Europa_Client.exe', 'not the game')
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), ROE_JOIN_DRY_RUN='1', PROTON=str(home / 'none'))
        command = [sys.executable, '-I', str(JOIN), '--game', str(game), '--voice', 'off']
        result = subprocess.run(command, env=env, input='3\n127.0.0.9\n', capture_output=True, text=True, timeout=30)
        self.assertIn('Server:\n  1. 127.0.0.1\n  2. 127.0.0.2\n  3. Enter another server (IP or domain)', result.stdout,
                      result.stdout + result.stderr)
        self.assertIn('Would log in to 127.0.0.9:8002', result.stdout)
        result = subprocess.run(command + ['--server', '127.0.0.3'], env=env, input='', capture_output=True, text=True, timeout=30)
        self.assertNotIn('Server:', result.stdout)
        self.assertIn('Would log in to 127.0.0.3:8002', result.stdout, result.stdout + result.stderr)


def run_powershell(test, harness, prepare, checks, code=None):
    """Runs a join-roe-os.cmd harness through powershell.exe in a Windows temp folder; asserts its OK lines.
    code: the file with the PowerShell code (default join-roe-os.cmd; separate-files/join-roe-os.ps1)."""
    # On a Windows drive: File.Replace (Copy-Checked) does not work on the WSL share.
    temp = subprocess.run(['cmd.exe', '/c', 'echo %TEMP%'], cwd='/mnt/c', capture_output=True, text=True).stdout.strip()
    temp = subprocess.run(['wslpath', '-u', temp], capture_output=True, text=True).stdout.strip()
    if not temp or not Path(temp).is_dir():
        test.skipTest('no Windows temp folder')
    with tempfile.TemporaryDirectory(dir=temp) as tmp:
        base = Path(tmp)
        prepare(base)
        source = base / 'join.ps1'
        shutil.copyfile(code or JOIN.parent / 'join-roe-os.cmd', source)

        def win(path):
            return subprocess.run(['wslpath', '-w', str(path)], capture_output=True, text=True, check=True).stdout.strip()
        script = Path(__file__).resolve().parent / harness
        result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', win(script),
                                 '-Source', win(source), '-Base', win(base)],
                                cwd='/mnt/c', stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=50)
        lines = [line.strip() for line in result.stdout.splitlines()]
        report = result.stdout + result.stderr
        test.assertEqual(result.returncode, 0, report)
        test.assertFalse([line for line in lines if line.startswith('FAIL')], report)
        test.assertEqual(len([line for line in lines if line.startswith('OK ')]), checks, report)


@unittest.skipUnless(shutil.which('powershell.exe') and shutil.which('wslpath'), 'needs powershell.exe (WSL)')
class JoinCmdAccounts(unittest.TestCase):
    """join-roe-os.cmd's account menu, accounts.json and login against a fake service (through powershell.exe)."""
    def test_functions(self):
        run_powershell(self, 'join_cmd_accounts.ps1', lambda base: None, 40)


@unittest.skipUnless(shutil.which('powershell.exe') and shutil.which('wslpath'), 'needs powershell.exe (WSL)')
class JoinCmdServers(unittest.TestCase):
    """join-roe-os.cmd's server menu, the servers list and -Server (through powershell.exe)."""
    def test_functions(self):
        run_powershell(self, 'join_cmd_servers.ps1', lambda base: None, 52)

    def test_with_steam(self):
        run_powershell(self, 'join_cmd_servers.ps1', lambda base: None, 52, WITH_STEAM)


@unittest.skipUnless(shutil.which('powershell.exe') and shutil.which('wslpath'), 'needs powershell.exe (WSL)')
class JoinCmdFirewall(unittest.TestCase):
    """join-roe-os.cmd's ADDRESSES parsing, blocked ranges, trusted servers and rule updates (through powershell.exe)."""
    def test_functions(self):
        run_powershell(self, 'join_cmd_firewall.ps1', lambda base: None, 56)

    def test_with_steam(self):
        run_powershell(self, 'join_cmd_firewall.ps1', lambda base: None, 56, WITH_STEAM)


class JoinCmdElevation(unittest.TestCase):
    """The administrator prompt of both join-roe-os.cmd copies: started with the window it belongs to
    (Start-Process names none, so the prompt could open behind), not hidden, without P/Invoke in the main one."""
    def test_start(self):
        for path in (JOIN.parent / 'join-roe-os.cmd', WITH_STEAM):
            text = path.read_text()
            with self.subTest(path=path.parent.name):
                self.assertNotRegex(text, r'(?i)-Verb\s+RunAs')
                if path != WITH_STEAM:
                    self.assertNotIn('DllImport', text)
                self.assertEqual(text.count('[Diagnostics.Process]::Start((New-ElevatedStart $Arguments (Get-PromptOwner)))'), 1)
                self.assertIn("$start.ErrorDialog = $true", text)
                self.assertIn("$start.ErrorDialogParentHandle = $Owner", text)
                self.assertIn("$start.WindowStyle = 'Normal'", text)
                self.assertIn('$window.Add_SourceInitialized({ $sync.Owner = (New-Object Windows.Interop.WindowInteropHelper $this).Handle })', text)
                self.assertIn("if ($sync) { $sync.Events.Enqueue([pscustomobject]@{ Kind = 'front'; Data = $null });", text)
                self.assertIn('Try again? (y/n)', text)


class NoCompiledCode(unittest.TestCase):
    """join-roe-os.cmd compiles no C# at run time (Add-Type with source or DllImport: what virus
    scanners flag); its only Add-Type loads the WPF and WinForms assemblies. No em dash, not even made."""
    def test_main_copy(self):
        text = (JOIN.parent / 'join-roe-os.cmd').read_text()
        self.assertEqual(set(re.findall(r'(?i)Add-Type\s+-?\w*', text)), {'Add-Type -AssemblyName'})
        self.assertNotRegex(text, r'(?i)DllImport|TypeDefinition|MemberDefinition|ComImport')
        self.assertNotIn('\u2014', text)
        self.assertNotRegex(text, r'(?i)0x2014')

    def test_steam_copy(self):
        """The Steam copy: the same, plus the one Add-Type its Steam start needs (hiding the console
        Steam's cmd.exe opens): kernel32/user32 console window calls, nothing for the window's look."""
        text = WITH_STEAM.read_text()
        self.assertEqual(set(re.findall(r'(?i)Add-Type\s+-?\w*', text)), {'Add-Type -AssemblyName', 'Add-Type -Namespace'})
        self.assertEqual(len(re.findall(r'(?i)Add-Type\s+-Namespace', text)), 1)
        self.assertEqual(len(re.findall(r'(?i)MemberDefinition', text)), 1)
        self.assertNotRegex(text, r'(?i)TypeDefinition|ComImport|dwmapi|shell32|IFileOpenDialog|DwmSetWindowAttribute')
        self.assertEqual(sorted(re.findall(r'\[DllImport\("(\w+\.dll)"[^]]*\] public static extern \w+ (\w+)\(', text)),
                         [('kernel32.dll', 'GetConsoleWindow'), ('user32.dll', 'GetClassName'), ('user32.dll', 'GetWindow'), ('user32.dll', 'ShowWindow')])
        self.assertEqual(len(re.findall(r'DllImport', text)), 4)
        self.assertNotIn('\u2014', text)
        self.assertNotRegex(text, r'(?i)0x2014')


@unittest.skipUnless(shutil.which('powershell.exe') and shutil.which('wslpath'), 'needs powershell.exe (WSL)')
class JoinCmdExport(unittest.TestCase):
    """join-roe-os.cmd's account backup: export, import, merge and a different certificate (through powershell.exe)."""
    def test_functions(self):
        def prepare(base):
            # A backup written by join-roe-os.py, for join-roe-os.cmd's import.
            root = base / 'py'
            join.save_accounts(root / 'linux.example', [{'name': 'Penny', 'token': 'f' * 64, 'last_used': 7}])
            (root / 'linux.example/server.pin').write_text('4' * 64 + '\n', encoding='ascii')
            join.export_accounts(root, {'servers': [{'address': 'linux.example', 'last_used': 7, 'name': 'Linux EU'}]}, base / 'py-backup.json')
        run_powershell(self, 'join_cmd_export.ps1', prepare, 13)


class AccountBackup(unittest.TestCase):
    """join-roe-os.py's --export / --import: the same file as join-roe-os.cmd's, merged, a different certificate asked."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_export_import_merge(self):
        root = self.base / 'one'
        join.save_accounts(root / 'play.example.org', [{'name': 'Anna', 'token': 'a' * 64, 'last_used': 50},
                                                       {'name': 'Ben', 'token': 'b' * 64, 'last_used': 40}])
        (root / 'play.example.org/server.pin').write_text('1' * 64 + '\n', encoding='ascii')
        join.save_accounts(root / '203.0.113.5', [{'name': 'Cleo', 'token': 'c' * 64, 'last_used': 30}])
        (root / '203.0.113.5/server.pin').write_text('2' * 64 + '\n', encoding='ascii')
        settings = {'servers': [{'address': 'Play.Example.org', 'last_used': 50, 'name': 'Europa'},
                                {'address': '203.0.113.5', 'last_used': 30}]}
        backup = self.base / 'backup.json'
        self.assertEqual(join.export_accounts(root, settings, backup), (2, 3))
        data = json.loads(backup.read_text())
        self.assertEqual((data['format'], data['version'], data['servers'][0]['address'], data['servers'][0]['name']),
                         ('roe-join-accounts', 1, 'Play.Example.org', 'Europa'))
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
        self.assertIn('account keys', join.BACKUP_WARNING)

        other = self.base / 'two'
        join.save_accounts(other / 'play.example.org', [{'name': 'Anna', 'token': 'a' * 64, 'last_used': 10},
                                                         {'name': 'Dora', 'token': 'd' * 64, 'last_used': 99},
                                                         {'name': 'Ben', 'token': 'e' * 64, 'last_used': 90}])
        (other / 'play.example.org/server.pin').write_text('1' * 64 + '\n', encoding='ascii')
        (other / '203.0.113.5').mkdir()
        (other / '203.0.113.5/server.pin').write_text('3' * 64 + '\n', encoding='ascii')
        mine = {'servers': [{'address': 'play.example.org', 'last_used': 99}]}
        answers = Answers('n')
        with contextlib.redirect_stdout(io.StringIO()):
            done = join.import_accounts(other, mine, backup, answers)
        merged = {a['name']: a for a in join.load_accounts(other / 'play.example.org')}
        self.assertEqual((merged['Anna']['last_used'], merged['Ben']['token'], len(merged)), (50, 'e' * 64, 3))
        self.assertEqual((done['added'], done['updated'], done['skipped']), (0, 1, ['203.0.113.5']))
        self.assertEqual(answers.asked[0][1], 'n')
        self.assertEqual(join.read_pin(other / '203.0.113.5'), '3' * 64)
        self.assertFalse((other / '203.0.113.5/accounts.json').exists())
        with contextlib.redirect_stdout(io.StringIO()):
            done = join.import_accounts(other, mine, backup, Answers('y'))
        self.assertEqual((done['added'], join.read_pin(other / '203.0.113.5')), (1, '2' * 64))
        self.assertEqual([(s['address'], s.get('name')) for s in done['servers']], [('play.example.org', 'Europa'), ('203.0.113.5', None)])
        done = join.import_accounts(other, mine, backup, Answers())  # nothing new, nothing asked
        self.assertEqual((done['added'], done['updated']), (0, 0))

    def test_join_cmd_file_and_refusals(self):
        # A file as join-roe-os.cmd writes it (BOM-less UTF-8, its own layout) and unsafe or foreign files.
        backup = self.base / 'cmd.json'
        backup.write_text(json.dumps({'format': 'roe-join-accounts', 'version': 1, 'servers': [
            {'address': 'Play.Example.org', 'name': 'Europa', 'pin': '1' * 64, 'accounts': [{'name': 'Anna', 'token': 'a' * 64, 'last_used': 5}]},
            {'address': '../../x', 'name': '', 'pin': '', 'accounts': [{'name': 'X', 'token': 'b' * 64, 'last_used': 1}]}]}), encoding='utf-8')
        fresh = self.base / 'fresh'
        done = join.import_accounts(fresh, {}, backup)
        self.assertEqual(done['added'], 1)
        self.assertEqual(done['servers'], [{'address': 'Play.Example.org', 'last_used': 5, 'name': 'Europa'}])
        self.assertFalse((self.base / 'x').exists())
        backup.write_text('{"accounts": []}', encoding='utf-8')
        with self.assertRaises(join.Failure):
            join.import_accounts(fresh, {}, backup)

    def test_options(self):
        self.assertEqual(join.parse_arguments(['--export']).export, '')
        self.assertEqual(join.parse_arguments(['--export', 'x.json']).export, 'x.json')
        self.assertEqual(join.parse_arguments(['--import', 'x.json']).import_, 'x.json')
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            join.parse_arguments(['--export', 'a', '--import', 'b'])


@unittest.skipUnless(shutil.which('powershell.exe') and shutil.which('wslpath'), 'needs powershell.exe (WSL)')
class JoinCmdVoice(unittest.TestCase):
    """join-roe-os.cmd parses, and its voice DLL functions work on fake folders (through powershell.exe)."""
    def test_functions(self):
        def prepare(base):
            ours = fake_dll(b'GetVoiceEngine our voice dll')
            original = fake_dll(b'GetVoiceEngine original voice dll')
            touch(base / 'game/Europa_Client.exe', 'not the game')
            (base / 'game/GCloudVoice.dll').write_bytes(original)
            for folder, data in (('package/voice', ours), ('copy', original), ('nohash', fake_dll(b'GetVoiceEngine 2')),
                                 ('x86', fake_dll(b'GetVoiceEngine', machine=0x14c)), ('noexport', fake_dll(b'nothing'))):
                (base / folder).mkdir(parents=True)
                (base / folder / 'GCloudVoice.dll').write_bytes(data)
        run_powershell(self, 'join_cmd_voice.ps1', prepare, 32)


def fake_install(base):
    """A fake Ring of Elysium folder with an XVersion folder; its files stand for the originals."""
    game = base / 'game'
    for rel, text in (('Europa_Client.exe', 'not the game'), ('SFC/Common.sfc', 'common archive'), ('SFC/UI.sfc', 'ui archive'),
                      ('data_dyn.sfc', 'dyn archive'), ('Cache/otherbin.sfc', 'cache archive'),
                      ('XVersion/Europa_Client.exe', 'not the dx12 game')):
        touch(game / rel, text)
    (game / 'GCloudVoice.dll').write_bytes(fake_dll(b'GetVoiceEngine original'))
    (game / 'XVersion/GCloudVoice.dll').write_bytes(fake_dll(b'GetVoiceEngine original, dx12'))
    shutil.copyfile(game / 'XVersion/GCloudVoice.dll', base / 'xversion-voice.dll')
    return game


class GameFiles(unittest.TestCase):
    """join-roe-os.py's game file check on a fake install whose files stand for the originals."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.game = fake_install(self.base)
        self.cache = self.base / 'config/file-check.json'
        self.backups = self.base / 'backups'
        saved = (join.ORIGINAL_FILES, join.ORIGINAL_VOICE_SHA)
        self.addCleanup(lambda: (setattr(join, 'ORIGINAL_FILES', saved[0]), setattr(join, 'ORIGINAL_VOICE_SHA', saved[1])))
        self.addCleanup(self.tmp.cleanup)
        join.ORIGINAL_FILES = tuple((rel, (self.game / rel).stat().st_size, join.sha256(self.game / rel))
                                    for rel in ('SFC/Common.sfc', 'SFC/UI.sfc', 'data_dyn.sfc', 'Cache/otherbin.sfc'))
        join.ORIGINAL_VOICE_SHA = {join.sha256(self.game / 'GCloudVoice.dll'), join.sha256(self.game / 'XVersion/GCloudVoice.dll')}

    def changed(self, client=None, write=True):
        return join.changed_game_files(client or self.game, self.backups, self.cache, write)

    def test_lists(self):
        real = importlib.util.module_from_spec(spec)   # the real lists, not the test's
        spec.loader.exec_module(real)
        self.assertEqual(len(real.ORIGINAL_FILES), 7)
        self.assertTrue(all(re.fullmatch('[0-9a-f]{64}', sha) and size > 0 for _, size, sha in real.ORIGINAL_FILES))
        self.assertEqual(len(real.ORIGINAL_VOICE_SHA), 2)
        # The same files and hashes as join-roe-os.cmd's.
        cmd = (JOIN.parent / 'join-roe-os.cmd').read_text()
        for rel, size, sha in real.ORIGINAL_FILES:
            self.assertIn(f"@{{ Path = '{rel.replace('/', chr(92))}'; Size = {size}; Sha = '{sha}' }}", cmd)
        for sha in real.ORIGINAL_VOICE_SHA:
            self.assertIn(sha, cmd)
        self.assertIn("'" + "', '".join(real.ADDED_FILES[:7]) + "'", cmd)

    def test_original_and_cache(self):
        self.assertEqual(self.changed(), [])
        files = json.loads(self.cache.read_text())['files']
        ui = str(self.game / 'SFC/UI.sfc')
        self.assertEqual(len(files), 5)
        self.assertEqual(files[ui], {'size': (self.game / 'SFC/UI.sfc').stat().st_size,
                                     'time': (self.game / 'SFC/UI.sfc').stat().st_mtime_ns, 'sha256': join.ORIGINAL_FILES[1][2]})
        # Trusted while size and time are the same: a wrong hash there counts, nothing is hashed.
        files[ui]['sha256'] = '0' * 64
        self.cache.write_text(json.dumps({'files': files}))
        hashed = []
        real = join.sha256
        join.sha256 = lambda path: hashed.append(path) or real(path)
        try:
            self.assertEqual(self.changed(), ['SFC/UI.sfc changed'])
        finally:
            join.sha256 = real
        self.assertEqual(hashed, [])
        self.cache.write_text('not json')
        self.assertEqual(self.changed(), [])
        self.assertIn('sha256', self.cache.read_text())
        # A dry run writes nothing.
        self.cache.unlink()
        self.assertEqual(self.changed(write=False), [])
        self.assertFalse(self.cache.exists())

    def test_changed_missing_added(self):
        self.changed()
        ui = self.game / 'SFC/UI.sfc'
        ui.write_text('UI archive')   # the same size, another time
        os.utime(ui, ns=(ui.stat().st_atime_ns, ui.stat().st_mtime_ns + 10 ** 9))
        self.assertEqual(self.changed(), ['SFC/UI.sfc changed'])
        ui.write_text('ui archive')
        (self.game / 'SFC/Common.sfc').write_text('common archive and a block')
        (self.game / 'data_dyn.sfc').unlink()
        (self.game / 'DInput8.dll').write_text('proxy')
        (self.game / 'data_exp.vfs').write_text('overlay')
        (self.game / 'backup-of-another-tool').mkdir()
        found = self.changed()
        self.assertEqual(found[:2], ['SFC/Common.sfc changed', 'data_dyn.sfc missing'])
        self.assertEqual(sorted(found[2:]), ['DInput8.dll added', 'data_exp.vfs added'])
        text = join.game_files_text(found, self.game)
        self.assertEqual(len(text), 4)
        self.assertTrue(text[0].startswith('Your game files were changed by another launcher (SFC/Common.sfc changed, data_dyn.sfc missing'))
        self.assertEqual(text[1], f'Verify them in {join.VERIFY}.')
        self.assertTrue(text[2].startswith('Delete ') and text[2].endswith(f" in {self.game} (not part of the game; Steam's check leaves them)."))
        self.assertEqual(text[3], 'Then start again.')
        many = join.game_files_text(['a changed', 'b changed', 'c changed', 'd missing', 'e changed', 'f changed'], self.game)
        self.assertIn('(a changed, b changed, c changed, d missing, and 2 more)', many[0])
        self.assertEqual(len(join.game_files_text(['x.dll added'], self.game)), 3)   # nothing to verify

    def test_case(self):
        # A copy on a case-sensitive file system with other cases than the depot's.
        (self.game / 'SFC').rename(self.game / 'sfc')
        (self.game / 'sfc/UI.sfc').rename(self.game / 'sfc/ui.SFC')
        self.assertEqual(self.changed(), [])

    def test_voice(self):
        dll = self.game / 'GCloudVoice.dll'
        original = dll.read_bytes()
        dll.write_bytes(fake_dll(b'GetVoiceEngine ours'))
        self.assertEqual(self.changed(), ['GCloudVoice.dll changed'])
        folder = join.voice_backup_dir(self.backups, self.game)
        folder.mkdir(parents=True)
        (folder / 'backup.json').write_text(json.dumps({'folder': str(self.game), 'original': join.sha256(self.base / 'xversion-voice.dll'),
                                                        'installed': join.sha256(dll)}))
        self.assertEqual(self.changed(), [])
        dll.unlink()
        self.assertEqual(self.changed(), ['GCloudVoice.dll missing'])
        dll.write_bytes(original)

    def test_xversion(self):
        xversion = self.game / 'XVersion'
        self.assertEqual(self.changed(xversion), [])
        (xversion / 'version.dll').write_text('proxy')
        (xversion / 'GCloudVoice.dll').write_bytes(fake_dll(b'GetVoiceEngine another'))
        (self.game / 'SFC/UI.sfc').write_text('patched')
        found = self.changed(xversion)
        self.assertEqual(found, ['SFC/UI.sfc changed', 'XVersion/GCloudVoice.dll changed', 'XVersion/version.dll added'])
        self.assertEqual(join.game_files_text(found, xversion)[2],
                         f"Delete XVersion/version.dll in {self.game} (not part of the game; Steam's check leaves them).")
        self.assertEqual(self.changed(), ['SFC/UI.sfc changed'])   # the main folder: its own voice DLL

    def test_confirm(self):
        out = io.StringIO()
        confirm = lambda **kw: join.confirm_game_files(self.game, self.backups, cache_file=self.cache, **kw)
        with contextlib.redirect_stdout(out):
            self.assertTrue(confirm(question=Answers()))
            (self.game / 'SFC/UI.sfc').write_text('patched')
            asked = Answers('n')
            with self.assertRaises(join.Failure) as stop:
                confirm(question=asked)
            self.assertIn('Cancelled: the game files are not the original ones', str(stop.exception))
            self.assertEqual(asked.asked, [('Start the game anyway? (y/n)', 'n')])
            self.assertFalse(confirm(question=Answers('y')))
            self.assertFalse(confirm(question=Answers(), dry_run=True))
            self.assertTrue(confirm(question=Answers(), skip=True))
        self.assertIn('Then start again.', out.getvalue())
        self.assertIn('Would ask: Start the game anyway? (y/n)', out.getvalue())
        self.assertIn('Game file check skipped (--skip-file-check).', out.getvalue())
        self.assertTrue(join.parse_arguments(['--skip-file-check']).skip_file_check)
        self.assertFalse(join.parse_arguments([]).skip_file_check)


@unittest.skipUnless(shutil.which('powershell.exe') and shutil.which('wslpath'), 'needs powershell.exe (WSL)')
class JoinCmdFiles(unittest.TestCase):
    """join-roe-os.cmd's game file check: original, changed, missing and added files, XVersion, the cache and the question."""
    def test_functions(self):
        run_powershell(self, 'join_cmd_files.ps1', fake_install, 26)


@unittest.skipUnless(shutil.which('powershell.exe') and shutil.which('wslpath'), 'needs powershell.exe (WSL)')
class JoinGui(unittest.TestCase):
    """join-roe-os.cmd's window: its code loads, its windows parse, its worker and its server and play steps (no window shown)."""
    def test_functions(self):
        def prepare(base):
            (base / 'game').mkdir()
            (base / 'valid-voice.dll').write_bytes(fake_dll(b'GetVoiceEngine UI test'))
        run_powershell(self, 'join_gui.ps1', prepare, 58)


@unittest.skipUnless(shutil.which('cmd.exe') and shutil.which('wslpath'), 'needs cmd.exe (WSL)')
class JoinCmdStart(unittest.TestCase):
    """join-roe-os.cmd's batch part: the window for a double-click (cmd.exe /c, no arguments) or --window,
    the console with arguments, --console or typed in a prompt."""
    def run_batch(self, base, line):
        # The line typed into a command prompt (cmd.exe without /c); cmd /c ""<file>" " is how
        # Explorer starts a double-clicked file. APPDATA in the test folder: the batch part writes
        # its .ps1 copy there.
        appdata = subprocess.run(['wslpath', '-w', str(base)], capture_output=True, text=True, check=True).stdout.strip()
        result = subprocess.run(['cmd.exe'], cwd=str(base), input=f'set "APPDATA={appdata}"\r\n' + line + '\r\nexit\r\n',
                                capture_output=True, text=True, timeout=30)
        return [line.strip() for line in result.stdout.splitlines() if line.strip().startswith('MODE ')]

    def windows_temp(self):
        temp = subprocess.run(['cmd.exe', '/c', 'echo %TEMP%'], cwd='/mnt/c', capture_output=True, text=True).stdout.strip()
        temp = subprocess.run(['wslpath', '-u', temp], capture_output=True, text=True).stdout.strip()
        if not temp or not Path(temp).is_dir():
            self.skipTest('no Windows temp folder')
        return temp

    def check_modes(self, batch, base, name='join-roe-os.cmd'):
        """Writes the batch part with its PowerShell starts printing what they would start; checks the modes."""
        batch = batch.replace('\r\n', '\n')
        window = 'start "" /min powershell.exe '
        console = '\npowershell.exe '
        self.assertEqual((batch.count(window), batch.count('\n  powershell.exe '), batch.count(console)), (1, 0, 1))
        batch = batch.replace(window, 'echo MODE window & rem ')
        batch = batch.replace(console, '\necho MODE console [%ROE_JOIN_ARGS%] & rem ')
        (base / name).write_text(batch.replace('\n', '\r\n'), newline='')
        path = subprocess.run(['wslpath', '-w', str(base / name)], capture_output=True, text=True, check=True).stdout.strip()
        self.assertEqual(self.run_batch(base, f'cmd /c ""{path}" "'), ['MODE window'])
        self.assertEqual(self.run_batch(base, f'cmd /C ""{path}""'), ['MODE window'])
        self.assertEqual(self.run_batch(base, f'cmd /c ""{path}" --window"'), ['MODE window'])
        self.assertEqual(self.run_batch(base, f'cmd /c ""{path}" --console"'), ['MODE console [--console]'])
        self.assertEqual(self.run_batch(base, f'cmd /c ""{path}" -Server roe-os.de -Name "Anna Lee""'), ['MODE console [-Server roe-os.de -Name "Anna Lee"]'])
        self.assertEqual(self.run_batch(base, f'cmd /c ""{path}" firewall"'), ['MODE console [firewall]'])
        # Typed in the prompt: the console, also without arguments.
        self.assertEqual(self.run_batch(base, f'"{path}"'), ['MODE console []'])
        self.assertEqual(self.run_batch(base, f'"{path}" export'), ['MODE console [export]'])
        self.assertEqual(self.run_batch(base, f'"{path}" --window'), ['MODE window'])
        # --window with more after it (Steam's launch option --window %command%): the window.
        self.assertEqual(self.run_batch(base, f'cmd /c ""{path}" --window -x"'), ['MODE window'])
        self.assertEqual(self.run_batch(base, f'cmd /c ""{path}" --window "C:\\Steam\\steamapps\\common\\Ring of Elysium\\SLauncher.exe" -steam -maintenance"'), ['MODE window'])
        self.assertEqual(self.run_batch(base, f'cmd /c ""{path}" --windowed"'), ['MODE console [--windowed]'])

    def test_window_or_console(self):
        temp = self.windows_temp()
        batch = (JOIN.parent / 'join-roe-os.cmd').read_text().split('#>')[0]
        with tempfile.TemporaryDirectory(dir=temp) as tmp:
            base = Path(tmp) / 'a b!c'
            base.mkdir()
            self.check_modes(batch, base)
            # PowerShell runs a .ps1 copy of the file (-File), written without the download's mark.
            copies = list((base / 'roe-join').glob('run-*.ps1'))
            self.assertTrue(copies)
            self.assertEqual(copies[0].read_bytes(), (base / 'join-roe-os.cmd').read_bytes())


# A localconfig.vdf as Steam writes it (tabs, LF), cut down: the game's block without launch
# options, another game's with some, and a "755790" elsewhere that must stay.
SAMPLE_VDF = '''"UserLocalConfigStore"
{
\t"friends"
\t{
\t\t"755790"\t\t"not this one"
\t}
\t// a comment
\t"Software"
\t{
\t\t"Valve"
\t\t{
\t\t\t"Steam"
\t\t\t{
\t\t\t\t"apps"
\t\t\t\t{
\t\t\t\t\t"730"
\t\t\t\t\t{
\t\t\t\t\t\t"LaunchOptions"\t\t"-novid \\"quoted\\" C:\\\\x"
\t\t\t\t\t}
\t\t\t\t\t"755790"
\t\t\t\t\t{
\t\t\t\t\t\t"LastPlayed"\t\t"1795123896"
\t\t\t\t\t\t"Playtime"\t\t"60437"
\t\t\t\t\t}
\t\t\t\t}
\t\t\t}
\t\t}
\t}
}
'''
STEAM_LINE = r'"C:\Users\A B\Desktop\join-roe-os.cmd" %command%'


def steam_tree(home, vdf=SAMPLE_VDF, user='30642568'):
    """A Steam folder in home with one user's localconfig.vdf and loginusers.vdf; the file's path."""
    root = home / '.local/share/Steam'
    path = touch(root / f'userdata/{user}/config/localconfig.vdf')
    path.write_bytes(vdf.encode('utf-8'))
    touch(root / 'config/loginusers.vdf', '"users"\n{\n\t"%d"\n\t{\n\t\t"PersonaName"\t\t"Anna"\n\t\t"MostRecent"\t\t"1"\n'
          '\t\t"Timestamp"\t\t"1795073593"\n\t}\n}\n' % (int(user) + join.STEAM_ID64_BASE))
    return path


class SteamLaunch(unittest.TestCase):
    """Started through Steam: Steam's command, the game folder, the Steam profile and the launch
    options in localconfig.vdf (round trip, only that key, backup, Steam running)."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_steam_command(self):
        game = '/home/a/.local/share/Steam/steamapps/common/Ring of Elysium'
        command = ['/home/a/.local/share/Steam/ubuntu12_32/reaper', 'SteamLaunch', 'AppId=755790', '--',
                   '/x/SteamLinuxRuntime_sniper/_v2-entry-point', '--verb=waitforexitandrun', '--',
                   '/x/Proton 9.0/proton', 'waitforexitandrun', f'{game}/SLauncher.exe', '-steam', '-maintenance', '-windowed']
        ours, steam = join.split_steam_command(['--server', 'roe-os.de', '--steam'] + command)
        self.assertEqual((ours, steam), (['--server', 'roe-os.de'], command))
        self.assertEqual(join.split_steam_command(['--voice', 'off']), (['--voice', 'off'], None))
        index, folder = join.steam_game(command)
        self.assertEqual((index, folder), (9, game))
        self.assertEqual(join.steam_game(['C:\\Games\\Ring of Elysium\\europa_client.EXE'])[0], 0)
        self.assertEqual(join.steam_game(['proton', 'run', 'other.exe']), (None, None))
        started = join.steam_game_command(command, index, game + '/XVersion', ['-uid=7', '-server=1.2.3.4:8001'])
        self.assertEqual(started, command[:9] + [f'{game}/XVersion/Europa_Client.exe', '-uid=7', '-server=1.2.3.4:8001', '-windowed'])

    def test_steam_client(self):
        game = self.base / 'common/Ring of Elysium'
        touch(game / 'Europa_Client.exe')
        touch(game / 'XVersion/Europa_Client.exe')
        touch(self.base / 'other/Europa_Client.exe')
        self.assertEqual(join.steam_client(str(game), ''), str(game.resolve()))
        self.assertEqual(join.steam_client(str(game), str(game / 'XVersion')), str((game / 'XVersion').resolve()))
        self.assertEqual(join.steam_client(str(game), str(self.base / 'other')), str(game.resolve()))

    def test_steam_profile(self):
        accounts = [{'name': 'Anna', 'token': 'a' * 64, 'last_used': 9}, {'name': 'Bob', 'token': 'b' * 64, 'last_used': 5}]
        self.assertEqual(join.account_id('a' * 64), 'ffe054fe7ae0cb6d')
        settings = {'servers': [{'address': 'old.example', 'last_used': 1}, {'address': 'new.example', 'last_used': 7}]}
        self.assertEqual(join.steam_server(settings), 'new.example')
        self.assertEqual(join.steam_server(settings, 'given.example'), 'given.example')
        self.assertEqual(join.steam_server({}), '')
        self.assertEqual(join.steam_account(settings, 'new.example', accounts), (True, accounts[0]))
        self.assertEqual(join.steam_account(settings, 'new.example', []), (True, None))
        settings['steam'] = {'server': 'old.example', 'account': join.account_id('b' * 64)}
        self.assertEqual(join.steam_server(settings), 'old.example')
        self.assertEqual(join.steam_account(settings, 'old.example', accounts), (True, accounts[1]))
        self.assertEqual(join.steam_account(settings, 'old.example', accounts[:1]), (False, None))
        self.assertEqual(join.steam_account(settings, 'new.example', accounts), (True, accounts[0]))

    def test_vdf_round_trip(self):
        self.assertIsNone(join.launch_options(SAMPLE_VDF))
        self.assertEqual(join.launch_options(SAMPLE_VDF, '730'), '-novid "quoted" C:\\x')
        added = join.set_launch_options(SAMPLE_VDF, STEAM_LINE)
        self.assertEqual(join.launch_options(added), STEAM_LINE)
        # Only one line more, in the game's block, escaped as Steam does.
        line = '\t\t\t\t\t\t"LaunchOptions"\t\t"\\"C:\\\\Users\\\\A B\\\\Desktop\\\\join-roe-os.cmd\\" %command%"\n'
        self.assertEqual(added, SAMPLE_VDF.replace('"60437"\n', '"60437"\n' + line))
        changed = join.set_launch_options(added, '-dx11')
        self.assertEqual(changed, SAMPLE_VDF.replace('"60437"\n', '"60437"\n\t\t\t\t\t\t"LaunchOptions"\t\t"-dx11"\n'))
        self.assertEqual(join.set_launch_options(changed, None), SAMPLE_VDF)
        self.assertEqual(join.set_launch_options(SAMPLE_VDF, None), SAMPLE_VDF)
        self.assertEqual(join.launch_options(changed, '730'), '-novid "quoted" C:\\x')
        # CRLF stays CRLF.
        crlf = SAMPLE_VDF.replace('\n', '\r\n')
        self.assertEqual(join.set_launch_options(crlf, '-x'), crlf.replace('"60437"\r\n', '"60437"\r\n\t\t\t\t\t\t"LaunchOptions"\t\t"-x"\r\n'))
        self.assertEqual(join.set_launch_options(join.set_launch_options(crlf, '-x'), None), crlf)
        # No block for the game yet (never started): added in apps; no apps: added too.
        other = SAMPLE_VDF.replace('755790"\n\t\t\t\t\t{', '228980"\n\t\t\t\t\t{')
        made = join.set_launch_options(other, '-x')
        self.assertEqual(join.launch_options(made), '-x')
        self.assertEqual(made, other.replace('\t\t\t\t}\n\t\t\t}\n', '\t\t\t\t\t"755790"\n\t\t\t\t\t{\n\t\t\t\t\t\t"LaunchOptions"\t\t"-x"\n'
                                                             '\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n', 1))
        bare = '"UserLocalConfigStore"\n{\n\t"x"\t\t"1"\n}\n'
        self.assertEqual(join.launch_options(join.set_launch_options(bare, '-x')), '-x')
        with self.assertRaises(ValueError):
            join.set_launch_options('"Other"\n{\n}\n', '-x')
        for damaged in ('"UserLocalConfigStore"\n{\n', '"UserLocalConfigStore"\n{\n}\n}\n', '"a" "b" "c"\n', '"open'):
            with self.assertRaises(ValueError, msg=damaged):
                join.vdf_parse(damaged)

    def test_write_backup(self):
        path = steam_tree(self.base)
        backup = join.write_launch_options(path, STEAM_LINE, now=1795000000)
        self.assertEqual(backup.read_bytes(), SAMPLE_VDF.encode('utf-8'))
        self.assertTrue(backup.name.startswith('localconfig.vdf.') and backup.name.endswith('.roe-join.bak'))
        self.assertEqual(join.launch_options(path.read_text(encoding='utf-8')), STEAM_LINE)
        self.assertIsNone(join.write_launch_options(path, STEAM_LINE))
        self.assertEqual(len(list(path.parent.glob('*.bak'))), 1)
        path.write_bytes(b'"UserLocalConfigStore"\n{\n\t"x"\t\t"\xff"\n}\n')
        with self.assertRaises(join.Failure):
            join.write_launch_options(path, STEAM_LINE)

    def setup(self, *argv, running=False, answers=('y',)):
        config = self.base / 'config'
        options = join.parse_arguments(list(argv))
        out = io.StringIO()
        with unittest.mock.patch.object(join, 'CONFIG', config), unittest.mock.patch.object(join, 'SETTINGS', config / 'roe-join.json'), \
                contextlib.redirect_stdout(out):
            settings = {}
            try:
                join.steam_setup_command(options, settings, home=self.base / 'home', question=Answers(*answers),
                                         running=lambda: running, script='/games/roe/join-roe-os.py')
            finally:
                self.said = out.getvalue()
        return settings

    def test_setup(self):
        path = steam_tree(self.base / 'home')
        line = 'python3 "/games/roe/join-roe-os.py" --steam %command%'
        self.assertEqual(join.steam_launch_line('/games/roe/join-roe-os.py'), line)
        with self.assertRaises(join.Failure) as refused:
            self.setup('--steam-setup', running=True)
        self.assertIn('Steam is running', str(refused.exception))
        self.assertIn(line, self.said)
        self.assertEqual(path.read_bytes(), SAMPLE_VDF.encode('utf-8'))
        self.assertEqual(list(path.parent.glob('*.bak')), [])
        self.setup('--steam-setup', answers=('n',))
        self.assertEqual(path.read_bytes(), SAMPLE_VDF.encode('utf-8'))
        self.setup('--steam-setup')
        self.assertEqual(join.launch_options(path.read_text(encoding='utf-8')), line)
        self.assertIn('Set in Steam', self.said)
        self.setup('--steam-setup', 'off')
        self.assertEqual(path.read_bytes(), SAMPLE_VDF.encode('utf-8'))
        # Someone else's launch options stay.
        path.write_text(join.set_launch_options(SAMPLE_VDF, '-dx11'), encoding='utf-8')
        self.setup('--steam-setup', 'off')
        self.assertIn('not ours', self.said)
        self.assertEqual(join.launch_options(path.read_text(encoding='utf-8')), '-dx11')
        # A line set up before the rename (the old join.py) is ours: setup replaces it, off removes it.
        old = 'python3 "/games/roe/join.py" --steam %command%'
        self.assertTrue(join.is_ours(old) and join.is_ours('"C:\\x\\join.cmd" %command%') and join.is_ours(line)
                        and join.is_ours('"C:\\x\\separate-files\\join-roe-os-window.cmd" --window %command%'))
        self.assertFalse(join.is_ours('-dx11'))
        path.write_text(join.set_launch_options(SAMPLE_VDF, old), encoding='utf-8')
        self.setup('--steam-setup')
        self.assertIn('Replacing', self.said)
        self.assertEqual(join.launch_options(path.read_text(encoding='utf-8')), line)
        path.write_text(join.set_launch_options(SAMPLE_VDF, old), encoding='utf-8')
        self.setup('--steam-setup', 'off')
        self.assertIsNone(join.launch_options(path.read_text(encoding='utf-8')))

    def test_setup_profile(self):
        steam_tree(self.base / 'home')
        join.save_accounts(self.base / 'config/roe-join/roe-os.de', [{'name': 'Anna', 'token': 'a' * 64, 'last_used': 1}])
        settings = self.setup('--server', 'roe-os.de', '--name', 'anna', '--steam-setup', answers=('n',))
        self.assertEqual(settings['steam'], {'server': 'roe-os.de', 'account': 'ffe054fe7ae0cb6d'})
        self.assertEqual(json.loads((self.base / 'config/roe-join.json').read_text())['steam'], settings['steam'])
        with self.assertRaises(join.Failure):
            self.setup('--server', 'roe-os.de', '--name', 'Nobody', '--steam-setup', answers=('n',))
        self.assertNotIn('steam', self.setup('--steam-setup', answers=('n',)))

    def test_users(self):
        steam_tree(self.base, user='30642568')
        root = self.base / '.local/share/Steam'
        touch(root / 'userdata/111/config/localconfig.vdf', '"UserLocalConfigStore"\n{\n}\n')
        touch(root / 'userdata/ac/config/localconfig.vdf', '')
        users = join.steam_users(root)
        self.assertEqual([(u['id'], u['owns'], u['name']) for u in users], [('30642568', True, 'Anna'), ('111', False, '')])
        self.assertEqual(join.choose_steam_user(users, choose=lambda entries: 1)['id'], '30642568')
        both = [dict(u, owns=True) for u in users]
        picked = []
        self.assertEqual(join.choose_steam_user(both, choose=lambda entries: picked.append(entries) or 1)['id'], '111')
        self.assertEqual(picked, [['Anna (30642568)', '111']])

    def test_steam_running(self):
        proc = self.base / 'proc'
        touch(proc / '12/comm', 'bash\n')
        self.assertFalse(join.steam_running(proc))
        touch(proc / '13/comm', 'steam\n')
        self.assertTrue(join.steam_running(proc))

    def test_dry_run_from_steam(self):
        home = self.base / 'home'
        config = home / '.config'
        config.mkdir(parents=True)
        (config / 'roe-join.json').write_text(json.dumps({'voice': False, 'servers': [
            {'address': '127.0.0.1', 'last_used': 20}, {'address': '127.0.0.2', 'last_used': 10}]}))
        game = self.base / 'steamapps/common/Ring of Elysium'
        touch(game / 'Europa_Client.exe', 'not the game')
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), ROE_JOIN_DRY_RUN='1')
        command = [sys.executable, '-I', str(JOIN), '--steam', '/x/proton', 'waitforexitandrun', str(game / 'SLauncher.exe'), '-steam', '-maintenance']
        result = subprocess.run(command, env=env, input='', capture_output=True, text=True, timeout=30)
        report = result.stdout + result.stderr
        self.assertNotIn('Server:', result.stdout, report)
        self.assertIn('Would log in to 127.0.0.1:8002 as a new account', result.stdout, report)
        self.assertIn(f"Would run Steam's command (in the game folder): /x/proton waitforexitandrun '{game.resolve()}/Europa_Client.exe' "
                      "-language=en -garena '-uid=<ticket>' -server=127.0.0.1:8001", result.stdout, report)
        result = subprocess.run(command[:3] + ['--steam', 'proton', 'run', 'other.exe'], env=env, input='', capture_output=True, text=True, timeout=30)
        self.assertIn('names no SLauncher.exe or Europa_Client.exe', result.stdout)


WITH_STEAM = JOIN.parent / 'with-steam' / 'join-roe-os.cmd'


@unittest.skipUnless(shutil.which('powershell.exe') and shutil.which('wslpath'), 'needs powershell.exe (WSL)')
class WithSteam(unittest.TestCase):
    """with-steam/join-roe-os.cmd: join-roe-os.cmd with Start through Steam: the Steam start's functions
    (command line, game folder, profile, launch options in localconfig.vdf, the same as join-roe-os.py's)
    and its window (through powershell.exe)."""
    def test_steam_functions(self):
        def prepare(base):
            (base / 'sample.vdf').write_bytes(SAMPLE_VDF.encode('utf-8'))
            added = join.set_launch_options(SAMPLE_VDF, STEAM_LINE)
            (base / 'added.vdf').write_bytes(added.encode('utf-8'))
            other = SAMPLE_VDF.replace('755790"\n\t\t\t\t\t{', '228980"\n\t\t\t\t\t{')
            (base / 'other.vdf').write_bytes(other.encode('utf-8'))
            (base / 'other-added.vdf').write_bytes(join.set_launch_options(other, '-x').encode('utf-8'))
            crlf = SAMPLE_VDF.replace('\n', '\r\n')
            (base / 'crlf.vdf').write_bytes(crlf.encode('utf-8'))
            (base / 'crlf-added.vdf').write_bytes(join.set_launch_options(crlf, '-x').encode('utf-8'))
            steam = base / 'steam'
            touch(steam / 'userdata/30642568/config/localconfig.vdf').write_bytes(SAMPLE_VDF.encode('utf-8'))
            touch(steam / 'userdata/111/config/localconfig.vdf', '"UserLocalConfigStore"\n{\n}\n')
            touch(steam / 'config/loginusers.vdf', '"users"\n{\n\t"%d"\n\t{\n\t\t"PersonaName"\t\t"Anna"\n\t\t"MostRecent"\t\t"1"\n\t}\n}\n'
                  % (30642568 + join.STEAM_ID64_BASE))
            touch(base / 'game/Europa_Client.exe')
            touch(base / 'game/XVersion/Europa_Client.exe')
        run_powershell(self, 'join_cmd_steam.ps1', prepare, 55, WITH_STEAM)

    def test_window(self):
        def prepare(base):
            (base / 'game').mkdir()
            (base / 'valid-voice.dll').write_bytes(fake_dll(b'GetVoiceEngine UI test'))
        run_powershell(self, 'join_gui_steam.ps1', prepare, 71, WITH_STEAM)

    def test_same_server_part(self):
        """The Steam copy is the main script plus the Steam start: the same version line."""
        version = re.compile(r"^\$joinVersion = '[0-9.]+'", re.M)
        steam = version.findall(WITH_STEAM.read_text())
        self.assertEqual(len(steam), 1)
        self.assertEqual(steam, version.findall((JOIN.parent / 'join-roe-os.cmd').read_text()))



class WithSteamShared(unittest.TestCase):
    """with-steam/join-roe-os.cmd is join-roe-os.cmd plus the Steam start: the same functions, the same
    UI texts in every language, plus its own."""
    def test_functions(self):
        """Every function of the main copy, unchanged except the ones the Steam start adds to."""
        def functions(path):
            pattern = re.compile(r'^function ([\w-]+)\b[^\n]*?(?:\}\n|\{\n(?:.*?\n)*?^\}\n)', re.M | re.S)
            return {m.group(1): m.group(0) for m in pattern.finditer(path.read_text())}
        main, steam = functions(JOIN.parent / 'join-roe-os.cmd'), functions(WITH_STEAM)
        self.assertGreater(len(main), 150)
        self.assertEqual(set(main) - set(steam), set())
        self.assertEqual({name for name in main if main[name] != steam[name]},
                         {'Get-GuiControlNames', 'Get-GuiLanguages', 'Get-GuiXaml', 'Invoke-PlayJob', 'Save-JoinSettings',
                          'Start-Game', 'Start-Gui', 'Start-Play', 'Update-Controls'})
        self.assertEqual(set(steam) - set(main) - {'Hide-ConsoleWindow', 'Get-AccountId', 'Get-WindowLauncher', 'Get-OwnLaunchers', 'Get-LaunchState',
                                                   'Split-CommandLine', 'Set-GuiClipboard'},
                         {name for name in steam if re.search(r'Steam|Vdf|LaunchOptions', name)})

    def test_texts(self):
        """The same languages and texts, the Steam section's texts in every language."""
        def catalog(path):
            text = path.read_text()
            return json.loads(re.search(r"function Get-GuiLanguages \{\n    return \(ConvertFrom-Json @'\n(.*?)\n'@", text, re.S).group(1))
        main, steam = catalog(JOIN.parent / 'join-roe-os.cmd'), catalog(WITH_STEAM)
        self.assertEqual(list(main), list(steam))
        own = {'SteamSetup', 'SteamIntro', 'SteamByHand', 'SteamByHandHelp', 'SteamCopy', 'SteamAutomatic', 'SteamAutomaticHelp',
               'SteamSet', 'SteamUse', 'SteamOff', 'SteamAutoStart'}
        for code in main:
            with self.subTest(language=code):
                self.assertEqual({k: v for k, v in steam[code].items() if k not in own}, main[code])
                self.assertEqual(set(steam[code]) - set(main[code]), own)
                self.assertTrue(all(steam[code][k].strip() for k in own))
        xaml = WITH_STEAM.read_text()
        self.assertEqual(set(re.findall(r'Ui\.(Steam\w+)', xaml)), own)
        self.assertTrue(all(ord(c) < 128 for c in xaml))


if __name__ == '__main__':
    unittest.main()
