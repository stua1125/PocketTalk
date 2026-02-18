-- Users
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    nickname        VARCHAR(50) UNIQUE NOT NULL,
    avatar_url      VARCHAR(500),
    chip_balance    BIGINT NOT NULL DEFAULT 10000,
    daily_reward_at TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Rooms
CREATE TABLE rooms (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(100) NOT NULL,
    owner_id        UUID NOT NULL REFERENCES users(id),
    max_players     SMALLINT NOT NULL DEFAULT 6 CHECK (max_players BETWEEN 2 AND 9),
    small_blind     BIGINT NOT NULL DEFAULT 10,
    big_blind       BIGINT NOT NULL DEFAULT 20,
    buy_in_min      BIGINT NOT NULL DEFAULT 400,
    buy_in_max      BIGINT NOT NULL DEFAULT 2000,
    status          VARCHAR(20) NOT NULL DEFAULT 'WAITING',
    invite_code     VARCHAR(8) UNIQUE,
    auto_start_delay INT NOT NULL DEFAULT 30,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_rooms_invite_code ON rooms(invite_code);

-- Room Players
CREATE TABLE room_players (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id         UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id),
    seat_number     SMALLINT NOT NULL CHECK (seat_number >= 0),
    chip_count      BIGINT NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(room_id, user_id),
    UNIQUE(room_id, seat_number)
);

-- Hands
CREATE TABLE hands (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id         UUID NOT NULL REFERENCES rooms(id),
    hand_number     BIGINT NOT NULL,
    dealer_seat     SMALLINT NOT NULL,
    small_blind_amt BIGINT NOT NULL,
    big_blind_amt   BIGINT NOT NULL,
    community_cards VARCHAR(20),
    pot_total       BIGINT NOT NULL DEFAULT 0,
    state           VARCHAR(20) NOT NULL DEFAULT 'PRE_FLOP',
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    UNIQUE(room_id, hand_number)
);

CREATE INDEX idx_hands_room_state ON hands(room_id, state);

-- Hand Players
CREATE TABLE hand_players (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hand_id         UUID NOT NULL REFERENCES hands(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id),
    seat_number     SMALLINT NOT NULL,
    hole_cards      VARCHAR(6),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    bet_total       BIGINT NOT NULL DEFAULT 0,
    won_amount      BIGINT NOT NULL DEFAULT 0,
    best_hand_rank  VARCHAR(30),
    best_hand_cards VARCHAR(14),
    UNIQUE(hand_id, user_id)
);

-- Hand Actions
CREATE TABLE hand_actions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hand_id         UUID NOT NULL REFERENCES hands(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id),
    action_type     VARCHAR(20) NOT NULL,
    amount          BIGINT DEFAULT 0,
    hand_state      VARCHAR(20) NOT NULL,
    sequence_num    INT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hand_actions_hand ON hand_actions(hand_id, sequence_num);

-- Chat Messages
CREATE TABLE chat_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id         UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id),
    hand_id         UUID REFERENCES hands(id),
    content         TEXT NOT NULL,
    message_type    VARCHAR(20) NOT NULL DEFAULT 'TEXT',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_room_time ON chat_messages(room_id, created_at DESC);

-- Transactions (Wallet)
CREATE TABLE transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    type            VARCHAR(30) NOT NULL,
    amount          BIGINT NOT NULL,
    balance_after   BIGINT NOT NULL,
    reference_id    UUID,
    description     VARCHAR(200),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_user ON transactions(user_id, created_at DESC);

-- Device Tokens (FCM)
CREATE TABLE device_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    token           VARCHAR(500) NOT NULL,
    platform        VARCHAR(10) NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, token)
);
