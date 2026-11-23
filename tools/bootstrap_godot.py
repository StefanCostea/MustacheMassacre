"""Install the project's pinned official Godot editor and Linux export templates."""
from pathlib import Path
import urllib.request,json,zipfile,hashlib,os

VERSION='4.7.2'
CACHE=Path.home()/'.cache/codex-tools'/('godot-'+VERSION)
CACHE.mkdir(parents=True,exist_ok=True)
base=f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/'
def fetch(name):
    path=CACHE/name
    if not path.exists():
        print('Downloading',name,flush=True)
        temp=path.with_suffix(path.suffix+'.part')
        urllib.request.urlretrieve(base+name,temp)
        temp.replace(path)
    return path
checksums={}
for line in fetch('SHA512-SUMS.txt').read_text().splitlines():
    parts=line.split()
    if len(parts)==2:checksums[parts[1].lstrip('*')]=parts[0]
def verified(name):
    path=fetch(name)
    hasher=hashlib.sha512()
    with path.open('rb') as source:
        for block in iter(lambda:source.read(1024*1024),b''):hasher.update(block)
    digest=hasher.hexdigest()
    if checksums.get(name)!=digest:raise RuntimeError('SHA512 verification failed: '+name)
    print('VERIFIED',name,flush=True)
    return path
editor=verified(f'Godot_v{VERSION}-stable_linux.x86_64.zip')
with zipfile.ZipFile(editor) as z:z.extractall(CACHE)
exe=CACHE/f'Godot_v{VERSION}-stable_linux.x86_64';exe.chmod(0o755)
print('EDITOR',exe,flush=True)
templates=verified(f'Godot_v{VERSION}-stable_export_templates.tpz')
dest=Path.home()/'.local/share/godot/export_templates'/f'{VERSION}.stable';dest.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(templates) as z:
    for name in z.namelist():
        if name.split('/')[-1] in ['linux_debug.x86_64','linux_release.x86_64','version.txt']:
            target=dest/name.split('/')[-1];target.write_bytes(z.read(name))
            if target.name.startswith('linux_'):target.chmod(0o755)
print('TEMPLATES',dest,flush=True)
