# Graph explorer component, migrated from dggraphui.
# Copyright Pawel Gajer. License: GPL (>= 3).
dg_html_table <- function(df, empty_text = "No rows.") {
  if (!is.data.frame(df) || nrow(df) < 1L || ncol(df) < 1L) {
    return(shiny::p(class = "dg-muted", empty_text))
  }
  header <- shiny::tags$tr(lapply(names(df), shiny::tags$th))
  rows <- lapply(seq_len(nrow(df)), function(ii) {
    shiny::tags$tr(lapply(df[ii, , drop = FALSE], function(x) shiny::tags$td(as.character(x[[1]] %||% ""))))
  })
  shiny::div(
    class = "table-responsive dg-table-wrap",
    shiny::tags$table(class = "table table-sm dg-table", shiny::tags$thead(header), shiny::tags$tbody(rows))
  )
}

dg_selector_input_values <- function(input) {
  fields <- c(
    "selection_mode", "metric_target", "surface", "curvature_label",
    "domain_shape", "sampling_profile", "n", "seed", "graph_family",
    "k", "radius_rank", "k_scale", "radius_rule", "radius_factor",
    "delta", "prune_method", "stage"
  )
  out <- list()
  for (field in fields) {
    out[[field]] <- input[[paste0("dg_", field)]]
  }
  out
}

dg_app_server <- function(input, output, session, default_run_dir = "") {
  run_state <- shiny::reactiveVal(NULL)
  run_error <- shiny::reactiveVal("")
  layout_revision <- shiny::reactiveVal(0L)

  load_selected_run <- function(path) {
    pp <- dg_scalar_chr(path)
    if (!nzchar(pp)) {
      run_state(NULL)
      run_error("Enter a benchmark run directory.")
      return(invisible(FALSE))
    }
    loaded <- tryCatch(load_benchmark_run(.graph_project_path(pp)), error = function(e) e)
    if (inherits(loaded, "error")) {
      run_state(NULL)
      run_error(conditionMessage(loaded))
      return(invisible(FALSE))
    }
    run_state(loaded)
    run_error("")
    layout_revision(0L)
    invisible(TRUE)
  }

  if (nzchar(default_run_dir)) {
    load_selected_run(default_run_dir)
  }

  shiny::observeEvent(input$load_run, {
    load_selected_run(input$run_dir)
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$saved_project, {
    if (nzchar(dg_scalar_chr(input$saved_project))) {
      shiny::updateTextInput(session, "run_dir", value = input$saved_project)
      load_selected_run(input$saved_project)
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$remember_project, {
    run <- run_state()
    if (!is.list(run)) {
      shiny::showNotification("Open a project before remembering it.", type = "warning")
      return()
    }
    name <- trimws(dg_scalar_chr(input$project_name))
    if (!nzchar(name)) name <- paste(basename(dirname(dirname(run$run_dir))), basename(run$run_dir))
    tryCatch({
      register.graph.project(run$run_dir, name)
      catalog <- .graph_project_catalog()
      shiny::updateSelectInput(session, "saved_project",
        choices = c("Choose a project" = "", stats::setNames(catalog$path, catalog$name)),
        selected = run$run_dir)
      shiny::showNotification("Project remembered. Its files have not moved.", type = "message")
    }, error = function(e) shiny::showNotification(conditionMessage(e), type = "error"))
  }, ignoreInit = TRUE)

  output$run_chip <- shiny::renderUI({
    run <- run_state()
    err <- run_error()
    if (is.list(run)) {
      shiny::span(class = "dg-chip dg-chip-ok", basename(run$run_dir))
    } else if (nzchar(err)) {
      shiny::span(class = "dg-chip dg-chip-warn", "No run loaded")
    } else {
      shiny::span(class = "dg-chip", "Ready")
    }
  })

  selection_state <- shiny::reactive({
    run <- run_state()
    if (!is.list(run)) {
      return(list(error = run_error() %||% "No run loaded.", fields = list(), row = data.frame()))
    }
    dg_selector_state(run, dg_selector_input_values(input))
  })

  view_state <- shiny::reactive({
    layout_revision()
    run <- run_state()
    sel <- selection_state()
    dg_view_state(run, sel)
  })

  output$selector_panel <- shiny::renderUI({
    run <- run_state()
    if (!is.list(run)) {
      err <- run_error()
      return(shiny::div(class = "dg-panel", shiny::h4("Selection"), shiny::p(class = "dg-muted", if (nzchar(err)) err else "Load a benchmark run.")))
    }
    sel <- selection_state()
    controls <- if (is.list(sel$fields) && length(sel$fields) > 0L) {
      lapply(sel$fields, function(field) {
        shiny::div(
          class = "dg-control-row",
          shiny::tags$label(dg_scalar_chr(field$label, field$id)),
          shiny::selectInput(
            inputId = dg_scalar_chr(field$input_id),
            label = NULL,
            choices = field$choices,
            selected = dg_scalar_chr(field$selected),
            width = "100%"
          )
        )
      })
    } else {
      list(shiny::p(class = "dg-muted", dg_scalar_chr(sel$error, "No selectors available.")))
    }
    st <- view_state()
    generate_btn <- if (is.list(st) && st$status %in% c("missing_layout", "layout_error")) {
      shiny::actionButton("generate_layout", "Generate Weighted Layout", class = "btn-primary dg-wide")
    } else {
      NULL
    }
    shiny::div(
      class = "dg-panel",
      shiny::h4("Graph Selection"),
      shiny::tagList(controls),
      shiny::hr(),
      shiny::p(class = "dg-status", dg_selection_summary(sel)),
      if (is.list(st) && !identical(st$status, "ok")) shiny::p(class = "dg-muted", dg_scalar_chr(st$message, st$status)) else NULL,
      generate_btn
    )
  })

  output$asset_panel <- shiny::renderUI({
    run <- run_state()
    if (!is.list(run)) {
      return(NULL)
    }
    rows <- data.frame(
      Asset = c("datasets", "graph stages", "layouts", "metrics"),
      Rows = c(
        run$summary$datasets$n_rows,
        run$summary$graph_assets$n_rows,
        run$summary$layout_assets$n_rows,
        run$summary$metrics$n_rows
      ),
      stringsAsFactors = FALSE
    )
    shiny::div(class = "dg-panel", shiny::h4("Assets"), dg_html_table(rows))
  })

  shiny::observeEvent(input$generate_layout, {
    st <- view_state()
    if (!is.list(st) || !(st$status %in% c("missing_layout", "layout_error"))) {
      shiny::showNotification("No missing weighted layout is selected.", type = "message")
      return()
    }
    out <- dg_generate_weighted_layout(
      graph_asset_path = st$graph_asset_file,
      output_path = st$cache_path,
      params = list(seed = 6L)
    )
    if (!identical(out$status, "ok")) {
      shiny::showNotification(dg_scalar_chr(out$message, "Weighted layout generation failed."), type = if (identical(out$status, "unavailable")) "warning" else "error")
      return()
    }
    layout_revision(shiny::isolate(layout_revision()) + 1L)
    shiny::showNotification("Weighted GRIP layout cached.", type = "message")
  }, ignoreInit = TRUE)

  output$original_plot <- plotly::renderPlotly({
    st <- view_state()
    shiny::req(is.list(st), st$status %in% c("ok", "missing_layout", "layout_error"))
    dataset <- st$dataset
    shiny::req(is.list(dataset), identical(dataset$status, "ok"))
    coords <- dg_normalize_coord_matrix(dataset$coords)
    row <- st$selected_row
    title <- sprintf(
      "Original data: %s, n=%s, seed=%s",
      dg_scalar_chr(row$surface[[1]], dg_scalar_chr(row$dataset_id[[1]])),
      dg_scalar_chr(row$n[[1]]),
      dg_scalar_chr(row$seed[[1]])
    )
    plotly::layout(
      plotly::plot_ly(
        x = coords[, 1], y = coords[, 2], z = coords[, 3],
        type = "scatter3d", mode = "markers",
        text = sprintf("vertex=%d", seq_len(nrow(coords))),
        hoverinfo = "text",
        marker = list(size = 3.5, color = "#2563eb", opacity = 0.88)
      ),
      title = list(text = title, font = list(size = 13)),
      margin = list(l = 0, r = 0, b = 0, t = 34),
      scene = list(
        xaxis = list(title = "", showgrid = FALSE, zeroline = FALSE, visible = FALSE),
        yaxis = list(title = "", showgrid = FALSE, zeroline = FALSE, visible = FALSE),
        zaxis = list(title = "", showgrid = FALSE, zeroline = FALSE, visible = FALSE)
      )
    )
  })

  output$graph_plot <- plotly::renderPlotly({
    st <- view_state()
    shiny::req(is.list(st), identical(st$status, "ok"))
    coords <- dg_normalize_coord_matrix(st$layout_coords)
    adj <- st$graph$adj_list
    shiny::req(is.matrix(coords), is.list(adj), nrow(coords) == length(adj))
    edges <- dg_adj_edges(adj)
    if (is.matrix(edges) && nrow(edges) > 4000L) {
      set.seed(1L)
      edges <- edges[sort(sample.int(nrow(edges), 4000L)), , drop = FALSE]
    }
    edge_xyz <- matrix(NA_real_, nrow = 0L, ncol = 3L)
    if (is.matrix(edges) && nrow(edges) > 0L) {
      edge_xyz <- matrix(NA_real_, nrow = nrow(edges) * 3L, ncol = 3L)
      edge_xyz[seq(1L, nrow(edge_xyz), by = 3L), ] <- coords[edges[, 1], , drop = FALSE]
      edge_xyz[seq(2L, nrow(edge_xyz), by = 3L), ] <- coords[edges[, 2], , drop = FALSE]
    }
    row <- st$selected_row
    title <- "Weighted graph layout"
    p <- plotly::plot_ly()
    if (nrow(edge_xyz) > 0L) {
      p <- plotly::add_trace(
        p,
        x = edge_xyz[, 1], y = edge_xyz[, 2], z = edge_xyz[, 3],
        type = "scatter3d", mode = "lines", hoverinfo = "skip",
        line = list(color = "rgba(17,24,39,0.20)", width = 1),
        showlegend = FALSE
      )
    }
    p <- plotly::add_trace(
      p,
      x = coords[, 1], y = coords[, 2], z = coords[, 3],
      type = "scatter3d", mode = "markers",
      text = sprintf("vertex=%d", seq_len(nrow(coords))),
      hoverinfo = "text",
      marker = list(size = 3.5, color = "#0f766e", opacity = 0.9),
      showlegend = FALSE
    )
    plotly::layout(
      p,
      title = list(text = title, font = list(size = 13)),
      margin = list(l = 0, r = 0, b = 0, t = 34),
      scene = list(
        xaxis = list(title = "", showgrid = FALSE, zeroline = FALSE, visible = FALSE),
        yaxis = list(title = "", showgrid = FALSE, zeroline = FALSE, visible = FALSE),
        zaxis = list(title = "", showgrid = FALSE, zeroline = FALSE, visible = FALSE)
      )
    )
  })

  output$compare_view <- shiny::renderUI({
    st <- view_state()
    if (!is.list(st) || !identical(st$status, "ok")) {
      title <- switch(dg_scalar_chr(st$status, "error"),
        missing_graph = "Graph Asset Missing",
        missing_layout = "Weighted Layout Missing",
        layout_error = "Layout Error",
        "Graph Reconstruction Explorer"
      )
      return(shiny::div(class = "dg-empty", shiny::h3(title), shiny::p(dg_scalar_chr(st$message, "Load a run and select a graph."))))
    }
    shiny::div(
      class = "dg-main",
      shiny::div(class = "dg-heading", shiny::h3(dg_selection_summary(st$selection)), shiny::p(class = "dg-muted", sprintf("graph-stage key: %s | layout source: %s", st$key, st$layout_source))),
      shiny::div(
        class = "dg-plot-grid",
        shiny::div(class = "dg-plot-panel", plotly::plotlyOutput("original_plot", height = "58vh")),
        shiny::div(class = "dg-plot-panel", plotly::plotlyOutput("graph_plot", height = "58vh"))
      )
    )
  })

  output$metrics_view <- shiny::renderUI({
    st <- view_state()
    if (!is.list(st) || is.null(st$selected_row)) {
      return(shiny::div(class = "dg-empty", shiny::h3("Metrics"), shiny::p("Select a graph to inspect metrics.")))
    }
    shiny::div(
      class = "dg-main",
      shiny::h3("Selected Metrics"),
      dg_html_table(dg_metric_table(st$metrics), empty_text = "No metric rows found."),
      shiny::h3("Graph Diagnostics"),
      dg_html_table(st$diagnostics, empty_text = "No diagnostics found.")
    )
  })

  output$scan_view <- shiny::renderUI({
    run <- run_state()
    st <- view_state()
    if (!is.list(run) || !is.list(st) || is.null(st$selected_row)) {
      return(shiny::div(class = "dg-empty", shiny::h3("Parameter Scan"), shiny::p("Load a run and select a graph.")))
    }
    target <- if (is.list(st$selection) && is.data.frame(st$selection$optimal_metric)) dg_scalar_chr(st$selection$optimal_metric$target[[1]], "surface") else "surface"
    scan <- dg_parameter_scan(run, st$selected_row, target = target)
    keep <- intersect(
      c("target", "surface", "curvature_label", "domain_shape", "sampling_profile", "n", "seed", "graph_family", "k", "radius_rank", "k_scale", "radius_rule", "radius_factor", "delta", "prune_method", "rel_rms_error", "rel_geodesic_stress", "pearson_cor"),
      names(scan)
    )
    shiny::div(
      class = "dg-main",
      shiny::h3("Parameter Scan"),
      shiny::p(class = "dg-muted", "Rows are filtered to the selected dataset stratum and metric target."),
      dg_html_table(scan[, keep, drop = FALSE], empty_text = "No scan rows found.")
    )
  })
}
