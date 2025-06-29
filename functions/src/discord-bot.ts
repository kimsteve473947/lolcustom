import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
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
    // 환경 변수에서 Discord 설정 가져오기 (v2 호환)
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
      console.log(`🏷️ Game Category: ${tournamentData?.gameCategory || 'individual'}`);

      if (!this.botToken || !this.guildId) {
        throw new Error('Discord bot token or guild ID not configured');
      }

      // 게임 카테고리에 따른 카테고리 ID 설정
      const targetCategoryId = this.getCategoryByGameType(tournamentData?.gameCategory);

      // 1. 토너먼트 참가자들의 Discord ID 수집
      const participantDiscordIds = await this.getParticipantDiscordIds(participants);
      console.log(`📋 Found ${participantDiscordIds.length} participants with Discord accounts`);
      
      if (participantDiscordIds.length === 0) {
        console.log('⚠️ No participants have Discord accounts connected. Creating public channels instead.');
        // Discord 계정 없는 사용자들을 위해 기존 방식으로 폴백
        return await this.createPublicTournamentChannels(tournamentId, tournamentName, participants, tournamentData, targetCategoryId);
      }

      // 토너먼트별 채널명 생성
      const baseChannelName = this.generateChannelName(tournamentData || {});
      
      console.log(`📝 Generated base channel name: ${baseChannelName}`);
      console.log(`🔐 Creating private channels with permission overrides in category: ${targetCategoryId}`);

      // 2. 권한 설정 생성 (참가자들만 접근 가능)
      const permissionOverwrites = await this.createPermissionOverwrites(participantDiscordIds);

      // 3. 텍스트 채널 생성 (비공개 + 권한 설정)
      console.log('💬 Creating private text channel...');
      const textChannelData = {
        name: baseChannelName,
        type: 0, // GUILD_TEXT
        topic: `${tournamentName} 토너먼트 채팅방 (참가자 전용)`,
        permission_overwrites: permissionOverwrites,
        parent_id: targetCategoryId, // 카테고리 지정
      };

      const textChannel = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, textChannelData);
      console.log(`✅ Created private text channel: ${textChannel.name} (${textChannel.id})`);

      // 4. 음성 채널 A팀 생성 (비공개 + 권한 설정)
      console.log('🔊 Creating private voice channel A...');
      const voiceChannel1Data = {
        name: `${baseChannelName}-A팀`,
        type: 2, // GUILD_VOICE
        user_limit: 5, // 5명 제한
        permission_overwrites: permissionOverwrites,
        parent_id: targetCategoryId, // 카테고리 지정
      };

      const voiceChannel1 = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, voiceChannel1Data);
      console.log(`✅ Created private voice channel A: ${voiceChannel1.name} (${voiceChannel1.id})`);

      // 5. 음성 채널 B팀 생성 (비공개 + 권한 설정)
      console.log('🔊 Creating private voice channel B...');
      const voiceChannel2Data = {
        name: `${baseChannelName}-B팀`,
        type: 2, // GUILD_VOICE
        user_limit: 5, // 5명 제한
        permission_overwrites: permissionOverwrites,
        parent_id: targetCategoryId, // 카테고리 지정
      };

      const voiceChannel2 = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, voiceChannel2Data);
      console.log(`✅ Created private voice channel B: ${voiceChannel2.name} (${voiceChannel2.id})`);

      // 6. 채널 정보를 반환 (초대링크 없이)
      const channelData: TournamentChannelData = {
        tournamentId,
        tournamentName,
        participants,
        textChannelId: textChannel.id,
        voiceChannel1Id: voiceChannel1.id,
        voiceChannel2Id: voiceChannel2.id,
        textChannelInvite: '', // 권한 기반이므로 초대링크 불필요
        voiceChannel1Invite: '', // 권한 기반이므로 초대링크 불필요
        voiceChannel2Invite: '', // 권한 기반이므로 초대링크 불필요
      };

      // 7. Firebase에 채널 정보 저장
      await this.saveTournamentChannelsToFirebase(channelData, targetCategoryId);

      // 8. 게임 카테고리별 웰컴 메시지 전송
      await this.sendGameCategoryWelcomeMessage(textChannel.id, tournamentName, participantDiscordIds.length, tournamentData);

      console.log(`🎉 Successfully created private tournament channels: ${baseChannelName}`);
      return channelData;

    } catch (error) {
      console.error('❌ Error creating private tournament channels:', error);
      // 권한 기반 채널 생성 실패시 공개 채널로 폴백
      console.log('🔄 Falling back to public channel creation...');
      return await this.createPublicTournamentChannels(tournamentId, tournamentName, participants, tournamentData);
    }
  }

  /**
   * 게임 카테고리에 따른 Discord 카테고리 ID 반환
   */
  private getCategoryByGameType(gameCategory?: any): string {
    // GameCategory enum 값에 따른 카테고리 ID 매핑
    switch (gameCategory) {
      case 0: // GameCategory.individual
        return '1385383466635624529'; // 스크림져드 개인전
      case 1: // GameCategory.clan  
        return '1385712517661331617'; // 스크림져드 클랜전
      case 2: // GameCategory.university
        return '1387287541950189609'; // 스크림져드 대학 대항전
      default:
        console.log(`⚠️ Unknown game category: ${gameCategory}, using individual category`);
        return '1385383466635624529'; // 기본값: 개인전
    }
  }

  /**
   * 토너먼트 참가자들의 Discord ID를 수집합니다
   */
  private async getParticipantDiscordIds(participantUids: string[]): Promise<string[]> {
    try {
      console.log(`🔍 Fetching Discord IDs for ${participantUids.length} participants`);
      
      const db = admin.firestore();
      const discordIds: string[] = [];
      
      // 각 참가자의 Discord ID 조회
      for (const uid of participantUids) {
        try {
          const userDoc = await db.collection('users').doc(uid).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            // additionalInfo에서 Discord ID 가져오기
            const additionalInfo = userData?.additionalInfo;
            const discordId = additionalInfo?.discordId;
            
            if (discordId && typeof discordId === 'string' && discordId.trim() !== '') {
              discordIds.push(discordId);
              console.log(`✅ Found Discord ID for user ${uid}: ${discordId}`);
            } else {
              console.log(`⚠️ User ${uid} doesn't have Discord connected`);
            }
          } else {
            console.log(`⚠️ User document not found: ${uid}`);
          }
        } catch (error) {
          console.error(`❌ Error fetching Discord ID for user ${uid}:`, error);
        }
      }
      
      console.log(`📊 Total Discord IDs collected: ${discordIds.length}/${participantUids.length}`);
      return discordIds;
      
    } catch (error) {
      console.error('❌ Error fetching participant Discord IDs:', error);
      return [];
    }
  }

  /**
   * Discord 채널 권한 설정을 생성합니다
   */
  private async createPermissionOverwrites(participantDiscordIds: string[]): Promise<any[]> {
    try {
      const permissionOverwrites = [];
      
      // 1. @everyone 역할에 대한 권한 거부 (채널 완전 비공개화)
      permissionOverwrites.push({
        id: this.guildId, // @everyone role은 guild_id와 동일
        type: 0, // role
        allow: "0", // 권한 없음
        deny: "1024", // VIEW_CHANNEL 권한 거부 (채널을 볼 수 없음)
      });
      
      // 2. 각 참가자에게 채널 접근 및 메시지 권한 부여
      for (const discordId of participantDiscordIds) {
        permissionOverwrites.push({
          id: discordId,
          type: 1, // member
          allow: "3072", // VIEW_CHANNEL (1024) + SEND_MESSAGES (2048) = 3072
          deny: "0", // 거부할 권한 없음
        });
      }
      
      console.log(`🔒 Created permission overwrites for ${participantDiscordIds.length} participants`);
      return permissionOverwrites;
      
    } catch (error) {
      console.error('❌ Error creating permission overwrites:', error);
      return [];
    }
  }

  /**
   * 기존 공개 채널 생성 방식 (폴백용)
   */
  private async createPublicTournamentChannels(tournamentId: string, tournamentName: string, participants: string[], tournamentData?: any, targetCategoryId?: string): Promise<TournamentChannelData | null> {
    try {
      console.log(`🌐 Creating public channels for tournament: ${tournamentName} (${tournamentId})`);

      // 카테고리 ID가 없으면 게임 카테고리로 결정
      if (!targetCategoryId) {
        targetCategoryId = this.getCategoryByGameType(tournamentData?.gameCategory);
      }

      // 토너먼트별 채널명 생성
      const baseChannelName = this.generateChannelName(tournamentData || {});
      
      console.log(`📝 Generated base channel name: ${baseChannelName}`);
      console.log(`📁 Using category: ${targetCategoryId}`);

      // 1. 텍스트 채널 생성
      console.log('💬 Creating public text channel...');
      const textChannelData = {
        name: baseChannelName,
        type: 0, // GUILD_TEXT
        topic: `${tournamentName} 토너먼트 채팅방 (주최자: ${tournamentData?.hostName || '알 수 없음'})`,
        parent_id: targetCategoryId, // 카테고리 지정
      };

      const textChannel = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, textChannelData);
      console.log(`✅ Created public text channel: ${textChannel.name} (${textChannel.id})`);

      // 2. 음성 채널 A팀 생성
      console.log('🔊 Creating public voice channel A...');
      const voiceChannel1Data = {
        name: `${baseChannelName}-A팀`,
        type: 2, // GUILD_VOICE
        user_limit: 5, // 5명 제한
        parent_id: targetCategoryId, // 카테고리 지정
      };

      const voiceChannel1 = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, voiceChannel1Data);
      console.log(`✅ Created public voice channel A: ${voiceChannel1.name} (${voiceChannel1.id})`);

      // 3. 음성 채널 B팀 생성
      console.log('🔊 Creating public voice channel B...');
      const voiceChannel2Data = {
        name: `${baseChannelName}-B팀`,
        type: 2, // GUILD_VOICE
        user_limit: 5, // 5명 제한
        parent_id: targetCategoryId, // 카테고리 지정
      };

      const voiceChannel2 = await this.makeDiscordRequest('POST', `/guilds/${this.guildId}/channels`, voiceChannel2Data);
      console.log(`✅ Created public voice channel B: ${voiceChannel2.name} (${voiceChannel2.id})`);

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

      // 6. Firebase에 채널 정보 저장
      await this.saveTournamentChannelsToFirebase(channelData, targetCategoryId);

      // 7. 게임 카테고리별 웰컴 메시지 전송
      await this.sendGameCategoryWelcomeMessage(textChannel.id, tournamentName, participants.length, tournamentData);

      console.log(`🎉 Successfully created public tournament channels: ${baseChannelName}`);
      return channelData;

    } catch (error) {
      console.error('❌ Error creating public tournament channels:', error);
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
   * 게임 카테고리별 맞춤 웰컴 메시지 전송
   */
  private async sendGameCategoryWelcomeMessage(channelId: string, tournamentName: string, participantCount: number, tournamentData?: any) {
    try {
      const gameCategory = tournamentData?.gameCategory;
      let title = '';
      let description = '';
      let gameModeValue = '';
      let additionalFields: any[] = [];

      // 게임 카테고리별 메시지 커스터마이징
      switch (gameCategory) {
        case 0: // GameCategory.individual (개인전)
          title = `🏆 ${tournamentName} 개인전`;
          description = '🔥 **개인전 토너먼트가 시작되었습니다!**\n\n개인 실력을 마음껏 뽐내고 새로운 사람들과 함께 즐거운 게임을 해보세요!';
          gameModeValue = '개인전 (랜덤 팀 매칭)';
          additionalFields = [
            {
              name: '🎯 개인전 특징',
              value: '• 티어와 포지션을 고려한 팀 구성\n• 새로운 팀원들과의 협력 경험\n• 개인 실력 향상 기회',
              inline: false,
            }
          ];
          break;

        case 1: // GameCategory.clan (클랜전)  
          title = `⚔️ ${tournamentName} 클랜전`;
          description = '🛡️ **클랜전 토너먼트가 시작되었습니다!**\n\n클랜원들과 함께 팀워크를 발휘하여 상대 클랜을 제압해보세요!';
          gameModeValue = '클랜전 (클랜 vs 클랜)';
          additionalFields = [
            {
              name: '⚔️ 클랜전 특징',
              value: '• 클랜원들과의 완벽한 팀워크\n• 클랜 명예를 걸고 하는 치열한 경쟁\n• 클랜 랭킹 포인트 획득',
              inline: false,
            },
            {
              name: '🏆 클랜 전적',
              value: '이 경기 결과는 클랜 전적에 반영됩니다.',
              inline: true,
            }
          ];
          break;

        case 2: // GameCategory.university (대학 리그전)
          title = `🎓 ${tournamentName} 대학 리그전`;
          description = '🏫 **대학 리그전 토너먼트가 시작되었습니다!**\n\n우리 대학의 명예를 걸고 다른 대학과 치열한 경쟁을 펼쳐보세요!';
          gameModeValue = '대학 리그전 (대학 vs 대학)';
          additionalFields = [
            {
              name: '🎓 대학 리그전 특징',
              value: '• 대학 인증된 학생들만 참가 가능\n• 대학별 랭킹 시스템\n• 대학 대항 명예의 전쟁',
              inline: false,
            },
            {
              name: '🏫 대학 랭킹',
              value: '이 경기 결과는 대학 랭킹에 반영됩니다.',
              inline: true,
            }
          ];
          break;

        default:
          title = `🏆 ${tournamentName} 토너먼트`;
          description = '토너먼트가 시작되었습니다! 팀원들과 소통하며 승리를 향해 달려보세요!';
          gameModeValue = '리그 오브 레전드 커스텀 게임';
      }

      const welcomeMessage = {
        embeds: [{
          color: 0xFF6B35, // 스크림져드 메인 컬러 (#FF6B35)
          title: title,
          description: description,
          fields: [
            {
              name: '👥 참가자 수',
              value: `${participantCount}명`,
              inline: true,
            },
            {
              name: '🎮 게임 모드',
              value: gameModeValue,
              inline: true,
            },
            ...additionalFields,
            {
              name: '📋 공통 규칙',
              value: '• 음성 채팅은 팀별로 구분되어 있습니다\n• 공정한 경기를 위해 매너를 지켜주세요\n• 문제 발생 시 관리자에게 문의해주세요\n• 게임 결과는 앱에 자동 반영됩니다',
              inline: false,
            },
          ],
          timestamp: new Date().toISOString(),
          footer: {
            text: 'Scrimjard - 스크림져드',
            icon_url: 'https://your-app-icon-url.com/icon.png', // 앱 아이콘 URL
          },
        }]
      };

      await this.makeDiscordRequest('POST', `/channels/${channelId}/messages`, welcomeMessage);
      console.log(`✅ Game category welcome message sent to channel: ${channelId} (Category: ${gameCategory})`);
    } catch (error) {
      console.error('❌ Error sending game category welcome message:', error);
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

  /**
   * Discord 슬래시 명령어 처리
   */
  async handleSlashCommand(interaction: any): Promise<void> {
    try {
      const commandName = interaction.data.name;
      
      console.log(`🎮 Processing Discord command: ${commandName}`);
      
      switch (commandName) {
        case '서버현황':
          await this.handleServerStatusCommand(interaction);
          break;
        case '토너먼트현황':
          await this.handleTournamentStatusCommand(interaction);
          break;
        case '클랜랭킹':
          await this.handleClanRankingCommand(interaction);
          break;
        case '대학랭킹':
          await this.handleUniversityRankingCommand(interaction);
          break;
        default:
          await this.sendInteractionResponse(interaction, {
            type: 4, // CHANNEL_MESSAGE_WITH_SOURCE
            data: {
              content: `❌ 알 수 없는 명령어입니다: ${commandName}`,
              flags: 64, // EPHEMERAL
            },
          });
      }
    } catch (error) {
      console.error('❌ Error handling slash command:', error);
      await this.sendInteractionResponse(interaction, {
        type: 4,
        data: {
          content: '❌ 명령어 처리 중 오류가 발생했습니다.',
          flags: 64,
        },
      });
    }
  }

  /**
   * 서버 현황 명령어 처리
   */
  private async handleServerStatusCommand(interaction: any): Promise<void> {
    try {
      const db = admin.firestore();
      
      // 총 사용자 수 조회
      const usersSnapshot = await db.collection('users').count().get();
      const totalUsers = usersSnapshot.data().count;
      
      // 활성 토너먼트 수 조회
      const tournamentsSnapshot = await db.collection('tournaments')
        .where('status', 'in', [1, 2]) // open, full 상태
        .count().get();
      const activeTournaments = tournamentsSnapshot.data().count;
      
      // 총 클랜 수 조회
      const clansSnapshot = await db.collection('clans').count().get();
      const totalClans = clansSnapshot.data().count;
      
      // Discord 멤버 수 조회
      const guildInfo = await this.makeDiscordRequest('GET', `/guilds/${this.guildId}`);
      const discordMembers = guildInfo.member_count || 0;

      const embed = {
        color: 0xFF6B35, // 스크림져드 메인 컬러
        title: '📊 스크림져드 실시간 서버 현황',
        description: '현재 스크림져드 플랫폼의 실시간 통계입니다.',
        fields: [
          {
            name: '👥 총 사용자',
            value: `${totalUsers.toLocaleString()}명`,
            inline: true,
          },
          {
            name: '💬 디스코드 멤버',
            value: `${discordMembers}명`,
            inline: true,
          },
          {
            name: '🏆 활성 토너먼트',
            value: `${activeTournaments}개`,
            inline: true,
          },
          {
            name: '👑 등록된 클랜',
            value: `${totalClans}개`,
            inline: true,
          },
          {
            name: '🎮 게임 모드',
            value: '• 개인전\n• 클랜전\n• 대학 리그전',
            inline: true,
          },
          {
            name: '📱 플랫폼',
            value: '• iOS App Store\n• Google Play Store\n• Discord 봇',
            inline: true,
          },
        ],
        timestamp: new Date().toISOString(),
        footer: {
          text: 'Scrimjard - 스크림져드',
        },
      };

      await this.sendInteractionResponse(interaction, {
        type: 4,
        data: {
          embeds: [embed],
        },
      });

      console.log('✅ Server status command response sent');
    } catch (error) {
      console.error('❌ Error in server status command:', error);
      throw error;
    }
  }

  /**
   * 토너먼트 현황 명령어 처리
   */
  private async handleTournamentStatusCommand(interaction: any): Promise<void> {
    try {
      const db = admin.firestore();
      
      // 최근 토너먼트들 조회 (상위 10개)
      const tournamentsSnapshot = await db.collection('tournaments')
        .where('status', 'in', [1, 2, 3]) // open, full, inProgress
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();

      if (tournamentsSnapshot.empty) {
        await this.sendInteractionResponse(interaction, {
          type: 4,
          data: {
            content: '현재 진행중인 토너먼트가 없습니다.',
            flags: 64,
          },
        });
        return;
      }

      const tournaments = tournamentsSnapshot.docs.map(doc => {
        const data = doc.data();
        const gameCategory = this.getGameCategoryName(data.gameCategory);
        const status = this.getTournamentStatusName(data.status);
        
        return {
          title: data.title || '제목 없음',
          gameCategory,
          status,
          participants: data.participants?.length || 0,
          totalSlots: 10, // 기본 슬롯 수
          startsAt: data.startsAt?.toDate?.() || new Date(),
        };
      });

      const embed = {
        color: 0xFF6B35,
        title: '🏆 현재 토너먼트 현황',
        description: '진행중이거나 모집중인 토너먼트 목록입니다.',
        fields: tournaments.slice(0, 5).map((tournament, index) => ({
          name: `${index + 1}. ${tournament.title}`,
          value: `🏷️ ${tournament.gameCategory} | 👥 ${tournament.participants}/${tournament.totalSlots}명 | 📅 ${tournament.startsAt.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' })}`,
          inline: false,
        })),
        timestamp: new Date().toISOString(),
        footer: {
          text: '더 많은 토너먼트는 스크림져드 앱에서 확인하세요!',
        },
      };

      await this.sendInteractionResponse(interaction, {
        type: 4,
        data: {
          embeds: [embed],
        },
      });

      console.log('✅ Tournament status command response sent');
    } catch (error) {
      console.error('❌ Error in tournament status command:', error);
      throw error;
    }
  }

  /**
   * 클랜 랭킹 명령어 처리
   */
  private async handleClanRankingCommand(interaction: any): Promise<void> {
    try {
      const db = admin.firestore();
      
      // 클랜 랭킹 조회 (승률 기준 상위 10개)
      const clansSnapshot = await db.collection('clans')
        .orderBy('winRate', 'desc')
        .limit(10)
        .get();

      if (clansSnapshot.empty) {
        await this.sendInteractionResponse(interaction, {
          type: 4,
          data: {
            content: '등록된 클랜이 없습니다.',
            flags: 64,
          },
        });
        return;
      }

      const clans = clansSnapshot.docs.map((doc, index) => {
        const data = doc.data();
        return {
          rank: index + 1,
          name: data.name || '클랜명 없음',
          winRate: ((data.winRate || 0) * 100).toFixed(1),
          wins: data.wins || 0,
          losses: data.losses || 0,
          memberCount: data.memberCount || 0,
        };
      });

      const embed = {
        color: 0xFF6B35,
        title: '👑 클랜 랭킹 TOP 10',
        description: '승률 기준 클랜 순위입니다.',
        fields: clans.slice(0, 10).map(clan => ({
          name: `${clan.rank}위. ${clan.name}`,
          value: `승률: ${clan.winRate}% | 전적: ${clan.wins}승 ${clan.losses}패 | 멤버: ${clan.memberCount}명`,
          inline: false,
        })),
        timestamp: new Date().toISOString(),
        footer: {
          text: '클랜 가입은 스크림져드 앱에서!',
        },
      };

      await this.sendInteractionResponse(interaction, {
        type: 4,
        data: {
          embeds: [embed],
        },
      });

      console.log('✅ Clan ranking command response sent');
    } catch (error) {
      console.error('❌ Error in clan ranking command:', error);
      throw error;
    }
  }

  /**
   * 대학 랭킹 명령어 처리
   */
  private async handleUniversityRankingCommand(interaction: any): Promise<void> {
    try {
      // 대학별 승률 집계 (사용자 통계 기반)
      const embed = {
        color: 0xFF6B35,
        title: '🎓 대학 리그 랭킹',
        description: '대학 인증 사용자들의 토너먼트 성과 기준 랭킹입니다.',
        fields: [
          {
            name: '🏆 준비중',
            value: '대학 리그전 랭킹 시스템이 곧 출시됩니다!\n\n더 자세한 정보는 스크림져드 앱에서 확인해주세요.',
            inline: false,
          },
        ],
        timestamp: new Date().toISOString(),
        footer: {
          text: '대학 인증은 스크림져드 앱에서!',
        },
      };

      await this.sendInteractionResponse(interaction, {
        type: 4,
        data: {
          embeds: [embed],
        },
      });

      console.log('✅ University ranking command response sent');
    } catch (error) {
      console.error('❌ Error in university ranking command:', error);
      throw error;
    }
  }

  /**
   * Discord Interaction 응답 전송
   */
  private async sendInteractionResponse(interaction: any, response: any): Promise<void> {
    try {
      await this.makeDiscordRequest('POST', `/interactions/${interaction.id}/${interaction.token}/callback`, response);
    } catch (error) {
      console.error('❌ Error sending interaction response:', error);
      throw error;
    }
  }

  /**
   * 게임 카테고리 이름 반환
   */
  private getGameCategoryName(gameCategory: number): string {
    switch (gameCategory) {
      case 0: return '개인전';
      case 1: return '클랜전';
      case 2: return '대학 리그전';
      default: return '일반전';
    }
  }

  /**
   * 토너먼트 상태 이름 반환
   */
  private getTournamentStatusName(status: number): string {
    switch (status) {
      case 0: return '초안';
      case 1: return '모집중';
      case 2: return '모집완료';
      case 3: return '진행중';
      case 4: return '완료';
      case 5: return '취소';
      default: return '알 수 없음';
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