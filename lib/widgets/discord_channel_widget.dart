import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class DiscordChannelWidget extends StatelessWidget {
  final Map<String, dynamic> discordChannels;
  final String tournamentName;

  const DiscordChannelWidget({
    Key? key,
    required this.discordChannels,
    required this.tournamentName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Discord 채널 정보가 없거나 비어있으면 위젯을 표시하지 않음
    if (!_hasValidChannelData()) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade800,
            Colors.purple.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildChannelsList(),
            const SizedBox(height: 12),
            _buildDiscordInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.discord,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎯 Discord 채널 생성됨',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '팀원들과 소통하세요!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelsList() {
    return Column(
      children: [
        // 텍스트 채팅방
        if (discordChannels['textChannelInvite'] != null)
          _buildChannelCard(
            '💬 텍스트 채팅방',
            '전체 참가자가 소통할 수 있는 채팅방',
            discordChannels['textChannelInvite'],
            Icons.chat_bubble_outline,
            Colors.blue.shade400,
          ),
        
        const SizedBox(height: 8),
        
        // 음성 채팅방들
        Row(
          children: [
            // 팀 A 음성 채팅
            if (discordChannels['voiceChannel1Invite'] != null)
              Expanded(
                child: _buildChannelCard(
                  '🎤 팀 A',
                  '음성 채팅',
                  discordChannels['voiceChannel1Invite'],
                  Icons.mic,
                  Colors.red.shade400,
                  isCompact: true,
                ),
              ),
            
            if (discordChannels['voiceChannel1Invite'] != null && 
                discordChannels['voiceChannel2Invite'] != null)
              const SizedBox(width: 8),
            
            // 팀 B 음성 채팅
            if (discordChannels['voiceChannel2Invite'] != null)
              Expanded(
                child: _buildChannelCard(
                  '🎤 팀 B',
                  '음성 채팅',
                  discordChannels['voiceChannel2Invite'],
                  Icons.mic,
                  Colors.green.shade400,
                  isCompact: true,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildChannelCard(
    String title,
    String subtitle,
    String? inviteUrl,
    IconData icon,
    Color accentColor, {
    bool isCompact = false,
  }) {
    if (inviteUrl == null || inviteUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _launchDiscordChannel(inviteUrl),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            child: isCompact ? _buildCompactContent(title, icon, accentColor) 
                            : _buildFullContent(title, subtitle, icon, accentColor),
          ),
        ),
      ),
    );
  }

  Widget _buildFullContent(String title, String subtitle, IconData icon, Color accentColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.launch,
          color: Colors.white.withOpacity(0.7),
          size: 18,
        ),
      ],
    );
  }

  Widget _buildCompactContent(String title, IconData icon, Color accentColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Icon(
          Icons.launch,
          color: Colors.white.withOpacity(0.7),
          size: 16,
        ),
      ],
    );
  }

  Widget _buildDiscordInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withOpacity(0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '📋 음성 채팅은 팀별로 구분되어 있습니다. 공정한 경기를 위해 매너를 지켜주세요.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasValidChannelData() {
    if (discordChannels.isEmpty) return false;
    
    return discordChannels['textChannelInvite'] != null ||
           discordChannels['voiceChannel1Invite'] != null ||
           discordChannels['voiceChannel2Invite'] != null;
  }

  Future<void> _launchDiscordChannel(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('Could not launch Discord URL: $url');
      }
    } catch (e) {
      print('Error launching Discord URL: $e');
    }
  }
}

// Discord 아이콘을 위한 커스텀 아이콘 클래스
class DiscordIcons {
  DiscordIcons._();

  static const IconData discord = IconData(
    0xe900,
    fontFamily: 'Discord',
  );
}

// 간단한 Discord 채널 버튼 위젯
class DiscordChannelButton extends StatelessWidget {
  final String title;
  final String url;
  final IconData icon;
  final Color color;

  const DiscordChannelButton({
    Key? key,
    required this.title,
    required this.url,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton.icon(
        onPressed: () => _launchUrl(url),
        icon: Icon(icon, size: 18),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }
} 