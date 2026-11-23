# Institutional Market Structure Framework (IMSF)

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](development_plan.md)
[![Platform](https://img.shields.io/badge/platform-MetaTrader%205%20%7C%20Python-orange.svg)](https://www.metatrader5.com)
[![Architecture](https://img.shields.io/badge/architecture-Headless%20OOP-green.svg)](development_plan.md)

IMSF (**Institutional Market Structure Framework**) is an enterprise-grade algorithmic trading framework for MetaTrader 5 (MQL5) and Python. It is designed to model institutional order flow and Smart Money Concepts (SMC) with mathematical rigor, zero repainting, and high-performance headless execution.

---

## 🏛️ System Architecture

The framework is decoupled into three primary tiers:

1. **Headless Core (`MQL5/Include/SMC/`):** Pure calculation and state management. Houses non-repainting pivot detection, structure tracking, dynamic supply/demand zones, and multi-timeframe synchronization. Completely free of graphical dependencies.
2. **Visual Overlay (`MQL5/Indicators/`):** Renders dynamic market structure, order blocks, fair value gaps, and liquidity levels on MT5 charts using `ObjectManager.mqh`.
3. **Autonomous Execution (`MQL5/Experts/`):** Automated Expert Advisors utilizing a 3-tier multi-timeframe strategy with institutional risk management, economic calendar news blackouts, and overnight rollover spread guards.
4. **Research & ML Layer (`Python/`):** Feature extraction and predictive machine learning models (LightGBM/XGBoost) for trade setup filtering and quantitative validation.

---

## 📁 Repository Layout

```text
metatrader/
│
├── development_plan.md       # Master engineering roadmap & progress tracker
├── README.md                  # Project overview & documentation
├── .gitignore                 # Excludes binaries (*.ex5) and cache
│
├── MQL5/
│   ├── Indicators/            # Chart visualization indicators
│   │   └── InstitutionalSMC.mq5
│   ├── Experts/               # Automated Expert Advisors
│   │   ├── SMC_Prototype_EA.mq5
│   │   └── InstitutionalSMC_EA.mq5
│   ├── Include/SMC/           # Core headless framework modules
│   │   ├── Types.mqh          # Data structures & enums
│   │   ├── Settings.mqh       # Config parameters
│   │   ├── Utilities.mqh      # Math & helper functions
│   │   ├── MarketData.mqh     # State repository
│   │   ├── SwingDetector.mqh  # Non-repainting pivot engine
│   │   ├── MarketStructure.mqh# HH/HL/LH/LL classification
│   │   ├── ZoneEngine.mqh     # S/R zone clustering & scoring
│   │   ├── OrderBlockEngine.mqh
│   │   ├── FVGEngine.mqh
│   │   ├── LiquidityEngine.mqh
│   │   ├── TimeframeManager.mqh
│   │   ├── RiskManager.mqh
│   │   ├── NewsFilter.mqh
│   │   ├── SpreadFilter.mqh
│   │   ├── SignalGenerator.mqh
│   │   ├── Dashboard.mqh
│   │   └── ObjectManager.mqh  # Isolated drawing engine
│   └── Scripts/               # Utility scripts & feature exporters
│
├── Python/                    # ML & quantitative backtesting suite
│   ├── data/
│   ├── models/
│   └── backtest/
│
└── Tests/                     # Unit test scripts for MQL5
```

---

## 🚀 Development Roadmap

Development is tracked through structured phases in [development_plan.md](development_plan.md):

* **Phase 0:** Project Setup & Architectural Baseline (`v0.1.0`)
* **Phase 1:** Foundation Layer & Core Data Structures (`v0.2.0`)
* **Phase 2:** Non-Repainting Swing Detection Engine (`v0.3.0`)
* **Phase 3:** Market Structure Classification (`v0.4.0`)
* **Phase 4:** Headless Verification & Chart Visualization (`v0.5.0`)
* **Phase 5:** Early Execution Prototype EA (`v0.6.0`)
* **Phase 6:** Dynamic Supply & Demand Zones (`v0.7.0`)
* **Phase 7:** Smart Money Concepts Core (OB, FVG, Sweeps) (`v0.8.0`)
* **Phase 8:** Multi-Timeframe Synchronization (`v0.9.0`)
* **Phase 9:** Production Hardening & Overnight Risk Guards (`v1.0.0`)
* **Phase 10:** On-Chart Institutional Dashboard (`v1.1.0`)
* **Phase 11:** Multi-Channel Alert Subsystem (`v1.2.0`)
* **Phase 12:** Flagship Autonomous EA (`v2.0.0`)
* **Phase 13:** Python Integration & ML Trade Filter (`v3.0.0`)

---

## 🛠️ Engineering Standards

1. **Compilation:** Strict compilation (`#property strict`) with zero errors and zero warnings.
2. **Non-Repainting:** Swings are confirmed strictly upon candle close ($N$ left, $M$ right bars) + ATR noise filtration.
3. **Headless Speed:** Calculation classes must never call graphical functions (`ObjectCreate`, etc.) to preserve backtest speed.
4. **Memory Safety:** All dynamic pointers must be properly released on deinitialization (`delete`, `ArrayFree`).

