#!/bin/bash
# ================================================
# 서비스 장애 감지 및 자동복구 스크립트
# 감시 대상: Nginx, MySQL, PHP-FPM
# Cron으로 1분마다 실행
# ================================================

DB_USER="srvadmin"
DB_PASS="1234"
DB_NAME="server_mgmt"
RECOVERY_LOG="/var/log/server_recovery.log"
NOW=$(date '+%Y-%m-%d %H:%M:%S')
# date '+%Y-%m-%d %H:%M:%S' : 현재 시각을 "2026-06-09 14:00:00" 형식으로 가져옴
# $() : 명령어 실행 결과를 변수에 저장하는 문법

# ── 서비스 체크 + 자동복구 함수 ────────────────
check_and_recover() {
    local SERVICE=$1
    # local : 이 함수 안에서만 쓰는 변수 선언
    # $1 : 함수 호출 시 첫 번째로 넘긴 값 (예: "nginx")

    local MAX_RETRY=3
    # 재시작 최대 3번까지 시도

    # systemctl is-active : 서비스가 실행 중인지 확인
    # --quiet : 출력 없이 결과만 반환
    # if ~ ; then ~ fi : 조건문. 참이면 실행
    if systemctl is-active --quiet "$SERVICE"; then
        return 0  # 정상이면 함수 종료 (0 = 정상)
    fi

    # 여기까지 왔다면 서비스가 다운된 상태
    echo "[$NOW] [감지] $SERVICE 서비스 다운 확인" | sudo tee -a "$RECOVERY_LOG"
    # echo : 터미널에 텍스트 출력
    # | : 파이프. 앞 명령어 출력을 뒤 명령어 입력으로 연결
    # tee -a : 터미널에도 출력하면서 파일에도 추가(-a) 저장

    # DB에 장애 발생 기록
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
        "INSERT INTO incident_log (service_name, action, result, message)
         VALUES ('$SERVICE', '장애감지', '처리중', '$SERVICE 서비스 다운 감지');" 2>/dev/null
    # -e : MySQL에 직접 쿼리 실행
    # 2>/dev/null : 오류 메시지는 버림 (비밀번호 경고 숨김용)

    # 재시작 반복 시도
    local RETRY=0
    while [ $RETRY -lt $MAX_RETRY ]; do
    # while : 조건이 참인 동안 반복
    # -lt : less than (작다)
    # RETRY가 MAX_RETRY(3)보다 작은 동안 반복

        RETRY=$((RETRY + 1))
        # $(( )) : 숫자 계산 문법. RETRY에 1 더하기

        echo "[$NOW] [복구시도] $SERVICE 재시작 시도 ($RETRY/$MAX_RETRY)" \
            | sudo tee -a "$RECOVERY_LOG"

        sudo systemctl restart "$SERVICE"
        # systemctl restart : 서비스 재시작

        sleep 3
        # sleep 3 : 3초 대기. 재시작 완료될 시간 기다림

        if systemctl is-active --quiet "$SERVICE"; then
            echo "[$NOW] [복구성공] $SERVICE 재시작 완료" \
                | sudo tee -a "$RECOVERY_LOG"

            mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
                "INSERT INTO incident_log (service_name, action, result, message)
                 VALUES ('$SERVICE', '자동복구', '성공', '$RETRY회 시도 후 복구 완료');" 2>/dev/null
            return 0
        fi
    done

    # 3번 다 시도했는데도 실패한 경우
    echo "[$NOW] [복구실패] $SERVICE $MAX_RETRY회 시도 후 복구 실패" \
        | sudo tee -a "$RECOVERY_LOG"

    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
        "INSERT INTO incident_log (service_name, action, result, message)
         VALUES ('$SERVICE', '자동복구', '실패', '$MAX_RETRY회 시도 후 복구 실패 - 수동 점검 필요');" 2>/dev/null
}

# ── 감시 대상 서비스 3개 체크 ──────────────────
# 함수를 서비스 이름을 바꿔가며 3번 호출
check_and_recover "nginx"
check_and_recover "mysql"
check_and_recover "php8.3-fpm"

# ── 1시간마다 정상 상태 기록 ───────────────────
MINUTE=$(date '+%M')
# date '+%M' : 현재 분(minute)만 가져옴

if [ "$MINUTE" = "00" ]; then
# 분이 00일 때 = 매 정각에만 실행
    echo "[$NOW] [정상] 전체 서비스 동작 중" | sudo tee -a "$RECOVERY_LOG"
fi
