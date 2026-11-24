# Institutional Market Structure Framework (IMSF)
## Master Engineering Development Plan & Sprint Roadmap

**Project Codename:** `InstitutionalSMC`  
**Target Platform:** MetaTrader 5 (MQL5) & Python (Research / ML)  
**Architecture:** Modular, Event-Driven, Headless-First OOP Framework  
**Current Status:** Phase 10 — Institutional On-Chart Dashboard & GUI  
**Document Version:** 1.0.0  
**Last Updated:** 2026-11-23  

---

## 1. Project Overview & Vision

The **Institutional Market Structure Framework (IMSF)** is an enterprise-grade algorithmic trading framework designed for MetaTrader 5. Rather than implementing an ad-hoc, monolithic `.mq5` script, this project is engineered as a decoupled, multi-layered trading system capable of serving three distinct targets:

1. **Analytical Chart Indicator (`InstitutionalSMC.mq5`):** High-performance visual overlay for discretionary analysis, drawing dynamic market structure, order blocks, liquidity sweeps, fair value gaps, and supply/demand zones.
2. **Autonomous Expert Advisor (`InstitutionalSMC_EA.mq5`):** A headless, low-latency execution robot capable of trading 24/5 with institutional risk controls, economic news blackouts, rollover spread filters, and multi-timeframe confirmation.
3. **Machine Learning & Python Research Hub:** Headless data exporter that transforms price action into structured numerical features for backtesting, strategy validation, and predictive machine learning models.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    CORE CALCULATION ENGINE (Headless Layer)                  │
│                                                                              │
│   CSwingPoint ──► CMarketData ◄── TimeframeManager ◄── ATRFilter / Utilities │
└───────────────────────┬──────────────────────────────────┬───────────────────┘
                        │                                  │
                        ▼                                  ▼
┌────────────────────────────────────────┐ ┌───────────────────────────────────┐
│     VISUALIZATION LAYER (Chart GUI)    │ │    EXECUTION LAYER (Expert Advisor)│
│                                        │ │                                   │
│  - ObjectManager.mqh                   │ │  - SignalGenerator.mqh            │
│  - Zone / FVG / OB Rectangles          │ │  - 3-Tier Multi-Timeframe Trigger │
│  - Interactive Dashboard               │ │  - RiskManager.mqh (Dynamic Lots) │
│  - Desktop, Push & Webhook Alerts      │ │  - NewsFilter & Rollover Guard    │
└────────────────────────────────────────┘ └───────────────────────────────────┘
```

---

## 2. Core Engineering Principles

Every engineer contributing to this repository must adhere to the following architectural rules:

1. **Strict Separation of Concerns (Single Responsibility Principle):**
   * Mathematical and structural calculations must never execute graphical functions (`ObjectCreate`, `ObjectSetInteger`, etc.).
   * The calculation core must run 100% headless. Drawing logic resides exclusively inside `ObjectManager.mqh`.
2. **Zero-Repainting Guarantee:**
   * Confirmed structural points (Swing Highs/Lows, BOS, CHoCH, Order Blocks) must **never** shift or vanish once confirmed.
   * Swing detection relies on confirmed candle closes ($N$ left bars, $M$ right bars) and ATR-based volatility filters.
3. **Headless Execution Performance:**
   * Backtesting and Strategy Tester optimizations must execute at maximum CPU speed without graphical overhead.
4. **Defensive Risk-First Execution:**
   * No position is ever entered without a pre-calculated hard Stop Loss and Take Profit.
   * System accounts for real-world execution friction: spread spikes, slippage, weekend gaps, and news blackouts.

---

## 3. Directory & File Architecture

```text
metatrader/
│
├── development_plan.md               # Master engineering plan & phase tracker
├── README.md                          # Project overview and quickstart guide
│
├── MQL5/
│   ├── Indicators/
│   │   └── InstitutionalSMC.mq5       # Main visual indicator
│   │
│   ├── Experts/
│   │   ├── SMC_Prototype_EA.mq5       # Early execution test robot (Phase 5)
│   │   └── InstitutionalSMC_EA.mq5    # Production-grade autonomous EA (Phase 12)
│   │
│   ├── Include/
│   │   └── SMC/
│   │       ├── Types.mqh              # Core data models, enums, and structures
│   │       ├── Settings.mqh           # Global configuration parameters
│   │       ├── Utilities.mqh          # Math, pip calculations, bar-state helpers
│   │       ├── MarketData.mqh         # Centralized state repository
│   │       ├── SwingDetector.mqh      # Non-repainting pivot detection engine
│   │       ├── MarketStructure.mqh    # HH, HL, LH, LL classification
│   │       ├── ObjectManager.mqh      # Graphical chart rendering engine
│   │       ├── ZoneEngine.mqh         # S/R clustering and zone scoring
│   │       ├── OrderBlockEngine.mqh   # Order block detection and mitigation
│   │       ├── FVGEngine.mqh          # Fair value gap detection and fill tracking
│   │       ├── LiquidityEngine.mqh    # Liquidity pools, equal highs/lows, sweeps
│   │       ├── TimeframeManager.mqh   # Multi-timeframe synchronization
│   │       ├── RiskManager.mqh        # Position sizing, drawdown, equity guard
│   │       ├── NewsFilter.mqh         # High-impact news blackout filter
│   │       ├── SpreadFilter.mqh       # Rollover and spread widening protection
│   │       ├── SignalGenerator.mqh    # 3-tier execution strategy logic
│   │       └── Dashboard.mqh          # On-chart HUD / Information panel
│   │
│   └── Scripts/
│       └── ExportSMCFeatures.mq5      # Data exporter for Python & ML research
│
├── Python/                            # Research, Backtesting & ML Engine
│   ├── data/                          # Exported historical feature sets
│   ├── models/                        # Trained machine learning models
│   ├── backtest/                      # Custom vector/event backtester
│   └── requirements.txt               # Python dependencies
│
└── Tests/                             # Unit tests and validation scripts
    ├── Test_SwingDetector.mq5
    ├── Test_MarketStructure.mq5
    └── Test_RiskManager.mq5
```

---

## 4. Master Progress Tracker

> **Notice for Engineers:** When completing a phase, check the box `[x]`, set the Status to `DONE`, and record the Completion Date and Engineer ID in the table below.

| Phase | Version | Module / Objective | Target Sprint | Status | Completion Date | Sign-Off |
| :---: | :---: | :--- | :---: | :---: | :---: | :---: |
| **0** | `v0.1.0` | Repository Setup & Architectural Baseline | Sprint 1 | [x] Completed | 2026-11-23 | KH |
| **1** | `v0.2.0` | Foundation Layer & Core Data Structures | Sprint 1 | [x] Completed | 2026-11-23 | KH |
| **2** | `v0.3.0` | Non-Repainting Swing Detection Engine | Sprint 1 | [x] Completed | 2026-11-23 | KH |
| **3** | `v0.4.0` | Market Structure Classification (HH/HL/LH/LL) | Sprint 2 | [x] Completed | 2026-11-23 | KH |
| **4** | `v0.5.0` | Headless Verification & Lightweight Visualization | Sprint 2 | [x] Completed | 2026-11-23 | KH |
| **5** | `v0.6.0` | Fast-Track Execution Baseline (Prototype EA) | Sprint 3 | [x] Completed | 2026-11-23 | KH |
| **6** | `v0.7.0` | Support & Resistance / Dynamic Zone Engine | Sprint 4 | [x] Completed | 2026-11-23 | KH |
| **7** | `v0.8.0` | Smart Money Concepts (OB, FVG, Liquidity) | Sprint 5 | [x] Completed | 2026-11-24 | KH |
| **8** | `v0.9.0` | Multi-Timeframe (MTF) Synchronization Engine | Sprint 6 | [x] Completed | 2026-11-24 | KH |
| **9** | `v1.0.0` | Production Hardening & Overnight Risk Guard | Sprint 7 | [x] Completed | 2026-11-24 | KH |
| **10** | `v1.1.0` | Institutional On-Chart Dashboard & GUI | Sprint 8 | [ ] Pending | — | — |
| **11** | `v1.2.0` | Multi-Channel Alert & Notification System | Sprint 8 | [ ] Pending | — | — |
| **12** | `v2.0.0` | Full Institutional Expert Advisor (Autonomous) | Sprint 9 | [ ] Pending | — | — |
| **13** | `v3.0.0` | Python Integration, Feature Export & ML Model | Sprint 10 | [ ] Pending | — | — |

---

## 5. Detailed Sprint Specifications & Phase Roadmaps

---

### Phase 0: Project Setup & Architectural Baseline
* **Version:** `v0.1.0`
* **Status:** `[x] Completed`
* **Dependencies:** None

#### Objective
Initialize repository directory layout, establish strict compiler parameters, and set up documentation standards.

#### Deliverables
* Complete file directory structure (`MQL5/Indicators/`, `MQL5/Include/SMC/`, `MQL5/Experts/`, etc.).
* `.gitignore` configured for MetaTrader compiled binaries (`*.ex5`), cache, and temporary files.
* Initial `README.md` and `development_plan.md`.

#### Acceptance Criteria
- [x] All directories created.
- [x] Baseline entry-point `.mq5` initialized under strict compiler requirements.

---

### Phase 1: Foundation Layer & Core Data Structures
* **Version:** `v0.2.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 0

#### Objective
Implement the fundamental data models, enums, global configuration inputs, and mathematical utility functions.

#### Deliverables
* `MQL5/Include/SMC/Types.mqh`: Enums (`ENUM_SWING_TYPE`, `ENUM_STRUCTURE_TYPE`, `ENUM_ZONE_TYPE`, `ENUM_MITIGATION_STATE`), `CSwingPoint` class, `SZone` struct, `SOrderBlock` struct.
* `MQL5/Include/SMC/Settings.mqh`: User configuration inputs (Swing Left/Right bars, ATR thresholds, colors, risk limits).
* `MQL5/Include/SMC/Utilities.mqh`: Pip/tick conversions, `IsNewBar()` detector, ATR helpers, normalized price comparisons.
* `MQL5/Include/SMC/MarketData.mqh`: Centralized in-memory storage holding dynamic arrays of confirmed swing points, active zones, and state queries.

#### Technical Specifications
```cpp
// Core Swing Point Structure in Types.mqh
class CSwingPoint
{
public:
   datetime             time;          // Time of candle peak/trough
   double               price;         // Exact price level
   int                  barIndex;      // Historical bar index
   ENUM_SWING_TYPE      swingType;     // SWING_HIGH or SWING_LOW
   ENUM_STRUCTURE_TYPE  structureType; // HH, HL, LH, LL, or NONE
   bool                 confirmed;     // True once right-bars confirmed
   double               atrAtFormation;// ATR value at time of creation
   int                  strengthScore; // Composite quality score (0-100)
};
```

#### Acceptance Criteria
- [x] Code compiles cleanly with zero warnings.
- [x] Unit tests confirm `IsNewBar()` behaves reliably across all MT5 timeframes.
- [x] `CMarketData` dynamic array correctly allocates, searches, and clears swing data without memory leaks.

---

### Phase 2: Non-Repainting Swing Detection Engine
* **Version:** `v0.3.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 1

#### Objective
Build a mathematically rigorous, non-repainting pivot detection algorithm that ignores market noise via ATR volatility filtering.

#### Deliverables
* `MQL5/Include/SMC/SwingDetector.mqh`: Core algorithmic swing calculation.
* `Tests/Test_SwingDetector.mq5`: Unit script to validate detected swings against historical data.

#### Algorithmic Logic
1. **Candidate Pivot:** Bar $i$ must be strictly higher than $gN$ bars to its left and $M$ bars to its right for a Swing High (reversed for Swing Low).
2. **ATR Noise Filter:** 
   $$\Delta \text{Price} = |\text{Candidate} - \text{Previous Opposite Swing}| \ge k \times \text{ATR}(14)$$
   Swings failing the ATR threshold are discarded as intraday noise.
3. **Minimum Separation Filter:** Two consecutive swing points of the same type within $B_{\text{min}}$ bars merge to the more extreme price.
4. **Non-Repainting Rule:** Once a swing is confirmed ($M$ bars elapsed), its price, time, and coordinates are immutable.

#### Acceptance Criteria
- [x] Zero repainting: Swings marked on historical data remain identical when running tick-by-tick in Strategy Tester.
- [x] Tested successfully on M5, M15, H1, and D1 timeframes.

---

### Phase 3: Market Structure Classification Engine
* **Version:** `v0.4.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 2

#### Objective
Automatically evaluate consecutive confirmed swings and classify market structure into Higher Highs (HH), Higher Lows (HL), Lower Highs (LH), and Lower Lows (LL).

#### Deliverables
* `MQL5/Include/SMC/MarketStructure.mqh`: Evaluates structure sequence and detects trend direction.

#### Classification Rules
* **Highs:**
  * If $\text{Price}(\text{Current High}) > \text{Price}(\text{Previous High}) + \epsilon \implies \mathbf{HH}$
  * If $\text{Price}(\text{Current High}) \le \text{Price}(\text{Previous High}) - \epsilon \implies \mathbf{LH}$
* **Lows:**
  * If $\text{Price}(\text{Current Low}) > \text{Price}(\text{Previous Low}) + \epsilon \implies \mathbf{HL}$
  * If $\text{Price}(\text{Current Low}) \le \text{Price}(\text{Previous Low}) - \epsilon \implies \mathbf{LL}$
* **Trend State:** Bullish if sequence is $(\text{HH}, \text{HL})$; Bearish if sequence is $(\text{LH}, \text{LL})$; Neutral / Consolidating otherwise.

#### Acceptance Criteria
- [x] Correctly identifies clean structural shifts on volatile historical periods (e.g., EURUSD London/NY sessions).
- [x] Updates state dynamically only when a new swing point is appended to `CMarketData`.

---

### Phase 4: Headless Verification & Lightweight Visualization
* **Version:** `v0.5.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 3

#### Objective
Implement `ObjectManager.mqh` to render visual arrows, labels (HH, HL, LH, LL), and debug overlays on chart windows, while ensuring calculation modules remain 100% headless.

#### Deliverables
* `MQL5/Include/SMC/ObjectManager.mqh`: Encapsulated graphic object creator with unique naming prefixes and cleanup routines.
* `MQL5/Indicators/InstitutionalSMC.mq5`: Working MT5 indicator overlaying structure on live charts.

#### Acceptance Criteria
- [x] Removing indicator cleanly deletes 100% of created chart objects without leaving artifacts.
- [x] Indicator loads and responds smoothly during timeframe changes.
- [x] Switching off visual settings (`ShowVisualObjects = false`) stops all GDI calls and runs at native CPU speed.

---

### Phase 5: Fast-Track Execution Baseline (Prototype EA)
* **Version:** `v0.6.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 4

#### Objective
Validate that market structure data can drive profitable, automated trade executions *early in the project lifecycle*, rather than delaying execution tests to the final sprints.

#### Deliverables
* `MQL5/Experts/SMC_Prototype_EA.mq5`: Minimalist automated trading robot executing trades based on confirmed structural trend shifts (e.g., first HL in new uptrend).
* `MQL5/Include/SMC/RiskManager.mqh` (Basic): Fixed fractional lot sizing based on Stop Loss distance.

#### Strategy Logic
* **Buy Entry:** Trend switches from Bearish to Bullish (formation of first confirmed HH + HL). Enter on break of intermediate structure.
* **Stop Loss:** Placed strictly below the most recent confirmed swing low minus $0.5 \times \text{ATR}$.
* **Take Profit:** Minimum $2.0 \times \text{Risk}$.

#### Acceptance Criteria
- [x] Prototype EA runs in MT5 Strategy Tester across 1 year of tick data without crashes, division-by-zero, or order errors.
- [x] Confirms that trading based on confirmed structure produces positive expectancy or clear optimization baselines.

---

### Phase 6: Support & Resistance / Dynamic Zone Engine
* **Version:** `v0.7.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 5

#### Objective
Replace naive single-line support/resistance with clustered, dynamic institutional zones scored by touch count, reaction volume, age, and ATR width.

#### Deliverables
* `MQL5/Include/SMC/ZoneEngine.mqh`: Clusters nearby swing points within an ATR threshold into supply/demand zones.
* Visual integration inside `ObjectManager.mqh` using translucent rectangles (`OBJ_RECTANGLE`).

#### Zone Scoring Matrix (Total: 100 Points)
| Factor | Weight | Evaluation Criteria |
| :--- | :---: | :--- |
| **Touch Frequency** | 30% | 2–3 touches optimal. Too many touches ($\ge 5$) degrades score (exhaustion). |
| **Reaction Magnitude** | 30% | Size of price displacement departing the zone measured in ATR multiples. |
| **Recency Decay** | 20% | Exponential decay based on number of elapsed bars. |
| **Timeframe Weight** | 20% | D1/H4 zones receive full score; M15/M5 receive lower baseline score. |

#### Acceptance Criteria
- [x] Overlapping or adjacent zones within $1.0 \times \text{ATR}$ automatically merge into a single consolidated zone.
- [x] Zones that are thoroughly penetrated by candle closes are marked as `MITIGATED` or deleted.

---

### Phase 7: Smart Money Concepts (SMC) Core
* **Version:** `v0.8.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 6

#### Objective
Mathematically formalize Order Blocks, Fair Value Gaps (FVG / Imbalances), and Liquidity Sweeps with precise algorithmic criteria.

#### Deliverables
* `MQL5/Include/SMC/FVGEngine.mqh`: Detects 3-candle imbalance gaps and tracks fill percentages (0%, 50% CE, 100% full mitigation).
* `MQL5/Include/SMC/OrderBlockEngine.mqh`: Identifies the last opposing candle prior to an impulsive structural break that leaves an FVG.
* `MQL5/Include/SMC/LiquidityEngine.mqh`: Identifies Equal Highs (EQH), Equal Lows (EQL), and detects stop-run sweeps (wick break followed by closing inside range).

#### Mathematical Definitions
* **Bullish FVG:** $\text{Low}(\text{Bar } i) > \text{High}(\text{Bar } i+2)$ with gap distance $\ge 0.5 \times \text{ATR}$.
* **Bearish FVG:** $\text{High}(\text{Bar } i) < \text{Low}(\text{Bar } i+2)$ with gap distance $\ge 0.5 \times \text{ATR}$.
* **BOS vs. Sweep:**
  * **Break of Structure (BOS):** Candle **body** closes past confirmed swing high/low.
  * **Liquidity Sweep:** Candle **wick** pierces swing high/low, but candle **body** closes back within the prior range.

#### Acceptance Criteria
- [x] Visual inspection confirms exact match with institutional SMC definitions.
- [x] Mitigation state changes from `UNMITIGATED` $\to$ `PARTIALLY_FILLED` $\to$ `MITIGATED` reliably.

---

### Phase 8: Multi-Timeframe (MTF) Synchronization Engine
* **Version:** `v0.9.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 7

#### Objective
Enable the framework to simultaneously analyze Macro (H4/D1), Intermediate (H1/M15), and Micro (M5/M1) timeframes without data desynchronization or lag.

#### Deliverables
* `MQL5/Include/SMC/TimeframeManager.mqh`: Asynchronous data retrieval using `CopyRates` with synchronization checks (`SeriesInfoInteger`).
* Multi-timeframe confluence matrix determining overall directional bias.

#### Timeframe Roles
* **Tier 1 (Macro - H4/D1):** Identifies macro trend, major liquidity pools, and primary Order Blocks.
* **Tier 2 (Setup - H1/M15):** Monitors price tapping into the HTF Order Block and identifies market structure shifts (CHoCH).
* **Tier 3 (Trigger - M5/M1):** Pinpoints the refined entry on internal FVG retest with tight invalidation.

#### Acceptance Criteria
- [x] Handles un-downloaded history gracefully without freezing MT5 terminal.
- [x] Provides unified structure state: `TimeframeManager.GetBias(PERIOD_H4)`.

---

### Phase 9: Production Hardening & Overnight Risk Guard
* **Version:** `v1.0.0`
* **Status:** `[x] Completed`
* **Dependencies:** Phase 8

#### Objective
Implement the safeguards required to operate an autonomous robot safely 24/5 ("making money while you sleep") without catastrophic tail-risk.

#### Deliverables
* `MQL5/Include/SMC/SpreadFilter.mqh`: Detects spread blowouts and enforces a trading freeze during daily rollover (21:45 – 23:15 UTC).
* `MQL5/Include/SMC/NewsFilter.mqh`: Integrates MT5 economic calendar (`CalendarValueHistory`) to suspend trading 30 minutes before and after high-impact events (CPI, NFP, FOMC).
* `MQL5/Include/SMC/RiskManager.mqh` (Hardened): Maximum Daily Loss circuit-breaker (e.g., -3% equity hard stop), dynamic ATR position sizing, and margin checks.

#### Acceptance Criteria
- [x] Zero orders executed during specified rollover hours or when spread exceeds maximum allowable threshold.
- [x] Daily loss circuit-breaker closes open positions and locks trading until the next calendar day.

---

### Phase 10: Institutional On-Chart Dashboard & GUI
* **Version:** `v1.1.0`
* **Status:** `[ ] Pending`
* **Dependencies:** Phase 9

#### Objective
Design an institutional Heads-Up Display (HUD) on the chart showing real-time market bias, active Order Blocks, session times, spread, and risk metrics.

#### Deliverables
* `MQL5/Include/SMC/Dashboard.mqh`: Clean, non-intrusive dashboard rendering spread, daily PnL, active bias across M15/H1/H4, and nearest liquidity targets.

#### Acceptance Criteria
- [ ] High-DPI screen compatible (4K display support).
- [ ] Collapsible with a single click to avoid obstructing price action.

---

### Phase 11: Multi-Channel Alert & Notification System
* **Version:** `v1.2.0`
* **Status:** `[ ] Pending`
* **Dependencies:** Phase 10

#### Objective
Notify traders instantly when high-confluence institutional events occur.

#### Deliverables
* `MQL5/Include/SMC/AlertManager.mqh`: Configurable alerts for Desktop Popups, Mobile Push notifications (`SendNotification`), and Discord/Telegram Webhooks (`WebRequest`).

#### Event Triggers
* High-confluence zone tapped on HTF.
* Liquidity sweep confirmed on lower timeframe.
* Confirmed Change of Character (CHoCH).

#### Acceptance Criteria
- [ ] Rate-limited alerts (prevents notification spamming on volatile candles).

---

### Phase 12: Production-Grade Expert Advisor (Autonomous)
* **Version:** `v2.0.0`
* **Status:** `[ ] Pending`
* **Dependencies:** Phase 9, Phase 11

#### Objective
Assemble all engines into the flagship autonomous trading robot (`InstitutionalSMC_EA.mq5`) executing the full 3-tier multi-timeframe strategy.

#### Deliverables
* `MQL5/Experts/InstitutionalSMC_EA.mq5`: Complete autonomous EA.
* `MQL5/Include/SMC/SignalGenerator.mqh`: High-confluence entry rules combining HTF bias, LTF sweep/CHoCH, and FVG mitigation.
* Complete Strategy Tester backtest reports across 5 major pairs (EURUSD, GBPUSD, USDJPY, AUDUSD, XAUUSD) over 5+ years of real tick data.

#### Acceptance Criteria
- [ ] Profit Factor $> 1.8$, Maximum Drawdown $< 12\%$ in 5-year tick backtest.
- [ ] Handles reconnects, broker requotes, slippage, and terminal restarts without losing state.

---

### Phase 13: Python Integration, Feature Export & Machine Learning
* **Version:** `v3.0.0`
* **Status:** `[ ] Pending`
* **Dependencies:** Phase 12

#### Objective
Bridge MQL5 and Python to generate institutional datasets and train predictive machine learning models for trade filtering.

#### Deliverables
* `MQL5/Scripts/ExportSMCFeatures.mq5`: Exports timestamped bars along with structural features:
  * `Distance_To_Nearest_OB_ATR`
  * `HTF_Bias` (-1, 0, 1)
  * `Active_Zone_Strength_Score`
  * `Is_Sweep_Forming` (0 or 1)
  * `Session_Phase` (Asian, London, NY)
* `Python/backtest/`: Python backtesting and feature evaluation pipeline.
* `Python/models/`: LightGBM / XGBoost classifier predicting trade setup win probabilities.

#### Acceptance Criteria
- [ ] Export script produces standardized CSV data matching Python schema.
- [ ] Machine learning model achieves statistically significant edge over random baseline on out-of-sample data.

---

## 6. Definition of Done (DoD) for Any Sprint

Before any phase is marked as completed in this document:

1. **Compilation:** Code compiles with **0 errors and 0 warnings** under `#property strict`.
2. **Headless Speed:** Calculation logic passes speed checks without requiring active chart graphics.
3. **Memory Safety:** Every allocated dynamic object or array is freed (`delete`, `ArrayFree`); zero memory leaks on terminal unload.
4. **Validation Test:** Dedicated test script in `Tests/` executes and passes all assertions.
5. **Documentation:** Public methods and structures must be documented with clear inline descriptions.
6. **Progress Tracking:** Update this file: check off items, mark phase as done in Section 4, and commit with tag `vX.X.X`.

---

## 7. How to Update This Document

When you complete a sprint or phase:
1. Open `development_plan.md`.
2. In **Section 4 (Master Progress Tracker)**, change `[ ] Pending` to `[x] Completed`.
3. Fill in the **Completion Date** (YYYY-MM-DD) and your **Sign-Off** initials/ID.
4. In **Section 5 (Detailed Sprint Specifications)**, change `Status: [ ] Pending` to `Status: [x] Completed` and check off all acceptance criteria boxes.
5. Commit the update to Git:
   ```bash
   git add development_plan.md
   git commit -m "docs: mark Phase X (ModuleName) as completed [vX.X.X]"
   ```

