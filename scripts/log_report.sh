#!/bin/bash
# ================================================
# 일일 서버 로그 분석 리포트
# 매일 자정 Cron으로 자동 실행
# 분석 항목: 접속 현황, 오류, SSH 보안, 디스크
# ================================================

REPORT_DIR="/var/log/reports"
TODAY=$(date '+%Y-%m-%d')
# date '+%Y-%m-%d' : 오늘 날짜를 "2026-06-09" 형식으로 가져옴

REPORT_FILE="$REPORT_DIR/report_$TODAY.txt"
# 리포트 파일명에 날짜 붙여서 매일 새 파일 생성

ACCESS_LOG="/var/log/nginx/portfolio-access.log"
ERROR_LOG="/var/log/nginx/portfolio-error.log"
AUTH_LOG="/var/log/auth.log"

# ── 리포트 디렉토리 생성 ────────────────────────
sudo mkdir -p "$REPORT_DIR"
sudo chmod 777 "$REPORT_DIR"

# ── 리포트 작성 시작 ────────────────────────────
{
# { } : 중괄호 안의 모든 출력을 한 번에 파일로 저장하는 문법

echo "============================================"
echo "  일일 서버 로그 분석 리포트"
echo "  날짜: $TODAY"
echo "  생성: $(date '+%H:%M:%S')"
echo "============================================"

# ── 1. 서비스 현황 ──────────────────────────────
echo ""
echo "[1] 서비스 동작 현황"
for SERVICE in nginx mysql php8.3-fpm; do
# for ~ in ~ do ~ done : 목록의 각 항목을 순서대로 처리하는 반복문
    if systemctl is-active --quiet "$SERVICE"; then
        echo "  ✅ $SERVICE : 정상"
    else
        echo "  ❌ $SERVICE : 중단됨"
    fi
done

# ── 2. 접속 통계 ────────────────────────────────
echo ""
echo "[2] 오늘 접속 통계"

if [ -f "$ACCESS_LOG" ]; then
# -f : 파일이 존재하는지 확인. 없으면 분석 건너뜀

    # 전체 요청 수 카운트
    TOTAL=$(sudo wc -l < "$ACCESS_LOG")
    # wc -l : 파일의 줄 수 카운트. 줄 수 = 요청 수

    echo "  전체 요청 수: $TOTAL 건"

    # HTTP 상태코드별 집계
    echo "  상태코드별 현황:"
    sudo awk '{print $9}' "$ACCESS_LOG" | sort | uniq -c | sort -rn | head -5 | \
        awk '{print "    " $2 "번 코드 → " $1 "건"}'
    # awk '{print $9}' : 각 줄의 9번째 컬럼(상태코드) 추출
    # sort : 정렬
    # uniq -c : 중복 제거 + 각 항목 개수 카운트
    # sort -rn : 숫자 기준 내림차순 정렬

    # 가장 많이 접속한 IP 상위 5개
    echo "  접속 상위 5개 IP:"
    sudo awk '{print $1}' "$ACCESS_LOG" | sort | uniq -c | sort -rn | head -5 | \
        awk '{print "    " $2 " → " $1 "회"}'

    # 가장 많이 요청된 URL 상위 5개
    echo "  요청 많은 URL 상위 5개:"
    sudo awk '{print $7}' "$ACCESS_LOG" | sort | uniq -c | sort -rn | head -5 | \
        awk '{print "    " $2 " → " $1 "건"}'
else
    echo "  접속 로그 없음"
fi

# ── 3. 오류 현황 ────────────────────────────────
echo ""
echo "[3] Nginx 오류 현황"

if [ -f "$ERROR_LOG" ]; then
    ERROR_COUNT=$(sudo wc -l < "$ERROR_LOG")
    echo "  전체 오류 수: $ERROR_COUNT 건"

    # 오류 유형별 분류
    echo "  오류 유형별:"
    sudo grep -oP '\[.*?\]' "$ERROR_LOG" | sort | uniq -c | sort -rn | head -5 | \
        awk '{print "    " $2 " → " $1 "건"}'
    # grep -oP '\[.*?\]' : 대괄호 안의 내용만 추출 (오류 레벨)
else
    echo "  오류 로그 없음"
fi

# ── 4. SSH 보안 현황 ────────────────────────────
echo ""
echo "[4] SSH 보안 현황"

# 로그인 실패 횟수
FAIL_COUNT=$(sudo grep -c "Failed password" "$AUTH_LOG" 2>/dev/null || echo 0)
# grep -c : 패턴이 일치하는 줄 수만 카운트
# 2>/dev/null : 오류 메시지 숨김
# || echo 0 : 앞 명령어 실패하면 0 출력

echo "  SSH 로그인 실패: $FAIL_COUNT 건"

# 실패 횟수 많은 IP 상위 5개
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "  공격 의심 IP 상위 5개:"
    sudo grep "Failed password" "$AUTH_LOG" | \
        awk '{print $11}' | sort | uniq -c | sort -rn | head -5 | \
        awk '{print "    " $2 " → " $1 "회 실패"}'
fi

# 로그인 성공 횟수
SUCCESS_COUNT=$(sudo grep -c "Accepted" "$AUTH_LOG" 2>/dev/null || echo 0)
echo "  SSH 로그인 성공: $SUCCESS_COUNT 건"

# ── 5. 디스크 및 메모리 현황 ───────────────────
echo ""
echo "[5] 시스템 리소스 현황"

# 디스크 사용률
echo "  디스크:"
df -h | grep -v tmpfs | awk 'NR>1 {print "    " $6 " → " $3 " / " $2 " (" $5 " 사용)"}'
# grep -v tmpfs : tmpfs(가상 디스크) 제외
# NR>1 : 첫 줄(헤더) 제외

# 메모리 사용률
MEM_INFO=$(free -m | awk '/^Mem:/{printf "%s MB / %s MB (%.1f%%)", $3, $2, $3*100/$2}')
echo "  메모리: $MEM_INFO"

# ── 6. 백업 현황 ────────────────────────────────
echo ""
echo "[6] 백업 현황"

BACKUP_DIR="$HOME/backups"
if [ -d "$BACKUP_DIR" ]; then
# -d : 디렉토리가 존재하는지 확인
    BACKUP_COUNT=$(ls "$BACKUP_DIR"/*.gz 2>/dev/null | wc -l)
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    LATEST=$(ls -t "$BACKUP_DIR"/*.gz 2>/dev/null | head -1)
    # ls -t : 수정 시간 기준 정렬 (최신이 먼저)

    echo "  백업 파일 수: $BACKUP_COUNT 개"
    echo "  백업 총 용량: $BACKUP_SIZE"
    echo "  최신 백업: $(basename $LATEST 2>/dev/null || echo '없음')"
    # basename : 경로에서 파일명만 추출
else
    echo "  백업 디렉토리 없음"
fi

echo ""
echo "============================================"
echo "  리포트 끝"
echo "============================================"

} | sudo tee "$REPORT_FILE"
# } | sudo tee : 중괄호 안 모든 출력을 파일에 저장하면서 터미널에도 출력

echo ""
echo "리포트 저장 완료: $REPORT_FILE"
