#' @importFrom EPhysData Rejected FilterFunction AverageFunction
#' @importFrom stats var
validERGExam <- function(object) {

  # Check if the metadata has the required columns and are of correct format
  required_columns <- c("Step", "Eye", "Channel","Result")
  if (!all(required_columns %in% names(object@Metadata))) {
    stop(
      "Metadata provided is not in correct format. Must be a data.frame with the columns 'Step', 'Eye', 'Channel', and 'Result'."
    )
  }
  if (!(any(c("integer","numeric") %in% class(object@Metadata$Step))) ||
      !(any(c("integer","numeric") %in% class(object@Metadata$Result)))) {
    stop(
      "Metadata columns 'Step' and 'Result' must be of class 'integer'. They are: '",
      class(object@Metadata$Step),
      "' and '",
      class(object@Metadata$Result),
      "', respectivley."
    )
  }
  if (!("character" %in% class(object@Metadata$Channel)) ||
      !("character" %in% class(object@Metadata$Eye))) {
    stop(
      "Metadata columns 'Channel' and 'Eye' must be of class 'character'. They are: '",
      class(object@Metadata$Step),
      "' and '",
      class(object@Metadata$Result),
      "', respectivley."
    )
  }

  if(any(is.na(object@Metadata[,c("Step", "Eye", "Channel","Result")]))){
    warning(
      "The essential columns of the Metadata slot ('Step', 'Eye', 'Channel','Result') should not contain missing values. Check using 'Metadata()' to ensure downstream methods won't fail."
    )
  }

  if (any(
    colnames(object@Metadata) %in% c(
      "Description",
      "Intensity",
      "Background",
      "Type",
      "Name",
      "ChannelBinding",
      "Relative",
      "Time"
    )
  )) {
    warning("'Description', 'Intensity', 'Background', 'Type', 'Name', 'ChannelBinding', 'Relative', and 'Time' are reserved column names and should not be used as extra column names in 'Metadata'." )
  }

  # Check if Eye entries valid
  if (!all(unique(object@Metadata$Eye) %in% eye.haystack())) {
    stop("Eye identifiers must be any of the values returned by 'eye.haystack()'.")
  }

  # Rejected (inEPhysRaw) - must be the same across all channels within one eye
  for (s in unique(object@Metadata$Step)) {
    for (e in unique(object@Metadata$Eye[object@Metadata$Step == s])) {
      for (r in unique(object@Metadata$Result[object@Metadata$Step == s &
                                              object@Metadata$Eye == e])) {
        ids.equal <-
          object@Metadata$Step == s & object@Metadata$Eye == e & object@Metadata$Result == r
        feature.list <- lapply(object@Data[ids.equal], Rejected)
        if (length(unique(unlist(lapply(feature.list,length))))!=1){
          stop(paste0("Step '", s, "', Eye '", e, "', Result ,'", r, "': Unequal amount of recordings for the different channels."))
        }
        feature.df <- tryCatch(
          as.data.frame(do.call(cbind, feature.list)),
          error = function(er) {
            stop(
              paste0(
                "Step '",
                s,
                "', Eye '",
                e,
                "', Result ,'",
                r,
                "': 'Rejected' slots are filled with vectors of unequal length in step ."
              )
            )
          }
        )
        if (!all(apply(feature.df, 1, function(x) {
          if (length(x) > 1) {
            var(x) == 0
          } else{
            TRUE
          }
        }))) {
          warnings("'Rejected' vectors are not identical across channels in step ",
                   s,
                   " eye ",
                   e,
                   ".")
        }
      }
    }
  }

  # filter.fx (inEPhysRaw) - must be the same across all eyes within one channel and step
  for (s in unique(object@Metadata$Step)) {
    for (c in unique(object@Metadata$Channel[object@Metadata$Step == s])) {
      ids.equal <-
        which(object@Metadata$Step == s &
                object@Metadata$Channel == c)
      feature.list <-
        lapply(object@Data[ids.equal], function(x) {
          deparse1(FilterFunction(x))
        })
      feature.df <- tryCatch(
        as.data.frame(do.call(cbind, feature.list)),
        error = function(e) {
          stop(
            "'filter.fx' slots are filled with vectors of unequal length in step ",
            s,
            "channel",
            c,
            "."
          )
        }
      )
      if (!all(apply(feature.df, 1, function(x) {
        length(unique(x)) == 1
      }))) {
        stop(
          "'filter.fx' vectors are not identical across both eyes in step ",
          s,
          "channel",
          c,
          "."
        )
      }
    }
  }

  # average.fx (inEPhysRaw) - must be the same across all eyes within one channel and step
  for (s in unique(object@Metadata$Step)) {
    for (c in unique(object@Metadata$Channel[object@Metadata$Step == s])) {
      ids.equal <-
        which(object@Metadata$Step == s &
                object@Metadata$Channel == c)
      feature.list <-
        lapply(object@Data[ids.equal], function(x) {
          deparse1(AverageFunction(x))
        })
      feature.df <- tryCatch(
        as.data.frame(do.call(cbind, feature.list)),
        error = function(e) {
          stop(
            "'average.fx' slots are filled with vectors of unequal length in step ",
            s,
            "channel",
            c,
            "."
          )
        }
      )
      if (!all(apply(feature.df, 1, function(x) {
        length(unique(x)) == 1
      }))) {
        stop(
          "'average.fx' vectors are not identical across both eyes in step ",
          s,
          "channel",
          c,
          "."
        )
      }
    }
  }

  # Averaged slot
  if (object@Averaged){
    Trials<-unique(unlist(lapply(object@Data,function(x){dim(x)[2]})))
    if(length(Trials)!=1 || Trials != 1){
      message("Object does not appear to contain averaged data. Multiple repeats observed. This message is likely irrelevant, as the 'Averaged' is obsolete.")
    }
  }

  # Measurements slot
  if (length(object@Measurements) != 0) {
    if (any(!("ERGMeasurements" %in% class(object@Measurements)),
            !validObject(object@Measurements))) {
      stop("'Measurements' slot must contain a valid ERGMeasurements object.")
    }

    # check if ChannelBinding matches Channel of Recording
    measurements<-Measurements(object@Measurements)
    for (r in unique(measurements$Recording)){
      cb<-unique(measurements$ChannelBinding[measurements$Recording ==r])
      if(length(cb)>1){
        stop("Measurements object malformed: multiple Channel Bindings for a single recording.")
      }
      if (Metadata(object)$Channel[r]!=cb){
        stop("ChannelBinding stored in Measurements slot does not match the channel of the respective recoding as stored in the parent object. Error orcurred for recording #", r,".")
      }
    }
  }

  # Stimulus slot
  if (!all(object@Stimulus$Step %in% unique(Metadata(object)$Step))) {
    stop("All stimuli described must correspond to a Step as defined in 'Metadata'.")
  }

  if (any(is.na(object@Stimulus[, c("Step", "Description", "Intensity", "Background", "Type")]))) {
    warning(
      "The essential columns of the Stimulus slot ('Step', 'Description', 'Intensity','Background'),'Type' should not contain missing values. Use 'Stimulus()' to check and adjust manually to ensure downstream methods won't fail."
    )
  }

  if (any(
    colnames(object@Stimulus) %in% c(
      "Channel",
      "Result",
      "Eye",
      "Name",
      "ChannelBinding",
      "Relative",
      "Time"
    )
  )) {
    warning("'Channel', 'Result','Eye', 'Type', 'Name', 'ChannelBinding', 'Relative', and 'Time' are reserved column names and should not be used as extra column names in 'Stimulus'." )
  }

  if (!("integer" %in% class(object@Stimulus$Step)) ||
      !(any(c("numeric","integer") %in% class(object@Stimulus$Intensity)))) {
    stop(
      "Stimulus slot columns 'Step' and 'Intensity' must be of class 'integer' and 'numeric' or 'integer', respectivley. They are: '",
      class(object@Stimulus$Step),
      "' and '",
      class(object@Stimulus$Intensity),
      "'."
    )
  }

  if (!("character" %in% class(object@Stimulus$Description)) ||
      !("character" %in% class(object@Stimulus$Background)) ||
    !("character" %in% class(object@Stimulus$Type))) {
    stop(
      "Stimulus slot columns 'Description', 'Background' and 'Type' must be of class 'character'. They are: '",
      class(object@Stimulus$Description),
      "', '",
      class(object@Stimulus$Background),
      "' and '",
      class(object@Stimulus$Type),
      "', respectivley."
    )
  }


  #Essential fields
  if (!(
    nzchar(object@SubjectInfo$Subject) &&
    !is.na(object@SubjectInfo$DOB) &&
    all(!is.na(object@ExamInfo$ExamDate))
  )) {
    stop("Subject Name, DOB and ExamDate must be provided.")
  }

  # Dates
  dob <- object@SubjectInfo$DOB
  exam_date <- object@ExamInfo$ExamDate
  imported_date <- object@Imported

  if (("Date" %in% class(dob)) &&
      ("POSIXct" %in% class(exam_date)) &&
      ("POSIXct" %in% class(imported_date))) {
  if (!(as.POSIXct(dob) < min(exam_date) && max(exam_date) < min(imported_date))) {
      stop("Temporal sequence of 'DOB', 'ExamDate', and 'Imported' is impossible. ")
    }
  } else {
    stop("DOB, ExamDate, and Imported should be of class Date ('DOB'), POSIXct.")
  }

  if(object@Imported<"2024-02-01"){
    message("This ERGExam object is outdated. Please run UpdateERGExam().")
  }
  TRUE
}

#' ERGExam Class
#'
#' A class representing an ERG (Electroretinogram) exam. This class extends the \link[EPhysData:EPhysSet]{EPhysData::EPhysSet} object and all methods valid for \link[EPhysData:EPhysSet]{EPhysData::EPhysSet} can also be applied to \linkS4class{ERGExam} objects.
#'
#' @slot Data Data A list of \link[EPhysData:EPhysData]{EPhysData::EPhysData} objects. Each item containing a recording in response to a particular Stimulus ("Step"), from a particular eye and data Channel (e.g. ERG or OP), as defined in the corresponding Metadata.
#' @slot Metadata  A data frame containing metadata information associated with the data in the Data slot, each row corresponds to one item in \code{data}.
#' \describe{
#'   \item{Step}{An integer vector containing the step index. A step describes data recorded in response to the same type of stimulus. This column links the Stimulus slot to the metadata}
#'   \item{Eye}{A character vector. Possible values "RE" (right eye) and "LE" (left eye).}
#'   \item{Channel}{A character vector containing the channel name. This can be "ERG", "VEP" or "OP" for instance.}
#'   \item{Result}{A numeric vector containing the indices of individual results contained in an ERG exam. E.g., if a recording to one identical stimulus is performed twice, these would be distinguished by different indices in the Result column. Warning: This is currently experimental}
#' }
#'
#' @slot Stimulus
#' A data frame containing stimulus information.
#' \describe{
#'   \item{Step}{An integer vector row index. Will be removed in future versions.}
#'   \item{Description}{A character vector describing the stimulus in a human-readable way.}
#'   \item{Intensity}{A numeric vector representing the intensity of the stimulus.}
#'   \item{Background}{A character vector describing the adaptation state of the retina for that stimulus (DA or LA).}
#'   \item{Type}{A character vector describing the type of the stimulus (e.g. Flash or Flicker).}
#' }
#'
#' @slot Averaged
#' TRUE if the object contains averaged data, FALES indicates object contains raw traces.
#'
#' @slot Measurements
#' An object of class \linkS4class{ERGMeasurements}
#'
#' @slot ExamInfo
#' A list containing exam-related information.
#' \describe{
#'   \item{ProtocolName}{A character vector indicating the name of the protocol.}
#'   \item{Version}{Optional: A character vector indicating the version of the protocol.}
#'   \item{ExamDate}{A \code{POSIXct} The date of the exam.}
#'   \item{Filename}{Optional: The filename associated where exam raw data have been imported from.}
#'   \item{RecMode}{Optional: A character vector indicating the recording mode.}
#'   \item{Investigator}{Optional: A character vector indicating the name of the investigator conducting the exam.}
#' }
#'
#' @slot SubjectInfo
#' A list containing subject-related information.
#' \describe{
#'   \item{Subject}{A character vector indicating the name of the subject}
#'   \item{DOB}{A \code{Date} object indicating the date of birth of the subject}
#'   \item{Gender}{Optional: A character vector indicating the gender of the subject}
#'   \item{Group}{Optional: A character vector indicating the study group to which the subject belongs.}
#' }
#'
#' @slot Imported
#' A \code{POSIXct} timestamp indicating when the object was imported.
#'
#' @name ERGExam
#' @seealso \link[EPhysData:EPhysData]{EPhysData::EPhysData-package} \link[EPhysData:EPhysData]{EPhysData::EPhysData-class} \link[EPhysData:EPhysSet]{EPhysData::EPhysSet-class}
#' @importClassesFrom EPhysData EPhysData EPhysSet
#' @importFrom units as_units
#' @aliases ERGExam-class
#' @exportClass ERGExam
ERGExam <- setClass(
  "ERGExam",
  contains = "EPhysSet",
  slots = c(
    Data = "list",
    # Data is a list of EPhysData objects
    Metadata = "data.frame",
    # Metadata is a data frame
    Stimulus = "data.frame",
    # Stimulus is a data frame
    Averaged = "logical",
    # Averaged is a logical
    Measurements = "ERGMeasurements",
    # Measurements is a data frame
    ExamInfo = "list",
    # ExamInfo is a list
    SubjectInfo = "list",
    # SubjectInfo is a list
    Imported = "POSIXct"
  ),
  prototype = list(
    Data = list(NULL),
    Metadata = data.frame(
      Step = integer(),
      Eye = character(),
      Channel = character(),
      stringsAsFactors = FALSE
    ),
    Stimulus = data.frame(
      Step = integer(),
      Description = character(),
      Intensity = as_units(numeric(), unitless),
      Background = character(),
      Type = character()
    ),
    Averaged = FALSE,
    Measurements =  new("ERGMeasurements"),
    ExamInfo = list(
      ProtocolName = character(),
      Version = character(),
      ExamDate = as.POSIXct(integer()),
      Filename = character(),
      RecMode = character(),
      Investigator = character()
    ),
    SubjectInfo = list(
      Subject = character(),
      DOB = as.Date(x = integer(0), origin = "1970-01-01"),
      Gender = character(),
      Group = character()
    ),
    Imported = as.POSIXct(integer())
  ),
  validity = validERGExam
)

#' Create an instance of the ERGExam class
#'
#' @description This function creates an instance of the \linkS4class{ERGExam} class.
#'
#' @param Data A list of \linkS4class{EPhysData::EPhysData} objects.
#' @param Metadata A data frame containing metadata information associated with the data, each row corresponds to one list item.
#' \describe{
#'   \item{Step}{An integer vector pointing to a row index of the Stimulus table.}
#'   \item{Eye}{A character vector containing the possible values "RE" (right eye) and "LE" (left eye).}
#'   \item{Channel}{A character vector containing the unique names of the third level of \code{Data}.}
#' }
#' @param Stimulus A data frame containing stimulus information associated with the data.
#' \describe{
#'   \item{Description}{A character vector describing the stimuli.}
#'   \item{Background}{An integer vector representing the background intensity of the stimulus (unitless).}
#'   \item{Intensity}{An numeric vector representing the intensity of the stimulus (unitless).}
#' }
#' @param Averaged A list of averaged data.
#' @param Measurements An object of class \linkS4class{ERGMeasurements}.
#' @param ExamInfo A list containing exam-related information.
#' \describe{
#'   \item{ProtocolName}{A character vector indicating the name of the protocol.}
#'   \item{Version}{Optional: A character vector indicating the version of the protocol.}
#'   \item{ExamDate}{A \code{POSIXct} timestamp representing the date of the exam.}
#'   \item{Filename}{Optional: A character vector indicating the filename associated with the exam data.}
#'   \item{RecMode}{Optional: A character vector indicating the recording mode during the exam.}
#'   \item{Investigator}{Optional: A character vector indicating the name of the investigator conducting the exam.}
#' }
#' @param SubjectInfo A list containing subject-related information.
#' \describe{
#'   \item{Subject}{A character vector (required) indicating the name of the patient.}
#'   \item{DOB}{A \code{Date} object  (required) indicating the date of birth of the patient.}
#'   \item{Gender}{Optional: A character vector indicating the gender of the patient.}
#'   \item{Group}{Optional: A character vector indicating the group to which the patient belongs.}
#' }
#' @examples
#' # Create example data and metadata
#' Data <-
#'   list(
#'     makeExampleEPhysData(sample_points = 100, replicate_count = 3),
#'     makeExampleEPhysData(sample_points = 100, replicate_count = 3),
#'     makeExampleEPhysData(sample_points = 100, replicate_count = 6),
#'     makeExampleEPhysData(sample_points = 100, replicate_count = 6)
#'   )  # List of EPhysData objects
#' Metadata <-
#'   data.frame(
#'     Step = as.integer(c(1,1,2,2)),
#'     Eye = c("RE", "LE", "LE", "LE"),
#'     Channel = c("Ch1", "Ch1", "Ch1", "Ch2"),
#'     Result = as.integer(c(1,1,1,1))
#'   )
#' Stimulus <-
#'   data.frame(Description = c("Stim1", "Stim2"),
#'              Intensity = as.numeric(c(1,10)),
#'              Background = c("DA","DA"),
#'              Type = c("Flash","Flash"))  # Example stimulus data
#' ExamInfo <-
#'   list(
#'     ProtocolName = "ERG Protocol",
#'     Version = "1.0",
#'     ExamDate = as.POSIXct("2023-08-14"),
#'     Filename = "exam_data.csv"
#'   )
#' SubjectInfo <-
#'   list(
#'     Subject = "John Doe",
#'     DOB = as.Date("1990-05-15"),
#'     Gender = "Male",
#'     Group = "Control"
#'   )
#' ergExam <-
#'   newERGExam(
#'     Data = Data,
#'     Metadata = Metadata,
#'     Stimulus = Stimulus,
#'     ExamInfo = ExamInfo,
#'     SubjectInfo = SubjectInfo
#'   )
#'
#' @return An object of class \code{ERGExam}.
#' @seealso \linkS4class{ERGExam}
#' @importFrom units as_units
#' @importFrom methods new validObject
#' @export
newERGExam <-
  function(Data,
           Metadata,
           Stimulus,
           Averaged = FALSE,
           Measurements =  new("ERGMeasurements"),
           ExamInfo,
           SubjectInfo) {
    # Call the default constructor
    obj <- new("ERGExam")

    if("Step" %in% colnames(Stimulus)){
      warning("Reserved column name 'Step' encountered. Will be overwritten.")
    }
    Stimulus$Step<-as.integer(1:nrow(Stimulus))

    # Set the values for the slots
    obj@Data <- Data
    Metadata$Eye <- as.std.eyename(Metadata$Eye)
    obj@Metadata <- Metadata
    obj@Stimulus <- Stimulus
    obj@Averaged <- Averaged
    obj@Measurements <- Measurements
    obj@ExamInfo <- ExamInfo
    obj@SubjectInfo <- SubjectInfo

    if (is.null(obj@SubjectInfo$Group)) {
      obj@SubjectInfo$Group<-"DEFAULT"
    }

    # Set default values for other slots
    obj@Imported <- as.POSIXct(Sys.time())

    # Call the validity method to check if the object is valid
    if (validObject(obj)) {
      return(obj)
    }
  }

#' @noMd
setAs("EPhysSet", "ERGExam", function(from) {
  new(to, Data = from@Data, Metadata = Metadata(from))
})

#' @noMd
#' @importFrom crayon green yellow
#' @importFrom utils object.size
setMethod("show",
          "ERGExam",
          function(object) {
            cat("An object of class ERGExam")
            cat(
              green("\nSubject:\t"),
              green(Subject(object)),
              ", ",
              as.character(DOB(object)),
              ", ",
              object@SubjectInfo$Gender,
              sep = ""
            )
            cat(green("\nExam Date:\t", as.character(ExamDate(object))))
            cat("\nProtocol:\t", object@ExamInfo$ProtocolName)
            cat("\nSteps:\t\t")
            cat(object@Stimulus$Description, sep = "\n\t\t")
            cat("Eyes:\t", Eyes(object), sep = "\t")
            cat("\nChannels:\t")
            cat(Channels(object), sep = "\n\t\t")
            if (length(object@Data) == 0) {
              cat("\nRaw data not stored in object.")
            }
            if (object@Averaged) {
              cat("\nObject contains imported averaged traces.")
            }
            if (length(object@Measurements) == 0) {
              cat("\nNo measurements stored in object.")
            } else {
              if (object@Averaged) {
                cat(green("\n*Measurements imported from external source.*"))
              }
            }
            suppressWarnings({
              fxSet<-CheckAvgFxSet(object)
            })

            if(!fxSet){
              cat(yellow("\nAn averge function has not been set for this object."))
            }else{
              cat("\nAn averge function has been set for this object.")
            }
            cat("\nSize:", format(object.size(object), "auto"),"\n")
          })
