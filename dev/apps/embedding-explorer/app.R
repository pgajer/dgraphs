options(rgl.useNULL=TRUE, shiny.maxRequestSize=100*1024^2)
library(shiny)
library(bslib)
library(DT)
# Small single-choice lists use native controls; ID search retains selectize.
selectInput <- function(...,selectize=FALSE) shiny::selectInput(...,selectize=selectize)
root <- normalizePath(Sys.getenv('GEOMETRY_LAB_ROOT',getwd()),mustWork=TRUE)
for(file in c('engine.R','viewer.R')) source(file.path(root,'R',file),local=TRUE)
python <- Sys.getenv('GEOMETRY_LAB_PYTHON','')
if(!nzchar(python) && file.exists(file.path(study_root_default(),'settings.rds')))
  python <- readRDS(file.path(study_root_default(),'settings.rds'))$python %||% ''

ui <- fluidPage(theme=bs_theme(version=5,base_font='system-ui',primary='#087e8b'),
  tags$head(tags$title('Geometry Lab · 3D embedding explorer'),
    includeCSS(file.path(root,'www/lab.css')),includeScript(file.path(root,'www/lab.js'))),
  div(class='appbar',div(div(class='eyebrow','ivue / Shiny · geometric experiments'),div(class='brand','Geometry Lab')),
    div(class='subtle','Generate a geometry. Compare its embeddings.\nFollow the same samples through every view.')),
  div(class='app-layout',
    div(class='controls',
      div(class='step',span('01'),'True geometry'),
      selectInput('surface','Generating surface',surface_labels,selected='saddle'),
      conditionalPanel("input.surface === 'custom'",div(class='inline-inputs',
        numericInput('coef_a','a · u²',.8,min=-20,max=20,step=.1),numericInput('coef_c','c · v²',-.8,min=-20,max=20,step=.1)),
        numericInput('coef_b','b · cross term 2uv',0,min=-20,max=20,step=.1)),
      uiOutput('surface_formula'),
      div(class='inline-inputs',selectInput('domain','Domain',c('Square'='square','Disk'='disk')),
        numericInput('extent','Half-width / radius',1,min=.1,max=5,step=.1)),
      tags$hr(),div(class='step',span('02'),'Sample the surface'),
      selectInput('sampling','Sampling distribution',c('Uniform parameter coordinates'='uniform',
        'Uniform surface area'='area','Regular grid'='grid','Concentrated center'='center','Gap across u = 0'='gap')),
      conditionalPanel("input.sampling === 'gap'",sliderInput('gap','Gap half-width / domain extent',.01,.8,.2,step=.01)),
      div(class='inline-inputs',numericInput('n','Samples',300,min=30,max=1200,step=10),
        numericInput('sample_seed','Sampling seed',4101,min=0,max=2147483647,step=1)),
      numericInput('noise','Measurement noise · SD per coordinate',0,min=0,max=2,step=.01),
      actionButton('generate','Generate samples',class='btn-primary'),
      div(class='help','Changes apply when you generate. A new cloud clears comparison history; export it first to keep it.'),
      tags$hr(),div(class='step',span('03'),'Embed in 3D'),
      selectInput('method','Method',method_labels,selected='isomap'),
      div(class='inline-inputs',numericInput('k','Graph k · other neighbors',10,min=2,max=100,step=1),
        numericInput('layout_seed','Layout seed',5101,min=0,max=2147483647,step=1)),
      conditionalPanel("input.method === 'umap'",
        selectInput('umap_init','Initial layout',c('Spectral'='spectral','Random'='random','PCA + tiny jitter'='pca','Graph MDS + tiny jitter'='graph_mds')),
        div(class='inline-inputs',numericInput('min_dist','min_dist',.1,min=0,max=5,step=.05),numericInput('spread','Spread',1,min=.01,max=10,step=.1)),
        numericInput('epochs','Epochs',300,min=10,max=2000,step=50),
        tags$details(tags$summary('UMAP optimization'),numericInput('learning_rate','Learning rate',1,min=.01,max=10,step=.1),
          numericInput('repulsion','Repulsion strength',1,min=.01,max=10,step=.1),numericInput('negative_samples','Negative samples',5,min=1,max=50,step=1)),
        div(class='help','Exact neighbors plus self: UMAP n_neighbors = k + 1. min_dist shapes packing; it is not a hard lower distance bound.')),
      conditionalPanel("input.method === 'mds'",selectInput('mds_init','Initial layout',c('Classical MDS'='classical','Random'='random')),
        div(class='inline-inputs',numericInput('mds_starts','Starts',1,min=1,max=5,step=1),numericInput('iterations','Iterations',150,min=10,max=1000,step=10)),
        numericInput('tolerance','Convergence tolerance',1e-7,min=1e-12,max=.01)),
      conditionalPanel("input.method === 'grip'",selectInput('placement','Insertion layout',c('Barycenter'='barycenter','Circle'='circle')),
        div(class='inline-inputs',numericInput('rounds','Initial rounds',100,min=10,max=1000,step=10),numericInput('final_rounds','Final rounds',240,min=10,max=2000,step=20)),
        selectInput('final_mode','Final force model',c('FR'='fr','KK + repulsion'='kk_repulse'))),
      checkboxInput('refine','Also run edge-KK refinement',FALSE),
      conditionalPanel('input.refine',numericInput('kk_iterations','Refinement iterations',60,min=1,max=500,step=10),
        selectInput('kk_scale','Refinement scale',c('Profiled'='profiled','Identity'='identity','Fixed initial'='fixed_initial')),
        selectInput('stiffness','Edge stiffness',c('Uniform'='uniform','Density'='density','Distance power (exponent 0)'='distance_power'))),
      actionButton('run_fit','Run embedding',class='btn-primary'),actionButton('cancel_fit','Cancel running fit'),
      div(class='help','One background job per session · 5 minute limit. View and compare completed fits while a new fit runs.'),
      tags$hr(),div(class='step',span('04'),'Explore the result'),
      selectInput('alignment','Display alignment',c('Similarity · rotation, reflection, scale'='similarity','Rigid · rotation and reflection'='rigid','Raw coordinates'='raw')),
      checkboxInput('show_surface','Overlay generating surface',TRUE),
      sliderInput('surface_alpha','Reference opacity',0,.7,.16,step=.02),
      checkboxInput('show_mesh','Show corresponding sample mesh',FALSE),
      sliderInput('mesh_alpha','Sample mesh opacity',0,.8,.2,step=.05),
      checkboxInput('show_edges','Show neighbor graph',FALSE),
      checkboxInput('show_axes','Show coordinate axes',TRUE),
      checkboxInput('link_cameras','Link rotation and zoom',TRUE),
      selectInput('color','Shared point colors',c('True u coordinate'='u','True v coordinate'='v',
        'True height'='height','Measurement noise magnitude'='noise','Fit A correspondence error'='error')),
      sliderInput('point_size','Point size',1,8,3,step=.5),
      radioButtons('mouse_mode','Left drag',c('Rotate'='rotate','Brush'='brush'),inline=TRUE),
      actionButton('reset_camera','Reset all cameras'),
      tags$details(tags$summary('Graph route'),checkboxInput('show_route','Show shortest route on fit A graph',FALSE),
        selectizeInput('route_from','From sample',choices=NULL),selectizeInput('route_to','To sample',choices=NULL)),
      tags$hr(),div(class='help','Flat and quadratic surfaces are available now. 16S triplet and simplex-complex models are specified as future adapters; see SPEC.md.')
    ),
    div(class='main',
      div(class='intro',div(h1('How much geometry survives?'),uiOutput('context_line')),uiOutput('job_status')),
      tabsetPanel(id='workspace',
        tabPanel('Compare',value='compare',
          div(class='viewer-grid',view_card('truth','Sampled truth'),
            view_card('a','Embedding A',selectInput('fit_a',NULL,choices=NULL)),
            view_card('b','Embedding B',selectInput('fit_b',NULL,choices=NULL))),
          uiOutput('color_legend'),
          div(class='selection-banner',uiOutput('selection_summary'),div(class='toolbar',
            actionButton('clear_selection','Clear selection'),downloadButton('download_selection','Save selected samples'))),
          div(class='detail-card',div(class='toolbar',h2('Diagnostics'),numericInput('q','Evaluation neighbors q',10,min=1,max=100,step=1)),
            div(class='help','Metrics use every sample, regardless of highlight. q changes diagnostics only; graph k belongs to each fit.'),
            DTOutput('diagnostics'),tags$details(tags$summary('Metric definitions'),
              tags$p('Correspondence NRMSE: similarity-aligned residual to noiseless truth, divided by its centered size. Chord and edge NRMSE: one least-squares scale fitted to all observed-space pair distances. Zero is ideal. These are not nearest-surface or intrinsic geodesic errors.'),
              tags$p('Trustworthiness penalizes false neighbors; continuity penalizes lost neighbors. Recall is the fraction of exact input-space neighbors retained. All use observed Euclidean distances, have ideal value 1, and break distance ties by sample row.'))),
          div(class='detail-card',h2('Fit history'),DTOutput('history'),
            div(class='help','The observed-input baseline retains measurement noise. Fit A and B always refer to the current cloud. New results select the latest fit, or parent and refinement, automatically.')),
          div(class='detail-card',h2('Selected samples'),selectizeInput('sample_find','Find sample IDs',choices=NULL,multiple=TRUE),DTOutput('sample_table')),
          uiOutput('route_note')),
        tabPanel('Surface overlay',value='overlay',
          div(class='overlay-layout',view_card('overlay','Fit A + fit B + generating surface',height='600px'),
            div(class='detail-card overlay-notes',h2('Follow corresponding vertices'),
              tags$p('Blue: fit A. Orange: fit B. Gray: the known generating surface. Both fits use the selected display alignment and the same original sample triangulation.'),
              checkboxInput('displacements','Join corresponding vertices',TRUE),sliderInput('segments','Correspondence segments',10,150,50,step=10),
              tags$p('Lines join the two displayed fits. They are not optimizer trajectories or surface-normal projections.'),
              tags$p('The full-domain analytic surface is a visual reference. The sample mesh spans the sampled footprint; it is not the neighbor graph.'),
              tags$p('Similarity alignment permits reflection and uniform rescaling. Raw coordinates preserve each method’s output scale and may produce widely separated overlays.'),
              tags$a(href='https://pgajer.github.io/grip/supplements/S4-interactive-saddle.html#fig-s4-3',target='_blank','Reference: Supplement S4.3')))),
        tabPanel('Saved study',value='study',
          div(class='detail-card',h2('Explore the best-of-six experiment'),
            div(class='help','Read existing coordinates and recorded scores. Select a row and load it into the comparison workspace. A different cloud replaces current history.'),
            textInput('study_path','Study main folder, study root, or review folder',study_root_default(),width='100%'),
            actionButton('load_study','Read study index'),uiOutput('study_status'),
            div(class='filter-grid',selectInput('study_surface','Surface',choices='All'),selectInput('study_domain','Domain',choices='All'),
              selectInput('study_n','Samples',choices='All'),selectInput('study_cloud','Cloud seed',choices='All'),
              selectInput('study_k','Graph k',choices='All'),selectInput('study_method','Method',choices='All'),
              selectInput('study_seed','Layout seed',choices='All'),selectInput('study_parameter','Parameter',choices='All')),
            DTOutput('study_table'),div(class='toolbar',actionButton('load_saved','Load selected fit',class='btn-primary'),
              downloadButton('download_study','Export filtered scores'))),
          div(class='detail-card',h2('Parameter exploration'),
            div(class='toolbar',selectInput('study_metric','Recorded metric',c('Ambient chord NRMSE'='ambient_chord_nrmse',
              'Rigid correspondence NRMSE'='rigid_correspondence_nrmse','Route-to-surface NRMSE'='route_to_surface_nrmse',
              'Trustworthiness, q = 10'='trustworthiness_10','Continuity, q = 10'='continuity_10'))),
            plotly::plotlyOutput('study_plot',height='340px'),
            div(class='help','Each dot is one saved attempt; hover identifies its cloud, method, seed and parameter. No pooled uncertainty interval is inferred from repeated clouds. Filter to matched conditions for comparisons.'))),
        tabPanel('Export & provenance',value='export',
          div(class='detail-card',h2('Keep this experiment'),div(class='toolbar',downloadButton('download_bundle','Experiment bundle · RDS'),
            downloadButton('download_coordinates','Coordinates · CSV'),downloadButton('download_specs','Specifications · JSON')),
            tags$p(class='help','The bundle includes truth, observations, sample mesh, raw fits, graphs and provenance. CSV includes raw and displayed coordinates for both selected fits, with stable sample IDs.'),
            fileInput('import_bundle','Restore a trusted Geometry Lab bundle',accept='.rds')),
          div(class='detail-card',h2('Current cloud and selected fits'),verbatimTextOutput('provenance')),
          div(class='detail-card',h2('Original saved-study scores'),
            tags$p(class='help','Shown only for imported historical fits. These retain the study’s original calibration and approximate geodesic definitions. They differ from the live diagnostics above.'),
            verbatimTextOutput('original_scores')),
          div(class='detail-card',h2('Errors and warnings'),verbatimTextOutput('warnings')))
      ),
      div(class='footer-note','Local Shiny application · ivue rendering · immutable sample correspondence · display alignment never changes saved fits')
    )
  ))

server <- function(input,output,session) {
  initial<-make_experiment()
  initial$fits<-run_fit(initial$cloud,default_fit_spec(),root)
  state<-reactiveVal(initial);selected<-reactiveVal(integer());revision<-reactiveVal(0L)
  status<-reactiveVal(list(text='Demo ready: 300 saddle samples, observed input and Isomap. Generate a cloud or run another embedding.',error=FALSE))
  job<-NULL;job_started<-NULL;job_cloud<-NULL;study<-reactiveVal(NULL);widget_keys<-reactiveValues()
  busy<-reactiveVal(FALSE)
  report_error<-function(e) { status(list(text=conditionMessage(e),error=TRUE));showNotification(conditionMessage(e),type='error',duration=10) }
  guard<-function(code) tryCatch(force(code),error=report_error)
  baseline<-function(c) list(id='observed',cloud_id=c$id,label='Observed input · baseline',coords=c$observed,
    graph=NULL,spec=list(method='observed'),warnings=character(),provenance=list(source='Observed input before embedding'))
  fits<-reactive(c(list(baseline(state()$cloud)),state()$fits))
  chosen<-function(id) { fs<-fits();ix<-match(id %||% 'observed',vapply(fs,`[[`,'','id'));fs[[if(is.na(ix)) 1L else ix]] }
  fit_a<-reactive(chosen(input$fit_a));fit_b<-reactive(chosen(input$fit_b))
  update_choices<-function(a=NULL,b=NULL) {
    fs<-isolate(fits());choices<-setNames(vapply(fs,`[[`,'','id'),vapply(fs,`[[`,'','label'))
    for(p in c('a','b')) {
      target<-if(p=='a') a else b
      old<-isolate(input[[paste0('fit_',p)]])
      updateSelectInput(session,paste0('fit_',p),choices=choices,selected=target %||% if(length(old) && old%in%choices) old else 'observed')
    }
  }
  replace_cloud<-function(bundle) {
    state(validate_bundle(bundle));selected(integer());revision(isolate(revision())+1L)
    ids<-bundle$cloud$ids
    spec<-bundle$cloud$spec
    for(name in c('surface','domain','sampling')) updateSelectInput(session,name,selected=spec[[name]])
    for(name in c('n','extent','noise')) updateNumericInput(session,name,value=spec[[name]])
    updateNumericInput(session,'sample_seed',value=spec$seed)
    updateNumericInput(session,'coef_a',value=spec$coefficients[1])
    updateNumericInput(session,'coef_b',value=spec$coefficients[2])
    updateNumericInput(session,'coef_c',value=spec$coefficients[3])
    updateSliderInput(session,'gap',value=spec$gap)
    updateSelectizeInput(session,'sample_find',choices=ids,selected=character(),server=TRUE)
    updateSelectizeInput(session,'route_from',choices=ids,selected=ids[1],server=TRUE)
    updateSelectizeInput(session,'route_to',choices=ids,selected=tail(ids,1),server=TRUE)
    updateNumericInput(session,'q',max=floor((length(ids)-1)/2),value=min(isolate(input$q) %||% 10,floor((length(ids)-1)/2)))
    update_choices(if(length(bundle$fits)) bundle$fits[[1]]$id else 'observed',if(length(bundle$fits)) tail(bundle$fits,1)[[1]]$id else 'observed')
  }
  observeEvent(TRUE,{replace_cloud(initial);update_choices('observed',initial$fits[[1]]$id);session$sendCustomMessage('labBusy',FALSE)},once=TRUE)
  draft_spec<-reactive({s<-default_spec();s$surface<-input$surface %||% 'saddle'
    s$coefficients<-if(s$surface=='custom') c(input$coef_a,input$coef_b,input$coef_c) else surface_presets[[s$surface]]
    s$domain<-input$domain;s$extent<-input$extent;s$sampling<-input$sampling;s$n<-input$n
    s$seed<-input$sample_seed;s$noise<-input$noise;s$gap<-input$gap;s})
  output$surface_formula<-renderUI({s<-draft_spec();div(class='help',sprintf('z = %g u² + %g uv + %g v²',s$coefficients[1],2*s$coefficients[2],s$coefficients[3]))})
  observeEvent(input$generate,guard({
    if(busy()) stop('Cancel or finish the running fit before replacing the cloud.')
    bundle<-make_experiment(draft_spec());replace_cloud(bundle)
    status(list(text=paste(length(bundle$cloud$ids),'samples generated. Choose an embedding to compare.'),error=FALSE))
  }))
  fit_spec<-function() {
    s<-default_fit_spec();s$method<-input$method;s$k<-input$k;s$seed<-input$layout_seed;s$init<-input$umap_init
    for(nm in c('epochs','min_dist','spread','learning_rate','repulsion','negative_samples','mds_init','mds_starts',
      'iterations','tolerance','rounds','final_rounds','placement','final_mode','refine','kk_iterations','kk_scale','stiffness')) s[[nm]]<-input[[nm]]
    for(nm in c('epochs','negative_samples','mds_starts','iterations','rounds','final_rounds','kk_iterations'))
      scalar_number(s[[nm]],nm,1,2000,TRUE)
    s
  }
  observeEvent(input$run_fit,guard({
    if(busy()) stop('A fit is already running.')
    if(length(state()$fits)>=38) stop('History is full. Export this experiment and generate a new cloud.')
    c<-state()$cloud;s<-fit_spec();scalar_number(s$k,'Graph k',2,min(100,length(c$ids)-2),TRUE)
    job_cloud<<-c$id;job_started<<-Sys.time()
    job<<-callr::r_bg(function(cloud,spec,app_root,python) {
      Sys.setenv(OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,VECLIB_MAXIMUM_THREADS=1,NUMBA_NUM_THREADS=1)
      source(file.path(app_root,'R/engine.R'))
      run_fit(cloud,spec,app_root,python)
    },args=list(cloud=c,spec=s,app_root=root,python=python),supervise=TRUE)
    busy(TRUE);session$sendCustomMessage('labBusy',TRUE)
    status(list(text=paste('Running',names(method_labels)[match(s$method,method_labels)],'on',length(c$ids),'samples…'),error=FALSE))
  }))
  finish_job<-function() {job<<-NULL;busy(FALSE);session$sendCustomMessage('labBusy',FALSE)}
  observe({invalidateLater(350,session)
    if(!is.null(job)) {
      if(as.numeric(difftime(Sys.time(),job_started,units='secs'))>300 && job$is_alive()) {
        job$kill_tree();finish_job();status(list(text='Fit stopped after the 5 minute budget. Completed fits are retained.',error=TRUE))
      } else if(!job$is_alive()) {
        guard({new<-job$get_result();if(!identical(job_cloud,isolate(state())$cloud$id)) stop('Completed fit belongs to a different cloud.')
          bundle<-isolate(state());bundle$fits<-c(bundle$fits,new);state(validate_bundle(bundle))
          update_choices(if(length(new)>1) new[[1]]$id else isolate(input$fit_b) %||% 'observed',tail(new,1)[[1]]$id)
          status(list(text=paste('Completed:',paste(vapply(new,`[[`,'','label'),collapse=' → ')),error=FALSE))})
        finish_job()
      }
    }
  })
  observeEvent(input$cancel_fit,{if(!is.null(job)) {job$kill_tree();finish_job();status(list(text='Run cancelled. Completed fits are retained.',error=FALSE))}})
  session$onSessionEnded(function() {if(!is.null(job)&&job$is_alive()) job$kill_tree()})
  output$job_status<-renderUI({x<-status();div(class=paste('status',if(x$error)'error'),if(busy())span(class='busy-dot'),x$text)})
  output$context_line<-renderUI({c<-state()$cloud;s<-c$spec;div(class='subtle',paste(length(c$ids),'samples ·',
    gsub('_',' ',s$surface),'·',s$domain,'·',gsub('_',' ',s$sampling),'· sampling seed',s$seed,
    '·',length(state()$fits),'saved fits'))})
  aligned<-reactive({c<-state()$cloud;list(truth=c$truth,a=align_coords(fit_a()$coords,c$truth,input$alignment %||% 'similarity')$coords,
    b=align_coords(fit_b()$coords,c$truth,input$alignment %||% 'similarity')$coords)})
  coloring<-reactive(cloud_colors(state()$cloud,input$color %||% 'u',fit_a()))
  config<-reactive({a<-aligned();c<-state()$cloud
    X<-rbind(a$truth,a$a,a$b,if(isTRUE(input$show_surface)) c$reference$coords)
    mid<-(apply(X,2,min)+apply(X,2,max))/2;half<-max(apply(X,2,function(x) diff(range(x))))/2*1.05
    bounds<-sweep(as.matrix(expand.grid(c(-1,1),c(-1,1),c(-1,1)))*half,2,mid,'+')
    list(surface=isTRUE(input$show_surface),surface_alpha=input$surface_alpha %||% .16,
      mesh=isTRUE(input$show_mesh),mesh_alpha=input$mesh_alpha %||% .2,edges=isTRUE(input$show_edges),
      axes=isTRUE(input$show_axes),size=input$point_size %||% 3,mouse=input$mouse_mode %||% 'rotate',
      bounds=bounds,segments=input$segments %||% 50)})
  route<-reactive({if(!isTRUE(input$show_route)) return(integer());c<-state()$cloud
    route_vertices(fit_a()$graph,length(c$ids),match(input$route_from,c$ids),match(input$route_to,c$ids))})
  for(p in c('truth','a','b','overlay')) local({panel<-p
    output[[paste0('view_',panel)]]<-rgl::renderRglwidget({
      c<-state()$cloud;cfg<-config();coords<-aligned()[[if(panel=='overlay') 'a' else panel]]
      fit<-if(panel=='b')fit_b() else fit_a()
      if(panel=='overlay') {cfg$mesh<-TRUE;cfg$displacements<-isTRUE(input$displacements);cfg$height<-600}
      key<-paste(c$id,panel,input$alignment,revision(),sep='|');widget_keys[[panel]]<-key
      lab_widget(coords,c,cfg,coloring()$colors,selected(),graph=fit$graph,
        other=if(panel=='overlay') aligned()$b else NULL,route=route(),panel=panel,key=key,session_group=session$token)
    })
    observeEvent(input[[paste0('brush_commit_',panel)]],guard({
      event<-input[[paste0('brush_commit_',panel)]];if(!identical(event$key,isolate(widget_keys[[panel]]))) return()
      brush<-input[[paste0('brush_',panel)]];if(is.null(brush$region)||!identical(brush$state,'changing')) return()
      xyz<-aligned()[[if(panel=='overlay') 'a' else panel]]
      ix<-which(rgl::selectionFunction3d(brush)(xyz));selected(ix)
      updateSelectizeInput(session,'sample_find',selected=state()$cloud$ids[ix])
    }),ignoreInit=TRUE)
  })
  observeEvent(input$reset_camera,{session$sendCustomMessage('labResetCamera',list());revision(revision()+1L)})
  observeEvent(input$clear_selection,{selected(integer());updateSelectizeInput(session,'sample_find',selected=character())})
  observeEvent(input$sample_find,{selected(na.omit(match(input$sample_find,state()$cloud$ids)))},ignoreNULL=FALSE)
  output$selection_summary<-renderUI(div(tags$strong(paste(length(selected()),'samples selected')),
    ' · Brush a view or search sample IDs. Selection is linked across views.'))
  output$color_legend<-renderUI({x<-coloring();div(class='legend-line',tags$strong(switch(input$color %||% 'u',
    u='True u',v='True v',height='True height',noise='Noise magnitude',error='Fit A error')),
    format(x$limits[1],digits=3),span(class='scale-bar'),format(x$limits[2],digits=3),' · one color per sample in all three views')})
  scores<-reactive({q<-min(input$q %||% 10,floor((length(state()$cloud$ids)-1)/2));list(
    a=score_fit(fit_a()$coords,state()$cloud,fit_a()$graph,q),b=score_fit(fit_b()$coords,state()$cloud,fit_b()$graph,q))})
  output$metric_truth<-renderUI(div(class='metric-block',span(class='metric-value',length(state()$cloud$ids)),
    span(class='metric-name','Known corresponding samples'),div(class='help','Colors stay attached to sample identity.')))
  for(p in c('a','b'))local({panel<-p;output[[paste0('metric_',panel)]]<-renderUI({s<-scores()[[panel]];f<-if(panel=='a')fit_a() else fit_b()
    div(class='metric-block',div(class='metric-grid',div(span(class='metric-value',sprintf('%.3f',s$correspondence_nrmse)),
      span(class='metric-name','Correspondence NRMSE ↓')),div(span(class='metric-value',sprintf('%.1f%%',100*s$neighbor_recall)),span(class='metric-name','Neighbor recall ↑'))),
      if(!is.null(f$graph)) div(class='help',paste('Graph k =',f$graph$k,'·',f$graph$components,'component(s)')))
  })})
  output$metric_overlay<-renderUI(div(class='metric-block',span(class='help','Blue: A · Orange: B · Gray: generating surface · Rose: corresponding-vertex displacement')))
  output$diagnostics<-renderDT({s<-scores();keys<-c('correspondence_nrmse','chord_nrmse','edge_nrmse','trustworthiness','continuity','neighbor_recall')
    x<-data.frame(Metric=c('Correspondence NRMSE','Ambient chord NRMSE','Graph-edge NRMSE','Trustworthiness','Continuity','Exact neighbor recall'),
      A=unlist(s$a[keys]),B=unlist(s$b[keys]),Ideal=c('0','0','0','1','1','1'),row.names=NULL)
    datatable(x,rownames=FALSE,options=list(dom='t',scrollX=TRUE),selection='none') |> formatRound(columns=c('A','B'),digits=4)})
  output$history<-renderDT({fs<-fits();x<-do.call(rbind,lapply(fs,function(f) data.frame(Method=f$label,
    k=if(!is.null(f$graph))f$graph$k else NA,Seconds=f$seconds %||% NA,Source=f$provenance$source,
    Warnings=paste(f$warnings,collapse='; '))))
    datatable(x,rownames=FALSE,options=list(pageLength=5,scrollX=TRUE),selection='none') |> formatRound('Seconds',2)})
  selected_data<-reactive({c<-state()$cloud;ix<-selected();a<-aligned();data.frame(id=c$ids[ix],u=c$uv[ix,1],v=c$uv[ix,2],
    truth_x=c$truth[ix,1],truth_y=c$truth[ix,2],truth_z=c$truth[ix,3],
    error_A=sqrt(rowSums((a$a[ix,,drop=FALSE]-c$truth[ix,,drop=FALSE])^2)),
    error_B=sqrt(rowSums((a$b[ix,,drop=FALSE]-c$truth[ix,,drop=FALSE])^2)))})
  output$sample_table<-renderDT(datatable(selected_data(),rownames=FALSE,options=list(pageLength=8,scrollX=TRUE),selection='none') |>
    formatRound(columns=setdiff(names(selected_data()),'id'),digits=4))
  output$route_note<-renderUI({if(!isTRUE(input$show_route))return(NULL);r<-route();div(class='notice',
    if(length(r)<2) 'No route: select two distinct samples and a graph-based fit A with connected endpoints.' else
      paste('Orange route:',length(r),'vertices on fit A’s observed-space graph, carried through all displays.'))})

  observeEvent(input$load_study,guard({s<-read_study(input$study_path);study(s)
    fields<-c(surface='surface',domain='domain',n='n',cloud='cloud_seed',k='k',method='family',seed='layout_seed',parameter='parameter')
    for(name in names(fields)) {values<-sort(unique(s$table[[fields[[name]]]]));updateSelectInput(session,paste0('study_',name),choices=c('All',as.character(values)),selected='All')}
  }))
  output$study_status<-renderUI({s<-study();if(is.null(s))return(div(class='help','No index loaded yet.'))
    div(class='chip',paste(format(nrow(s$table),big.mark=','),'recorded attempts ·',length(unique(s$table$cloud_id)),'clouds'))})
  filtered_study<-reactive({req(study());x<-study()$table
    fields<-c(surface='surface',domain='domain',n='n',cloud='cloud_seed',k='k',method='family',seed='layout_seed',parameter='parameter')
    for(name in names(fields)) {v<-input[[paste0('study_',name)]] %||% 'All';if(v!='All')x<-x[!is.na(x[[fields[[name]]]]) & as.character(x[[fields[[name]]]])==v,,drop=FALSE]};x})
  output$study_table<-renderDT({x<-filtered_study();keep<-c('row_id','surface','domain','n','cloud_seed','k','family','layout_seed','parameter','status','ambient_chord_nrmse','trustworthiness_10')
    datatable(x[,intersect(keep,names(x)),drop=FALSE],rownames=FALSE,selection='single',options=list(pageLength=8,scrollX=TRUE)) |> formatRound(c('ambient_chord_nrmse','trustworthiness_10'),4)})
  observeEvent(input$load_saved,guard({
    if(busy())stop('Cancel or finish the running fit before loading another fit.')
    req(input$study_table_rows_selected);row<-filtered_study()[input$study_table_rows_selected,,drop=FALSE]
    if(nrow(row)!=1)stop('Select one saved attempt.')
    bundle<-load_study_fit(study(),row$row_id)
    if(identical(bundle$cloud$id,state()$cloud$id)) {
      b<-state();f<-bundle$fits[[1]]
      if(!f$id%in%vapply(b$fits,`[[`,'','id'))b$fits<-c(b$fits,list(f))
      state(validate_bundle(b));update_choices(b$fits[[1]]$id,f$id)
    } else replace_cloud(bundle)
    updateTabsetPanel(session,'workspace',selected='compare')
    status(list(text=paste('Loaded exact saved coordinates:',bundle$fits[[1]]$label),error=FALSE))
  }))
  output$study_plot<-plotly::renderPlotly({x<-filtered_study();req(nrow(x));metric<-input$study_metric
    x<-x[is.finite(x[[metric]]),,drop=FALSE];validate(need(nrow(x)>0,'No finite scores for these filters.'))
    x$hover<-paste('Cloud:',x$cloud_id,'<br>Method:',x$family,'<br>Parameter:',x$parameter,'<br>Seed:',x$layout_seed,'<br>Status:',x$status)
    plotly::plot_ly(x,x=~k,y=x[[metric]],color=~family,type='scatter',mode='markers',text=~hover,hoverinfo='text+x+y',
      marker=list(size=6,opacity=.55)) |> plotly::layout(xaxis=list(title='Graph k (other neighbors)'),
      yaxis=list(title=gsub('_',' ',metric)),legend=list(orientation='h',y=-.22),margin=list(b=90))
  })
  output$download_study<-downloadHandler(filename=function() 'geometry-study-filtered.csv',content=function(file) write.csv(filtered_study(),file,row.names=FALSE))
  output$download_selection<-downloadHandler(filename=function() 'geometry-selected-samples.csv',content=function(file) write.csv(selected_data(),file,row.names=FALSE))
  output$download_bundle<-downloadHandler(filename=function() paste0('geometry-lab-',substr(state()$cloud$id,1,8),'.rds'),content=function(file) saveRDS(state(),file))
  output$download_coordinates<-downloadHandler(filename=function() 'geometry-coordinates.csv',content=function(file) {
    c<-state()$cloud;a<-aligned();x<-data.frame(id=c$ids)
    for(nm in c('truth','observed','A_raw','B_raw','A_display','B_display')) {
      z<-switch(nm,truth=c$truth,observed=c$observed,A_raw=fit_a()$coords,B_raw=fit_b()$coords,A_display=a$a,B_display=a$b)
      for(j in 1:3)x[[paste0(nm,'_',c('x','y','z')[j])]]<-z[,j]
    };write.csv(x,file,row.names=FALSE)
  })
  specs<-reactive(list(schema=state()$schema,cloud_id=state()$cloud$id,truth=state()$cloud$spec,
    display=list(alignment=input$alignment,evaluation_q=input$q),cloud_provenance=state()$cloud$provenance,
    A=list(id=fit_a()$id,spec=fit_a()$spec,metadata=compact_metadata(fit_a()$metadata),provenance=fit_a()$provenance),
    B=list(id=fit_b()$id,spec=fit_b()$spec,metadata=compact_metadata(fit_b()$metadata),provenance=fit_b()$provenance)))
  output$download_specs<-downloadHandler(filename=function() 'geometry-specifications.json',content=function(file) jsonlite::write_json(specs(),file,auto_unbox=TRUE,pretty=TRUE,null='null',digits=NA))
  observeEvent(input$import_bundle,guard({if(busy())stop('Cancel or finish the running fit before importing.')
    b<-validate_bundle(readRDS(input$import_bundle$datapath));replace_cloud(b);status(list(text='Experiment bundle restored.',error=FALSE))}))
  output$provenance<-renderText(jsonlite::toJSON(specs(),auto_unbox=TRUE,pretty=TRUE,null='null'))
  output$original_scores<-renderPrint(list(A=fit_a()$original_scores %||% 'No historical scores.',B=fit_b()$original_scores %||% 'No historical scores.'))
  output$warnings<-renderPrint(list(A=fit_a()$warnings %||% character(),B=fit_b()$warnings %||% character(),last_message=status()$text))
}
shinyApp(ui,server)
