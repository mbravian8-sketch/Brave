# Aggressive Scalp EA

**An aggressive, dual-timeframe MT5 Expert Advisor for scalping with dynamic lot sizing and trailing stops.**

## Features

✅ **M1 + M5 Dual Timeframe Trading** - Catches more trading opportunities across multiple timeframes

✅ **Always Active Trading** - Maintains BUY STOP + SELL STOP pending orders 24/5 for continuous market exposure

✅ **Smart Pending Order Management** - Automatically closes opposite pending order when one position hits 20 pips profit

✅ **Trailing Stop System** - Dynamically follows price into profit to lock in gains

✅ **Dynamic Lot Sizing** - Risk-based position sizing (3-5% per trade) that grows with account balance

✅ **Automatic Re-entry** - New pending orders placed immediately after a trade closes

✅ **ATR-Based Logic** - All distances calculated using Average True Range for market-adaptive behavior

## Strategy Overview

### How It Works

1. **Initial Setup**
   - Places BUY STOP above current price
   - Places SELL STOP below current price
   - Both orders use ATR × 1.2 as distance (breakout method)

2. **Trade Entry**
   - One pending order triggers when price reaches it
   - Position opens with dynamic lot size based on risk

3. **Profit Management**
   - When trade hits 20 pips profit:
     - Opposite pending order is CLOSED
     - Trailing stop is ACTIVATED
     - Trailing distance = ATR × 0.75

4. **Trade Exit**
   - Position closes when price reverses against trailing stop
   - New pending orders are immediately placed
   - Cycle repeats continuously

## Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RiskPercent` | 3.0 | Risk per trade as % of account (3-5% recommended) |
| `ATRMultiplier` | 1.2 | Distance for pending orders from current price |
| `TrailATRMultiplier` | 0.75 | Trailing stop distance from current price |
| `MinProfitPips` | 20 | Pips profit needed to activate trailing stop |
| `ATRPeriod` | 14 | Period for ATR calculation |
| `UseM1` | true | Enable M1 timeframe signals |
| `UseM5` | true | Enable M5 timeframe signals |
| `MagicNumber` | 123456 | Unique EA identifier |

## Installation

1. Download `AggressiveScalpEA.mq5`
2. Copy to `C:\Program Files\MetaTrader 5\MQL5\Experts\`
3. Restart MetaTrader 5
4. Drag EA onto desired chart
5. Configure input parameters
6. Click "Allow Live Trading" and OK

## Recommended Settings

- **Timeframe**: M5 or M1 chart
- **Currency Pairs**: EURUSD, GBPUSD, USDJPY (highly liquid)
- **Account Risk**: 3-5% per trade
- **Spread**: <2 pips recommended
- **Trading Hours**: 8:00-17:00 GMT (London/NY overlap)

## Risk Disclaimer

⚠️ **AGGRESSIVE STRATEGY** - This EA is designed for aggressive trading and can result in significant losses. Always:

- Test on a Demo account first
- Use proper risk management
- Start with small account sizes
- Monitor the EA regularly
- Never risk money you can't afford to lose

## Performance Expectations

- **Win Rate**: 45-55% (breakout strategies)
- **Average Win**: 1.5-2.5 ATR
- **Average Loss**: 1.5 × ATR (fixed stop)
- **Profit Factor**: 1.5-2.0 (depending on market conditions)

## Support

For issues, questions, or improvements, please create an issue or pull request.

---

**Disclaimer**: Past performance is not indicative of future results. Trade at your own risk.