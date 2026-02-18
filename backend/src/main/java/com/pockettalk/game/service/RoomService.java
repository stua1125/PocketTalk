package com.pockettalk.game.service;

import com.pockettalk.auth.entity.User;
import com.pockettalk.auth.repository.UserRepository;
import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.game.dto.*;
import com.pockettalk.game.entity.Room;
import com.pockettalk.game.entity.RoomPlayer;
import com.pockettalk.game.repository.HandRepository;
import com.pockettalk.game.repository.RoomPlayerRepository;
import com.pockettalk.game.repository.RoomRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class RoomService {

    private static final String ACTIVE = "ACTIVE";
    private static final String WAITING = "WAITING";
    private static final String PLAYING = "PLAYING";
    private static final String CLOSED = "CLOSED";
    private static final String LEFT = "LEFT";
    private static final String INVITE_CODE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    private static final int INVITE_CODE_LENGTH = 6;

    private final RoomRepository roomRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final HandRepository handRepository;
    private final UserRepository userRepository;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public RoomResponse createRoom(UUID userId, CreateRoomRequest request) {
        User owner = findUserOrThrow(userId);

        validateBlindRelationship(request.smallBlind(), request.bigBlind());
        validateBuyInRange(request.buyInMin(), request.buyInMax());

        String inviteCode = generateInviteCode();

        Room room = Room.builder()
            .name(request.name())
            .owner(owner)
            .maxPlayers(request.maxPlayers())
            .smallBlind(request.smallBlind())
            .bigBlind(request.bigBlind())
            .buyInMin(request.buyInMin())
            .buyInMax(request.buyInMax())
            .status(WAITING)
            .inviteCode(inviteCode)
            .build();

        room = roomRepository.save(room);

        return RoomResponse.from(room, List.of());
    }

    @Transactional(readOnly = true)
    public List<RoomResponse> getMyRooms(UUID userId) {
        List<Room> rooms = roomRepository.findRoomsByOwnerOrPlayer(userId);

        return rooms.stream()
            .map(room -> {
                List<RoomPlayer> activePlayers = roomPlayerRepository
                    .findAllByRoomIdAndStatus(room.getId(), ACTIVE);
                return RoomResponse.from(room, activePlayers);
            })
            .toList();
    }

    @Transactional(readOnly = true)
    public RoomResponse getRoom(UUID roomId) {
        Room room = findRoomOrThrow(roomId);
        List<RoomPlayer> activePlayers = roomPlayerRepository
            .findAllByRoomIdAndStatus(room.getId(), ACTIVE);
        return RoomResponse.from(room, activePlayers);
    }

    @Transactional
    public RoomResponse updateRoom(UUID roomId, UUID userId, UpdateRoomRequest request) {
        Room room = findRoomOrThrow(roomId);

        validateOwnership(room, userId);
        validateRoomIsWaiting(room);

        if (request.name() != null) {
            room.setName(request.name());
        }
        if (request.maxPlayers() != null) {
            room.setMaxPlayers(request.maxPlayers());
        }
        if (request.smallBlind() != null) {
            room.setSmallBlind(request.smallBlind());
        }
        if (request.bigBlind() != null) {
            room.setBigBlind(request.bigBlind());
        }
        if (request.buyInMin() != null) {
            room.setBuyInMin(request.buyInMin());
        }
        if (request.buyInMax() != null) {
            room.setBuyInMax(request.buyInMax());
        }

        // Validate final state after applying updates
        validateBlindRelationship(room.getSmallBlind(), room.getBigBlind());
        validateBuyInRange(room.getBuyInMin(), room.getBuyInMax());

        room = roomRepository.save(room);
        List<RoomPlayer> activePlayers = roomPlayerRepository
            .findAllByRoomIdAndStatus(room.getId(), ACTIVE);
        return RoomResponse.from(room, activePlayers);
    }

    @Transactional
    public void deleteRoom(UUID roomId, UUID userId) {
        Room room = findRoomOrThrow(roomId);

        validateOwnership(room, userId);
        validateRoomIsWaiting(room);

        room.setStatus(CLOSED);
        roomRepository.save(room);
    }

    @Transactional
    public RoomResponse joinRoom(UUID roomId, UUID userId, JoinRoomRequest request) {
        Room room = findRoomOrThrow(roomId);

        validateRoomJoinable(room);
        validateNotAlreadyInRoom(roomId, userId);
        validateRoomNotFull(room);
        validateBuyInAmount(room, request.buyInAmount());

        // Auto-assign next available seat if seatNumber < 0
        int seatNumber = request.seatNumber();
        if (seatNumber < 0) {
            seatNumber = findNextAvailableSeat(roomId, room.getMaxPlayers());
        } else {
            validateSeatAvailable(roomId, seatNumber);
        }

        // Pessimistic lock on user for chip deduction
        User user = userRepository.findByIdForUpdate(userId)
            .orElseThrow(() -> new BusinessException(
                "User not found", HttpStatus.NOT_FOUND, "USER_NOT_FOUND"));

        if (user.getChipBalance() < request.buyInAmount()) {
            throw new BusinessException(
                "Insufficient chip balance. Required: " + request.buyInAmount()
                    + ", available: " + user.getChipBalance(),
                HttpStatus.BAD_REQUEST, "INSUFFICIENT_CHIPS");
        }

        // Atomically deduct chips from wallet
        user.setChipBalance(user.getChipBalance() - request.buyInAmount());
        userRepository.save(user);

        // Create room player
        RoomPlayer roomPlayer = RoomPlayer.builder()
            .room(room)
            .user(user)
            .seatNumber(seatNumber)
            .chipCount(request.buyInAmount())
            .status(ACTIVE)
            .build();
        roomPlayerRepository.save(roomPlayer);

        List<RoomPlayer> activePlayers = roomPlayerRepository
            .findAllByRoomIdAndStatus(room.getId(), ACTIVE);
        return RoomResponse.from(room, activePlayers);
    }

    @Transactional
    public void leaveRoom(UUID roomId, UUID userId) {
        Room room = findRoomOrThrow(roomId);

        RoomPlayer roomPlayer = roomPlayerRepository
            .findByRoomIdAndUserIdAndStatus(roomId, userId, ACTIVE)
            .orElseThrow(() -> new BusinessException(
                "You are not an active player in this room",
                HttpStatus.BAD_REQUEST, "NOT_IN_ROOM"));

        // Check if player is in an active hand
        if (handRepository.isPlayerInActiveHand(roomId, userId)) {
            throw new BusinessException(
                "Cannot leave room during an active hand",
                HttpStatus.CONFLICT, "ACTIVE_HAND_IN_PROGRESS");
        }

        // Return remaining chips to user's wallet with pessimistic lock
        User user = userRepository.findByIdForUpdate(userId)
            .orElseThrow(() -> new BusinessException(
                "User not found", HttpStatus.NOT_FOUND, "USER_NOT_FOUND"));

        user.setChipBalance(user.getChipBalance() + roomPlayer.getChipCount());
        userRepository.save(user);

        // Mark player as LEFT
        roomPlayer.setStatus(LEFT);
        roomPlayer.setChipCount(0);
        roomPlayerRepository.save(roomPlayer);
    }

    @Transactional
    public RoomResponse joinByCode(UUID userId, JoinByCodeRequest request) {
        Room room = roomRepository.findByInviteCode(request.inviteCode().toUpperCase().trim())
            .orElseThrow(() -> new BusinessException(
                "Invalid invite code", HttpStatus.NOT_FOUND, "INVALID_INVITE_CODE"));

        JoinRoomRequest joinRequest = new JoinRoomRequest(
            request.seatNumber(), request.buyInAmount());

        return joinRoom(room.getId(), userId, joinRequest);
    }

    // --- Helper Methods ---

    private String generateInviteCode() {
        String code;
        int attempts = 0;
        do {
            if (attempts++ > 100) {
                throw new BusinessException(
                    "Failed to generate unique invite code",
                    HttpStatus.INTERNAL_SERVER_ERROR, "INVITE_CODE_GENERATION_FAILED");
            }
            StringBuilder sb = new StringBuilder(INVITE_CODE_LENGTH);
            for (int i = 0; i < INVITE_CODE_LENGTH; i++) {
                sb.append(INVITE_CODE_CHARS.charAt(
                    secureRandom.nextInt(INVITE_CODE_CHARS.length())));
            }
            code = sb.toString();
        } while (roomRepository.existsByInviteCode(code));

        return code;
    }

    private User findUserOrThrow(UUID userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> new BusinessException(
                "User not found", HttpStatus.NOT_FOUND, "USER_NOT_FOUND"));
    }

    private Room findRoomOrThrow(UUID roomId) {
        return roomRepository.findById(roomId)
            .orElseThrow(() -> new BusinessException(
                "Room not found", HttpStatus.NOT_FOUND, "ROOM_NOT_FOUND"));
    }

    private void validateOwnership(Room room, UUID userId) {
        if (!room.getOwner().getId().equals(userId)) {
            throw new BusinessException(
                "Only the room owner can perform this action",
                HttpStatus.FORBIDDEN, "NOT_ROOM_OWNER");
        }
    }

    private void validateRoomIsWaiting(Room room) {
        if (!WAITING.equals(room.getStatus())) {
            throw new BusinessException(
                "Room can only be modified while in WAITING status",
                HttpStatus.CONFLICT, "ROOM_NOT_WAITING");
        }
    }

    private void validateRoomJoinable(Room room) {
        if (!WAITING.equals(room.getStatus()) && !PLAYING.equals(room.getStatus())) {
            throw new BusinessException(
                "Room is not accepting players. Current status: " + room.getStatus(),
                HttpStatus.CONFLICT, "ROOM_NOT_JOINABLE");
        }
    }

    private void validateNotAlreadyInRoom(UUID roomId, UUID userId) {
        if (roomPlayerRepository.existsByRoomIdAndUserIdAndStatus(roomId, userId, ACTIVE)) {
            throw new BusinessException(
                "You are already in this room",
                HttpStatus.CONFLICT, "ALREADY_IN_ROOM");
        }
    }

    private void validateRoomNotFull(Room room) {
        int currentCount = roomPlayerRepository
            .countByRoomIdAndStatus(room.getId(), ACTIVE);
        if (currentCount >= room.getMaxPlayers()) {
            throw new BusinessException(
                "Room is full (" + currentCount + "/" + room.getMaxPlayers() + ")",
                HttpStatus.CONFLICT, "ROOM_FULL");
        }
    }

    private void validateSeatAvailable(UUID roomId, int seatNumber) {
        if (roomPlayerRepository.existsByRoomIdAndSeatNumberAndStatus(roomId, seatNumber, ACTIVE)) {
            throw new BusinessException(
                "Seat " + seatNumber + " is already taken",
                HttpStatus.CONFLICT, "SEAT_TAKEN");
        }
    }

    /**
     * Find the lowest available seat number (0-based, sequential).
     */
    private int findNextAvailableSeat(UUID roomId, int maxPlayers) {
        List<RoomPlayer> active = roomPlayerRepository.findAllByRoomIdAndStatus(roomId, ACTIVE);
        Set<Integer> takenSeats = new HashSet<>();
        for (RoomPlayer rp : active) {
            takenSeats.add(rp.getSeatNumber());
        }
        for (int i = 0; i < maxPlayers; i++) {
            if (!takenSeats.contains(i)) {
                return i;
            }
        }
        throw new BusinessException("No available seats", HttpStatus.CONFLICT, "NO_SEATS");
    }

    private void validateBuyInAmount(Room room, long buyInAmount) {
        if (buyInAmount < room.getBuyInMin() || buyInAmount > room.getBuyInMax()) {
            throw new BusinessException(
                "Buy-in amount must be between " + room.getBuyInMin()
                    + " and " + room.getBuyInMax(),
                HttpStatus.BAD_REQUEST, "INVALID_BUY_IN");
        }
    }

    private void validateBlindRelationship(long smallBlind, long bigBlind) {
        if (bigBlind != 2 * smallBlind) {
            throw new BusinessException(
                "Big blind must be exactly 2x the small blind",
                HttpStatus.BAD_REQUEST, "INVALID_BLIND_RATIO");
        }
    }

    private void validateBuyInRange(long buyInMin, long buyInMax) {
        if (buyInMax < buyInMin) {
            throw new BusinessException(
                "Maximum buy-in must be greater than or equal to minimum buy-in",
                HttpStatus.BAD_REQUEST, "INVALID_BUY_IN_RANGE");
        }
    }
}
