# ---------------------------------------------------------------------------- #
# Get Text Similarity depending on the settings
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# compute the similarities
similarities <- as.matrix(textstat_simil(dfm_refs, dfm_apps, method = "cosine"))

# ---------------------------------------------------------------------------- #
# reduce the dimension of similarities to the referee basis

# get IDs for refs and apps
list_of_referees <- as.character(unique(ref_texts$ref_id))
list_of_apps <- app_texts$ApplicationId

# check if only the single bets matching paper should be considered for a ref
if (single_best_match) {
  # reduce the similarity matrix just to the best matching paper of each
  # referee to a each proposal
  best_match <- vector(mode = "list", length = length(list_of_apps))
  names(best_match) <- list_of_apps
  # loop to find the best matching paper of each referee for each proposal
  for (ref_idx in list_of_referees) {
    # isolate only 1 single referee
    # drop=FALSE to preserve df format if only 1 row selected
    single_ref_sim <- similarities[which(grepl(
      ref_idx, gsub("\\_[^_]*$", "", rownames(similarities)))), ,
      drop = FALSE]
    # check for each proposal which of these papers is the best matching one
    for (app_idx in list_of_apps) {
      # isolate the best-matching paper (take care of 1-row entry names)
      best_match[[app_idx]][[ref_idx]] <- ifelse(
        nrow(single_ref_sim) == 1, rownames(single_ref_sim),
        names(which.max(single_ref_sim[, app_idx])))
    }
  }
  
  # reduce the matrix based on best match of referee paper for each proposal
  similarities_reduced <- matrix(NA, ncol = length(list_of_apps),
                                 nrow = length(list_of_referees))
  # add colnames
  colnames(similarities_reduced) <- list_of_apps
  rownames(similarities_reduced) <- list_of_referees
  
  # fill in the matrix, for each proposal take the best matching referee paper
  for (app_idx in list_of_apps) {
    # fill in relevant values
    similarities_reduced[, app_idx] <- similarities[
      which(rownames(similarities) %in% as.character(
        unlist(best_match[[app_idx]]))), app_idx]
  }
} else {
  # take the referee values for top XY% of matching papers
  top_match <- vector(mode = "list", length = length(list_of_apps))
  names(top_match) <- list_of_apps
  
  # find the top % of best matching paper of each referee for each proposal
  for (ref_idx in list_of_referees) {
    # isolate only 1 single referee
    # drop=FALSE to preserve df format if only 1 row selected
    single_ref_sim <- similarities[which(grepl(
      ref_idx, gsub("\\_[^_]*$", "", rownames(similarities)))), ,
      drop = FALSE]
    
    # check for each proposal which of these papers is the best matching one
    for (app_idx in list_of_apps) {
      # get the top matching papers (take care of 1-row entry names)
      # check if only 1 paper (this should not happen here as we restrict to 10)
      # and will happen only if we use concatenation for tfidf - only 1 entry
      if (nrow(single_ref_sim) == 1) {
        # then take only the similarity of that one paper
        top_match[[app_idx]][[ref_idx]] <- single_ref_sim[, app_idx]
      } else {
        # or get the average similarity for top % of papers
        # use ceiling to get at least 1, given the percentage considered
        n_top_papers <- ceiling(top_match_per_ref * nrow(single_ref_sim))
        # if this is less then 5, ensure at least 5 papers being considered
        n_top_papers <- ifelse(n_top_papers < 5, 5, n_top_papers)
        # get the average similarity for the n top papers
        # take unweighted mean
        top_match[[app_idx]][[ref_idx]] <- mean(sort(
          single_ref_sim[, app_idx], decreasing = TRUE)[1:n_top_papers])
      }
    }
  }
  # reduce the matrix based on best match of referee paper for each proposal
  similarities_reduced <- matrix(NA, ncol = length(list_of_apps),
                                 nrow = length(list_of_referees))
  # add colnames
  colnames(similarities_reduced) <- list_of_apps
  rownames(similarities_reduced) <- list_of_referees
  # fill in the matrix, for each proposal take the best matching referee paper
  for (app_idx in list_of_apps) {
    for (ref_idx in list_of_referees) {
      # fill in relevant values
      similarities_reduced[ref_idx, app_idx] <- top_match[[app_idx]][[ref_idx]]
    }
  }
}

# reassign back to similarities
similarities <- similarities_reduced

# and save the results as they can be reused for tf-idf combinations
# specify the file name for saving
sim_filename <- paste0(here("data", "output", "similarity",
                            paste0("similarity_truncation_", truncation, "_",
                                   "concatenation_", concatenation, "_",
                                  stri_replace_all_regex(str_replace_all(
                                    paste(all_settings[test_idx, ],
                                          collapse = "_"), "-", "_"),
                                    c("google/", "allenai/",
                                      "sentence_transformers/"),
                                    "", vectorize = FALSE), ".xlsx")))

# store the data in the similarity folder
if (!file.exists(here("data", "output", "similarity"))) {
  dir.create(here("data", "output", "similarity"))
}

# save the excel sheet
rio::export(similarities, file = sim_filename, rowNames = TRUE)

# ---------------------------------------------------------------------------- #
