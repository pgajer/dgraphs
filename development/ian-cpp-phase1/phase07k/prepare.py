"""No optimizer calls: derive explicit arithmetic candidates and build them."""
import shutil
from common import *
root=Path(sys.argv[1]).resolve();root.mkdir(parents=True,exist_ok=False)
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
deps=W/'phase06a/clean-v2/dependencies/Clarabel.cpp';lib=W/'phase06a/clean-v2/prefix/lib/libclarabel_c.dylib'
manifest=dict(revision=revision(),parent_files={str(p):sha(p) for p in (E/'candidate').rglob('*') if p.is_file() and '__pycache__' not in str(p)},library_sha256=sha(lib),derivations={},commands=[])
for mode in ['multiply','power']:
 dst=root/mode/'candidate';shutil.copytree(E/'candidate',dst,ignore=shutil.ignore_patterns('__pycache__'))
 s=(dst/'src/solver.hpp').read_text()
 square='return x*x;' if mode=='multiply' else 'volatile double exponent=2.; return std::pow(x,exponent);'
 s=s.replace('#include <memory>','#include <memory>\n#include <cstring>\n#include <cstddef>')
 s=s.replace('struct LPResult {',f'inline double constraint_square(double x) {{ {square} }}\nstruct LPResult {{')
 for a,b in [('d * d','constraint_square(d)'),('C * C','constraint_square(C)'),('w * w','constraint_square(w)')]:
  assert s.count(a)==1;s=s.replace(a,b)
 anchor='    const bool normalized_retry = tolerance < 1e-9;'
 s=s.replace(anchor,'''    // Observe the historically pinned non-SDP ABI; do not modify its settings.
    unsigned char drop=255;
    std::memcpy(&drop,reinterpret_cast<const unsigned char*>(&settings)+offsetof(ClarabelDefaultSettings,presolve_enable)+1,1);
    require(drop==0,"unexpected_backend_dropzeros_byte");
'''+anchor)
 (dst/'src/solver.hpp').write_text(s)
 p=(dst/'reference.py').read_text();p=p.replace('import clarabel','import clarabel\nimport math\ndef _square(v):\n return '+('float(v)*float(v)' if mode=='multiply' else 'math.pow(float(v),2.)'))
 assert p.count('C**2')==1;p=p.replace('C**2','_square(C)')
 anchor=' generated=generate.prepare(folder/\'source\');text=generated.read_text()'
 assert anchor in p
 p=p.replace(anchor,anchor+'''\n assert text.count('e_len**2')==1 and text.count('w**2')==1
 text=text.replace('e_len**2','_ian_square(e_len)').replace('w**2','_ian_square(w)')''')
 p=p.replace(" exec(compile(tree", " module._ian_square=_square\n exec(compile(tree")
 (dst/'reference.py').write_text(p)
 manifest['derivations'][mode]={str(p.relative_to(dst)):sha(p) for p in dst.rglob('*') if p.is_file()}
 commands=[['cmake','-S',dst,'-B',root/mode/'build','-DCMAKE_BUILD_TYPE=Release',f'-DCLARABEL_SOURCE={deps}',f'-DCLARABEL_LIBRARY={lib}',f'-DJSON_INCLUDE={W}/phase03/deps'],['cmake','--build',root/mode/'build','--target','ian_engine','-j2']]
 for i,cmd in enumerate(commands):
  cmd=list(map(str,cmd));manifest['commands'].append(cmd);write(root/'derivation.json',manifest)
  with (root/mode/f'build-{i}.log').open('w') as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
 manifest['derivations'][mode]['engine_sha256']=sha(root/mode/'build/ian_engine')
write(root/'derivation.json',manifest)
print('Two arithmetic candidates built; zero solves.')
