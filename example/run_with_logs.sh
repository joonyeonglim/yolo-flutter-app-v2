#!/bin/bash

# Flutter YOLO 앱 실행 + 로그 필터링 및 파일 저장 스크립트

# 로그 디렉토리 생성
LOG_DIR="logs"
mkdir -p $LOG_DIR

# 현재 시간으로 로그 파일명 생성
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
FULL_LOG_FILE="$LOG_DIR/full_log_$TIMESTAMP.txt"
FILTERED_LOG_FILE="$LOG_DIR/filtered_log_$TIMESTAMP.txt"
BUILD_LOG_FILE="$LOG_DIR/build_log_$TIMESTAMP.txt"

echo "🧹 Cleaning Flutter project..."
fvm flutter clean

echo "📦 Getting dependencies..."
fvm flutter pub get 2>&1 | tee $BUILD_LOG_FILE

echo "🚀 Starting Flutter app..."
echo "📁 Build logs saved to: $BUILD_LOG_FILE"

# Flutter 실행 로그도 파일에 저장
fvm flutter run -d "R3CNC030KPB" 2>&1 | tee -a $BUILD_LOG_FILE &
FLUTTER_PID=$!

echo "⏳ Waiting for app to start..."
sleep 5

echo "📊 Starting log capture..."
echo "📁 Full logs: $FULL_LOG_FILE"
echo "📁 Filtered logs: $FILTERED_LOG_FILE"
echo "=== Filtered YOLO App Logs (INFO+) ==="
echo "=== Press Ctrl+C to stop ==="

# 전체 로그를 파일에 저장하면서, 필터링된 로그만 화면에 표시
adb logcat "*:I" | tee $FULL_LOG_FILE | grep -E "(YOLOView|YOLOPlatformView|Classifier|tflite|Camera)" | tee $FILTERED_LOG_FILE

# 종료 시 Flutter 프로세스도 정리
trap "kill $FLUTTER_PID 2>/dev/null; exit" SIGINT SIGTERM 