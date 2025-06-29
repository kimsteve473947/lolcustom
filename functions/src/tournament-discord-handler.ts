import {onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {onCall} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';
import { getDiscordBot } from './discord-bot';

/**
 * 토너먼트 참가자가 변경될 때 트리거되는 함수
 * 참가자가 10명이 되면 디스코드 채널을 생성하고 앱에 알림을 보냅니다
 */
export const onTournamentParticipantChange = onDocumentUpdated(
  {
    document: 'tournaments/{tournamentId}',
    region: 'us-central1'
  },
  async (event) => {
    try {
      console.log('🔔 onTournamentParticipantChange 함수 실행됨!');
      console.log('🔧 Event context:', JSON.stringify(event.params));
      
      const tournamentId = event.params.tournamentId;
      console.log(`📋 Tournament ID: ${tournamentId}`);
      
      const beforeData = event.data?.before.data();
      const afterData = event.data?.after.data();

      if (!beforeData || !afterData) {
        console.log('⚠️ Missing tournament data');
        console.log('beforeData:', beforeData ? 'exists' : 'null');
        console.log('afterData:', afterData ? 'exists' : 'null');
        return;
      }

      console.log('📊 Before data keys:', Object.keys(beforeData));
      console.log('📊 After data keys:', Object.keys(afterData));

      // 참가자 수 확인
      const beforeParticipantCount = beforeData?.participants?.length || 0;
      const afterParticipantCount = afterData?.participants?.length || 0;

      console.log(`🔔 Tournament ${tournamentId} participant count changed: ${beforeParticipantCount} → ${afterParticipantCount}`);
      console.log('🔍 Before participants:', beforeData?.participants || []);
      console.log('🔍 After participants:', afterData?.participants || []);

      // 10명 달성 확인 (before < 10 && after >= 10)
      if (beforeParticipantCount < 10 && afterParticipantCount >= 10) {
        console.log(`🎯 Tournament ${tournamentId} reached 10 participants! Processing Discord channels...`);
        
        const discordBot = getDiscordBot();
        let channelData = null;
        
        // 1. 기존 Discord 채널 확인
        if (!afterData.discordChannels || !afterData.discordChannels.textChannelId) {
          // Discord 채널이 없는 경우 → 새로 생성
          console.log('🏗️ No existing Discord channels, creating new ones...');
          
          channelData = await discordBot.createTournamentChannels(
            tournamentId,
            afterData.title || afterData.name || `토너먼트 ${tournamentId}`,
            afterData.participants || [],
            afterData // 토너먼트 전체 데이터 전달
          );

          if (channelData) {
            console.log('✅ Discord channels created successfully!');
            console.log('📝 Channel data:', {
              textChannelId: channelData.textChannelId,
              voiceChannel1Id: channelData.voiceChannel1Id,
              voiceChannel2Id: channelData.voiceChannel2Id
            });

            // 토너먼트 문서 업데이트 (discordChannels 필드 추가)
            await admin.firestore().collection('tournaments').doc(tournamentId).update({
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

            // tournamentChannels 컬렉션에도 저장
            await admin.firestore().collection('tournamentChannels').doc(tournamentId).set({
              isActive: true,
              deleteAt: admin.firestore.Timestamp.fromMillis(Date.now() + 4 * 60 * 60 * 1000), // 4시간 후
              textChannelId: channelData.textChannelId,
              voiceChannel1Id: channelData.voiceChannel1Id,
              voiceChannel2Id: channelData.voiceChannel2Id,
              textChannelInvite: channelData.textChannelInvite,
              voiceChannel1Invite: channelData.voiceChannel1Invite,
              voiceChannel2Invite: channelData.voiceChannel2Invite,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } else {
            console.error(`❌ Failed to create Discord channels for tournament: ${tournamentId}`);
          }
        } else {
          // Discord 채널이 이미 있는 경우 → 기존 채널 데이터 사용
          console.log(`✅ Discord channels already exist for tournament ${tournamentId}`);
          channelData = afterData.discordChannels;
        }
        
        // 2. 채널 데이터가 있으면 무조건 초대링크 메시지 전송
        if (channelData && channelData.textChannelInvite) {
          console.log('📱 Sending Discord invite link to chat...');
          console.log('⏰ Waiting 3 seconds before sending invite link...');
          await new Promise(resolve => setTimeout(resolve, 3000));
          
          await sendDiscordInviteMessage(
            { id: tournamentId, name: afterData.title, participants: afterData.participants },
            channelData
          );
          
          console.log(`🎉 Successfully sent Discord invite link for tournament: ${tournamentId}`);
        } else {
          console.error(`❌ No valid Discord channel data found for tournament: ${tournamentId}`);
        }
      } else {
        console.log(`📊 Participant count change detected but conditions not met:`);
        console.log(`   - Before: ${beforeParticipantCount}, After: ${afterParticipantCount}`);
        console.log(`   - Condition: before < 10 && after >= 10`);
        console.log(`   - Result: ${beforeParticipantCount < 10} && ${afterParticipantCount >= 10} = ${beforeParticipantCount < 10 && afterParticipantCount >= 10}`);
      }
    } catch (error) {
      console.error('❌ Error in onTournamentParticipantChange:', error);
      console.error('📚 Error stack:', error instanceof Error ? error.stack : 'No stack trace');
    }
  }
);

/**
 * Discord 초대링크를 채팅방에 전송
 * Updated: 2025-06-21 Force deploy v2
 */
async function sendDiscordInviteMessage(tournamentData: any, channelData: any): Promise<void> {
  console.log(`📱 [DISCORD INVITE] Sending Discord channel info for tournament: ${tournamentData.id}`);
  
  try {
    const db = admin.firestore();
    
    // 채팅방 ID 찾기
    const chatRoomId = await getTournamentChatRoomId(tournamentData.id);
    if (!chatRoomId) {
      console.error(`❌ [DISCORD INVITE] No chat room found for tournament: ${tournamentData.id}`);
      return;
    }
    
    console.log(`✅ [DISCORD INVITE] Using chat room: ${chatRoomId}`);
    
    // Discord 채널 메시지 생성 (권한 기반 vs 초대링크 기반)
    let messageContent: string;
    
    if (channelData.textChannelInvite && channelData.textChannelInvite.trim() !== '') {
      // 기존 초대링크 기반 메시지
      messageContent = `🎯 ${tournamentData.name} 토너먼트 Discord 채널이 생성되었습니다!

💬 텍스트 채팅방 입장하기:
${channelData.textChannelInvite}

🎤 음성 채팅방:
A팀: ${channelData.voiceChannel1Invite}
B팀: ${channelData.voiceChannel2Invite}

📱 링크를 터치하여 Discord 채널에 입장하세요!`;
    } else {
      // 새로운 권한 기반 메시지
      messageContent = `🔒 ${tournamentData.name} 토너먼트 Discord 채널이 생성되었습니다!

✨ **자동 권한 설정 완료!**
Discord 계정을 연결한 참가자들은 자동으로 채널 접근 권한을 받았습니다.

🎮 **채널 이용 방법:**
1. Discord 앱을 열어주세요
2. 스크림져드 서버에서 새로 생성된 채널을 확인하세요
3. 텍스트 채널과 A팀/B팀 음성 채널을 이용하세요

🔐 **보안 기능:**
• 참가자들만 접근 가능한 비공개 채널
• 토너먼트 종료 시 자동 삭제
• 안전한 경기 진행 보장

📋 Discord 계정을 연결하지 않은 참가자는 앱 내 채팅을 이용해주세요.`;
    }
    
    console.log(`📝 [DISCORD INVITE] Generated message content (length: ${messageContent.length})`);
    
    // 메시지 생성
    const messageData = {
      chatRoomId: chatRoomId,
      senderId: 'system',
      senderName: '시스템',
      text: messageContent,
      readStatus: {},
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        type: channelData.textChannelInvite ? 'discord_invite' : 'discord_private_channel',
        discordChannels: channelData,
        isPrivateChannel: !channelData.textChannelInvite,
        textChannelInvite: channelData.textChannelInvite || null,
        voiceChannel1Invite: channelData.voiceChannel1Invite || null,
        voiceChannel2Invite: channelData.voiceChannel2Invite || null,
      },
    };

    console.log(`💾 [DISCORD INVITE] Adding message to chat room: ${chatRoomId}`);
    
    const messageRef = await db.collection('messages').add(messageData);
    console.log(`✅ [DISCORD INVITE] Message added with ID: ${messageRef.id}`);
    
    // 채팅방의 lastMessage 업데이트
    const lastMessageText = channelData.textChannelInvite 
      ? 'Discord 채널이 생성되었습니다!' 
      : 'Discord 비공개 채널이 생성되었습니다!';
      
    await db.collection('chatRooms').doc(chatRoomId).update({
      lastMessageText: lastMessageText,
      lastMessageTime: messageData.timestamp,
    });
    
    console.log(`🎉 [DISCORD INVITE] Successfully sent Discord channel info to chat room: ${chatRoomId}`);
    
  } catch (error) {
    console.error(`❌ [DISCORD INVITE] Error sending channel info message:`, error);
    throw error;
  }
}

/**
 * 토너먼트와 연결된 채팅방 ID 가져오기 (강화된 검색)
 */
async function getTournamentChatRoomId(tournamentId: string): Promise<string | null> {
  try {
    console.log(`🔍 [CHAT ROOM SEARCH] Searching for chat room with tournament ID: ${tournamentId}`);
    const db = admin.firestore();
    
    // 1차: tournamentRecruitment 타입으로 검색
    console.log(`🔍 [CHAT ROOM SEARCH] Searching tournamentRecruitment type...`);
    const recruitmentQuery = await db.collection('chatRooms')
      .where('type', '==', 'tournamentRecruitment')
      .where('tournamentId', '==', tournamentId)
      .limit(1)
      .get();

    if (!recruitmentQuery.empty) {
      const chatRoomId = recruitmentQuery.docs[0].id;
      const chatRoomData = recruitmentQuery.docs[0].data();
      console.log(`✅ [CHAT ROOM SEARCH] Found tournamentRecruitment chat room: ${chatRoomId}`);
      console.log(`🔍 [CHAT ROOM SEARCH] Chat room data:`, {
        id: chatRoomId,
        tournamentId: chatRoomData.tournamentId,
        type: chatRoomData.type,
        title: chatRoomData.title,
        participantCount: chatRoomData.participantIds?.length || 0
      });
      return chatRoomId;
    }

    // 2차: tournament 타입으로 검색
    console.log(`🔍 [CHAT ROOM SEARCH] Searching tournament type...`);
    const tournamentQuery = await db.collection('chatRooms')
      .where('type', '==', 'tournament')
      .where('tournamentId', '==', tournamentId)
      .limit(1)
      .get();

    if (!tournamentQuery.empty) {
      const chatRoomId = tournamentQuery.docs[0].id;
      const chatRoomData = tournamentQuery.docs[0].data();
      console.log(`✅ [CHAT ROOM SEARCH] Found tournament chat room: ${chatRoomId}`);
      console.log(`🔍 [CHAT ROOM SEARCH] Chat room data:`, {
        id: chatRoomId,
        tournamentId: chatRoomData.tournamentId,
        type: chatRoomData.type,
        title: chatRoomData.title,
        participantCount: chatRoomData.participantIds?.length || 0
      });
      return chatRoomId;
    }

    // 3차: 모든 채팅방에서 tournamentId 검색 (백업) - 더 엄격한 검색
    console.log(`🔍 [CHAT ROOM SEARCH] Searching all chat rooms...`);
    const allQuery = await db.collection('chatRooms')
      .where('tournamentId', '==', tournamentId)
      .limit(3) // 여러 결과 확인
      .get();

    if (!allQuery.empty) {
      console.log(`🔍 [CHAT ROOM SEARCH] Found ${allQuery.docs.length} chat rooms with tournament ID: ${tournamentId}`);
      
      // 각 채팅방 정보 로깅
      for (const doc of allQuery.docs) {
        const data = doc.data();
        console.log(`🔍 [CHAT ROOM SEARCH] Chat room candidate:`, {
          id: doc.id,
          tournamentId: data.tournamentId,
          type: data.type,
          title: data.title,
          participantCount: data.participantIds?.length || 0,
          createdAt: data.createdAt
        });
      }
      
      // 가장 최근에 생성된 채팅방 선택 (tournamentRecruitment 타입 우선)
      const sortedDocs = allQuery.docs.sort((a, b) => {
        const aData = a.data();
        const bData = b.data();
        
        // tournamentRecruitment 타입 우선
        if (aData.type === 'tournamentRecruitment' && bData.type !== 'tournamentRecruitment') {
          return -1;
        }
        if (bData.type === 'tournamentRecruitment' && aData.type !== 'tournamentRecruitment') {
          return 1;
        }
        
        // 생성 시간순으로 정렬 (최신 우선)
        const aTime = aData.createdAt?.toMillis() || 0;
        const bTime = bData.createdAt?.toMillis() || 0;
        return bTime - aTime;
      });
      
      const selectedChatRoom = sortedDocs[0];
      const chatRoomId = selectedChatRoom.id;
      const chatRoomData = selectedChatRoom.data();
      
      console.log(`✅ [CHAT ROOM SEARCH] Selected chat room from general search: ${chatRoomId}`);
      console.log(`🔍 [CHAT ROOM SEARCH] Selected chat room data:`, {
        id: chatRoomId,
        tournamentId: chatRoomData.tournamentId,
        type: chatRoomData.type,
        title: chatRoomData.title,
        participantCount: chatRoomData.participantIds?.length || 0,
        createdAt: chatRoomData.createdAt
      });
      
      return chatRoomId;
    }

    console.log(`⚠️ [CHAT ROOM SEARCH] No chat room found for tournament: ${tournamentId}`);
    return null;

  } catch (error) {
    console.error(`❌ [CHAT ROOM SEARCH] Error searching for tournament chat room: ${tournamentId}`, error);
    return null;
  }
}

/**
 * 수동으로 디스코드 채널 생성 (테스트용)
 */
export const createDiscordChannelsManually = onCall(async (request) => {
  try {
    console.log('🚀 createDiscordChannelsManually 함수 시작');
    console.log('📝 Request data:', JSON.stringify(request.data));
    console.log('👤 Request auth:', request.auth ? 'Authenticated' : 'Not authenticated');

    // 인증 확인
    if (!request.auth) {
      console.error('❌ Authentication required');
      throw new Error('Authentication required');
    }

    const { tournamentId } = request.data;
    console.log('🎯 Tournament ID:', tournamentId);

    if (!tournamentId) {
      console.error('❌ tournamentId is required');
      throw new Error('tournamentId is required');
    }

    // 토너먼트 데이터 가져오기
    console.log('📊 Fetching tournament data from Firestore...');
    const db = admin.firestore();
    const tournamentDoc = await db.collection('tournaments').doc(tournamentId).get();

    if (!tournamentDoc.exists) {
      console.error('❌ Tournament not found:', tournamentId);
      throw new Error('Tournament not found');
    }

    const tournamentData = tournamentDoc.data();
    console.log('✅ Tournament data loaded:', {
      title: tournamentData?.title || 'No title',
      participants: tournamentData?.participants?.length || 0,
      status: tournamentData?.status || 'No status'
    });
    
    // 이미 Discord 채널이 생성되었는지 확인
    if (tournamentData?.discordChannels) {
      console.log('✅ Discord channels already exist, returning existing invite links');
      
      const channelData = tournamentData.discordChannels;
      return {
        success: true,
        channelData: {
          textChannelInvite: channelData.textChannelInvite,
          voiceChannel1Invite: channelData.voiceChannel1Invite,
          voiceChannel2Invite: channelData.voiceChannel2Invite,
        },
      };
    }
    
    // 채널이 없는 경우에만 새로 생성
    console.log('🤖 No existing channels found, creating new ones...');
    const discordBot = getDiscordBot();
    
    console.log('🏗️ Creating Discord channels...');
    const channelData = await discordBot.createTournamentChannels(
      tournamentId,
      tournamentData?.title || `토너먼트 ${tournamentId}`,
      tournamentData?.participants || [],
      tournamentData // 토너먼트 전체 데이터 전달
    );

    if (!channelData) {
      console.error('❌ Failed to create Discord channels');
      throw new Error('Failed to create Discord channels');
    }

    console.log('✅ Discord channels created successfully:', {
      textChannelId: channelData.textChannelId,
      voiceChannel1Id: channelData.voiceChannel1Id,
      voiceChannel2Id: channelData.voiceChannel2Id
    });

    // 토너먼트 문서 업데이트
    console.log('📄 Updating tournament document...');
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

    // 초대링크 메시지 전송
    console.log('📱 Sending invite link to chat...');
    await sendDiscordInviteMessage(
      { id: tournamentId, name: tournamentData?.title, participants: tournamentData?.participants },
      channelData
    );

    console.log('🎉 createDiscordChannelsManually 함수 완료!');
    return {
      success: true,
      channelData: {
        textChannelInvite: channelData.textChannelInvite,
        voiceChannel1Invite: channelData.voiceChannel1Invite,
        voiceChannel2Invite: channelData.voiceChannel2Invite,
      },
    };

  } catch (error) {
    console.error('❌ Error in createDiscordChannelsManually:', error);
    console.error('📚 Error stack:', error instanceof Error ? error.stack : 'No stack trace');
    throw error;
  }
});

/**
 * 토너먼트 종료 시 디스코드 채널 정리
 */
export const onTournamentEnd = onDocumentUpdated(
  {
    document: 'tournaments/{tournamentId}',
    region: 'us-central1'
  },
  async (event) => {
    try {
      const tournamentId = event.params.tournamentId;
      const beforeData = event.data?.before.data();
      const afterData = event.data?.after.data();

      if (!beforeData || !afterData) {
        console.log('⚠️ Missing tournament data');
        return;
      }

      // 토너먼트가 종료된 경우
      if (beforeData?.status !== 'completed' && afterData?.status === 'completed') {
        console.log(`🏁 Tournament ${tournamentId} ended. Cleaning up Discord channels...`);

        const discordBot = getDiscordBot();
        const success = await discordBot.cleanupTournamentChannels(tournamentId);

        if (success) {
          console.log(`✅ Successfully cleaned up Discord channels for tournament: ${tournamentId}`);
        } else {
          console.error(`❌ Failed to clean up Discord channels for tournament: ${tournamentId}`);
        }
      }
    } catch (error) {
      console.error('❌ Error in onTournamentEnd:', error);
    }
  }
);

/**
 * 매 30분마다 실행되어 삭제 시간이 지난 Discord 채널들을 정리합니다
 */
export const cleanupExpiredDiscordChannels = onSchedule(
  {
    schedule: 'every 30 minutes',
    timeZone: 'Asia/Seoul',
  },
  async () => {
    try {
      console.log('🧹 Starting cleanup of expired Discord channels...');
      
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      
      // 삭제 시간이 지났고 아직 활성화된 채널들 찾기
      const expiredChannelsQuery = await db.collection('tournamentChannels')
        .where('isActive', '==', true)
        .where('deleteAt', '<=', now)
        .get();
      
      if (expiredChannelsQuery.empty) {
        console.log('✅ No expired Discord channels found');
        return;
      }
      
      console.log(`🎯 Found ${expiredChannelsQuery.docs.length} expired Discord channels to clean up`);
      
      const discordBot = getDiscordBot();
      let cleanedCount = 0;
      
      for (const doc of expiredChannelsQuery.docs) {
        try {
          const tournamentId = doc.id;
          
          console.log(`🗑️ Cleaning up expired channels for tournament: ${tournamentId}`);
          
          const success = await discordBot.cleanupTournamentChannels(tournamentId);
          
          if (success) {
            cleanedCount++;
            console.log(`✅ Successfully cleaned up channels for tournament: ${tournamentId}`);
          } else {
            console.error(`❌ Failed to clean up channels for tournament: ${tournamentId}`);
          }
          
        } catch (error) {
          console.error(`❌ Error cleaning up tournament ${doc.id}:`, error);
        }
      }
      
      console.log(`🧹 Cleanup complete! Cleaned ${cleanedCount}/${expiredChannelsQuery.docs.length} expired Discord channels`);
      
    } catch (error) {
      console.error('❌ Error in cleanupExpiredDiscordChannels:', error);
    }
  }
);