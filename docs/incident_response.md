# 장애대응 절차서

## 1. 서비스 다운 (Nginx / MySQL / PHP-FPM)

**자동 대응**: recovery.sh가 1분마다 감지하여 최대 3회 자동 재시작합니다.

**자동복구 실패 시 수동 대응**:

```bash
# 1) 상태 확인
sudo systemctl status nginx   # 또는 mysql, php8.3-fpm

# 2) 에러 로그 확인
sudo journalctl -u nginx -n 50 --no-pager

# 3) 설정 파일 문법 오류 확인 (Nginx인 경우)
sudo nginx -t

# 4) 수동 재시작
sudo systemctl restart nginx

# 5) 장애 이력 확인
mysql -u srvadmin -p server_mgmt -e \
  "SELECT * FROM incident_log ORDER BY occurred_at DESC LIMIT 10;"
```

---

## 2. 디스크 용량 부족 (90% 이상)

```bash
# 1) 용량 큰 디렉토리 확인
sudo du -sh /var/log/* | sort -rh | head -10
sudo du -sh ~/backups/* | sort -rh | head -10

# 2) 오래된 로그 정리
sudo journalctl --vacuum-time=7d

# 3) 30일 이상 백업 수동 삭제 (긴급 시)
find ~/backups -name "*.gz" -mtime +30 -delete
```

---

## 3. CPU/메모리 과부하 (80% 이상 지속)

```bash
# 1) 리소스 많이 쓰는 프로세스 확인
top -o %CPU
top -o %MEM

# 2) 비정상 프로세스 종료
sudo kill -9 [PID]

# 3) 모니터링 이력으로 발생 시점 파악
mysql -u srvadmin -p server_mgmt -e \
  "SELECT * FROM monitor_log WHERE status='경고' ORDER BY log_time DESC LIMIT 10;"
```

---

## 4. SSH 무차별 공격(Brute-force) 의심

**증상**: auth.log에 특정 IP의 Failed password 다수 발생

```bash
# 1) 공격 IP 확인
sudo grep "Failed password" /var/log/auth.log | \
  awk '{print $11}' | sort | uniq -c | sort -rn | head -5

# 2) UFW로 해당 IP 차단
sudo ufw deny from [공격자IP]

# 3) 차단 확인
sudo ufw status numbered
```

---

## 5. 웹사이트 접속 불가 (504/502 에러)

```bash
# 1) PHP-FPM 상태 확인 (502의 주요 원인)
sudo systemctl status php8.3-fpm

# 2) Nginx 에러 로그 확인
sudo tail -30 /var/log/nginx/portfolio-error.log

# 3) PHP-FPM 재시작
sudo systemctl restart php8.3-fpm
sudo systemctl reload nginx
```

---

## 6. DB 접속 불가

```bash
# 1) MySQL 상태 확인
sudo systemctl status mysql

# 2) 접속 테스트
mysql -u srvadmin -p server_mgmt -e "SELECT 1;"

# 3) 권한 문제 시 재부여
sudo mysql -u root -p
GRANT ALL PRIVILEGES ON server_mgmt.* TO 'srvadmin'@'localhost';
FLUSH PRIVILEGES;
```

---

## 7. 에스컬레이션 기준

| 상황 | 대응 |
|------|------|
| 자동복구 3회 실패 | 수동 점검 + incident_log 기록 확인 |
| 디스크 95% 이상 | 즉시 정리 + 증설 검토 |
| 동일 IP 50회 이상 로그인 실패 | 즉시 IP 차단 |
| DB 데이터 손상 의심 | 백업에서 즉시 복구, 원본 보존 |
