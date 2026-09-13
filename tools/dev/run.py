"""Developer-only Linux staging for a Windows checkout; no runtime wrapper."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

source = Path('/source')
workspace = Path('/workspace')
task = sys.argv[1]
if task == 'versions':
    for command in (['rustc', '--version'], ['cargo', '--version'],
                    ['ruby', '--version'], ['python3', '--version']):
        subprocess.run(command, check=True)
    raise SystemExit(0)

# A fresh container supplies an empty Linux workspace. Copy bytes, not NTFS modes.
# Restore archive modes; the existing exact-tree verifier still validates them.
for relative in ('.cargo', 'addon', 'custom_components', 'data/mlp', 'tests/mlp', 'tools'):
    shutil.copytree(source / relative, workspace / relative,
                    copy_function=shutil.copyfile,
                    ignore=shutil.ignore_patterns('__pycache__', '__MACOSX', '.DS_Store', 'target'))
for name in ('Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', 'LICENSE'):
    shutil.copyfile(source / name, workspace / name)
# Only executable vendor file in the current frozen dependency set. Verified from
# unicode-normalization-0.1.25.crate, SHA256:
# 5fd4f6878c9cb28d874b009da9e8d183b5abc80117c40bbd187a1fde336be6e8
(workspace / 'addon/vendor/unicode-normalization-0.1.25/scripts/unicode.py').chmod(0o755)
for path in (workspace / 'tools').rglob('*'):
    if path.is_file():
        with path.open('rb') as file:
            if file.read(2) == b'#!':
                path.chmod(0o755)
(workspace / 'target').symlink_to('/output', target_is_directory=True)
os.chdir(workspace)
commands = {
    'check': ['sh', './tools/mlp-check'],
    'build': ['cargo', 'build', '--workspace', '--release', '--locked', '--offline'],
    'corpus': ['ruby', 'tools/generate-mlp-corpus.rb'],
    'corpus-check': ['ruby', 'tools/generate-mlp-corpus.rb', '--check'],
}
subprocess.run(commands[task], check=True)
if task == 'corpus':
    for name in ('project-authored-synthetic-catalog-v1.json', 'project-authored-synthetic-v1.jsonl'):
        shutil.copyfile(workspace / 'data/mlp' / name, Path('/corpus-output') / name)
