#!/usr/bin/env python3
"""Author presentation checks; neither an independent audit nor numerical replay."""
import json, re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
from pypdf import PdfReader
from catalogue_common import E,ROOT,B,sha,sources,records
class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[];self.ids=set()
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:self.ids.add(a['id'])
        for k in ['href','src']:
            if k in a:self.links.append(a[k])
def main():
    errors=[];checks={};m=json.loads((B/'build-manifest.json').read_text());rec=records();ids={r['id'] for _,r in rec}
    def check(value,msg):
        if not value:errors.append(msg)
    check(sources()==m['source_hashes'],'Maintained sources changed since the full build')
    inventory=json.loads((E/'discovery-inventory.json').read_text())
    check(len(ids)==len(rec) and ids=={r['id'] for r in inventory['records']},'Question identity/inventory mismatch')
    counts={'executed':0,'proposal':0,'historical_audited':0,'pending_new_report_review':0};graph={}
    for p,r in rec:
        a=json.loads((p/'audit-summary.json').read_text());key='executed' if r['execution_status']=='executed' else 'proposal';counts[key]+=1
        check('audit_status' not in r and 'numerically_checked' not in r,'Duplicate audit authority: '+r['id'])
        check(a['current_report_review']['report_sha256']==sha(p/'report.md'),'Review binding drift: '+r['id'])
        counts['historical_audited']+=bool(a['audit_history']);counts['pending_new_report_review']+=a['current_report_review']['status']=='not independently reviewed'
        check(bool(r['figure_paths']) or bool(r.get('missing_figure_reason')),'Missing figure disposition: '+r['id'])
        graph[r['id']]=[d['id'] for d in r['dependencies']]
        for d in r['dependencies']:check(d['id'] in ids and bool(d['type']),'Invalid dependency '+r['id'])
        for q in ['report.md','audit-summary.json','evidence-manifest.json']:check((p/q).exists(),'Missing record source '+str(p/q))
        if (p/'build_figure.py').exists():
            fm=json.loads((p/'build/figure-manifest.json').read_text())
            check(fm['data_sha256']==sha(p/'figure-data.json'),'Local figure input drift: '+r['id'])
            check(fm['script_sha256']==sha(p/'build_figure.py'),'Local figure script drift: '+r['id'])
            for name,digest in fm['outputs'].items():check(sha(p/'build'/name)==digest,'Local figure output drift: '+r['id'])
    def visit(n,stack):
        if n in stack:errors.append('Dependency cycle: '+str(stack+[n]));return
        for v in graph.get(n,[]):visit(v,stack+[n])
    for n in graph:visit(n,[])
    declared=json.loads((E/'coverage-counts.json').read_text())
    check(counts==declared['counts'],'Coverage mismatch')
    check(m['counts']['documented']==len(rec) and m['counts']['executed_questions']==counts['executed'] and m['counts']['historical_audited_questions']==counts['historical_audited'],'Build count mismatch')
    links=0;htmls=[p for p in ROOT.rglob('*.html') if 'build' in p.relative_to(ROOT).parts];cache={}
    for p in htmls:
        parser=Links();parser.feed(p.read_text());cache[p.resolve()]=parser
    for p,parser in cache.items():
        for u in parser.links:
            parts=urlsplit(u)
            if parts.scheme or parts.netloc:continue
            q=(p.parent/unquote(parts.path)).resolve() if parts.path else p;links+=1
            check(q.exists(),'Broken local link '+str(p)+' -> '+u)
            if parts.fragment and q.suffix=='.html' and q in cache:check(unquote(parts.fragment) in cache[q].ids,'Broken HTML anchor: '+u)
    for source,r in m['rendered'].items():
        check(sha(ROOT/source)==r['source_sha256'],'Source mismatch '+source)
        for kind in ['html','pdf']:check(sha(ROOT/r[kind])==r[kind+'_sha256'],'Output mismatch '+r[kind])
    book=PdfReader(B/'experiment-book.pdf');offset=0
    for part in m['assembly']:
        q=ROOT/part['pdf'];check(sha(q)==part['sha256'],'Book component drift '+str(q));r=PdfReader(q)
        check(part['start_page_1based']==offset+1,'Book order mismatch')
        for i,page in enumerate(r.pages):check(page.extract_text()==book.pages[offset+i].extract_text(),'Book text mismatch '+str(q)+':'+str(i))
        offset+=len(r.pages)
    check(offset==len(book.pages),'Book page count mismatch');check(len(book.outline)==len(m['assembly']),'Missing book bookmarks')
    check(sha(B/'experiment-book.pdf')==m['book_sha256'],'Book hash drift');check(sha(B/'index.html')==m['index_sha256'],'Index hash drift');check(sha(B/'figure-manifest.json')==m['figure_manifest_sha256'],'Figure manifest drift')
    fm=json.loads((B/'figure-manifest.json').read_text());check(fm['input']['sha256']==sha(E/'figure-evidence.json'),'Figure input drift');check(fm['script_sha256']==sha(E/'scripts/build_figures.py'),'Figure script drift')
    for path,h in fm['outputs'].items():check(sha(E/path)==h,'Figure output drift '+path)
    checks={'status':'pass' if not errors else 'fail','scope':'author structural/presentation checks; no numerical reruns or independent review','coverage':counts,'html_documents':len(htmls),'local_links_checked':links,'book_pages_compared':offset,'book_components':len(m['assembly']),'book_bookmarks':len(book.outline),'source_files_bound':len(m['source_hashes']),'errors':errors}
    out=B/'qa';out.mkdir(exist_ok=True);(out/'checks.json').write_text(json.dumps(checks,indent=2)+'\n');print(json.dumps(checks,indent=2))
    if errors:raise SystemExit(1)
if __name__=='__main__':main()
