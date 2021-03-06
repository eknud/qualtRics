% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getSurveys.R
\name{getSurveys}
\alias{getSurveys}
\title{Retrieve a list of all active surveys that you own on qualtrics}
\usage{
getSurveys(root_url = "https://yourdatacenterid.qualtrics.com")
}
\arguments{
\item{root_url}{Base url for your institution (see \url{https://api.qualtrics.com/docs/root-url}. If you do not fill in anything, the function will use the default url. Using your institution-specific url can significantly speed up queries.)}
}
\description{
Retrieve a list of all active surveys that you own on qualtrics
}
\examples{
\dontrun{
registerApiKey("<YOUR-QUALTRICS-API-KEY>")
surveys <- getSurveys("https://leidenuniv.eu.qualtrics.com")
                      # URL is for my own institution.
                      # Substitute with your own institution's url
mysurvey <- getSurvey(surveys$id[6],
                      format = "csv",
                      save_dir = tempdir(),
                      "https://leidenuniv.eu.qualtrics.com",
                      verbose=TRUE)
}
}
\author{
Jasper Ginn
}
\seealso{
See \url{https://api.qualtrics.com/docs} for documentation on the Qualtrics API.
}

