import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/room.dart';
import '../providers/room_provider.dart';

/// Dialog for joining a room by invite code.
/// Call [showJoinByCodeDialog] for invite-code entry, or
/// [showDirectJoinDialog] when the user taps a known room card.
class JoinRoomDialog extends ConsumerStatefulWidget {
  /// When non-null the dialog shows "Direct Join" mode (room already known).
  final Room? room;

  const JoinRoomDialog({super.key, this.room});

  @override
  ConsumerState<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<JoinRoomDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _codeController = TextEditingController();
  final _buyInController = TextEditingController();
  int _selectedSeat = -1;

  bool get _isDirectJoin => widget.room != null;
  Room? get _room => widget.room;

  int get _maxSeat => (_room?.maxPlayers ?? 9) - 1;
  int get _buyInMin => _room?.buyInMin ?? 1;
  int get _buyInMax => _room?.buyInMax ?? 10000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _isDirectJoin ? 1 : 2,
      vsync: this,
    );
    if (_room != null) {
      _buyInController.text = _room!.buyInMin.toString();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _buyInController.dispose();
    super.dispose();
  }

  void _handleJoin() {
    final buyIn = int.tryParse(_buyInController.text) ?? 0;
    if (buyIn <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid buy-in amount'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_isDirectJoin) {
      ref.read(joinRoomProvider.notifier).joinRoom(
            roomId: _room!.id,
            seatNumber: _selectedSeat,
            buyInAmount: buyIn,
          );
    } else {
      final code = _codeController.text.trim();
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter an invite code'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      ref.read(joinRoomProvider.notifier).joinByCode(
            inviteCode: code,
            seatNumber: _selectedSeat,
            buyInAmount: buyIn,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final joinState = ref.watch(joinRoomProvider);

    ref.listen<JoinRoomState>(joinRoomProvider, (previous, next) {
      if (next.joinedRoom != null) {
        final roomId = next.joinedRoom!.id;
        ref.read(joinRoomProvider.notifier).reset();
        Navigator.of(context).pop();
        context.go('/game/$roomId');
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isDirectJoin
                        ? 'Join ${_room!.name}'
                        : 'Join Room',
                    style: AppTypography.headline3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Tab bar (only for invite-code mode)
              if (!_isDirectJoin) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: AppTypography.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    dividerHeight: 0,
                    tabs: const [
                      Tab(text: 'Invite Code'),
                      Tab(text: 'Room ID'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Content
              if (_isDirectJoin)
                _buildJoinForm(joinState)
              else
                SizedBox(
                  height: 320,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInviteCodeTab(joinState),
                      _buildDirectIdTab(joinState),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCodeTab(JoinRoomState joinState) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invite Code',
            style: AppTypography.body2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              hintText: 'Enter invite code',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSeatPicker(),
          const SizedBox(height: AppSpacing.md),
          _buildBuyInField(),
          const SizedBox(height: AppSpacing.lg),
          _buildJoinButton(joinState),
        ],
      ),
    );
  }

  Widget _buildDirectIdTab(JoinRoomState joinState) {
    final idController = TextEditingController();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Room ID',
            style: AppTypography.body2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: idController,
            decoration: const InputDecoration(
              hintText: 'Enter room ID',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSeatPicker(),
          const SizedBox(height: AppSpacing.md),
          _buildBuyInField(),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: joinState.isLoading
                ? null
                : () {
                    final roomId = idController.text.trim();
                    final buyIn = int.tryParse(_buyInController.text) ?? 0;
                    if (roomId.isEmpty || buyIn <= 0) return;
                    ref.read(joinRoomProvider.notifier).joinRoom(
                          roomId: roomId,
                          seatNumber: _selectedSeat,
                          buyInAmount: buyIn,
                        );
                  },
            child: joinState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinForm(JoinRoomState joinState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Room info summary
        if (_room != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Blinds ${_room!.smallBlind}/${_room!.bigBlind}  |  '
                    'Buy-in ${_room!.buyInMin}-${_room!.buyInMax}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _buildSeatPicker(),
        const SizedBox(height: AppSpacing.md),
        _buildBuyInField(),
        const SizedBox(height: AppSpacing.lg),
        _buildJoinButton(joinState),
      ],
    );
  }

  Widget _buildSeatPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Seat',
          style: AppTypography.body2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _maxSeat + 1,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final isOccupied = _room?.players
                      .any((p) => p.seatNumber == index) ??
                  false;
              final isSelected = _selectedSeat == index;
              return GestureDetector(
                onTap: isOccupied
                    ? null
                    : () => setState(() => _selectedSeat = index),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? AppColors.surfaceLight.withOpacity(0.3)
                        : isSelected
                            ? AppColors.primary
                            : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected && !isOccupied
                        ? Border.all(color: AppColors.primaryLight, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: AppTypography.body1.copyWith(
                      color: isOccupied
                          ? AppColors.textSecondary.withOpacity(0.4)
                          : isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_room != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '${_room!.currentPlayers}/${_room!.maxPlayers} seats taken',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBuyInField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buy-in Amount',
          style: AppTypography.body2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _buyInController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: _room != null
                ? '${_room!.buyInMin} - ${_room!.buyInMax}'
                : 'Enter amount',
            prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
          ),
        ),
        if (_room != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Range: $_buyInMin - $_buyInMax chips',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildJoinButton(JoinRoomState joinState) {
    return ElevatedButton(
      onPressed: joinState.isLoading ? null : _handleJoin,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: joinState.isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              'Join',
              style: AppTypography.button.copyWith(color: Colors.white),
            ),
    );
  }
}

// ── Convenience functions ──

/// Shows the join-room dialog in invite-code mode (no room context).
Future<void> showJoinByCodeDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const JoinRoomDialog(),
  );
}

/// Shows the join-room dialog in direct-join mode for a known [room].
Future<void> showDirectJoinDialog(BuildContext context, Room room) {
  return showDialog(
    context: context,
    builder: (_) => JoinRoomDialog(room: room),
  );
}
