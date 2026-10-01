# Import a completed synthetic experiment; never rerun the benchmark here.
args <- commandArgs(TRUE)
if (length(args) != 1L) stop('Supply the completed experiment directory.')
root <- normalizePath(args[1]); out <- 'inst/extdata/fermat-density-curvature'
dir.create(out, recursive=TRUE, showWarnings=FALSE)
metrics <- read.csv(file.path(root,'results/metrics.csv'))
metrics <- subset(metrics,stratum=='all')
summary <- subset(read.csv(file.path(root,'results/summary.csv')),stratum=='all')
references <- read.csv(file.path(root,'results/references.csv'))
stopifnot(nrow(metrics)==2100L,nrow(references)==10500L,
          all(table(metrics$id)==300L),all(metrics$test_pairs<=1000L))
files <- c('common.R','prepare.R','references.R','distances.R',
           'reference_sensitivity.R','evaluate.R','validate.R',
           'power_common.R','power_tuning.R','power_transfer.R','power_summarize.R','power_validate.R')
figures <- c('surfaces','paraboloid_fermat','saddle_fermat','swiss_roll_fermat',
             'chord_distortion','paraboloid_knn','saddle_knn','swiss_roll_knn',
             'paraboloid_clairaut','paired_difference','power_tuning_full','power_tuning_near',
             'power_transfer','power_transfer_difference','power_clairaut_tuning','power_clairaut_transfer')
power_files <- c('folds','fold_scores','cv_repetitions','cv_summary','coarse_winners',
                 'selection','transfer_metrics','transfer_summary')
power_tuning <- setNames(lapply(power_files,function(name)
 read.csv(file.path(root,'results/power_tuning',paste0(name,'.csv')))),power_files)
power_tuning$provenance <- jsonlite::read_json(file.path(root,'power_tuning_provenance.json'))
power_tuning$validation <- jsonlite::read_json(file.path(root,'power_tuning_validation.json'))
power_tuning$completion <- jsonlite::read_json(file.path(root,'results/power_tuning/transfer_completion.json'))
stopifnot(nrow(power_tuning$selection)==9L,nrow(power_tuning$transfer_metrics)==1275L)
inputs <- c(files,'power_tuning_provenance.json','power_tuning_validation.json',
            paste0('results/power_tuning/',power_files,'.csv'),'results/power_tuning/transfer_completion.json','results/metrics.csv','results/summary.csv','results/references.csv',
            'results/reference_sensitivity.csv','results/completion.json','provenance.json',
            paste0('results/figures/',figures,'.png'))
provenance <- list(experiment='fermat_density_curvature_01_oct_2026',
  research_revision=system2('git',c('-C',shQuote(root),'rev-parse','HEAD'),stdout=TRUE),
  source_md5=setNames(unname(tools::md5sum(file.path(root,inputs))),inputs),
  original=jsonlite::read_json(file.path(root,'provenance.json')),
  completion=jsonlite::read_json(file.path(root,'results/completion.json')),
  adaptation='Packaged saddle diagnostic defaults to one worker; numerical controls are unchanged.',
  note='Frozen completed synthetic benchmark. No new experiments run during import or article rendering.')
provenance$original$installed_dgraphs_path <- NULL
saveRDS(list(metrics=metrics,summary=summary,references=references,power_tuning=power_tuning,
  sensitivity=read.csv(file.path(root,'results/reference_sensitivity.csv')),
  provenance=provenance),file.path(out,'benchmark.rds'),compress='xz',version=2)
writeLines(trimws(capture.output(dput(provenance)),which='right'),file.path(out,'provenance.R'))
stopifnot(all(file.copy(file.path(root,files),'inst/examples/fermat-density-curvature',overwrite=TRUE)),
 all(file.copy(file.path(root,paste0('results/figures/',figures,'.png')),
               'vignettes/articles/figures/fermat-density-curvature',overwrite=TRUE)))
cat('Imported the original benchmark plus nine power selections and 1,275 follow-up comparison records.\n')

# Keep the installed reproduction workflow portable to non-fork platforms.
p <- 'inst/examples/fermat-density-curvature/reference_sensitivity.R'
text <- paste(readLines(p),collapse='\n')
text <- sub('a<-parallel::mclapply(seq_len(nrow(tasks)),work,mc.cores=2L,mc.preschedule=FALSE)',
 'args<-commandArgs(TRUE); workers<-if(length(args))as.integer(args[1]) else 1L\na<-parallel::mclapply(seq_len(nrow(tasks)),work,mc.cores=workers,mc.preschedule=FALSE)',text,fixed=TRUE)
writeLines(text,p)
