-- Performance indexes for PocketTalk
-- Optimizes common query patterns: hand lookups, player lookups, action history

-- Hand players: speed up lookups by hand_id (used in every toHandResponse call)
CREATE INDEX IF NOT EXISTS idx_hand_players_hand_id ON hand_players(hand_id);

-- Hand players: speed up lookups by user_id (used in isPlayerInActiveHand)
CREATE INDEX IF NOT EXISTS idx_hand_players_user_id ON hand_players(user_id);

-- Hand actions: composite index for ordered action retrieval per hand
-- Note: V1 created idx_hand_actions_hand on the same columns; this is a named alias for clarity
CREATE INDEX IF NOT EXISTS idx_hand_actions_hand_id_seq ON hand_actions(hand_id, sequence_num);

-- Rooms: index on status for filtering (may already exist from V1)
CREATE INDEX IF NOT EXISTS idx_rooms_status ON rooms(status);

-- Hands: composite index for room hand history sorted by hand number descending
CREATE INDEX IF NOT EXISTS idx_hands_room_id_number ON hands(room_id, hand_number DESC);

-- Transactions: composite index for user transaction history sorted by date
CREATE INDEX IF NOT EXISTS idx_transactions_user_id_created ON transactions(user_id, created_at DESC);

-- Chat messages: composite index for room chat history sorted by date
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id_created ON chat_messages(room_id, created_at DESC);
