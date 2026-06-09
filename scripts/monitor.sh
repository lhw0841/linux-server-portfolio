#!/bin/bash
# ================================================
# 서버 리소스 모니터링 스크립트
# Cron으로 5분마다 자동 실행
# 수집 항목: CPU, 메모리, 디스크, 로드평균
# ================================================

DB_USER="srvadmin"
DB_PASS="1234"
DB_NAME="server_mgmt"
LOG_FILE="/var/log/server_monitor.log"
ALERT_CPU=80 #CPU 경고 임계값 (%)
ALERT_MEM=85 #메모리 경고 임계값(%)
ALERT_DISK=85 #디스크 경고 임계값(5)

NOW=$(date '+%Y-%m-%d %H:%M:%S')

# ── 1. CPU 사용률 수집 ──────────────────────────
# idel 값을 빼서 계산
CPU_IDLE=$(top -bn1 | grep "%Cpu" | awk '{print $8}' | cut -d. -f1)
CPU_USAGE=$((100 - CPU_IDLE))

# ── 2. 메모리 수집 ─────────────────────────────
MEM_TOTAL=$(LANG=C free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(LANG=C free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$(echo "scale=1; $MEM_USED * 100 / $MEM_TOTAL" | bc)

# ── 3. 디스크 수집 ─────────────────────────────
DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
DISK_USED=$(df -h / | awk 'NR==2{print $3}')
DISK_PCT=$(df /  | awk 'NR==2{gsub(/%/,"",$5); print $5}')

# ── 4. 로드 평균 수집 ──────────────────────────
LOAD_AVG=$(uptime | awk -F 'load average:' '{print $2}' | xargs)

# ── 5. 상태 판단 ───────────────────────────────
STATUS="정상"
if [ "$CPU_USAGE" -ge "$ALERT_CPU" ] || \
   [ "${MEM_PCT%.*}" -ge "$ALERT_MEM" ] || \
   [ "$DISK_PCT" -ge "$ALERT_DISK" ]; then
    STATUS="경고"
fi

# ── 6. DB에 기록 ───────────────────────────────
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << EOF
INSERT INTO monitor_log
    (cpu_usage, mem_total, mem_used, mem_pct,
     disk_total, disk_used, disk_pct, load_avg, status)
VALUES
    ($CPU_USAGE, $MEM_TOTAL, $MEM_USED, $MEM_PCT,
     '$DISK_TOTAL', '$DISK_USED', $DISK_PCT, '$LOAD_AVG', '$STATUS');
EOF

# ── 7. 로그 파일에 기록 ────────────────────────
echo "[$NOW] CPU:${CPU_USAGE}% MEM:${MEM_PCT}% DISK:${DISK_PCT}% 상태:${STATUS}" \
    | sudo tee -a "$LOG_FILE" > /dev/null

# ── 8. 경고 시 별도 알림 로그 ─────────────────
if [ "$STATUS" = "경고" ]; then
    echo "[$NOW] [경고] CPU:${CPU_USAGE}% MEM:${MEM_PCT}% DISK:${DISK_PCT}%" \
        | sudo tee -a /var/log/server_alert.log > /dev/null
fi

echo "[$NOW] 모니터링 완료 - $STATUS"










