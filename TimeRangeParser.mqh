//+------------------------------------------------------------------+
//|                                            TimeRangeParser.mqh   |
//|                              時間帯パーサー "0500-0600" 形式    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

//+------------------------------------------------------------------+
//| 時間帯構造体                                                    |
//+------------------------------------------------------------------+
struct STimeRange
{
   int startHour;      // 開始時(0-23)
   int startMinute;    // 開始分(0-59)
   int endHour;        // 終了時(0-23)
   int endMinute;      // 終了分(0-59)
   bool isValid;       // 有効かどうか
};

//+------------------------------------------------------------------+
//| 時間帯パーサークラス                                            |
//+------------------------------------------------------------------+
class CTimeRangeParser
{
public:
   //+------------------------------------------------------------------+
   //| 時間帯文字列をパース "0500-0600" → (5,0,6,0)                   |
   //+------------------------------------------------------------------+
   static STimeRange Parse(string timeStr)
   {
      STimeRange range;
      range.isValid = false;

      // 空文字列チェック
      if(StringLen(timeStr) == 0)
         return range;

      // "-" で分割
      string parts[];
      int count = StringSplit(timeStr, '-', parts);

      if(count != 2)
      {
         Print("ERROR: Invalid time range format: ", timeStr, " (expected: HHMM-HHMM)");
         return range;
      }

      // 開始時刻をパース
      string startStr = parts[0];
      if(StringLen(startStr) != 4)
      {
         Print("ERROR: Invalid start time format: ", startStr, " (expected: HHMM)");
         return range;
      }

      string startHourStr = StringSubstr(startStr, 0, 2);
      string startMinuteStr = StringSubstr(startStr, 2, 2);
      range.startHour = (int)StringToInteger(startHourStr);
      range.startMinute = (int)StringToInteger(startMinuteStr);

      // 終了時刻をパース
      string endStr = parts[1];
      if(StringLen(endStr) != 4)
      {
         Print("ERROR: Invalid end time format: ", endStr, " (expected: HHMM)");
         return range;
      }

      string endHourStr = StringSubstr(endStr, 0, 2);
      string endMinuteStr = StringSubstr(endStr, 2, 2);
      range.endHour = (int)StringToInteger(endHourStr);
      range.endMinute = (int)StringToInteger(endMinuteStr);

      // 検証
      if(range.startHour < 0 || range.startHour > 23 ||
         range.endHour < 0 || range.endHour > 23 ||
         range.startMinute < 0 || range.startMinute > 59 ||
         range.endMinute < 0 || range.endMinute > 59)
      {
         Print("ERROR: Time values out of range: ", timeStr);
         return range;
      }

      range.isValid = true;
      return range;
   }

   //+------------------------------------------------------------------+
   //| 指定時刻が時間帯内かチェック                                    |
   //+------------------------------------------------------------------+
   static bool IsInRange(STimeRange &range, int hour, int minute)
   {
      if(!range.isValid)
         return false;

      int currentMinutes = hour * 60 + minute;
      int startMinutes = range.startHour * 60 + range.startMinute;
      int endMinutes = range.endHour * 60 + range.endMinute;

      // 日跨ぎのケース (例: 2300-0100)
      if(endMinutes < startMinutes)
      {
         // 開始時刻以降 または 終了時刻以前
         return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
      }
      else
      {
         // 通常のケース (例: 0500-0600)
         return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
      }
   }

   //+------------------------------------------------------------------+
   //| 時間帯を文字列に変換                                            |
   //+------------------------------------------------------------------+
   static string ToString(STimeRange &range)
   {
      if(!range.isValid)
         return "Invalid";

      return IntegerToString(range.startHour, 2, '0') +
             IntegerToString(range.startMinute, 2, '0') + "-" +
             IntegerToString(range.endHour, 2, '0') +
             IntegerToString(range.endMinute, 2, '0');
   }

   //+------------------------------------------------------------------+
   //| 時間帯が有効かチェック (0000-0000 は無効)                       |
   //+------------------------------------------------------------------+
   static bool IsEnabled(string timeStr)
   {
      // "0000-0000" は無効扱い
      if(timeStr == "0000-0000" || timeStr == "" || timeStr == "0")
         return false;

      STimeRange range = Parse(timeStr);
      if(!range.isValid)
         return false;

      // 開始と終了が同じ場合も無効
      if(range.startHour == range.endHour && range.startMinute == range.endMinute)
         return false;

      return true;
   }
};

//+------------------------------------------------------------------+
