"""No-solve adversaries verify strict choices and complete first-divergence capture."""
import argparse,copy,json
from pathlib import Path
from compare import compare,traces,check_lp,write
p=argparse.ArgumentParser();p.add_argument('reference',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False);events=traces(a.reference);checks=[]
for mode in ['removed_edge','scale_array']:
 mutated=copy.deepcopy(events)
 if mode=='removed_edge':
  index=next(i for i,e in enumerate(mutated) if e['event']=='pruned');mutated[index]['removed']=[]
 else:
  index=next(i for i,e in enumerate(mutated) if e['event']=='solve');mutated[index]['scales']=[0.]*len(mutated[index]['scales']);assert not check_lp(mutated[index])['accepted']
 folder=a.output/mode;folder.mkdir();(folder/'trace.jsonl').write_text('\n'.join(json.dumps(e) for e in mutated)+'\n')
 result=compare(a.reference,folder,a.output/(mode+'-comparison'));assert not result['passed'] and result['first_divergence']==index
 context=json.loads((a.output/(mode+'-comparison')/'first-divergence.json').read_text());state=context['complete_preceding_state_a'];assert all(k in state for k in ['mapping','processed','iteration','tune_start','furthest_neighbor_tie_gaps'])
 if mode=='removed_edge':assert 'decision' in state and 'threshold_margins' in state['decision'] and 'retune_eval' in state
 checks.append(dict(adversary=mode,index=index,detected=True,complete_context_saved=True))
write(a.output/'checks.json',dict(checks=checks,optimizations=0));print('Two no-solve comparator adversaries detected; preceding state and decision margins retained.')
