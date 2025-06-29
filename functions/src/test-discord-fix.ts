import {onCall} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { getDiscordBot } from './discord-bot';

/**
 * Discord 토너먼트 채널 생성 테스트
 */
export const testDiscordFix = onCall(async (request) => {
  console.log('🔧 Testing Discord tournament channel creation...');
  
  try {
    // 환경 변수에서 Discord 설정 확인
    const botToken = process.env.DISCORD_BOT_TOKEN;
    const guildId = process.env.DISCORD_GUILD_ID;
    
    console.log('📋 Config check:', {
      hasToken: !!botToken,
      hasGuildId: !!guildId,
      tokenPrefix: botToken ? botToken.substring(0, 10) + '...' : 'Missing'
    });
    
    if (!botToken || !guildId) {
      return {
        success: false,
        error: 'Missing Discord configuration in environment variables',
        details: {
          hasToken: !!botToken,
          hasGuildId: !!guildId,
          note: 'Please set DISCORD_BOT_TOKEN and DISCORD_GUILD_ID environment variables'
        }
      };
    }

    // 테스트용 토너먼트 ID
    const tournamentId = "test_tournament_" + Date.now();
    
    // 토너먼트 데이터 생성 (테스트용)
    const tournamentData = {
      title: `테스트 토너먼트 ${new Date().toLocaleTimeString('ko-KR')}`,
      gameCategory: 0, // 개인전
      hostName: '관리자',
      startsAt: admin.firestore.Timestamp.fromDate(new Date()),
    };
    
    console.log('🎮 Creating test tournament channels...');
    
    // Discord 봇으로 채널 생성 시도
    const discordBot = getDiscordBot();
    const channelData = await discordBot.createTournamentChannels(
      tournamentId,
      tournamentData.title,
      ['test_user_1', 'test_user_2'], // 테스트 참가자
      tournamentData
    );
    
    if (channelData) {
      console.log('✅ Discord test channels created successfully!');
      
      return {
        success: true,
        message: '🎉 Discord 테스트 채널 생성 성공!',
        channelData: {
          tournamentId,
          textChannelId: channelData.textChannelId,
          voiceChannel1Id: channelData.voiceChannel1Id,
          voiceChannel2Id: channelData.voiceChannel2Id,
          note: '채널은 4시간 후 자동 삭제됩니다.'
        }
      };
    } else {
      return { 
        success: false, 
        error: 'Discord bot failed to create test channels' 
      };
    }
    
  } catch (error: any) {
    console.error('❌ testDiscordFix failed:', error);
    return {
      success: false,
      error: error.message,
      stack: error.stack
    };
  }
});
