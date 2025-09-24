
# This is a Shiny web application. The app connects to the models hosted on the HuggingFace server using the ellmer package 
# 'chat_huggingface()' and the HugginFace API. These models are hosted on the ollama server with sufficient GPU power to ensure 
# smooth performance. The API Key was created on the free plan. That’s why only smaller models (1.5B–3B parameters) are available, 
# and just two support text generation. The app provides a user-friendly interface for users to interact with the models.


# 1. Load packaged --------------------------------------------------------

library(shiny)
library(bslib)
library(glue)
library(here)
library(shinycssloaders)
library(shinyjs)
library(shinychat)
library(hover)


# 2. API KEY --------------------------------------------------------------

usethis::edit_r_environ()
readRenviron("~/.Renviron")
Sys.getenv("HUGGINGFACE_API_KEY")


# 2. Define system_prompt -------------------------------------------------

system_prompt <- "Du bist ein hilfsbereiter Schweizer Jurist und Assistent.
    Du beantwortest nur Fragen zum Strafrecht im Schweizer Rechtssystem.
    
    Wenn der Nutzer Fragen zu anderen Themen stellt, die sich nicht in irgendeiner Weise auf das strafrecht beziehen,
    antwortest du höflich, dass du nur Fragen zum Schweizer Strafrecht beantworten kannst. 
    
    Für jede Antwort verwendest du zuerst Informationen aus der für dich zur Verfügung gestellten Datenbank 
    (im **store** über ragnar_register_tool_retrieve()) mit Gerichtsentscheidungen.
    
    Falls du keine passenden Informationen in der Datenbank findest, gib dies bitte an. Danach darfst du mit deinen
    eigenen Informationen fortfahren, um die Frage zu beantworten.
    
    Du zitierst jedoch **niemals** direkt aus diesen, sondern formulierst alle Antworten **in deinen eigenen Worten**.
    Du lieferst Zusammenfassungen, Erklärungen und Interpretationen auf der Grundlage der Inhalte der Datenbank.
    
    Du nutzt die Urteile als Hintergrundwissen. Du verweist nicht direkt auf sie,
    es sei denn, der Nutzer bittet dich ausdrücklich darum.
    
    Wenn der Nutzer ein bestimmtes Urteil lesen möchte, kannst du ihm eines empfehlen, das zum Thema passt.
    Du verwendet **immer** die Sprache Deutsch, ausser der Nutzer möchte mir dir in einer anderen Sprache kommunizieren."


# 3. Define UI for application --------------------------------------------

ui <- page_sidebar(
  title = h4(strong("Swiss Criminal Law Assistant", 
                    style = "color: #A81843; 
                      font-family: Trebuchet MS, sans-serif;")),
  theme = bs_theme(
    bootswatch = "darkly",
    primary = "#A81843", # Main color for the app, so no overriding with CSS needed
    secondary = "#444"
  ), 
  sidebar = sidebar(
    style = "display:flex; 
                flex-direction:column; 
                min-height:100%;", # style is defined inside the sidebar, now the wellpanel() sticks to the bottom 
    
    
    useShinyjs(),
    use_hover(),
    
    hover_action_button(
      inputId = "modell",
      label = "Modell: HuggingFaceTB/SmolLM3-3B",
      icon = icon("robot"),
      icon_animation = NULL,
      button_animation = NULL,
      class = "btn btn-secondary",
      style = "color: white; background-color: #A81843; border-color: #A81843;",
      width = "100%"
    ),

    hover_action_button(
      inputId = "clear",
      label = "Chatverlauf löschen",
      icon = icon("eraser"),
      icon_animation = "",
      button_animation = "grow",
      class = "btn btn-secondary",
      style = "color: white; background-color: #A81843; border-color: #A81843;",
      width = "100%"
    ),
    
    wellPanel(
      style = "border-color:#A81843; 
                    border-radius:7px; 
                    border-width:2px; 
                    color:white; 
                    padding:3px; 
                    text-align:center; 
                    width:100%; 
                    font-size:10pt; 
                    margin-top:auto;",
      tags$strong("Hinweis:"),
      tags$span(" Keine Rechtsberatung")
    )
  ),
  
  # Main content layout
  div(
    style = "height: 91vh; 
                 display: flex; 
                 flex-direction: column;",
    div(
      style = "flex: 1; 
                    display: flex;
                    padding: 10px;
                    flex-direction: column;
                    justify-content: flex-end;
                    position:relative;",
      chat_ui("chat",
              messages = "Hallo! Ich bin dein Assistent für Schweizer Strafrecht. Wie kann ich dir heute helfen?",
              placeholder = "Schreibe hier deine Frage ..."),
      fill = TRUE,
      height = "auto"
      
      
      
    ),
    
    # Bottom input area
    div(
      style = "
                background: #222;
                padding: 4px;
                border-top: 1px solid #444;
                display: flex;
                align-items: center;      
                justify-content: center; 
                text-align: center;",
      tags$p(
        "Swiss Criminal Law Assistant kann Fehler machen. Bitte Antworten sorgfältig überprüfen.",
        style = "color: white; margin: 0; font-size:9pt;"
      )
    )
  )
)



# 4. Define server logic --------------------------------------------------

server <- function(input, output, session) {
  
  # Clear chat history when button is clicked
  observeEvent(input$clear, {
    chat_clear("chat")
    showNotification("Chat gelöscht", type = "message")
  })
  
  current_stream <- reactiveVal(NULL)  # Store the current stream
  chat_session <- reactiveVal(NULL)     # Store the chat session
  
  # Initialize chat session
    tryCatch({
      sess <- ellmer::chat_huggingface(
                          system_prompt = system_prompt,
                          model         = "HuggingFaceTB/SmolLM3-3B",    
                          api_key       = Sys.getenv("HUGGINGFACE_API_KEY"))

              #sess <- ragnar_register_tool_retrieve(sess, store, top_k = 3L)  
              chat_session(sess)
    },
    error = function(e) {
      showNotification("Bitte überprüfe deinen API-Schlüssel und die Verbindung zu HuggingFace", type = "error")
    })
  
  
  observeEvent(input$chat_user_input, {
    req(chat_session())
    
    # Retrieve context 
    context <- tryCatch(
      ragnar_retrieve(store, input$chat_user_input, top_k = 3L),
      error = function(e) character(0)
    )
    context_text <- if (length(context)) paste(context, collapse = "\n\n---\n\n") else ""
    
    # Building a single augmented user prompt 
    augmented <- if (nzchar(context_text)) {
      paste0(
        "Kontext (nicht zitieren, nur als Hintergrundwissen verwenden):\n",
        context_text,
        "\n\nFrage:\n", input$chat_user_input
      )
    } else {
      input$chat_user_input
    }
    
    # Stream 
    stream <- chat_session()$stream_async(augmented)
    current_stream(stream)
    
    chat_append("chat", stream)$catch(function(e) {
      chat_append("chat", "Entschuldigung, ein Fehler ist aufgetreten.")
    })
  })
  
}

# Run the application 
shinyApp(ui = ui, server = server)





