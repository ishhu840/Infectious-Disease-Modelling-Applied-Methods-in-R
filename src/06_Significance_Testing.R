################################################################################
# 17_Intervention_PValues.R — SIGNIFICANCE TESTING
# Purpose: Calculate P-values and effect sizes for the ISV intervention impact.
################################################################################
cat("=== PHASE 2: INTERVENTION SIGNIFICANCE TESTING ===\n")
library(dplyr)

# 1. LOAD DATA
df_all <- read.csv("../03_Results/processed_data.csv")

# 2. DYNAMIC ISV LOGIC (From previous optimization)
calculate_isv_shield <- function(actual_vec, weeks_vec, release_week, target_blocking=0.75) {
  shielded_vec <- actual_vec
  k <- 0.08 # Slower biological growth (Agreed)
  for (i in 1:length(actual_vec)) {
    if (weeks_vec[i] >= release_week) {
        weeks_since <- weeks_vec[i] - release_week
        current_blocking <- target_blocking * (1 - exp(-k * weeks_since))
        shielded_vec[i] <- actual_vec[i] * (1 - current_blocking)
    }
  }
  return(shielded_vec)
}

# 3. RUN TESTS
years <- c(2023, 2024)
release_months <- list(March=10, April=14, May=19, June=23, August=31)
results_list <- list()

for (yr in years) {
  df_yr <- df_all %>% filter(Year == yr)
  actual_cases <- df_yr$cases
  weeks <- df_yr$Week
  
  for (m_name in names(release_months)) {
    rel_week <- release_months[[m_name]]
    # CFAV Biological Refinement: 82% Efficacy
    intv_cases <- calculate_isv_shield(actual_cases, weeks, rel_week, target_blocking = 0.82)
    
    # Wilcoxon Signed-Rank Test (Non-parametric for count data)
    test_res <- wilcox.test(actual_cases, intv_cases, paired = TRUE, alternative = "greater")
    
    # Calculate Magnitude of Impact
    reduction_pct <- 100 * (1 - sum(intv_cases)/sum(actual_cases))
    
    results_list[[paste(yr, m_name)]] <- data.frame(
      Year = yr,
      Scenario = m_name,
      Baseline_Total = sum(actual_cases),
      Intv_Total = sum(intv_cases),
      P_Value = test_res$p.value,
      Is_Significant = ifelse(test_res$p.value < 0.05, "YES", "NO"),
      Reduction_Impact = sprintf("%.1f%%", reduction_pct)
    )
  }
}

# 4. SAVE AND PRINT
comparison_table <- bind_rows(results_list)
write.csv(comparison_table, "../03_Results/intervention_p_values.csv", row.names=FALSE)
cat("✓ Significance testing complete. Saved to: ../03_Results/intervention_p_values.csv\n")
print(comparison_table)
