//+------------------------------------------------------------------+
//|                                                     Settings.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_SETTINGS_MQH__
#define __IMSF_SETTINGS_MQH__

//--- 1. Swing Detection Inputs
input group "=== 1. Swing Detection Engine ==="
input int    InpSwingLeftBars          = 5;             // Left Confirmation Bars (N)
input int    InpSwingRightBars         = 5;             // Right Confirmation Bars (M)
input int    InpMinBarsBetweenSwings   = 8;             // Minimum Bars Between Swings
input int    InpATRPeriod              = 14;            // ATR Filter Period
input double InpATRMultiplier          = 1.5;           // ATR Filter Multiplier
input bool   InpFilterNoiseWithATR     = true;          // Enable ATR Noise Filter

//--- 2. Market Structure Inputs
input group "=== 2. Market Structure Classification ==="
input bool   InpShowHH                 = true;          // Show Higher Highs (HH)
input bool   InpShowHL                 = true;          // Show Higher Lows (HL)
input bool   InpShowLH                 = true;          // Show Lower Highs (LH)
input bool   InpShowLL                 = true;          // Show Lower Lows (LL)

//--- 3. Visual & Object Manager Inputs
input group "=== 3. Chart Visualization ==="
input bool   InpShowSwingLabels        = true;          // Render Structure Labels (HH/HL/LH/LL)
input bool   InpShowSwingPoints        = true;          // Render Swing Arrows/Dots
input color  InpSwingHighColor         = clrDodgerBlue; // Swing High & Bullish Color
input color  InpSwingLowColor          = clrOrangeRed;  // Swing Low & Bearish Color
input int    InpLabelFontSize          = 9;             // Label Font Size
input string InpObjectNamePrefix       = "IMSF_";       // Unique Chart Object Prefix

//--- 4. Execution & Risk Management (For EA)
input group "=== 4. Risk & Execution Configuration ==="
input double InpRiskPercent            = 1.0;           // Risk per Trade (% Balance)
input double InpMinRiskRewardRatio     = 2.0;           // Minimum Risk:Reward Ratio
input double InpMaxSpreadPips          = 3.0;           // Maximum Permissible Spread (Pips)
input bool   InpRolloverFilter         = true;          // Blackout Daily Rollover Window
input int    InpRolloverStartHour      = 23;            // Rollover Start Hour (Server)
input int    InpRolloverEndHour        = 0;             // Rollover End Hour (Server)
input double InpMaxDailyDrawdownPct    = 3.0;           // Hard Daily Loss Circuit-Breaker (%)

#endif // __IMSF_SETTINGS_MQH__

