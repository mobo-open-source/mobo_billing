import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/session_service.dart';
import '../services/odoo_session_manager.dart';
import '../screens/login/add_account_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/login/totp_page.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/custom_snackbar.dart';

class SwitchAccountWidget extends StatelessWidget {
  const SwitchAccountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final subtitleColor = isDark ? Colors.white38 : Colors.black38;

    return Consumer<SessionService>(
      builder: (context, sessionService, child) {
        final currentSession = sessionService.currentSession;

        final otherAccounts = sessionService.storedAccounts.where((account) {
          return !_isCurrentAccount(account, sessionService);
        }).toList();
        final accountCount = otherAccounts.length;

        return ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedUserSwitch,
            color: iconColor,
          ),
          trailing: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: iconColor,
            size: 20,
          ),
          title: const Text(
            'Switch Accounts',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            accountCount > 0
                ? '$accountCount other account${accountCount != 1 ? 's' : ''} available'
                : 'Add multiple accounts to switch quickly',
            style: TextStyle(color: subtitleColor, fontSize: 12),
          ),
          children: [
            if (accountCount == 0)
              _buildEmptyState(context)
            else
              ...otherAccounts.map(
                (account) =>
                    _buildAccountTile(context, account, sessionService),
              ),
            _buildAddAccountButton(context),
          ],
        );
      },
    );
  }

  bool _isCurrentAccount(
    Map<String, dynamic> account,
    SessionService sessionService,
  ) {
    final current = sessionService.currentSession;
    if (current == null) return false;

    final accountUserId = account['userId']?.toString();
    final currentUserId = current.userId?.toString();
    final accountServerUrl = account['serverUrl']?.toString();
    final currentServerUrl = current.serverUrl?.toString();
    final accountDatabase = account['database']?.toString();
    final currentDatabase = current.database?.toString();
    final accountUserLogin = account['userLogin']?.toString();
    final currentUserLogin = current.userLogin?.toString();

    if (accountUserId != null &&
        accountUserId.isNotEmpty &&
        currentUserId != null &&
        currentUserId.isNotEmpty) {
      final isMatch =
          accountUserId == currentUserId &&
          accountServerUrl == currentServerUrl &&
          accountDatabase == currentDatabase;

      return isMatch;
    }

    final isMatch =
        accountServerUrl == currentServerUrl &&
        accountDatabase == currentDatabase &&
        accountUserLogin == currentUserLogin;

    return isMatch;
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUserSwitch,
            color: isDark ? Colors.white10 : Colors.black12,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No other accounts stored. Add another account to quickly switch between them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildUserAvatar(account, isDark),
        title: Text(
          account['userName'] ?? account['userLogin'] ?? 'Unknown User',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${account['userLogin']} @ ${account['database']}',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            if (account['needsReauth']?.toString() == 'true' ||
                account['password']?.toString().isEmpty == true)
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: Colors.orange[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Needs re-authentication',
                    style: TextStyle(
                      color: Colors.orange[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            size: 18,
          ),
          onSelected: (value) async {
            if (value == 'remove') {
              await _confirmRemoveAccount(context, account, sessionService);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Remove',
                    style: TextStyle(color: Colors.red[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _switchAccount(context, account, sessionService),
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> account, bool isDark) {
    final serverUrl = account['serverUrl'] as String?;
    final userId = account['userId'];
    final imageBase64 = account['imageBase64'] as String?;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: ClipOval(
        child: _buildAvatarImage(serverUrl, userId, imageBase64, isDark),
      ),
    );
  }

  Widget _buildAvatarImage(
    String? serverUrl,
    dynamic userId,
    String? imageBase64,
    bool isDark,
  ) {
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        var raw = imageBase64.trim();
        final dataUrlPrefix = RegExp(r'^data:image\/[a-zA-Z0-9.+-]+;base64,');
        raw = raw.replaceFirst(dataUrlPrefix, '');
        final clean = raw.replaceAll(RegExp(r'\s+'), '');
        if (clean.isNotEmpty) {
          final bytes = const Base64Decoder().convert(clean);
          if (_looksLikeImage(bytes)) {
            return Image.memory(bytes, fit: BoxFit.cover);
          }
        }
      } catch (_) {}
    }

    if (serverUrl != null && userId != null) {
      final avatarUrl =
          '$serverUrl/web/image?model=res.users&id=$userId&field=image_128';
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultAvatar(isDark),
        errorWidget: (context, url, error) => _buildDefaultAvatar(isDark),
      );
    }

    return _buildDefaultAvatar(isDark);
  }

  bool _looksLikeImage(List<int> bytes) {
    if (bytes.length < 4) return false;
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47)
      return true;
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50)
      return true;
    return false;
  }

  Widget _buildDefaultAvatar(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedUser,
        size: 20,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }

  Widget _buildAddAccountButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 16,
        top: 8,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddAccountScreen()),
            );
          },
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedUserAdd01,
            size: 18,
          ),
          label: const Text('Add Account'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Future<void> _switchAccount(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final password = await sessionService.getStoredPassword(account);

    if (password == null ||
        account['needsReauth']?.toString() == 'true' ||
        account['password']?.toString().isEmpty == true) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              serverUrl: account['serverUrl'],
              database: account['database'],
            ),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Switching Account...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final storedSessionId = account['sessionId']?.toString();
      if (storedSessionId != null &&
          storedSessionId.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        final reused = await OdooSessionManager.loginWithSessionId(
          serverUrl: (account['serverUrl'] ?? '').toString(),
          database: (account['database'] ?? '').toString(),
          userLogin: (account['userLogin'] ?? '').toString(),
          password: password,
          sessionId: storedSessionId,
        );
        if (reused) {
          final session = await OdooSessionManager.getCurrentSession();
          if (session != null) {
            await sessionService.switchToAccount(session);
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.pop(context);
            }
            return;
          }
        }
      }

      final newSession = await OdooSessionManager.authenticate(
        serverUrl: account['serverUrl'],
        database: account['database'],
        username: account['userLogin'],
        password: password,
      );

      if (newSession == null) {
        throw Exception('Authentication failed');
      }

      await sessionService.switchToAccount(newSession);

      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        String errorTitle = 'Switch Failed';
        String errorMessage = e.toString();
        final errorLower = errorMessage.toLowerCase();

        if (errorLower.contains('two factor') ||
            errorLower.contains('2fa') ||
            errorLower.contains('totp')) {
          final srv = (account['serverUrl'] ?? '').toString();
          final protocol = srv.startsWith('https') ? 'https://' : 'http://';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TotpPage(
                serverUrl: account['serverUrl'],
                database: account['database'],
                username: account['userLogin'],
                password: password ?? '',
                protocol: protocol,
                isAddingAccount: false,
              ),
            ),
          );
          return;
        }

        if (errorLower.contains('html instead of json') ||
            errorLower.contains('404') ||
            errorLower.contains('socketexception') ||
            errorLower.contains('connection refused') ||
            errorLower.contains('failed host lookup') ||
            errorLower.contains('timeout')) {
          errorTitle = 'Connection Error';
          errorMessage =
              'Unable to connect to the server. Please check your internet connection or the server URL.';
        }

        _showErrorDialog(context, errorTitle, errorMessage);
      }

      if (e.toString().toLowerCase().contains('authentication') ||
          e.toString().toLowerCase().contains('password')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              serverUrl: account['serverUrl'],
              database: account['database'],
            ),
          ),
        );
      }
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: isDark ? 0 : 3,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveAccount(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Account',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Are you sure you want to remove the account for ${account['userLogin']}?',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: isDark ? 0 : 3,
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await sessionService.removeStoredAccount(account);
      if (context.mounted) {
        CustomSnackbar.showSuccess(
          context,
          'Account ${account['userLogin']} removed',
        );
      }
    }
  }
}
