//+------------------------------------------------------------------+
//|                                        JapanTimeCalculator.mqh   |
//|                              Based on harukii's Zenn article    |
//|                   https://zenn.dev/harukii/articles/...         |
//+------------------------------------------------------------------+
#property copyright "Based on harukii's work"
#property strict

//+------------------------------------------------------------------+
//| タイムゾーン選択                                                |
//+------------------------------------------------------------------+
enum ENUM_TIMEZONE_MODE
{
   TZ_SERVER_TIME,        // サーバー時刻
   TZ_JST,                // 日本時間(GMT+9) - 夏時間自動調整
   TZ_JST_FIXED           // 日本時間(GMT+9) - 固定オフセット
};

//+------------------------------------------------------------------+
//| 日本時間計算クラス                                              |
//+------------------------------------------------------------------+
class CJapanTimeCalculator
{
private:
   ENUM_TIMEZONE_MODE m_timezoneMode;
   int                m_summerOffset;    // 夏時間オフセット(時間)
   int                m_winterOffset;    // 冬時間オフセット(時間)
   int                m_fixedOffset;     // 固定オフセット(時間)

   //+------------------------------------------------------------------+
   //| 夏時間判定(米国基準)                                            |
   //| 3月第2日曜日 ～ 11月第1日曜日                                   |
   //+------------------------------------------------------------------+
   bool IsSummerTime(datetime dt)
   {
      MqlDateTime dts;
      TimeToStruct(dt, dts);

      int year = dts.year;
      int month = dts.mon;
      int day = dts.day;
      int dayOfWeek = dts.day_of_week;

      // 3月より前、または11月より後は冬時間
      if(month < 3 || month > 11)
         return false;

      // 4月～10月は夏時間
      if(month > 3 && month < 11)
         return true;

      // 3月の判定: 第2日曜日以降
      if(month == 3)
      {
         // 第2日曜日を計算
         int firstDay = 1;
         MqlDateTime firstDayDt;
         TimeToStruct(StringToTime(IntegerToString(year) + ".03.01"), firstDayDt);
         int firstDayOfWeek = firstDayDt.day_of_week;

         // 第1日曜日の日付
         int firstSunday = (firstDayOfWeek == 0) ? 1 : (8 - firstDayOfWeek);
         // 第2日曜日の日付
         int secondSunday = firstSunday + 7;

         if(day < secondSunday)
            return false;
         else if(day > secondSunday)
            return true;
         else // day == secondSunday
            return (dayOfWeek == 0); // 日曜日なら夏時間開始
      }

      // 11月の判定: 第1日曜日より前
      if(month == 11)
      {
         // 第1日曜日を計算
         MqlDateTime firstDayDt;
         TimeToStruct(StringToTime(IntegerToString(year) + ".11.01"), firstDayDt);
         int firstDayOfWeek = firstDayDt.day_of_week;

         // 第1日曜日の日付
         int firstSunday = (firstDayOfWeek == 0) ? 1 : (8 - firstDayOfWeek);

         if(day < firstSunday)
            return true;
         else if(day > firstSunday)
            return false;
         else // day == firstSunday
            return (dayOfWeek != 0); // 日曜日でなければまだ夏時間
      }

      return false;
   }

public:
   //+------------------------------------------------------------------+
   //| コンストラクタ                                                  |
   //+------------------------------------------------------------------+
   CJapanTimeCalculator()
   {
      m_timezoneMode = TZ_SERVER_TIME;
      m_summerOffset = 6;  // デフォルト: GMT+2サーバーの場合、+6時間で日本時間
      m_winterOffset = 7;  // デフォルト: GMT+2サーバーの場合、+7時間で日本時間
      m_fixedOffset = 9;   // デフォルト: GMT+0の場合、+9時間で日本時間
   }

   //+------------------------------------------------------------------+
   //| 設定                                                            |
   //+------------------------------------------------------------------+
   void Configure(ENUM_TIMEZONE_MODE mode, int summerOffset, int winterOffset, int fixedOffset = 9)
   {
      m_timezoneMode = mode;
      m_summerOffset = summerOffset;
      m_winterOffset = winterOffset;
      m_fixedOffset = fixedOffset;
   }

   //+------------------------------------------------------------------+
   //| 日本時間取得                                                    |
   //+------------------------------------------------------------------+
   datetime GetJapanTime(datetime serverTime)
   {
      if(m_timezoneMode == TZ_SERVER_TIME)
      {
         // サーバー時刻をそのまま返す
         return serverTime;
      }
      else if(m_timezoneMode == TZ_JST)
      {
         // 夏時間を考慮してオフセット
         bool isSummer = IsSummerTime(serverTime);
         int offset = isSummer ? m_summerOffset : m_winterOffset;
         return serverTime + (offset * 3600);
      }
      else // TZ_JST_FIXED
      {
         // 固定オフセット
         return serverTime + (m_fixedOffset * 3600);
      }
   }

   //+------------------------------------------------------------------+
   //| 現在の日本時間取得                                              |
   //+------------------------------------------------------------------+
   datetime GetCurrentJapanTime()
   {
      return GetJapanTime(TimeCurrent());
   }

   //+------------------------------------------------------------------+
   //| 日本時間の時を取得                                              |
   //+------------------------------------------------------------------+
   int GetHour(datetime japanTime)
   {
      MqlDateTime dt;
      TimeToStruct(japanTime, dt);
      return dt.hour;
   }

   //+------------------------------------------------------------------+
   //| 日本時間の分を取得                                              |
   //+------------------------------------------------------------------+
   int GetMinute(datetime japanTime)
   {
      MqlDateTime dt;
      TimeToStruct(japanTime, dt);
      return dt.min;
   }

   //+------------------------------------------------------------------+
   //| 日本時間の曜日を取得                                            |
   //+------------------------------------------------------------------+
   int GetDayOfWeek(datetime japanTime)
   {
      MqlDateTime dt;
      TimeToStruct(japanTime, dt);
      return dt.day_of_week;
   }

   //+------------------------------------------------------------------+
   //| 日本時間の日を取得                                              |
   //+------------------------------------------------------------------+
   int GetDay(datetime japanTime)
   {
      MqlDateTime dt;
      TimeToStruct(japanTime, dt);
      return dt.day;
   }

   //+------------------------------------------------------------------+
   //| タイムゾーンモード名を取得                                      |
   //+------------------------------------------------------------------+
   string GetTimeZoneName()
   {
      switch(m_timezoneMode)
      {
         case TZ_SERVER_TIME:  return "Server Time";
         case TZ_JST:          return "JST (Auto DST)";
         case TZ_JST_FIXED:    return "JST (Fixed)";
         default:              return "Unknown";
      }
   }

   //+------------------------------------------------------------------+
   //| 現在のオフセット取得(デバッグ用)                                |
   //+------------------------------------------------------------------+
   int GetCurrentOffset()
   {
      if(m_timezoneMode == TZ_SERVER_TIME)
         return 0;
      else if(m_timezoneMode == TZ_JST)
         return IsSummerTime(TimeCurrent()) ? m_summerOffset : m_winterOffset;
      else
         return m_fixedOffset;
   }
};

//+------------------------------------------------------------------+
