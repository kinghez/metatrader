//+------------------------------------------------------------------+
//|                                                        Types.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_TYPES_MQH__
#define __IMSF_TYPES_MQH__

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_SWING_TYPE
{
   SWING_NONE = 0,
   SWING_HIGH = 1,
   SWING_LOW  = 2
};

enum ENUM_STRUCTURE_TYPE
{
   STRUCTURE_NONE = 0,
   STRUCTURE_HH   = 1,   // Higher High
   STRUCTURE_HL   = 2,   // Higher Low
   STRUCTURE_LH   = 3,   // Lower High
   STRUCTURE_LL   = 4    // Lower Low
};

enum ENUM_ZONE_TYPE
{
   ZONE_NONE      = 0,
   ZONE_DEMAND    = 1,
   ZONE_SUPPLY    = 2,
   ZONE_LIQUIDITY = 3
};

enum ENUM_MITIGATION_STATE
{
   STATE_UNMITIGATED = 0,
   STATE_PARTIAL     = 1,
   STATE_MITIGATED   = 2
};

enum ENUM_TREND_BIAS
{
   BIAS_NEUTRAL = 0,
   BIAS_BULLISH = 1,
   BIAS_BEARISH = 2
};

//+------------------------------------------------------------------+
//| Class CSwingPoint                                                |
//| Core data structure representing confirmed or candidate pivots   |
//+------------------------------------------------------------------+
class CSwingPoint
{
private:
   datetime             m_time;
   double               m_price;
   int                  m_barIndex;
   ENUM_SWING_TYPE      m_swingType;
   ENUM_STRUCTURE_TYPE  m_structureType;
   bool                 m_confirmed;
   double               m_atrAtFormation;
   int                  m_strengthScore;
   int                  m_touches;

public:
   // Default Constructor
   CSwingPoint() :
      m_time(0),
      m_price(0.0),
      m_barIndex(-1),
      m_swingType(SWING_NONE),
      m_structureType(STRUCTURE_NONE),
      m_confirmed(false),
      m_atrAtFormation(0.0),
      m_strengthScore(0),
      m_touches(0)
   {
   }

   // Parameterized Constructor
   CSwingPoint(const datetime time,
               const double price,
               const int barIndex,
               const ENUM_SWING_TYPE swingType,
               const double atr = 0.0) :
      m_time(time),
      m_price(price),
      m_barIndex(barIndex),
      m_swingType(swingType),
      m_structureType(STRUCTURE_NONE),
      m_confirmed(false),
      m_atrAtFormation(atr),
      m_strengthScore(0),
      m_touches(0)
   {
   }

   // Copy Constructor
   CSwingPoint(const CSwingPoint &other)
   {
      m_time           = other.m_time;
      m_price          = other.m_price;
      m_barIndex       = other.m_barIndex;
      m_swingType      = other.m_swingType;
      m_structureType  = other.m_structureType;
      m_confirmed      = other.m_confirmed;
      m_atrAtFormation = other.m_atrAtFormation;
      m_strengthScore  = other.m_strengthScore;
      m_touches        = other.m_touches;
   }

   // Getters
   datetime             Time() const             { return m_time; }
   double               Price() const            { return m_price; }
   int                  BarIndex() const         { return m_barIndex; }
   ENUM_SWING_TYPE      SwingType() const        { return m_swingType; }
   ENUM_STRUCTURE_TYPE  StructureType() const    { return m_structureType; }
   bool                 IsConfirmed() const      { return m_confirmed; }
   double               AtrAtFormation() const   { return m_atrAtFormation; }
   int                  StrengthScore() const    { return m_strengthScore; }
   int                  Touches() const          { return m_touches; }

   // Setters
   void                 SetTime(const datetime time)                   { m_time = time; }
   void                 SetPrice(const double price)                  { m_price = price; }
   void                 SetBarIndex(const int barIndex)               { m_barIndex = barIndex; }
   void                 SetSwingType(const ENUM_SWING_TYPE type)       { m_swingType = type; }
   void                 SetStructureType(const ENUM_STRUCTURE_TYPE t) { m_structureType = t; }
   void                 SetConfirmed(const bool confirmed)            { m_confirmed = confirmed; }
   void                 SetAtr(const double atr)                      { m_atrAtFormation = atr; }
   void                 SetStrengthScore(const int score)             { m_strengthScore = score; }
   void                 SetTouches(const int touches)                 { m_touches = touches; }
   void                 IncrementTouches()                            { m_touches++; }

   // Helper methods
   bool                 IsHigh() const { return (m_swingType == SWING_HIGH); }
   bool                 IsLow()  const { return (m_swingType == SWING_LOW); }

   string ToString() const
   {
      string sType = (m_swingType == SWING_HIGH) ? "HIGH" : ((m_swingType == SWING_LOW) ? "LOW" : "NONE");
      string sStruct = "NONE";
      switch(m_structureType)
      {
         case STRUCTURE_HH: sStruct = "HH"; break;
         case STRUCTURE_HL: sStruct = "HL"; break;
         case STRUCTURE_LH: sStruct = "LH"; break;
         case STRUCTURE_LL: sStruct = "LL"; break;
         default: break;
      }
      return StringFormat("[Swing: %s | Struct: %s | Price: %.5f | Bar: %d | Confirmed: %s | Score: %d]",
                          sType, sStruct, m_price, m_barIndex, (m_confirmed ? "YES" : "NO"), m_strengthScore);
   }
};

//+------------------------------------------------------------------+
//| Structure SZone                                                  |
//| Container for dynamic supply, demand, and liquidity zones        |
//+------------------------------------------------------------------+
struct SZone
{
   ulong                 id;
   ENUM_ZONE_TYPE        type;
   double                topPrice;
   double                bottomPrice;
   double                meanPrice;
   datetime              creationTime;
   int                   touchCount;
   int                   strengthScore;
   ENUM_MITIGATION_STATE mitigationState;
   ENUM_TIMEFRAMES       timeframe;

   SZone()
   {
      id              = 0;
      type            = ZONE_NONE;
      topPrice        = 0.0;
      bottomPrice     = 0.0;
      meanPrice       = 0.0;
      creationTime    = 0;
      touchCount      = 0;
      strengthScore   = 0;
      mitigationState = STATE_UNMITIGATED;
      timeframe       = PERIOD_CURRENT;
   }
};

//+------------------------------------------------------------------+
//| Structure SOrderBlock                                            |
//| Represents institutional order block candles                     |
//+------------------------------------------------------------------+
struct SOrderBlock
{
   ulong                 id;
   bool                  isBullish;
   datetime              time;
   double                openPrice;
   double                highPrice;
   double                lowPrice;
   double                closePrice;
   double                fvgGapSize;
   bool                  isMitigated;
   datetime              mitigationTime;

   SOrderBlock()
   {
      id             = 0;
      isBullish      = false;
      time           = 0;
      openPrice      = 0.0;
      highPrice      = 0.0;
      lowPrice       = 0.0;
      closePrice     = 0.0;
      fvgGapSize     = 0.0;
      isMitigated    = false;
      mitigationTime = 0;
   }
};

//+------------------------------------------------------------------+
//| Structure SFairValueGap                                          |
//| Imbalance / Fair Value Gap structure                             |
//+------------------------------------------------------------------+
struct SFairValueGap
{
   ulong                 id;
   bool                  isBullish;
   datetime              time;
   double                topPrice;
   double                bottomPrice;
   double                midPrice;       // 50% Consequent Encroachment (CE)
   ENUM_MITIGATION_STATE state;
   double                fillPercentage;

   SFairValueGap()
   {
      id             = 0;
      isBullish      = false;
      time           = 0;
      topPrice       = 0.0;
      bottomPrice    = 0.0;
      midPrice       = 0.0;
      state          = STATE_UNMITIGATED;
      fillPercentage = 0.0;
   }
};

#endif // __IMSF_TYPES_MQH__

