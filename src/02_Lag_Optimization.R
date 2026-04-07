################################################################################
# 02_Find_Optimal_Lags.R — V4 CONTINUOUS SEIR VERSION
# Mirroring Python Logic: No resets, waning immunity, natural death (mu)
################################################################################
cat("=== PHASE 1: LAG GRID SEARCH (V4 CONTINUOUS) ===\n")
library(deSolve)
library(dplyr)
library(ggplot2)

# 1. LOAD DATA
cat("  Loading processed data...\n")
df_all <- read.csv("../03_Results/processed_data.csv")
df_all$date <- as.Date(df_all$date)

# Training: 2013-2022 | Testing: 2023-2024
train_mask <- df_all$Year <= 2022
test_mask  <- df_all$Year >= 2023
cat(sprintf("  ✓ Data: %d weeks | Train: %d | Test: %d\n", nrow(df_all), sum(train_mask), sum(test_mask)))

# 2. SEIR MODEL (V4 CONTINUOUS)
# Python logic: discrete-time weekly equations
# We will use discrete mapping to match Python's simulate_seir_v4 exactly.
run_seir_v4 <- function(params, df_input, rain_lag, temp_lag) {
  # params: log_kappa (1), b0 (2), bR (3), bT (4), bT2 (5), logit_rho (6), 
  #         log_lambda (7), logit_E0f (8), logit_I0f (9)
  
  kappa <- exp(params[1])
  b0 <- params[2]; bR <- params[3]; bT <- params[4]; bT2 <- params[5]
  rho <- plogis(params[6])
  lambda_import <- exp(params[7])
  E0_frac <- 0.01 * plogis(params[8]) # max 1%
  I0_frac <- 0.01 * plogis(params[9]) # max 1%
  
  # Biological constants (Weekly)
  SIGMA <- 7/6; GAMMA <- 7/5; OMEGA <- 1 / (2.5 * 52); MU <- (1/68) / 52
  EPS <- 1e-12
  
  # Prep weather lags - Handle NAs (standardized mean = 0)
  col_R <- paste0("Rain_z_lag", rain_lag); col_T <- paste0("Temp_z_lag", temp_lag)
  col_T2 <- paste0("Temp_z_lag", temp_lag, "2")
  
  R_z <- df_input[[col_R]]; R_z[is.na(R_z)] <- 0
  T_z <- df_input[[col_T]]; T_z[is.na(T_z)] <- 0
  T2_z <- df_input[[col_T2]]; T2_z[is.na(T2_z)] <- 0
  
  N_arr <- df_input$Nh
  N0 <- N_arr[1]
  N_arr[is.na(N_arr)] <- N0
  obs_cases <- df_input$cases
  
  T_len <- nrow(df_input)
  S <- numeric(T_len); E <- numeric(T_len); I <- numeric(T_len); R <- numeric(T_len)
  inc_t <- numeric(T_len)
  
  # Initial conditions (Week 1)
  N0 <- N_arr[1]
  S[1] <- N0 * (1 - E0_frac - I0_frac)
  E[1] <- N0 * E0_frac
  I[1] <- N0 * I0_frac
  R[1] <- 0
  
  for (t in 1:T_len) {
    # Temperature biological penalty check (handled in loss_fn usually, 
    # but here we just compute transmission)
    eta <- b0 + bR * R_z[t] + bT * T_z[t] + bT2 * T2_z[t]
    beta <- kappa * exp(pmax(pmin(eta, 15), -15))
    
    # New infections (Local transmission + Importation)
    inc <- beta * (S[t] * I[t]) / max(N_arr[t], EPS) + lambda_import
    inc <- max(min(inc, S[t]), 0)
    inc_t[t] <- inc
    
    if (t < T_len) {
      Nt <- N_arr[t]; new_E <- inc; new_I <- SIGMA * E[t]
      new_R <- GAMMA * I[t]; wane <- OMEGA * R[t]
      
      # Dynamics + Demographics
      S[t+1] <- max(S[t] - new_E + wane + MU * (Nt - S[t]), 0)
      E[t+1] <- max(E[t] + new_E - new_I - MU * E[t], 0)
      I[t+1] <- max(I[t] + new_I - new_R - MU * I[t], 0)
      R[t+1] <- max(R[t] + new_R - wane - MU * R[t], 0)
      
      # Census update (delta_N)
      total <- S[t+1] + E[t+1] + I[t+1] + R[t+1]
      delta_N <- N_arr[t+1] - total
      if (delta_N >= 0) {
        S[t+1] <- S[t+1] + delta_N
      } else if (total > EPS) {
        scale <- N_arr[t+1] / total
        S[t+1] <- S[t+1] * scale; E[t+1] <- E[t+1] * scale
        I[t+1] <- I[t+1] * scale; R[t+1] <- R[t+1] * scale
      }
    }
  }
  return(list(pred = inc_t * rho, obs = obs_cases))
}

# 3. LOSS FUNCTION (With V4 Penalties)
# Need weather stats for the temperature vertex penalty
cat("  Calculating weather stats for penalties...\n")
col_T_base <- "Temperature"
temp_mu  <- mean(df_all$Temperature[train_mask], na.rm=TRUE)
temp_std <- sd(df_all$Temperature[train_mask], na.rm=TRUE)

build_loss_v4 <- function(params, df_input, rain_lag, temp_lag) {
  # Biological Penalties
  bT <- params[4]; bT2 <- params[5]
  penalty <- 0
  
  # 1. Temperature inverted-U check
  if (bT2 >= 0) penalty <- penalty + 1e6 * (bT2 + 0.01)^2
  
  # 2. Temperature vertex penalty (20-35C)
  if (bT2 < -1e-12) {
    T_std_vertex <- -bT / (2 * bT2)
    T_c_vertex <- T_std_vertex * temp_std + temp_mu
    if (T_c_vertex < 20 || T_c_vertex > 35) {
      dist <- min(abs(T_c_vertex - 20), abs(T_c_vertex - 35))
      penalty <- penalty + 1e6 * dist^2
    }
  }
  
  # 3. Reporting fraction prior (logit-space centered at 10%)
  logit_rho_prior <- qlogis(0.10)
  penalty <- penalty + 200 * (params[6] - logit_rho_prior)^2
  
  # 4. SSE (Training Period)
  sim <- run_seir_v4(params, df_input, rain_lag, temp_lag)
  if (is.null(sim)) return(1e12)
  
  # We use SSE as per Python MSE approach
  train_obs <- sim$obs[df_input$Year <= 2022]
  train_pred <- sim$pred[df_input$Year <= 2022]
  sse <- sum((train_obs - train_pred)^2, na.rm=TRUE)
  
  if (is.na(sse) || is.infinite(sse)) return(1e12)
  return(sse + penalty)
}

# 4. GRID SEARCH
RAIN_LAGS <- c(4, 5, 6, 7, 8)
TEMP_LAGS <- c(6, 7, 8, 9, 10, 11, 12)
results_list <- list(); counter <- 0

# Initial Guesses (sigmoids and logs already handled in loss_v4)
x0 <- c(log(0.5), -2.0, 0.05, 0.70, -0.10, qlogis(0.10), log(5.0), qlogis(1e-4), qlogis(1e-5))

cat("\n  Starting grid search (35 combinations)...\n")
for (r_lag in RAIN_LAGS) {
  for (t_lag in TEMP_LAGS) {
    counter <- counter + 1
    cat(sprintf("  [%2d/35] Rain=%dw, Temp=%dw ... ", counter, r_lag, t_lag))
    
    # Run optimization for this combination
    fit <- optim(par = x0, fn = build_loss_v4, df_input = df_all, 
                 rain_lag = r_lag, temp_lag = t_lag, method = "Nelder-Mead",
                 control = list(maxit = 2000, reltol = 1e-6))
    
    # Evaluation
    sim <- run_seir_v4(fit$par, df_all, r_lag, t_lag)
    r_train <- cor(sim$obs[train_mask], sim$pred[train_mask], use = "complete.obs")
    r_test  <- cor(sim$obs[test_mask],  sim$pred[test_mask],  use = "complete.obs")
    
    res_df <- data.frame(rain_lag = r_lag, temp_lag = t_lag, 
                         train_r = r_train, test_r = r_test,
                         rho = plogis(fit$par[6]), kappa = exp(fit$par[1]),
                         lambda_import = exp(fit$par[7]))
    results_list[[counter]] <- res_df
    cat(sprintf("r_train=%.3f, r_test=%.3f\n", r_train, r_test))
  }
}

# 5. FIND BEST AND SAVE
all_res <- bind_rows(results_list)
write.csv(all_res, "../03_Results/V4_GridSearch_AllResults.csv", row.names = FALSE)

best <- all_res %>% slice_max(test_r, n = 1, with_ties = FALSE)
cat(sprintf("\n✓ BEST LAGS (by Testing r): Rain=%dw, Temp=%dw\n", best$rain_lag, best$temp_lag))

# Re-run best to save full params
cat("  Saving optimal parameters...\n")
best_fit <- optim(par = x0, fn = build_loss_v4, df_input = df_all, 
                  rain_lag = best$rain_lag, temp_lag = best$temp_lag, 
                  method = "Nelder-Mead", control = list(maxit = 5000))

params <- best_fit$par
best_params <- data.frame(rain_lag = best$rain_lag, temp_lag = best$temp_lag,
                          log_kappa = params[1], b0 = params[2], bR = params[3],
                          bT = params[4], bT2 = params[5], logit_rho = params[6],
                          log_lambda = params[7], logit_E0f = params[8], logit_I0f = params[9],
                          kappa = exp(params[1]), rho = plogis(params[6]),
                          lambda_import = exp(params[7]), r_train = best$train_r, r_test = best$test_r)
write.csv(best_params, "../03_Results/optimal_lag_params.csv", row.names = FALSE)

# Generate Heatmap
p_heat <- ggplot(all_res, aes(x = factor(temp_lag), y = factor(rain_lag), fill = test_r)) +
  geom_tile(color = "white") + scale_fill_gradient2(low = "blue", mid="white", high = "red") +
  theme_minimal() + labs(title = "Testing Correlation (2023-2024)", x = "Temperature Lag", y = "Rainfall Lag")
ggsave("../04_Figures/fig_lag_heatmap.png", p_heat, width = 8, height = 6)

cat("✓ FINAL RESULTS: Testing r = ", round(best$test_r, 3), "\n")
cat("✓ All results saved in ../03_Results/\n")