#' Export fake IDs
#'
#' @param ids Real IDs.
#' @param path .xlsx fake id file path to export.
#' @param key Either "p" or "j" for fake IDs.
#' @param .survey_id ISAS survey id.
#' @param .outurl Survey URL provided by client.
#' @param .etc1 etc1 column value.
#'
#' @import dplyr openxlsx
#' @return NULL. Generate file at provided path.
#' 
#' @examples
#' \dontrun{
#' id_output %>>%
#' ## Export pid
#' (~ gen_fake_id(., path, .survey_id = survey_id, .outurl = outurl)) %>%
#' ## Export mail ids
#'   write_mail_list(mail_path)
#' }

#' @export
gen_fake_id <- function(ids, path, key=c("p", "j"), .survey_id=NULL, .outurl=NULL, .etc1=NA) {
  
  if (missing(key)) {
    warning("the fake-id key is not specified; by default, the key is 'p'", 
            call.=FALSE)
    method = "p"
  }
  
  key <- match.arg(key)
  
  if (is.null(ids)) return()
  
  ## check if file extention is ".xlsx"
  ext <- tolower(tools::file_ext(path))
  if (!identical(ext, "xlsx")) stop("`path` must be .xlsx file", call. = FALSE)
  
  old_fake_id <- NULL
  
  
  ## get path base string
  file_match_str <- tools::file_path_sans_ext(basename(path))
  file_match <- list.files("./", paste0("^", file_match_str, ".*\\.xlsx$"))
  
  ## check old file exists
  if (length(file_match)!=0) {
    old_file_name <- file_match[[1]]
    original_file_exists <- file.exists(old_file_name)
  } else original_file_exists <- FALSE
  
  
  if (original_file_exists) {
    old_data <- readxl::read_excel(old_file_name, 
                                   col_types = c("numeric",rep("text", 3)))
    cat("\u5f9e", normalizePath(old_file_name), "\u532f\u5165", nrow(old_data), "\u7b46\u820apid\n\n")
    
    old_fake_id <- stringr::str_extract(old_data$outurl,
                                        "[^=]+$")  # str after last "="
    
    if (is.null(.outurl)) {
      .outurl <- stringr::str_extract(old_data$outurl,
                                      "^(.*[=])")[[1]]  # str before last "="
    }
    if (is.null(.survey_id)) .survey_id <- old_data$survey_id[[1]]
    
    new_panel_id <- setdiff(ids, old_data$panel_id) # exclude existed panel_id
    
    if (length(new_panel_id)==0) {
      cat("# `gen_fake_id`: \u6c92\u6709\u65b0panel_id\u9700\u8981\u4e0a\u50b3pid\n\n")
      return()
    }
  } else {
    new_panel_id <- ids
  }
  
  if (is.null(.survey_id)) stop("`.survey_id` must not be NULL", call. = FALSE)
  if (is.null(.outurl)) stop("`.outurl` must not be NULL", call. = FALSE)
  
  ## generate id
  n_new_panel_id <- length(new_panel_id)  
  n_duplicated_id <- n_new_panel_id
  new_fake_id <- NULL  # reserve space
  
  if (n_duplicated_id != 0) {
    repeat {
      new_fake_id <- c(setdiff(new_fake_id, old_fake_id), 
                       id_generator(n_duplicated_id, key))
      n_duplicated_id <- length(intersect(new_fake_id, old_fake_id))
      if (n_duplicated_id == 0) break
    }
    
    ## new output df
    df <- data.frame(survey_id = as.numeric(.survey_id), 
                     panel_id = as.character(new_panel_id), 
                     outurl = paste0(.outurl, new_fake_id),
                     etc1 = .etc1, stringsAsFactors=F)
    if (original_file_exists) {
      df <- as.data.frame(dplyr::bind_rows(old_data, df), stringsAsFactors=F)
    }
  } else {
    df <- old_data
  }
  
  ## write to excel file
  time_stamp <- strftime(Sys.time(), format = "%Y-%m-%d-%H%M%S")  # time stamp for file name
  new_file_name <- paste0(file_match_str, "_",time_stamp, ".xlsx")
  openxlsx::write.xlsx(df, new_file_name, sheetName="sheet1")
  
  ## create log file
  dir.create("./pid_log", showWarnings = FALSE)
  df_log <- data.frame(survey_id = as.numeric(.survey_id), 
                       panel_id = as.character(new_panel_id), 
                       pid = new_fake_id)
  write.table(df_log,
              file = file.path("./pid_log", paste0("log_",
                                                   file_match_str, "_",
                                                   time_stamp, ".log")),
              quote = FALSE, row.names = FALSE, col.names = TRUE
  )
  
  
  cat("-> pid \u5df2\u532f\u51fa\u81f3 ", new_file_name, "\n",
      "\u5171\u532f\u51fa", 
      if (original_file_exists) 
        length(old_data$panel_id), "\u7b46\u820apid, ",
      n_new_panel_id, "\u7b46\u65b0pid, ",
      "\u6a94\u6848\u4e2d\u5171\u5305\u542b", length(df$panel_id), "\u7b46id\n",
      "(\u8acb\u7528excel\'\u53e6\u5b58\'\u6210.xls\u6a94 =>\u300c\u5916\u90e8\u8abf\u67e5\u9023\u7d50\u532f\u5165\u300d=> \u4e0a\u50b3pid)\n\n")
  
  
  if (file.exists(new_file_name) & original_file_exists) {
    ## copy file
    file.copy(from = old_file_name, 
              to = paste0("./pid_log/", basename(old_file_name), ".temp"))
    
    ## remove old file
    file.remove(old_file_name)
    log_xlsx_match <- list.files("./pid_log", 
                                 paste0("\\.backup$"), 
                                 full.names = TRUE)
    if (length(log_xlsx_match) !=0) {
      file.remove(log_xlsx_match)
      cat(log_xlsx_match, sep = "\n", "removed.\n")
    }
  }
  
  ## rename
  file.rename(from = list.files("./pid_log", "\\.temp$", full.names = TRUE),
              to = gsub("\\.temp$", ".backup",
                        list.files("./pid_log", "\\.temp$", full.names = TRUE))
  )
  
  invisible()
}

