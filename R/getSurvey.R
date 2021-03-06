#   Download qualtrics data into R
#    Copyright (C) 2016 Jasper Ginn

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#' Export a survey and download into R
#'
#' Export a qualtrics survey you own and import the survey directly into R. NOTE: If you keep getting errors try to use your institution's base URL. See \url{https://api.qualtrics.com/docs/root-url}.
#'
#' @param surveyID Unique ID for the survey you want to download. Returned as 'id' by the \link[qualtRics]{getSurveys} function.
#' @param root_url Base url for your institution (see \url{https://api.qualtrics.com/docs/csv}. You need to supply this url. Your query will NOT work without it.)
#' @param format Type of file that will be downloaded. CSV will return a data frame, JSON and XML will return a list. SPSS is currently not supported. Defaults to CSV.
#' @param useLabels TRUE to export survey responses as Choice Text or FALSE to export survey responses as values
#' @param lastResponseId Export all responses received after the specified response
#' @param save_dir Directory where survey results will be stored. Defaults to a temporary directory which is cleaned when your R session is terminated. This parameter is useful if you'd like to store survey results.
#' @param verbose Print verbose messages to the R console? Defaults to FALSE
#'
#' @seealso See \url{https://api.qualtrics.com/docs/csv} for documentation on the Qualtrics API.
#' @author Jasper Ginn
#' @importFrom httr GET
#' @importFrom httr POST
#' @importFrom httr content
#' @importFrom stringr str_sub
#' @importFrom utils read.csv
#' @importFrom utils unzip
#' @importFrom jsonlite fromJSON
#' @importFrom XML xmlParse
#' @importFrom XML xmlToList
#' @export
#' @examples
#' \dontrun{
#' registerApiKey("<YOUR-QUALTRICS-API-KEY>")
#' surveys <- getSurveys("https://leidenuniv.eu.qualtrics.com")
#'                       # URL is for my own institution.
#'                       # Substitute with your own institution's url
#' mysurvey <- getSurvey(surveys$id[6],
#'                       format = "csv",
#'                       save_dir = tempdir(),
#'                       "https://leidenuniv.eu.qualtrics.com",
#'                       verbose=TRUE)
#' }

getSurvey <- function(surveyID,
                      root_url,
                      format = c("csv", "json", "xml", "spss"),
                      useLabels = TRUE,
                      lastResponseId=NULL,
                      startDate=NULL,
                      endDate=NULL,
                      save_dir = tempdir(),
                      verbose = FALSE) {

  # Match arg
  format <- match.arg(format)
  # Stop if SPSS
  if(format == "spss") {
    stop("SPSS files are currently not supported.")
  }

  # Check if save_dir exists
  if(!file.info(save_dir)$isdir | is.na(file.info(save_dir)$isdir)) stop(paste0("The directory ", save_dir, " does not exist."))

  # Look in temporary directory. If file 'qualtRics_header.rds' does not exist, then abort and tell user to register API key first
  f <- list.files(tempdir())
  if(!"qualtRics_header.rds" %in% f) stop("You need to register your qualtrics API key first using the 'registerApiKey()' function.")
  # Read headers information
  headers <- readRDS(paste0(tempdir(), "/qualtRics_header.rds"))
  # Function-specific API stuff
  root_url <- paste0(root_url,
                           ifelse(substr(root_url, nchar(root_url), nchar(root_url)) == "/",
                                  "API/v3/responseexports/",
                                  "/API/v3/responseexports/"))
  # Create raw JSON payload
  raw_payload <- paste0(
    '{"format": ', '"', format, '"' ,
    ', "surveyId": ', '"', surveyID,
    ifelse(
      is.null(lastResponseId),
      "",
      paste0('"' ,
        ', "lastResponseId": ',
        '"',
        lastResponseId)
    ) ,
    ifelse(
      is.null(startDate),
      "",
      paste0('"' ,
        ', "startDate": ',
        '"',
          paste0(startDate,"T00:00:00Z"))
    ) ,
    ifelse(
      is.null(endDate),
      "",
      paste0('"' ,
        ', "endDate": ',
        '"',
          paste0(endDate,"T00:00:00Z"))
    ) , '", ',
    '"useLabels": ', tolower(useLabels),
    '}'
  )


  # POST request for download
  res <- POST(root_url,
              add_headers(
                headers
              ),
              body = raw_payload
  )
  # Check response type
  cnt <- qualtRicsResponseCodes(res)
  # Check if OK
  if(cnt$OK) {
    cnt <- cnt$content
  } else {
    # Else is (temporary) internal server error
    return(cnt$content)
  }
  # Get id
  ID = cnt$result$id
  # Create a progress bar and monitor when export is ready
  if(verbose) {
    pbar <- utils::txtProgressBar(min=0,
                                  max=100,
                                  style = 3)
  }
  # This is the url to use when checking the ID
  check_url <- paste0(root_url, ID)
  # While download is in progress
  progress <- 0
  while(progress < 100) {
    # Get percentage complete
    CU <- GET(check_url, add_headers(headers))
    progress <- content(CU)$result$percentComplete
    # Set progress
    if(verbose) {
      utils::setTxtProgressBar(pbar, progress)
    }
  }
  # Kill progress bar
  if(verbose) {
    close(pbar)
  }
  # Download file
  f <- tryCatch({
    GET(paste0(check_url, "/file"), add_headers(headers))
  }, error = function(e) {
    # Retry if first attempt fails
    GET(paste0(check_url, "/file"), add_headers(headers))
  })
  # Load raw zip file
  ty <- content(f, "raw")
  # To zip file
  tf <- paste0(save_dir,
               ifelse(substr(save_dir, nchar(save_dir), nchar(save_dir)) == "/",
                      "temp.zip",
                      "/temp.zip"))
  # Write to temporary file
  writeBin(ty, tf)
  # Take snapshot
  SS <- list.files(save_dir)
  u <- tryCatch({
    unzip(tf, exdir = save_dir)
  }, error = function(e) {
    stop(paste0("Error extracting ", format, " from zip file."))
  })
  # Read data
  if(format == "csv") {
    # Return minus first row
    data <- read.csv(u, header=TRUE, skip = 1, stringsAsFactors = FALSE)[-1,]
  } else if(format == "json") {
    data <- fromJSON(u, simplifyDataFrame = FALSE)
  } else if(format == "xml") {
    xmlData <- xmlParse(u)
    data <- xmlToList(xmlData)
  } else {
    stop("SPSS files are currently not supported.")
  }
  # Remove tmpfiles
  if(save_dir != tempdir()) {
    p<- file.remove(tf)
    return(data)
  } else {
    p <- file.remove(tf) ; p<- file.remove(u)
    # Return
    return(data)
  }
}
