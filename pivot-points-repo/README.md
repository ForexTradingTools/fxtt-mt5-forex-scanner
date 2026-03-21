# FxTT MT5 Pivot Points – Free Multi-Timeframe Indicator

![MQL5](https://img.shields.io/badge/MQL5-Indicator-blue?style=flat-square)
![MT5](https://img.shields.io/badge/Platform-MetaTrader%205-informational?style=flat-square)
![Version](https://img.shields.io/badge/Version-1.00-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Free](https://img.shields.io/badge/Price-Free-brightgreen?style=flat-square)

> A free, open-source MT5 pivot points indicator that plots Classic, Camarilla, Woodie, and Fibonacci pivot levels across multiple timeframes — directly on your chart, with customizable colors, line styles, and label display.

---

## 📌 Overview

The **FxTT MT5 Pivot Points** indicator calculates and draws pivot point levels for the current or any higher timeframe directly on your MetaTrader 5 chart. It supports four calculation methods — Classic, Camarilla, Woodie, and Fibonacci — so you can trade with the pivot style that matches your strategy.

Pivot points are one of the most widely used technical analysis tools by professional traders. They provide objective support and resistance levels derived purely from the previous period's price action (high, low, and close), making them a reliable reference for intraday and swing trading decisions.

**Product page & documentation:** [forextradingtools.eu/products/indicators/pivot-points-mt5-free](https://forextradingtools.eu/products/indicators/pivot-points-mt5-free/)

---

## ✨ Features

- **Four pivot methods** — Classic, Camarilla, Woodie, and Fibonacci
- **Multi-timeframe support** — calculate pivots from D1, W1, or MN1 on any chart timeframe
- **Full S/R levels** — Pivot (PP), Resistance levels (R1–R4), Support levels (S1–S4)
- **Customizable line styles** — solid, dashed, or dotted lines for each level group
- **Customizable colors** — set individual colors for PP, resistance, and support levels
- **Price labels** — optional labels showing the exact price for each level
- **Level labels** — show or hide the level name (PP, R1, S1, etc.) on each line
- **Extend lines** — pivot lines extend across the full chart for easy reference
- **Historical levels** — optionally display pivot levels for previous periods
- **Lightweight** — minimal CPU and memory footprint, suitable for VPS use

---

## 📊 Pivot Levels

| Level | Description |
|-------|-------------|
| **PP** | Pivot Point — the primary reference level |
| **R1** | First resistance level |
| **R2** | Second resistance level |
| **R3** | Third resistance level |
| **R4** | Fourth resistance level (Camarilla / Fibonacci only) |
| **S1** | First support level |
| **S2** | Second support level |
| **S3** | Third support level |
| **S4** | Fourth support level (Camarilla / Fibonacci only) |

---

## 🧮 Calculation Methods

### Classic (Standard)
The most widely used method, derived from the previous period's high, low, and close:
- PP = (High + Low + Close) / 3
- R1 = 2 × PP − Low
- S1 = 2 × PP − High
- R2 = PP + (High − Low)
- S2 = PP − (High − Low)
- R3 = High + 2 × (PP − Low)
- S3 = Low − 2 × (High − PP)

### Camarilla
Uses a multiplier-based formula that places levels closer to price, useful for mean-reversion strategies:
- R1 = Close + (High − Low) × 1.1 / 12
- R2 = Close + (High − Low) × 1.1 / 6
- R3 = Close + (High − Low) × 1.1 / 4
- R4 = Close + (High − Low) × 1.1 / 2
- S1 = Close − (High − Low) × 1.1 / 12
- S2 = Close − (High − Low) × 1.1 / 6
- S3 = Close − (High − Low) × 1.1 / 4
- S4 = Close − (High − Low) × 1.1 / 2

### Woodie
Gives extra weight to the closing price:
- PP = (High + Low + 2 × Close) / 4
- R1 = 2 × PP − Low
- S1 = 2 × PP − High
- R2 = PP + (High − Low)
- S2 = PP − (High − Low)

### Fibonacci
Uses Classic PP with Fibonacci retracement levels applied to the range:
- PP = (High + Low + Close) / 3
- R1 = PP + 0.382 × (High − Low)
- R2 = PP + 0.618 × (High − Low)
- R3 = PP + 1.000 × (High − Low)
- S1 = PP − 0.382 × (High − Low)
- S2 = PP − 0.618 × (High − Low)
- S3 = PP − 1.000 × (High − Low)

---

## 🖥️ Platform Requirements

- **Platform:** MetaTrader 5 (MT5)
- **File type:** `.ex5` (compiled) / `.mq5` (source)
- **Version:** 1.00 (March 2026)
- **Instruments:** Forex, gold, indices, crypto, and all MT5-supported symbols

---

## 🚀 Installation

1. Download `FXTT_Pivot_Points.ex5` from the [Releases](../../releases) page
   *(or compile `FXTT_Pivot_Points.mq5` yourself in the MetaEditor)*
2. Open MT5 → **File → Open Data Folder**
3. Navigate to `MQL5/Indicators/`
4. Copy `FXTT_Pivot_Points.ex5` into that folder
5. Restart MT5 (or right-click the Navigator panel → **Refresh**)
6. Find **FXTT_Pivot_Points** under **Navigator → Indicators**
7. Drag it onto any chart — pivot levels will appear immediately
8. Configure the method, timeframe, and display settings in the Inputs tab

---

## ⚙️ Settings Reference

### General

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Pivot Method` | Classic | Calculation method: Classic, Camarilla, Woodie, or Fibonacci |
| `Pivot Timeframe` | D1 | Source timeframe for OHLC data: D1, W1, or MN1 |
| `Number of Periods` | 1 | How many historical pivot periods to display |
| `Show Labels` | true | Show level name labels (PP, R1, S1, etc.) |
| `Show Prices` | true | Show price value labels on each level |

### Line Styles

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PP Line Style` | Solid | Line style for the pivot point level |
| `PP Line Width` | 2 | Line width for the pivot point level |
| `R/S Line Style` | Dashed | Line style for resistance and support levels |
| `R/S Line Width` | 1 | Line width for resistance and support levels |

### Colors

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PP Color` | Yellow | Color of the pivot point line |
| `Resistance Color` | Red | Color of resistance level lines (R1–R4) |
| `Support Color` | Aqua | Color of support level lines (S1–S4) |

---

## 💡 How to Use It

1. **Use PP as the key bias level** — if price is above PP, the session bias is bullish; below PP, bearish
2. **Trade bounces at S1/R1** — these are the most commonly respected levels for intraday reversals
3. **Treat S3/R3 as breakout targets** — when price breaks through R1/S1, it often runs to R2/S2 or further
4. **Combine with confluence** — use pivot levels together with RSI, MA Cross, or candlestick patterns for higher-probability setups
5. **Switch to Weekly pivots for swing trading** — select W1 timeframe for multi-day support/resistance levels
6. **Use Camarilla for mean reversion** — when price reaches R3/S3 on Camarilla, consider a fade setup back toward the close
7. **Use Fibonacci for breakout trading** — Fibonacci pivots give clear extension targets when price breaks out of the prior range

---

## 🗂️ Repository Structure

```
fxtt-mt5-pivot-points/
├── src/
│   └── FXTT_Pivot_Points.mq5        # Full MQL5 source code
├── releases/
│   └── FXTT_Pivot_Points.ex5        # Compiled MT5 binary (ready to install)
├── screenshots/
│   ├── pivot-points-chart.png        # Indicator on MT5 chart
│   └── pivot-points-settings.png     # Settings panel
└── README.md
```

---

## 📝 Changelog

### v1.00 — March 2026
- Initial release
- Classic, Camarilla, Woodie, and Fibonacci pivot methods
- Daily, Weekly, and Monthly timeframe support
- Customizable colors, line styles, and label display
- Multi-period history display

---

## 🤝 Contributing

Contributions are welcome. If you find a bug or want to propose an improvement:

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/my-improvement`)
3. Commit your changes (`git commit -m 'Add my improvement'`)
4. Push to the branch (`git push origin feature/my-improvement`)
5. Open a Pull Request

For significant changes, please open an issue first to discuss what you'd like to change.

---

## ❓ FAQ

**Is this indicator free?**
Yes, completely free to download and use.

**Which pivot method should I use?**
Classic pivots work well for most trading styles. Camarilla is preferred for mean-reversion day trading. Fibonacci pivots are useful if you already use Fibonacci retracements in your analysis.

**Can I use it on any timeframe?**
Yes. Apply it to any chart — the indicator reads OHLC data from the selected pivot timeframe (D1, W1, or MN1) regardless of your chart's timeframe.

**Does it repaint?**
No. Pivot levels are calculated from the previous period's completed bar and remain fixed for the entire current period.

**Can I use it alongside Expert Advisors?**
Yes. The indicator is display-only and does not send orders or interfere with EAs.

**Is there a version for the MT5 Forex Scanner?**
Yes — the [FxTT MT5 Forex Scanner](https://forextradingtools.eu/products/indicators/mt5-forex-scanner-free/) includes a Pivots column showing the current pivot level and pip distance for every scanned pair.

---

## 📄 License

This project is licensed under the **MIT License** — you are free to use, modify, and distribute this code, provided the original copyright notice is retained.

See [LICENSE](./LICENSE) for details.

---

## 🔗 More Free Tools

All free indicators and EAs from Forex Trading Tools:

- 🔗 [FxTT MT5 Forex Scanner – Free MT5 Indicator](https://forextradingtools.eu/products/indicators/mt5-forex-scanner-free/)
- 🔗 [FxTT Multi-purpose Forex Scanner – Free MT4 Indicator](https://forextradingtools.eu/products/indicators/forex-scanner-free/)
- 🔗 [Strategy Checklist – Free MT4 Indicator](https://forextradingtools.eu/products/indicators/strategy-checklist-free-indicator/)
- 🔗 [MTF Triple Moving Averages – Free MT4 Indicator](https://forextradingtools.eu/products/indicators/mtf-triple-moving-averages-free-indicator/)
- 🔗 [MTF Bollinger Bands – Free MT4 Indicator](https://forextradingtools.eu/products/indicators/mtf-bollinger-bands-indicator/)
- 🔗 [MTF Bollinger Bands MT5 – Free MT5 Indicator](https://forextradingtools.eu/products/indicators/mtf-bollinger-bands-mt5-indicator/)

---

*Made with ❤️ by [Carlos Oliveira](https://forextradingtools.eu) | Forex Trading Tools*
