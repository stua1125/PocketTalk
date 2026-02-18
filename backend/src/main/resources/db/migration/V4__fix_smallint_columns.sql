-- Fix SMALLINT columns to INTEGER for Hibernate compatibility
ALTER TABLE room_players ALTER COLUMN seat_number TYPE INTEGER;
ALTER TABLE hand_players ALTER COLUMN seat_number TYPE INTEGER;
ALTER TABLE hands ALTER COLUMN dealer_seat TYPE INTEGER;
ALTER TABLE rooms ALTER COLUMN max_players TYPE INTEGER;
