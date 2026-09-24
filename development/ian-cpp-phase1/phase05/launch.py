"""Single supervised Python tool invocation with the established thread policy."""
import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'phase02'))
from supervise import supervise, one_thread_environment

p = argparse.ArgumentParser()
p.add_argument('record', type=Path)
p.add_argument('script', type=Path)
p.add_argument('arguments', nargs=argparse.REMAINDER)
a = p.parse_args()
assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True)
result = supervise([sys.executable, '-B', str(a.script.resolve()), *a.arguments], a.record, one_thread_environment())
print(result)
raise SystemExit(result['exit_code'])
