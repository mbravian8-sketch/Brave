//+------------------------------------------------------------------+
//|                         Aggressive Scalp EA                       |
//|                    Dual Timeframe Scalping Robot                  |
//|                        M1 + M5 Trading                            |
//|                        M1 + M5 Trading                            |
//|              Multiple Pending Orders - ULTRA AGGRESSIVE            |
//+------------------------------------------------------------------+

#property copyright "Copyright 2026"
#property link      "https://github.com/mbravian8-sketch/Brave"
#property version   "2.1"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

// Input parameters - ADJUSTABLE
input int NumberOfStops = 5;                 // Number of BUY and SELL stops (5-7 recommended)
input double RiskPercent = 5.0;              // Risk percentage per trade (5-10% for aggressive)
input double ATRMultiplier = 0.5;            // ATR multiplier for pending order distance (reduced for aggressive)
input double TrailATRMultiplier = 0.3;       // ATR multiplier for trailing stop (reduced for aggressive)
input int BreakevenBuffer = 1;               // Pips buffer for breakeven (0 = exact breakeven)
input int ATRPeriod = 14;                    // ATR period
input double StopSpacing = 0.5;              // Spacing between stops (in ATR multiplier)
input int MagicNumber = 123456;              // Magic number for identification

// Global variables
CTrade trade;
CPositionInfo posInfo;
COrderInfo ordInfo;
double atrValue;
ulong buyPendingTickets[];
ulong sellPendingTickets[];
bool stopAlreadyLocked[];
int lastOrderCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    
    // Initialize arrays for pending orders
    ArrayResize(buyPendingTickets, NumberOfStops);
    ArrayResize(sellPendingTickets, NumberOfStops);
    ArrayResize(stopAlreadyLocked, 1000);
    ArrayInitialize(buyPendingTickets, 0);
    ArrayInitialize(sellPendingTickets, 0);
    ArrayInitialize(stopAlreadyLocked, false);
    
    Print("========================================");
    Print("AggressiveScalpEA v2.1 - ULTRA AGGRESSIVE");
    Print("========================================");
    Print("Number of Stops: ", NumberOfStops);
    Print("Risk: ", RiskPercent, "%");
    Print("ATR Distance Multiplier: ", ATRMultiplier);
    Print("Trail ATR Multiplier: ", TrailATRMultiplier);
    Print("Breakeven Buffer: ", BreakevenBuffer, " pips");
    Print("Stop Spacing: ", StopSpacing, " × ATR");
    Print("========================================");
    Print("STRATEGY: Lock profits immediately at breakeven!");
    Print("========================================");
    
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
    
    // Check for open positions and lock in profits IMMEDIATELY
    ManageOpenPositions();
    
    // Update pending order status
    UpdatePendingOrders();
    
    // Check if NO positions and NO pending orders exist
    if (CountOpenPositions() == 0 && CountPendingOrders() == 0)
    {
        Print(">>> ALL TRADES CLOSED! Opening new set of stops...");
        PlaceMultiplePendingOrders();
    }
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                 |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int posCount = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (posInfo.SelectByIndex(i))
        {
            if (posInfo.Magic() == MagicNumber && posInfo.Symbol() == _Symbol)
            {
                posCount++;
            }
        }
    }
    return posCount;
}

//+------------------------------------------------------------------+
//| Count pending orders for this EA                                 |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
    int orderCount = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (ordInfo.SelectByIndex(i))
        {
            if (ordInfo.Magic() == MagicNumber && ordInfo.Symbol() == _Symbol)
            {
                orderCount++;
            }
        }
    }
    return orderCount;
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
//| Place multiple pending orders (BUY STOPS + SELL STOPS)          |
//+------------------------------------------------------------------+
void PlaceMultiplePendingOrders()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double baseDistance = atrValue * ATRMultiplier;
    double lotSize = CalculateLotSize(baseDistance);
    
    if (lotSize < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        lotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    Print(">>> Placing ", NumberOfStops, " BUY and ", NumberOfStops, " SELL stops...");
    
    // Place multiple BUY STOPs above current price
    for (int i = 0; i < NumberOfStops; i++)
    {
        double distance = baseDistance * (1 + (i * StopSpacing));
        double buyStopPrice = ask + distance;
        double buySL = buyStopPrice - (distance * 1.5);
        double buyTP = 0;
        
        if (!trade.BuyStop(lotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "BUY STOP #" + (string)(i+1)))
        {
            Print("Failed to place BUY STOP #", (i+1), ": ", trade.ResultRetcode());
        }
        else
        {
            buyPendingTickets[i] = trade.ResultOrder();
            Print("✓ BUY STOP #", (i+1), " placed at ", buyStopPrice, " | Lot: ", lotSize);
        }
    }
    
    // Place multiple SELL STOPs below current price
    for (int i = 0; i < NumberOfStops; i++)
    {
        double distance = baseDistance * (1 + (i * StopSpacing));
        double sellStopPrice = bid - distance;
        double sellSL = sellStopPrice + (distance * 1.5);
        double sellTP = 0;
        
        if (!trade.SellStop(lotSize, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "SELL STOP #" + (string)(i+1)))
        {
            Print("Failed to place SELL STOP #", (i+1), ": ", trade.ResultRetcode());
        }
        else
        {
            sellPendingTickets[i] = trade.ResultOrder();
            Print("✓ SELL STOP #", (i+1), " placed at ", sellStopPrice, " | Lot: ", lotSize);
        }
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
//| Manage open positions (LOCK IN PROFITS IMMEDIATELY)             |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (posInfo.SelectByIndex(i))
        {
            if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol)
                continue;
            
            ulong ticket = posInfo.Ticket();
            double currentPrice = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            double profitPips = (currentPrice - posInfo.PriceOpen()) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            if (posInfo.PositionType() == POSITION_TYPE_SELL)
                profitPips = (posInfo.PriceOpen() - currentPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            // LOCK IN PROFITS IMMEDIATELY (even 0.01 pips)
            if (profitPips > 0 && !stopAlreadyLocked[ticket])
            {
                // Close ALL opposite pending orders
                if (posInfo.PositionType() == POSITION_TYPE_BUY)
                {
                    CloseAllSellPendingOrders();
                }
                else if (posInfo.PositionType() == POSITION_TYPE_SELL)
                {
                    CloseAllBuyPendingOrders();
                }
                
                // MOVE SL TO BREAKEVEN + BUFFER (LOCK IN PROFIT!)
                LockInProfit(ticket, posInfo.PositionType(), posInfo.PriceOpen());
                stopAlreadyLocked[ticket] = true;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Lock in profit by moving SL to breakeven + buffer               |
//+------------------------------------------------------------------+
void LockInProfit(ulong ticket, ENUM_POSITION_TYPE posType, double entryPrice)
{
    if (!posInfo.SelectByTicket(ticket))
        return;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double bufferPips = BreakevenBuffer * point;
    double newSL = 0;
    
    if (posType == POSITION_TYPE_BUY)
    {
        newSL = entryPrice + bufferPips;  // Breakeven + buffer above entry
        if (newSL > posInfo.StopLoss())
        {
            trade.PositionModify(ticket, newSL, posInfo.TakeProfit());
            Print("⭐ BUY LOCKED IN at ", newSL, " (Breakeven + ", BreakevenBuffer, " pips)");
        }
    }
    else if (posType == POSITION_TYPE_SELL)
    {
        newSL = entryPrice - bufferPips;  // Breakeven + buffer below entry
        if (newSL < posInfo.StopLoss() || posInfo.StopLoss() == 0)
        {
            trade.PositionModify(ticket, newSL, posInfo.TakeProfit());
            Print("⭐ SELL LOCKED IN at ", newSL, " (Breakeven + ", BreakevenBuffer, " pips)");
        }
    }
}

//+------------------------------------------------------------------+
//| Close all SELL pending orders                                    |
//+------------------------------------------------------------------+
void CloseAllSellPendingOrders()
{
    for (int i = 0; i < NumberOfStops; i++)
    {
        if (sellPendingTickets[i] != 0)
        {
            if (trade.OrderDelete(sellPendingTickets[i]))
            {
                Print("✗ SELL pending order #", (i+1), " DELETED");
                sellPendingTickets[i] = 0;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Close all BUY pending orders                                     |
//+------------------------------------------------------------------+
void CloseAllBuyPendingOrders()
{
    for (int i = 0; i < NumberOfStops; i++)
    {
        if (buyPendingTickets[i] != 0)
        {
            if (trade.OrderDelete(buyPendingTickets[i]))
            {
                Print("✗ BUY pending order #", (i+1), " DELETED");
                buyPendingTickets[i] = 0;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update pending order status                                      |
//+------------------------------------------------------------------+
void UpdatePendingOrders()
{
    // Clear old tickets
    for (int i = 0; i < NumberOfStops; i++)
    {
        buyPendingTickets[i] = 0;
        sellPendingTickets[i] = 0;
    }
    
    // Query pending orders and update tickets
    int buyCount = 0;
    int sellCount = 0;
    
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (ordInfo.SelectByIndex(i))
        {
            if (ordInfo.Magic() == MagicNumber && ordInfo.Symbol() == _Symbol)
            {
                if (ordInfo.OrderType() == ORDER_TYPE_BUY_STOP && buyCount < NumberOfStops)
                {
                    buyPendingTickets[buyCount] = ordInfo.Ticket();
                    buyCount++;
                }
                else if (ordInfo.OrderType() == ORDER_TYPE_SELL_STOP && sellCount < NumberOfStops)
                {
                    sellPendingTickets[sellCount] = ordInfo.Ticket();
                    sellCount++;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
