#!/bin/bash

# Flutter YOLO 앱 실행 + 상세 로그 분류 및 파일 저장 스크립트

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 디렉토리 생성
LOG_DIR="logs"
mkdir -p $LOG_DIR

# 현재 시간으로 로그 파일명 생성
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
BUILD_LOG="$LOG_DIR/build_$TIMESTAMP.txt"
YOLO_LOG="$LOG_DIR/yolo_$TIMESTAMP.txt"
CAMERA_LOG="$LOG_DIR/camera_$TIMESTAMP.txt"
ERROR_LOG="$LOG_DIR/errors_$TIMESTAMP.txt"
FULL_LOG="$LOG_DIR/full_$TIMESTAMP.txt"

echo -e "${GREEN}🧹 Cleaning Flutter project...${NC}"
fvm flutter clean

echo -e "${GREEN}📦 Getting dependencies...${NC}"
fvm flutter pub get 2>&1 | tee $BUILD_LOG

echo -e "${GREEN}🚀 Starting Flutter app...${NC}"
echo -e "${BLUE}📁 Logs will be saved to:${NC}"
echo -e "   📄 Build logs: $BUILD_LOG"
echo -e "   🤖 YOLO logs: $YOLO_LOG"
echo -e "   📹 Camera logs: $CAMERA_LOG"
echo -e "   ❌ Error logs: $ERROR_LOG"
echo -e "   📊 Full logs: $FULL_LOG"

# Flutter 실행 (백그라운드)
fvm flutter run -d "R3CNC030KPB" 2>&1 | tee -a $BUILD_LOG &
FLUTTER_PID=$!

echo -e "${YELLOW}⏳ Waiting for app to start...${NC}"
sleep 5

echo -e "${GREEN}📊 Starting categorized log capture...${NC}"
echo -e "${BLUE}=== Live Filtered Logs (화면 표시용) ===${NC}"
echo -e "${YELLOW}=== Press Ctrl+C to stop ===${NC}"

# 로그를 실시간으로 분류하여 저장
adb logcat "*:I" | tee $FULL_LOG | while IFS= read -r line; do
    # YOLO 관련 로그
    if echo "$line" | grep -qE "(YOLOView|YOLOPlatformView|Classifier|Predictor|YOLO)"; then
        echo "$line" >> $YOLO_LOG
        echo -e "${GREEN}[YOLO]${NC} $line"
    
    # 카메라 관련 로그  
    elif echo "$line" | grep -qE "(Camera|Preview|VideoCapture|Recording|Surface)"; then
        echo "$line" >> $CAMERA_LOG
        echo -e "${BLUE}[CAM]${NC} $line"
    
    # 에러 로그
    elif echo "$line" | grep -qE "(E/|ERROR|FATAL|Exception|Error)"; then
        echo "$line" >> $ERROR_LOG
        echo -e "${RED}[ERR]${NC} $line"
    
    # 중요한 기타 로그만 화면에 표시
    elif echo "$line" | grep -qE "(tflite|GPU|Model|I/flutter)"; then
        echo -e "${YELLOW}[INFO]${NC} $line"
    fi
done &

LOG_PID=$!

# 종료 시 모든 프로세스 정리
cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping processes...${NC}"
    kill $FLUTTER_PID 2>/dev/null
    kill $LOG_PID 2>/dev/null
    echo -e "${GREEN}✅ Logs saved successfully!${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# 메인 프로세스 대기
wait $LOG_PID 