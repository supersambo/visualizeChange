library(shiny)
library(shinyBS)
library(plyr)
library(rCharts)
load("db.RData")
infoText <- readLines(con="inforeadme.html")

ui = fluidPage(
    includeCSS("style.css"),

    mainPanel(width=11,
    fluidRow(align="right",  
             tags$a(href = "https://twitter.com/supersambo", icon("twitter","fa-2x")),
             tags$a(href = "http://github.com/supersambo", icon("github","fa-2x")),
             tags$a(href = "mailto:stephan@schloegl.net", icon("envelope","fa-2x"))
             ),

    titlePanel("#VisualizeChange"),
              fluidRow(column(2, textInput(inputId = "searchTerm", label = "")),
                       column(2,align="left",br(), actionButton("searchButton", "Search"))),
                       actionLink("reset", "Reset"),
                       br(),br(),

    fluidRow(column(8, radioButtons(inputId = "facetCat", label = "Group documents by origin:",choices=c("All"="All","National Context"="National.Context", "Public Input"="Public.Input", "Regional Context"="Regional.Context", "Stakeholder Group"="Stakeholder.Group", "WHS Output"="WHS.Output"), selected="Stakeholder.Group", inline=TRUE)),
             column(4, align="right", br(),actionLink("info", icon("info-circle", "fa-3x")))),

    tags$hr(),
    htmlOutput("hover"),
    plotOutput("plot1", height = "1px"),
    showOutput("chart", "highcharts"),
    br(),

    bsCollapse(id="QuotPanel",
    bsCollapsePanel("Quotations", 
    htmlOutput("quotations")))
    ),

    bsModal(id="description", "Info", "info", size = "large",HTML(infoText))


)

server = function(input, output, session) {


    d <- reactiveValues(quoteTable=db, dataTable = data.frame(), labs= data.frame(), quotes="", selection=vector())

    observeEvent(input$reset, {
        updateCollapse(session, "QuotPanel", close = "Quotations")
        updateTextInput(session, "searchTerm", value = "")
            })

    observeEvent(c(input$facetCat,input$searchButton),{
        updateCollapse(session, "QuotPanel", close = "Quotations")
        if(input$searchTerm==""){d$quoteTable <- db}
        else{d$quoteTable <- subset(db, grepl(input$searchTerm, citations, ignore.case=TRUE))
             d$quoteTable$citations <- gsub(paste("(", input$searchTerm, ")", sep="") ,"<b>\\1</b>",d$quoteTable$citations, ignore.case=TRUE)

        }
        cdb <- d$quoteTable[!is.na(d$quoteTable[[input$facetCat]]), ]
        cdb <- arrange(count(cdb, c(input$facetCat,"category_label", "code_id", "js_color")), code_id, decreasing=TRUE)
        cdb <- subset(cdb, !is.na(category_label))
        cdb$x <- xAxs$numeric_codeid[match(cdb$code_id, xAxs$code_id)]
        cdb$y <- yAxs[[input$facetCat]]$numeric_id[match(cdb[,input$facetCat], yAxs[[input$facetCat]]$doctype)]
        d$dataTable <- cdb

        d$quoteTable$x <- cdb$x[match(d$quoteTable$code_id, cdb$code_id)]
        d$quoteTable$y <- cdb$y[match(d$quoteTable[, input$facetCat], cdb[ ,input$facetCat])]

        d$labs <- arrange(subset(cdb, !duplicated(y)), y)
        })


    observeEvent(input$click,{
                     d$quotes <- subset(d$quoteTable, x==input$click$x & y==input$click$y)
                     if(length(input$click$selected)==0){updateCollapse(session, "QuotPanel", open = "Quotations")}
                     else if(!input$click$selected){updateCollapse(session, "QuotPanel", open = "Quotations")}
                     else if(input$click$selected){updateCollapse(session, "QuotPanel", close = "Quotations")}
                })

    output$text <- renderText({unlist(subset(d$dataTable, x==input$click$x & y==input$click$y)[, c(input$facetCat, "code_id")])})
    output$hover <- renderText({
        if(length(input$hover)==0){"<br><br>"}
        else{paste("&nbsp;&nbsp;&nbsp;<b>",xAxs[xAxs$numeric_codeid==input$hover$x,"category_id"] ,"&nbsp;",xAxs[xAxs$numeric_codeid==input$hover$x,"category_short"], "</b>&nbsp;-&nbsp;",xAxs[xAxs$numeric_codeid==input$hover$x,"category_label"],
                   "<br>", 
                   "&nbsp;&nbsp;&nbsp;<b>",xAxs[xAxs$numeric_codeid==input$hover$x,"code_suffix"], "</b>&nbsp;-&nbsp;",xAxs[xAxs$numeric_codeid==input$hover$x,"code_label"],
                   sep="")}})
    output$quotations <- renderUI({
        d$quotes$citations <- str_replace_all(d$quotes$citations, "\n", "<br>")
        HTML(paste(d$quotes$citations,"<br><br><div align=\"right\" padding=\"0px\"><font size=\"0.5\", color=\"grey\">",d$quotes$document," - ", d$quotes$pages,"</font></div>",  "<hr>"))})


    output$chart <- renderChart2({
        p <- hPlot(y~x, data = d$dataTable, type = 'bubble', size='freq',group = 'category_label', radius = 6)
        p$colors(list(unique(arrange(d$dataTable, code_id)$js_color)))
        p$chart(backgroundColor='transparent', zoomType='xy')
        p$legend(align = 'center', verticalAlign = 'bottom', layout = 'horizontal', itemDistance=20, itemStyle=list(color="#F2F2F2"), itemHoverStyle="#4A4D4D")
        p$plotOptions(bubble = list(allowPointSelect='true',
                                    marker=list(states=list(select=list(lineWidth=3, fillColor='transparent', lineColor=NULL))),
                                    maxSize='12%', 
                                    minSize="4", 
                                    events = list(click="#! function(event) {Shiny.onInputChange('click', {x: event.point.x, y: event.point.y, selected: event.point.selected})} !#", 
                                    legendItemClick="#! function(){return false} !#")))
        p$tooltip(formatter = "#! function() {Shiny.onInputChange('hover', {x: this.point.x, y: this.point.y});return this.point.z + ' Quote(s)'} !#", crosshairs=list('true','true'))
        p$xAxis(categories=c(0,xAxs$code_id), 
                min=min(xAxs$numeric_codeid),
                max=max(xAxs$numeric_codeid), 
                tickColor='#000',
                tickWidth='0.2', 
                lineColor='#000', 
                lineWidth='0.2')
        p$yAxis(categories=c(0,yAxs[[input$facetCat]]$doctype), min=min(yAxs[[input$facetCat]]$numeric_id), max=max(yAxs[[input$facetCat]]$numeric_id),title= list(text=gsub("[.]", " ", input$facetCat)),gridLineColor='#000',gridLineWidth='0.2',minorGridLineWidth='0.2', opposite='true')

        p$params$height = '700'
        p$addParams(dom = "chart")
        return(p)
        })
    }

shinyApp(ui = ui, server = server)

