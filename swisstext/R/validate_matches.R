# ---------------------------------------------------------------------------- #
# Validate top matches: compare the overlap with actual attribution
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# check for each best ref and co ref if its one without (english) texts
# only needed for the very first test round
if (test_idx == 1) {
  # clean the validation data for referees that don't have any (english) texts
  ref_english_names <- input_ref_df %>%
    filter(scopus_number %in% list_of_referees) %>%
    select(name) %>%
    pull()
  
  # prepare storage for removal
  remove_best_ref <- c(rep(FALSE, nrow(validation_data)))
  remove_best_coref <- remove_best_ref
  
  for (ref_idx in 1:nrow(validation_data)) {
    # ignore NAs as these are always NA
    if (!is.na(validation_data$`Best Ref`[ref_idx])) {
      # check if main ref is among the english ones
      remove_best_ref[ref_idx] <- (!any(grepl(
        pattern = validation_data$`Best Ref`[ref_idx], ref_english_names,
        ignore.case = TRUE)))
    }
    # ignore NAs as these are always NA
    if (!is.na(validation_data$`Best Co-Ref`[ref_idx])) {
      # check if co-ref is among the english ones
      remove_best_coref[ref_idx] <- (!any(grepl(
        pattern = validation_data$`Best Co-Ref`[ref_idx], ref_english_names,
        ignore.case = TRUE)))
    }
  }
  # print how many are affected
  print(paste0("From all assigned referees, ", sum(remove_best_ref),
               " main referees assigned and ", sum(remove_best_coref),
               " co-referees assigned do not have any (english) texts and will ",
               "be removed from the analysis."))
  
  # remove those referees from the validation data
  validation_data$`Best Ref`[remove_best_ref] <- NA
  validation_data$`Best Co-Ref`[remove_best_coref] <- NA
  
  # save clean validation data
  rio::export(validation_data,
              here("data", "output", "validation_data_clean.xlsx"))
  
  # get the number of unique refs assigned
  n_assigned_allrefs <- c(validation_data$`Best Co-Ref` %>% unique(),
                          validation_data$`Best Ref` %>% unique()) %>%
    unique() %>% length()
  # get the number of unqiue refs and co-refs
  n_assigned_refs <- validation_data$`Best Ref` %>% unique() %>% length()
  n_assigned_coref <- validation_data$`Best Co-Ref` %>% unique() %>% length()
  # print number of used refs
  print(paste0("Effectively, ", n_assigned_refs, " referees",
               " and ", n_assigned_coref, " co-referees", 
               " and in total ", n_assigned_allrefs, " unique referees",
               " have been assigned, while ", length(list_of_referees),
               " are available in total."))
}

# ---------------------------------------------------------------------------- #
# Mean average precision at K: top 2 and top 5
top_overlap <- c(2, 5)

# join the top ref output on the validation data
results <- left_join(validation_data, top_refs_for_display,
                     by = "ApplicationId") %>%
  # and remove non-english proposals (resulting join is NA)
  filter(!is.na(`Ref 1`)) %>%
  # and assign main discipline
  mutate(research_area = case_when(
    str_detect(panel, "LS") ~ "LS",
    str_detect(panel, "MINT") ~ "MINT",
    str_detect(panel, "SSH") ~ "SSH",
    TRUE ~ NA
  ))  %>%
  # and remove those applications that have both refs without english texts!
  filter(!(is.na(`Best Ref`) & is.na(`Best Co-Ref`)))

# ---------------------------------------------------------------------------- #
# compute mean average precision at K as well as the main measure

# get first the scopus numbers, only once
if (test_idx == 1) {
  # get the scopus numbers for the validation data
  validation_data <- validation_data %>%
    # best ref scopus
    left_join(input_ref_df %>%
                select(name, scopus_number),
              by = c("Best Ref" = "name")) %>%
    rename("Best Ref Number" = "scopus_number") %>%
    # coref scopus
    left_join(input_ref_df %>%
                select(name, scopus_number),
              by = c("Best Co-Ref" = "name")) %>%
    rename("Best Co-Ref Number" = "scopus_number") %>%
    # coref scopus
    left_join(input_ref_df %>%
                select(name, scopus_number),
              by = c("Option" = "name")) %>%
    rename("Option Number" = "scopus_number")
}

# ---------------------------------------------------------------------------- #
# now prepare the actual matching and predicted matching as lists of matches
actual_matches <- lapply(1:nrow(validation_data), function(app_idx) {
  # format into vector the best ref, coref and option as well if in there
  matching_vector <- c(as.character(validation_data$`Best Ref Number`[app_idx]),
                       as.character(validation_data$`Best Co-Ref Number`[app_idx]),
                       as.character(validation_data$`Option Number`[app_idx]))
  # remove NAs
  matching_vector <- matching_vector[!is.na(matching_vector)]
  # return the matching vector
  return(matching_vector)
})
# add names
names(actual_matches) <- validation_data$ApplicationId
# and remove those where all were NAs, i.e. character(0) as a results
no_valid_matches <- which(actual_matches == "character(0)")
actual_matches[no_valid_matches] <- NULL
# plus remove those that do not have english texts as applications alone
no_english_apps <- which(!names(actual_matches) %in% list_of_apps)
actual_matches[no_english_apps] <- NULL
# and sort by names
actual_matches = actual_matches[order(names(actual_matches))]

# ---------------------------------------------------------------------------- #
# prepare the predicted matches in the same manner
predicted_matches <- lapply(1:nrow(results), function(app_idx) {
  # format into vector the best ref, coref and option as well if in there
  matching_vector <- c(results$`Ref 1`[app_idx],
                       results$`Ref 2`[app_idx],
                       results$`Ref 3`[app_idx],
                       results$`Ref 4`[app_idx],
                       results$`Ref 5`[app_idx])
  # remove NAs
  matching_vector <- matching_vector[!is.na(matching_vector)]
  # return the matching vector
  return(matching_vector)
})
# add names
names(predicted_matches) <- results$ApplicationId
# and sort by names
predicted_matches = predicted_matches[order(names(predicted_matches))]

# ---------------------------------------------------------------------------- #
# compute the MAP@K for K=2 and K=5
map_at_2 <- mapk(2, actual_matches, predicted_matches)
map_at_5 <- mapk(5, actual_matches, predicted_matches)

# compute the variance of AP@K for K=2 and K=5
# prepare storage for the single AP@K
vap_at_2 <- c()
vap_at_5 <- c()
# loop through each application to compute AP@K (same as MAP@K for single entry)
for (app_idx in names(actual_matches)) {
  # at K=2
  vap_at_2[app_idx] <- mapk(2, list(actual_matches[[app_idx]]),
                            list(predicted_matches[[app_idx]]))
  # at K=5
  vap_at_5[app_idx] <- mapk(5, list(actual_matches[[app_idx]]),
                            list(predicted_matches[[app_idx]]))
}

# make sure that the mean results are identical
if (!identical(map_at_2, mean(vap_at_2))) {
  warning("MAP at 2 results vary. Check the computations.")
}
if (!identical(map_at_5, mean(vap_at_5))) {
  warning("MAP at 5 results vary. Check the computations.")
}

# compute the variance of the AP@K
vap_at_2 <- var(vap_at_2)
vap_at_5 <- var(vap_at_5)

# ---------------------------------------------------------------------------- #
# do the same for research areas

# ---------------------------------------------------------------------------- #
# SSH
apps_ssh <- results %>%
  filter(research_area == "SSH") %>%
  select(ApplicationId) %>%
  pull()
# subset ssh for actual matches
actual_matches_ssh <- actual_matches[which(names(actual_matches) %in% apps_ssh)]
# subset ssh for predicted matches
predicted_matches_ssh <- predicted_matches[
  which(names(predicted_matches) %in% apps_ssh)]

# compute the MAP@K for K=2 and K=5
map_at_2_ssh <- mapk(2, actual_matches_ssh, predicted_matches_ssh)
map_at_5_ssh <- mapk(5, actual_matches_ssh, predicted_matches_ssh)

# compute the variance of AP@K for K=2 and K=5
# prepare storage for the single AP@K
vap_at_2_ssh <- c()
vap_at_5_ssh <- c()
# loop through each application to compute AP@K (same as MAP@K for single entry)
for (app_idx in names(actual_matches_ssh)) {
  # at K=2
  vap_at_2_ssh[app_idx] <- mapk(2, list(actual_matches_ssh[[app_idx]]),
                            list(predicted_matches_ssh[[app_idx]]))
  # at K=5
  vap_at_5_ssh[app_idx] <- mapk(5, list(actual_matches_ssh[[app_idx]]),
                            list(predicted_matches_ssh[[app_idx]]))
}

# make sure that the mean results are identical
if (!identical(map_at_2_ssh, mean(vap_at_2_ssh))) {
  warning("SSH MAP at 2 results vary. Check the computations.")
}
if (!identical(map_at_5_ssh, mean(vap_at_5_ssh))) {
  warning("SSH MAP at 5 results vary. Check the computations.")
}

# compute the variance of the AP@K
vap_at_2_ssh <- var(vap_at_2_ssh)
vap_at_5_ssh <- var(vap_at_5_ssh)

# ---------------------------------------------------------------------------- #
# LS
apps_ls <- results %>%
  filter(research_area == "LS") %>%
  select(ApplicationId) %>%
  pull()
# subset ssh for actual matches
actual_matches_ls <- actual_matches[which(names(actual_matches) %in% apps_ls)]
# subset ssh for predicted matches
predicted_matches_ls <- predicted_matches[
  which(names(predicted_matches) %in% apps_ls)]

# compute the MAP@K for K=2 and K=5
map_at_2_ls <- mapk(2, actual_matches_ls, predicted_matches_ls)
map_at_5_ls <- mapk(5, actual_matches_ls, predicted_matches_ls)

# compute the variance of AP@K for K=2 and K=5
# prepare storage for the single AP@K
vap_at_2_ls <- c()
vap_at_5_ls <- c()
# loop through each application to compute AP@K (same as MAP@K for single entry)
for (app_idx in names(actual_matches_ls)) {
  # at K=2
  vap_at_2_ls[app_idx] <- mapk(2, list(actual_matches_ls[[app_idx]]),
                                list(predicted_matches_ls[[app_idx]]))
  # at K=5
  vap_at_5_ls[app_idx] <- mapk(5, list(actual_matches_ls[[app_idx]]),
                                list(predicted_matches_ls[[app_idx]]))
}

# make sure that the mean results are identical
if (!identical(map_at_2_ls, mean(vap_at_2_ls))) {
  warning("SSH MAP at 2 results vary. Check the computations.")
}
if (!identical(map_at_5_ls, mean(vap_at_5_ls))) {
  warning("SSH MAP at 5 results vary. Check the computations.")
}

# compute the variance of the AP@K
vap_at_2_ls <- var(vap_at_2_ls)
vap_at_5_ls <- var(vap_at_5_ls)

# ---------------------------------------------------------------------------- #
# MINT
apps_mint <- results %>%
  filter(research_area == "MINT") %>%
  select(ApplicationId) %>%
  pull()
# subset mint for actual matches
actual_matches_mint <- actual_matches[
  which(names(actual_matches) %in% apps_mint)]
# subset mint for predicted matches
predicted_matches_mint <- predicted_matches[
  which(names(predicted_matches) %in% apps_mint)]

# compute the MAP@K for K=2 and K=5
map_at_2_mint <- mapk(2, actual_matches_mint, predicted_matches_mint)
map_at_5_mint <- mapk(5, actual_matches_mint, predicted_matches_mint)

# compute the variance of AP@K for K=2 and K=5
# prepare storage for the single AP@K
vap_at_2_mint <- c()
vap_at_5_mint <- c()
# loop through each application to compute AP@K (same as MAP@K for single entry)
for (app_idx in names(actual_matches_mint)) {
  # at K=2
  vap_at_2_mint[app_idx] <- mapk(2, list(actual_matches_mint[[app_idx]]),
                               list(predicted_matches_mint[[app_idx]]))
  # at K=5
  vap_at_5_mint[app_idx] <- mapk(5, list(actual_matches_mint[[app_idx]]),
                               list(predicted_matches_mint[[app_idx]]))
}

# make sure that the mean results are identical
if (!identical(map_at_2_mint, mean(vap_at_2_mint))) {
  warning("SSH MAP at 2 results vary. Check the computations.")
}
if (!identical(map_at_5_mint, mean(vap_at_5_mint))) {
  warning("SSH MAP at 5 results vary. Check the computations.")
}

# compute the variance of the AP@K
vap_at_2_mint <- var(vap_at_2_mint)
vap_at_5_mint <- var(vap_at_5_mint)

# ---------------------------------------------------------------------------- #
# summarise results
results_map <- data.frame(model = NA, embedding = NA, years = NA, text = NA,
                          map_at_2 = NA, map_at_5 = NA)
# and for areas
results_map_area <- data.frame(model = NA, embedding = NA, years = NA,
                               text = NA, area = c("LS", "MINT", "SSH"),
                               map_at_2 = NA, map_at_5 = NA)
# assign results: overall
# define setting
results_map$model <- all_settings$model[test_idx]
results_map$embedding <- all_settings$embedding[test_idx]
results_map$years <- all_settings$years[test_idx]
results_map$text <- all_settings$text[test_idx]
# assign map 2 and 5
results_map$map_at_2 <- map_at_2
results_map$map_at_5 <- map_at_5

# ---------------------------------------------------------------------------- #
# assign results: by research area
# define setting
results_map_area$model <- rep(all_settings$model[test_idx], 3)
results_map_area$embedding <- rep(all_settings$embedding[test_idx], 3)
results_map_area$years <- rep(all_settings$years[test_idx], 3)
results_map_area$text <- rep(all_settings$text[test_idx], 3)
# assign map 2 and 5
results_map_area$map_at_2 <- c(map_at_2_ls, map_at_2_mint, map_at_2_ssh)
results_map_area$map_at_5 <- c(map_at_5_ls, map_at_5_mint, map_at_5_ssh)

# ---------------------------------------------------------------------------- #
# summarise results for variances as well
results_vap <- data.frame(model = NA, embedding = NA, years = NA, text = NA,
                          vap_at_2 = NA, vap_at_5 = NA)
# and for areas
results_vap_area <- data.frame(model = NA, embedding = NA, years = NA,
                               text = NA, area = c("LS", "MINT", "SSH"),
                               vap_at_2 = NA, vap_at_5 = NA)
# assign results: overall
# define setting
results_vap$model <- all_settings$model[test_idx]
results_vap$embedding <- all_settings$embedding[test_idx]
results_vap$years <- all_settings$years[test_idx]
results_vap$text <- all_settings$text[test_idx]
# assign map 2 and 5
results_vap$vap_at_2 <- vap_at_2
results_vap$vap_at_5 <- vap_at_5

# ---------------------------------------------------------------------------- #
# assign results: by research area
# define setting
results_vap_area$model <- rep(all_settings$model[test_idx], 3)
results_vap_area$embedding <- rep(all_settings$embedding[test_idx], 3)
results_vap_area$years <- rep(all_settings$years[test_idx], 3)
results_vap_area$text <- rep(all_settings$text[test_idx], 3)
# assign map 2 and 5
results_vap_area$vap_at_2 <- c(vap_at_2_ls, vap_at_2_mint, vap_at_2_ssh)
results_vap_area$vap_at_5 <- c(vap_at_5_ls, vap_at_5_mint, vap_at_5_ssh)

# ---------------------------------------------------------------------------- #
