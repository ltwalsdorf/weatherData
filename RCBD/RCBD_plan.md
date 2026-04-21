# RCBD Experimental Design Plan
## Climate Coders — Stat 318

---

## 1. Overview

We will analyze whether **mean relative humidity differs significantly across Nebraska's 9 ASOS weather stations** after accounting for the effect of air temperature. A Randomized Complete Block Design (RCBD) lets us isolate the station effect (the factor we care about) while blocking out temperature (a strong physical driver of humidity that would confound results if ignored).

---

## 2. Design Structure

| Element       | Definition                                               | Levels                                                    |
| ------------- | -------------------------------------------------------- | --------------------------------------------------------- |
| **Response**  | Mean relative humidity (`relh`, %)                       | Continuous                                                |
| **Treatment** | Weather station (geographic location)                    | 9 stations: AIA, BFF, BIE, BTA, GRI, HSI, LNK, OFK, OMA |
| **Block**     | Temperature bin (removes temperature-driven humidity effect) | 5 bins based on `tmpf` (°F)                           |

**Why block on temperature?** Relative humidity is physically constrained by air temperature — warmer air can hold more moisture, so the same absolute water content produces lower relative humidity at higher temperatures. Without blocking, station differences in humidity could simply reflect station differences in temperature rather than true moisture differences. By grouping observations into temperature bins, we hold thermal conditions approximately constant across blocks and isolate whether stations differ in humidity at the same temperature level — likely reflecting proximity to moisture sources like the Missouri River, differences in elevation, or local land cover.

**Temperature bins:**

| Block | Label     | Range         |
| ----- | --------- | ------------- |
| 1     | Freezing  | `tmpf` < 25°F |
| 2     | Cold      | 25°F – 44°F   |
| 3     | Cool      | 45°F – 59°F   |
| 4     | Mild      | 60°F – 74°F   |
| 5     | Warm/Hot  | `tmpf` ≥ 75°F |

These breakpoints reflect meaningful meteorological regimes in Nebraska and should yield a reasonable number of observations in each bin across all 9 stations.

**Why a complete block?** Every station experiences all five temperature regimes over the course of a year, so each block will contain one mean humidity value for all 9 stations — satisfying the "complete" requirement.

---

## 3. Data Scope

- **Files:** `data/alliance.csv` through `data/scottsbluff.csv` (9 files)
- **Date range used:** 2025-01-01 through 2025-12-31 (full calendar year)
- **Station IDs confirmed from raw data:**

| File            | Station ID | Location         |
| --------------- | ---------- | ---------------- |
| alliance.csv    | AIA        | Alliance, NE     |
| scottsbluff.csv | BFF        | Scottsbluff, NE  |
| beatrice.csv    | BIE        | Beatrice, NE     |
| blair.csv       | BTA        | Blair, NE        |
| grandIsland.csv | GRI        | Grand Island, NE |
| hastings.csv    | HSI        | Hastings, NE     |
| lincoln.csv     | LNK        | Lincoln, NE      |
| norfolk.csv     | OFK        | Norfolk, NE      |
| omaha.csv       | OMA        | Omaha, NE        |

> Note: The README lists both Alliance and Scottsbluff as "BFF" — this is a typo. Alliance is AIA; Scottsbluff is BFF.

---

## 4. Design Diagram

Each cell is one experimental unit: the **mean relative humidity** for a given station within a given temperature bin.

```
                   Block 1      Block 2      Block 3      Block 4      Block 5
                   Freezing     Cold         Cool         Mild         Warm/Hot
                   (<25°F)      (25–44°F)    (45–59°F)    (60–74°F)    (≥75°F)
                   ----------   ----------   ----------   ----------   ----------
AIA (Alliance)     [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]
BFF (Scottsbluff)  [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]
BIE (Beatrice)     [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]
BTA (Blair)        [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]
GRI (Grand Is.)    [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]
HSI (Hastings)     [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]
LNK (Lincoln)      [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]
OFK (Norfolk)      [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]
OMA (Omaha)        [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]   [  relh  ]

9 treatments × 5 blocks = 45 experimental units (cells)
```

---

## 5. Hypotheses

**Primary test — Station effect:**

- H₀: Mean relative humidity is the same across all 9 stations at a given temperature level (μ_AIA = μ_BFF = … = μ_OMA)
- H₁: At least one station has a different mean relative humidity after accounting for temperature

**Block effect (secondary, not the focus):**

- H₀: Temperature bin has no effect on relative humidity
- H₁: Temperature level significantly explains humidity variation (expected to be true — validates the blocking choice)

---

## 6. Missing Data Strategy

Missing values are encoded as `M` in the raw files.

1. Load all files with `read_csv(..., na = "M")` to convert `M` → `NA` in R.
2. Both `relh` and `tmpf` have low missing rates in the ASOS data, so listwise deletion (dropping rows where either is `NA`) is the preferred strategy — no imputation needed.
3. After dropping missing rows, assign each remaining hourly observation to a temperature bin using `cut()`.
4. Compute the mean `relh` for each station × temperature bin combination (the experimental unit).
5. Verify all 45 cells are populated. If any bin is empty for a station (unlikely given ~11,000+ observations per station), either widen that bin's boundaries or note the missing cell and use `na.action = na.omit` in `aov()`.

---

## 7. R Code Plan

```r
library(dplyr)
library(readr)
library(ggplot2)

# Step 1 — Load and combine all stations
files <- list.files("data/", pattern = "*.csv", full.names = TRUE)
weather <- lapply(files, read_csv, na = "M") |> bind_rows()

# Step 2 — Filter to 2025, drop missing relh or tmpf
obs <- weather |>
  filter(format(as.Date(valid), "%Y") == "2025",
         !is.na(relh), !is.na(tmpf))

# Step 3 — Assign temperature bins (blocks)
obs <- obs |>
  mutate(temp_bin = cut(tmpf,
                        breaks = c(-Inf, 25, 45, 60, 75, Inf),
                        labels = c("Freezing (<25°F)", "Cold (25–44°F)",
                                   "Cool (45–59°F)",  "Mild (60–74°F)",
                                   "Warm/Hot (≥75°F)"),
                        right  = FALSE))

# Step 4 — Compute mean relh per experimental unit (station × temp bin)
units <- obs |>
  group_by(station, temp_bin) |>
  summarise(mean_relh = mean(relh, na.rm = TRUE),
            n_obs      = n(),
            .groups    = "drop")

# Check completeness — should be 45 rows
print(units, n = 45)

# Step 5 — Fit RCBD model
# Model: response ~ treatment + block  (no interaction term in classic RCBD)
rcbd_model <- aov(mean_relh ~ station + temp_bin, data = units)
summary(rcbd_model)

# Step 6 — Tukey post-hoc on station effect
TukeyHSD(rcbd_model, which = "station")

# Step 7 — Residual diagnostics
par(mfrow = c(2, 2))
plot(rcbd_model)

# Step 8 — Interaction check (should NOT be significant in a valid RCBD)
rcbd_interaction <- aov(mean_relh ~ station * temp_bin, data = units)
anova(rcbd_model, rcbd_interaction)   # F-test for interaction term

# Step 9 — Profile plot (treatment means across blocks)
ggplot(units, aes(x = temp_bin, y = mean_relh,
                  color = station, group = station)) +
  geom_line() + geom_point() +
  labs(title = "Mean Relative Humidity by Station and Temperature Bin (2025)",
       x = "Temperature Bin (Block)", y = "Mean Relative Humidity (%)",
       color = "Station") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
```

---

## 8. Expected Outputs

| Output | Description |
| --- | --- |
| ANOVA table | F-statistics and p-values for station and temperature bin effects |
| Tukey HSD table | Pairwise station comparisons with 95% CIs and adjusted p-values |
| Tukey grouping letters | Stations clustered by statistically indistinguishable mean humidity |
| Profile plot | Line chart of mean humidity per station across the 5 temperature bins |
| Residual diagnostics | 4-panel plot to verify ANOVA assumptions |
| Interaction F-test | Confirms whether block × treatment interaction is present |

---

## 9. Potential Concerns

**Block × Treatment Interaction:** The RCBD assumes the humidity difference between stations is consistent across all temperature bins. In practice, eastern stations near the Missouri River (OMA, BTA) may show a humidity advantage that grows stronger in warm temperatures (when vegetation and water bodies evapotranspirate more heavily) but not in freezing conditions. We will test for this explicitly (Step 8 above) and report it.

**Non-normality of residuals:** With 45 cells the dataset is small; the QQ plot and Shapiro-Wilk test on residuals will be important to check. If residuals are skewed, a non-parametric Friedman test is the fallback.

**Bin balance:** Some temperature bins will have many more observations contributing to their mean than others (e.g., "Cold" will dominate in Nebraska's climate). The means themselves are the experimental units, so the within-cell sample sizes don't affect the ANOVA directly, but very sparse bins (< ~30 observations) produce unreliable means and should be noted.

**Multicollinearity between `relh` and `tmpf`:** Since we are blocking on `tmpf` precisely because it drives `relh`, the block effect is expected to be large and significant. This is the design working correctly, not a problem.

---

## 10. "Best" Station Recommendation Criterion

Per the assignment requirement to "recommend the best station," we will define **best** as the station with the highest mean relative humidity across temperature bins (most consistently moist conditions). The Tukey grouping letters will identify statistically distinguishable groups. We expect eastern stations (OMA, BTA, BIE) to rank highest given their proximity to the Missouri River valley, and the Panhandle stations (AIA, BFF) to rank lowest due to their higher elevation and drier high-plains climate.
