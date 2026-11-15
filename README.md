# Package Studio Pro

Package Studio Pro builds self-contained Windows setup executables from an explicit project file. The application and setup forms are FireMonkey forms stored in the source tree and editable in RAD Studio 37.0. The command-line builder and install engine share the same project model.

## Build

From this folder, run `tools\build_all.ps1 -SkipSample` in PowerShell. Omitting `-SkipSample` preserves the original sample-build behavior. The script compiles resources, builds the authoring application, graphical setup, builder and console runtime, and embeds their manifests. RAD Studio 37.0 and the Windows SDK resource/manifest tools are development requirements; installed products do not need them.

Run the acceptance checks with:

```powershell
& 'C:\Users\Example\AppData\Local\Microsoft\WindowsApps\python.exe' tools\release_acceptance.py
```

The checks use an automatically removed disposable directory. They exercise installation, hashes, upgrades, rollback after a failed upgrade, unsafe journal rejection, registered uninstall after the original staging files are gone, uninstaller self-cleanup and preservation of user files.

## Repair for the Web Studio release

The November 15, 2026 repair includes the console uninstaller inside each setup bundle and installs a durable copy plus its metadata under `.package-studio`. Uninstall registration refers to that installed copy. File hashes protect modified files, upgrades retain the original pre-install state, and a failed upgrade restores its previous files and uninstall registration. A Windows-owned cleanup worker removes the running uninstaller after it exits, without recursively deleting user content.

The package reader recognizes the bundle before an Authenticode certificate table rather than assuming it ends at the last byte. Extraction checks paths, duplicate entries and expansion limits. The signed-layout test used a synthetic certificate-table overlay; a real certificate-backed signing test remains unverified.

New projects default to a folder under the current user's Local AppData. Packages targeting that user's profile use per-user setup/uninstall manifests and shortcuts. Targets outside the profile retain elevated setup/uninstall manifests and shared shortcut locations. Existing Program Files targets therefore still require administrator approval. Registry integration remains HKCU as in the original engine; full machine-wide registry support is not claimed.

Prerequisite entries use `Name|Method|Help URL`. Supported detection methods are `Windows10`, `Windows-x64`, `WebView2`, and `OpenSSH-Optional`. Missing required prerequisites stop before payload writes. WebView2 guidance points users to Microsoft; the runtime is not silently downloaded. `Manual` prerequisites stop with instructions rather than pretending to install a dependency. Web Studio uses the Windows OpenSSH Client instead of copying system binaries into its package.

Signing settings stay in the authoring project. Certificate/tool paths are not copied into the installed package metadata. Setup must be signed after its bundle has been embedded. No certificate was supplied for the Web Studio release, so its installers are unsigned.

The existing guides and help describe the original authoring screens. Use these repair notes for the updated installation, prerequisite and uninstall behavior. Existing `Exports`, `MySetups`, build outputs and backup folders are user/generated content and are excluded from this source repository.

## Ready-to-build Web Studio projects

Open either saved project under `MySetups/DelphiWebStudioPro-1.0.0.1`. Each has a permanent architecture-specific payload containing the editor, WebView2 loader, SFTP workflow, all seven guides and license notices. The adjacent README explains opening, validation, output paths and refreshing the snapshots. These two deliberately retained release projects are versioned in Git; other user projects under MySetups remain excluded.

Opening a saved project selects its own product-specific Exports folder. Rebuilding preserves additional project shortcuts, including the installed PDF User Guide shortcut.
