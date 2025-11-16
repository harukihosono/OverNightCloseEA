//+------------------------------------------------------------------+
//|                                          OverNightCloseEA.mq5    |
//|                              Copyright 2025, OverNightClose EA  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, OverNightCloseEA"
#property version   "2.0"
#property description "曜日別時間帯自動決済EA - MQL5版"
#property description "プロップファーム週末持ち越し防止用"
#property description "ポジション+待機注文を自動決済"

// 共通ヘッダーファイルをインクルード
#include "OverNightCloseEA.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   WCEA_Init();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   WCEA_Deinit();
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   WCEA_OnTick();
}

//+------------------------------------------------------------------+
