# Graph explorer component, migrated from dggraphui.
# Copyright Pawel Gajer. License: GPL (>= 3).
dg_app_ui <- function(default_run_dir = "") {
  css_path <- system.file("shiny/graph-explorer/www/styles.css", package = "dgraphs")
  theme <- bslib::bs_theme(
    version = 5,
    base_font = "system-ui, sans-serif",
    heading_font = "Georgia, serif",
    code_font = "monospace",
    bg = "#f7f5ef",
    fg = "#17252a",
    primary = "#0f766e",
    secondary = "#8b5cf6",
    success = "#15803d",
    warning = "#b45309",
    danger = "#b91c1c",
    "border-radius" = "0.55rem",
    "btn-border-radius" = "999px",
    "card-border-radius" = "0.55rem"
  )

  bslib::page_sidebar(
    title = shiny::div(
      class = "dg-appbar",
      shiny::div(class = "dg-brand", "Graph Reconstruction Explorer"),
      shiny::uiOutput("run_chip")
    ),
    class = "dg-root",
    theme = theme,
    sidebar = bslib::sidebar(
      class = "dg-sidebar",
      width = 420,
      shiny::div(
        class = "dg-panel",
        shiny::h4("Open Project"),
        shiny::selectInput("saved_project", "Saved projects", choices = c("Choose a project" = "", stats::setNames(.graph_project_catalog()$path, .graph_project_catalog()$name))),
        shiny::textInput("run_dir", NULL, value = default_run_dir, placeholder = "/path/to/benchmark/runs/full"),
        shiny::actionButton("load_run", "Open", class = "btn-primary dg-wide"),
        shiny::textInput("project_name", "Remember as", placeholder = "A name for this project"),
        shiny::actionButton("remember_project", "Remember Project"),
        shiny::p(class = "dg-muted", "Saved results open without refitting. Files stay in their existing directory.")
      ),
      shiny::uiOutput("selector_panel"),
      shiny::uiOutput("asset_panel")
    ),
    if (nzchar(css_path)) shiny::tags$head(shiny::includeCSS(css_path)),
    bslib::navset_tab(
      id = "main_tab",
      bslib::nav_panel("3D Compare", shiny::uiOutput("compare_view")),
      bslib::nav_panel("Metrics", shiny::uiOutput("metrics_view")),
      bslib::nav_panel("Parameter Scan", shiny::uiOutput("scan_view"))
    )
  )
}
