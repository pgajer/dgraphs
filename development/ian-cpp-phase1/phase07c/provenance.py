"""Reconstruct CMake's identity independently before any measured candidate run."""
import hashlib,re
from pathlib import Path
H=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build_identity(build):
 names=sorted(str(p.relative_to(H)) for folder in ['include','src','tests'] for p in (H/folder).rglob('*') if p.suffix in ['.hpp','.cpp','.inc'])
 expected=hashlib.sha256((''.join(sha(H/n) for n in names)+sha(H/'CMakeLists.txt')).encode()).hexdigest()
 flags=(Path(build)/'CMakeFiles/ian_core.dir/flags.make').read_text()
 assert expected in flags,'source_identity_mismatch'
 assert sha(H/'config.json') in flags,'configuration_identity_mismatch'
 return dict(source=expected,configuration=sha(H/'config.json'),files={n:sha(H/n) for n in names},engine_sha256=sha(Path(build)/'ian_engine'))
