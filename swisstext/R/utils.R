# ---------------------------------------------------------------------------- #
# Utility functions
# ---------------------------------------------------------------------------- #

# path to python environment
python_path <- "C:/Users/gokasa/AppData/Local/R-MINI~1/"
# set the python environment for reticulate
Sys.setenv(RETICULATE_PYTHON = python_path)

# ---------------------------------------------------------------------------- #
# check folder structure
# store the data in the python folder
if (!file.exists(here("python"))) {
  dir.create(here("python"))
}
if (!file.exists(here("python", "data"))) {
  dir.create(here("python", "data"))
}
# and storage for text embeddings
if (!file.exists(here("data"))) {
  dir.create(here("data"))
}
if (!file.exists(here("data", "embeddings"))) {
  dir.create(here("data", "embeddings"))
}
# and storage for text embeddings as inputs
if (!file.exists(here("data", "input"))) {
  dir.create(here("data", "input"))
}
if (!file.exists(here("data", "output"))) {
  dir.create(here("data", "output"))
}

# ---------------------------------------------------------------------------- #
# Collapse a vector to a string, separated by ";", removing all NULLs from sql
str_sans_NULL <- function(str) {
  str <- str %>% 
    str_replace_all(., "NULL; ", "") %>% 
    str_replace_all(., "; NULL", "") %>% 
    str_replace_all(., "NULL", "") %>% 
    str_replace_all(., "NA; ", "") %>% 
    str_replace_all(., "; NA", "") %>% 
    str_replace_all(., "NA", "")
}

# ---------------------------------------------------------------------------- #
# function to retrieve referee data for export
get_ref_data_for_display <- function(ref_number, ref_idx) {
  
  # column name for the referee
  ref_name <- paste0("Ref ", ref_idx)
  # get the text for the referee: disciplines and keywords
  ref_text <- get_display_text_referee(ref_number)
  
  # combine this to a vector in 3 columns
  ref_data <- c(ref_number, ref_text$disciplines, ref_text$keywords)
  names(ref_data) <- c(ref_name, paste0(ref_name, " disciplines"),
                       paste0(ref_name, " keywords"))
  return(ref_data)
}

# ---------------------------------------------------------------------------- #
# Use most common keywords and disciplines as representative texts
get_display_text_referee <- function(ref_id) {
  
  # get the referee index in the scopus data
  ref_id_scopus <- which(sapply(scopus_texts, function(x) {
    as.character(x$scopus_auth_id) }) == ref_id)
  # get the scopus data for this referee
  this_ref_texts <- scopus_texts[[ref_id_scopus]]
  
  # -------------------------------------------------------------------------- #
  # get the keywords
  keyword_data <- this_ref_texts$keywords
  # get the most frequent keywords
  top_keywords <- get_top_terms(keyword_data, n_top_terms, keywords = TRUE)
  
  # Remove "; ; ;" from display if not enough keywords available from pubs
  if (all(top_keywords == "")) {
    keyword_str <- "(no keywords from publications)"
  } else {
    if (any(top_keywords == "")) {
      top_keywords <- top_keywords[top_keywords != ""]
    }
    keyword_str <- paste0(top_keywords, collapse = "; ")
  }
  
  # -------------------------------------------------------------------------- #
  # get the disciplines
  disciplines_data <- this_ref_texts$snsf_disciplines_per_pub
  # get the most frequent keywords
  top_disciplines <- get_top_terms(disciplines_data, n_top_terms,
                                   keywords = FALSE)
  
  # Remove "; ; ;" from display if not enough keywords available from pubs
  if (all(top_disciplines == "")) {
    disciplines_str <- "(no disciplines from publications)"
  } else {
    if (any(top_disciplines == "")) {
      top_disciplines <- top_disciplines[top_disciplines != ""]
    }
    disciplines_str <- paste0(top_disciplines, collapse = "; ")
  }
  
  # -------------------------------------------------------------------------- #
  # return the string of top keywords and top disciplines
  term_str <- list(disciplines_str, keyword_str)
  names(term_str) <- c("disciplines", "keywords")
  return(term_str)
}

# ---------------------------------------------------------------------------- #
# get top terms fun def
get_top_terms <- function(term_data, nterms = n_top_terms, keywords = TRUE) {
  # check if keywords or disciplines should be extracted
  if (keywords){
    term_vec_no_na <- extract_keywords(term_data)
  } else {
    term_vec_no_na <- extract_disciplines(term_data)
  }
  
  top_repeat_terms <- get_top_terms_from_vec(term_vec_no_na, nterms)
  # take care of empty strings
  top_repeat_terms_wo_empty <- length(stri_remove_empty(top_repeat_terms))
  if (top_repeat_terms_wo_empty < length(top_repeat_terms)) {
    top_repeat_terms <- get_top_terms_from_vec(
      term_vec_no_na, nterms + (nterms - top_repeat_terms_wo_empty))
    top_repeat_terms <- stri_remove_empty(top_repeat_terms)
  }
  # take care of missing terms
  if (length(top_repeat_terms) < nterms) {
    # augment by empty strings
    top_repeat_terms <- c(top_repeat_terms,
                          rep("", nterms - length(top_repeat_terms)))
  }
  return(top_repeat_terms)
}

# ---------------------------------------------------------------------------- #
# extract terms fun def
extract_terms <- function(keyword_data, sep_str = " \\| ") {
  keyword_vec <- unname(unlist(sapply(keyword_data, function(str) {
    trimws(unlist(str_split(str, sep_str)))
  })))
  keyword_vec_no_na <- keyword_vec[!is.na(keyword_vec) & keyword_vec != "NA"] %>%
    tolower()
  # remove empty strings, only if there are any, otherwise this results in NAs
  if (any(keyword_vec_no_na == "")) {
    keyword_vec_no_na <- keyword_vec_no_na[-which(keyword_vec_no_na == "")]
  }
  return(keyword_vec_no_na)
}

# ---------------------------------------------------------------------------- #
# extract keywords fun def
extract_keywords <- function(term_data) {
  extract_terms(term_data, sep_str = " \\| ")
}

# extract disciplines fun def
extract_disciplines <- function(term_data) {
  extract_terms(term_data, sep_str = ";")
}

# ---------------------------------------------------------------------------- #
# Extract lists of top terms
get_top_terms_from_vec <- function(term_vec, n_top_terms = n_top_terms) {
  if (n_top_terms == 0) return(c())
  sorted_terms <- sort(table(term_vec), decreasing = TRUE)
  if (length(sorted_terms) < n_top_terms) {
    nmissing <- n_top_terms - length(sorted_terms)
    empty_data <- rep("", 1, nmissing)
    names(empty_data) <- empty_data
    sorted_terms <- c(sorted_terms, empty_data)
  }
  return(names(sorted_terms[1:n_top_terms]))
}

# ---------------------------------------------------------------------------- #
