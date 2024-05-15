# ---------------------------------------------------------------------------- #
# Get Text Embeddings depending on the settings
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# define function to get embeddings using the transformers
# feed in the unfiltered, unprocessed text as transformers learn the context
# and have been trained on plain text as such, only lowercase transformation
get_deep_embeddings <- function(text_df, model, token, truncation, file_name) {
  
  # store the applicants/referee data to be loaded by python script
  rio::export(text_df, here("python", "data", "text_data.csv"))
  # store the model params to be used in the python script as well
  model_params <- data.frame(name = model,
                             token = token,
                             truncation = truncation)
  # and export
  rio::export(model_params, here("python", "data", "model_params.csv"))
  
  # time the computations
  start_time <- Sys.time()
  # run python script using reticulate connection
  reticulate::source_python(file = here("python", "get_text_embeddings.py"),
                            envir = NULL, convert = FALSE)
  # print time
  end_time <- Sys.time()
  print(paste0("Time for extracting embeddings: ",
               round(difftime(end_time, start_time, units = 'mins'), 2),
               " minutes."))
  
  # load the embeddings
  text_embeddings <- rio::import(here("python", "data", "embeddings.csv"),
                                 header = TRUE, dec = ".", sep = ",")
  # and save them into current folder
  rio::export(text_embeddings, here("data", "input",
                                    paste0(file_name, "_embeddings.csv")))
  
  # and convert them to desired format
  text_embeddings <- text_embeddings %>%
    set_rownames(.$doc_id) %>%
    select(-doc_id)
  
  # save the embeddings for future use (take care of allenai/ and google/)
  save(text_embeddings,
       file = here("data", "embeddings",
                   paste0(file_name, "_embeddings_",
                          stri_replace_all_regex(model,
                                                 c("google/", "allenai/",
                                                   "sentence-transformers/"),
                                                 "", vectorize = FALSE),
                          ".RData")))
  # call garbage collection
  gc()
  
  # return the embeddings as dfm
  return(as.dfm(text_embeddings))
  
}

# ---------------------------------------------------------------------------- #
# define function to get embeddings using tfidf
# pre-filter and pre-processed text accordingly using quanteda
get_bag_embeddings <- function(text_df, token, concatenate) {
  
  # concatenate the texts of publications if desired for tfidf
  if (concatenate) {
    # check if we are handling referee data
    if ("ref_id" %in% colnames(text_df)) {
      # then concatenate the publication texts
      text_df <- text_df %>%
        # group by at referee level
        group_by(ref_id) %>%
        # and summarize by concatenation text-data column
        summarise(text_data = paste(text_data, collapse = ". ")) %>%
        # and add doc_id back equal to ref_id
        mutate(doc_id = as.character(ref_id))
    }
  }
  
  # time the computations
  start_time <- Sys.time()
  
  # Convert texts to quanteda corpus data structure
  text_corp <- corpus(text_df, text_field = "text_data")
  
  # preprocess the text corpus into tokens
  tokens_of_corp <- tokens(text_corp,
                           remove_punct = TRUE,
                           remove_symbols = FALSE,
                           remove_numbers = FALSE,
                           remove_url = FALSE,
                           remove_separators = TRUE,
                           include_docvars = TRUE) %>%
    # and remove tokens with uninformative characters
    tokens_remove(c("|", "NULL", "NA", ""))
  
  # Keep 1-grams, 2-grams, ... max_ngram of texts depending in settings
  if (token == "uni_gram") {
    # get only unigrams
    tokens_with_ngrams <- tokens_ngrams(tokens_of_corp, n = 1)
  } else {
    # extract the n-grams
    n_grams <- as.numeric(gsub("\\D", "", token))
    # get up to n-grams
    tokens_with_ngrams <- tokens_ngrams(tokens_of_corp, n = 1:n_grams)
  }
  
  # Construct document-frequency matrix, lower case and remove punctuation
  df_mat <- dfm(tokens_with_ngrams,
                tolower = TRUE,
                remove_punct = TRUE) %>%
    # Removes stop words from unigrams, but not higher-order n-grams
    dfm_remove(stopwords("english")) %>%
    # perform stemming of english words
    dfm_wordstem() %>%
    # remove words of length 1 as these are uninformative
    dfm_select(min_nchar = 2)
  
  # Weight the dfm by term frequency-inverse document frequency (tf-idf)
  text_embeddings <- dfm_tfidf(df_mat)
  
  # print time
  end_time <- Sys.time()
  print(paste0("Time for extracting embeddings: ",
               round(difftime(end_time, start_time, units='mins'), 2),
               " minutes."))
  
  # call garbage collection
  gc()
  
  # return the embeddings as dfm
  return(text_embeddings)
}

# ---------------------------------------------------------------------------- #
# prepare the input files for the transformers/tfidf
# get the number of papers for each referee (use rownames that already exist)
# and replace dot with - due to csv import that truncates the decimals
ref_texts$doc_id <- str_replace(rownames(ref_texts), "\\.", "-")
# and the names of document ids for applicants too
app_texts$doc_id <- app_texts$ApplicationId

# ---------------------------------------------------------------------------- #
# extract embeddings depending on the model
if (method_selection == "transformers") {
  # refs
  dfm_refs <- get_deep_embeddings(text_df = ref_texts,
                                  model = all_settings$model[test_idx],
                                  token = all_settings$embedding[test_idx],
                                  truncation = truncation,
                                  file_name = "ref_data")
  
  # apps
  dfm_apps <- get_deep_embeddings(text_df = app_texts,
                                  model = all_settings$model[test_idx],
                                  token = all_settings$embedding[test_idx],
                                  truncation = truncation,
                                  file_name = "app_data")
  # or tfidf
} else if (method_selection == "tfidf") {
  # refs
  dfm_refs <- get_bag_embeddings(text_df = ref_texts,
                                 token = all_settings$embedding[test_idx],
                                 concatenate = concatenation)
  
  # apps
  dfm_apps <- get_bag_embeddings(text_df = app_texts,
                                 token = all_settings$embedding[test_idx],
                                 concatenate = concatenation)
}

# ---------------------------------------------------------------------------- #
