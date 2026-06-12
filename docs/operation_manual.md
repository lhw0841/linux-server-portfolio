# 운영 매뉴얼

## 1. 일일 점검 절차

매일 아침 아래 순서로 점검합니다.

### 1) 자동 생성된 일일 리포트 확인
```bash
cat /var/log/reports/report_$(date '+%Y-%m-%d').txt
```
전날 자정에 자동 생성된 리포트입니다. 서비스 상태, 접속 통계, 오류, SSH 보안, 백업 현황을 한눈에 확인합니다.

### 2) 대시보드 확인
브라우저에서 `https://서버IP` 접속 → 현재 CPU/메모리/디스크 사용률, 최근 모니터링 로그, 장애 이력 확인

### 3) 보안 점검 (주 1회)
```bash
~/projects/linux-server-portfolio/scripts/security_check.sh
```

---

## 2. 서비스 상태 확인

```bash
# 전체 서비스 상태 한 번에 확인
sudo systemctl status nginx mysql php8.3-fpm
```

---

## 3. Cron 작업 확인

```bash
# 등록된 자동화 작업 목록
crontab -l

# 최근 실행 로그 확인
tail -20 /var/log/server_monitor.log
tail -20 /var/log/server_recovery.log
tail -20 /var/log/backup.log
```

---

## 4. 백업 확인 및 복구

### 백업 파일 확인
```bash
ls -lh ~/backups/db/
ls -lh ~/backups/web/
```

### DB 복구
```bash
gunzip -c ~/backups/db/db_server_mgmt_YYYYMMDD_HHMMSS.sql.gz | \
    mysql -u srvadmin -p server_mgmt
```

### 웹파일 복구
```bash
sudo tar -xzf ~/backups/web/web_portfolio_YYYYMMDD_HHMMSS.tar.gz -C /var/www/
```

---

## 5. 수동 점검 명령어 모음

```bash
# 현재 리소스 확인
free -m              # 메모리
df -h                # 디스크
top                   # CPU/프로세스 실시간

# 최근 SSH 접속 기록
sudo tail -20 /var/log/auth.log

# Nginx 접속 로그
sudo tail -50 /var/log/nginx/portfolio-access.log

# 방화벽 상태
sudo ufw status verbose
```
