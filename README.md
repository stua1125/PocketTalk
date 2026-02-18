# PocketTalk

**Async Texas Hold'em Poker Messenger** - 비동기 텍사스 홀덤 포커 메신저 앱

## Overview

PocketTalk은 친구들과 실시간으로 텍사스 홀덤 포커를 플레이할 수 있는 풀스택 모바일/웹 앱입니다.
WebSocket 기반 실시간 통신, 자동 딜링, AFK 감지, 승률 계산 등 완전한 포커 게임 경험을 제공합니다.

### Key Features

- **Texas Hold'em Engine** - 완전한 포커 게임 엔진 (프리플롭 ~ 쇼다운, 사이드 팟, 블라인드 로테이션)
- **Real-time WebSocket** - STOMP 프로토콜 기반 실시간 게임 이벤트 브로드캐스트
- **Auto-Deal** - 핸드 종료 후 5초 뒤 자동으로 다음 핸드 시작 (2명 이상일 때)
- **AFK Detection** - Heartbeat 기반 자리비움 감지, AFK 플레이어 2초 후 자동 폴드
- **Turn Timer** - 10초 턴 타이머, 시간 초과 시 자동 폴드
- **Win Probability** - Monte Carlo 시뮬레이션 기반 실시간 승률 계산
- **In-game Chat** - 실시간 채팅 + 이모지 리액션
- **Wallet System** - 칩 지갑, 입출금, 거래 내역
- **Push Notifications** - FCM 기반 턴 알림 (RabbitMQ 비동기 처리)
- **i18n** - 한국어/영어 다국어 지원

---

## Tech Stack

### Backend

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Spring Boot | 3.4.2 |
| Language | Java | 21 |
| Database | PostgreSQL | 16 |
| Cache | Redis | 7 |
| Message Queue | RabbitMQ | 3 |
| Real-time | WebSocket (STOMP + SockJS) | - |
| Auth | JWT (jjwt 0.12.6) | - |
| Migration | Flyway | - |
| Monitoring | Spring Actuator + Prometheus + Micrometer | - |
| API Docs | SpringDoc OpenAPI (Swagger) | 2.8.4 |
| Build | Gradle (Kotlin DSL) | - |

### Frontend (Mobile/Web)

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Flutter | 3.27+ |
| Language | Dart | 3.5+ |
| State Management | Riverpod 2 | 2.6.1 |
| Routing | GoRouter | 14.8.1 |
| HTTP | Dio | 5.7.0 |
| WebSocket | stomp_dart_client | 2.0.0 |
| Storage | flutter_secure_storage | 9.2.3 |
| Push | firebase_messaging | 15.1.6 |
| i18n | flutter_localizations + intl | 0.20.2 |

### Infrastructure

| Component | Technology |
|-----------|-----------|
| Container | Docker Compose |
| CI/CD | GitHub Actions |
| Platforms | Web (Chrome), iOS, Android |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Client                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Auth    │  │  Lobby   │  │  Game    │  │  Chat/Emoji   │  │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  Overlay      │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬───────┘  │
│       │              │             │                │           │
│  ┌────┴──────────────┴─────────────┴────────────────┴───────┐  │
│  │              Riverpod Providers + GoRouter                │  │
│  └────┬───────────────────────────────┬─────────────────────┘  │
│       │ REST (Dio)                    │ WebSocket (STOMP)      │
└───────┼───────────────────────────────┼─────────────────────────┘
        │                               │
┌───────┼───────────────────────────────┼─────────────────────────┐
│       ▼                               ▼                         │
│  ┌─────────────┐              ┌──────────────┐                  │
│  │  REST API   │              │  STOMP WS    │   Spring Boot    │
│  │  Controllers│              │  Controllers │   Backend        │
│  └──────┬──────┘              └──────┬───────┘                  │
│         │                            │                          │
│  ┌──────┴────────────────────────────┴───────┐                  │
│  │              Service Layer                 │                  │
│  │  ┌────────────┐  ┌──────────────────────┐ │                  │
│  │  │ HandService│  │  TurnTimerService    │ │                  │
│  │  │ RoomService│  │  PlayerPresenceService│ │                  │
│  │  │ AuthService│  │  PushNotificationSvc │ │                  │
│  │  └──────┬─────┘  └──────────────────────┘ │                  │
│  └─────────┼─────────────────────────────────┘                  │
│            │                                                    │
│  ┌─────────┴─────────────────────────────────┐                  │
│  │            Game Engine                     │                  │
│  │  HandManager │ BettingRound │ HandEvaluator│                  │
│  │  PotCalculator │ ShowdownResolver          │                  │
│  └─────────┬─────────────────────────────────┘                  │
│            │                                                    │
│  ┌─────────┼──────────┬──────────┬───────────┐                  │
│  │ PostgreSQL 16      │ Redis 7  │ RabbitMQ  │                  │
│  │ (JPA + Flyway)     │ (Cache)  │ (Push Q)  │                  │
│  └────────────────────┴──────────┴───────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
PocketTalk/
├── backend/                          # Spring Boot API Server
│   ├── src/main/java/com/pockettalk/
│   │   ├── auth/                     # JWT 인증 (login, register, token refresh)
│   │   ├── chat/                     # 실시간 채팅 + 이모지
│   │   ├── common/                   # 공통 모델 (Card, Deck, HandRank, ActionType)
│   │   ├── config/                   # Security, WebSocket, Redis, RabbitMQ 설정
│   │   ├── game/
│   │   │   ├── cache/                # Redis 캐시 (HandCache, OnlineStatus)
│   │   │   ├── controller/           # REST + WebSocket 컨트롤러
│   │   │   ├── dto/                  # Request/Response DTO
│   │   │   ├── engine/               # 포커 엔진 (핵심 로직)
│   │   │   │   ├── HandManager.java      # 핸드 라이프사이클 오케스트레이터
│   │   │   │   ├── BettingRound.java     # 베팅 라운드 상태 관리
│   │   │   │   ├── HandEvaluator.java    # 포커 핸드 평가 (7장 → 최고 5장)
│   │   │   │   ├── PotCalculator.java    # 사이드 팟 계산
│   │   │   │   ├── ShowdownResolver.java # 쇼다운 승자 결정
│   │   │   │   ├── ActionValidator.java  # 액션 유효성 검증
│   │   │   │   └── GameStateMachine.java # 게임 상태 전이
│   │   │   ├── entity/               # JPA 엔티티 (Room, Hand, HandPlayer, HandAction)
│   │   │   ├── event/                # WebSocket 이벤트 발행
│   │   │   ├── repository/           # Spring Data JPA 리포지토리
│   │   │   └── service/              # HandService, RoomService, TurnTimer, Presence
│   │   ├── notification/             # FCM 푸시 알림 (RabbitMQ 비동기)
│   │   ├── probability/              # Monte Carlo 승률 시뮬레이션
│   │   └── wallet/                   # 칩 지갑 시스템
│   ├── src/main/resources/
│   │   ├── application.yml           # 메인 설정
│   │   └── db/migration/             # Flyway SQL 마이그레이션
│   ├── src/test/                     # Unit tests
│   ├── docker-compose.yml            # 개발용 (PostgreSQL, Redis, RabbitMQ)
│   ├── docker-compose.prod.yml       # 프로덕션용
│   └── build.gradle.kts
│
├── mobile/                           # Flutter Client (Web/iOS/Android)
│   ├── lib/
│   │   ├── core/                     # 상수, 라우터, 테마, 유틸리티
│   │   ├── data/datasources/         # API 클라이언트 (Dio, WebSocket, Storage)
│   │   ├── domain/entities/          # 도메인 모델 (Card, Hand, Room, User, Wallet)
│   │   ├── l10n/                     # 다국어 (한국어/영어)
│   │   ├── presentation/
│   │   │   ├── auth/                 # 로그인, 회원가입, 스플래시
│   │   │   ├── chat/                 # 채팅 오버레이, 이모지 피커/애니메이션
│   │   │   ├── common/               # 공통 위젯 (카드, 칩, 아바타, 에러)
│   │   │   ├── game/                 # 게임 화면 (핵심)
│   │   │   │   ├── screens/              # GameScreen
│   │   │   │   ├── widgets/              # PokerTable, PlayerSeat, ActionPanel, ...
│   │   │   │   └── providers/            # GameNotifier, WebSocket, Probability
│   │   │   ├── hand_history/         # 핸드 히스토리 타임라인
│   │   │   ├── lobby/                # 로비 (방 목록, 생성, 참가)
│   │   │   └── wallet/               # 지갑 화면
│   │   └── main.dart
│   └── pubspec.yaml
│
├── .github/workflows/                # CI/CD (backend-ci, mobile-ci, docker-build)
└── docs/                             # 문서
```

---

## Game Policies

### Poker Rules
- **Game Type**: No-Limit Texas Hold'em
- **Players**: 2-6 per table
- **Blinds**: Configurable small/big blind per room
- **Buy-in**: Min/Max configurable per room
- **Dealer Rotation**: Clockwise after each hand

### Turn & AFK Policy
| Condition | Timeout | Action |
|-----------|---------|--------|
| Active player (heartbeat received) | 10 seconds | Auto-fold |
| AFK player (no heartbeat for 15s) | 2 seconds | Immediate auto-fold |
| Hand complete | 5 seconds | Auto-deal next hand |
| Less than 2 active players | - | Game paused |

### Heartbeat System
- Client sends heartbeat every 5 seconds via STOMP WebSocket
- Heartbeats are only sent when user activity is detected (touch/mouse/keyboard)
- If no user activity for 30 seconds, heartbeats stop
- Server considers a player AFK if no heartbeat received for 15 seconds

### Card Visibility
- Hole cards: only visible to the owning player
- Showdown/Settlement: all non-folded players' cards revealed
- Folded players' cards are always hidden

### Chip Management
- Players with 0 chips after settlement are marked as `SITTING_OUT`
- Buy-in amount must be within the room's min/max range
- Seat assignment: auto-sequential (first available seat)

---

## Getting Started

### Prerequisites
- Java 21+
- Flutter 3.27+ / Dart 3.5+
- Docker & Docker Compose

### 1. Start Infrastructure
```bash
cd backend
docker-compose up -d    # PostgreSQL:5433, Redis:6379, RabbitMQ:5672
```

### 2. Start Backend
```bash
cd backend
./gradlew bootRun
# Server starts at http://localhost:8080
# Swagger UI: http://localhost:8080/swagger-ui.html
# Actuator: http://localhost:8080/actuator/health
```

### 3. Start Frontend
```bash
cd mobile
flutter pub get
flutter run -d chrome   # Web
flutter run             # iOS/Android
```

### 4. Play
1. Register an account (or login)
2. Create a room (set blinds, buy-in range)
3. Join with a second account (different browser/incognito)
4. Click "Start Hand" to begin the first hand
5. Subsequent hands auto-deal after 5 seconds

---

## API Endpoints

### Auth
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Login (returns JWT) |
| POST | `/api/v1/auth/refresh` | Refresh access token |
| GET | `/api/v1/auth/me` | Get current user |

### Rooms
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/rooms` | List rooms |
| POST | `/api/v1/rooms` | Create room |
| GET | `/api/v1/rooms/{id}` | Get room details |
| POST | `/api/v1/rooms/{id}/join` | Join room |
| POST | `/api/v1/rooms/join-by-code` | Join by invite code |
| POST | `/api/v1/rooms/{id}/leave` | Leave room |

### Hands
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/rooms/{roomId}/hands/start` | Start new hand |
| GET | `/api/v1/hands/{handId}` | Get hand state |
| POST | `/api/v1/hands/{handId}/actions` | Submit action (FOLD/CHECK/CALL/RAISE/ALL_IN) |
| GET | `/api/v1/hands/{handId}/actions` | Get action history |
| GET | `/api/v1/rooms/{roomId}/hands` | Hand history (paginated) |

### WebSocket (STOMP)
| Destination | Direction | Description |
|-------------|-----------|-------------|
| `/app/room/{roomId}/action` | Client -> Server | Send game action |
| `/app/room/{roomId}/heartbeat` | Client -> Server | Player activity ping |
| `/app/room/{roomId}/chat` | Client -> Server | Send chat message |
| `/app/room/{roomId}/emoji` | Client -> Server | Send emoji reaction |
| `/topic/room/{roomId}/game` | Server -> Client | Game events broadcast |
| `/topic/room/{roomId}/chat` | Server -> Client | Chat messages broadcast |
| `/topic/room/{roomId}/emoji` | Server -> Client | Emoji reactions broadcast |
| `/user/queue/cards` | Server -> Client | Private hole cards |
| `/user/queue/notifications` | Server -> Client | Turn notifications |

---

## Monitoring

- **Health Check**: `GET /actuator/health`
- **Prometheus Metrics**: `GET /actuator/prometheus`
- **RabbitMQ Management**: `http://localhost:15672` (guest/guest)

---

## License

All rights reserved.
