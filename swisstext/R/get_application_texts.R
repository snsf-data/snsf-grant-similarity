# ---------------------------------------------------------------------------- #
# Download text data about applications
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# Define dataset parameters
dataset <- "pdm_aug21"

# and the corresponding paths
if (!file.exists(here("data", "input"))) {
  dir.create(here("data", "input"))
  dir.create(here("data", "output"))
}
# and for dataset itself
if (!file.exists(here("data", "input", dataset))) {
  dir.create(here("data", "input", dataset))
  dir.create(here("data", "output", dataset))
}

# ---------------------------------------------------------------------------- #
# Application info

# List of Application IDs to use
app_names_to_keep <- validation_data$`Corresponding Applicant`
app_ids_to_keep <- validation_data$ApplicationId

# ---------------------------------------------------------------------------- #
# Download the applications from excel
app_texts_full <- read_excel(here("data", "input", dataset,
                                  "application_list.xlsx")) %>%
  # and only keep application with english texts (only relevant for validation)
  # new column indicating the language
  mutate(title_language = detect_language(Title),
         abstract_language = detect_language(Abstract)) %>%
  # filter the english ones only
  filter(title_language == "en" & abstract_language == "en") %>%
  # filter out the proposals to keep based on Ids
  filter(ApplicationId %in% app_ids_to_keep) %>%
  # select ID and text vars
  select(Number, ApplicationId, Title, Keywords, Abstract, MainDiscipline,
         SecondaryDisciplines) %>%
  # clear secondary disciplines
  mutate(SecondaryDisciplines = str_sans_NULL(SecondaryDisciplines)) %>%
  # concatenate main and secondary disciplines
  unite(col = "disciplines", c("MainDiscipline", "SecondaryDisciplines"),
        sep = '; ', remove = TRUE) %>%
  # clean the disciplines off NULL and NAs
  mutate(disciplines = str_sans_NULL(disciplines))

# ---------------------------------------------------------------------------- #
