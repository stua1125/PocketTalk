package com.pockettalk.game.controller;

import com.pockettalk.common.dto.ApiResponse;
import com.pockettalk.game.dto.*;
import com.pockettalk.game.service.RoomService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/rooms")
@RequiredArgsConstructor
public class RoomController {

    private final RoomService roomService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<RoomResponse> createRoom(@Valid @RequestBody CreateRoomRequest request) {
        UUID userId = getCurrentUserId();
        RoomResponse room = roomService.createRoom(userId, request);
        return ApiResponse.ok(room);
    }

    @GetMapping
    public ApiResponse<List<RoomResponse>> getMyRooms() {
        UUID userId = getCurrentUserId();
        List<RoomResponse> rooms = roomService.getMyRooms(userId);
        return ApiResponse.ok(rooms);
    }

    @GetMapping("/{roomId}")
    public ApiResponse<RoomResponse> getRoom(@PathVariable UUID roomId) {
        RoomResponse room = roomService.getRoom(roomId);
        return ApiResponse.ok(room);
    }

    @PutMapping("/{roomId}")
    public ApiResponse<RoomResponse> updateRoom(
            @PathVariable UUID roomId,
            @Valid @RequestBody UpdateRoomRequest request) {
        UUID userId = getCurrentUserId();
        RoomResponse room = roomService.updateRoom(roomId, userId, request);
        return ApiResponse.ok(room);
    }

    @DeleteMapping("/{roomId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteRoom(@PathVariable UUID roomId) {
        UUID userId = getCurrentUserId();
        roomService.deleteRoom(roomId, userId);
    }

    @PostMapping("/{roomId}/join")
    public ApiResponse<RoomResponse> joinRoom(
            @PathVariable UUID roomId,
            @Valid @RequestBody JoinRoomRequest request) {
        UUID userId = getCurrentUserId();
        RoomResponse room = roomService.joinRoom(roomId, userId, request);
        return ApiResponse.ok(room);
    }

    @PostMapping("/{roomId}/leave")
    public ApiResponse<Void> leaveRoom(@PathVariable UUID roomId) {
        UUID userId = getCurrentUserId();
        roomService.leaveRoom(roomId, userId);
        return ApiResponse.ok(null, "Left room successfully");
    }

    @PostMapping("/join-by-code")
    public ApiResponse<RoomResponse> joinByCode(@Valid @RequestBody JoinByCodeRequest request) {
        UUID userId = getCurrentUserId();
        RoomResponse room = roomService.joinByCode(userId, request);
        return ApiResponse.ok(room);
    }

    private UUID getCurrentUserId() {
        return UUID.fromString(
            SecurityContextHolder.getContext().getAuthentication().getName());
    }
}
