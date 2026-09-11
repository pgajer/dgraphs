#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
home <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
fixture.home <- normalizePath(file.path(home, "../../fixtures/quadform_geodesics"))
source(file.path(fixture.home, "collection.R")); source(file.path(home, "interface.R"))
source(file.path(home, "runner.R")); source(file.path(home, "campaign.R"))
if (!length(args) || identical(args, "--help")) {
  cat("Usage: Rscript compare.R plan NEW_DIRECTORY\n",
      "       Rscript compare.R run EXISTING_DIRECTORY [MAX_JOBS]\n",
      "       Rscript compare.R status EXISTING_DIRECTORY\n",
      "Plan freezes the 704-job calibration design, but does not execute it.\n",
      "Run requires all bound adapters (including adaptive_initializer) to be implemented.\n", sep = "")
  quit(status = 0)
}
qg.assert(length(args) %in% 2:3 && args[1] %in% c("plan", "run", "status"), "Invalid command")
if (args[1] == "plan") {
  qg.assert(length(args) == 2L, "plan accepts only the output directory")
  x <- qg.read(file.path(fixture.home, "v1"))
  plan <- qgs.campaign.plan(x)
  qgs.campaign.create(home, file.path(fixture.home, "v1"), args[2], plan)
  cat("Frozen", length(plan$jobs), "planned jobs; no solvers executed.\n")
} else if (args[1] == "run") {
  cap <- if (length(args) == 3L) as.double(args[3]) else Inf
  result <- qgs.campaign.run(home, args[2], max_jobs = cap)
  print(result)
  if (!is.null(result$termination)) {
    quit(status = if (result$termination %in% c("campaign_budget", "time_budget")) 2L else 1L)
  }
} else {
  qg.assert(length(args) == 2L, "status accepts only the output directory")
  data <- qgs.campaign.read(args[2])
  print(table(data$state$status))
  cat("Charged campaign seconds:", data$state$charged_seconds, "/", data$plan$seconds, "\n")
}
