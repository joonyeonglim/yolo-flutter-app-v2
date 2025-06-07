# クイックモデルセットアップ

## 1. モデルファイルの配置確認

```bash
# 現在の配置を確認
ls -la android/app/src/main/assets/

# 以下のファイルが必要：
# - yolo11n.tflite
# - yolo11n-seg.tflite
# - yolo11n-cls.tflite
# - yolo11n-pose.tflite
# - yolo11n-obb.tflite
```

## 2. モデルファイルがない場合

### オプション A: ダウンロード
```bash
# GitHubのリリースページから手動でダウンロード
# https://github.com/ultralytics/yolo-flutter-app/releases/tag/v0.0.0
# ダウンロード後、以下に配置：
# android/app/src/main/assets/yolo11n.tflite
```

### オプション B: Pythonでエクスポート
```python
# Pythonスクリプトでモデルを生成
from ultralytics import YOLO

# 検出モデル
model = YOLO("yolo11n.pt")
model.export(format="tflite", imgsz=640)
# 生成された yolo11n_saved_model/yolo11n_float32.tflite を
# yolo11n.tflite にリネームして配置

# その他のモデルも同様に：
# セグメンテーション
model_seg = YOLO("yolo11n-seg.pt")
model_seg.export(format="tflite", imgsz=640)
# yolo11n-seg_saved_model/yolo11n-seg_float32.tflite → yolo11n-seg.tflite

# 分類
model_cls = YOLO("yolo11n-cls.pt")
model_cls.export(format="tflite", imgsz=224)
# yolo11n-cls_saved_model/yolo11n-cls_float32.tflite → yolo11n-cls.tflite
```

## 3. デバッグ手順

```bash
# 1. ファイルの存在確認
file android/app/src/main/assets/yolo11n.tflite

# 2. ファイルサイズ確認（0バイトでないこと）
ls -lh android/app/src/main/assets/yolo11n.tflite

# 3. アプリをクリーンビルド
cd screenshot_app
flutter clean
flutter pub get
flutter run
```

## 4. 簡易テスト用の最小構成

最低限、検出モデルだけでもテスト可能：
```bash
# yolo11n.tflite だけ配置してテスト
cp /path/to/yolo11n.tflite android/app/src/main/assets/
```

## トラブルシューティング

### エラー: FileNotFoundException
- ファイル名の大文字小文字を確認
- 拡張子が `.tflite` であることを確認
- ファイルが0バイトでないことを確認

### エラー: Failed to load model
- TFLiteファイルが正しい形式か確認
- モデルのバージョンが互換性があるか確認