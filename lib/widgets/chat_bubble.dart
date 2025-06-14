import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

enum ChatBubbleType {
  sent,
  received,
  system
}

class ChatBubble extends StatelessWidget {
  final String message;
  final ChatBubbleType type;
  final String? senderName;
  final String? senderAvatar;
  final String? time;
  final bool showSender;
  final Color? customColor;
  final Function()? onTap;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.type,
    this.senderName,
    this.senderAvatar,
    this.time,
    this.showSender = false,
    this.customColor,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    switch (type) {
      case ChatBubbleType.system:
        return _buildSystemMessage();
      case ChatBubbleType.sent:
        return _buildSentMessage();
      case ChatBubbleType.received:
        return _buildReceivedMessage();
    }
  }
  
  Widget _buildSystemMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: customColor ?? Colors.black54,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSentMessage() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 2.0,
        bottom: 2.0,
        left: 60.0,
        right: 12.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
              child: Text(
                time!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            
          Flexible(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: customColor ?? AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (customColor ?? AppColors.primary).withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReceivedMessage() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 2.0,
        bottom: 2.0,
        left: 12.0,
        right: 60.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender name
          if (showSender && senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 52.0, bottom: 4.0),
              child: Text(
                senderName!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar
              if (showSender)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    image: senderAvatar != null
                        ? DecorationImage(
                            image: NetworkImage(senderAvatar!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: senderAvatar == null
                      ? const Icon(Icons.person, size: 20, color: Colors.grey)
                      : null,
                )
              else
                const SizedBox(width: 44),
                
              // Message bubble
              Flexible(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: customColor ?? Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Time
              if (time != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                  child: Text(
                    time!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
} 