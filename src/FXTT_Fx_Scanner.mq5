#property copyright "Copyright 2016, Carlos Oliveira"
#property link      "https://www.forextradingtools.eu/products/indicators/forex-scanner-free-indicator/"
#property version   "1.30"
#property indicator_chart_window
#property indicator_plots 0

//--- Prefix for all chart objects created by this indicator
const string INDI_NAME = "MPSCN-";

//--- Module-level reusable copy buffer (avoids per-call heap allocation)
double g_buf[1];

//--- Tracks last full scanner refresh time (used by OnTimer)
datetime g_lastScanTime = 0;

//--- Saved original chart appearance (restored on deinit)
color    g_origBackground;
color    g_origForeground;
color    g_origGrid;
long     g_origChartMode;
bool     g_chartModified = false;

//--- Previous symbol list — used to detect and remove ghost rows
string   g_prevSymbols[];

//--- Per-handle alert cooldown (indexed parallel to g_handles)
datetime g_lastAlertTime[];

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_SHOW_SYMBOLS
  {
   MarketWatch, //from Market Watch
   Custom       //from Custom List
  };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input ENUM_SHOW_SYMBOLS ShowSymbols       = MarketWatch; //Show Symbols from
input string            CustomSymbols     = "";          //Custom List (e.g. "EURUSD,GBPUSD")
input int               TimerInterval     = 60;          //Data refresh interval (secs)
input int               FontSize          = 8;           //Font Size
input string            FontName          = "Calibri";   //Font Name
input int               ColumnHeight      = 50;          //Max rows per column (new column when exceeded)
input bool              HideChartElements = true;        //Hide chart — scanner-only mode
input color             TextColor         = clrWhite;    //Text color (White for dark, Black for light themes)

input group "--- Price / Spread / Swap ---"
input bool ShowPrice  = true; //Show Price
input bool ShowSpread = true; //Show Spread
input bool ShowSwap   = true; //Show Swap

input group "--- ATR (displays % of average ATR) ---"
input bool            ShowATR      = true;      //Show ATR
input ENUM_TIMEFRAMES AtrTimeframe = PERIOD_H1; //ATR Timeframe
input int             AtrPeriod    = 20;        //ATR Period

input group "--- Volume (displays % of average volume) ---"
input bool            ShowVolume      = true;      //Show Volume
input ENUM_TIMEFRAMES VolumeTimeframe = PERIOD_H1; //Volume Timeframe
input int             VolumePeriod    = 60;        //Volume Period

input group "--- RSI ---"
input bool            ShowRsi       = true;      //Show RSI
input ENUM_TIMEFRAMES RsiTimeframe  = PERIOD_H1; //RSI Timeframe
input int             RsiPeriod     = 14;        //RSI Period
input int             RsiUpperLevel = 75;        //RSI Upper Level (overbought)
input int             RsiLowerLevel = 25;        //RSI Lower Level (oversold)

input group "--- Stochastic (shows %K value) ---"
input bool            ShowStoch       = true;        //Show Stochastic
input ENUM_TIMEFRAMES StochTimeframe  = PERIOD_H1;   //Stoch Timeframe
input int             StochK          = 5;           //%K period
input int             StochD          = 3;           //%D period
input int             StochSlow       = 3;           //Slowing
input ENUM_MA_METHOD  StochMethod     = MODE_SMA;    //MA Method
input ENUM_STO_PRICE  StochPrice      = STO_LOWHIGH; //Price Field
input int             StochUpperLevel = 80;          //Stoch Upper Level (overbought)
input int             StochLowerLevel = 20;          //Stoch Lower Level (oversold)

input group "--- ADX ---"
input bool            ShowAdx      = true;      //Show ADX
input ENUM_TIMEFRAMES AdxTimeframe = PERIOD_H1; //ADX Timeframe
input int             AdxPeriod    = 20;        //ADX Period

input group "--- Pivots ---"
input bool            ShowPivots     = true;      //Show Pivots (hover cell for all levels + pip distance)
input ENUM_TIMEFRAMES PivotTimeframe = PERIOD_D1; //Pivot Timeframe

input group "--- Moving Average ---"
input bool               ShowMA         = true;        //Show MA (direction + pip distance from MA)
input ENUM_TIMEFRAMES    MATimeframe    = PERIOD_H1;   //MA Timeframe
input int                MAPeriod       = 60;          //MA Period
input ENUM_MA_METHOD     MAMethod       = MODE_SMA;    //MA Method
input ENUM_APPLIED_PRICE MAAppliedPrice = PRICE_CLOSE; //MA Applied

input group "--- MA Cross ---"
input bool               ShowMACross        = true;        //Show MA Cross
input ENUM_TIMEFRAMES    FastMATimeframe    = PERIOD_H1;   //Fast MA Timeframe
input int                FastMAPeriod       = 5;           //Fast MA Period
input ENUM_MA_METHOD     FastMAMethod       = MODE_SMA;    //Fast MA Method
input ENUM_APPLIED_PRICE FastMAAppliedPrice = PRICE_CLOSE; //Fast MA Applied
input ENUM_TIMEFRAMES    SlowMATimeframe    = PERIOD_H1;   //Slow MA Timeframe
input int                SlowMAPeriod       = 20;          //Slow MA Period
input ENUM_MA_METHOD     SlowMAMethod       = MODE_SMA;    //Slow MA Method
input ENUM_APPLIED_PRICE SlowMAAppliedPrice = PRICE_CLOSE; //Slow MA Applied
input int                MACrossAtrPeriod   = 20;          //ATR period for 'Near Cross' detection

input group "--- Alerts ---"
input bool AlertRsiLevels     = false; //Alert on RSI overbought/oversold
input bool AlertStochLevels   = false; //Alert on Stoch overbought/oversold
input bool AlertMACross       = false; //Alert on MA Cross
input bool AlertPushNotify    = false; //Also send push notification
input int  AlertCooldownHours = 4;     //Alert cooldown per symbol (hours)

//+------------------------------------------------------------------+
//| GUI layout — all pixel values derived from FontSize             |
//+------------------------------------------------------------------+
int S(int px) { return (int)MathRound(px * FontSize / 8.0); }

int ColSymbol()  { return S(80);  }
int ColPrice()   { return S(60);  }
int ColSpread()  { return S(60);  }
int ColSwap()    { return S(100); }
int ColStd()     { return S(100); }
int ColAdx()     { return S(130); }
int ColMaCross() { return S(130); }

int RowH()       { return S(15); }
int HeaderY()    { return S(45); }
int DataStartY() { return S(60); }
int TimeBarY()   { return S(20); }

int PanelWidth()
  {
   int w = ColSymbol();
   if(ShowPrice)   w += ColPrice();
   if(ShowSpread)  w += ColSpread();
   if(ShowSwap)    w += ColSwap();
   if(ShowATR)     w += ColStd();
   if(ShowVolume)  w += ColStd();
   if(ShowRsi)     w += ColStd();
   if(ShowStoch)   w += ColStd();
   if(ShowAdx)     w += ColAdx();
   if(ShowPivots)  w += ColStd();
   if(ShowMA)      w += ColStd();
   if(ShowMACross) w += ColMaCross();
   return w;
  }

//+------------------------------------------------------------------+
//| Indicator handle cache — one entry per symbol                   |
//+------------------------------------------------------------------+
struct TSymbolHandles
  {
   string symbol;
   int    rsi;
   int    atr;
   int    ma;
   int    fastMa;
   int    slowMa;
   int    stoch;
   int    adx;
   int    atrCross;
  };

TSymbolHandles g_handles[];

int FindHandleIndex(const string symbol)
  {
   for(int i = 0; i < ArraySize(g_handles); i++)
      if(g_handles[i].symbol == symbol) return i;
   return -1;
  }

int GetOrCreateHandleIndex(const string symbol)
  {
   int idx = FindHandleIndex(symbol);
   if(idx >= 0) return idx;

   int newIdx = ArraySize(g_handles);
   ArrayResize(g_handles,       newIdx + 1);
   ArrayResize(g_lastAlertTime, newIdx + 1);

   TSymbolHandles h;
   h.symbol   = symbol;
   h.rsi      = iRSI        (symbol, RsiTimeframe,    RsiPeriod,    PRICE_CLOSE);
   h.atr      = iATR        (symbol, AtrTimeframe,    AtrPeriod);
   h.ma       = iMA         (symbol, MATimeframe,     MAPeriod,     0, MAMethod,     MAAppliedPrice);
   h.fastMa   = iMA         (symbol, FastMATimeframe, FastMAPeriod, 0, FastMAMethod, FastMAAppliedPrice);
   h.slowMa   = iMA         (symbol, SlowMATimeframe, SlowMAPeriod, 0, SlowMAMethod, SlowMAAppliedPrice);
   h.stoch    = iStochastic (symbol, StochTimeframe,  StochK, StochD, StochSlow, StochMethod, StochPrice);
   h.adx      = iADX        (symbol, AdxTimeframe,    AdxPeriod);
   h.atrCross = iATR        (symbol, FastMATimeframe, MACrossAtrPeriod);

   g_handles[newIdx]       = h;
   g_lastAlertTime[newIdx] = 0;
   return newIdx;
  }

//+------------------------------------------------------------------+
//| Read one buffer value; returns EMPTY_VALUE when unavailable     |
//+------------------------------------------------------------------+
double GetBufferValue(const int handle, const int bufferIdx, const int shift)
  {
   if(handle == INVALID_HANDLE) return EMPTY_VALUE;
   ArraySetAsSeries(g_buf, true);
   if(CopyBuffer(handle, bufferIdx, shift, 1, g_buf) <= 0) return EMPTY_VALUE;
   return g_buf[0];
  }

//+------------------------------------------------------------------+
void ReleaseAllHandles()
  {
   for(int i = 0; i < ArraySize(g_handles); i++)
     {
      if(g_handles[i].rsi      != INVALID_HANDLE) IndicatorRelease(g_handles[i].rsi);
      if(g_handles[i].atr      != INVALID_HANDLE) IndicatorRelease(g_handles[i].atr);
      if(g_handles[i].ma       != INVALID_HANDLE) IndicatorRelease(g_handles[i].ma);
      if(g_handles[i].fastMa   != INVALID_HANDLE) IndicatorRelease(g_handles[i].fastMa);
      if(g_handles[i].slowMa   != INVALID_HANDLE) IndicatorRelease(g_handles[i].slowMa);
      if(g_handles[i].stoch    != INVALID_HANDLE) IndicatorRelease(g_handles[i].stoch);
      if(g_handles[i].adx      != INVALID_HANDLE) IndicatorRelease(g_handles[i].adx);
      if(g_handles[i].atrCross != INVALID_HANDLE) IndicatorRelease(g_handles[i].atrCross);
     }
   ArrayFree(g_handles);
  }

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(ColumnHeight < 1)
     {
      Alert("FX Scanner: ColumnHeight must be >= 1");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(TimerInterval < 5)
     {
      Alert("FX Scanner: TimerInterval must be >= 5 seconds");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(AlertCooldownHours < 0)
     {
      Alert("FX Scanner: AlertCooldownHours must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
     }

   // Save original chart appearance before any modification
   g_origBackground = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   g_origForeground = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   g_origGrid       = (color)ChartGetInteger(0, CHART_COLOR_GRID);
   g_origChartMode  = ChartGetInteger(0, CHART_MODE);

   if(HideChartElements)
     {
      ChartSetInteger(0, CHART_COLOR_BACKGROUND,  clrBlack);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND,  clrWhite);
      ChartSetInteger(0, CHART_COLOR_GRID,        clrNONE);
      ChartSetInteger(0, CHART_COLOR_VOLUME,      clrNONE);
      ChartSetInteger(0, CHART_COLOR_CHART_UP,    clrNONE);
      ChartSetInteger(0, CHART_COLOR_CHART_DOWN,  clrNONE);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE,  clrNONE);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrNONE);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrNONE);
      ChartSetInteger(0, CHART_COLOR_BID,         clrNONE);
      ChartSetInteger(0, CHART_COLOR_ASK,         clrNONE);
      ChartSetInteger(0, CHART_COLOR_LAST,        clrNONE);
      ChartSetInteger(0, CHART_COLOR_STOP_LEVEL,  clrNONE);
      ChartSetInteger(0, CHART_MODE,              CHART_LINE);
      g_chartModified = true;
     }

   EventSetTimer(1);

   DrawScanner();
   g_lastScanTime = TimeCurrent();

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| De-initialisation                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ReleaseAllHandles();
   ObjectsDeleteAll(ChartID(), INDI_NAME);

   if(g_chartModified)
     {
      ChartSetInteger(0, CHART_COLOR_BACKGROUND, g_origBackground);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND, g_origForeground);
      ChartSetInteger(0, CHART_COLOR_GRID,       g_origGrid);
      ChartSetInteger(0, CHART_MODE,             g_origChartMode);
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//| OnCalculate — price bar feed (no per-tick work needed)          |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
  {
   return rates_total;
  }

//+------------------------------------------------------------------+
//| Timer — time display every second, full scan at interval        |
//+------------------------------------------------------------------+
void OnTimer()
  {
   DrawMissingTime();
   datetime now = TimeCurrent();
   if(now - g_lastScanTime >= (datetime)TimerInterval)
     {
      g_lastScanTime = now;
      DrawScanner();
     }
   else
      ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Scanner dispatcher                                               |
//+------------------------------------------------------------------+
void DrawScanner()
  {
   ObjectDelete(0, INDI_NAME + ":info_msg"); // clear any previous info message
   DrawHeader();                             // rebuild — panel count may have changed
   if(ShowSymbols == MarketWatch)
      DrawFromMarketWatch();
   else
      DrawFromCustomList();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Ghost-row cleanup                                                |
//+------------------------------------------------------------------+
void DeleteRemovedSymbolRows(const string &currentSymbols[])
  {
   for(int p = 0; p < ArraySize(g_prevSymbols); p++)
     {
      bool found = false;
      for(int c = 0; c < ArraySize(currentSymbols); c++)
         if(g_prevSymbols[p] == currentSymbols[c]) { found = true; break; }
      if(!found)
         DeleteSymbolRow(g_prevSymbols[p]);
     }
  }

void DeleteSymbolRow(const string sym)
  {
   string prefix = INDI_NAME + ":";
   string tags[] = {"lbl_", "price_", "spread_", "swap_L_", "swap_X_", "swap_S_",
                    "atr_", "vol_",   "rsi_",    "stoch_",  "adx_",    "pivots_",
                    "ma_",  "macross_"};
   for(int i = 0; i < ArraySize(tags); i++)
      ObjectDelete(0, prefix + tags[i] + sym);
  }

//+------------------------------------------------------------------+
void DrawFromMarketWatch()
  {
   int    count = SymbolsTotal(true);
   string syms[];
   ArrayResize(syms, count);
   for(int i = 0; i < count; i++)
      syms[i] = SymbolName(i, true);

   DeleteRemovedSymbolRows(syms);
   ArrayCopy(g_prevSymbols, syms);

   for(int i = 0; i < count; i++)
      DrawSymbol(syms[i], i);
  }

//+------------------------------------------------------------------+
void DrawFromCustomList()
  {
   string raw = CustomSymbols;
   StringTrimLeft(raw);
   StringTrimRight(raw);

   string syms[];
   int    k = 0;

   if(StringLen(raw) > 0)
     {
      ushort sep = StringGetCharacter(",", 0);
      k = StringSplit(raw, sep, syms);
      for(int i = 0; i < k; i++)
        {
         StringTrimLeft(syms[i]);
         StringTrimRight(syms[i]);
        }
     }

   DeleteRemovedSymbolRows(syms);
   ArrayCopy(g_prevSymbols, syms);

   if(k == 0)
     {
      DrawLabel("info_msg", S(20), DataStartY(),
                "No symbols configured. Set the 'Custom List' input (e.g. EURUSD,GBPUSD)",
                FontSize, FontName, clrOrange);
      return;
     }

   for(int i = 0; i < k; i++)
      DrawSymbol(syms[i], i);
  }

//+------------------------------------------------------------------+
//| Draw all visible columns for one symbol row                     |
//+------------------------------------------------------------------+
void DrawSymbol(const string symbolName, const int symbolIdx)
  {
   int yMult = (int)MathMod(symbolIdx, ColumnHeight);
   int xMult = symbolIdx / ColumnHeight;
   int x     = S(20) + PanelWidth() * xMult;
   int y     = DataStartY() + RowH() * yMult;

   DrawSymbolColumn(symbolName, x, y);
   x += ColSymbol();

   if(ShowPrice)   { DrawPriceColumn  (symbolName, x, y); x += ColPrice();  }
   if(ShowSpread)  { DrawSpreadColumn (symbolName, x, y); x += ColSpread(); }
   if(ShowSwap)    { DrawSwapColumn   (symbolName, x, y); x += ColSwap();   }
   if(ShowATR)     { DrawRangeColumn  (symbolName, x, y); x += ColStd();    }
   if(ShowVolume)  { DrawVolumeColumn (symbolName, x, y); x += ColStd();    }
   if(ShowRsi)     { DrawRsiColumn    (symbolName, x, y); x += ColStd();    }
   if(ShowStoch)   { DrawStochColumn  (symbolName, x, y); x += ColStd();    }
   if(ShowAdx)     { DrawAdxColumn    (symbolName, x, y); x += ColAdx();    }
   if(ShowPivots)  { DrawPivotsColumn (symbolName, x, y); x += ColStd();    }
   if(ShowMA)      { DrawMAColumn     (symbolName, x, y); x += ColStd();    }
   if(ShowMACross) { DrawMACrossColumn(symbolName, x, y);                   }
  }

//+------------------------------------------------------------------+
//| Individual column drawing functions                             |
//+------------------------------------------------------------------+
void DrawSymbolColumn(const string symbolName, const int x, const int y)
  {
   DrawLabel("lbl_" + symbolName, x, y, symbolName, FontSize, FontName, TextColor, symbolName);
  }

//+------------------------------------------------------------------+
void DrawPriceColumn(const string symbolName, const int x, const int y)
  {
   int    digits = (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS);
   double bid    = SymbolInfoDouble(symbolName, SYMBOL_BID);
   DrawLabel("price_" + symbolName, x, y, DoubleToString(bid, digits), FontSize, FontName, TextColor);
  }

//+------------------------------------------------------------------+
void DrawSpreadColumn(const string symbolName, const int x, const int y)
  {
   int spread = (int)SymbolInfoInteger(symbolName, SYMBOL_SPREAD);
   DrawLabel("spread_" + symbolName, x, y, IntegerToString(spread), FontSize, FontName, TextColor);
  }

//+------------------------------------------------------------------+
void DrawSwapColumn(const string symbolName, const int x, const int y)
  {
   double swapLong  = SymbolInfoDouble(symbolName, SYMBOL_SWAP_LONG);
   double swapShort = SymbolInfoDouble(symbolName, SYMBOL_SWAP_SHORT);

   color clrLong  = (swapLong  > 0) ? clrLime : (swapLong  < 0 ? clrRed : TextColor);
   color clrShort = (swapShort > 0) ? clrLime : (swapShort < 0 ? clrRed : TextColor);

   DrawLabel("swap_L_" + symbolName, x,         y, DoubleToString(swapLong,  2), FontSize, FontName, clrLong);
   DrawLabel("swap_X_" + symbolName, x + S(38), y, "/",                           FontSize, FontName, TextColor);
   DrawLabel("swap_S_" + symbolName, x + S(50), y, DoubleToString(swapShort, 2), FontSize, FontName, clrShort);
  }

//+------------------------------------------------------------------+
void DrawRangeColumn(const string symbolName, const int x, const int y)
  {
   int    hIdx   = GetOrCreateHandleIndex(symbolName);
   double point  = SymbolInfoDouble(symbolName, SYMBOL_POINT);
   double atrRaw = GetBufferValue(g_handles[hIdx].atr, 0, 0);

   if(atrRaw == EMPTY_VALUE)
     {
      DrawLabel("atr_" + symbolName, x, y, "---", FontSize, FontName, clrGray);
      return;
     }

   double modifier    = GetModifier(symbolName);
   double atr         = (point > 0) ? NormalizeDouble(atrRaw / point, 0) / modifier : 1.0;
   if(atr == 0) atr   = 1.0;
   double range        = GetRange(symbolName, AtrTimeframe) / modifier;
   double rangePercent = (range / atr) * 100.0;

   string tooltip = symbolName + " ATR (" + GetPeriodStr(AtrTimeframe) + ")" +
                    "\nCurrent bar range: " + DoubleToString(range, 1) + " pips" +
                    "\nAvg ATR (" + IntegerToString(AtrPeriod) + " bars): " + DoubleToString(atr, 1) + " pips" +
                    "\nRange as % of avg ATR: " + DoubleToString(rangePercent, 1) + "%";

   DrawLabel("atr_" + symbolName, x, y,
             DoubleToString(rangePercent, 1) + "%",
             FontSize, FontName, GetPercentColor(rangePercent), tooltip);
  }

//+------------------------------------------------------------------+
void DrawVolumeColumn(const string symbolName, const int x, const int y)
  {
   long   volume = GetTickVolume(symbolName, VolumeTimeframe, 0);
   double volAvg = (double)GetAvgVolume(symbolName, VolumeTimeframe, VolumePeriod);
   if(volAvg == 0) volAvg = 1.0;
   double volPct = (volume / volAvg) * 100.0;

   string tooltip = symbolName + " Volume (" + GetPeriodStr(VolumeTimeframe) + ")" +
                    "\nCurrent bar volume: " + DoubleToString((double)volume, 0) +
                    "\nAvg volume (" + IntegerToString(VolumePeriod) + " bars): " + DoubleToString(volAvg, 0) +
                    "\nVolume as % of average: " + DoubleToString(volPct, 1) + "%";

   DrawLabel("vol_" + symbolName, x, y,
             DoubleToString(volPct, 2) + "%",
             FontSize, FontName, GetPercentColor(volPct), tooltip);
  }

//+------------------------------------------------------------------+
void DrawRsiColumn(const string symbolName, const int x, const int y)
  {
   int    hIdx = GetOrCreateHandleIndex(symbolName);
   double rsi  = GetBufferValue(g_handles[hIdx].rsi, 0, 0);

   if(rsi == EMPTY_VALUE)
     {
      DrawLabel("rsi_" + symbolName, x, y, "---", FontSize, FontName, clrGray);
      return;
     }

   rsi = NormalizeDouble(rsi, 0);

   string tooltip = symbolName + " RSI (" + GetPeriodStr(RsiTimeframe) + ", " + IntegerToString(RsiPeriod) + ")" +
                    "\nValue: " + DoubleToString(rsi, 1) +
                    "\nOverbought above: " + IntegerToString(RsiUpperLevel) +
                    "\nOversold below: "   + IntegerToString(RsiLowerLevel);

   DrawLabel("rsi_" + symbolName, x, y, DoubleToString(rsi, 1),
             FontSize, FontName, GetRsiColor(rsi), tooltip);

   if(AlertRsiLevels)
      CheckRsiAlert(symbolName, hIdx, rsi);
  }

//+------------------------------------------------------------------+
void DrawStochColumn(const string symbolName, const int x, const int y)
  {
   int    hIdx  = GetOrCreateHandleIndex(symbolName);
   double stoch = GetBufferValue(g_handles[hIdx].stoch, 0, 0);

   if(stoch == EMPTY_VALUE)
     {
      DrawLabel("stoch_" + symbolName, x, y, "---", FontSize, FontName, clrGray);
      return;
     }

   string tooltip = symbolName + " Stoch %K (" + GetPeriodStr(StochTimeframe) + ", " +
                    IntegerToString(StochK) + "/" + IntegerToString(StochD) + ")" +
                    "\nValue: " + DoubleToString(stoch, 1) +
                    "\nOverbought above: " + IntegerToString(StochUpperLevel) +
                    "\nOversold below: "   + IntegerToString(StochLowerLevel);

   DrawLabel("stoch_" + symbolName, x, y, DoubleToString(stoch, 1),
             FontSize, FontName, GetStochColor(stoch), tooltip);

   if(AlertStochLevels)
      CheckStochAlert(symbolName, hIdx, stoch);
  }

//+------------------------------------------------------------------+
void DrawAdxColumn(const string symbolName, const int x, const int y)
  {
   int    hIdx = GetOrCreateHandleIndex(symbolName);
   double adx  = GetBufferValue(g_handles[hIdx].adx, 0, 0);

   if(adx == EMPTY_VALUE)
     {
      DrawLabel("adx_" + symbolName, x, y, "---", FontSize, FontName, clrGray);
      return;
     }

   string tooltip = symbolName + " ADX (" + GetPeriodStr(AdxTimeframe) + ", " + IntegerToString(AdxPeriod) + ")" +
                    "\nValue: " + DoubleToString(adx, 1) +
                    "\n<=25: No Trend  26-50: Weak  51-75: Strong  >75: Very Strong";

   DrawLabel("adx_" + symbolName, x, y, GetAdxStr(adx),
             FontSize, FontName, GetAdxColor(adx), tooltip);
  }

//+------------------------------------------------------------------+
void DrawPivotsColumn(const string symbolName, const int x, const int y)
  {
   int    digits   = (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS);
   double bid      = SymbolInfoDouble(symbolName, SYMBOL_BID);
   double point    = SymbolInfoDouble(symbolName, SYMBOL_POINT);
   double modifier = GetModifier(symbolName);
   double pivot    = NormalizeDouble(GetPivotValue(symbolName, PivotTimeframe), digits);

   double pivots[7];
   pivots[0] = pivot;
   pivots[1] = NormalizeDouble(GetPivotResistance(symbolName, PivotTimeframe, pivot, 1), digits);
   pivots[2] = NormalizeDouble(GetPivotResistance(symbolName, PivotTimeframe, pivot, 2), digits);
   pivots[3] = NormalizeDouble(GetPivotResistance(symbolName, PivotTimeframe, pivot, 3), digits);
   pivots[4] = NormalizeDouble(GetPivotSupport   (symbolName, PivotTimeframe, pivot, 1), digits);
   pivots[5] = NormalizeDouble(GetPivotSupport   (symbolName, PivotTimeframe, pivot, 2), digits);
   pivots[6] = NormalizeDouble(GetPivotSupport   (symbolName, PivotTimeframe, pivot, 3), digits);

   int    closestIdx = GetClosestPivot(bid, pivots);
   double priceDiff  = bid - pivots[closestIdx];
   double pipDist    = (point > 0) ? MathAbs(priceDiff) / point / modifier : 0.0;
   string direction  = GetPivotDirection(priceDiff);
   string pivotText  = direction + " " + GetPivotStr(closestIdx);

   string tooltip = symbolName + " Pivots (" + GetPeriodStr(PivotTimeframe) + ")" +
                    "\nPrice is " + direction + " " + GetPivotStr(closestIdx) +
                    " by " + DoubleToString(pipDist, 1) + " pips" +
                    "\nR3: " + DoubleToString(pivots[3], digits) +
                    "\nR2: " + DoubleToString(pivots[2], digits) +
                    "\nR1: " + DoubleToString(pivots[1], digits) +
                    "\nPP: " + DoubleToString(pivots[0], digits) +
                    "\nS1: " + DoubleToString(pivots[4], digits) +
                    "\nS2: " + DoubleToString(pivots[5], digits) +
                    "\nS3: " + DoubleToString(pivots[6], digits);

   DrawLabel("pivots_" + symbolName, x, y, pivotText,
             FontSize, FontName, GetPivotColor(closestIdx), tooltip);
  }

//+------------------------------------------------------------------+
void DrawMAColumn(const string symbolName, const int x, const int y)
  {
   int    hIdx   = GetOrCreateHandleIndex(symbolName);
   int    digits = (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS);
   double ask    = NormalizeDouble(SymbolInfoDouble(symbolName, SYMBOL_ASK), digits);
   double ma     = GetBufferValue(g_handles[hIdx].ma, 0, 0);

   if(ma == EMPTY_VALUE)
     {
      DrawLabel("ma_" + symbolName, x, y, "---", FontSize, FontName, clrGray);
      return;
     }

   double point    = SymbolInfoDouble(symbolName, SYMBOL_POINT);
   double modifier = GetModifier(symbolName);
   double pipDist  = (point > 0) ? MathAbs(ask - ma) / point / modifier : 0.0;

   string tooltip = symbolName + " MA" + IntegerToString(MAPeriod) +
                    " (" + GetPeriodStr(MATimeframe) + ")" +
                    "\nMA value: " + DoubleToString(ma, digits) +
                    "\nCurrent price: " + DoubleToString(ask, digits) +
                    "\nDistance: " + DoubleToString(pipDist, 1) + " pips";

   DrawLabel("ma_" + symbolName, x, y, GetMAStr(ma, ask, pipDist),
             FontSize, FontName, GetMAColor(ma, ask), tooltip);
  }

//+------------------------------------------------------------------+
void DrawMACrossColumn(const string symbolName, const int x, const int y)
  {
   int    hIdx     = GetOrCreateHandleIndex(symbolName);
   int    digits   = (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS);
   double fastMa   = GetBufferValue(g_handles[hIdx].fastMa,   0, 0);
   double slowMa   = GetBufferValue(g_handles[hIdx].slowMa,   0, 0);
   double fastMaB1 = GetBufferValue(g_handles[hIdx].fastMa,   0, 1);
   double slowMaB1 = GetBufferValue(g_handles[hIdx].slowMa,   0, 1);
   double atr      = GetBufferValue(g_handles[hIdx].atrCross, 0, 0);

   if(fastMa == EMPTY_VALUE || slowMa == EMPTY_VALUE ||
      fastMaB1 == EMPTY_VALUE || slowMaB1 == EMPTY_VALUE)
     {
      DrawLabel("macross_" + symbolName, x, y, "---", FontSize, FontName, clrGray);
      return;
     }

   double atrHalf   = (atr != EMPTY_VALUE) ? atr / 2.0 : 0.0;
   bool isCrossUp   = (fastMa >= slowMa && fastMaB1 < slowMaB1);
   bool isCrossDown = (fastMa <= slowMa && fastMaB1 > slowMaB1);
   bool isNear      = (atrHalf > 0 && MathAbs(fastMa - slowMa) < atrHalf);

   string status  = GetMACrossStr(isCrossUp, isCrossDown, isNear);
   string tooltip = symbolName + " MA Cross (" + GetPeriodStr(FastMATimeframe) + ")" +
                    "\nFast MA" + IntegerToString(FastMAPeriod) + ": " + DoubleToString(fastMa, digits) +
                    "\nSlow MA" + IntegerToString(SlowMAPeriod) + ": " + DoubleToString(slowMa, digits) +
                    "\nStatus: " + status;

   DrawLabel("macross_" + symbolName, x, y, status,
             FontSize, FontName,
             GetMACrossColor(isCrossUp, isCrossDown, isNear), tooltip);

   if(AlertMACross)
      CheckMACrossAlert(symbolName, hIdx, isCrossUp, isCrossDown);
  }

//+------------------------------------------------------------------+
//| Alert helpers                                                    |
//+------------------------------------------------------------------+
void SendScannerAlert(const int hIdx, const string msg)
  {
   datetime now      = TimeCurrent();
   datetime cooldown = (datetime)((long)AlertCooldownHours * 3600);
   if(now - g_lastAlertTime[hIdx] < cooldown) return;
   g_lastAlertTime[hIdx] = now;
   Alert(msg);
   if(AlertPushNotify) SendNotification(msg);
  }

void CheckRsiAlert(const string sym, const int hIdx, const double rsi)
  {
   string tf = GetPeriodStr(RsiTimeframe);
   if(rsi >= RsiUpperLevel)
      SendScannerAlert(hIdx, sym + " RSI (" + tf + ") Overbought: " + DoubleToString(rsi, 1));
   else if(rsi <= RsiLowerLevel)
      SendScannerAlert(hIdx, sym + " RSI (" + tf + ") Oversold: "   + DoubleToString(rsi, 1));
  }

void CheckStochAlert(const string sym, const int hIdx, const double stoch)
  {
   string tf = GetPeriodStr(StochTimeframe);
   if(stoch >= StochUpperLevel)
      SendScannerAlert(hIdx, sym + " Stoch (" + tf + ") Overbought: " + DoubleToString(stoch, 1));
   else if(stoch <= StochLowerLevel)
      SendScannerAlert(hIdx, sym + " Stoch (" + tf + ") Oversold: "   + DoubleToString(stoch, 1));
  }

void CheckMACrossAlert(const string sym, const int hIdx,
                       const bool crossUp, const bool crossDown)
  {
   string tf  = GetPeriodStr(FastMATimeframe);
   string mas = IntegerToString(FastMAPeriod) + "x" + IntegerToString(SlowMAPeriod);
   if(crossUp)
      SendScannerAlert(hIdx, sym + " MA CrossUp ("   + tf + " " + mas + ")");
   else if(crossDown)
      SendScannerAlert(hIdx, sym + " MA CrossDown (" + tf + " " + mas + ")");
  }

//+------------------------------------------------------------------+
//| Header row                                                       |
//+------------------------------------------------------------------+
void DrawHeader()
  {
   int totalSymbols;
   if(ShowSymbols == MarketWatch)
     {
      totalSymbols = SymbolsTotal(true);
     }
   else
     {
      string parts[];
      string raw = CustomSymbols;
      StringTrimLeft(raw);
      StringTrimRight(raw);
      totalSymbols = (StringLen(raw) > 0)
                     ? StringSplit(raw, StringGetCharacter(",", 0), parts)
                     : 0;
     }

   // Ceiling division — avoids empty trailing panel
   int numPanels = (totalSymbols + ColumnHeight - 1) / ColumnHeight;
   if(numPanels < 1) numPanels = 1;

   for(int i = 0; i < numPanels; i++)
     {
      int    x = S(20) + PanelWidth() * i;
      int    y = HeaderY();
      string n = IntegerToString(i);

      DrawLabel("Headername" + n, x, y, "Name", FontSize, FontName, TextColor, "Symbol name");
      DrawHorizontalLine("Headernamehline" + n, x, y, 15);
      x += ColSymbol();

      if(ShowPrice)
        {
         DrawLabel("Headerprice" + n, x, y, "Price", FontSize, FontName, TextColor,
                   "Current bid price");
         DrawHorizontalLine("Headerpricehline" + n, x, y, 15);
         x += ColPrice();
        }
      if(ShowSpread)
        {
         DrawLabel("Headerspread" + n, x, y, "Spread", FontSize, FontName, TextColor,
                   "Current spread in points");
         DrawHorizontalLine("Headerspreadhline" + n, x, y, 15);
         x += ColSpread();
        }
      if(ShowSwap)
        {
         DrawLabel("Headerswap" + n, x, y, "Swap L/S", FontSize, FontName, TextColor,
                   "Overnight swap: Long / Short\nGreen = positive, Red = negative");
         DrawHorizontalLine("Headerswaphline" + n, x, y, 15);
         x += ColSwap();
        }
      if(ShowATR)
        {
         DrawLabel("Headerrange" + n, x, y,
                   "ATR% (" + GetPeriodStr(AtrTimeframe) + ")",
                   FontSize, FontName, TextColor,
                   "ATR: Current bar range as % of average ATR (" + IntegerToString(AtrPeriod) + " bars)\n"
                   "Hover each cell for raw pip values");
         DrawHorizontalLine("Headerrangehline" + n, x, y, 15);
         x += ColStd();
        }
      if(ShowVolume)
        {
         DrawLabel("Headercurvolume" + n, x, y,
                   "Vol% (" + GetPeriodStr(VolumeTimeframe) + ")",
                   FontSize, FontName, TextColor,
                   "Volume: Current bar volume as % of average (" + IntegerToString(VolumePeriod) + " bars)\n"
                   "Hover each cell for raw values");
         DrawHorizontalLine("Headervolhline" + n, x, y, 15);
         x += ColStd();
        }
      if(ShowRsi)
        {
         DrawLabel("Headerrsi" + n, x, y,
                   "RSI (" + GetPeriodStr(RsiTimeframe) + ")",
                   FontSize, FontName, TextColor,
                   "RSI (" + IntegerToString(RsiPeriod) + ") — "
                   "Green >= " + IntegerToString(RsiUpperLevel) + " (overbought), "
                   "Orange <= " + IntegerToString(RsiLowerLevel) + " (oversold)");
         DrawHorizontalLine("Headerrsihline" + n, x, y, 15);
         x += ColStd();
        }
      if(ShowStoch)
        {
         DrawLabel("Headerstoch" + n, x, y,
                   "Stoch% (" + GetPeriodStr(StochTimeframe) + ")",
                   FontSize, FontName, TextColor,
                   "Stochastic %K (" + IntegerToString(StochK) + "/" + IntegerToString(StochD) + ") — "
                   "Green >= " + IntegerToString(StochUpperLevel) + " (overbought), "
                   "Orange <= " + IntegerToString(StochLowerLevel) + " (oversold)");
         DrawHorizontalLine("Headerstochhline" + n, x, y, 15);
         x += ColStd();
        }
      if(ShowAdx)
        {
         DrawLabel("Headeradx" + n, x, y,
                   "ADX (" + GetPeriodStr(AdxTimeframe) + ")",
                   FontSize, FontName, TextColor,
                   "ADX (" + IntegerToString(AdxPeriod) + ") — trend strength\n"
                   "<=25: No Trend   26-50: Weak   51-75: Strong   >75: Very Strong");
         DrawHorizontalLine("Headeradxhline" + n, x, y, 15);
         x += ColAdx();
        }
      if(ShowPivots)
        {
         DrawLabel("Headerpivots" + n, x, y,
                   "Pivots (" + GetPeriodStr(PivotTimeframe) + ")",
                   FontSize, FontName, TextColor,
                   "Pivot points — price position relative to nearest level\n"
                   "Hover each cell for all levels (PP, R1-R3, S1-S3) and pip distance");
         DrawHorizontalLine("Headerpivotshline" + n, x, y, 15);
         x += ColStd();
        }
      if(ShowMA)
        {
         DrawLabel("Headerma" + n, x, y,
                   "MA" + IntegerToString(MAPeriod) + " (" + GetPeriodStr(MATimeframe) + ")",
                   FontSize, FontName, TextColor,
                   "MA" + IntegerToString(MAPeriod) + " — direction and pip distance from MA\n"
                   "Green = Above, Red = Below");
         DrawHorizontalLine("Headermaline" + n, x, y, 15);
         x += ColStd();
        }
      if(ShowMACross)
        {
         DrawLabel("Headermacross" + n, x, y,
                   "MA " + IntegerToString(FastMAPeriod) + "x" + IntegerToString(SlowMAPeriod) +
                   " (" + GetPeriodStr(FastMATimeframe) + ")",
                   FontSize, FontName, TextColor,
                   "MA Cross: Fast MA" + IntegerToString(FastMAPeriod) +
                   " vs Slow MA" + IntegerToString(SlowMAPeriod) +
                   " (" + GetPeriodStr(FastMATimeframe) + ")\n"
                   "Green = CrossUp, Red = CrossDown, White = Near, Gray = Far");
         DrawHorizontalLine("Headermacrossline" + n, x, y, 15);
        }
     }
  }

//+------------------------------------------------------------------+
//| Time-to-candle-close strip                                      |
//+------------------------------------------------------------------+
void DrawMissingTime()
  {
   int x0 = S(20);
   int y  = TimeBarY();
   int x1 = x0 + S(150);
   int x2 = x1 + S(150);
   int x3 = x2 + S(180);

   DrawLabel("CurTimeLbl",   x0, y, "Server Time: " + TimeToString(TimeCurrent(), TIME_MINUTES), FontSize, FontName, TextColor);
   DrawLabel("LocalTimeLbl", x1, y, "Local Time: "  + TimeToString(TimeLocal(),   TIME_MINUTES), FontSize, FontName, TextColor);
   DrawLabel("TimeLeftLbl",  x2, y, "Time 'til Candle close: ",                                  FontSize, FontName, TextColor);

   DrawTimeMissingColumn(PERIOD_M1,  x3,          y);
   DrawTimeMissingColumn(PERIOD_M5,  x3 + S(100), y);
   DrawTimeMissingColumn(PERIOD_M15, x3 + S(200), y, S(30));
   DrawTimeMissingColumn(PERIOD_H1,  x3 + S(300), y);
   DrawTimeMissingColumn(PERIOD_H4,  x3 + S(400), y);
   DrawTimeMissingColumn(PERIOD_D1,  x3 + S(500), y);

   string lastScanStr = (g_lastScanTime > 0)
                        ? "Scan: " + TimeToString(g_lastScanTime, TIME_SECONDS)
                        : "Scan: --:--:--";
   DrawLabel("LastScanLbl", x3 + S(620), y, lastScanStr, FontSize, FontName, clrGray,
             "Time of last full data refresh (interval: " + IntegerToString(TimerInterval) + "s)");
  }

//+------------------------------------------------------------------+
void DrawTimeMissingColumn(const ENUM_TIMEFRAMES period,
                           const int x, const int y, const int dxOffset = -1)
  {
   int    gap       = (dxOffset < 0) ? S(25) : dxOffset;
   color  timeColor;
   string periodStr = GetPeriodStr(period);
   string timeLeft  = GetTimeToClose(period, timeColor);

   DrawLabel("TimeLeftLbl_" + periodStr, x,       y, periodStr + ":", FontSize, FontName, TextColor);
   DrawLabel("TimeLeftVal_" + periodStr, x + gap, y, timeLeft,        FontSize, FontName, timeColor);
  }

//+------------------------------------------------------------------+
string GetTimeToClose(const ENUM_TIMEFRAMES period, color &timeColor)
  {
   int      periodSec   = PeriodSeconds(period);
   datetime barTime     = GetBarTime(Symbol(), period, 0);
   datetime closeTime   = barTime + (datetime)periodSec;
   int      secondsLeft = (int)(closeTime - TimeCurrent());

   string result = GetTimeStr(secondsLeft, timeColor);
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      result += " x";
   return result;
  }

//+------------------------------------------------------------------+
datetime GetBarTime(const string symbol, const ENUM_TIMEFRAMES period, const int shift)
  {
   datetime arr[];
   if(CopyTime(symbol, period, shift, 1, arr) <= 0)
      return TimeCurrent();
   return arr[0];
  }

//+------------------------------------------------------------------+
string GetTimeStr(int seconds, color &theColor)
  {
   if(seconds < 0)
     {
      theColor = clrOrange;
      seconds  = (int)MathAbs(seconds);
     }
   else
      theColor = clrYellow;

   int h = seconds / 3600;
   int m = (seconds % 3600) / 60;
   int s = seconds % 60;

   string result = "";
   if(h > 0)
      result = IntegerToString(h) + (m < 10 ? ":0" : ":");
   result += IntegerToString(m);
   result += (s < 10 ? ":0" : ":") + IntegerToString(s);
   return result;
  }

//+------------------------------------------------------------------+
//| Chart object helper — create-once, update-always                |
//+------------------------------------------------------------------+
void DrawLabel(const string name, const int x, const int y,
               const string label,
               const int size = 9, const string font = "Arial",
               const color clr = clrDimGray, const string tooltip = "")
  {
   string fullName = INDI_NAME + ":" + name;
   if(ObjectFind(0, fullName) < 0)
      ObjectCreate(0, fullName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, fullName, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE,   size);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
   ObjectSetString (0, fullName, OBJPROP_TEXT,       label);
   ObjectSetString (0, fullName, OBJPROP_FONT,       font);
   ObjectSetString (0, fullName, OBJPROP_TOOLTIP,    tooltip);
  }

//+------------------------------------------------------------------+
void DrawHorizontalLine(const string objName, const int x, const int y,
                        const int length = 250)
  {
   string line;
   StringInit(line, length, '_');
   DrawLabel(objName + "1", x, y, line, FontSize, FontName, TextColor);
  }

//+------------------------------------------------------------------+
//| Volume helpers                                                   |
//+------------------------------------------------------------------+
long GetTickVolume(const string symbol, const ENUM_TIMEFRAMES timeframe, const int shift)
  {
   long arr[];
   ArraySetAsSeries(arr, true);
   if(CopyTickVolume(symbol, timeframe, shift, 1, arr) <= 0) return 0;
   return arr[0];
  }

long GetAvgVolume(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period)
  {
   long arr[];
   ArraySetAsSeries(arr, true);
   int copied = CopyTickVolume(symbol, timeframe, 0, period, arr);
   if(copied <= 0) return 1;
   long total = 0;
   for(int i = 0; i < copied; i++) total += arr[i];
   return total / copied;
  }

//+------------------------------------------------------------------+
double GetRange(const string symbol, const ENUM_TIMEFRAMES period)
  {
   double range = iHigh(symbol, period, 0) - iLow(symbol, period, 0);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point > 0)
      return NormalizeDouble(range / point, 0);
   return 1.0;
  }

double GetModifier(const string symbol)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return (digits == 3 || digits == 5) ? 10.0 : 1.0;
  }

//+------------------------------------------------------------------+
//| Pivot point calculations                                         |
//+------------------------------------------------------------------+
double GetPivotValue(const string symbol, const ENUM_TIMEFRAMES timeframe)
  {
   return (iHigh(symbol, timeframe, 1) +
           iLow (symbol, timeframe, 1) +
           iClose(symbol, timeframe, 1)) / 3.0;
  }

double GetPivotResistance(const string symbol, const ENUM_TIMEFRAMES timeframe,
                          const double pivotValue, const int resistanceIdx = 1)
  {
   double hi = iHigh(symbol, timeframe, 1);
   double lo = iLow (symbol, timeframe, 1);
   switch(resistanceIdx)
     {
      case 3:  return hi + 2.0 * (pivotValue - lo);
      case 2:  return pivotValue + (hi - lo);
      default: return 2.0 * pivotValue - lo;
     }
  }

double GetPivotSupport(const string symbol, const ENUM_TIMEFRAMES timeframe,
                       const double pivotValue, const int supportIdx = 1)
  {
   double hi = iHigh(symbol, timeframe, 1);
   double lo = iLow (symbol, timeframe, 1);
   switch(supportIdx)
     {
      case 3:  return lo - 2.0 * (hi - pivotValue);
      case 2:  return pivotValue - (hi - lo);
      default: return 2.0 * pivotValue - hi;
     }
  }

int GetClosestPivot(const double price, const double &pivots[])
  {
   int    idx         = 0;
   double minDistance = DBL_MAX;
   for(int i = 0; i < ArraySize(pivots); i++)
     {
      double dist = MathAbs(price - pivots[i]);
      if(dist < minDistance)
        {
         minDistance = dist;
         idx         = i;
        }
     }
   return idx;
  }

//+------------------------------------------------------------------+
//| String helpers                                                   |
//+------------------------------------------------------------------+
string GetPivotDirection(const double value) { return (value > 0) ? "Above" : "Below"; }

string GetPivotStr(const int pivotIdx)
  {
   switch(pivotIdx)
     {
      case 1:  return "R1";
      case 2:  return "R2";
      case 3:  return "R3";
      case 4:  return "S1";
      case 5:  return "S2";
      case 6:  return "S3";
      default: return "PP";
     }
  }

string GetAdxStr(const double adx)
  {
   if(adx <= 25) return "No Trend";
   if(adx <= 50) return "Weak Trend";
   if(adx <= 75) return "Strong Trend";
   return "Very Strong";
  }

string GetMAStr(const double ma, const double price, const double pipDist)
  {
   string dir = (price > ma) ? "Above" : "Below";
   return dir + " " + DoubleToString(pipDist, 0) + "p";
  }

string GetMACrossStr(const bool crossUp, const bool crossDown, const bool near)
  {
   if(crossUp)   return "CrossUp";
   if(crossDown) return "CrossDown";
   return near   ? "Near Cross" : "Far from Cross";
  }

string GetPeriodStr(const ENUM_TIMEFRAMES period)
  {
   switch(period)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return EnumToString(period);
     }
  }

//+------------------------------------------------------------------+
//| Color helpers                                                    |
//+------------------------------------------------------------------+
color GetRsiColor(const double value)
  {
   if(value >= RsiUpperLevel) return clrLime;
   if(value <= RsiLowerLevel) return clrOrange;
   return TextColor;
  }

color GetStochColor(const double value)
  {
   if(value >= StochUpperLevel) return clrLime;
   if(value <= StochLowerLevel) return clrOrange;
   return TextColor;
  }

color GetAdxColor(const double adx)
  {
   if(adx <= 25) return TextColor;
   if(adx <= 50) return clrLime;
   if(adx <= 75) return clrYellow;
   return clrOrange;
  }

color GetPivotColor(const int pivotIdx)
  {
   if(pivotIdx == 0) return TextColor;
   if(pivotIdx <= 3) return clrLime;
   return clrOrange;
  }

color GetMAColor(const double ma, const double price)
  {
   return (price <= ma) ? clrRed : clrLime;
  }

color GetMACrossColor(const bool crossUp, const bool crossDown, const bool near)
  {
   if(crossUp)   return clrLime;
   if(crossDown) return clrRed;
   return near   ? TextColor : clrGray;
  }

color GetPercentColor(const double value)
  {
   if(value <= 25)  return TextColor;
   if(value <= 50)  return clrLime;
   if(value <= 75)  return clrYellow;
   if(value <= 100) return clrOrange;
   return clrRed;
  }
