# OverNight Close EA

MT4/MT5対応の曜日別時間帯自動決済EA。プロップファームの週末持ち越し防止や、指定時間帯での自動決済に最適。

## 特徴

- **曜日別設定**: 各曜日ごとに異なる決済時間帯を設定可能
- **MT4/MT5両対応**: 同一コードで両プラットフォームに対応
- **多彩な通知機能**: アラート、サウンド、メール、プッシュ通知
- **ブローカー自動対応**: 25社以上の主要ブローカーのフィリングモード自動検出（MT5）
- **日本時間対応**: 夏時間自動調整またはGMT固定オフセット対応
- **マジックナンバーフィルター**: 特定のEAのポジションのみ決済可能

## インストール

### MT4の場合
1. すべての`.mqh`ファイルと`OverNightCloseEA.mq4`を`MQL4/Experts/`フォルダにコピー
2. MetaEditorで`OverNightCloseEA.mq4`をコンパイル
3. チャートにドラッグ&ドロップ

### MT5の場合
1. すべての`.mqh`ファイルと`OverNightCloseEA.mq5`を`MQL5/Experts/`フォルダにコピー
2. MetaEditorで`OverNightCloseEA.mq5`をコンパイル
3. チャートにドラッグ&ドロップ

## 使い方

### 基本設定

#### 曜日別決済時間帯（日本時間）
各曜日ごとにHHMM-HHMM形式で時間帯を指定します。

```
Monday_CloseTime    = "0000-0000"  // 無効
Tuesday_CloseTime   = "0000-0000"  // 無効
Wednesday_CloseTime = "0000-0000"  // 無効
Thursday_CloseTime  = "0000-0000"  // 無効
Friday_CloseTime    = "2300-2359"  // 金曜23:00-23:59に決済
Saturday_CloseTime  = "0000-0000"  // 無効
Sunday_CloseTime    = "0000-0000"  // 無効
```

**日跨ぎ対応**: `2300-0100`のような設定も可能です。

#### タイムゾーン設定

**TZ_JST（推奨）**: 夏時間自動調整
- GMT+2ブローカーの場合: SummerOffset=6, WinterOffset=7
- GMT+3ブローカーの場合: SummerOffset=5, WinterOffset=6

**TZ_JST_FIXED**: 固定オフセット
- GMT+0ブローカーの場合: FixedOffset=9

**TZ_SERVER_TIME**: サーバー時刻をそのまま使用

### 決済対象設定

```
ClosePositions      = true   // ポジションを決済
ClosePendingOrders  = true   // 待機注文を削除
MagicNumber         = 0      // 0=全て、特定の値=そのマジックナンバーのみ
```

### アクション設定

```
CloseAction = ACTION_CLOSE_AND_STOP_EA  // 決済後にEAを停止
CloseAction = ACTION_CLOSE_ONLY         // 決済のみ（EA継続）
```

### 通知設定

```
EnableAlert         = true   // アラート通知
EnableSound         = true   // サウンド通知
EnableEmail         = false  // メール通知（要設定）
EnablePush          = false  // プッシュ通知（要設定）
AlertMinutesBefore  = 5      // 事前通知（5分前）
```

#### メール通知の設定方法
1. MT4/MT5メニュー: ツール → オプション → メール
2. 有効化にチェック
3. SMTPサーバー、ログイン情報、送信先メールアドレスを入力

#### プッシュ通知の設定方法
1. スマホにMetaTraderアプリをインストール
2. MT4/MT5メニュー: ツール → オプション → 通知
3. 有効化にチェック
4. MetaQuotes IDを入力（アプリで確認）

### 決済設定

```
MaxRetries   = 3      // 決済リトライ回数
RetryDelay   = 1000   // リトライ間隔（ミリ秒）
Slippage     = 3      // スリッページ（pips）
```

## ファイル構成

```
OverNightCloseEA.mq4           # MT4メインファイル
OverNightCloseEA.mq5           # MT5メインファイル
OverNightCloseEA.mqh           # コアロジック（MT4/MT5共通）
JapanTimeCalculator.mqh        # 日本時間計算（夏時間対応）
TimeRangeParser.mqh            # 時間帯パーサー
BrokerFillingMode.mqh          # ブローカー別フィリングモード自動検出
```

## 使用例

### 例1: 金曜日23:00-23:59に全決済してEA停止
```
Friday_CloseTime = "2300-2359"
ClosePositions = true
ClosePendingOrders = true
CloseAction = ACTION_CLOSE_AND_STOP_EA
```

### 例2: 毎日17:00-17:30にマジックナンバー12345のポジションのみ決済
```
Monday_CloseTime = "1700-1730"
Tuesday_CloseTime = "1700-1730"
Wednesday_CloseTime = "1700-1730"
Thursday_CloseTime = "1700-1730"
Friday_CloseTime = "1700-1730"
MagicNumber = 12345
CloseAction = ACTION_CLOSE_ONLY
```

### 例3: 週末持ち越し防止（金曜深夜＋土曜早朝）
```
Friday_CloseTime = "2355-2359"
Saturday_CloseTime = "0000-0100"
CloseAction = ACTION_CLOSE_AND_STOP_EA
```

## 対応ブローカー（MT5フィリングモード自動検出）

XM, EXNESS, FXGT, 外為ファイネスト, IC Markets, Pepperstone, HotForex, RoboForex, Alpari, FBS, OCTA, Tickmill, TitanFX, AvaTrade, FXTM, Admiral Markets, Axiory, ThinkMarkets, IronFX, GKFX, FXCM, FP Markets など25社以上

未対応ブローカーでも自動検出して学習します。

## トラブルシューティング

### コンパイルエラーが出る
- すべての`.mqh`ファイルが同じフォルダにあることを確認
- MetaEditorを再起動してコンパイル

### 決済されない
- 日本時間の設定を確認（夏時間オフセットが正しいか）
- ログを確認して現在の日本時間が表示されているか確認
- `0000-0000`は無効なので、有効な時間帯を設定

### メール/プッシュ通知が届かない
- MT4/MT5のオプション設定を確認
- テスト送信ボタンで接続確認

## ライセンス

Copyright 2025, OverNightCloseEA

## クレジット

- 日本時間計算ロジック: harukiiの記事を参考
- ブローカーフィリングモード検出: 独自実装

## バージョン履歴

### v2.0 (2025-01-16)
- DLL依存を削除
- メール通知機能追加
- プッシュ通知機能追加
- コード最適化

### v1.0
- 初回リリース
- 曜日別時間帯決済機能
- MT4/MT5対応
