# ---------------------------------------------------------------------------- #
# Validation of Models for Computing Text Similarity: Main Def Script
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# load libraries
library(tidyverse)
library(magrittr)
library(here)
library(readxl)
library(cld2)
library(stringi)
library(Metrics)
library(quanteda)
library(quanteda.textstats)

# ---------------------------------------------------------------------------- #
# source utility functions
source(here("R", "utils.R"))

# ---------------------------------------------------------------------------- #
# methods: transformers or tfidf
method_selection <- "transformers"

# define model names based on method selection
if (method_selection == "transformers") {
  # models to test
  model_names <- c(
    "bert-base-uncased", # BERT
    "allenai/scibert_scivocab_uncased", # SciBERT
    "allenai/specter2_base" # SPECTER2
    )
} else if (method_selection == "tfidf") {
  # models to test
  model_names <- c(
    "tfidf" # tfidf
  )
} else {
  # throw an error
  stop("Invalid method selection. Must be one of transformers or tfidf. ")
}

# number of models
n_model_names <- length(model_names)

# type of embeddings to extract - different for tfidf and transformers
if (method_selection == "tfidf") {
  # 2 types of embeddings: unigrams and n-grams
  embedding_type <- c(
    # unigrams - only single tokens
    "uni_gram",
    # n-grams - several sequences
    "3_gram"
  )
} else if (method_selection == "transformers") {
  # 2 types of embeddings: cls and pooling
  embedding_type <- c(
    # mean pooling, i.e. average of word tokens for the text chunk
    "mean_pooling",
    # CLS token from the BERT models
    "cls_token"
  )
}

# number of embeddings
n_embedding_type <- length(embedding_type)

# data years
data_years <- c(5, 10)
# number of years
n_data_years <- length(data_years)

# data text
data_text <- c("title", "abstract", "title_abstract")
# number of texts
n_data_text <- length(data_text)
# how should be the texts longer than the context window truncated?
# default from "right", i.e. cutting excess text from the end, from "left"
# truncates the text from the beginning, only relevant for transformer models
if (!str_detect("tfidf", method_selection)) {
  # define truncation side
  truncation <- "right"
} else {
  # no truncation
  truncation <- ""
}
# and specify for tfidf if publication texts should be concatenated
concatenation <- FALSE # handling per publication basis as for transformers

# ---------------------------------------------------------------------------- #
# create matrix of all combinations
all_settings <- matrix(data = NA,
                       nrow = (n_model_names*n_embedding_type*n_data_years*
                                 n_data_text),
                       ncol = 4) %>%
  as.data.frame() %>%
  set_colnames(c("model", "embedding", "years", "text")) %>%
  mutate(model = rep(model_names, n_embedding_type*n_data_years*n_data_text)) %>%
  group_by(model) %>%
  mutate(embedding = sort(rep(embedding_type, n_data_years*n_data_text)),
         years = rep(sort(rep(data_years, n_data_text)), n_embedding_type),
         text = rep(data_text, n_embedding_type*n_data_years))

# summarize the setup
cat(paste0("Alltogether ", nrow(all_settings), " different settings ",
           "will be compared.", "\n\n"))
# save the setup
rio::export(all_settings, here("data", "input", "all_settings.xlsx"))

# ---------------------------------------------------------------------------- #
# define settings for similarities:
# to get per referee level, use only single best pub?
single_best_match <- FALSE
# proportion of best matching publications to be used for final similarity
top_match_per_ref <- 1/5
# how many most frequent keywords/disciplines should be used for output?
n_top_terms <- 5

# save the general settings
general_settings <- data.frame(proportion = top_match_per_ref,
                               truncation = truncation,
                               concatenation = concatenation,
                               method = method_selection)
# save the setup
rio::export(general_settings, here("data", "input", "general_settings.xlsx"))

# ---------------------------------------------------------------------------- #
# download annotated data
source(here("R", "get_validation_data.R"))
# get application texts
source(here("R", "get_application_texts.R"))
# get referee texts
source(here("R", "get_referee_texts.R"))

# ---------------------------------------------------------------------------- #
# prepare storage for results for mean and variance of average precision
results_validation_map <- NULL
results_validation_vap <- NULL
# and by research area as well
results_validation_map_area <- NULL
results_validation_vap_area <- NULL

# start looping through all settings combinations
# parallelization not possible due to limited resources wrt GPU
for (test_idx in 1:nrow(all_settings)) {
  
  # print to console which setting is being tested
  cat(paste("Iteration n. ", test_idx, ": ", all_settings$model[test_idx],
             all_settings$embedding[test_idx], all_settings$years[test_idx],
             all_settings$text[test_idx], "\n\n", sep = " "))
  
  # load in data based on the current settings: years and type of texts
  source(here("R", "subset_text_data.R"))
  
  # process texts based on the model: transformers or tfidf
  source(here("R", "get_text_embeddings.R"))
  
  # compute text similarity
  source(here("R", "get_text_similarity.R"))
  
  # get the top 2 and top 5 matches based on similarities
  source(here("R", "get_top_matches.R"))
  
  # validation of top referees vs assigned referees
  source(here("R", "validate_matches.R"))
  
  # add results for this test round for map at K metric
  results_validation_map <- rbind(results_validation_map, results_map)
  results_validation_map_area <- rbind(results_validation_map_area,
                                       results_map_area)
  
  # add results for this test round for vap at K metric
  results_validation_vap <- rbind(results_validation_vap, results_vap)
  results_validation_vap_area <- rbind(results_validation_vap_area,
                                       results_vap_area)
  
  # save the results in the meantime for MAP
  rio::export(results_validation_map,
              here("data", "output", "validation_results_map.xlsx"))
  # and by research area
  rio::export(results_validation_map_area,
              here("data", "output", "validation_results_map_area.xlsx"))
  
  # as well as variance results
  rio::export(results_validation_vap,
              here("data", "output", "validation_results_vap.xlsx"))
  # and by research area
  rio::export(results_validation_vap_area,
              here("data", "output", "validation_results_vap_area.xlsx"))
  
}

# ---------------------------------------------------------------------------- #
# save the results finally after major loop finished
rio::export(results_validation_map,
            here("data", "output",
                 paste0("validation_results_map_", method_selection,
                        "_trunc_", truncation,
                        "_concatenation_", concatenation, "_proportion_",
                        as.character(round(100*top_match_per_ref)), ".xlsx")))
# and per research area
rio::export(results_validation_map_area,
            here("data", "output",
                 paste0("validation_results_map_area_", method_selection,
                        "_trunc_", truncation,
                        "_concatenation_", concatenation, "_proportion_",
                        as.character(round(100*top_match_per_ref)), ".xlsx")))

# save the results for variance as well
rio::export(results_validation_vap,
            here("data", "output",
                 paste0("validation_results_vap_", method_selection,
                        "_trunc_", truncation,
                        "_concatenation_", concatenation, "_proportion_",
                        as.character(round(100*top_match_per_ref)), ".xlsx")))
# and per research area
rio::export(results_validation_vap_area,
            here("data", "output",
                 paste0("validation_results_vap_area_", method_selection,
                        "_trunc_", truncation,
                        "_concatenation_", concatenation, "_proportion_",
                        as.character(round(100*top_match_per_ref)), ".xlsx")))

# ---------------------------------------------------------------------------- #
# and generate pdf report
rmarkdown::render(here("report.Rmd"),
                  output_dir = here("output", "pdf"),
                  output_file = paste0("validation_report_", method_selection, 
                                       "_truncation_", truncation,
                                       "_concatenation_", concatenation,
                                       "_proportion_",
                                       as.character(round(100*top_match_per_ref)),
                                       ".pdf"))

# ---------------------------------------------------------------------------- #
