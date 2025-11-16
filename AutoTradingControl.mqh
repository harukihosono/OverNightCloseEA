//+------------------------------------------------------------------+
//|                                         AutoTradingControl.mqh   |
//|                                         MQL4/5自動売買制御       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.10"
#property strict

#ifdef __MQL4__
   // MT4用定義
   #define MT_WMCMD_EXPERTS  33020
#else
   // MT5用定義
   #define MT_WMCMD_EXPERTS  32851
#endif

// 定数定義
#define WM_COMMAND  0x0111
#define GA_ROOT     2

// DLLインポート
#import "user32.dll"
   int GetAncestor(int hWnd, int flags);
   #ifdef __MQL4__
      int PostMessageA(int hWnd, int Msg, int wParam, int lParam);
   #else
      int PostMessageW(int hWnd, int Msg, int wParam, int lParam);
   #endif
#import

//+------------------------------------------------------------------+
//| DLL機能が利用可能か確認                                          |
//+------------------------------------------------------------------+
bool IsDLLAvailable()
{
   #ifdef __MQL5__
      if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED))
      {
         Print("ERROR: DLL imports are not allowed in terminal settings");
         Print("ERROR: Enable DLL imports: Tools > Options > Expert Advisors > Allow DLL imports");
         return false;
      }
   #else
      if(!IsDllsAllowed())
      {
         Print("ERROR: DLL imports are not allowed in terminal settings");
         Print("ERROR: Enable DLL imports: Tools > Options > Expert Advisors > Allow DLL imports");
         return false;
      }
   #endif

   return true;
}

//+------------------------------------------------------------------+
//| 自動売買が現在有効か確認                                          |
//+------------------------------------------------------------------+
bool IsAutoTradingEnabled()
{
   #ifdef __MQL4__
      return (bool)IsTradeAllowed();
   #else
      return (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   #endif
}

//+------------------------------------------------------------------+
//| 自動売買の状態をON/OFF切り替え                                    |
//+------------------------------------------------------------------+
bool SetAutoTradingState(bool newStatus)
{
   // DLL利用可能性チェック
   if(!IsDLLAvailable())
   {
      return false;
   }

   // 現在の状態を確認
   bool currentStatus = IsAutoTradingEnabled();

   // 現在の状態と指定した状態が異なる場合のみ切り替え
   if(currentStatus != newStatus)
   {
      int result = 0;

      #ifdef __MQL4__
         // MT4の場合
         int hwnd = WindowHandle(Symbol(), Period());
         if(hwnd == 0)
         {
            Print("ERROR: Failed to get chart window handle");
            return false;
         }

         int main = GetAncestor(hwnd, GA_ROOT);
         if(main == 0)
         {
            Print("ERROR: Failed to get main window handle");
            return false;
         }

         result = PostMessageA(main, WM_COMMAND, MT_WMCMD_EXPERTS, 0);
      #else
         // MT5の場合
         int hwnd = (int)ChartGetInteger(0, CHART_WINDOW_HANDLE);
         if(hwnd == 0)
         {
            Print("ERROR: Failed to get chart window handle");
            return false;
         }

         int main = GetAncestor(hwnd, GA_ROOT);
         if(main == 0)
         {
            Print("ERROR: Failed to get main window handle");
            return false;
         }

         result = PostMessageW(main, WM_COMMAND, MT_WMCMD_EXPERTS, 0);
      #endif

      if(result == 0)
      {
         Print("ERROR: Failed to post message to MetaTrader window");
         Print("ERROR: AutoTrading state may not have changed");
         return false;
      }

      // 状態変更の確認（最大5秒待機）
      int maxWait = 25;  // 5秒 (200ms * 25回)
      for(int i = 0; i < maxWait; i++)
      {
         Sleep(200);
         if(IsAutoTradingEnabled() == newStatus)
         {
            Print("MetaTrader自動売買: ", newStatus ? "ON" : "OFF", " (confirmed)");
            return true;
         }
      }

      Print("WARNING: AutoTrading state change could not be verified within 5 seconds");
      Print("WARNING: Requested: ", newStatus ? "ON" : "OFF",
            ", Current: ", IsAutoTradingEnabled() ? "ON" : "OFF");
      return false;
   }

   return true;  // 既に目的の状態
}

//+------------------------------------------------------------------+
//| 自動売買をONにする                                                |
//+------------------------------------------------------------------+
bool EnableAutoTrading()
{
   return SetAutoTradingState(true);
}

//+------------------------------------------------------------------+
//| 自動売買をOFFにする                                               |
//+------------------------------------------------------------------+
bool DisableAutoTrading()
{
   return SetAutoTradingState(false);
}

//+------------------------------------------------------------------+
//| 自動売買のON/OFFをトグル切り替え                                  |
//+------------------------------------------------------------------+
bool ToggleAutoTrading()
{
   bool currentStatus = IsAutoTradingEnabled();
   return SetAutoTradingState(!currentStatus);
}

//+------------------------------------------------------------------+
