import * as admin from 'firebase-admin';
import axios from 'axios';

export interface TournamentChannelData {
  tournamentId: string;
  tournamentName: string;
  participants: string[];
  textChannelId: string;
  voiceChannel1Id: string;
  voiceChannel2Id: string;
  textChannelInvite: string;
  voiceChannel1Invite: string;
  voiceChannel2Invite: string;
}

export class TournamentDiscordBot {
  private botToken: string;
  private guildId: string;
  private categoryId: string;

  constructor() {
    // Firebase Functions v2에서는 환경변수 사용
    this.botToken = process.env.DISCORD_BOT_TOKEN || '';
    this.guildId = process.env.DISCORD_GUILD_ID || '';
    this.categoryId = process.env.DISCORD_CATEGORY_ID || '';

    console.log('🤖 Discord Bot initialized with environment variables');
    console.log('✅ Bot Token:', this.botToken ? 'Set' : 'Missing');
    console.log('✅ Guild ID:', this.guildId || 'Missing');
    console.log('✅ Category ID:', this.categoryId || 'Missing');
  }

  /**
   * Discord REST API 요청 헬퍼
   */
  private async makeDiscordRequest(method: string, endpoint: string, body?: any) {
    const url = `https://discord.com/api/v10${endpoint}`;
    
    console.log(`📡 Discord API Request: ${method} ${endpoint}`);
    
    try {
      const response = await axios({
        method,
        url,
        headers: {
          'Authorization': `Bot ${this.botToken}`,
          'Content-Type': 'application/json',
        },
        data: body,
      });
      
      console.log(`✅ Discord API Success: ${method} ${endpoint}`);
      return response.data;
    } catch (error: any) {
      console.error(`❌ Discord API Error:`, error.response?.data || error.message);
      throw new Error(`Discord API Error: ${error.response?.status} ${error.response?.statusText || error.message}`);
    }
  }

  /**
   * Discord 채널이 실제로 존재하는지 확인
   */
  async checkChannelExists(channelId: string): Promise<boolean> {
    try {
      console.log(`🔍 Checking if Discord channel exists: ${channelId}`);
      
      if (!this.botToken || !channelId) {
        console.log('⚠️ Missing bot token or channel ID');
        return false;
      }

      // Discord API로 채널 정보 조회
      await this.makeDiscordRequest('GET', `/channels/${channelId}`);
      
      console.log(`✅ Discord channel exists: ${channelId}`);
      return true;
    } catch (error: any) {
      console.error(`❌ Discord channel does not exist or is inaccessible: ${channelId}`, error.message);
      return false;
    }
  }

  /**
   * 토너먼트를 위한 디스코드 채널들을 생성합니다
   */
  async createTournamentChannels(tournamentId: string, tournamentName: string, participants: string[], tournamentData?: any): Promise<TournamentChannelData | null> {
    try {
      console.log(`🎯 Creating channels for tournament: ${tournamentName} (${tournamentId})`);

      if (!this.botToken || !this.guildId || !this.categoryId) {
        throw new Error('Discord bot token, guild ID, or category ID not configured');
      }

      // 토너먼트별 채널명 생성 (카테고리는 기존 사용)
      const baseChannelName = this.generateChannelName(tournamentData || {});
      
      console.log(`📝 Generated base channel name: ${baseChannelName}`);
      console.log(`📁 Using existing category ID: ${this.categoryId}`);

      // 기존 채널들의 position 값 조회하여 다음 위치 계산
      const existingChannels = await this.makeDiscordRequest('GET', `/guilds/${this.guildId}/channels`);
      const categoryChannels = existingChannels.filter((channel: any) => channel.parent_id === this.categoryId);
      
      // 가장 높은 position 값 찾기 (3개씩 그룹화)
      const maxPosition = categoryChannels.length > 0 
        ? Math.max(...categoryChannels.map((ch: any) => ch.position || 0))
        : 0;
      
      // 새 토너먼트 채널들의 시작 position (기존 채널들 다음에 3개씩 그룹으로)
      const startPosition = maxPosition + 1;

      // 1. 텍스트 채널 생성 (기존 스크림져드 내전방 카테고리 내)
      console.log('💬 Creating text channel...');
      const textChannelData = {
        name: baseChannelName,
        type: 0, // GUILD_TEXT
        parent_id: this.categoryId, // 기존 스크림져드 내전방 카테고리
        position: startPosition, // 토너먼트 그룹의 첫 번째
        topic: `${tournamentName} 토너먼트 채팅방 (주최자: ${tournamentData?.hostName || '알 수 없음'})`,
        permission_overwrites: [
          {
            id: this.guildId, // @everyone role
            type: 0, // role
            deny: '1024' // VIEW_CHANNEL permission
          }
        ]
      };

      const textChannel = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, textChannelData);
      console.log(`✅ Created text channel: ${textChannel.name} (${textChannel.id}) at position ${startPosition}`);

      // 2. 음성 채널 A팀 생성 (텍스트 채널 바로 다음)
      console.log('🔊 Creating voice channel A...');
      const voiceChannel1Data = {
        name: `${baseChannelName}-A팀`,
        type: 2, // GUILD_VOICE
        parent_id: this.categoryId, // 기존 스크림져드 내전방 카테고리
        position: startPosition + 1, // 텍스트 채널 바로 다음
        user_limit: 5, // 5명 제한
        permission_overwrites: [
          {
            id: this.guildId, // @everyone role
            type: 0, // role
            deny: '1024' // VIEW_CHANNEL permission
          }
        ]
      };

      const voiceChannel1 = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, voiceChannel1Data);
      console.log(`✅ Created voice channel A: ${voiceChannel1.name} (${voiceChannel1.id}) at position ${startPosition + 1}`);

      // 3. 음성 채널 B팀 생성 (A팀 바로 다음)
      console.log('🔊 Creating voice channel B...');
      const voiceChannel2Data = {
        name: `${baseChannelName}-B팀`,
        type: 2, // GUILD_VOICE
        parent_id: this.categoryId, // 기존 스크림져드 내전방 카테고리
        position: startPosition + 2, // A팀 채널 바로 다음
        user_limit: 5, // 5명 제한
        permission_overwrites: [
          {
            id: this.guildId, // @everyone role
            type: 0, // role
            deny: '1024' // VIEW_CHANNEL permission
          }
        ]
      };

      const voiceChannel2 = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, voiceChannel2Data);
      console.log(`✅ Created voice channel B: ${voiceChannel2.name} (${voiceChannel2.id}) at position ${startPosition + 2}`);

      // 4. 각 채널의 초대 링크 생성 (4시간 후 만료)
      console.log('🔗 Creating invite links...');
      const textChannelInvite = await this.makeDiscordRequest('POST', `/channels/${textChannel.id}/invites`, {
        max_age: 4 * 60 * 60, // 4시간 후 만료
        max_uses: participants.length * 2, // 참가자 수의 2배로 제한
        reason: `${tournamentName} 토너먼트 텍스트 채널 초대`
      });

      const voiceChannel1Invite = await this.makeDiscordRequest('POST', `/channels/${voiceChannel1.id}/invites`, {
        max_age: 4 * 60 * 60, // 4시간 후 만료
        max_uses: 5, // 팀 A 멤버 5명
        reason: `${tournamentName} 토너먼트 A팀 음성 채널 초대`
      });

      const voiceChannel2Invite = await this.makeDiscordRequest('POST', `/channels/${voiceChannel2.id}/invites`, {
        max_age: 4 * 60 * 60, // 4시간 후 만료
        max_uses: 5, // 팀 B 멤버 5명
        reason: `${tournamentName} 토너먼트 B팀 음성 채널 초대`
      });

      // 5. 채널 정보를 반환
      const channelData: TournamentChannelData = {
        tournamentId,
        tournamentName,
        participants,
        textChannelId: textChannel.id,
        voiceChannel1Id: voiceChannel1.id,
        voiceChannel2Id: voiceChannel2.id,
        textChannelInvite: `https://discord.gg/${textChannelInvite.code}`,
        voiceChannel1Invite: `https://discord.gg/${voiceChannel1Invite.code}`,
        voiceChannel2Invite: `https://discord.gg/${voiceChannel2Invite.code}`,
      };

      // 6. Firebase에 채널 정보 저장 (기존 카테고리 ID 사용)
      await this.saveTournamentChannelsToFirebase(channelData, this.categoryId);

      // 7. 웰컴 메시지 전송
      await this.sendWelcomeMessage(textChannel.id, tournamentName, participants.length, tournamentData);

      console.log(`🎉 Successfully created tournament channels grouped together: ${baseChannelName} (positions: ${startPosition}-${startPosition + 2})`);
      return channelData;

    } catch (error) {
      console.error('❌ Error creating tournament channels:', error);
      return null;
    }
  }

  /**
   * 토너먼트 정보를 기반으로 채널명 생성: "3시00분_주최자:김철수"
   */
  private generateChannelName(tournamentData: any): string {
    try {
      // 토너먼트 시작 시간 파싱 (간단한 시:분 형식)
      const startsAt = tournamentData.startsAt;
      let timeString = '';
      
      if (startsAt) {
        const startDate = startsAt.toDate ? startsAt.toDate() : new Date(startsAt);
        const hours = startDate.getHours();
        const minutes = startDate.getMinutes();
        
        // 간단한 시간 형식: "15시30분" 또는 "3시00분"
        timeString = `${hours}시${minutes.toString().padStart(2, '0')}분`;
      } else {
        timeString = '시간미정';
      }
      
      // 주최자 이름 (최대 10자, 특수문자 제거)
      const hostName = (tournamentData.hostNickname || tournamentData.hostName || '알수없음')
        .replace(/[^a-zA-Z0-9가-힣]/g, '')
        .substring(0, 10);
      
      // 최종 채널명: "3시00분_주최자:김철수"
      const channelName = `${timeString}_주최자:${hostName}`;
      
      console.log(`🏷️ Generated channel name: ${channelName}`);
      return channelName;
      
    } catch (error) {
      console.error('❌ Error generating channel name:', error);
      // 실패시 기본 채널명 생성
      return `토너먼트_${Date.now().toString().slice(-6)}`;
    }
  }

  /**
   * 채널 정보를 Firebase에 저장
   */
  private async saveTournamentChannelsToFirebase(channelData: TournamentChannelData, categoryId: string) {
    try {
      const db = admin.firestore();
      
      // 4시간 후 삭제 예정 시간 계산
      const deleteAt = new Date();
      deleteAt.setHours(deleteAt.getHours() + 4);
      
      await db.collection('tournamentChannels').doc(channelData.tournamentId).set({
        ...channelData,
        categoryId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        deleteAt: admin.firestore.Timestamp.fromDate(deleteAt),
        isActive: true,
      });
      console.log(`✅ Tournament channel data saved to Firebase: ${channelData.tournamentId} (삭제 예정: ${deleteAt.toLocaleString('ko-KR')})`);
    } catch (error) {
      console.error('❌ Error saving tournament channel data to Firebase:', error);
    }
  }

  /**
   * 텍스트 채널에 웰컴 메시지 전송
   */
  private async sendWelcomeMessage(channelId: string, tournamentName: string, participantCount: number, tournamentData?: any) {
    try {
      const welcomeMessage = {
        embeds: [{
          color: 0xE97451, // 오렌지 색상 (앱의 메인 컬러)
          title: `🏆 ${tournamentName} 토너먼트`,
          description: '토너먼트가 시작되었습니다! 팀원들과 소통하며 승리를 향해 달려보세요!',
          fields: [
            {
              name: '👥 참가자 수',
              value: `${participantCount}명`,
              inline: true,
            },
            {
              name: '🎮 게임 모드',
              value: '리그 오브 레전드 커스텀 게임',
              inline: true,
            },
            {
              name: '📋 규칙',
              value: '• 음성 채팅은 팀별로 구분되어 있습니다\n• 공정한 경기를 위해 매너를 지켜주세요\n• 문제 발생 시 관리자에게 문의해주세요',
              inline: false,
            },
          ],
          timestamp: new Date().toISOString(),
          footer: {
            text: 'LOL Custom Game Manager',
          },
        }]
      };

      await this.makeDiscordRequest('POST', `/channels/${channelId}/messages`, welcomeMessage);
      console.log(`✅ Welcome message sent to channel: ${channelId}`);
    } catch (error) {
      console.error('❌ Error sending welcome message:', error);
    }
  }

  /**
   * 토너먼트 종료 시 채널들을 정리
   */
  async cleanupTournamentChannels(tournamentId: string): Promise<boolean> {
    try {
      const db = admin.firestore();
      const channelDoc = await db.collection('tournamentChannels').doc(tournamentId).get();

      if (!channelDoc.exists) {
        console.log(`⚠️ No channel data found for tournament: ${tournamentId}`);
        return false;
      }

      const channelData = channelDoc.data() as TournamentChannelData & { categoryId: string };

      // 토너먼트 채널들만 삭제 (기존 카테고리는 유지)
      const channelsToDelete = [
        channelData.textChannelId,
        channelData.voiceChannel1Id,
        channelData.voiceChannel2Id,
      ];

      console.log(`🗑️ Deleting tournament channels for: ${tournamentId}`);
      for (const channelId of channelsToDelete) {
        try {
          await this.makeDiscordRequest('DELETE', `/channels/${channelId}`);
          console.log(`✅ Deleted channel: ${channelId}`);
        } catch (error) {
          console.error(`❌ Error deleting channel ${channelId}:`, error);
        }
      }

      // 기존 스크림져드 내전방 카테고리는 삭제하지 않음 (다른 토너먼트들도 사용)
      console.log(`📁 Keeping existing category (used by other tournaments)`);

      // Firebase 문서 업데이트 (삭제하지 않고 비활성화)
      await channelDoc.ref.update({
        isActive: false,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`🎉 Cleaned up tournament channels for: ${tournamentId}`);
      return true;

    } catch (error) {
      console.error('❌ Error cleaning up tournament channels:', error);
      return false;
    }
  }

  /**
   * 특정 토너먼트 ID의 Discord 채널이 실제로 존재하는지 확인
   */
  async checkTournamentChannelsExist(tournamentId: string): Promise<boolean> {
    try {
      console.log(`🔍 Checking if Discord channels exist for tournament: ${tournamentId}`);
      
      if (!this.botToken) {
        console.log('⚠️ Missing bot token');
        return false;
      }

      // Firebase에서 해당 토너먼트의 채널 정보 조회
      const admin = await import('firebase-admin');
      const db = admin.firestore();
      
      const channelDoc = await db.collection('tournamentChannels').doc(tournamentId).get();
      
      if (!channelDoc.exists) {
        console.log(`💡 No channel data found for tournament: ${tournamentId}`);
        return false;
      }
      
      const channelData = channelDoc.data();
      if (!channelData?.textChannelId) {
        console.log(`💡 Invalid channel data for tournament: ${tournamentId}`);
        return false;
      }

      // Discord API를 통해 채널이 실제로 존재하는지 확인
      const channelExists = await this.checkChannelExists(channelData.textChannelId);
      console.log(`🔗 Tournament ${tournamentId} Discord channel exists: ${channelExists}`);
      
      return channelExists;
    } catch (error) {
      console.error(`❌ Error checking tournament channels for ${tournamentId}:`, error);
      return false;
    }
  }
}

// 싱글톤 인스턴스
let botInstance: TournamentDiscordBot | null = null;

export function getDiscordBot(): TournamentDiscordBot {
  if (!botInstance) {
    botInstance = new TournamentDiscordBot();
  }
  return botInstance;
} 