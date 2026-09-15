"""Bind generated guides/checks to exact package inputs, not just a version."""
import hashlib, json, os, platform, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def snapshot():
    paths = [ROOT / n for n in ('DESCRIPTION','NAMESPACE','LICENSE','NEWS.md','README.md')]
    for directory in ('R','src','man','vignettes','inst'):
        paths.extend(p for p in (ROOT / directory).rglob('*') if p.is_file()
                     and p.suffix not in ('.o','.so','.dll','.dylib')
                     and p.name != 'build-provenance.json')
    files = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
             for p in sorted(paths)}
    return files
if __name__ == '__main__':
    command = sys.argv[1]
    if command == 'write':
        record = dict(source_files=snapshot(), git_revision=subprocess.check_output(
            ['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            working_tree_dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip()),
            platform=platform.platform(),
            media_mode='static' if os.getenv('DGRAPHS_STATIC_VIGNETTES') == 'true' else 'interactive-if-available')
        (ROOT/'inst/build-provenance.json').write_text(json.dumps(record,indent=2)+'\n')
    elif command == 'verify':
        installed = Path(sys.argv[2])/'dgraphs/build-provenance.json'
        if not installed.exists(): raise SystemExit('Missing build fingerprint. Rebuild with make build and install that archive.')
        old=json.loads(installed.read_text())['source_files']; now=snapshot()
        changed=[p for p in sorted(old.keys()|now.keys()) if old.get(p)!=now.get(p)]
        if changed: raise SystemExit('Stale installation; differing package inputs: '+', '.join(changed))
        print(f'Exact package input fingerprint verified: {len(now)} files.')
    elif command == 'archive':
        archive=Path(sys.argv[2]); record=json.loads((ROOT/'inst/build-provenance.json').read_text())
        record['archive']=archive.name; record['archive_sha256']=hashlib.sha256(archive.read_bytes()).hexdigest()
        archive.with_suffix('.provenance.json').write_text(json.dumps(record,indent=2)+'\n')
    else: raise SystemExit('Expected write, verify LIBRARY, or archive TARBALL')
