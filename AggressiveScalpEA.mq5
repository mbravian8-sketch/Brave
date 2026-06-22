//+------------------------------------------------------------------+
//|                         Aggressive Scalp EA                       |
//|                    Dual Timeframe Scalping Robot                  |
//|                        M1 + M5 Trading                            |
//+------------------------------------------------------------------+

#property copyright "Copyright 2026"
#property link      "https://github.com/mbravian8-sketch/Brave"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

// Input parameters
input double RiskPercent = 3.0;              // Risk percentage per trade (3-5%)
input double ATRMultiplier = 1.2;            // ATR multiplier for pending order distance
input double TrailATRMultiplier = 0.75;      // ATR multiplier for trailing stop
input int MinProfitPips = 20;                // Minimum profit in pips to activate trail
input int ATRPeriod = 14;                    // ATR period
input bool UseM1 = true;                     // Use M1 timeframe
input bool UseM5 = true;                     // Use M5 timeframe
input int MagicNumber = 123456;              // Magic number for identification

// Global variables
CTrade trade;
CPositionInfo posInfo;
COrderInfo ordInfo;
double atrValue;
int buyPendingTicket = 0;
int sellPendingTicket = 0;
datetime lastTradeTime = 0;
bool buyPositionOpen = false;
bool sellPositionOpen = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    
    Print("AggressiveScalpEA initialized");
    Print("Risk: ", RiskPercent, "% | ATR Distance: ", ATRMultiplier, " | Trailing ATR: ", TrailATRMultiplier);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("AggressiveScalpEA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update ATR value
    atrValue = GetATR(PERIOD_M5);
    
    // Check for open positions and apply trailing stop
    ManageOpenPositions();
    
    // Update pending order status
    UpdatePendingOrders();
    
    // Check if we need to place new pending orders
    if (!buyPositionOpen && !sellPositionOpen && buyPendingTicket == 0 && sellPendingTicket == 0)
    {
        PlacePendingOrders();
    }
}

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double GetATR(ENUM_TIMEFRAMES timeframe)
{
    int handle = iATR(_Symbol, timeframe, ATRPeriod);
    if (handle < 0)
    {
        Print("Failed to create ATR handle");
        return 0;
    }
    
    double atr[];
    ArraySetAsSeries(atr, true);
    
    if (CopyBuffer(handle, 0, 0, 1, atr) <= 0)
    {
        Print("Failed to copy ATR data");
        IndicatorRelease(handle);
        return 0;
    }
    
    IndicatorRelease(handle);
    return atr[0];
}

//+------------------------------------------------------------------+
//| Place initial pending orders (BUY STOP + SELL STOP)             |
//+------------------------------------------------------------------+
void PlacePendingOrders()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    double distance = atrValue * ATRMultiplier;
    
    // Calculate lot size based on risk
    double lotSize = CalculateLotSize(distance);
    
    if (lotSize < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        lotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    // BUY STOP above current price
    double buyStopPrice = ask + distance;
    double buySL = buyStopPrice - (distance * 1.5);
    double buyTP = 0;
    
    // SELL STOP below current price
    double sellStopPrice = bid - distance;
    double sellSL = sellStopPrice + (distance * 1.5);
    double sellTP = 0;
    
    // Place BUY STOP
    if (!trade.BuyStop(lotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "BUY STOP"))
    {
        Print("Failed to place BUY STOP: ", trade.ResultRetcode());
    }
    else
    {
        buyPendingTicket = trade.ResultOrder();
        Print("BUY STOP placed at ", buyStopPrice, " | Lot: ", lotSize, " | SL: ", buySL);
    }
    
    // Place SELL STOP
    if (!trade.SellStop(lotSize, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "SELL STOP"))
    {
        Print("Failed to place SELL STOP: ", trade.ResultRetcode());
    }
    else
    {
        sellPendingTicket = trade.ResultOrder();
        Print("SELL STOP placed at ", sellStopPrice, " | Lot: ", lotSize, " | SL: ", sellSL);
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopDistance)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercent / 100.0);
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if (tickValue == 0 || point == 0)
        return 0.01;
    
    // Calculate pips
    double stopPips = stopDistance / point;
    
    // Lot size = Risk Amount / (Stop Distance in Pips * Tick Value per Lot)
    double lotSize = riskAmount / (stopPips * tickValue);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Normalize lot size
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    if (lotSize < minLot)
        lotSize = minLot;
    if (lotSize > maxLot)
        lotSize = maxLot;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Manage open positions (trailing stop logic)                      |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (posInfo.SelectByIndex(i))
        {
            if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol)
                continue;
            
            double currentPrice = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            double profit = posInfo.Profit();
            double profitPips = (currentPrice - posInfo.PriceOpen()) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            if (posInfo.PositionType() == POSITION_TYPE_SELL)
                profitPips = (posInfo.PriceOpen() - currentPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            // If profit reaches minimum, close opposite pending order and apply trailing stop
            if (profitPips >= MinProfitPips)
            {
                // Close opposite pending order
                if (posInfo.PositionType() == POSITION_TYPE_BUY && sellPendingTicket != 0)
                {
                    trade.OrderDelete(sellPendingTicket);
                    Print("SELL pending order closed (BUY position in profit)");
                    sellPendingTicket = 0;
                }
                else if (posInfo.PositionType() == POSITION_TYPE_SELL && buyPendingTicket != 0)
                {
                    trade.OrderDelete(buyPendingTicket);
                    Print("BUY pending order closed (SELL position in profit)");
                    buyPendingTicket = 0;
                }
                
                // Apply trailing stop
                ApplyTrailingStop(posInfo.Ticket(), posInfo.PositionType(), posInfo.StopLoss());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop to position                                  |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket, ENUM_POSITION_TYPE posType, double currentSL)
{
    if (!posInfo.SelectByTicket(ticket))
        return;
    
    double trailDistance = atrValue * TrailATRMultiplier;
    double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double newSL = 0;
    
    if (posType == POSITION_TYPE_BUY)
    {
        newSL = currentPrice - trailDistance;
        if (newSL > currentSL)
        {
            trade.PositionModify(ticket, newSL, posInfo.TakeProfit());
            Print("BUY trailing stop updated to: ", newSL);
        }
    }
    else if (posType == POSITION_TYPE_SELL)
    {
        newSL = currentPrice + trailDistance;
        if (newSL < currentSL || currentSL == 0)
        {
            trade.PositionModify(ticket, newSL, posInfo.TakeProfit());
            Print("SELL trailing stop updated to: ", newSL);
        }
    }
}

//+------------------------------------------------------------------+
//| Update pending order status                                      |
//+------------------------------------------------------------------+
void UpdatePendingOrders()
{
    // Check BUY STOP
    if (buyPendingTicket != 0)
    {
        if (!ordInfo.SelectByTicket(buyPendingTicket))
            buyPendingTicket = 0;
    }
    
    // Check SELL STOP
    if (sellPendingTicket != 0)
    {
        if (!ordInfo.SelectByTicket(sellPendingTicket))
            sellPendingTicket = 0;
    }
    
    // Check for open positions
    buyPositionOpen = false;
    sellPositionOpen = false;
    
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (posInfo.SelectByIndex(i))
        {
            if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol)
                continue;
            
            if (posInfo.PositionType() == POSITION_TYPE_BUY)
                buyPositionOpen = true;
            else if (posInfo.PositionType() == POSITION_TYPE_SELL)
                sellPositionOpen = true;
        }
    }
}

//+------------------------------------------------------------------+