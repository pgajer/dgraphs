"""Read-only imports of accepted guard and independent scalar check utilities."""
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase07c'))
from guard import run,tree_bytes
sys.path.insert(0,str(HERE.parent/'phase07b'))
from common import load,write,sha,events,matrix,pack,product,norm,scalar_check
POLICIES={
 'tight12':'IAN evaluated-LP retry tight12 0.1',
 'refined11':'IAN evaluated-LP retry refined11 0.1',
 'units11':'IAN evaluated-LP retry units11 0.1'}
CONDITIONS=['ordinary','retry11','tight12','refined11','units11']
