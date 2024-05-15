# ---------------------------------------------------------------------------- #
# Get top matches: top 2 and top 5, without any restrictions
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# get the number of apps and refs
n_apps <- length(list_of_apps)
n_refs <- length(list_of_referees)
# get the top2 and top5 - its enough to do 5 and then subset to 2 for evaluation
n_top_refs <- 5

# ---------------------------------------------------------------------------- #
# Get most similar referees for each application
  
# loop through apps
top_refs_result <- lapply(list_of_apps, function(app_idx) {
  
  # get the similarity for the current application
  this_row_sim <- similarities[, app_idx]  # cols are applications
  
  # get top n matches
  top_n <- sort(this_row_sim, decreasing = TRUE)[1:n_top_refs]
  top_refs <- names(top_n)
  
  # return the top refs
  return(top_refs)    
})
# add names for applications
names(top_refs_result) <- list_of_apps

# ---------------------------------------------------------------------------- #
# Construct output df with one row per application, with data about their top
# matched referees

# dataframe for output (for each ref include top disciplines and keywords)
top_refs_for_display <- data.frame(matrix(nrow = n_apps,
                                          ncol = (1 + n_top_refs*3)))

# go through all applications
for (app_idx in list_of_apps) {
  
  # get app data (only app ID)
  app_data <- app_idx
  names(app_data) <- "ApplicationId"
  # get the index of the application ID
  app_id_idx <- which(app_idx == list_of_apps)
  
  # Get storage for referee data
  ref_data <- c()
  
  for (ref_idx in 1:n_top_refs) {
    # get referee id
    ref_id <- top_refs_result[[app_idx]][ref_idx]
    # get the data about referee
    ref_data_here <- get_ref_data_for_display(ref_number = ref_id, ref_idx)
    # take everything together
    ref_data <- c(ref_data, ref_data_here)
  }
  
  # Insert into display df
  this_row <- c(app_data, ref_data)
  top_refs_for_display[app_id_idx, ] <- this_row
}
# add names
colnames(top_refs_for_display) <- names(this_row)

# specify the file name for saving
outfilename <- paste0(here("data", "output", dataset,
                           paste0("top_referees_", method_selection, "_", 
                                  "truncation_", truncation, "_",
                                  "concatenation_", concatenation, "_",
                                  stri_replace_all_regex(str_replace_all(
                                    paste(all_settings[test_idx, ],
                                          collapse = "_"), "-", "_"),
                                    c("google/", "allenai/",
                                      "sentence_transformers/"),
                                    "", vectorize = FALSE), ".xlsx")))

# store the data in the similarity folder
if (!file.exists(here("data", "output", dataset))) {
  dir.create(here("data", "output", dataset))
}

# save the excel sheet
rio::export(top_refs_for_display, file = outfilename)

# ---------------------------------------------------------------------------- #
