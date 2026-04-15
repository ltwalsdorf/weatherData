# =============================================================================
# RCBD Analysis — Relative Humidity by Station, Blocking on Temperature
# Climate Coders | Stat 318
#
# Design:
#   Response  : mean relative humidity (relh, %)
#   Treatment : weather station (9 levels)
#   Block     : temperature bin derived from tmpf (5 levels)
#
# Model: relh ~ station + temp_bin
# =============================================================================

library(dplyr)
library(readr)
library(ggplot2)

# -----------------------------------------------------------------------------
# 1. Load Data
# -----------------------------------------------------------------------------

files   <- list.files("data/", pattern = "\\.csv$", full.names = TRUE)
weather <- lapply(files, read_csv, na = "M", show_col_types = FALSE) |>
  bind_rows()

cat("Total observations loaded:", nrow(weather), "\n")
cat("Stations:", paste(sort(unique(weather$station)), collapse = ", "), "\n\n")

# -----------------------------------------------------------------------------
# 2. Filter to 2025, Drop Missing relh / tmpf
# -----------------------------------------------------------------------------

obs <- weather |>
  filter(format(as.Date(valid), "%Y") == "2025",
         !is.na(relh),
         !is.na(tmpf))

cat("Observations after filtering to 2025 and dropping NA:\n")
obs |>
  count(station) |>
  print()
cat("\n")

# -----------------------------------------------------------------------------
# 3. Assign Temperature Bins (Blocks)
# -----------------------------------------------------------------------------

obs <- obs |>
  mutate(temp_bin = cut(
    tmpf,
    breaks = c(-Inf, 25, 45, 60, 75, Inf),
    labels = c("1_Freezing (<25F)",
               "2_Cold (25-44F)",
               "3_Cool (45-59F)",
               "4_Mild (60-74F)",
               "5_Warm/Hot (>=75F)"),
    right  = FALSE
  ))

cat("Hourly observations per temperature bin:\n")
print(table(obs$temp_bin))
cat("\n")

# -----------------------------------------------------------------------------
# 4. Compute Experimental Units (mean relh per station × temp_bin)
# -----------------------------------------------------------------------------

units <- obs |>
  group_by(station, temp_bin) |>
  summarise(
    mean_relh = mean(relh),
    n_obs     = n(),
    .groups   = "drop"
  )

cat("Experimental units (should be 45 rows — 9 stations × 5 bins):\n")
print(units, n = 45)
cat("\n")

# Flag any sparse cells (fewer than 30 hourly observations)
sparse <- units |> filter(n_obs < 30)
if (nrow(sparse) > 0) {
  cat("WARNING: sparse cells (< 30 obs) — means may be unreliable:\n")
  print(sparse)
  cat("\n")
} else {
  cat("All cells have >= 30 observations. No sparsity concerns.\n\n")
}

# Confirm design is complete (no missing station × bin combinations)
n_cells <- nrow(units)
if (n_cells < 45) {
  cat("WARNING: only", n_cells, "of 45 cells present — design is incomplete.\n\n")
} else {
  cat("Design is complete: all 45 cells populated.\n\n")
}

# -----------------------------------------------------------------------------
# 5. Descriptive Summary
# -----------------------------------------------------------------------------

cat("Mean relh by station (averaged across all temperature bins):\n")
units |>
  group_by(station) |>
  summarise(overall_mean_relh = round(mean(mean_relh), 2)) |>
  arrange(desc(overall_mean_relh)) |>
  print()
cat("\n")

cat("Mean relh by temperature bin (averaged across all stations):\n")
units |>
  group_by(temp_bin) |>
  summarise(overall_mean_relh = round(mean(mean_relh), 2)) |>
  print()
cat("\n")

# -----------------------------------------------------------------------------
# 6. Fit RCBD Model
#    Model: response ~ treatment + block  (additive — no interaction term)
# -----------------------------------------------------------------------------

rcbd_model <- aov(mean_relh ~ station + temp_bin, data = units)

cat("=== RCBD ANOVA Table ===\n")
print(summary(rcbd_model))
cat("\n")

# -----------------------------------------------------------------------------
# 7. Tukey HSD Post-Hoc on Station Effect
# -----------------------------------------------------------------------------

tukey_results <- TukeyHSD(rcbd_model, which = "station")

cat("=== Tukey HSD — Station Pairwise Comparisons ===\n")
print(tukey_results)
cat("\n")

# Extract and display grouping summary (stations ranked by mean relh)
tukey_df <- as.data.frame(tukey_results$station) |>
  tibble::rownames_to_column("comparison") |>
  arrange(`p adj`)

cat("Top significant pairwise differences (p < 0.05):\n")
tukey_df |>
  filter(`p adj` < 0.05) |>
  select(comparison, diff, `lwr`, `upr`, `p adj`) |>
  mutate(across(where(is.numeric), \(x) round(x, 3))) |>
  print()
cat("\n")

# -----------------------------------------------------------------------------
# 8. Residual Diagnostics
# -----------------------------------------------------------------------------

cat("=== Shapiro-Wilk Test on Residuals ===\n")
shapiro_result <- shapiro.test(residuals(rcbd_model))
print(shapiro_result)
if (shapiro_result$p.value < 0.05) {
  cat("WARNING: residuals may not be normally distributed (p < 0.05).\n")
  cat("Consider Friedman test as a non-parametric alternative.\n")
} else {
  cat("Residuals appear normally distributed (p >= 0.05).\n")
}
cat("\n")

# 4-panel diagnostic plot
par(mfrow = c(2, 2))
plot(rcbd_model, main = "RCBD Residual Diagnostics")
par(mfrow = c(1, 1))

# -----------------------------------------------------------------------------
# 9. Interaction Check
#    The RCBD assumes no block × treatment interaction.
#    A significant interaction would mean humidity gaps between stations
#    vary across temperature regimes — violating the additive assumption.
# -----------------------------------------------------------------------------

rcbd_interaction <- aov(mean_relh ~ station * temp_bin, data = units)

cat("=== Interaction F-Test (station × temp_bin) ===\n")
print(anova(rcbd_model, rcbd_interaction))
cat("\n")

interaction_p <- anova(rcbd_model, rcbd_interaction)[2, "Pr(>F)"]
if (!is.na(interaction_p) && interaction_p < 0.05) {
  cat("NOTE: Significant interaction detected (p =", round(interaction_p, 4), ").\n")
  cat("The humidity gap between stations is not consistent across temperature bins.\n")
  cat("Interpret main station effects with caution.\n")
} else {
  cat("No significant interaction (p =", round(interaction_p, 4), ").\n")
  cat("Additive RCBD assumption holds — station main effects are reliable.\n")
}
cat("\n")

# -----------------------------------------------------------------------------
# 10. Non-Parametric Fallback — Friedman Test
#     Run if Shapiro-Wilk flagged non-normality above.
# -----------------------------------------------------------------------------

# Friedman test requires a balanced, complete block design in wide format
units_wide <- units |>
  select(station, temp_bin, mean_relh) |>
  tidyr::pivot_wider(names_from = temp_bin, values_from = mean_relh)

friedman_matrix <- as.matrix(units_wide[, -1])
rownames(friedman_matrix) <- units_wide$station

cat("=== Friedman Test (non-parametric RCBD alternative) ===\n")
print(friedman.test(friedman_matrix))
cat("\n")

# -----------------------------------------------------------------------------
# 11. Visualizations
# -----------------------------------------------------------------------------

# -- 11a. Profile plot: mean relh per station across temperature bins --
plot_profile <- ggplot(units,
                       aes(x = temp_bin, y = mean_relh,
                           color = station, group = station)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2.5) +
  labs(
    title   = "Mean Relative Humidity by Station and Temperature Bin (2025)",
    subtitle = "RCBD: treatment = station, block = temperature bin",
    x       = "Temperature Bin (Block)",
    y       = "Mean Relative Humidity (%)",
    color   = "Station"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

print(plot_profile)

# -- 11b. Bar chart: overall mean relh per station (collapsed across blocks) --
station_means <- units |>
  group_by(station) |>
  summarise(mean_relh = mean(mean_relh), .groups = "drop") |>
  arrange(desc(mean_relh))

plot_bar <- ggplot(station_means,
                   aes(x = reorder(station, -mean_relh), y = mean_relh,
                       fill = station)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = round(mean_relh, 1)), vjust = -0.4, size = 3.5) +
  labs(
    title = "Overall Mean Relative Humidity by Station (2025)",
    x     = "Station",
    y     = "Mean Relative Humidity (%)"
  ) +
  theme_minimal()

print(plot_bar)

# -- 11c. Heatmap of experimental units --
plot_heat <- ggplot(units,
                    aes(x = temp_bin, y = station, fill = mean_relh)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(mean_relh, 1)), size = 3) +
  scale_fill_gradient(low = "#fff7bc", high = "#2171b5",
                      name = "Mean relh (%)") +
  labs(
    title = "Experimental Unit Values: Mean Relative Humidity (2025)",
    x     = "Temperature Bin (Block)",
    y     = "Station (Treatment)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

print(plot_heat)
