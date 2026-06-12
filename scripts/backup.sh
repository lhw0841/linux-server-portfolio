#!/bin/bash
# ================================================
# 통합 자동 백업 스크립트
# 백업 대상: MySQL DB + Nginx 웹 파일
# Cron으로 매일 새벽 2시 실행
# 보존 정책: 30일 이상 된 백업 자동 삭제
# ================================================

DB_USER="srvadmin"
DB_PASS="1234"
DB_NAME="server_mgmt"
BACKUP_DIR="$HOME/backups"
WEB_DIR="/var/www/server-portfolio"
RETENTION_DAYS=30
NOW=$(date '+%Y-%m-%d %H:%M:%S')
DATE=$(date '+%Y%m%d_%H%M%S')
# DATE : 파일명에 쓸 날짜+시각. 예) 20260609_020000

# ── 백업 디렉토리 생성 ──────────────────────────
mkdir -p "$BACKUP_DIR/db"
mkdir -p "$BACKUP_DIR/web"
# -p:상위 폴더도 없으면 같이 생성

LOG_FILE="$BACKUP_DIR/backup.log"

echo "[$NOW] ===== 백업 시작 =====" >> "$LOG_FILE"

# ── 함수: DB에 백업 결과 기록 ──────────────────
record_backup() {
	local TYPE=$1
	local FILE=$2
	local SIZE=$3
	local RESULT=$4
	local MSG=$5

	 mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
        "INSERT INTO backup_log (backup_type, file_name, file_size, result, message)
         VALUES ('$TYPE', '$FILE', '$SIZE', '$RESULT', '$MSG');" 2>/dev/null

}


# ── 1. MySQL DB 백업 ────────────────────────────
echo "[$NOW] DB 백업 시작..." >> "$LOG_FILE"

DB_FILE="db_${DB_NAME}_${DATE}.sql.gz"
DB_PATH="$BACKUP_DIR/db/$DB_FILE"

mysqldump -u "$DB_USER" -p"$DB_PASS" "DB_NAME" 2>/dev/null | gzip > "DB_PATH"
# mysqldump : MySQL DB 전체를 SQL 파일로 내보내는 명령어
# | gzip : 출력을 바로 압축. 파일 크기를 줄이기 위해 사용

if [ $? -eq 0 ] && [ -s "$DB_PATH" ]; then
# $? : 바로 앞 명령어 종료 코드. 0이면 성공
# -s : 파일이 존재하고 크기가 0보다 큰지 확인
    SIZE=$(du -sh "$DB_PATH" | cut -f1)
    echo "[$NOW] DB 백업 성공: $DB_FILE ($SIZE)" >> "$LOG_FILE"
    record_backup "DB" "$DB_FILE" "$SIZE" "성공" "DB 백업 완료"
else
    echo "[$NOW] DB 백업 실패!" >> "$LOG_FILE"
    record_backup "DB" "$DB_FILE" "0" "실패" "DB 백업 중 오류 발생"
fi

# ── 2. 웹 파일 백업 ─────────────────────────────

echo "[$NOW] 웹파일 백업 시작..." >> "$LOG_FILE"

WEB_FILE="web_portfolio_${DATE}.tar.gz"
WEB_PATH="$BACKUP_DIR/web/$WEB_FILE"

sudo tar -czf "$WEB_PATH" -C /var/www server-portfolio 2>/dev/null
# tar -czf : 파일/폴더를 압축 묶음으로 만드는 명령어
# -c : 새로 만들기
# -z : gzip 압축
# -f : 파일명 지정
# -C /var/www : /var/www 폴더 기준으로
# server-portfolio : 이 폴더를 백업

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$WEB_PATH" | cut -f1)
    echo "[$NOW] 웹파일 백업 성공: $WEB_FILE ($SIZE)" >> "$LOG_FILE"
    record_backup "웹파일" "$WEB_FILE" "$SIZE" "성공" "웹 파일 백업 완료"
else
    echo "[$NOW] 웹파일 백업 실패!" >> "$LOG_FILE"
    record_backup "웹파일" "$WEB_FILE" "0" "실패" "웹파일 백업 중 오류 발생"
fi

# ── 3. 오래된 백업 자동 삭제 ───────────────────
echo "[$NOW] 오래된 백업 정리 중..." >> "$LOG_FILE"

find "$BACKUP_DIR" -name "*.gz" -mtime +"$RETENTION_DAYS" -delete
# find : 조건에 맞는 파일 찾기
# -name "*.gz" : .gz 확장자 파일
# -mtime +30 : 수정된 지 30일 이상 된 파일
# -delete : 찾은 파일 삭제

echo "[$NOW] 보존기간(${RETENTION_DAYS}일) 초과 파일 정리 완료" >> "$LOG_FILE"

# ── 4. 최종 현황 출력 ──────────────────────────
DB_COUNT=$(ls "$BACKUP_DIR/db/"*.gz 2>/dev/null | wc -l)
WEB_COUNT=$(ls "$BACKUP_DIR/web/"*.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)

echo "[$NOW] ===== 백업 완료 =====" >> "$LOG_FILE"
echo "[$NOW] DB 백업 파일: ${DB_COUNT}개 / 웹 백업 파일: ${WEB_COUNT}개 / 총 용량: ${TOTAL_SIZE}" >> "$LOG_FILE"

# 터미널에도 출력
echo "백업 완료 - DB: ${DB_COUNT}개 | 웹: ${WEB_COUNT}개 | 총 용량: ${TOTAL_SIZE}"



















