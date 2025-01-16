library(shiny)
library(bslib)
library(DT)
library(tidyverse)
library(ospsuite)
library(plotly)

options(
  shiny.maxRequestSize = 30 * 1024^2,
  shiny.host = "0.0.0.0",
  shiny.port = 8180
  )

# Shiny app that loads a pkml file and displays its parameter in a table
ui <- page_navbar(
  title = "OSPSuite Shiny App",
  sidebar = sidebar(
    title = span(icon("file-import"), " Inputs"),
    fileInput("file", "Select a .pkml simulation", accept = ".pkml"),
    br(),
    strong("Simulation Name"),
    verbatimTextOutput("simulationName")
  ),
  nav_spacer(),
  nav_panel(
    "Simulation Paths",
    icon = icon("timeline"),
    card(
      card_header(popover(
        HTML(paste0("<font color='dodgerblue'>", icon("info-circle"), " Simulation Paths Selection</font>")),
        HTML(paste(
          "After loading the simulation,",
          "paths selected in the <strong>Simulation Paths</strong> table",
          "are simulated in <strong>Time Profile</strong> and <strong>PK Parameters</strong> tabs"
        ))
      )),
      DTOutput("tablePaths")
    )
  ),
  nav_panel(
    "Time Profile",
    icon = icon("chart-line"),
    card(plotlyOutput("timeProfile"))
  ),
  nav_panel(
    "PK Parameters",
    icon = icon("chart-pie"),
    card(DTOutput("pkData"))
  )
)

server <- function(input, output, session) {
  # Reactive values ----
  toStore <- reactiveValues(simulation = NULL, simulationPaths = NULL)
  getSelectedPaths <- reactive({
    if (is.null(toStore$simulationPaths)) {
      return()
    }
    if (is.null(input$tablePaths_rows_selected)) {
      return()
    }
    toStore$simulationPaths[input$tablePaths_rows_selected]
  })
  getSimulationResults <- reactive({
    if (is.null(getSelectedPaths())) {
      return()
    }
    clearOutputs(toStore$simulation)
    addOutputs(getSelectedPaths(), toStore$simulation)
    simulationResults <- runSimulations(simulations = toStore$simulation)
    simulationResults <- simulationResults[[toStore$simulation$id]]
    return(simulationResults)
  })
  getSimulationData <- reactive({
    simulationResults <- getSimulationResults()
    if (is.null(simulationResults)) {
      return()
    }
    simulationData <- simulationResultsToTibble(simulationResults)
    return(simulationData)
  })
  getPKParameters <- reactive({
    simulationResults <- getSimulationResults()
    if (is.null(simulationResults)) {
      return()
    }
    pkAnalysis <- calculatePKAnalyses(results = simulationResults)
    pkData <- pkAnalysesToTibble(pkAnalysis)
    return(pkData)
  })

  observeEvent(input$file, {
    toStore$simulation <- loadSimulation(input$file$datapath)
    toStore$simulationPaths <- getAllObserverPathsIn(toStore$simulation)
  })

  output$simulationName <- renderText({
    toStore$simulation$name
  })

  output$pkData <- renderDT({
    pkData <- getPKParameters()
    if (is.null(pkData)) {
      return(data.frame())
    }
    DT::datatable(pkData, rownames = FALSE)
  })

  output$tablePaths <- renderDT({
    paths <- toStore$simulationPaths
    if (is.null(paths)) {
      return(data.frame())
    }
    firstElement <- sapply(
      toStore$simulationPaths,
      function(path) {
        head(toPathArray(path), 1)
      }
    )
    lastElement <- sapply(
      toStore$simulationPaths,
      function(path) {
        tail(toPathArray(path), 1)
      }
    )
    pathTable <- data.frame(
      "First Element" = firstElement,
      "Last Element" = lastElement,
      "Path" = toStore$simulationPaths,
      check.names = FALSE
    )

    datatable(pathTable, rownames = FALSE)
  })

  output$timeProfile <- renderPlotly({
    simulationData <- getSimulationData()
    if (is.null(simulationData)) {
      return()
    }
    xLabel <- paste0("Time [", head(simulationData$TimeUnit, 1), "]")
    yLabel <- paste0(
      head(simulationData$paths, 1), " [",
      head(simulationData$unit, 1), "]"
    )

    p <- ggplot(
      simulationData,
      aes(x = Time, y = simulationValues, color = paths)
    ) +
      theme_bw() +
      theme(legend.position = "top") +
      geom_line() +
      scale_color_viridis_d() +
      labs(x = xLabel, y = yLabel)

    ggplotly(p, dynamicTicks = TRUE) |> layout(legend = list(x = 0, y = 100))
  })

  session$onSessionEnded(function() {
    stopApp()
  })
}

shinyApp(ui, server)
