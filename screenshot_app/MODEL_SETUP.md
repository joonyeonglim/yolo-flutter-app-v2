# モデルファイルの配置方法 / Model Setup Guide

## Android用 (TFLite models)

1. **配置場所**: `screenshot_app/android/app/src/main/assets/`

2. **必要なファイル**:
   - `yolo11n.tflite` (検出用)
   - `yolo11n-seg.tflite` (セグメンテーション用)
   - `yolo11n-cls.tflite` (分類用)
   - `yolo11n-pose.tflite` (ポーズ推定用)
   - `yolo11n-obb.tflite` (回転バウンディングボックス用)

3. **コマンド例**:
   ```bash
   # exampleアプリからコピーする場合
   cp ../example/android/app/src/main/assets/*.tflite android/app/src/main/assets/
   
   # または個別にコピー
   cp path/to/yolo11n.tflite android/app/src/main/assets/
   ```

## iOS用 (CoreML models)

1. **Xcodeで追加**:
   - `screenshot_app/ios/Runner.xcworkspace` をXcodeで開く
   - モデルファイル (`.mlpackage` または `.mlmodel`) をドラッグ&ドロップ
   - Target を "Runner" に設定

2. **必要なファイル**:
   - `yolo11n.mlpackage` (検出用)
   - `yolo11n-seg.mlpackage` (セグメンテーション用)
   - `yolo11n-cls.mlpackage` (分類用)
   - `yolo11n-pose.mlpackage` (ポーズ推定用)
   - `yolo11n-obb.mlpackage` (回転バウンディングボックス用)

## モデルファイルの入手方法

### 方法1: Exampleアプリから
```bash
# Androidモデル
cp -r ../example/android/app/src/main/assets/*.tflite android/app/src/main/assets/

# iOSモデルはXcodeで手動追加が必要
```

### 方法2: ダウンロード
[Release Assets](https://github.com/ultralytics/yolo-flutter-app/releases/tag/v0.0.0) からダウンロード

### 方法3: エクスポート
```python
from ultralytics import YOLO

# 各タスク用のモデルをエクスポート
model = YOLO("yolo11n.pt")
model.export(format="tflite")  # Android用
model.export(format="coreml")  # iOS用
```

## トラブルシューティング

### "Model not found" エラーの場合
1. ファイル名が正確か確認 (例: `yolo11n.tflite`)
2. 配置場所が正しいか確認
3. Androidの場合、`flutter clean && flutter pub get` を実行
4. iOSの場合、Xcodeでファイルがターゲットに含まれているか確認

### デバッグ用ログ
```dart
// InferenceService.dartで以下を追加してパスを確認
print('Looking for model at: $_getModelPath()');
```