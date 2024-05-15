# ---------------------------------------------------------------------------- #
# Subset Text Data depending on the settings
# ---------------------------------------------------------------------------- #

# subset referee data
ref_text_data_subset <- lapply(scopus_texts, function(ref_idx) {
  # for each ref check which are the last 5 or 10 years (+1 to ensure 5 exactly)
  last_years_idx <- (ref_idx$years %in%
                       c(2021:(2021 - all_settings$years[test_idx] + 1)))
  # subset everything
  for (entry_idx in c("titles", "journals", "keywords", "abstracts", "years",
                      "is_first_last_author", "is_first2_last2_author",
                      "scopus_research_areas_per_pub",
                      "snsf_disciplines_per_pub")) {
    # take only subset
    subset <- ref_idx[[entry_idx]][last_years_idx]
    # re-assign the subset
    ref_idx[[entry_idx]] <- subset
  }
  # return the referee data
  return(ref_idx)
})
# add names
names(ref_text_data_subset) <- sapply(scopus_texts, function(x) x$scopus_auth_id)

# ---------------------------------------------------------------------------- #

# prepare dataframe
ref_texts <- data.frame(ref_id = numeric(), text_data = character())
# subset further based on the type of text - both ref and app data
ref_text_data_subset <- lapply(ref_text_data_subset, function(ref_idx) {
  # for each ref take only the relevant text type
  if (all_settings$text[test_idx] == "title") {
    # take only subset of titles
    subset <- data.frame(ref_id = ref_idx[["scopus_auth_id"]],
                         text_data = ref_idx[["titles"]])
    # append it to dataframe
    ref_texts <- rbind(ref_texts, subset)
    
  } else if (all_settings$text[test_idx] == "abstract") {
    # take only abstracts
    subset <- data.frame(ref_id = ref_idx[["scopus_auth_id"]],
                         text_data = ref_idx[["abstracts"]])
    # append it to dataframe
    ref_texts <- rbind(ref_texts, subset)
    
  } else if (all_settings$text[test_idx] == "title_abstract") {
    # concatenate titles with abstracts
    title_abstract <- paste(ref_idx[["titles"]], ref_idx[["abstracts"]],
                            sep = ". ")
    # take the subset
    subset <- data.frame(ref_id = ref_idx[["scopus_auth_id"]],
                         text_data = title_abstract)
    # append it to dataframe
    ref_texts <- rbind(ref_texts, subset)
    
  } else {
    # issue an error ad stop the program
    stop("Non-supported text type. Must be one of:
         'title', 'abstract', 'title_abstract'.")
  }
  # return the subset referee data
  return(ref_texts)
})

# reduce list to a dataframe
ref_texts <- do.call(rbind, ref_text_data_subset)

# ---------------------------------------------------------------------------- #
# application data subset: for each ref take only the relevant text type
if (all_settings$text[test_idx] == "title") {
  # take only subset of titles
  app_texts <- app_texts_full %>%
    select(ApplicationId, Title) %>%
    rename("text_data" = Title)
  
} else if (all_settings$text[test_idx] == "abstract") {
  # take only abstracts
  app_texts <- app_texts_full %>%
    select(ApplicationId, Abstract) %>%
    rename("text_data" = Abstract)
  
} else if (all_settings$text[test_idx] == "title_abstract") {
  # concatenate titles with abstracts
  app_texts <- app_texts_full %>%
    select(ApplicationId, Title, Abstract) %>%
    unite("text_data", c("Title", "Abstract"))
  
} else {
  # issue an error ad stop the program
  stop("Non-supported text type. Must be one of:
         'title', 'abstract', 'title_abstract'.")
}

# ---------------------------------------------------------------------------- #
