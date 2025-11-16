//+------------------------------------------------------------------+
//|                                          OverNightCloseEA.mqh    |
//|                              Copyright 2025, OverNightClose EA  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, OverNightCloseEA"
#property strict

//+------------------------------------------------------------------+
//| MQL4/MQL5 互換性マクロ定義                                      |
//+------------------------------------------------------------------+
#ifdef __MQL5__
   #include <Trade\Trade.mqh>
   CTrade g_trade;

   #define MODE_TRADES 0
   #define SELECT_BY_POS 0
   #define MODE_HISTORY 1
   #define SELECT_BY_TICKET 1
   #define MODE_BID 1
   #define MODE_ASK 2
   #define OP_BUY 0
   #define OP_SELL 1
   #define OP_BUYLIMIT 2
   #define OP_SELLLIMIT 3
   #define OP_BUYSTOP 4
   #define OP_SELLSTOP 5
#endif

// ライブラリをインクルード
#include "AutoTradingControl.mqh"
#include "JapanTimeCalculator.mqh"
#include "TimeRangeParser.mqh"
#include "BrokerFillingMode.mqh"

//+------------------------------------------------------------------+
//| 曜日の列挙型                                                     |
//+------------------------------------------------------------------+
enum ENUM_WEEKDAY
{
   WEEKDAY_SUNDAY = 0,    // 日曜日
   WEEKDAY_MONDAY = 1,    // 月曜日
   WEEKDAY_TUESDAY = 2,   // 火曜日
   WEEKDAY_WEDNESDAY = 3, // 水曜日
   WEEKDAY_THURSDAY = 4,  // 木曜日
   WEEKDAY_FRIDAY = 5,    // 金曜日
   WEEKDAY_SATURDAY = 6   // 土曜日
};

//+------------------------------------------------------------------+
//| 決済アクション                                                   |
//+------------------------------------------------------------------+
enum ENUM_CLOSE_ACTION
{
   ACTION_CLOSE_ONLY,           // 決済のみ
   ACTION_CLOSE_AND_STOP_EA,    // 決済＋EA停止
   ACTION_CLOSE_AND_DISABLE_AT  // 決済＋自動売買停止
};

//+------------------------------------------------------------------+
//| Input Parameters                                                |
//+------------------------------------------------------------------+
sinput string separator1 = "=== 曜日別決済時間帯設定(日本時間) ===";  // 曜日別決済時間帯設定
input string Monday_CloseTime = "0000-0000";             // 月曜日 決済時間帯(HHMM-HHMM)
input string Tuesday_CloseTime = "0000-0000";            // 火曜日 決済時間帯(HHMM-HHMM)
input string Wednesday_CloseTime = "0000-0000";          // 水曜日 決済時間帯(HHMM-HHMM)
input string Thursday_CloseTime = "0000-0000";           // 木曜日 決済時間帯(HHMM-HHMM)
input string Friday_CloseTime = "2300-2359";             // 金曜日 決済時間帯(HHMM-HHMM)
input string Saturday_CloseTime = "0000-0000";           // 土曜日 決済時間帯(HHMM-HHMM)
input string Sunday_CloseTime = "0000-0000";             // 日曜日 決済時間帯(HHMM-HHMM)

sinput string separator_tz = "=== タイムゾーン設定 ===";  // タイムゾーン設定
input ENUM_TIMEZONE_MODE TimezoneMode = TZ_JST;          // タイムゾーンモード
input int SummerOffset = 6;                               // 夏時間オフセット(時間) GMT+2の場合6
input int WinterOffset = 7;                               // 冬時間オフセット(時間) GMT+2の場合7
input int FixedOffset = 9;                                // 固定オフセット(時間) GMT+0の場合9

sinput string separator2 = "=== 決済対象設定 ===";       // 決済対象設定
input bool ClosePositions = true;                        // ポジションを決済
input bool ClosePendingOrders = true;                    // 待機注文を削除
input int MagicNumber = 0;                               // マジックナンバー(0=全て)

sinput string separator3 = "=== アクション設定 ===";      // アクション設定
input ENUM_CLOSE_ACTION CloseAction = ACTION_CLOSE_AND_DISABLE_AT; // 決済後のアクション

sinput string separator4 = "=== 通知設定 ===";           // 通知設定
input bool EnableAlert = true;                           // アラート通知
input bool EnableSound = true;                           // サウンド通知
input string SoundFile = "alert.wav";                    // 通知サウンドファイル
input int AlertMinutesBefore = 5;                        // 事前通知(分前)

sinput string separator5 = "=== 決済設定 ===";           // 決済設定
input int MaxRetries = 3;                                // 決済リトライ回数
input int RetryDelay = 1000;                             // リトライ間隔(ミリ秒)
input int Slippage = 3;                                  // スリッページ(pips)

sinput string separator6 = "=== 表示設定 ===";           // 表示設定
input int DisplayX = 10;                                 // 表示位置X座標
input int DisplayY = 25;                                 // 表示位置Y座標
input int FontSize = 12;                                 // フォントサイズ
input string FontName = "MS Gothic";                     // フォント名

//+------------------------------------------------------------------+
//| グローバル変数                                                  |
//+------------------------------------------------------------------+
bool g_closedToday[7];                                   // 曜日ごとの決済済みフラグ[0-6]
datetime g_lastCloseTime = 0;                            // 最後に決済した時刻
bool g_alertSent[7];                                     // 曜日ごとの事前アラート送信済みフラグ
int g_lastCheckDay = -1;                                 // 最後にチェックした日
string g_prefix = "WCEA_";                               // オブジェクト名プレフィックス
bool g_eaStopped = false;                                // EA停止フラグ

// 検証済み入力パラメータ
int g_maxRetries = 3;
int g_retryDelay = 1000;

// 日本時間計算機
CJapanTimeCalculator g_timeCalc;

// 曜日ごとの時間帯設定
STimeRange g_timeRanges[7];                              // 0=日曜, 1=月曜, ..., 6=土曜

//+------------------------------------------------------------------+
//| アカウント情報関数ラッパー                                      |
//+------------------------------------------------------------------+
int WCEA_OrdersTotal()
{
#ifdef __MQL5__
   return PositionsTotal();
#else
   return OrdersTotal();
#endif
}

//+------------------------------------------------------------------+
//| MQL5用関数ラッパー                                              |
//+------------------------------------------------------------------+
#ifdef __MQL5__
bool WCEA_OrderSelect(int index, int select, int pool = MODE_TRADES)
{
   ResetLastError();
   if(pool == MODE_TRADES && select == SELECT_BY_POS)
   {
      return (PositionGetTicket(index) > 0);
   }
   else if(select == SELECT_BY_TICKET)
   {
      return PositionSelectByTicket(index);
   }
   return false;
}

bool WCEA_OrderSelect(ulong ticket, int select, int pool = MODE_TRADES)
{
   ResetLastError();
   if(select == SELECT_BY_TICKET)
   {
      return PositionSelectByTicket(ticket);
   }
   return false;
}

string WCEA_OrderSymbol()
{
   return PositionGetString(POSITION_SYMBOL);
}

int WCEA_OrderType()
{
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   return (type == POSITION_TYPE_BUY) ? OP_BUY : OP_SELL;
}

double WCEA_OrderLots()
{
   return PositionGetDouble(POSITION_VOLUME);
}

ulong WCEA_OrderTicket()
{
   return PositionGetInteger(POSITION_TICKET);
}

double WCEA_MarketInfo(string symbol, int mode)
{
   if(mode == MODE_BID)
      return SymbolInfoDouble(symbol, SYMBOL_BID);
   else if(mode == MODE_ASK)
      return SymbolInfoDouble(symbol, SYMBOL_ASK);
   return 0;
}

bool WCEA_OrderClose(ulong ticket, double lots, double price, int slippage)
{
   g_trade.SetDeviationInPoints(slippage);
   return g_trade.PositionClose(ticket);
}

bool WCEA_OrderDelete(ulong ticket)
{
   return g_trade.OrderDelete(ticket);
}

int WCEA_PendingOrdersTotal()
{
   return OrdersTotal();
}

bool WCEA_PendingOrderSelect(int index)
{
   ulong ticket = OrderGetTicket(index);
   return (ticket > 0);
}

ulong WCEA_PendingOrderTicket(int index)
{
   return OrderGetTicket(index);
}

string WCEA_PendingOrderSymbol()
{
   return OrderGetString(ORDER_SYMBOL);
}

int WCEA_PendingOrderType()
{
   return (int)OrderGetInteger(ORDER_TYPE);
}

long WCEA_PendingOrderMagic()
{
   return OrderGetInteger(ORDER_MAGIC);
}

#else // MQL4

bool WCEA_OrderSelect(int index, int select, int pool = MODE_TRADES)
{
   return OrderSelect(index, select, pool);
}

string WCEA_OrderSymbol()
{
   return OrderSymbol();
}

int WCEA_OrderType()
{
   return OrderType();
}

double WCEA_OrderLots()
{
   return OrderLots();
}

int WCEA_OrderTicket()
{
   return OrderTicket();
}

double WCEA_MarketInfo(string symbol, int mode)
{
   return MarketInfo(symbol, mode);
}

bool WCEA_OrderClose(int ticket, double lots, double price, int slippage)
{
   return OrderClose(ticket, lots, price, slippage, clrYellow);
}

bool WCEA_OrderDelete(int ticket)
{
   return OrderDelete(ticket);
}

int WCEA_PendingOrdersTotal()
{
   return OrdersTotal();
}

bool WCEA_PendingOrderSelect(int index)
{
   return OrderSelect(index, SELECT_BY_POS, MODE_TRADES);
}

int WCEA_PendingOrderTicket(int index)
{
   if(OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
      return OrderTicket();
   return -1;
}

string WCEA_PendingOrderSymbol()
{
   return OrderSymbol();
}

int WCEA_PendingOrderType()
{
   return OrderType();
}

int WCEA_PendingOrderMagic()
{
   return OrderMagicNumber();
}

#endif

//+------------------------------------------------------------------+
//| エラーコード説明関数                                            |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code)
{
   switch(error_code)
   {
      case 0:     return "No error";
      case 1:     return "No error, operation successful";
      case 2:     return "Common error";
      case 3:     return "Invalid trade parameters";
      case 4:     return "Trade server is busy";
      case 128:   return "Trade timeout";
      case 129:   return "Invalid price";
      case 130:   return "Invalid stops";
      case 131:   return "Invalid trade volume";
      case 132:   return "Market is closed";
      case 133:   return "Trade is disabled";
      case 134:   return "Not enough money";
      case 135:   return "Price changed";
      case 136:   return "Off quotes";
      case 137:   return "Broker is busy";
      case 138:   return "Requote";
      case 139:   return "Order is locked";
      case 146:   return "Trade context is busy";
      default:    return "Unknown error (" + IntegerToString(error_code) + ")";
   }
}

//+------------------------------------------------------------------+
//| 初期化処理                                                      |
//+------------------------------------------------------------------+
void WCEA_Init()
{
   // DLL機能の確認（自動売買停止機能を使う場合のみ）
   if(CloseAction == ACTION_CLOSE_AND_DISABLE_AT && !IsDLLAvailable())
   {
      Print("WARNING: DLL imports are not enabled. AutoTrading control will not work.");
      Print("WARNING: Changing action to CLOSE_AND_STOP_EA");
      Alert("OverNightCloseEA: DLL機能が無効です。\nアクションを「決済＋EA停止」に変更しました。");
   }

   if(!ClosePositions && !ClosePendingOrders)
   {
      Print("ERROR: Both ClosePositions and ClosePendingOrders are disabled.");
      Alert("OverNightCloseEA: ポジション決済と待機注文削除の両方が無効です。\n最低1つを有効にしてください。");
      ExpertRemove();
      return;
   }

   // リトライパラメータ検証
   g_maxRetries = (MaxRetries < 1) ? 3 : MaxRetries;
   g_retryDelay = (RetryDelay < 100) ? 100 : RetryDelay;

   // 日本時間計算機を設定
   g_timeCalc.Configure(TimezoneMode, SummerOffset, WinterOffset, FixedOffset);

   // フィリングモードを初期化
   InitFillingMode();

   // 曜日ごとの時間帯をパース
   g_timeRanges[0] = CTimeRangeParser::Parse(Sunday_CloseTime);       // 日曜
   g_timeRanges[1] = CTimeRangeParser::Parse(Monday_CloseTime);       // 月曜
   g_timeRanges[2] = CTimeRangeParser::Parse(Tuesday_CloseTime);      // 火曜
   g_timeRanges[3] = CTimeRangeParser::Parse(Wednesday_CloseTime);    // 水曜
   g_timeRanges[4] = CTimeRangeParser::Parse(Thursday_CloseTime);     // 木曜
   g_timeRanges[5] = CTimeRangeParser::Parse(Friday_CloseTime);       // 金曜
   g_timeRanges[6] = CTimeRangeParser::Parse(Saturday_CloseTime);     // 土曜

   // 少なくとも1つの曜日が有効か確認
   bool hasValidDay = false;
   for(int i = 0; i < 7; i++)
   {
      if(g_timeRanges[i].isValid &&
         !(g_timeRanges[i].startHour == 0 && g_timeRanges[i].startMinute == 0 &&
           g_timeRanges[i].endHour == 0 && g_timeRanges[i].endMinute == 0))
      {
         hasValidDay = true;
         break;
      }
   }

   if(!hasValidDay)
   {
      Print("ERROR: No valid close time ranges configured.");
      Alert("OverNightCloseEA: 有効な決済時間帯が設定されていません。\n最低1つの曜日に時間帯を設定してください。");
      ExpertRemove();
      return;
   }

   // フラグ初期化
   ArrayInitialize(g_closedToday, false);
   ArrayInitialize(g_alertSent, false);
   g_lastCloseTime = 0;
   g_lastCheckDay = -1;
   g_eaStopped = false;

#ifdef __MQL5__
   // CTrade設定
   g_trade.SetDeviationInPoints(Slippage);
   g_trade.SetAsyncMode(false);
   g_trade.SetTypeFilling(GetFillingMode());  // ブローカーに最適なフィリングモードを設定
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
#endif

   // 表示初期化
   CreateDisplay();
   UpdateDisplay();

   Print("===========================================");
   Print("OverNightCloseEA v2.0 initialized - 曜日別時間帯決済");
   Print("Timezone mode: ", g_timeCalc.GetTimeZoneName());
   if(TimezoneMode == TZ_JST)
      Print("DST offset: Summer=", SummerOffset, "h, Winter=", WinterOffset, "h, Current=", g_timeCalc.GetCurrentOffset(), "h");
   else if(TimezoneMode == TZ_JST_FIXED)
      Print("Fixed offset: ", FixedOffset, " hours");

   Print("--- 曜日別決済時間帯 ---");
   string weekdayNames[] = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
   for(int i = 0; i < 7; i++)
   {
      if(g_timeRanges[i].isValid &&
         !(g_timeRanges[i].startHour == 0 && g_timeRanges[i].startMinute == 0 &&
           g_timeRanges[i].endHour == 0 && g_timeRanges[i].endMinute == 0))
      {
         Print(weekdayNames[i], ": ", CTimeRangeParser::ToString(g_timeRanges[i]));
      }
   }

   Print("Close positions: ", ClosePositions ? "YES" : "NO");
   Print("Close pending orders: ", ClosePendingOrders ? "YES" : "NO");
   Print("Magic filter: ", MagicNumber == 0 ? "All" : IntegerToString(MagicNumber));
   Print("Action: ", GetActionName(CloseAction));
   Print("Alert before: ", AlertMinutesBefore, " minutes");
   Print("===========================================");
}

//+------------------------------------------------------------------+
//| 終了処理                                                        |
//+------------------------------------------------------------------+
void WCEA_Deinit()
{
   // オブジェクト削除
   ObjectDelete(0, g_prefix + "Background");
   ObjectDelete(0, g_prefix + "Title");
   ObjectDelete(0, g_prefix + "CloseDay");
   ObjectDelete(0, g_prefix + "CloseTime");
   ObjectDelete(0, g_prefix + "NextClose");
   ObjectDelete(0, g_prefix + "Positions");
   ObjectDelete(0, g_prefix + "PendingOrders");
   ObjectDelete(0, g_prefix + "LastClose");
   ObjectDelete(0, g_prefix + "Status");

   Print("OverNightCloseEA deinitialized");
}

//+------------------------------------------------------------------+
//| メイン処理                                                      |
//+------------------------------------------------------------------+
void WCEA_OnTick()
{
   // EA停止中は何もしない
   if(g_eaStopped)
   {
      UpdateDisplay();
      return;
   }

   // サーバー時刻を取得
   datetime serverTime = TimeCurrent();

   // 日本時間に変換
   datetime japanTime = g_timeCalc.GetJapanTime(serverTime);

   MqlDateTime dt;
   TimeToStruct(japanTime, dt);

   int dayOfWeek = dt.day_of_week;  // 0=日曜, 1=月曜, ..., 6=土曜

   // 日付が変わったら全曜日の決済済みフラグとアラートフラグをリセット
   if(g_lastCheckDay != dt.day)
   {
      ArrayInitialize(g_closedToday, false);
      ArrayInitialize(g_alertSent, false);
      g_lastCheckDay = dt.day;
      Print("New day detected. Flags reset. Today: ", GetWeekdayName((ENUM_WEEKDAY)dayOfWeek));
   }

   // 今日の時間帯設定が有効かチェック
   if(!g_timeRanges[dayOfWeek].isValid)
   {
      UpdateDisplay();
      return;
   }

   // 0000-0000 は無効
   if(g_timeRanges[dayOfWeek].startHour == 0 && g_timeRanges[dayOfWeek].startMinute == 0 &&
      g_timeRanges[dayOfWeek].endHour == 0 && g_timeRanges[dayOfWeek].endMinute == 0)
   {
      UpdateDisplay();
      return;
   }

   // 事前アラートチェック
   if(!g_alertSent[dayOfWeek] && !g_closedToday[dayOfWeek] && AlertMinutesBefore > 0)
   {
      if(IsTimeToAlert(dt.hour, dt.min, dayOfWeek))
      {
         SendPreAlert(dayOfWeek);
         g_alertSent[dayOfWeek] = true;
      }
   }

   // 決済時刻チェック
   if(!g_closedToday[dayOfWeek] && IsTimeToClose(dt.hour, dt.min, dayOfWeek))
   {
      ExecuteClose(dayOfWeek);
   }

   // 表示更新
   UpdateDisplay();
}

//+------------------------------------------------------------------+
//| 決済時刻判定                                                    |
//+------------------------------------------------------------------+
bool IsTimeToClose(int hour, int minute, int dayOfWeek)
{
   return CTimeRangeParser::IsInRange(g_timeRanges[dayOfWeek], hour, minute);
}

//+------------------------------------------------------------------+
//| 事前アラート時刻判定                                            |
//+------------------------------------------------------------------+
bool IsTimeToAlert(int hour, int minute, int dayOfWeek)
{
   if(AlertMinutesBefore <= 0)
      return false;

   // 開始時刻のN分前を計算
   int startMinutes = g_timeRanges[dayOfWeek].startHour * 60 + g_timeRanges[dayOfWeek].startMinute;
   int alertMinutes = startMinutes - AlertMinutesBefore;

   // 日跨ぎ対応
   if(alertMinutes < 0)
      alertMinutes += 1440;  // 24時間

   int currentMinutes = hour * 60 + minute;

   // アラート時刻の前後1分以内
   return (MathAbs(currentMinutes - alertMinutes) < 1);
}

//+------------------------------------------------------------------+
//| 事前アラート送信                                                |
//+------------------------------------------------------------------+
void SendPreAlert(int dayOfWeek)
{
   int posCount = GetFilteredPositionCount();
   int orderCount = GetFilteredPendingOrderCount();

   string weekdayNames[] = {"日曜", "月曜", "火曜", "水曜", "木曜", "金曜", "土曜"};
   string timeRange = CTimeRangeParser::ToString(g_timeRanges[dayOfWeek]);

   string message = "OverNightCloseEA: " + IntegerToString(AlertMinutesBefore) + "分後に決済開始!\n";
   message += weekdayNames[dayOfWeek] + " " + timeRange + "\n";
   message += "ポジション: " + IntegerToString(posCount) + "件\n";
   message += "待機注文: " + IntegerToString(orderCount) + "件";

   if(EnableAlert)
      Alert(message);

   if(EnableSound)
      PlaySound(SoundFile);

   Print("===========================================");
   Print("Pre-alert sent: ", AlertMinutesBefore, " minutes before close");
   Print("Day: ", weekdayNames[dayOfWeek], " Time range: ", timeRange);
   Print("Positions: ", posCount);
   Print("Pending orders: ", orderCount);
   Print("===========================================");
}

//+------------------------------------------------------------------+
//| 決済実行                                                        |
//+------------------------------------------------------------------+
void ExecuteClose(int dayOfWeek)
{
   string weekdayNames[] = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
   string timeRange = CTimeRangeParser::ToString(g_timeRanges[dayOfWeek]);

   Print("===========================================");
   Print("Executing time-range close at ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Day: ", weekdayNames[dayOfWeek], " Time range: ", timeRange);
   Print("===========================================");

   int closedPositions = 0;
   int deletedOrders = 0;

   // ポジション決済
   if(ClosePositions)
   {
      closedPositions = CloseAllPositions();
      Print("Closed positions: ", closedPositions);
   }

   // 待機注文削除
   if(ClosePendingOrders)
   {
      deletedOrders = DeleteAllPendingOrders();
      Print("Deleted pending orders: ", deletedOrders);
   }

   g_closedToday[dayOfWeek] = true;
   g_lastCloseTime = TimeCurrent();

   // アラート送信
   string message = "OverNightCloseEA: 決済完了!\n";
   message += weekdayNames[dayOfWeek] + " " + timeRange + "\n";
   message += "ポジション: " + IntegerToString(closedPositions) + "件決済\n";
   message += "待機注文: " + IntegerToString(deletedOrders) + "件削除";

   if(EnableAlert)
      Alert(message);

   if(EnableSound)
      PlaySound(SoundFile);

   Print("===========================================");
   Print("Time-range close completed");
   Print("Total closed: ", closedPositions, " positions, ", deletedOrders, " orders");
   Print("===========================================");

   // アクション実行
   ExecuteAction();
}

//+------------------------------------------------------------------+
//| アクション実行                                                  |
//+------------------------------------------------------------------+
void ExecuteAction()
{
   if(CloseAction == ACTION_CLOSE_AND_STOP_EA)
   {
      Print("Stopping EA...");
      g_eaStopped = true;
      ExpertRemove();
   }
   else if(CloseAction == ACTION_CLOSE_AND_DISABLE_AT)
   {
      if(IsDLLAvailable())
      {
         Print("Disabling AutoTrading...");
         DisableAutoTrading();
         g_eaStopped = true;
      }
      else
      {
         Print("WARNING: DLL not available. Stopping EA instead.");
         g_eaStopped = true;
         ExpertRemove();
      }
   }
   // ACTION_CLOSE_ONLY の場合は何もしない
}

//+------------------------------------------------------------------+
//| 全ポジション決済                                                |
//+------------------------------------------------------------------+
int CloseAllPositions()
{
   int totalClosed = 0;
   int consecutiveFailures = 0;
   int totalAttempts = 0;
   const int MAX_TOTAL_ATTEMPTS = g_maxRetries * 10;

   Print("Starting CloseAllPositions");
   Print("Magic filter: ", MagicNumber == 0 ? "None (all positions)" : IntegerToString(MagicNumber));

   while(consecutiveFailures < g_maxRetries && totalAttempts < MAX_TOTAL_ATTEMPTS)
   {
      totalAttempts++;

#ifdef __MQL5__
      ulong tickets[];
#else
      int tickets[];
#endif
      int ticketCount = 0;
      int total = WCEA_OrdersTotal();

      // チケット収集
      for(int i = 0; i < total; i++)
      {
         if(!WCEA_OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

         // マジックナンバーフィルター
         if(MagicNumber != 0)
         {
#ifdef __MQL5__
            long posMagic = PositionGetInteger(POSITION_MAGIC);
#else
            int posMagic = OrderMagicNumber();
#endif
            if(posMagic != MagicNumber)
               continue;
         }

         // ポジションタイプチェック
         int type = WCEA_OrderType();
         if(type != OP_BUY && type != OP_SELL)
            continue;

         ArrayResize(tickets, ticketCount + 1);
#ifdef __MQL5__
         tickets[ticketCount] = (ulong)WCEA_OrderTicket();
#else
         tickets[ticketCount] = (int)WCEA_OrderTicket();
#endif
         ticketCount++;
      }

      if(ticketCount == 0)
      {
         Print("All positions closed. Total: ", totalClosed);
         return totalClosed;
      }

      Print("Round ", totalAttempts, ": Found ", ticketCount, " positions");

      int closedThisRound = 0;

      // 決済実行
      for(int i = 0; i < ticketCount; i++)
      {
         if(!WCEA_OrderSelect(tickets[i], SELECT_BY_TICKET))
         {
            closedThisRound++;
            continue;
         }

         string symbol = WCEA_OrderSymbol();
         int type = WCEA_OrderType();
         double lots = WCEA_OrderLots();

         double closePrice = (type == OP_BUY) ?
                            WCEA_MarketInfo(symbol, MODE_BID) :
                            WCEA_MarketInfo(symbol, MODE_ASK);

         if(closePrice <= 0)
         {
            Print("ERROR: Invalid price for ", symbol);
            continue;
         }

#ifdef __MQL5__
         bool success = WCEA_OrderClose((ulong)tickets[i], lots, closePrice, Slippage);
#else
         bool success = WCEA_OrderClose(tickets[i], lots, closePrice, Slippage);
#endif

         if(success)
         {
            closedThisRound++;
            totalClosed++;
            Print("Closed #", tickets[i], " (", symbol, ")");
            Sleep(100);
         }
         else
         {
            int error = GetLastError();
            Print("Failed to close #", tickets[i], " Error: ", error, " - ", ErrorDescription(error));
         }
      }

      Print("Round ", totalAttempts, " result: ", closedThisRound, "/", ticketCount);

      if(closedThisRound > 0)
      {
         consecutiveFailures = 0;
         Sleep(g_retryDelay / 2);
      }
      else
      {
         consecutiveFailures++;
         if(consecutiveFailures < g_maxRetries)
            Sleep(g_retryDelay);
      }
   }

   int remaining = GetFilteredPositionCount();
   if(remaining > 0)
   {
      Print("WARNING: ", remaining, " positions remain");
      Alert("OverNightCloseEA: ", remaining, " ポジションの決済に失敗しました!");
   }

   return totalClosed;
}

//+------------------------------------------------------------------+
//| 全待機注文削除                                                  |
//+------------------------------------------------------------------+
int DeleteAllPendingOrders()
{
   int totalDeleted = 0;
   int consecutiveFailures = 0;
   int totalAttempts = 0;
   const int MAX_TOTAL_ATTEMPTS = g_maxRetries * 10;

   Print("Starting DeleteAllPendingOrders");
   Print("Magic filter: ", MagicNumber == 0 ? "None (all orders)" : IntegerToString(MagicNumber));

   while(consecutiveFailures < g_maxRetries && totalAttempts < MAX_TOTAL_ATTEMPTS)
   {
      totalAttempts++;

#ifdef __MQL5__
      ulong tickets[];
#else
      int tickets[];
#endif
      int ticketCount = 0;

#ifdef __MQL5__
      // MQL5: OrdersTotal()を使用
      int total = WCEA_PendingOrdersTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = WCEA_PendingOrderTicket(i);
         if(ticket == 0)
            continue;

         // マジックナンバーフィルター
         if(MagicNumber != 0)
         {
            long orderMagic = WCEA_PendingOrderMagic();
            if(orderMagic != MagicNumber)
               continue;
         }

         ArrayResize(tickets, ticketCount + 1);
         tickets[ticketCount] = ticket;
         ticketCount++;
      }
#else
      // MQL4: OrdersTotal()からペンディングオーダーのみ抽出
      int total = WCEA_PendingOrdersTotal();
      for(int i = 0; i < total; i++)
      {
         if(!WCEA_PendingOrderSelect(i))
            continue;

         int type = WCEA_PendingOrderType();
         // ペンディングオーダーのみ(BUY/SELL以外)
         if(type == OP_BUY || type == OP_SELL)
            continue;

         // マジックナンバーフィルター
         if(MagicNumber != 0)
         {
            int orderMagic = WCEA_PendingOrderMagic();
            if(orderMagic != MagicNumber)
               continue;
         }

         int ticket = WCEA_PendingOrderTicket(i);
         if(ticket < 0)
            continue;

         ArrayResize(tickets, ticketCount + 1);
         tickets[ticketCount] = ticket;
         ticketCount++;
      }
#endif

      if(ticketCount == 0)
      {
         Print("All pending orders deleted. Total: ", totalDeleted);
         return totalDeleted;
      }

      Print("Round ", totalAttempts, ": Found ", ticketCount, " pending orders");

      int deletedThisRound = 0;

      // 削除実行
      for(int i = 0; i < ticketCount; i++)
      {
         bool success = WCEA_OrderDelete(tickets[i]);

         if(success)
         {
            deletedThisRound++;
            totalDeleted++;
            Print("Deleted order #", tickets[i]);
            Sleep(100);
         }
         else
         {
            int error = GetLastError();
            Print("Failed to delete order #", tickets[i], " Error: ", error, " - ", ErrorDescription(error));
         }
      }

      Print("Round ", totalAttempts, " result: ", deletedThisRound, "/", ticketCount);

      if(deletedThisRound > 0)
      {
         consecutiveFailures = 0;
         Sleep(g_retryDelay / 2);
      }
      else
      {
         consecutiveFailures++;
         if(consecutiveFailures < g_maxRetries)
            Sleep(g_retryDelay);
      }
   }

   int remaining = GetFilteredPendingOrderCount();
   if(remaining > 0)
   {
      Print("WARNING: ", remaining, " pending orders remain");
      Alert("OverNightCloseEA: ", remaining, " 待機注文の削除に失敗しました!");
   }

   return totalDeleted;
}

//+------------------------------------------------------------------+
//| フィルター済みポジション数取得                                    |
//+------------------------------------------------------------------+
int GetFilteredPositionCount()
{
   int count = 0;
   for(int i = 0; i < WCEA_OrdersTotal(); i++)
   {
      if(!WCEA_OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      int type = WCEA_OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      if(MagicNumber != 0)
      {
#ifdef __MQL5__
         long posMagic = PositionGetInteger(POSITION_MAGIC);
#else
         int posMagic = OrderMagicNumber();
#endif
         if(posMagic != MagicNumber)
            continue;
      }

      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| フィルター済み待機注文数取得                                      |
//+------------------------------------------------------------------+
int GetFilteredPendingOrderCount()
{
#ifdef __MQL5__
   int count = 0;
   int total = WCEA_PendingOrdersTotal();
   for(int i = 0; i < total; i++)
   {
      if(!WCEA_PendingOrderSelect(i))
         continue;

      if(MagicNumber != 0)
      {
         long orderMagic = WCEA_PendingOrderMagic();
         if(orderMagic != MagicNumber)
            continue;
      }

      count++;
   }
   return count;
#else
   int count = 0;
   for(int i = 0; i < WCEA_PendingOrdersTotal(); i++)
   {
      if(!WCEA_PendingOrderSelect(i))
         continue;

      int type = WCEA_PendingOrderType();
      if(type == OP_BUY || type == OP_SELL)
         continue;

      if(MagicNumber != 0)
      {
         int orderMagic = WCEA_PendingOrderMagic();
         if(orderMagic != MagicNumber)
            continue;
      }

      count++;
   }
   return count;
#endif
}

//+------------------------------------------------------------------+
//| 次回決済時刻を計算(表示用・簡略版)                              |
//+------------------------------------------------------------------+
string GetNextCloseTimeString()
{
   datetime serverTime = TimeCurrent();
   datetime japanTime = g_timeCalc.GetJapanTime(serverTime);

   MqlDateTime dt;
   TimeToStruct(japanTime, dt);

   int currentDay = dt.day_of_week;

   // 今日から7日間検索
   for(int i = 0; i < 7; i++)
   {
      int checkDay = (currentDay + i) % 7;

      if(!g_timeRanges[checkDay].isValid)
         continue;

      if(g_timeRanges[checkDay].startHour == 0 && g_timeRanges[checkDay].startMinute == 0 &&
         g_timeRanges[checkDay].endHour == 0 && g_timeRanges[checkDay].endMinute == 0)
         continue;

      // 今日の場合、時刻をチェック
      if(i == 0)
      {
         int currentMinutes = dt.hour * 60 + dt.min;
         int startMinutes = g_timeRanges[checkDay].startHour * 60 + g_timeRanges[checkDay].startMinute;

         if(currentMinutes < startMinutes)
         {
            string weekdayNames[] = {"日曜", "月曜", "火曜", "水曜", "木曜", "金曜", "土曜"};
            return weekdayNames[checkDay] + " " + CTimeRangeParser::ToString(g_timeRanges[checkDay]);
         }
      }
      else
      {
         string weekdayNames[] = {"日曜", "月曜", "火曜", "水曜", "木曜", "金曜", "土曜"};
         return weekdayNames[checkDay] + " " + CTimeRangeParser::ToString(g_timeRanges[checkDay]);
      }
   }

   return "なし";
}

//+------------------------------------------------------------------+
//| 曜日名取得                                                      |
//+------------------------------------------------------------------+
string GetWeekdayName(ENUM_WEEKDAY day)
{
   switch(day)
   {
      case WEEKDAY_SUNDAY:    return "Sunday";
      case WEEKDAY_MONDAY:    return "Monday";
      case WEEKDAY_TUESDAY:   return "Tuesday";
      case WEEKDAY_WEDNESDAY: return "Wednesday";
      case WEEKDAY_THURSDAY:  return "Thursday";
      case WEEKDAY_FRIDAY:    return "Friday";
      case WEEKDAY_SATURDAY:  return "Saturday";
      default:                return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| アクション名取得                                                |
//+------------------------------------------------------------------+
string GetActionName(ENUM_CLOSE_ACTION action)
{
   switch(action)
   {
      case ACTION_CLOSE_ONLY:          return "Close only";
      case ACTION_CLOSE_AND_STOP_EA:   return "Close + Stop EA";
      case ACTION_CLOSE_AND_DISABLE_AT: return "Close + Disable AutoTrading";
      default:                         return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| 表示作成                                                        |
//+------------------------------------------------------------------+
void CreateDisplay()
{
   int panelWidth = 420;
   int panelHeight = 280;
   CreatePanel(g_prefix + "Background", DisplayX - 5, DisplayY - 5, panelWidth, panelHeight);

   int y = DisplayY;
   int lineHeight = 26;

   CreateLabel(g_prefix + "Title", "■ 週末自動決済EA", DisplayX, y, clrWhite, FontSize + 2, true);
   y += 35;

   CreateLabel(g_prefix + "CloseDay", "", DisplayX, y, clrGold, FontSize);
   y += lineHeight;

   CreateLabel(g_prefix + "CloseTime", "", DisplayX, y, clrGold, FontSize);
   y += lineHeight;

   CreateLabel(g_prefix + "NextClose", "", DisplayX, y, clrLime, FontSize + 1, true);
   y += lineHeight + 5;

   CreateLabel(g_prefix + "Positions", "", DisplayX, y, clrWhite, FontSize);
   y += lineHeight;

   CreateLabel(g_prefix + "PendingOrders", "", DisplayX, y, clrWhite, FontSize);
   y += lineHeight + 5;

   CreateLabel(g_prefix + "LastClose", "", DisplayX, y, clrSilver, FontSize);
   y += lineHeight;

   CreateLabel(g_prefix + "Status", "", DisplayX, y, clrLime, FontSize + 1);
}

//+------------------------------------------------------------------+
//| 表示更新                                                        |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   // 基本情報
   UpdateLabel(g_prefix + "CloseDay", "タイムゾーン: " + g_timeCalc.GetTimeZoneName(), clrWhiteSmoke);
   UpdateLabel(g_prefix + "CloseTime", "曜日別時間帯決済モード", clrWhiteSmoke);

   // 次回決済時刻
   string nextCloseText = "次回決済: " + GetNextCloseTimeString();
   UpdateLabel(g_prefix + "NextClose", nextCloseText, clrLime);

   // 現在の状況
   int posCount = GetFilteredPositionCount();
   int orderCount = GetFilteredPendingOrderCount();

   UpdateLabel(g_prefix + "Positions", "現在のポジション: " + IntegerToString(posCount) + "件", posCount > 0 ? clrWhite : clrGray);
   UpdateLabel(g_prefix + "PendingOrders", "待機注文: " + IntegerToString(orderCount) + "件", orderCount > 0 ? clrWhite : clrGray);

   // 最終決済時刻
   if(g_lastCloseTime > 0)
      UpdateLabel(g_prefix + "LastClose", "最終決済: " + TimeToString(g_lastCloseTime, TIME_DATE|TIME_MINUTES), clrSilver);
   else
      UpdateLabel(g_prefix + "LastClose", "最終決済: なし", clrGray);

   // ステータス
   if(g_eaStopped)
      UpdateLabel(g_prefix + "Status", "状態: 停止", clrRed);
   else
      UpdateLabel(g_prefix + "Status", "状態: 稼働中", clrLime);
}

//+------------------------------------------------------------------+
//| パネル作成                                                      |
//+------------------------------------------------------------------+
void CreatePanel(string name, int x, int y, int width, int height)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'25,25,35');
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, C'60,60,80');
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   }
}

//+------------------------------------------------------------------+
//| ラベル作成                                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int size, bool bold = false)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);

      string fontToUse = FontName;
      if(bold && (FontName == "Arial" || FontName == "Tahoma"))
         fontToUse = FontName + " Bold";

      ObjectSetString(0, name, OBJPROP_FONT, fontToUse);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| ラベル更新                                                      |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text, color clr)
{
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}

//+------------------------------------------------------------------+
