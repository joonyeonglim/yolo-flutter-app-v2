#!/bin/bash

# 로그 파일 조회 및 분석 스크립트

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_DIR="logs"

if [ ! -d "$LOG_DIR" ]; then
    echo -e "${RED}❌ logs 디렉토리가 없습니다!${NC}"
    exit 1
fi

echo -e "${GREEN}📁 저장된 로그 파일들:${NC}"
echo

# 최신 파일들 표시
echo -e "${BLUE}=== 최신 로그 파일들 (최근 5개) ===${NC}"
ls -lt $LOG_DIR/*.txt 2>/dev/null | head -5 | while read -r line; do
    echo "   $line"
done

echo
echo -e "${YELLOW}📊 사용 가능한 명령어들:${NC}"
echo "   1) ${GREEN}./view_logs.sh errors${NC}     - 최신 에러 로그 보기"
echo "   2) ${GREEN}./view_logs.sh yolo${NC}       - 최신 YOLO 로그 보기"
echo "   3) ${GREEN}./view_logs.sh camera${NC}     - 최신 카메라 로그 보기"
echo "   4) ${GREEN}./view_logs.sh build${NC}      - 최신 빌드 로그 보기"
echo "   5) ${GREEN}./view_logs.sh full${NC}       - 최신 전체 로그 보기"
echo "   6) ${GREEN}./view_logs.sh list${NC}       - 모든 로그 파일 목록"
echo "   7) ${GREEN}./view_logs.sh clean${NC}      - 오래된 로그 파일 정리"

echo

case "$1" in
    "errors")
        LATEST_ERROR=$(ls -t $LOG_DIR/errors_*.txt 2>/dev/null | head -1)
        if [ -n "$LATEST_ERROR" ]; then
            echo -e "${RED}🚨 최신 에러 로그: $LATEST_ERROR${NC}"
            echo "======================================"
            tail -50 "$LATEST_ERROR"
        else
            echo -e "${YELLOW}⚠️ 에러 로그 파일이 없습니다.${NC}"
        fi
        ;;
    "yolo")
        LATEST_YOLO=$(ls -t $LOG_DIR/yolo_*.txt 2>/dev/null | head -1)
        if [ -n "$LATEST_YOLO" ]; then
            echo -e "${GREEN}🤖 최신 YOLO 로그: $LATEST_YOLO${NC}"
            echo "======================================"
            tail -50 "$LATEST_YOLO"
        else
            echo -e "${YELLOW}⚠️ YOLO 로그 파일이 없습니다.${NC}"
        fi
        ;;
    "camera")
        LATEST_CAMERA=$(ls -t $LOG_DIR/camera_*.txt 2>/dev/null | head -1)
        if [ -n "$LATEST_CAMERA" ]; then
            echo -e "${BLUE}📹 최신 카메라 로그: $LATEST_CAMERA${NC}"
            echo "======================================"
            tail -50 "$LATEST_CAMERA"
        else
            echo -e "${YELLOW}⚠️ 카메라 로그 파일이 없습니다.${NC}"
        fi
        ;;
    "build")
        LATEST_BUILD=$(ls -t $LOG_DIR/build_*.txt 2>/dev/null | head -1)
        if [ -n "$LATEST_BUILD" ]; then
            echo -e "${YELLOW}📄 최신 빌드 로그: $LATEST_BUILD${NC}"
            echo "======================================"
            tail -100 "$LATEST_BUILD"
        else
            echo -e "${YELLOW}⚠️ 빌드 로그 파일이 없습니다.${NC}"
        fi
        ;;
    "full")
        LATEST_FULL=$(ls -t $LOG_DIR/full_*.txt 2>/dev/null | head -1)
        if [ -n "$LATEST_FULL" ]; then
            echo -e "${BLUE}📊 최신 전체 로그: $LATEST_FULL${NC}"
            echo "======================================"
            echo -e "${YELLOW}(마지막 100줄만 표시)${NC}"
            tail -100 "$LATEST_FULL"
        else
            echo -e "${YELLOW}⚠️ 전체 로그 파일이 없습니다.${NC}"
        fi
        ;;
    "list")
        echo -e "${BLUE}📂 모든 로그 파일 목록:${NC}"
        ls -lh $LOG_DIR/*.txt 2>/dev/null || echo -e "${YELLOW}⚠️ 로그 파일이 없습니다.${NC}"
        ;;
    "clean")
        echo -e "${YELLOW}🧹 7일 이상 된 로그 파일 정리 중...${NC}"
        find $LOG_DIR -name "*.txt" -mtime +7 -delete 2>/dev/null
        echo -e "${GREEN}✅ 정리 완료!${NC}"
        ;;
    *)
        echo -e "${BLUE}💡 예시: ./view_logs.sh errors${NC}"
        ;;
esac 