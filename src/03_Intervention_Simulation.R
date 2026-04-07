# 03_Intervention_Simulation.R
# Core SEIR-ISV Mathematical Engine (V4 Continuous)
# Biological Refinement: CFAV (93% VT)

library(deSolve)

# 1. Biological Parameters (CFAV Verified)
# ----------------------------------------
# Vertical Transmission probability (nu) = 0.93 (Baidaliuk et al. 2019)
# Blocking Efficacy (epsilon) = 0.82 (Zhang et al. 2017)

get_fixed_params <- function() {
  list(
    sigma_h = 1/7,       # Human latent period
    gamma   = 1/5,       # Human infectious period
    omega   = 1/(2.5*365), # Waning immunity (2.5 years)
    mu_h    = 1/(68*365),  # Human natural mortality (68 years)
    a       = 0.35,      # Biting rate (average)
    nu      = 0.93,      # CFAV Vertical Transmission (93%)
    epsilon = 0.82,      # CFAV Blocking Efficacy (82%)
    rho     = 0.10,      # Reporting fraction
    sigma_v = 1/10       # Vector extrinsic incubation period
  )
}

# 2. ODE System Definition
# ------------------------
seir_isv_model <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    
    # Calculate Total Populations
    Nh <- Sh + Eh + Ih + Rh
    Nv <- Sv + Ev + Iv
    
    # Weather-Driven Beta(t) - to be provided by simulation loop
    beta_t <- beta_func(t)
    
    # Force of Infection
    lambda_h <- a * (Iv / Nv) * beta_t
    
    # If Intervention is ACTIVE, reduce vector susceptibility
    # -------------------------------------------------------
    # Superinfection Exclusion (SIE) Shield
    red_factor <- if(is_intervention_active(t)) (1 - epsilon) else 1.0
    lambda_v <- a * (Ih / Nh) * beta_t * red_factor
    
    # Human SEIR Equations
    # --------------------
    dSh <- mu_h*Nh + omega*Rh - lambda_h*Sh - mu_h*Sh
    dEh <- lambda_h*Sh - sigma_h*Eh - mu_h*Eh
    dIh <- sigma_h*Eh - gamma*Ih - mu_h*Ih
    dRh <- gamma*Ih - omega*Rh - mu_h*Rh
    
    # Vector S-E-I Equations
    # ----------------------
    recruit_t <- recruit_func(t, Nv)
    mu_v_t <- mu_v_func(t)
    
    # Vertical Transmission (nu) influences the starting compartment
    # New recruits can enter directly into Iv if vertically infected
    dSv <- recruit_t * (1 - nu) - lambda_v*Sv - mu_v_t*Sv
    dEv <- lambda_v*Sv - sigma_v*Ev - mu_v_t*Ev
    dIv <- sigma_v*Ev + recruit_t*nu - mu_v_t*Iv
    
    return(list(c(dSh, dEh, dIh, dRh, dSv, dEv, dIv)))
  })
}

# SAVE to workspace for use in other scripts
dir.create("ISHTIAQ/03_Results", showWarnings = FALSE, recursive = TRUE)
saveRDS(list(model=seir_isv_model, params=get_fixed_params), "ISHTIAQ/../03_Results/seir_isv_engine.rds")

print("03_Intervention_Simulation.R: Core CFAV Engine Reconstructed (nu=0.93).")
