"""Read-only reuse of accepted supervisor and original-unit scalar checks."""
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
E=HERE.parent/'phase07e'
CANDIDATE=E/'candidate'
sys.path.insert(0,str(HERE.parent/'phase07c'))
from guard import run,tree_bytes
sys.path.insert(0,str(HERE.parent/'phase07b'))
from common import load,write,sha,events,scalar_check
POLICY='IAN evaluated-LP retry units11 almost 0.1'
