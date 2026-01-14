import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';

class ConversationTile extends StatelessWidget {
  final User user;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.user,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(user.username[0].toUpperCase()),
      ),
      title: Text(user.username),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.lastMessageSent != null)
            Text(
              user.lastMessageSent!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            'Last message sent: ${user.lastMessageSent ?? "None"}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (user.lastSeen != null)
            Text(
              DateFormat('HH:mm').format(user.lastSeen!),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          const SizedBox(height: 4),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: user.onlineStatus ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
