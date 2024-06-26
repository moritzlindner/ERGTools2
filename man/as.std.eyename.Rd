% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/INT_as.std.X.R
\name{as.std.eyename}
\alias{as.std.eyename}
\alias{eye.haystack}
\alias{od_str}
\alias{os_str}
\title{Convert eye identifier strings to standard notation}
\usage{
as.std.eyename(eye_str, exact = T, warn.only = F)

eye.haystack()

od_str()

os_str()
}
\arguments{
\item{eye_str}{Character vector of eye identifier strings.}

\item{exact}{If \code{TRUE}: Require exact match. If \code{FALSE}: Whole word match is sufficient.}

\item{warn.only}{Invalid eye identifier strings will only cause a warning, not an error.}
}
\value{
A character vector with standardized eye identifiers ('RE' for right eye, 'LE' for left eye).
}
\description{
Convert eye identifier strings to standard notation
}
\section{Functions}{
\itemize{
\item \code{eye.haystack()}: Get standard eye identifier strings

\item \code{od_str()}: Get standard right eye identifier strings

\item \code{os_str()}: Get standard left eye identifier strings

}}
\examples{
as.std.eyename(c("RE", "OD", "OS", "Right"))
\dontrun{
eye.haystack()
}#'
\dontrun{
od_str()
}
\dontrun{
os_str()
}
}
\keyword{internal}
