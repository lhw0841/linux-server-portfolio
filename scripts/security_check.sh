#!/bin/bash
# ================================================
# 서버 보안 설정 점검 스크립트
# 실행: ./security_check.sh
# ================================================

echo "============================"
echo " 서버 보안 설정 점검 결과"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================"

# 1. UFW 방화벽 상태
echo ""
echo"[1] 방화벽 상태"
UFW_STATUS=$(sudo ufw status | grep "Status" | awk '{print $2}')
if [ "$UFW_STATUS" = "active" ]; then
	echo "  ✅ UFW 방화벽 활성화 "
else
	echo "  ❌ UFW 방화벽 비활성화 - 즉시 설정 필요"
fi

# 2. SSH 비밀번호 로그인 차단 여부
echo ""
echo "[2] SSH 보안설정"
PW_AUTH=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
if [ "$PW_AUTH" =  "no" ]; then
	echo "  ✅ SSH 비밀번호 로그인 차단됨"
else
	echo "  ❌ SSH 비밀번호 로그인 허용 중 - 보안 위험"
fi

ROOT_LOGIN=$(grep "^PermitRootLogin" /etc/ssh/ssh_config | awk '{print $2}')
if [ "$ROOT_LOGIN" = "no" ]; then
    echo "  ✅ root 직접 로그인 차단됨"
else
    echo "  ❌ root 로그인 허용 중 - 보안 위험"
fi

# 3. 열린 포트 확인
echo ""
echo "[3] 현재 열린 포트"
sudo ss -tlnp | grep LISTEN | awk '{print "  포트: " $4}'

# 4. 최근 SSH 접속 실패 횟수
echo ""
echo "[4] 최근 SSH 로그인 실패 (상위 5개 IP)"
sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
    awk '{print $11}' | sort | uniq -c | sort -rn | head -5 | \
    awk '{print "  " $2 " → " $1 "회 실패"}'

echo ""
echo "=============================="
echo " 점검 완료"
echo "=============================="



