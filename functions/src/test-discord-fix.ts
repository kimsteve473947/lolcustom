import {onCall} from 'firebase-functions/v2/https';
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getDiscordBot } from './discord-bot';

/**
 * Firebase Functions config로 Discord 채널 강제 생성 테스트
 */
export const testDiscordFix = onCall(async (request) => {
  console.log('🔧 Testing Discord with Firebase Functions config...');
  
  try {
    // Firebase Functions config 확인
    const config = functions.config();
    const botToken = config.discord?.bot_token || process.env.DISCORD_BOT_TOKEN;
    const guildId = config.discord?.guild_id || process.env.DISCORD_GUILD_ID;
    const categoryId = config.discord?.category_id || process.env.DISCORD_CATEGORY_ID;
    
    console.log('📋 Config check:', {
      hasToken: !!botToken,
      hasGuildId: !!guildId,
      hasCategoryId: !!categoryId,
      tokenPrefix: botToken ? botToken.substring(0, 10) + '...' : 'Missing'
    });
    
    if (!botToken || !guildId || !categoryId) {
      return {
        success: false,
        error: 'Missing Firebase Functions config',
        details: {
          hasToken: !!botToken,
          hasGuildId: !!guildId,
          hasCategoryId: !!categoryId
        }
      };
    }
    
    // 토너먼트 ID
    const tournamentId = "PCvpXkcBGFJCucv4ljKQ";
    
    // 토너먼트 데이터 가져오기
    console.log('📊 Fetching tournament data...');
    const db = admin.firestore();
    const tournamentDoc = await db.collection('tournaments').doc(tournamentId).get();
    
    if (!tournamentDoc.exists) {
      return { success: false, error: 'Tournament not found' };
    }
    
    const tournamentData = tournamentDoc.data();
    console.log('✅ Tournament data:', {
      title: tournamentData?.title,
      participantCount: tournamentData?.participants?.length || 0
    });
    
    // Discord 봇으로 채널 생성 시도
    console.log('🤖 Creating Discord channels...');
    const discordBot = getDiscordBot();
    const channelData = await discordBot.createTournamentChannels(
      tournamentId,
      tournamentData?.title || `토너먼트 ${tournamentId}`,
      tournamentData?.participants || []
    );
    
    if (channelData) {
      console.log('✅ Discord channels created successfully!');
      
      // 토너먼트 문서 업데이트
      await tournamentDoc.ref.update({
        discordChannels: {
          textChannelId: channelData.textChannelId,
          voiceChannel1Id: channelData.voiceChannel1Id,
          voiceChannel2Id: channelData.voiceChannel2Id,
          textChannelInvite: channelData.textChannelInvite,
          voiceChannel1Invite: channelData.voiceChannel1Invite,
          voiceChannel2Invite: channelData.voiceChannel2Invite,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      
      return {
        success: true,
        message: '🎉 Discord 채널 생성 성공!',
        channelData: {
          textChannelInvite: channelData.textChannelInvite,
          voiceChannel1Invite: channelData.voiceChannel1Invite,
          voiceChannel2Invite: channelData.voiceChannel2Invite,
        }
      };
    } else {
      return { 
        success: false, 
        error: 'Discord bot failed to create channels' 
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
