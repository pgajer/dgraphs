"""Launch the local app without tying its lifetime to the terminal window."""
from pathlib import Path
import json
import os
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request

root = Path(__file__).resolve().parents[1]
port = int(os.getenv('GEOMETRY_LAB_PORT', '8462'))
url = f'http://127.0.0.1:{port}/'
logs = Path(os.getenv('GEOMETRY_LAB_LOGS', str(Path.home()/'.codex/private/geosmooth/geometry-lab/logs')))
logs.mkdir(parents=True, exist_ok=True)

def running():
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            html = response.read().decode()
        if 'Geometry Lab · 3D embedding explorer' not in html:
            raise RuntimeError(f'Port {port} belongs to another app. Set GEOMETRY_LAB_PORT.')
        return True
    except urllib.error.HTTPError as error:
        raise RuntimeError(f'Port {port} belongs to another service.') from error
    except urllib.error.URLError as error:
        if isinstance(error.reason, (socket.timeout, TimeoutError)):
            raise RuntimeError('The server is unresponsive; no duplicate was started.') from error
        return False

if running():
    print(url)
    raise SystemExit(0)
rscript = shutil.which('Rscript') or '/usr/local/bin/Rscript'
with (logs/'server.log').open('a') as handle:
    process = subprocess.Popen([rscript, str(root/'launch.R')], cwd=root,
        stdout=handle, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
        start_new_session=True, env=dict(os.environ, GEOMETRY_LAB_ROOT=str(root), GEOMETRY_LAB_PORT=str(port)))
for _ in range(120):
    if process.poll() is not None:
        raise RuntimeError(f'App failed to start. See {logs / "server.log"}.')
    if running():
        (logs/'server.json').write_text(json.dumps(dict(pid=process.pid,url=url,root=str(root)),indent=2))
        print(url)
        break
    time.sleep(.25)
else:
    process.terminate()
    raise RuntimeError(f'App startup timed out. See {logs / "server.log"}.')
