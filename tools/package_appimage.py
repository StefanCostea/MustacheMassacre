"""Pack the natural-hero Linux release using a local AppImage type-2 runtime."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RELEASES = ROOT / "build/releases"
PINNED_RUNTIME = "617aa77314d57c8b8e4fae9c3f0b35af7b30d5529cb69e98f64f92510ed98a46"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime", type=Path, help="Pinned x86_64 type-2 runtime binary")
    parser.add_argument("--release", type=Path, default=RELEASES / "LastCall")
    parser.add_argument("--output", type=Path, default=RELEASES / "MoustacheMassacre-x86_64.AppImage")
    args = parser.parse_args()
    runtime = args.runtime.read_bytes()
    if hashlib.sha256(runtime).hexdigest() != PINNED_RUNTIME:
        parser.error("Runtime checksum differs from the tested x86_64 release")
    destination = args.output.resolve()
    with tempfile.TemporaryDirectory(prefix="lastcall-appimage-", dir=destination.parent) as work:
        work = Path(work)
        app = work / "AppDir"
        shutil.copytree(args.release, app)
        shutil.copy2(ROOT / "game/icon.svg", app / "lastcall.svg")
        shutil.copy2(ROOT / "tools/appimage/lastcall.desktop", app)
        shutil.copy2(ROOT / "tools/appimage/AppImage-runtime.txt", app / "licenses")
        (app / "AppRun").symlink_to("play-natural.sh")
        (app / ".DirIcon").symlink_to("lastcall.svg")
        filesystem = work / "data.squashfs"
        subprocess.run(["mksquashfs", app, filesystem, "-noappend", "-comp", "zstd",
                        "-Xcompression-level", "20", "-b", "1M", "-all-root", "-no-xattrs",
                        "-no-progress", "-processors", "6"], check=True)
        candidate = work / destination.name
        with candidate.open("wb") as stream, filesystem.open("rb") as squash:
            stream.write(runtime)
            shutil.copyfileobj(squash, stream)
        candidate.chmod(0o755)
        for diagnostic in ("badlands-expansion-test", "campaign-test", "paired-ui-test", "county-test"):
            test = subprocess.run([candidate, "--appimage-extract-and-run", "--headless", "--fixed-fps", "60",
                                   "--", "--" + diagnostic], cwd=work, text=True,
                                  env={**os.environ, "XDG_DATA_HOME": str(work / diagnostic)},
                                  capture_output=True, timeout=120)
            if test.returncode or " failures=0" not in test.stdout or "ERROR:" in test.stderr:
                raise RuntimeError(test.stdout + test.stderr)
        candidate.replace(destination)
    print(destination)


if __name__ == "__main__":
    main()
