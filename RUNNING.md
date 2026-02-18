# PocketTalk 실행 및 테스트 가이드

## 목차
1. [사전 준비](#1-사전-준비)
2. [로컬 개발 실행](#2-로컬-개발-실행-개발자용)
3. [프로덕션 Docker 실행](#3-프로덕션-docker-실행-서버-배포)
4. [Flutter 앱 빌드 및 배포](#4-flutter-앱-빌드-및-배포)
5. [다른 사람에게 테스트 전달하기](#5-다른-사람에게-테스트-전달하기)
6. [테스트 시나리오](#6-테스트-시나리오)
7. [트러블슈팅](#7-트러블슈팅)

---

## 1. 사전 준비

### 필수 소프트웨어

| 도구 | 버전 | 용도 |
|------|------|------|
| **Java 21** (Temurin) | 21+ | 백엔드 빌드/실행 |
| **Docker Desktop** | 최신 | PostgreSQL, Redis, RabbitMQ |
| **Flutter** | 3.27+ | 모바일 앱 빌드 |
| **Xcode** | 15+ | iOS 빌드 (macOS만 해당) |
| **Android Studio** | 최신 | Android 빌드 + 에뮬레이터 |

### 설치 확인

```bash
java --version        # 21 이상
docker --version      # Docker 설치 확인
flutter --version     # 3.27 이상
flutter doctor        # 환경 진단
```

---

## 2. 로컬 개발 실행 (개발자용)

### Step 1: 인프라 서비스 시작

```bash
cd backend
docker compose up -d
```

이 명령으로 다음 서비스가 시작됩니다:
- **PostgreSQL** (localhost:5432) - 계정: `pockettalk` / `pockettalk_dev`
- **Redis** (localhost:6379)
- **RabbitMQ** (localhost:5672, 관리UI: localhost:15672) - 계정: `guest` / `guest`

### Step 2: 백엔드 실행

```bash
cd backend
./gradlew bootRun
```

백엔드가 시작되면:
- REST API: http://localhost:8080
- Swagger UI: http://localhost:8080/swagger-ui.html
- Health Check: http://localhost:8080/actuator/health

### Step 3: Flutter 앱 실행

```bash
cd mobile

# 의존성 설치
flutter pub get

# i18n 코드 생성
flutter gen-l10n

# iOS 시뮬레이터에서 실행
flutter run -d iphone

# Android 에뮬레이터에서 실행
flutter run -d android

# 특정 디바이스 확인
flutter devices
```

> **참고**: 기본 설정으로 앱은 `localhost:8080`에 연결합니다.
> 실기기에서 테스트하려면 [4번 섹션](#4-flutter-앱-빌드-및-배포)을 참고하세요.

---

## 3. 프로덕션 Docker 실행 (서버 배포)

외부 서버(AWS, GCP, 온프레미스 등)에 배포하여 여러 사람이 동시 접속할 수 있습니다.

### Step 1: 환경변수 설정

```bash
cd backend
cp .env.example .env
```

`.env` 파일을 열고 비밀번호를 변경합니다:

```env
POSTGRES_PASSWORD=your_strong_postgres_password
RABBITMQ_PASSWORD=your_strong_rabbitmq_password
JWT_SECRET=$(openssl rand -base64 64)
GRAFANA_ADMIN_PASSWORD=your_grafana_password
```

### Step 2: 전체 서비스 빌드 및 실행

```bash
cd backend
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```

6개 서비스가 시작됩니다:

| 서비스 | URL | 용도 |
|--------|-----|------|
| **App** | http://서버IP:8080 | PocketTalk API |
| **Swagger UI** | http://서버IP:8080/swagger-ui.html | API 문서 |
| **RabbitMQ 관리** | http://서버IP:15672 | 메시지 큐 모니터링 |
| **Prometheus** | http://서버IP:9090 | 메트릭 수집 |
| **Grafana** | http://서버IP:3000 | 대시보드 |

### Step 3: 서비스 상태 확인

```bash
# 모든 컨테이너 상태 확인
docker compose -f docker-compose.prod.yml ps

# 앱 헬스체크
curl http://서버IP:8080/actuator/health

# 로그 확인
docker compose -f docker-compose.prod.yml logs -f app
```

---

## 4. Flutter 앱 빌드 및 배포

### 서버 주소 변경 (필수)

실기기나 외부 테스터가 접속하려면 API 서버 주소를 변경해야 합니다.

**`mobile/lib/core/constants/api_constants.dart`** 파일 수정:

```dart
class ApiConstants {
  ApiConstants._();

  // 로컬 개발 (에뮬레이터)
  // static const baseUrl = 'http://localhost:8080';
  // static const wsUrl = 'ws://localhost:8080';

  // 같은 Wi-Fi 네트워크 (Mac IP 주소)
  // static const baseUrl = 'http://192.168.0.XX:8080';
  // static const wsUrl = 'ws://192.168.0.XX:8080';

  // 외부 서버 배포 시
  static const baseUrl = 'http://your-server-ip:8080';
  static const wsUrl = 'ws://your-server-ip:8080';

  // ...
}
```

> **Mac IP 확인**: `ifconfig | grep "inet " | grep -v 127.0.0.1`

### Android APK 빌드

```bash
cd mobile

# Release APK 빌드
flutter build apk --release

# 빌드 결과물
# → build/app/outputs/flutter-apk/app-release.apk
```

**APK 전달 방법:**
- 카카오톡/텔레그램으로 APK 파일 직접 전송
- Google Drive에 업로드 후 링크 공유
- Firebase App Distribution 사용 (권장)

### iOS TestFlight 빌드

```bash
cd mobile

# iOS 빌드
flutter build ios --release

# Xcode에서 Archive → TestFlight 업로드
open ios/Runner.xcworkspace
```

Xcode에서:
1. Product → Archive
2. Distribute App → App Store Connect
3. TestFlight에서 테스터 이메일 초대

### Android 에뮬레이터에서 localhost 접속

Android 에뮬레이터는 `localhost`가 에뮬레이터 자신을 가리킵니다. 호스트 머신 접속 시:

```dart
// Android 에뮬레이터용
static const baseUrl = 'http://10.0.2.2:8080';
static const wsUrl = 'ws://10.0.2.2:8080';
```

---

## 5. 다른 사람에게 테스트 전달하기

### 방법 A: 같은 Wi-Fi (가장 빠름)

테스터가 같은 Wi-Fi에 있는 경우:

1. Mac에서 백엔드 로컬 실행 (Step 2)
2. `api_constants.dart`에서 Mac의 로컬 IP로 변경
3. APK 빌드 후 카카오톡으로 전송
4. 테스터가 APK 설치 후 바로 사용

```
개발자 Mac (192.168.0.10)
    ├── 백엔드 서버 (:8080)
    ├── PostgreSQL (:5432)
    ├── Redis (:6379)
    └── RabbitMQ (:5672)

테스터 A 핸드폰 ──(같은 Wi-Fi)──→ 192.168.0.10:8080
테스터 B 핸드폰 ──(같은 Wi-Fi)──→ 192.168.0.10:8080
```

### 방법 B: 외부 서버 배포 (가장 안정적)

클라우드 서버에 Docker로 배포:

1. AWS EC2 / GCP Compute / NCP 서버 준비 (Ubuntu 22.04, 2vCPU/4GB RAM 이상)
2. Docker 설치: `sudo apt install docker.io docker-compose-plugin`
3. 프로젝트 업로드: `git clone` 또는 `scp`
4. `docker compose -f docker-compose.prod.yml up -d --build`
5. 방화벽에서 8080 포트 오픈
6. `api_constants.dart`에 서버 공인 IP 설정 후 APK 빌드
7. APK를 테스터에게 전송

### 방법 C: ngrok 터널 (임시 테스트)

로컬 서버를 인터넷에 임시 노출:

```bash
# ngrok 설치
brew install ngrok

# 터널 생성
ngrok http 8080
```

ngrok이 제공하는 URL (예: `https://abc123.ngrok-free.app`)을 `api_constants.dart`에 설정:

```dart
static const baseUrl = 'https://abc123.ngrok-free.app';
static const wsUrl = 'wss://abc123.ngrok-free.app';
```

> **주의**: ngrok 무료 플랜은 세션 시간 제한이 있고, URL이 매번 변경됩니다.

### 방법 D: Firebase App Distribution (Android, 권장)

```bash
# Firebase CLI 설치
npm install -g firebase-tools
firebase login

# APK 배포
cd mobile
flutter build apk --release
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_FIREBASE_APP_ID \
  --groups "testers" \
  --release-notes "PocketTalk v1.0 테스트 빌드"
```

테스터는 이메일로 초대를 받고 앱을 바로 설치할 수 있습니다.

---

## 6. 테스트 시나리오

### 기본 플레이 테스트 (2인 이상 필요)

```
1. 각자 회원가입
   → 이메일, 비밀번호(8자 이상), 닉네임 입력

2. 방 만들기 (1명이 생성)
   → 로비 → "방 만들기" → 이름, 블라인드 설정
   → 생성 후 초대 코드 확인

3. 방 참가 (나머지 인원)
   → 로비 → "코드로 참여" → 초대 코드 입력

4. 게임 시작
   → 방장이 "Start Hand" 버튼 탭
   → 각자 홀카드 2장 확인 (비공개)

5. 베팅 라운드 (PRE_FLOP → FLOP → TURN → RIVER)
   → 자기 차례에 Fold / Check / Call / Raise / All In 선택
   → 비동기이므로 타이머 없음 — 여유롭게 진행

6. 쇼다운 & 정산
   → 최종 핸드 비교 → 승자 칩 획득
   → "Deal Next Hand"로 다음 핸드 시작
```

### 기능별 체크리스트

- [ ] **회원가입/로그인**: 이메일 중복 체크, 비밀번호 유효성
- [ ] **방 생성**: 이름, 블라인드(SB/BB), 최대 인원 설정
- [ ] **초대코드**: 방 참가, 유효하지 않은 코드 에러
- [ ] **게임 진행**: 프리플랍→플랍→턴→리버→쇼다운 전체 흐름
- [ ] **채팅**: 게임 중 실시간 채팅 송수신
- [ ] **이모지**: 이모지 반응 전송, 플로팅 애니메이션
- [ ] **지갑**: 잔액 확인, 일일 보상 수령
- [ ] **핸드 히스토리**: 이전 핸드 타임라인 확인
- [ ] **승률 계산기**: 홀카드 보유 시 승률 표시
- [ ] **재접속**: 앱 종료 후 재진입 시 게임 상태 복구
- [ ] **한국어/영어 전환**: 설정에서 언어 토글

---

## 7. 트러블슈팅

### 백엔드가 시작되지 않음

```bash
# Docker 서비스 확인
docker compose ps

# PostgreSQL 연결 확인
docker compose logs postgres

# 포트 충돌 확인
lsof -i :8080
lsof -i :5432
```

### Flutter 앱이 서버에 연결 안 됨

1. **에뮬레이터**: `10.0.2.2:8080` (Android) 또는 `localhost:8080` (iOS)
2. **실기기 (같은 Wi-Fi)**: Mac IP 주소 확인 → `api_constants.dart` 수정
3. **방화벽**: macOS 방화벽에서 8080 포트 허용
4. **서버 상태**: `curl http://서버주소:8080/actuator/health`

### WebSocket 연결 실패

- HTTP → `http://`, WebSocket → `ws://` 프로토콜 확인
- HTTPS 사용 시 `wss://`로 변경
- 프록시/VPN이 WebSocket을 차단하는 경우 해제

### Android APK 설치 실패

- 설정 → 보안 → "출처를 알 수 없는 앱 설치 허용"
- Google Play Protect 경고 → "무시하고 설치"

### iOS 실기기 빌드 실패

```bash
cd mobile/ios
pod install
cd ..
flutter clean
flutter pub get
flutter build ios --release
```

- Xcode에서 Signing & Capabilities → 개인 팀 또는 개발자 계정 설정
- Bundle Identifier 고유값 설정 (예: `com.yourname.pockettalk`)

### DB 초기화 (개발 중 데이터 리셋)

```bash
cd backend
docker compose down -v    # 볼륨 포함 삭제
docker compose up -d      # 새로 시작 (Flyway가 자동 마이그레이션)
```
