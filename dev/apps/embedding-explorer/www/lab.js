window.labCameras = {};
window.labViews = {};
window.labReady = {};
window.labBindWidget = function(el, config) {
  const r = el.rglinstance;
  if (!r) return;
  const root = r.getObj(r.scene.rootSubscene);
  const initialZoom = root.par3d.zoom;
  const saved = window.labCameras[config.cameraKey];
  if (saved) { root.par3d.userMatrix.load(saved.matrix); root.par3d.zoom=saved.zoom; r.drawScene(); }
  const canvas=r.canvas;
  canvas.setAttribute('aria-label',config.label);
  canvas.setAttribute('tabindex','0');
  canvas.oncontextmenu=e=>e.preventDefault();
  const controls=el.closest('.view-card').querySelector('.zoom-controls');
  function label() { controls.querySelector('.zoom-value').textContent=Math.round(100*initialZoom/root.par3d.zoom)+'%'; }
  function save(sync=true) {
    const camera={matrix:root.par3d.userMatrix.getAsArray(),zoom:root.par3d.zoom};
    window.labCameras[config.cameraKey]=camera;label();
    if(sync && document.getElementById('link_cameras')?.checked) {
      Object.entries(window.labViews).forEach(([id,view])=>{
        if(id!==el.id && document.contains(view.el)) view.apply(camera);
      });
    }
  }
  window.labViews[el.id]={el,apply(camera){root.par3d.userMatrix.load(camera.matrix);root.par3d.zoom=camera.zoom;r.drawScene();save(false);}};
  function zoom(value) { root.par3d.zoom=Math.max(initialZoom/50,Math.min(initialZoom*20,value));r.drawScene();save(); }
  controls.querySelectorAll('[data-zoom]').forEach(button=>button.onclick=()=>
    zoom(button.dataset.zoom==='reset'?initialZoom:root.par3d.zoom*(button.dataset.zoom==='in'?1/1.2:1.2)));
  canvas.addEventListener('wheel',e=>{
    e.preventDefault();e.stopImmediatePropagation();
    const unit=e.deltaMode===1?16:e.deltaMode===2?canvas.clientHeight:1;
    zoom(root.par3d.zoom*Math.exp(Math.max(-.6,Math.min(.6,e.deltaY*unit*(e.shiftKey?.0003:.0015)))));
  },{passive:false,capture:true});
  ['mousewheel','DOMMouseScroll'].forEach(type=>canvas.addEventListener(type,e=>{e.preventDefault();e.stopImmediatePropagation();},{passive:false,capture:true}));
  canvas.addEventListener('keydown',e=>{
    if(e.ctrlKey||e.metaKey||e.altKey||!['+','=','-','_','0'].includes(e.key))return;
    e.preventDefault();zoom(e.key==='0'?initialZoom:root.par3d.zoom*(['+','='].includes(e.key)?1/1.2:1.2));
  });
  canvas.addEventListener('pointermove',e=>{if(e.buttons && !r.select?.state?.includes('changing'))save();});
  canvas.addEventListener('pointerup',()=>{
    save();
    if(r.select && r.select.state==='changing') {
      r.clearBrush();r.select={state:'inactive'};
      setTimeout(()=>Shiny.setInputValue(config.commit,{time:Date.now(),key:config.cameraKey},{priority:'event'}),0);
    }
  });
  canvas.addEventListener('touchend',()=>setTimeout(save,0));
  label();window.labReady[el.id]=config;
  el.dataset.rows=config.rows;el.dataset.selected=config.selected;
};
$(document).on('shiny:connected',()=>{
  Shiny.addCustomMessageHandler('labResetCamera',message=>{window.labCameras={};});
  Shiny.addCustomMessageHandler('labBusy',busy=>{
    ['generate','run_fit','load_saved','load_study','import_bundle'].forEach(id=>{const el=document.getElementById(id);if(el)el.disabled=busy;});
    const cancel=document.getElementById('cancel_fit');if(cancel)cancel.disabled=!busy;
  });
});
