"""Shared presentation helpers. All scientific build inputs are maintained locally."""
import base64, hashlib, html, json, os, re, shutil, subprocess
from pathlib import Path
from urllib.parse import quote
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, PageBreak, KeepTogether, XPreformatted
E=Path(__file__).resolve().parents[1]; ROOT=E.parent; B=E/'build'
CSS='''body{font:16px/1.6 system-ui,sans-serif;color:#243c4b;background:#f5f7f8;margin:0}main{max-width:1100px;margin:auto;padding:36px 28px}article,.panel{background:white;border:1px solid #dbe2e5;border-radius:10px;padding:24px;margin:20px 0}h1{font-size:2rem;line-height:1.2;max-width:900px}h2{font-size:1.3rem;margin-top:1.8em}h3{font-size:1.1rem}a{color:#125c80;overflow-wrap:anywhere}p,li{max-width:95ch}img{max-width:100%;height:auto}table{border-collapse:collapse;width:100%;font-size:.9rem}th,td{padding:10px;border:1px solid #ccd6dc;vertical-align:top}th{background:#edf3f5}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#edf3f5;padding:14px}code{overflow-wrap:anywhere}.meta{color:#53646e;font-size:.86rem}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:18px}.cards article{margin:0;padding:20px}.cards h3{margin-top:0}.cards img{border:1px solid #e5ebed}.controls{display:flex;gap:14px;flex-wrap:wrap;padding:16px;background:#e6eef1;position:relative}input,select{font:inherit;padding:8px;border:1px solid #9dafb8;border-radius:4px;max-width:100%}.badge{display:inline-block;border-radius:4px;padding:2px 7px;background:#e5f1ed;font-size:.8rem}.proposal{background:#faf4e7}.warning{border-left:4px solid #bd7b29;padding-left:16px}nav{display:flex;flex-wrap:wrap;gap:14px;font-size:.9rem}article[hidden]{display:none}@media(max-width:600px){main{padding:18px 12px}.cards{display:block}.cards article{margin:16px 0}article{padding:16px}table{font-size:.75rem}td,th{padding:5px}}'''
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def sources():return {str(p.relative_to(ROOT)):sha(p) for p in sorted(ROOT.rglob('*')) if p.is_file() and 'build' not in p.relative_to(ROOT).parts and '__pycache__' not in p.parts}
def records():return [(p.parent,json.loads(p.read_text())) for p in sorted(E.glob('[0-9]*/experiment.yml'))]
def md_sources():return sorted(ROOT.rglob('*.md'))
def destination(p):
    if p.is_relative_to(ROOT/'stages'):
        return B/'stages'/p.relative_to(ROOT/'stages').with_suffix('.html')
    if p.name=='report.md' and p.parent.parent==E:return p.parent/'build/report.html'
    if p.parent.parent==E:return p.parent/'build'/(p.stem+'.html')
    return B/(('docs-' if p.parent==ROOT/'docs' else 'project-' if p.parent==ROOT else '')+p.stem+'.html')
def document(p):
    text=p.read_text(); specs=json.loads((E/'figure-evidence.json').read_text())['figures']
    for i,f in enumerate(specs,1):
        token='{{figure:'+f['id']+'}}'
        if token in text:
            img=B/'assets'/f"{f['id']}.png"
            text=text.replace(token,f"![{f['title']}]({img})\n\n**Figure {i}.** {f['caption']}")
    pandoc=shutil.which('pandoc') or '/Users/pgajer/bin/pandoc'
    ast=json.loads(subprocess.run([pandoc,'--from=markdown-implicit_figures','--to=json'],input=text,text=True,capture_output=True,check=True).stdout)
    targets={str(q.resolve()):destination(q) for q in md_sources()}
    def walk(x):
        if isinstance(x,dict):
            if x.get('t') in ['Link','Image']:
                u=x['c'][-1][0]
                if not re.match(r'^[a-zA-Z]+:',u) and not u.startswith('#'):
                    raw,sep,frag=u.partition('#');q=(p.parent/raw).resolve();q=targets.get(str(q),q) if x['t']=='Link' else q
                    x['c'][-1][0]=str(q)+(sep+frag if sep else '')
            for v in x.values():walk(v)
        elif isinstance(x,list):
            for v in x:walk(v)
    walk(ast);return ast,pandoc

def html_document(p,out,ast,pandoc):
    body=subprocess.run([pandoc,'--from=json','--to=html5'],input=json.dumps(ast),text=True,capture_output=True,check=True).stdout
    if p.name=='report.md' and (p.parent/'audit-summary.json').exists():
        review=json.loads((p.parent/'audit-summary.json').read_text())['current_report_review']
        if review.get('status')=='accepted':
            body='<div class="panel"><strong>Independent audit: accepted.</strong> <a href="'+html.escape(review['review'],quote=True)+'">Read the audit</a>. The reviewed submission below is preserved; its earlier “review pending” labels describe the submission state.</div>'+body
    def link(m):
        attr,url=m.groups()
        if url.startswith('/'):
            q=Path(html.unescape(url).split('#')[0]);frag='#'+url.split('#')[1] if '#' in url else ''
            if attr=='src':return 'src="data:image/png;base64,'+base64.b64encode(q.read_bytes()).decode()+'"'
            return 'href="'+html.escape(os.path.relpath(q,out.parent)+frag,quote=True)+'"'
        return m.group(0)
    body=re.sub(r'(href|src)="([^"]+)"',link,body)
    out.parent.mkdir(parents=True,exist_ok=True)
    nav=f'<nav><a href="{os.path.relpath(B/"index.html",out.parent)}">Catalogue</a><a href="{out.with_suffix(".pdf").name}">PDF</a></nav>'
    title=next((plain(b['c'][2]) for b in ast['blocks'] if b['t']=='Header'),'IAN project')
    out.write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>'+html.escape(title)+'</title><style>'+CSS+'</style><main>'+nav+'<article>'+body+'</article></main></html>')

def plain(items):
    return ''.join(x.get('c','') if x['t'] in ['Str','Code'] and isinstance(x.get('c'),str) else ' ' if x['t'] in ['Space','SoftBreak','LineBreak'] else plain(x['c'][1]) if x['t'] in ['Link','Image'] else x['c'][1] if x['t']=='Code' else plain(x['c']) if isinstance(x.get('c'),list) else '' for x in items)

def pdf_document(ast,out,label='IAN project',page_per_section=False):
    if 'IAN' not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont('IAN',os.environ.get('IAN_CATALOGUE_FONT','/Library/Fonts/Arial Unicode.ttf')))
        pdfmetrics.registerFontFamily('IAN',normal='IAN',bold='IAN',italic='IAN',boldItalic='IAN')
    st=getSampleStyleSheet()
    for x in st.byName.values():x.fontName='IAN'
    st['Normal'].fontSize=9;st['Normal'].leading=12;st['Normal'].spaceAfter=4;st['Normal'].splitLongWords=True
    st['Title'].fontSize=17;st['Title'].leading=21;st['Title'].spaceAfter=10;st['Title'].keepWithNext=1
    st['Heading2'].fontSize=11.5;st['Heading2'].leading=15;st['Heading2'].spaceBefore=6;st['Heading2'].spaceAfter=4;st['Heading2'].keepWithNext=1
    st.add(ParagraphStyle('Small',parent=st['Normal'],fontSize=7.5,leading=10))
    def inline(items):
        ans=''
        for x in items:
            t,c=x['t'],x.get('c')
            if t=='Str':ans+=html.escape(c)
            elif t in ['Space','SoftBreak']:ans+=' '
            elif t=='LineBreak':ans+='<br/>'
            elif t=='Code':ans+=html.escape(c[1])
            elif t in ['Strong','Emph']:ans+=('<b>' if t=='Strong' else '<i>')+inline(c)+('</b>' if t=='Strong' else '</i>')
            elif t=='Link':ans+='<a color="#125c80" href="'+html.escape(c[-1][0],quote=True)+'">'+inline(c[1])+'</a>'
            elif t=='Image':ans+=html.escape(plain(c[1]))
            elif t=='Math':ans+=html.escape(c[1])
            elif t=='Quoted':ans+='“'+inline(c[1])+'”'
            elif t=='Span':ans+=inline(c[1])
        return ans
    def blocks(bs,small=False):
        flow=[]
        for b in bs:
            t,c=b['t'],b.get('c')
            if t=='Header':
                if page_per_section and c[0]==2:flow.append(PageBreak())
                flow.append(Paragraph(inline(c[2]),st['Title'] if c[0]==1 else st['Heading2']))
            elif t in ['Para','Plain']:
                if len(c)==1 and c[0]['t']=='Image':
                    im=Image(c[0]['c'][-1][0]);im.drawHeight*=480/im.drawWidth;im.drawWidth=480;flow.extend([Spacer(1,5),im,Spacer(1,5)])
                else:flow.append(Paragraph(inline(c),st['Small' if small else 'Normal']))
            elif t in ['BulletList','OrderedList']:
                for i,sub in enumerate(c if t=='BulletList' else c[1]):
                    sub=list(sub)
                    if sub and sub[0]['t'] in ['Para','Plain']:sub[0]={'t':sub[0]['t'],'c':[{'t':'Str','c':'•' if t=='BulletList' else str(i+1)+'.'},{'t':'Space'}]+sub[0]['c']}
                    flow.extend(blocks(sub,small))
            elif t=='CodeBlock':flow.append(Paragraph(html.escape(c[1]).replace('\n','<br/>'),st['Small']))
            elif t=='Table':
                rows=c[3][1]+[r for body in c[4] for r in body[2]+body[3]]+c[5][1]
                data=[[blocks(cell[4],True) for cell in row[1]] for row in rows]
                table=Table(data,colWidths=[480/len(data[0])]*len(data[0]),repeatRows=1,hAlign='LEFT')
                table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('BACKGROUND',(0,0),(-1,0),colors.HexColor('#edf3f5')),('GRID',(0,0),(-1,-1),.4,colors.HexColor('#d1dce2')),('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6)]));flow.append(table)
            elif t=='BlockQuote':flow.extend(blocks(c,small))
            elif t=='HorizontalRule':flow.append(Spacer(1,10))
            elif t=='Div':flow.extend(blocks(c[1],small))
            else:raise ValueError('Unsupported PDF block: '+t)
        return flow
    raw=blocks(ast['blocks']);flow=[];i=0
    while i<len(raw):
        if isinstance(raw[i],Image) and i+2<len(raw) and isinstance(raw[i+2],Paragraph):
            flow.append(KeepTogether(raw[i:i+3]));i+=3
        else:flow.append(raw[i]);i+=1
    out.parent.mkdir(parents=True,exist_ok=True)
    def footer(canvas,doc):
        canvas.setFont('IAN',7);canvas.setFillColor(colors.HexColor('#556a76'));canvas.drawString(48,27,label[:95]);canvas.drawRightString(552,27,str(doc.page))
    SimpleDocTemplate(str(out),pagesize=(600,792),rightMargin=60,leftMargin=60,topMargin=40,bottomMargin=44,title=label,author='IAN project').build(flow,onFirstPage=footer,onLaterPages=footer)
