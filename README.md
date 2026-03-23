# 🌩️ Climate Coders — Nebraska Weather Data Analysis

> **Team:** Climate Coders
> **Course:** Stat 318
> **Dataset:** Hourly surface weather observations from 9 Nebraska ASOS stations (2025)

---

## 📁 Project Overview

This project applies a full suite of statistical methods to real-world meteorological data collected from nine weather stations across Nebraska. Each analysis builds toward a richer understanding of how temperature, humidity, wind speed, dew point, and sky cover vary across geography, time, and conditions.

---

## 📂 Repository Structure

```
weatherData/
├── README.md                   ← You are here
└── data/
    ├── alliance.csv            ← Alliance, NE  (BFF)
    ├── beatrice.csv            ← Beatrice, NE  (BIE)
    ├── blair.csv               ← Blair, NE     (BTA)
    ├── grandIsland.csv         ← Grand Island, NE (GRI)
    ├── hastings.csv            ← Hastings, NE  (HSI)
    ├── lincoln.csv             ← Lincoln, NE   (LNK)
    ├── norfolk.csv             ← Norfolk, NE   (OFK)
    ├── omaha.csv               ← Omaha, NE     (OMA)
    └── scottsbluff.csv         ← Scottsbluff, NE (BFF)
```

---

## 📊 Dataset Description

Each CSV file contains hourly automated surface observation (ASOS) data for its respective station. All files share the same schema:

| Column               | Description                           | Units |
| -------------------- | ------------------------------------- | ----- |
| `station`            | ASOS station identifier (ICAO)        | –     |
| `valid`              | Observation timestamp                 | UTC   |
| `tmpf`               | Air temperature                       | °F    |
| `dwpf`               | Dew point temperature                 | °F    |
| `relh`               | Relative humidity                     | %     |
| `sped`               | Wind speed                            | mph   |
| `skyl1`              | First reported sky cover layer height | feet  |
| `peak_wind_gust_mph` | Peak wind gust                        | mph   |

> **Missing data** is encoded as `M` throughout all files and must be handled before analysis.

### Station Summary

| File            | Station | Location         | Approx. Records |
| --------------- | ------- | ---------------- | --------------- |
| alliance.csv    | BFF     | Alliance, NE     | ~12,400         |
| beatrice.csv    | BIE     | Beatrice, NE     | ~24,800         |
| blair.csv       | BTA     | Blair, NE        | ~28,000         |
| grandIsland.csv | GRI     | Grand Island, NE | ~11,500         |
| hastings.csv    | HSI     | Hastings, NE     | ~11,300         |
| lincoln.csv     | LNK     | Lincoln, NE      | ~12,800         |
| norfolk.csv     | OFK     | Norfolk, NE      | ~12,000         |
| omaha.csv       | OMA     | Omaha, NE        | ~11,500         |
| scottsbluff.csv | BFF\*   | Scottsbluff, NE  | ~12,400         |

---

## 🔬 Analyses Planned

### 1. Basic Statistical Inference

**Goal:** Run appropriate hypothesis test(s), assess statistical significance, discuss validity assumptions, and identify the most interesting result.

- **Approach:** Two-sample t-tests or z-tests comparing mean temperatures or wind speeds between pairs of stations (e.g., Scottsbluff vs. Omaha, reflecting the eastern plains vs. Panhandle climate divide).
- **Variables of interest:** `tmpf`, `sped`, `relh`
- **Validity considerations:** Check normality (QQ plots, Shapiro-Wilk), independence of observations, and equal variance assumptions (Levene's test).
- **R functions:** `t.test()`, `var.test()`, `wilcox.test()` (if non-normal)

---

### 2. One-Way ANOVA

**Goal:** Handle missing data logically, run a one-way ANOVA in R, perform a Tukey post-hoc test, and interpret results to recommend the "best" station (or time period).

- **Design:** Compare mean daily temperature across all 9 stations to determine if geographic location significantly explains temperature variation.
- **Missing data strategy:** Replace `M` values with `NA` and exclude from analysis (listwise deletion), or impute via station-specific hourly means if appropriate.
- **R functions:** `aov()`, `TukeyHSD()`, `summary()`, `ggplot2::ggplot()`
- **Expected output:** ANOVA table, Tukey grouping letters, boxplot by station.

---

### 3. Two-Way ANOVA

**Goal:** Fill missing data, run a two-way ANOVA in R, create and analyze an interaction plot, and recommend the best combination of factor levels.

- **Design:** Factors = **Station** (2–3 selected stations) × **Season/Time-of-Day** (Morning / Afternoon / Night). Response = `tmpf` or `relh`.
- **Missing data strategy:** Impute `M` values using the hourly median for that station and time-of-day block.
- **R functions:** `aov()` with two-factor formula, `interaction.plot()`, `TukeyHSD()`
- **Expected output:** Two-way ANOVA table, interaction plot, interpretation of main effects and interaction term.

---

### 4. Experimental Design — Randomized Complete Block Design (RCBD)

**Goal:** Diagram the design, analyze using RCBD in R, interpret results, and address potential block-treatment interaction concerns.

- **Treatment:** Station (the factor of interest — 9 levels)
- **Block:** Month or week (removes temporal variability, which is a nuisance factor)
- **Response:** `tmpf` (daily maximum or mean)
- **Diagram:** Each block (month) contains one observation per station, blocking out seasonal trends to isolate the station effect.
- **R functions:** `aov(response ~ treatment + block)`, residual diagnostics
- **Concern:** If a late-winter cold snap only hit western stations, a block × treatment interaction could bias results — we will test for this.

---

### 5. Simple Linear Regression

**Goal:** Plot the data, check correlation, run regression in R, interpret slope/intercept and R², and make 5 meaningful predictions.

- **Model:** `tmpf ~ dwpf` — predicting air temperature from dew point temperature (strongly physically related).
- **Exploratory:** Scatter plot with regression line, Pearson correlation coefficient.
- **R functions:** `lm()`, `summary()`, `predict()`, `ggplot2::geom_smooth(method = "lm")`
- **5 Predictions:** Predict `tmpf` at dew points of 0°F, 10°F, 20°F, 30°F, 40°F.
- **Diagnostics:** Residual vs. fitted, QQ plot, check for heteroskedasticity.

---

### 6. Multiple Linear Regression

**Goal:** Check multicollinearity (VIF/tolerance), run regression in R, interpret all coefficients in plain language, and make 5 predictions.

- **Model:** `sped ~ tmpf + dwpf + relh` — predicting wind speed from temperature, dew point, and humidity.
- **Multicollinearity check:** VIF using `car::vif()`. Note that `tmpf`, `dwpf`, and `relh` are correlated; tolerance < 0.1 or VIF > 10 would flag a problem.
- **R functions:** `lm()`, `car::vif()`, `summary()`, `predict()`
- **5 Predictions:** Generate predictions for 5 real-world weather scenarios (e.g., cold dry day, warm humid day, etc.)
- **Interpretation:** Express each coefficient in plain English (e.g., "For every 1°F increase in temperature, wind speed increases by X mph on average, holding other variables constant").

---

### 7. Data Visualization

**Goal:** Create one useful, publication-quality visualization in both R (ggplot2) and Excel; present them side by side.

- **Visualization:** A faceted time-series plot showing daily mean temperature (°F) over 2025 for all 9 stations — illustrating the east–west temperature gradient and seasonal patterns.
- **R (ggplot2):** Faceted line chart with `facet_wrap(~station)`, custom color palette, labeled axes, and a clean theme (`theme_minimal()`).
- **Excel:** Equivalent line chart using a pivot table to compute daily means, formatted with consistent colors and title.
- **Side-by-side comparison:** Both visuals included in the final report with commentary on strengths and weaknesses of each tool.

---

## 🛠️ Tools & Requirements

| Tool        | Purpose                                      |
| ----------- | -------------------------------------------- |
| **R**       | All statistical analyses and ggplot2 visuals |
| **Excel**   | Data visualization (parallel to R)           |
| `ggplot2`   | Publication-quality plots in R               |
| `car`       | VIF / multicollinearity diagnostics          |
| `dplyr`     | Data wrangling and missing-value handling    |
| `lubridate` | Parsing and manipulating datetime columns    |

### Suggested R Setup

```r
install.packages(c("ggplot2", "dplyr", "lubridate", "car", "readr"))
library(ggplot2)
library(dplyr)
library(lubridate)
library(car)
library(readr)

# Load a single station
lincoln <- read_csv("data/lincoln.csv", na = "M")

# Load all stations
stations <- list.files("data/", pattern = "*.csv", full.names = TRUE) |>
  lapply(read_csv, na = "M") |>
  bind_rows()
```

---

## 📝 Notes on Missing Data

- `M` is the ASOS sentinel for missing observations.
- `skyl1` and `peak_wind_gust_mph` have the highest proportion of missing values (sky cover and gusts are only recorded when present).
- `tmpf`, `dwpf`, `relh`, and `sped` are generally complete for standard hourly observations.
- Strategy per analysis is described above; no single strategy fits all contexts.

---

## 👥 Team

**Climate Coders**

---

_Data sourced from ASOS automated surface weather stations across Nebraska, 2025._
