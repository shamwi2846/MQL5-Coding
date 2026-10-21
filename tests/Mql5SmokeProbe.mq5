//+------------------------------------------------------------------+
//| Mql5SmokeProbe.mq5                                                |
//| Nontrading test EA for the mql5-coding skill's real check: it     |
//| prints the marker it is given once, inside the test, and never    |
//| sends an order.                                                   |
//+------------------------------------------------------------------+
#property copyright "mql5-coding"
#property version   "1.00"

input string InpMarker = "";  // MQL5_CODING_PASS:<hex>, printed once when set

int OnInit()
  {
   if(InpMarker != "")
      Print(InpMarker);
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
  }
//+------------------------------------------------------------------+
