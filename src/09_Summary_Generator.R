################################################################################
# 14_Final_Summary_Table.R — PhD REPORT CONSOLIDATED RESULTS
# Purpose: Generate the final impact table for 2023 and 2024 interventions.
################################################################################
cat("=== PHASE 3: GENERATING FINAL SUMMARY TABLE ===\n")
library(dplyr)

# 1. LOAD DATA
df_all <- read.csv("../03_Results/processed_data.csv")
df_all$date <- as.Date(df_all$date)

# 2. ISV SHIELD LOGIC (DYNAMIC VERTICAL TRANSMISSION)
calculate_isv_stats <- function(year_val, release_week, target_blocking=0.75) {
  df_yr <- df_all %>% filter(Year == year_val)
  actual_vec <- df_yr$cases
  weeks_vec <- df_yr$Week
  
  shielded_vec <- actual_vec
  k <- 0.08 # Slower growth constant (Vertical Spread)
  
  for (i in 1:length(actual_vec)) {
    if (weeks_vec[i] >= release_week) {
        weeks_since <- weeks_vec[i] - release_week
        current_blocking <- target_blocking * (1 - exp(-k * weeks_since))
        shielded_vec[i] <- actual_vec[i] * (1 - current_blocking)
    }
  }
  
  total_actual <- sum(actual_vec, na.rm=TRUE)
  total_shielded <- sum(shielded_vec, na.rm=TRUE)
  prevented <- total_actual - total_shielded
  reduction_pct <- 100 * (1 - total_shielded / total_actual)
  
  return(data.frame(
    Year = year_val,
    Release_Month = case_when(
        release_week == 10 ~ "March",
        release_week == 14 ~ "April",
        release_week == 19 ~ "May"
    ),
    ISV_Release_Quantity = "50,000",
    Baseline_Cases = total_actual,
    Cases_Prevented = round(prevented, 0),
    Reduction_Success = sprintf("%.1f%%", reduction_pct)
  ))
}

# 3. RUN ALL SCENARIOS
results <- bind_rows(
  calculate_isv_stats(2023, 10),
  calculate_isv_stats(2023, 14),
  calculate_isv_stats(2023, 19),
  calculate_isv_stats(2024, 10),
  calculate_isv_stats(2024, 14),
  calculate_isv_stats(2024, 19)
)

# 4. SAVE RESULTS
out_path <- "../03_Results/final_intervention_summary.csv"
write.csv(results, out_path, row.names = FALSE)
cat(sprintf("✓ Saved full summary to: %s\n", out_path))

# DISPLAY TO CONSOLE
print(results)
