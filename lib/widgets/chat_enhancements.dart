import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

/// Emojis rapides proposés pour les réactions aux messages
const List<String> kQuickReactions = ['👍', '❤️', '🔥', '🎾', '😂', '👏'];

/// Rangée de pilules de réactions affichées sous une bulle de message
class ChatReactionsRow extends StatelessWidget {
  final Map<String, dynamic>? reactions;
  final String currentUserId;
  final Function(String emoji) onReactionTapped;
  final bool isMe;

  const ChatReactionsRow({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTapped,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions == null || reactions!.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeReactions = <String, int>{};
    final userReactedMap = <String, bool>{};

    reactions!.forEach((emoji, users) {
      if (users is List && users.isNotEmpty) {
        activeReactions[emoji] = users.length;
        userReactedMap[emoji] = users.contains(currentUserId);
      }
    });

    if (activeReactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: activeReactions.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value;
          final didUserReact = userReactedMap[emoji] ?? false;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onReactionTapped(emoji);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: didUserReact
                    ? AppColors.gold.withValues(alpha: 0.3)
                    : const Color(0xFF1E293B).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: didUserReact
                      ? AppColors.gold
                      : Colors.white.withValues(alpha: 0.2),
                  width: didUserReact ? 1.2 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      color: didUserReact ? AppColors.gold : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Aperçu d'un message cité à l'intérieur d'une bulle de message
class QuotedMessagePreview extends StatelessWidget {
  final Map<String, dynamic>? replyTo;
  final bool isMe;

  const QuotedMessagePreview({
    super.key,
    required this.replyTo,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (replyTo == null) return const SizedBox.shrink();

    final senderName = replyTo!['senderName'] as String? ?? 'Message';
    final text = replyTo!['text'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? AppColors.gold : AppColors.coral,
            width: 3.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName,
            style: TextStyle(
              color: isMe ? AppColors.gold : AppColors.coral,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            text.isNotEmpty ? text : '📷 Photo',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Bandeau au-dessus de la zone de saisie lorsqu'une réponse est active
class ActiveReplyBanner extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final VoidCallback onCancel;

  const ActiveReplyBanner({
    super.key,
    required this.replyTo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = replyTo['senderName'] as String? ?? 'Message';
    final text = replyTo['text'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16253B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          left: const BorderSide(color: AppColors.gold, width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Réponse à $senderName",
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  text.isNotEmpty ? text : '📷 Photo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Modal moderne d'actions au long-press sur un message (Réactions WhatsApp, Répondre, Copier, Supprimer)
class ChatMessageActionsModal extends StatelessWidget {
  final String text;
  final String senderName;
  final bool isMe;
  final Function(String emoji) onReactionSelected;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  const ChatMessageActionsModal({
    super.key,
    required this.text,
    required this.senderName,
    required this.isMe,
    required this.onReactionSelected,
    required this.onReply,
    this.onDelete,
  });

  static void show(
    BuildContext context, {
    required String text,
    required String senderName,
    required bool isMe,
    required Function(String emoji) onReactionSelected,
    required VoidCallback onReply,
    VoidCallback? onDelete,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatMessageActionsModal(
        text: text,
        senderName: senderName,
        isMe: isMe,
        onReactionSelected: onReactionSelected,
        onReply: onReply,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF121E2F).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barre horizontale des réactions emojis style WhatsApp
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2D44),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: kQuickReactions.map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                          onReactionSelected(emoji);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Option Répondre
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.reply_rounded, color: AppColors.gold, size: 20),
                  ),
                  title: const Text("Répondre", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("Citer ce message de $senderName", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    onReply();
                  },
                ),

                // Option Copier le texte
                if (text.isNotEmpty)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                    ),
                    title: const Text("Copier le texte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Message copié dans le presse-papier"),
                          duration: Duration(seconds: 2),
                          backgroundColor: Color(0xFF1E293B),
                        ),
                      );
                    },
                  ),

                // Option Supprimer (si auteur)
                if (isMe && onDelete != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    ),
                    title: const Text("Supprimer le message", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      onDelete!();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
