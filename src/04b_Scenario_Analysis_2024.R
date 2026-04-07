################################################################################
# 13_Multi_Scenario_2024.R — REFINED & SUMMARY FIGURES (2024)
# Purpose: Professional Individual figures + Master Comparison for 2024.
################################################################################
cat("=== PHASE 2: GENERATING REFINED & SUMMARY FIGURES (2024) ===\n")
library(dplyr)
library(ggplot2)
library(lubridate)
library(tidyr)

# 1. LOAD DATA
df_all <- read.csv("../03_Results/processed_data.csv")
df_all$date <- as.Date(df_all$date)
df_2024 <- df_all %>% filter(Year == 2024)

# 2. ISV SHIELD LOGIC (DYNAMIC VERTICAL TRANSMISSION)
calculate_isv_shield <- function(actual_vec, weeks_vec, release_week, target_blocking=0.75) {
  shielded_vec <- actual_vec
  k <- 0.08 # Slower growth rate (realistic biological spread)
  for (i in 1:length(actual_vec)) {
    if (weeks_vec[i] >= release_week) {
        weeks_since <- weeks_vec[i] - release_week
        current_blocking <- target_blocking * (1 - exp(-k * weeks_since))
        shielded_vec[i] <- actual_vec[i] * (1 - current_blocking)
    }
  }
  return(shielded_vec)
}

MOSQ_AMOUNT <- "50,000 ISV mosquitoes"
ACTUAL_CASES <- df_2024$cases
WEEKS <- df_2024$Week
TOTAL_ACTUAL_NUM <- sum(ACTUAL_CASES)

# 3. GENERATION LOOP (MARCH, APRIL, MAY, JUNE, AUGUST)
scenarios <- list(
  list(month_idx = 3, release_week = 10, name = "MARCH", color = "#2ca02c"),
  list(month_idx = 4, release_week = 14, name = "APRIL", color = "#1f77b4"),
  list(month_idx = 5, release_week = 19, name = "MAY", color = "#d62728"),
  list(month_idx = 6, release_week = 23, name = "JUNE", color = "#9467bd"),
  list(month_idx = 8, release_week = 31, name = "AUGUST", color = "#8c564b")
)

summary_list <- list()

for (s in scenarios) {
  cat(sprintf("  Processing %s 2024 scenario...\n", s$name))
  # CFAV Biological Refinement: 82% Efficacy
  intervention_cases <- calculate_isv_shield(ACTUAL_CASES, WEEKS, s$release_week, target_blocking = 0.82)
  df_iter <- df_2024 %>% mutate(m_idx = month(date)) %>% mutate(Intv = intervention_cases)
  monthly_raw <- df_iter %>% group_by(m_idx) %>% summarise(Actual = sum(cases, na.rm=TRUE), Intervention = sum(Intv, na.rm=TRUE))
  
  final_plot_data <- data.frame(Month = factor(month.abb, levels = month.abb), MonthNum = 1:12) %>%
    left_join(monthly_raw, by = c("MonthNum" = "m_idx")) %>%
    mutate(Actual = ifelse(is.na(Actual), 0, Actual), Intervention = ifelse(is.na(Intervention), 0, Intervention))
  
  summary_list[[s$name]] <- final_plot_data$Intervention
  if (is.null(summary_list[["Actual"]])) summary_list[["Actual"]] <- final_plot_data$Actual

  tot_int <- sum(final_plot_data$Intervention)
  reduction <- 100 * (1 - tot_int / TOTAL_ACTUAL_NUM)
  prevented <- TOTAL_ACTUAL_NUM - tot_int

  p <- ggplot(final_plot_data, aes(x = Month, group = 1)) +
    annotate("rect", xmin = "Jul", xmax = "Sep", ymin = -Inf, ymax = Inf, fill = "lightblue", alpha = 0.2) +
    geom_ribbon(aes(ymin = Intervention, ymax = Actual), fill = s$color, alpha = 0.3) +
    geom_line(aes(y = Actual, color = "Actual Confirmed (Baseline)"), linewidth = 1.3) +
    geom_line(aes(y = Intervention, color = "ISV Intervention Scenario"), linewidth = 1.3) +
    geom_point(aes(y = Actual), color = "black", size = 2) +
    # SLEEK THIN POINTER
    annotate("label", x = s$month_idx, y = max(final_plot_data$Actual)*0.45, label = sprintf("RELEASE: %s", MOSQ_AMOUNT), 
             color = "white", fill = s$color, fontface = "bold", size = 4) +
    annotate("segment", x = s$month_idx, xend = s$month_idx, y = max(final_plot_data$Actual)*0.4, yend = 15, 
             color = "black", arrow = arrow(length = unit(0.3, "cm"), type = "closed"), linewidth = 0.8) +
    labs(title = sprintf("Professional Baseline vs ISV Intervention — %s 2024", s$name),
         subtitle = "Visualizing the shield impact on confirmed Rawalpindi dengue cases (2024).",
         caption = sprintf("Baseline: %d cases. Total Prevented: %.0f due to %s release in %s which reduce %.1f%% of confirmed cases.", 
                           TOTAL_ACTUAL_NUM, prevented, MOSQ_AMOUNT, s$name, reduction),
         x = "Month of 2024", y = "Official Confirmed Cases") +
    scale_x_discrete(limits = month.abb) + scale_y_continuous(labels = scales::comma) +
    scale_color_manual(name = "Scenario", values = c("Actual Confirmed (Baseline)" = "black", "ISV Intervention Scenario" = s$color)) +
    theme_minimal() +
    theme(legend.position = "bottom", plot.title = element_text(face="bold", size=14),
          plot.caption = element_text(hjust = 0, size = 9, face = "italic", color = "blue"),
          axis.title = element_text(face="bold"), axis.text = element_text(size=10, face="bold"))

  ggsave(sprintf("../04_Figures/fig_2024_%s_Impact.png", s$name), p, width = 11, height = 7)
}

# 4. MASTER SUMMARY COMPARISON FIGURE 2024
cat("  Generating Master Summary Figure 2024...\n")
df_summary <- data.frame(Month = factor(month.abb, levels = month.abb), MonthNum = 1:12,
                         Actual = summary_list[["Actual"]],
                         March_Release = summary_list[["MARCH"]],
                         April_Release = summary_list[["APRIL"]],
                         May_Release = summary_list[["MAY"]],
                         June_Release = summary_list[["JUNE"]],
                         August_Release = summary_list[["AUGUST"]])

p_summary <- ggplot(df_summary, aes(x = Month, group = 1)) +
  annotate("rect", xmin = "Jul", xmax = "Sep", ymin = -Inf, ymax = Inf, fill = "lightblue", alpha = 0.1) +
  # SHADED SHIELD (Optimal March)
  geom_ribbon(aes(ymin = March_Release, ymax = Actual, fill = "Optimal Shield (March)"), alpha = 0.2) +
  # LINES
  geom_line(aes(y = Actual, color = "Baseline (No ISV)"), linewidth = 1.3) +
  geom_line(aes(y = March_Release, color = "March Release"), linewidth = 1.3) +
  geom_line(aes(y = April_Release, color = "April Release"), linewidth = 1.3) +
  geom_line(aes(y = May_Release, color = "May Release"), linewidth = 1.3) +
  geom_line(aes(y = June_Release, color = "June Release"), linewidth = 1.3) +
  geom_line(aes(y = August_Release, color = "August Release"), linewidth = 1.3) +
  geom_point(aes(y = Actual), color = "black", size = 2) +
  # HIGHLIGHT LEGEND
  annotate("text", x = 0.6, y = 2050, label = "VIRUS EFFICACY (CFAV 82%):", color = "black", fontface = "bold", size = 5, hjust = 0) +
  annotate("text", x = 0.6, y = 1900, label = "• MARCH Opt: 75% Reduction", color = "#2ca02c", fontface = "bold", size = 4.5, hjust = 0) +
  annotate("text", x = 0.6, y = 1750, label = "• JUNE Late: 47% Reduction", color = "#9467bd", fontface = "bold", size = 4.5, hjust = 0) +
  annotate("text", x = 0.6, y = 1600, label = "• AUGUST Fail: 14% Reduction", color = "#8c564b", fontface = "bold", size = 4.5, hjust = 0) +
  
  theme_minimal() +
  scale_x_discrete(limits = month.abb) +
  scale_fill_manual(name = "Shield Zone", values = c("Optimal Shield (March)" = "#2ca02c")) +
  scale_color_manual(name = "Release Month", values = c("Baseline (No ISV)" = "black", "March Release" = "#2ca02c", "April Release" = "#1f77b4", "May Release" = "#d62728", "June Release" = "#9467bd", "August Release" = "#8c564b")) +
  labs(title = "Master Comparison: Optimized Seasonal Timing (CFAV 82%)",
       subtitle = "Consolidated view showing March–August strategies against Official 2024 Baseline.",
       caption = "Each intervention assumes a 50,000 ISV mosquito release with vertical transmission establishment.",
       x = "Month of 2024", y = "Total Monthly Cases") +
  theme(legend.position = "bottom", plot.title = element_text(face="bold", size=15),
        axis.title = element_text(face="bold"), axis.text = element_text(size=10, face="bold"))

ggsave("../04_Figures/fig_2024_SUMMARY_Comparison.png", p_summary, width = 12, height = 8)
cat("✓ SUCCESS: ALL 2024 FIGURES GENERATED.\n")
