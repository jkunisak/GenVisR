################################################################################
##################### Public/Private Class Definitions #########################

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Public Class !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#

#' Class VarScanFormat
#' 
#' @name VarScanFormat-class
#' @rdname VarScanFormat-class
#' @slot path Character string specifying the path of the VarScan file read in.
#' @exportClass VarScanFormat
#' @include VarScanFormat_Virtual-class.R
#' @import methods
setClass("VarScanFormat",
         representation=representation(path="character"), 
         contains="VarScanFormat_Virtual",
         validity = function(object) {
             ## Perform validity checks on loh data
             if (object@varscan$varscanType[1] == "LOH") {
                 ## Expected varscan column names
                 cnames <- c("chrom", "position", "ref", "var",
                             "normal_reads1", "normal_reads2", "normal_var_freq",
                             "normal_gt", "tumor_reads1", "tumor_reads2", "tumor_var_freq",
                             "tumor_gt", "somatic_status", "variant_p_value",
                             "somatic_p_value", "tumor_reads1_plus", "tumor_reads1_minus",
                             "tumor_reads2_plus", "tumor_reads2_minus",
                             "normal_reads1_plus", "normal_reads1_minus",
                             "normal_reads2_plus", "normal_reads2_minus", "sample", "varscanType")
                 
                 ## Check to see if there is any data after the filtering steps for varscan
                 if (nrow(object@varscan) == 0) {
                     stop("No varscan data can be found after filtering based on 
                          normal VAF and Germline/LOH somatic_status")
                 }
                 
                 ## Check the column names to see if there is the appropriate input
                 varscan_column_names <- colnames(object@varscan)
                 num <- which(!varscan_column_names%in%cnames)
                 if (length(num) > 0 & length(varscan_column_names) == length(cnames)) {
                     mismatch <- paste(as.character(varscan_column_names[num]), collapse=", ")
                     stop(paste0("Column names of varscan input are not what is expected. Please ",
                          "refer to http://varscan.sourceforge.net/somatic-calling.html#somatic-output ", 
                          "for appropriate column names. The columns: ", 
                          mismatch, " are discrepant."))
                 }
                 
                 if (length(num) > 0 & length(varscan_column_names) != length(cnames)) {
                     stop("Number of columns in varscan input are not what is expected. 23
                          columns are expected. Please refer to 
                          http://varscan.sourceforge.net/somatic-calling.html#somatic-output
                          for appropriate columns and column names.")
                 }
                 
                 ## Check to see if the VAF columns are percentage as opposed to proportion
                 ## Function requires input in percentages and will convert percentage to proportion
                 tumor_per <- any(grepl("%", object@varscan$tumor_var_freq) == TRUE)
                 normal_per <- any(grepl("%", object@varscan$normal_var_freq) == TRUE)
                 if (tumor_per == TRUE | normal_per == TRUE) {
                     message("Make sure the tumor/normal VAF column is in percentage and not proportion. 
                             (i.e. 75.00% as opposed to 0.75).")
                 }
                 
                 ## Check to see if the VAF provided are somatic or not
                 if (any(object@varscan$tumor_var_freq>1 | object@varscan$normal_var_freq >1)) {
                     message("Detected values in either the normal or tumor variant ",
                             "allele fraction columns above 1. Values supplied should ",
                             "be a proportion between 0-1!")
                 }
             }
             
             ## Perform validity checks on cnv data
             if (object@varscan$varscanType[1] == "CNV") {
                 cnames <- c("chrom", "chr_start", "chr_stop", "normal_depth",
                          "tumor_depth", "log_ratio", "gc_content", "sample", "varscanType")
             }
             
             ## Check to see if there is any data after the filtering steps for varscan
             if (nrow(object@varscan) == 0) {
                 stop("No varscan data can be found after filtering based on 
                      normal VAF and Germline/LOH somatic_status")
             }
             
             ## Check the column names to see if there is the appropriate input
             varscan_column_names <- colnames(object@varscan)
             num <- which(!varscan_column_names%in%cnames)
             if (length(num) > 0 & length(varscan_column_names) == length(cnames)) {
                 mismatch <- paste(as.character(varscan_column_names[num]), collapse=", ")
                 stop(paste0("Column names of varscan input are not what is expected. Please ",
                             "refer to http://varscan.sourceforge.net/somatic-calling.html#somatic-output ", 
                             "for appropriate column names. The columns: ", 
                             mismatch, " are discrepant."))
             }
             
             if (length(num) > 0 & length(varscan_column_names) != length(cnames)) {
                 stop(paste0("Number of columns in varscan input are not what is expected. 24",
                      " columns are expected, including the sample column. Please refer to", 
                      " http://varscan.sourceforge.net/somatic-calling.html#somatic-output",
                      " for appropriate columns and column names."))
             }
             
             return(TRUE)
         }
)

#' Constructor for the VarScanFormat container class.
#' 
#' @name VarScanFormat
#' @rdname VarScanFormat-class
#' @param path String specifying the path to a VarScan file.
#' @param verbose Boolean specifying if progress should be reported while reading
#' in the VarScan. file.
#' @seealso \code{\link{lohSpec}}
#' @importFrom data.table fread
#' @export
VarScanFormat <- function(path, varscanType, verbose=FALSE) {
    ## Read in VarScan data
    varscanData <- suppressWarnings(fread(input=path, stringsAsFactors=FALSE,
                                                      verbose=verbose))
    
    ## Add varscanType value to dataset
    varscanData$varscanType <- varscanType
    
    ## Get the sample names
    sample <- varscanData[,which(colnames(varscanData)=="sample"), with=FALSE]
    
    ## If the varscan output is to visualize loh
    if (varscanType == "LOH") {
        ## Obtain coordinates that were called as germline or LOH by varscan
        varscanData <- varscanData[somatic_status=="Germline"|somatic_status=="LOH"]
        
        ## Convert VAF percentages to VAF proportions
        varscanData$normal_var_freq <- round(as.numeric(
            as.character(gsub(pattern="%", replacement="", 
                              varscanData$normal_var_freq)))/100, digits = 3)
        varscanData$tumor_var_freq <- round(as.numeric(
            as.character(gsub(pattern="%", replacement="", 
                              varscanData$tumor_var_freq)))/100, digits = 3)
    }
    
    ## If the varscan output is to visualize copy number data
    if (varscanType == "CNV") {
        ## Read in the copy number data
        varscanData <- suppressWarnings(fread(input=path, stringsAsFactors=FALSE,
                                     verbose=verbose))
        
        ## Add varscanType value to dataset
        varscanData$varscanType <- varscanType
        
        ## Get the sample names
        sample <- varscanData[,which(colnames(varscanData)=="sample"), with=FALSE]
    }
    
    ## Create the varscan object
    varscanObject <- new(Class="VarScanFormat", path=path, varscan=varscanData, sample=sample)
    return(varscanObject)
    
}

################################################################################
###################### Accessor function definitions ###########################

#' @rdname writeData-methods
#' @aliases writeData
setMethod(f="writeData", 
          signature="VarScanFormat",
          definition=function(object, file, ...) {
              writeData(object@varscan, file, sep="\t")
          })

#' @rdname getPath-methods
#' @aliases getPath
setMethod(f="getPath",
          signature="VarScanFormat",
          definition=function(object, ...){
              path <- object@path
              return(path)
          })
 


################################################################################
####################### Method function definitions ############################

#' @rdname getLohData-methods
#' @aliases getLohData
#' @noRd
#' @importFrom data.table data.table
setMethod(f="getLohData",
          signature="VarScanFormat",
          definition=function(object, verbose, lohSpec, germline, ...) {

              ## Print status message
              if (verbose) {
                  message("Generating LOH dataset.")
              }
              
              ## Obtain loh data
              primaryData <- object@varscan[somatic_status=="Germline" | somatic_status=="LOH"]
              
              ## Get germline data if necessary
              if (germline) {
                  primaryData <- primaryData[somatic_status=="Germline"]
              }
               
              ## Get the necessary columns from varscan output
              primaryData <- primaryData[,c("chrom", "position", "tumor_var_freq", 
                                        "normal_var_freq", "sample"), 
                                        with=FALSE]
              
              colnames(primaryData) <- c("chromosome", "position", "tumor_var_freq", 
                                         "normal_var_freq", "sample")
              
              if (lohSpec) {
                  ## Remove rows if necessary
                  if (any(object@varscan$normal_var_freq<0.4 | object@varscan$normal_var_freq>0.6)) {
                      message("Detected values with a variant allele fraction either ",
                              "above .6 or below .4 in the normal. Please ensure ",
                              "variants supplied are heterozygous in the normal! ", 
                              "Make sure to remove coordinates with normal VAF > 0.6 or < 0.4. ",
                              "Attempting to remove rows.")
                      
                      ## Remove coordinates with normal VAF > 0.6 or < 0.4
                      primaryData <- primaryData[normal_var_freq<=0.6 &
                                                     normal_var_freq>=0.4]
                  }
              }

              return(primaryData)
          })

#' @rdname getCnvData-methods
#' @aliases getCnvData
#' @noRd
#' @importFrom data.table data.table
setMethod(f="getCnvData",
          signature="VarScanFormat",
          definition=function(object, verbose, ...) {
              
              ## Print status message
              if (verbose) {
                  message("Generating CNV dataset.")
              }
              
              ## Get the necessary columns from varscan output
              primaryData <- object@varscan[,c("chrom", "chr_start", "chr_stop", "normal_depth",
                                               "tumor_depth", "log_ratio", "gc_content", "sample"), 
                                            with=FALSE]
              
              colnames(primaryData) <- c("chromosome", "position", "chr_stop", "normal_depth",
                                         "tumor_depth", "cn", "gc_content", "sample")
              
              ## Convert out of log space into absolute copy number
              primaryData$cn <- (2^primaryData$cn)*2
              
              return(primaryData)
              
          })