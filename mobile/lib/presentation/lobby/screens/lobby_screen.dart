import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/chip_display.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/skeleton_loader.dart';
import '../providers/lobby_provider.dart';
import '../widgets/room_card.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    // Load rooms only when authenticated
    Future.microtask(() {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.authenticated) {
        ref.read(lobbyProvider.notifier).loadRooms();
      }
    });
  }

  void _showJoinByCodeDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Join by Code',
          style: AppTypography.headline3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the invite code to join a room.',
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.body1.copyWith(
                color: AppColors.textPrimary,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. ABC123',
                hintStyle: AppTypography.body1.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                prefixIcon: const Icon(
                  Icons.vpn_key_outlined,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.button.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              Navigator.of(context).pop();
              _joinByCode(code);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinByCode(String code) async {
    try {
      final room = await ref.read(lobbyProvider.notifier).joinByCode(
            code,
            0, // default seat, server will assign
            500, // default buy-in
          );
      if (mounted) {
        context.go('/game/${room.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobbyState = ref.watch(lobbyProvider);
    final authState = ref.watch(authProvider);

    // Load rooms when auth state becomes authenticated (handles race conditions).
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        ref.read(lobbyProvider.notifier).loadRooms();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.casino, color: AppColors.primary, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'PocketTalk',
              style: AppTypography.headline3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Chip balance
          if (authState.user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Center(
                child: ChipDisplay(
                  amount: authState.user!.chipBalance,
                  fontSize: 14,
                ),
              ),
            ),
          // Profile button
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.textPrimary),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => ref.read(lobbyProvider.notifier).loadRooms(),
              child: _buildBody(lobbyState),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-room'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Create Room',
          style: AppTypography.button.copyWith(color: Colors.white),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody(LobbyState lobbyState) {
    // Error state
    if (lobbyState.error != null && lobbyState.rooms.isEmpty) {
      return _buildErrorState(lobbyState.error!);
    }

    // Loading state (only show full-screen loader on initial load)
    if (lobbyState.isLoading && lobbyState.rooms.isEmpty) {
      return _buildSkeletonList();
    }

    // Empty state
    if (!lobbyState.isLoading && lobbyState.rooms.isEmpty) {
      return EmptyState.noRooms(
        onAction: () => context.go('/create-room'),
      );
    }

    // Room list
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100, // extra bottom padding for FAB
      ),
      itemCount: lobbyState.rooms.length,
      itemBuilder: (context, index) {
        final room = lobbyState.rooms[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: RoomCard(
            room: room,
            onTap: () => context.go('/game/${room.id}'),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100,
      ),
      itemCount: 5,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: SkeletonCard(),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error.withOpacity(0.7),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Something went wrong',
                style: AppTypography.headline3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                error,
                textAlign: TextAlign.center,
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () => ref.read(lobbyProvider.notifier).loadRooms(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _showJoinByCodeDialog,
          icon: const Icon(Icons.vpn_key_outlined),
          label: Text(
            'Join by Code',
            style: AppTypography.button.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            side: const BorderSide(color: AppColors.primaryLight),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
