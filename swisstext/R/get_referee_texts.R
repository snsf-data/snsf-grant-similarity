# ---------------------------------------------------------------------------- #
# Download text data about referees
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# read in the raw data about referees
input_ref_df <- NULL
# loop through all sheets with panels and add panel info
for (panel_idx in panel_names) {
  # read in the data
  panel_experts_data <- read_excel(
    here("data", "input", dataset, "expert_list.xlsx"), sheet = panel_idx) %>%
    # add info on panel
    mutate(panel = panel_idx)
  # combine with other panels
  input_ref_df <- rbind(input_ref_df, panel_experts_data)
}

# remove refs in case there is no scopus number
input_ref_df <- input_ref_df %>%
  # rename var for consistency
  rename(name = `Full name`,
         snsf_number = `SNSF ID`,
         scopus_number = `Scopus ID`) %>%
  # drop nas
  drop_na(scopus_number)

# summarize referees
cat(paste("There are", nrow(input_ref_df), "referees in total.", "\n\n",
          sep = " "))

# ---------------------------------------------------------------------------- #
# read in scopus data for referee publications
scopus_texts <- readRDS(file = here("data", "input", dataset,
                                    paste0(dataset, "_referee_text_data.rds")))

# check the number of pubs before filtering only english texts
n_pubs_per_ref_all <- unlist(lapply(scopus_texts, function(x) length(x$titles)))

# ---------------------------------------------------------------------------- #
# keep only english referee publications
scopus_texts <- lapply(scopus_texts, function(ref_idx) {
  # check which referee is processed
  paste0("Processing referee: ", ref_idx$name)
  # storage for english indicator
  is_english <- c(rep(NA, length(ref_idx$titles)))
  # check for each referee her/his publications
  for (text_idx in 1:length(is_english)) {
    # get language of titles and abstracts
    abstract_lang <- detect_language(as.character(ref_idx$abstracts[text_idx]))
    title_lang <- detect_language(as.character(ref_idx$titles[text_idx]))
    # take care of NAs if the language cannot be determined
    abstract_lang <- ifelse(is.na(abstract_lang), "unknown", abstract_lang)
    title_lang <- ifelse(is.na(title_lang), "unknown", title_lang)
    # check if both are english and assign
    is_english[text_idx] <- (abstract_lang == "en" & title_lang == "en")
  }
  # now take only subsets of fully english texts for the subset of list entries
  for (entry_idx in c("titles", "journals", "keywords", "abstracts", "years",
                      "is_first_last_author", "is_first2_last2_author",
                      "scopus_research_areas_per_pub",
                      "snsf_disciplines_per_pub")) {
    # keep only the english entries and check if its empty first
    if (all(is.na(ref_idx[[entry_idx]]))) {
      ref_idx[[entry_idx]] <- NA
    } else {
      # take only english subset
      english_subset <- ref_idx[[entry_idx]][is_english]
      # check if some are character(0), i.e. effectively NAs
      no_info_idx <- sapply(english_subset, function(x) {
        identical(x,  character(0)) })
      # if there are no NAs, then continue, otherwise remove mark as NA
      if (any(no_info_idx)) {
        english_subset[which(no_info_idx)] <- NA
      }
      # assign the english subset
      ref_idx[[entry_idx]] <- english_subset
    }
  }
  # return the ref_idx back
  return(ref_idx)
})

# ---------------------------------------------------------------------------- #
# get only those that are max 10 years old
scopus_texts <- lapply(scopus_texts, function(ref_idx) {
  # check which referee is processed
  paste0("Processing referee: ", ref_idx$name)
  # check if years of publications is between 2021 und 2011
  is_less10years <- (ref_idx$years %in% c(2011:2021))
  # now take only subsets of texts less than 10 years
  for (entry_idx in c("titles", "journals", "keywords", "abstracts", "years",
                      "is_first_last_author", "is_first2_last2_author",
                      "scopus_research_areas_per_pub",
                      "snsf_disciplines_per_pub")) {
    # take only english subset
    year_subset <- ref_idx[[entry_idx]][is_less10years]
    # assign the 10year subset
    ref_idx[[entry_idx]] <- year_subset
  }
  #return the ref_idx back
  return(ref_idx)
})

# ---------------------------------------------------------------------------- #
# check the number of pubs after filtering only english texts
n_pubs_per_ref_en <- unlist(lapply(scopus_texts, function(x) length(x$titles) ))
# keep only those that have 10 publications at least
ref_names_10 <- names(which(n_pubs_per_ref_en >= 10))
# subset the list
scopus_texts <- lapply(ref_names_10, function(x) scopus_texts[[x]])

# summarize referees again
cat(paste("There are", length(scopus_texts),
          "referees in total that have at least 10 publications in English",
          "between 2011 and 2021.", "\n\n", sep = " "))

# ---------------------------------------------------------------------------- #
