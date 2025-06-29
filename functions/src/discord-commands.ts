import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import axios from 'axios';

export class DiscordCommandHandler {
  private botToken: string;
  private guildId: string;

  constructor() {
    // 환경 변수에서 Discord 설정 가져오기 (v2 호환)
    this.botToken = process.env.DISCORD_BOT_TOKEN || '';
    this.guildId = process.env.DISCORD_GUILD_ID || '';
  }

  /**
   * Discord REST API 요청 헬퍼
   */
  private async makeDiscordRequest(method: string, endpoint: string, body?: any) {
    const url = `https://discord.com/api/v10${endpoint}`;
    
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
      
      return response.data;
    } catch (error: any) {
      console.error(`❌ Discord API Error:`, error.response?.data || error.message);
      throw new Error(`Discord API Error: ${error.response?.status} ${error.response?.statusText || error.message}`);
    }
  }

  /**
   * 슬래시 명령어 등록
   */
  async registerSlashCommands(): Promise<void> {
    try {
      console.log('📝 Registering Discord slash commands...');

      const commands = [
        {
          name: '서버현황',
          description: '스크림져드 서버의 실시간 현황을 확인합니다',
          type: 1, // CHAT_INPUT
        },
        {
          name: '토너먼트현황',
          description: '현재 진행중이거나 모집중인 토너먼트 목록을 확인합니다',
          type: 1,
        },
        {
          name: '클랜랭킹',
          description: '클랜 승률 기준 상위 랭킹을 확인합니다',
          type: 1,
        },
        {
          name: '대학랭킹',
          description: '대학별 리그전 랭킹을 확인합니다',
          type: 1,
        },
      ];

      // Guild 명령어로 등록 (즉시 적용)
      await this.makeDiscordRequest('PUT', `/applications/${await this.getApplicationId()}/guilds/${this.guildId}/commands`, commands);
      
      console.log('✅ Discord slash commands registered successfully');
    } catch (error) {
      console.error('❌ Error registering slash commands:', error);
    }
  }

  /**
   * Application ID 가져오기
   */
  private async getApplicationId(): Promise<string> {
    try {
      const response = await this.makeDiscordRequest('GET', '/oauth2/applications/@me');
      return response.id;
    } catch (error) {
      console.error('❌ Error getting application ID:', error);
      throw error;
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

// Discord Interaction 처리를 위한 HTTP 함수들은 제거
// 필요시 별도 파일에서 구현 