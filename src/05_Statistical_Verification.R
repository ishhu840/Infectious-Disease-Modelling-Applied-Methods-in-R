################################################################################
# 16_Lag_Validation_Stats.R — MODEL ACCURACY COMPARISON
# Purpose: Compare Optimal Lags vs. Fixed Standard Lags (Training & Testing).
################################################################################
cat("=== PHASE 1: LAG ROBUSTNESS VALIDATION ===\n")
library(dplyr)

# 1. LOAD DATA
df <- read.csv("../03_Results/processed_data.csv")

# 2. DEFINE COMPARISON FUNCTION
validate_lags <- function(rain_lag, temp_lag) {
  # Build lagged predictive data
  df_lagged <- df %>%
    mutate(
      L_Rain = lag(Rainfall, rain_lag),
      L_Temp = lag(Temperature, temp_lag)
    ) %>%
    filter(!is.na(L_Rain) & !is.na(L_Temp))
  
  # Split: 2013-2022 (Train), 2023-2024 (Test)
  train_data <- df_lagged %>% filter(Year <= 2022)
  test_data <- df_lagged %>% filter(Year >= 2023)
  
  # Linear model on training set
  fit <- lm(cases ~ L_Rain * L_Temp, data = train_data)
  
  # Predictions
  preds_test <- predict(fit, newdata = test_data)
  
  # Pure R metrics (No Metrics package required)
  actuals <- test_data$cases
  r_val <- cor(actuals, preds_test)
  rmse_val <- sqrt(mean((actuals - preds_test)^2))
  r_sq <- summary(fit)$adj.r.squared
  
  return(data.frame(
    Rain_Lag = rain_lag,
    Temp_Lag = temp_lag,
    Testing_Correlation = round(r_val, 3),
    Adj_RSquared = round(r_sq, 3),
    RMSE = round(rmse_val, 1)
  ))
}

# 3. RUN MODELS
cat("  Comparing Optimal (5,10) vs Standard (4,4)...\n")
optimal_stats <- validate_lags(5, 10)
standard_stats <- validate_lags(4, 4)

comparison_table <- rbind(
  cbind(Model_Type = "OPTIMAL (Optimized)", optimal_stats),
  cbind(Model_Type = "STANDARD (Fixed)", standard_stats)
)

# 4. SAVE AND PRINT
write.csv(comparison_table, "../03_Results/lag_robustness_stats.csv", row.names=FALSE)
cat("✓ Lag validation complete. Saved to: ../03_Results/lag_robustness_stats.csv\n")
print(comparison_table)
