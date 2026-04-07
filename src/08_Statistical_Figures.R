################################################################################
# 19_Statistical_Figures.R — PUBLICATION-QUALITY EVIDENCE VISUALS
# Purpose: Create scholarly figures for Lag Validation and Significance.
################################################################################
cat("=== PHASE 4: GENERATING PUBLISHABLE STATISTICAL FIGURES ===\n")
library(dplyr)
library(ggplot2)

# 1. LOAD STATS
lag_stats <- read.csv("../03_Results/lag_robustness_stats.csv")
p_stats <- read.csv("../03_Results/intervention_p_values.csv")

# 2. FIGURE 10: LAG ROBUSTNESS (CORRELATION COMPARISON)
cat("  Generating Lag Comparison Plot...\n")
p10 <- ggplot(lag_stats, aes(x = Model_Type, y = Testing_Correlation, fill = Model_Type)) +
  geom_bar(stat = "identity", width = 0.6, color = "black") +
  geom_text(aes(label = Testing_Correlation), vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("OPTIMAL (Optimized)" = "#2ca02c", "STANDARD (Fixed)" = "#7f7f7f")) +
  labs(title = "Figure 10: Model Validation via Lag Robustness",
       subtitle = "Prediction correlation (r) on 2023-2024 Testing Data.",
       x = "Lag Configuration", y = "Pearson Correlation (r)") +
  theme_minimal() +
  ylim(0, 0.8) +
  theme(legend.position = "none", plot.title = element_text(face="bold"), axis.title = element_text(face="bold"))

ggsave("../04_Figures/fig_10_Lag_Validation_Stats.png", p10, width = 8, height = 5)

# 3. FIGURE 11: INTERVENTION SIGNIFICANCE SUMMARY
cat("  Generating Significance Summary Plot (Baseline Comparison with Significance Stars)...\n")

# Format P-values as stars for display (standard academic shorthand)
p_stats_clean <- p_stats %>%
  mutate(P_Label = case_when(
    P_Value < 0.0001 ~ "****",
    P_Value < 0.001 ~ "***",
    P_Value < 0.01 ~ "**",
    P_Value < 0.05 ~ "*",
    TRUE ~ "ns"
  ))

# Prepare comparison data: Baseline vs Interventions
df_baseline <- p_stats_clean %>% 
  group_by(Year) %>% 
  summarise(Scenario = "Baseline (No ISV)", Total_Cases = unique(Baseline_Total), P_Label = "") %>%
  distinct()

df_intv <- p_stats_clean %>% 
  select(Year, Scenario, Total_Cases = Intv_Total, P_Label)

plot_data <- bind_rows(df_baseline, df_intv)
plot_data$Scenario <- factor(plot_data$Scenario, levels = c("Baseline (No ISV)", "March", "April", "May", "June", "August"))

p11 <- ggplot(plot_data, aes(x = Scenario, y = Total_Cases, fill = Scenario)) +
  facet_wrap(~Year, scales = "free_y") +
  geom_bar(stat = "identity", width = 0.7, color = "black", alpha = 0.9) +
  # Case count label (comma formatted)
  geom_text(aes(label = scales::comma(Total_Cases)), vjust = -0.5, fontface = "bold", size = 3) +
  # Significance stars (font size increased for clarity)
  geom_text(aes(label = P_Label), vjust = -1.8, fontface = "bold", size = 4.5, color = "darkred") +
  
  scale_fill_manual(values = c("Baseline (No ISV)" = "#7f7f7f", "March" = "#2ca02c", "April" = "#1f77b4", 
                               "May" = "#d62728", "June" = "#9467bd", "August" = "#8c564b")) +
  labs(title = "Figure 11: Statistical Impact Profile (Baseline vs ISV Scenarios)",
       subtitle = "Comparative Annual Case Suppression with Significance Stars (**** p < 0.0001).",
       caption = "Baseline: Observed Cases. All interventions achieve high significance (Wilcoxon Signed-Rank Test).",
       x = "Seasonal Timing Strategy", y = "Total Annual Dengue Cases") +
  theme_bw() +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.2))) +
  theme(plot.title = element_text(face="bold", size = 14), axis.title = element_text(face="bold"),
        plot.caption = element_text(color = "darkblue", face = "bold.italic", size = 10),
        legend.position = "none",
        strip.background = element_rect(fill = "grey90"), strip.text = element_text(face="bold"))

ggsave("../04_Figures/fig_11_Significance_Summary.png", p11, width = 11, height = 7)

cat("✓ SUCCESS: ALL PUBLISHABLE STATISTICAL FIGURES GENERATED.\n")
