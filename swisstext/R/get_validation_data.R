# ---------------------------------------------------------------------------- #
# Get validation data
# ---------------------------------------------------------------------------- #

# specify names for validation data
postfix <- "_applications_pdm_aug21.xlsx"

# specify panels
panel_names <- c("LS-B", "LS-M", "MINT-N", "MINT-T", "SSH-S", "SSH-H")

# initiate data storage
validation_data <- NULL
# load the data and add panel indicator
for (panel_idx in panel_names) {
  # load panel data
  panel_data <- read_excel(here("data", "validation",
                                paste0(panel_idx, postfix))) %>%
    # select only first 7 columns (no comments needed)
    select(1:7) %>%
    # add panel indicator
    mutate(panel = panel_idx)
  # bind with full data
  validation_data <- rbind(validation_data, panel_data)
}

# remove NAs
validation_data <- validation_data %>%
  filter(!is.na(ApplicationId))

# ---------------------------------------------------------------------------- #
