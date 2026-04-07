################################################################################
# 01_Data_Prep.R - Phase 1: Data Preparation
################################################################################

cat("=== PHASE 1: DATA PREPARATION ===\n")

library(readxl)
library(dplyr)
library(lubridate)
library(ggplot2)

# Configuration
DATA_DIR <- "6 April/01_Data"
RESULT_DIR <- "6 April/03_Results"
FIGURE_DIR <- "6 April/04_Figures"

dir.create(RESULT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIGURE_DIR, recursive = TRUE, showWarnings = FALSE)

CITY <- "Rawalpindi"
TRAIN_END <- 2022
TEST_START <- 2023

RAIN_LAGS <- c(4, 5, 6, 7, 8)
TEMP_LAGS <- c(6, 7, 8, 9, 10, 11, 12)

# Load data
cat("Loading data...\n")
d1 <- read_excel(file.path(DATA_DIR, "D1_Weekly_Cases_Weather_AllCities.xlsx"))
d2 <- read_excel(file.path(DATA_DIR, "D2_Population_2017_2023.xlsx"))

# Filter Rawalpindi
df <- d1 %>%
  filter(City == CITY) %>%
  arrange(Year, Week) %>%
  mutate(
    date = make_date(Year, 1, 1) + weeks(Week - 1),
    cases = as.numeric(`Number of Dengue Cases`)
  )

cat(sprintf("Rawalpindi: %d weeks (%d-%d)\n", nrow(df), min(df$Year), max(df$Year)))

# Create lag columns
add_lags <- function(df, var, lags) {
  for (lag in lags) {
    new_name <- paste0(var, "_lag", lag)
    df[[new_name]] <- lag(df[[var]], n = lag)
  }
  return(df)
}

df <- add_lags(df, "Rainfall", RAIN_LAGS)
df <- add_lags(df, "Temperature", TEMP_LAGS)

# Population interpolation
pop_row <- d2 %>% filter(City == CITY)
N_2017 <- pop_row$`Population 2017`
N_2023 <- pop_row$`Population 2023`

df <- df %>%
  mutate(
    Nh = N_2017 + (N_2023 - N_2017) * (Year - 2017) / (2023 - 2017)
  )

# Standardize weather (training period only)
cat("Standardizing weather...\n")
train_mask <- df$Year <= TRAIN_END

for (lag in RAIN_LAGS) {
  col_raw <- paste0("Rainfall_lag", lag)
  col_z <- paste0("Rain_z_lag", lag)
  mu <- mean(df[[col_raw]][train_mask], na.rm = TRUE)
  sd_val <- sd(df[[col_raw]][train_mask], na.rm = TRUE)
  sd_val <- ifelse(is.na(sd_val) || sd_val == 0, 1, sd_val)
  df[[col_z]] <- (df[[col_raw]] - mu) / sd_val
}

for (lag in TEMP_LAGS) {
  col_raw <- paste0("Temperature_lag", lag)
  col_z <- paste0("Temp_z_lag", lag)
  mu <- mean(df[[col_raw]][train_mask], na.rm = TRUE)
  sd_val <- sd(df[[col_raw]][train_mask], na.rm = TRUE)
  sd_val <- ifelse(is.na(sd_val) || sd_val == 0, 1, sd_val)
  df[[col_z]] <- (df[[col_raw]] - mu) / sd_val
  df[[paste0(col_z, "2")]] <- df[[col_z]]^2
}

# Save processed data
write.csv(df, file.path(RESULT_DIR, "processed_data.csv"), row.names = FALSE)
cat(sprintf("Saved: %s\n", file.path(RESULT_DIR, "processed_data.csv")))

cat("\n=== PHASE 1 COMPLETE ===\n")