"""Exercise disposable install/upgrade/uninstall fixtures; never use real projects."""
from pathlib import Path
import ctypes
import hashlib
import json
import shutil
import subprocess
import tempfile
import time
import winreg
import uuid

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME = PROJECT_ROOT / 'bin' / 'WipRuntime.exe'
PRODUCT = 'Package Studio Release Acceptance ' + uuid.uuid4().hex
REGISTRY_KEY = r'Software\Microsoft\Windows\CurrentVersion\Uninstall\PackageStudioPro_' + PRODUCT


def exercise(work):
    assert not work.resolve().is_relative_to(Path.home().resolve()), 'Custom-folder regression must run outside the user profile'
    staging = work / 'staging'
    staging.mkdir()
    shutil.copy2(RUNTIME, staging / RUNTIME.name)
    payload = staging / 'payload'
    payload.mkdir()
    (payload / 'app.txt').write_text('version one')
    (payload / 'nested').mkdir()
    (payload / 'nested' / 'asset.txt').write_text('owned nested file')
    target = work / 'installed'
    target.mkdir()
    (target / 'app.txt').write_text('original user file')
    (target / 'user-project.txt').write_text('preserved project')
    (target / 'unrelated-empty-folder').mkdir()
    external = work / 'outside.txt'
    external.write_text('untouched external file')
    sibling = work / 'unrelated-sibling'
    sibling.mkdir()
    (sibling / 'keep.txt').write_text('untouched sibling folder')
    shortcut_paths = []
    common_shortcut_paths = []
    for csidl, paths in ((0x02, shortcut_paths), (0x10, shortcut_paths),
                         (0x17, common_shortcut_paths), (0x19, common_shortcut_paths)):
        folder = ctypes.create_unicode_buffer(260)
        assert ctypes.windll.shell32.SHGetFolderPathW(None, csidl, None, 0, folder) == 0
        shortcut = Path(folder.value) / (PRODUCT + '.lnk')
        assert not shortcut.exists(), 'Disposable shortcut name already exists'
        paths.append(shortcut)
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REGISTRY_KEY)
    except FileNotFoundError:
        pass
    else:
        key.Close()
        raise AssertionError('Disposable uninstall key already exists')
    manifest = target / 'PackageStudioPro.install-manifest'
    config = {'productName': PRODUCT, 'publisher': 'Local acceptance fixture',
              'version': '1.0.0', 'installFolder': str(target), 'files': ['payload/app.txt', 'payload/nested/asset.txt'],
              'shortcuts': ['StartMenu|' + PRODUCT + '|app.txt', 'Desktop|' + PRODUCT + '|app.txt'],
              'registry': [], 'environment': [], 'pathEntries': [],
              'fileAssociations': [], 'prerequisites': [], 'features': []}
    project_file = staging / 'install.wiproj'

    def run(mode, success=True, exe=None, project=None):
        project_file.write_text(json.dumps(config))
        result = subprocess.run([str(exe or staging / RUNTIME.name),
                                 str(project or project_file), mode], capture_output=True, text=True, timeout=40)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result

    try:
        run('--install')
        assert all(shortcut.is_file() for shortcut in shortcut_paths), 'Current-user shortcuts were not created'
        assert not any(shortcut.exists() for shortcut in common_shortcut_paths), 'Created an all-users shortcut'
        run('--verify')
        config['version'] = '1.0.1'
        (payload / 'app.txt').write_text('version two')
        run('--install')
        run('--verify')
        assert all(shortcut.is_file() for shortcut in shortcut_paths), 'Upgrade lost a current-user shortcut'
        assert not any(shortcut.exists() for shortcut in common_shortcut_paths)
        shortcut_hashes = {shortcut: hashlib.sha256(shortcut.read_bytes()).hexdigest() for shortcut in shortcut_paths}
        previous_manifest = manifest.read_bytes()
        manifest.write_bytes(previous_manifest + ('\nfile=' + str(external) + '|' + hashlib.sha256(external.read_bytes()).hexdigest() + '\n').encode())
        run('--uninstall', success=False)
        assert external.read_text() == 'untouched external file'
        assert (target / 'app.txt').read_text() == 'version two'
        manifest.write_bytes(previous_manifest)

        # Fail after file replacement and uninstall registration to test rollback.
        config['version'] = '1.0.2'
        (payload / 'app.txt').write_text('version three')
        blocked_manifest = Path(str(manifest) + '.new')
        blocked_manifest.mkdir()
        failed_upgrade = run('--install', success=False)
        failure_log = failed_upgrade.stdout + failed_upgrade.stderr
        assert 0 <= failure_log.find('Install error: ') < failure_log.find('Install failed. Rolling back completed operations.'), failure_log
        assert all(hashlib.sha256(shortcut.read_bytes()).hexdigest() == shortcut_hashes[shortcut]
                   for shortcut in shortcut_paths), 'Rollback did not restore prior shortcuts'
        if blocked_manifest.exists():
            blocked_manifest.rmdir()
        assert manifest.read_bytes() == previous_manifest
        assert (target / 'app.txt').read_text() == 'version two'
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REGISTRY_KEY) as key:
            assert winreg.QueryValueEx(key, 'DisplayVersion')[0] == '1.0.1'
            registered_command = winreg.QueryValueEx(key, 'UninstallString')[0]
        uninstaller = target / '.package-studio' / RUNTIME.name
        uninstall_project = uninstaller.parent / 'uninstall.wiproj'
        assert str(uninstaller) in registered_command and str(uninstall_project) in registered_command
        shutil.rmtree(staging)
        result = subprocess.run([str(uninstaller), str(uninstall_project), '--uninstall'],
                                capture_output=True, text=True, timeout=40)
        assert result.returncode == 0, result.stdout + result.stderr
        for _ in range(150):
            if not uninstaller.exists():
                break
            time.sleep(.1)
        assert not uninstaller.exists(), 'Running uninstaller did not clean itself up'
        assert (target / 'app.txt').read_text() == 'original user file'
        assert (target / 'user-project.txt').read_text() == 'preserved project'
        assert external.read_text() == 'untouched external file'
        assert (sibling / 'keep.txt').read_text() == 'untouched sibling folder'
        assert not any(shortcut.exists() for shortcut in shortcut_paths), 'Owned current-user shortcuts remained after uninstall'
        assert not any(shortcut.exists() for shortcut in common_shortcut_paths)
        assert (target / 'unrelated-empty-folder').is_dir()
        assert not (target / 'nested').exists()
        try:
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REGISTRY_KEY)
        except FileNotFoundError:
            pass
        else:
            key.Close()
            raise AssertionError('Uninstall registration remained')

    finally:
        for shortcut in shortcut_paths + common_shortcut_paths:
            shortcut.unlink(missing_ok=True)
        try:
            winreg.DeleteKey(winreg.HKEY_CURRENT_USER, REGISTRY_KEY)
        except FileNotFoundError:
            pass


if __name__ == '__main__':
    output_root = PROJECT_ROOT / 'test-results'
    output_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='release-acceptance-', dir=output_root) as directory:
        exercise(Path(directory))
    if not any(output_root.iterdir()):
        output_root.rmdir()
    print('PASS: outside-profile custom install, current-user StartMenu/Desktop shortcuts, hash verification, upgrade, failed-upgrade rollback and original-error logging, unsafe journal rejection, durable registered uninstall, self-cleanup and unrelated-file preservation')
