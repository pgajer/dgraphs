#!/usr/bin/env python3
"""Full HTML/PDF presentation build. No analysis execution or private evidence reads."""
import datetime, html, json, os, platform, subprocess
from pathlib import Path
import pypdf, reportlab
from catalogue_common import E,ROOT,B,CSS,sha,sources,records,md_sources,destination,document,html_document,pdf_document

def main():
    before=sources();B.mkdir(parents=True,exist_ok=True)
    fm=json.loads((B/'figure-manifest.json').read_text())
    assert fm['input']['sha256']==sha(E/'figure-evidence.json'),'Reconstruct figures after editing aggregate evidence'
    assert fm['script_sha256']==sha(E/'scripts/build_figures.py'),'Reconstruct figures after changing figure code'
    for k,v in fm['outputs'].items():assert sha(E/k)==v,'Stale figure: '+k
    rec=records();rendered={};pages={}
    accepted=sum(bool(json.loads((p/'audit-summary.json').read_text())['audit_history']) for p,m in rec)
    executed=sum(m['execution_status']=='executed' for p,m in rec);proposals=len(rec)-executed
    historical_milestones=len({v for p,m in rec if json.loads((p/'audit-summary.json').read_text())['audit_history'] for v in m['phase_aliases']})
    pending=sum(json.loads((p/'audit-summary.json').read_text())['current_report_review']['status']=='not independently reviewed' for p,m in rec)
    for p,m in rec:
        a=json.loads((p/'audit-summary.json').read_text());assert a['current_report_review']['report_sha256']==sha(p/'report.md'),'Reconcile report review status: '+m['id']
    for p in md_sources():
        if 'build' in p.relative_to(ROOT).parts:continue
        out=destination(p);ast,pandoc=document(p);html_document(p,out,ast,pandoc)
        review=json.loads((p.parent/'audit-summary.json').read_text())['current_report_review'] if p.name=='report.md' and (p.parent/'audit-summary.json').exists() else {}
        pdf=out.with_suffix('.pdf')
        preserve=review.get('status')=='accepted' and pdf.exists() and review.get('report_pdf_sha256')==sha(pdf)
        if not preserve:pdf_document(ast,pdf,p.parent.name if p.name=='report.md' else p.stem,page_per_section=p.name=='meeting-figure-selection.md')
        rendered[str(p.relative_to(ROOT))]={'source_sha256':sha(p),'html':str(out.relative_to(ROOT)),'html_sha256':sha(out),'pdf':str(out.with_suffix('.pdf').relative_to(ROOT)),'pdf_sha256':sha(out.with_suffix('.pdf')),'preserved_reviewed_pdf':preserve}
        pages[str(out.with_suffix('.pdf').relative_to(ROOT))]=len(pypdf.PdfReader(out.with_suffix('.pdf')).pages)
    groups={'A':'Feasibility and attribution','B':'Reference fidelity and reusable core','C':'Numerical reliability and scale compatibility','D':'Performance and portability','E':'Controlled scientific application','F':'Method and scientific benchmarks'}
    def link(path,label):return '<a href="'+html.escape(os.path.relpath(path,B))+'">'+html.escape(label)+'</a>'
    nav='<nav>'+''.join(link(destination(p),label) for p,label in [(ROOT/'docs/project-aims.md','Project aims'),(ROOT/'docs/roadmap.md','Roadmap'),(E/'shared-methods.md','Shared methods'),(E/'dataset-orientation.md','Datasets'),(E/'discovery-scope.md','Discovery scope'),(E/'audit-coverage.md','Audit coverage'),(E/'synthesis.md','Synthesis'),(E/'meeting-figure-selection.md','Figure selection'),(E/'analysis-queue.md','Analysis queue')])+link(B/'experiment-book.pdf','PDF book')+link(B/'build-manifest.json','Build provenance')+'</nav>'
    cards={'executed':[],'proposal':[]};paths={m['id']:p for p,m in rec}
    for p,m in rec:
        a=json.loads((p/'audit-summary.json').read_text());kind='executed' if m['execution_status']=='executed' else 'proposal';status=a['audit_status'];preview=''
        if m['figure_paths']:
            q=(p/m['figure_paths'][0]).resolve();preview='<img alt="Evidence figure preview" src="'+os.path.relpath(q,B)+'">'
        else:preview='<p class="meta">'+html.escape(m['missing_figure_reason'])+'</p>'
        deps='; '.join(link(paths[d['id']]/'build/report.html',d['id'])+' ('+html.escape(d['type'])+')' for d in m['dependencies']) or 'No declared predecessor.'
        reviewed=a['current_report_review']['status']=='accepted'
        review_label='accepted by independent review' if reviewed else 'not independently reviewed'
        cards[kind].append('<article data-group="'+m['programme_group']+'" data-execution="'+kind+'" data-audit="'+('accepted' if a['audit_history'] else 'unexamined')+'" data-review="'+('accepted' if reviewed else 'pending')+'"><div class="meta">'+m['id']+' · Phase '+html.escape(', '.join(m['phase_aliases']))+' · '+groups[m['programme_group']]+'</div><h3>'+link(p/'build/report.html',m['title'])+'</h3><span class="badge '+kind+'">'+html.escape(m['execution_status'])+'</span><p>'+html.escape(status)+'. Current report: '+review_label+'.</p>'+link(p/'build/report.html',m['outcome'])+preview+'<p>'+link(p/'build/report.html','Full record')+' · '+link(p/'build/report.pdf','PDF')+'</p><p class="meta">Dependencies: '+deps+'</p></article>')
    controls='''<div class="controls"><label>Search <input id="search" type="search" placeholder="Question, phase, method…"></label><label>Topic <select id="group"><option value="">All topics</option>'''+''.join('<option value="'+k+'">'+v+'</option>' for k,v in groups.items())+'''</select></label><label>Execution <select id="execution"><option value="">All records</option><option value="executed">Executed</option><option value="proposal">Proposals</option></select></label><label>Evidence audit <select id="audit"><option value="">All</option><option value="accepted">Bounded evidence accepted</option><option value="unexamined">Not examined</option></select></label><label>New presentation <select id="review"><option value="">All</option><option value="pending">Awaiting independent review</option><option value="accepted">Independently accepted</option></select></label></div><p id="count" aria-live="polite"></p>'''
    script='''<script>const cards=[...document.querySelectorAll('article[data-group]')];function filter(){const q=document.getElementById('search').value.toLowerCase();let n=0;cards.forEach(c=>{c.hidden=!(c.textContent.toLowerCase().includes(q)&&['group','execution','audit','review'].every(k=>!document.getElementById(k).value||c.dataset[k]===document.getElementById(k).value));if(!c.hidden)n++});document.getElementById('count').textContent=n+' of '+cards.length+' records shown';for(const k of ['executed','proposal'])document.getElementById(k+'-empty').hidden=cards.some(c=>c.dataset.execution===k&&!c.hidden)};document.querySelectorAll('input,select').forEach(e=>e.addEventListener('input',filter));filter();</script>'''
    (B/'index.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>IAN experiment catalogue</title><style>'+CSS+'</style><main><p class="meta">IAN PROJECT · UPDATED 23 SEPTEMBER 2026</p><h1>Evidence for a reliable IAN implementation</h1><p>A question-based guide to implementation fidelity, numerical reliability and the limits of scale expansion.</p>'+nav+'<div class="panel"><b>'+str(len(rec))+' documented questions · '+str(executed)+' executed · '+str(proposals)+' unexecuted proposals</b><p>'+str(accepted)+' questions map to '+str(historical_milestones)+' independently accepted bounded milestones. '+str(executed-accepted)+' new executed studies await independent review. Acceptance includes informative negative studies. '+str(pending)+' current reports and figures await independent presentation review; these counts are not numbers of solver calls or biological observations.</p><p class="warning">The larger-run compatibility gate remains closed. Project aims are consolidated working wording, pending owner review; this organization does not adopt a new numerical policy.</p></div>'+controls+'<h2>Executed studies</h2><p id="executed-empty" hidden>No executed studies match these filters.</p><div class="cards">'+''.join(cards['executed'])+'</div><h2>Proposals — not executed</h2><p id="proposal-empty" hidden>No proposals match these filters.</p><div class="cards">'+''.join(cards['proposal'])+'</div><p class="meta">Local artifact. Original evidence remains in place; external backup coverage is unknown.</p></main>'+script+'</html>')
    intro=[E/'book-introduction.md',ROOT/'docs/project-aims.md',E/'audit-coverage.md',E/'shared-methods.md',E/'discovery-scope.md',E/'dataset-orientation.md']
    parts=[destination(p).with_suffix('.pdf') for p in intro]+[p/'build/report.pdf' for p,m in rec]
    writer=pypdf.PdfWriter();assembly=[];offset=0
    for p in parts:
        reader=pypdf.PdfReader(p);title=p.parent.parent.name if p.name=='report.pdf' else p.stem
        writer.append(reader,outline_item=title);assembly.append({'pdf':str(p.relative_to(ROOT)),'sha256':sha(p),'start_page_1based':offset+1,'pages':len(reader.pages)});offset+=len(reader.pages)
    writer.add_metadata({'/Title':'IAN experiment book — bounded evidence and proposals','/Author':'IAN implementer/coordinator','/Subject':'Historical evidence acceptance is separate from new presentation review'})
    with (B/'experiment-book.pdf').open('wb') as f:writer.write(f)
    assert before==sources(),'Renderer modified maintained sources'
    manifest={'operation':'full scientific rendering only; zero optimizer calls','built_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'git_head':subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip(),'source_hashes':before,'rendered':rendered,'assembly':assembly,'book_sha256':sha(B/'experiment-book.pdf'),'index_sha256':sha(B/'index.html'),'figure_manifest_sha256':sha(B/'figure-manifest.json'),'counts':{'documented':len(rec),'executed_questions':executed,'historical_milestones':historical_milestones,'historical_audited_questions':accepted,'new_executed_studies_awaiting_review':executed-accepted,'unexecuted_proposals':proposals,'current_reports_awaiting_review':pending},'environment':{'python':platform.python_version(),'reportlab':reportlab.Version,'pypdf':pypdf.__version__,'pandoc':subprocess.run([pandoc,'--version'],capture_output=True,text=True).stdout.splitlines()[0]},'external_backup':'unknown','private_evidence_reads':'none; private paths remain links only'}
    (B/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(f'Rendered {len(rendered)} documents; assembled {offset}-page bookmarked book.')
if __name__=='__main__':main()
