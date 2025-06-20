import {onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {onCall} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';
import { getDiscordBot, TournamentChannelData } from './discord-bot';

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

      // 10명이 된 경우에만 디스코드 채널 생성 시도
      if (beforeParticipantCount < 10 && afterParticipantCount >= 10) {
        console.log(`🎯 Tournament ${tournamentId} reached ${afterParticipantCount} participants! Checking Discord channels...`);

        // 해당 토너먼트 ID의 Discord 채널이 실제로 존재하는지 확인
        const discordBot = getDiscordBot();
        const hasValidTournamentChannels = await discordBot.checkTournamentChannelsExist(tournamentId);
        console.log(`📁 Valid Discord channels exist for tournament ${tournamentId}: ${hasValidTournamentChannels}`);

        // 해당 토너먼트의 유효한 Discord 채널이 없다면 새로 생성
        if (!hasValidTournamentChannels) {
          console.log(`🚀 Creating new Discord channels for tournament: ${tournamentId}...`);

          const tournamentData = {
            id: tournamentId,
            name: afterData.title || afterData.name || `토너먼트 ${tournamentId}`,
            participants: afterData.participants || [],
            startsAt: afterData.startsAt,
            hostName: afterData.hostName,
            hostNickname: afterData.hostNickname,
            gameFormat: afterData.gameFormat,
            ...afterData,
          };

          console.log(`🤖 Initializing Discord bot for tournament ${tournamentId}...`);
          console.log(`📅 Tournament info:`, {
            name: tournamentData.name,
            startsAt: tournamentData.startsAt,
            hostName: tournamentData.hostName,
            gameFormat: tournamentData.gameFormat
          });
          
          // 디스코드 채널 생성 (토너먼트 데이터 전달)
          console.log('🏗️ Attempting to create Discord channels...');
          
          const channelData = await discordBot.createTournamentChannels(
            tournamentId,
            tournamentData.name,
            tournamentData.participants,
            tournamentData // 토너먼트 전체 데이터 전달
          );

          if (channelData) {
            console.log('✅ Discord channels created successfully!');
            console.log('📝 Channel data:', {
              textChannelId: channelData.textChannelId,
              voiceChannel1Id: channelData.voiceChannel1Id,
              voiceChannel2Id: channelData.voiceChannel2Id
            });

            // 앱에 시스템 메시지 전송
            console.log('📱 Sending notification to app...');
            await sendDiscordChannelNotificationToApp(tournamentData, channelData);
            
            // 토너먼트 문서에 디스코드 채널 정보 업데이트
            console.log('📄 Updating tournament document...');
            await event.data?.after.ref.update({
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

            console.log(`🎉 Successfully created Discord channels for tournament: ${tournamentId}`);
          } else {
            console.error(`❌ Failed to create Discord channels for tournament: ${tournamentId}`);
          }
        } else {
          console.log(`✅ Valid Discord channels already exist for tournament ${tournamentId}`);
          
          // 기존 Discord 채널이 있어도 새로운 참가자를 위해 알림 재전송
          console.log(`📱 Sending existing Discord channel notification for tournament ${tournamentId}...`);
          
          const tournamentData = {
            id: tournamentId,
            name: afterData.title || afterData.name || `토너먼트 ${tournamentId}`,
            participants: afterData.participants || [],
            ...afterData,
          };

          // 기존 Discord 채널 정보를 사용해서 알림 전송
          const existingChannelData = {
            textChannelInvite: afterData.discordChannels?.textChannelInvite,
            voiceChannel1Invite: afterData.discordChannels?.voiceChannel1Invite,
            voiceChannel2Invite: afterData.discordChannels?.voiceChannel2Invite,
          };

          // 기존 채널 정보가 있는 경우에만 알림 전송
          if (existingChannelData.textChannelInvite) {
            await sendDiscordChannelNotificationToApp(tournamentData, existingChannelData as any);
            console.log(`📤 Resent Discord channel notification for tournament ${tournamentId}`);
          } else {
            console.log(`⚠️ No existing channel invite links found for tournament ${tournamentId}`);
          }
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
 * 앱에 디스코드 채널 생성 알림 메시지 전송
 */
async function sendDiscordChannelNotificationToApp(
  tournamentData: any,
  channelData: TournamentChannelData
): Promise<void> {
  try {
    console.log(`📱 [DISCORD NOTIFICATION] Starting notification for tournament: ${tournamentData.id}`);
    console.log(`📱 [DISCORD NOTIFICATION] Tournament name: ${tournamentData.name}`);
    console.log(`📱 [DISCORD NOTIFICATION] Channel data:`, {
      textChannelInvite: channelData.textChannelInvite,
      voiceChannel1Invite: channelData.voiceChannel1Invite,
      voiceChannel2Invite: channelData.voiceChannel2Invite
    });

    const db = admin.firestore();
    
    // 토너먼트 채팅방 ID 가져오기 (강화된 검색)
    console.log(`🔍 [DISCORD NOTIFICATION] Searching for chat room for tournament: ${tournamentData.id}`);
    const tournamentChatId = await getTournamentChatRoomId(tournamentData.id);
    
    if (!tournamentChatId) {
      console.error(`❌ [DISCORD NOTIFICATION] No chat room found for tournament: ${tournamentData.id}`);
      console.log(`🔍 [DISCORD NOTIFICATION] Attempting to create chat room...`);
      
      // 채팅방이 없다면 생성 시도
      const newChatRoomId = await createTournamentChatRoom(tournamentData);
      if (!newChatRoomId) {
        console.error(`❌ [DISCORD NOTIFICATION] Failed to create chat room for tournament: ${tournamentData.id}`);
        return;
      }
      console.log(`✅ [DISCORD NOTIFICATION] Created new chat room: ${newChatRoomId}`);
    }

    // 최종 채팅방 ID 확인
    const finalChatId = tournamentChatId || await getTournamentChatRoomId(tournamentData.id);
    if (!finalChatId) {
      console.error(`❌ [DISCORD NOTIFICATION] Still no chat room available for tournament: ${tournamentData.id}`);
      return;
    }

    console.log(`✅ [DISCORD NOTIFICATION] Using chat room: ${finalChatId}`);

    // 시스템 메시지 생성
    const messageContent = createDiscordChannelMessage(tournamentData.name, channelData);
    console.log(`📝 [DISCORD NOTIFICATION] Generated message content (length: ${messageContent.length})`);

    // Flutter 앱과 동일한 메시지 구조 사용
    const systemMessage = {
      chatRoomId: finalChatId,
      senderId: 'system',
      senderName: '시스템',
      senderProfileImageUrl: null,
      text: messageContent, // content -> text로 변경
      readStatus: {},
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        isSystem: true, // Flutter 앱 시스템 메시지 식별용
        type: 'discord_channels',
        tournamentId: tournamentData.id,
        tournamentName: tournamentData.name,
        channelData: {
          textChannelInvite: channelData.textChannelInvite,
          voiceChannel1Invite: channelData.voiceChannel1Invite,
          voiceChannel2Invite: channelData.voiceChannel2Invite,
        },
      },
    };

    console.log(`💾 [DISCORD NOTIFICATION] Adding message to messages collection: ${finalChatId}`);
    console.log(`💾 [DISCORD NOTIFICATION] Message content (first 100 chars): ${messageContent.substring(0, 100)}...`);
    console.log(`💾 [DISCORD NOTIFICATION] System message structure:`, {
      chatRoomId: finalChatId,
      senderId: systemMessage.senderId,
      senderName: systemMessage.senderName,
      textLength: systemMessage.text.length,
      hasMetadata: !!systemMessage.metadata,
      metadataType: systemMessage.metadata?.type,
      isSystem: systemMessage.metadata?.isSystem,
    });
    
    try {
      // Firebase Admin SDK 확인
      console.log(`🔐 [DISCORD NOTIFICATION] Admin app initialized: ${admin.apps.length > 0}`);
      console.log(`🔐 [DISCORD NOTIFICATION] Using admin.firestore()`);
      
      // Flutter 앱과 동일한 messages 컬렉션에 저장
      const messageRef = await db.collection('messages').add(systemMessage);
      console.log(`✅ [DISCORD NOTIFICATION] Message added with ID: ${messageRef.id}`);
      
      // 저장된 메시지 즉시 검증
      console.log(`🔍 [DISCORD NOTIFICATION] Verifying saved message...`);
      const savedMessage = await messageRef.get();
      if (savedMessage.exists) {
        const savedData = savedMessage.data();
        console.log(`✅ [DISCORD NOTIFICATION] Message verified - ID: ${savedMessage.id}`);
        console.log(`🔍 [DISCORD NOTIFICATION] Verified data:`, {
          chatRoomId: savedData?.chatRoomId,
          senderId: savedData?.senderId,
          textLength: savedData?.text?.length || 0,
          hasMetadata: !!savedData?.metadata,
          metadataType: savedData?.metadata?.type,
          isSystem: savedData?.metadata?.isSystem,
        });
      } else {
        console.error(`❌ [DISCORD NOTIFICATION] CRITICAL: Message was not saved! ID: ${messageRef.id}`);
        throw new Error(`Failed to save Discord notification message`);
      }
    } catch (error) {
      console.error(`❌ [DISCORD NOTIFICATION] CRITICAL ERROR saving message:`, error);
      console.error(`❌ [DISCORD NOTIFICATION] Error type: ${error instanceof Error ? error.name : typeof error}`);
      console.error(`❌ [DISCORD NOTIFICATION] Error message: ${error instanceof Error ? error.message : String(error)}`);
      console.error(`❌ [DISCORD NOTIFICATION] Error stack:`, error instanceof Error ? error.stack : 'No stack');
      throw error; // 에러를 다시 던져서 함수 실패로 표시
    }

    // 채팅방 lastMessage 업데이트
    console.log(`🔄 [DISCORD NOTIFICATION] Updating chat room last message...`);
    await db.collection('chatRooms').doc(finalChatId).update({
      lastMessageText: systemMessage.text.substring(0, 100) + '...', // lastMessage -> lastMessageText로 변경
      lastMessageTime: systemMessage.timestamp,
      lastMessageSenderId: systemMessage.senderId,
    });

    console.log(`🎉 [DISCORD NOTIFICATION] Successfully sent Discord channel notification to chat room: ${finalChatId}`);

  } catch (error) {
    console.error('❌ [DISCORD NOTIFICATION] Error sending Discord channel notification to app:', error);
    console.error('📚 [DISCORD NOTIFICATION] Error stack:', error instanceof Error ? error.stack : 'No stack trace');
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
 * 토너먼트 채팅방 생성
 */
async function createTournamentChatRoom(tournamentData: any): Promise<string | null> {
  try {
    console.log(`🏗️ [CHAT ROOM CREATE] Creating chat room for tournament: ${tournamentData.id}`);
    const db = admin.firestore();

    const chatRoomData = {
      type: 'tournamentRecruitment',
      tournamentId: tournamentData.id,
      tournamentName: tournamentData.name || `토너먼트 ${tournamentData.id}`,
      participants: tournamentData.participants || [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: '',
      lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSenderId: '',
    };

    console.log(`💾 [CHAT ROOM CREATE] Chat room data:`, chatRoomData);
    const newChatRoom = await db.collection('chatRooms').add(chatRoomData);
    console.log(`✅ [CHAT ROOM CREATE] Created new chat room: ${tournamentData.id} → ${newChatRoom.id}`);
    
    return newChatRoom.id;

  } catch (error) {
    console.error(`❌ [CHAT ROOM CREATE] Error creating tournament chat room: ${tournamentData.id}`, error);
    return null;
  }
}

/**
 * 디스코드 채널 안내 메시지 생성 (Flutter 앱 호환)
 */
function createDiscordChannelMessage(tournamentName: string, channelData: TournamentChannelData): string {
  return `🎯 ${tournamentName} 토너먼트 Discord 채널이 생성되었습니다!

💬 텍스트 채팅
${channelData.textChannelInvite}

🎤 음성 채팅
A팀: ${channelData.voiceChannel1Invite}
B팀: ${channelData.voiceChannel2Invite}

📱 링크를 터치하여 Discord 채널에 입장하세요!`;
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
    
    // 디스코드 채널 생성
    console.log('🤖 Initializing Discord bot...');
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

    // 앱에 알림 전송
    console.log('📱 Sending notification to app...');
    await sendDiscordChannelNotificationToApp(
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