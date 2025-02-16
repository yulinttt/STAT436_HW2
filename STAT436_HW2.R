library(rsconnect)
library(shiny)
library(ggplot2)
library(plotly)
library(tidyverse)
library(lubridate)
library(dplyr)
library(DT)
library(rsconnect)
rsconnect::setAccountInfo(name='yulint0', token='8384799C39990841C799B619CB7634C9', secret='TX04n6ylKR1arGM8Aufib/4GkepRnF6nnOiEyEaZ')
rsconnect::deployApp('STAT436_HW2.Rmd')


book_df <- read_csv("https://raw.githubusercontent.com/yulinttt/STAT436_HW2/refs/heads/main/data/Books_Data_Clean.csv") %>%
  select(
    "Book Name", "Author", 
    "Year" = "Publishing Year", 
    "Language" = "language_code", 
    "Book_Rating" = "Book_average_rating", 
    "Genre" = "genre", 
    "Units_Sold" = "units sold", 
    "Sale_Price" = "sale price", 
    "Sales_Rank" = "sales rank", 
    "Publisher"
  ) %>%
  drop_na(`Book Name`) %>%
  filter(Year >= 1750) %>%
  mutate(
    Genre = ifelse(Genre == "fiction", "literary fiction", Genre),
    Language = fct_explicit_na(Language),
    Genre = fct_explicit_na(Genre)
  )

# Sort languages by frequency and categorize into 'en' and others
language_freq <- book_df %>%
  group_by(Language) %>%
  summarise(count = n()) %>%
  arrange(desc(count))

en_languages <- language_freq %>%
  filter(grepl("^en", Language))

other_languages <- language_freq %>%
  filter(!grepl("^en", Language) & Language != "(Missing)")

missing_language <- language_freq %>%
  filter(Language == "(Missing)")

# Reorder languages: 'en' first, others next, and missing last
sorted_languages <- c(en_languages$Language, other_languages$Language, missing_language$Language)

# Extract unique values for genres and languages
languages <- pull(book_df, Language) %>%
  unique() %>%
  na.omit()

genres <- pull(book_df, Genre) %>%
  unique() %>%
  na.omit()

book_df <- book_df %>%
  mutate(Language = factor(Language, levels = sorted_languages))

# Function to generate a scatter plot of Book Ratings vs Units Sold
scatter <- function(df) {
  ggplot(df) +
    geom_point(aes(Book_Rating, Units_Sold, color = factor(is_filtered, levels = c(FALSE, TRUE)))) +
    scale_color_manual(
      values = c("#d4d4d4", "black"), 
      labels = c("Not Selected", "Selected")
    ) +
    guides(color = guide_legend(title = NULL)) +
    labs(x = "Book Rating", y = "Units Sold") +
    theme(legend.position = "bottom")
}



ui <- fluidPage(
  titlePanel("Books Sales & Ratings Dashboard"),
  
  # Create a row with filters on the left and scatter plot + table on the right
  fluidRow(
    column(3,  
           wellPanel(
             # Filters for Genre, Year, and Language
             selectInput("genres", "Select Genre", genres),
             sliderInput("year", "Select Year Range",
                         min = min(book_df$Year), max = max(book_df$Year), 
                         value = c(min(book_df$Year), max(book_df$Year)), sep = ""),
             checkboxGroupInput("language", "Select Language", sorted_languages, sorted_languages),
             
             # Add note at the bottom of the wellPanel
             p("Note: The brush will be reset whenever you change any selection.", 
               style = "color: gray; font-style: italic;")
           ),
           style = "background-color: #f7f7f7; padding: 15px; border-radius: 5px;"  # Style the grey panel
    ),
    column(9,  # Right side: scatter plot and table vertically aligned
           plotOutput("ratings_scatter", brush = "scatter_brush"),
           DTOutput("table")
    )
  )
)


server <- function(input, output, session) {
  
  selected_brushed <- reactiveVal(NULL)
  
  # Reactive to filter the dataset based on user input
  book_subset <- reactive({
    # Every time the filter changes, reset brushed points to NULL and reset the brush box
    selected_brushed(NULL)
    session$resetBrush("scatter_brush") 
    
    book_df %>%
      mutate(is_filtered = Genre %in% input$genres & 
               Language %in% input$language & 
               Year >= input$year[1] & 
               Year <= input$year[2])
  })
  
  # Observe brushing events and update the selected points based on filtered data
  observeEvent(input$scatter_brush, {
    brushed_points <- brushedPoints(book_subset() %>% filter(is_filtered), input$scatter_brush, allRows = TRUE)
    selected_brushed(brushed_points$selected_)
  })
  
  # Render the scatter plot
  output$ratings_scatter <- renderPlot({
    scatter(book_subset())
  })
  
  # Render the table
  output$table <- renderDT({
    filtered_data <- book_subset() %>% filter(is_filtered)
    if (is.null(selected_brushed())) {
      filtered_data
    } else {
      filtered_data %>% filter(selected_brushed())
    }
  })
}


shinyApp(ui, server)
