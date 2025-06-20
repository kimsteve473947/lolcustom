import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onCall} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

interface FCMMessage {
  id: string;
  recipients: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
  createdAt: admin.firestore.Timestamp;
  status: 'pending' | 'sent' | 'failed';
}

export const sendFCMMessage = onDocumentCreated(
  'fcm_messages/{messageId}',
  async (event) => {
    try {
      const messageData = event.data?.data() as FCMMessage;
      
      if (!messageData) {
        console.log('⚠️ No message data found');
        return;
      }

      console.log('📱 Processing FCM message:', messageData.id);

      const messaging = admin.messaging();
      const results = [];

      // 각 수신자에게 개별적으로 메시지 전송
      for (const recipientToken of messageData.recipients) {
        try {
          const message = {
            notification: {
              title: messageData.title,
              body: messageData.body,
            },
            data: messageData.data || {},
            token: recipientToken,
          };

          const response = await messaging.send(message);
          results.push({
            token: recipientToken,
            success: true,
            messageId: response,
          });

          console.log('✅ FCM message sent successfully:', response);
        } catch (error) {
          console.error('❌ Failed to send FCM message:', error);
          results.push({
            token: recipientToken,
            success: false,
            error: (error as Error).toString(),
          });
        }
      }

      // 결과를 Firestore에 업데이트
      await event.data?.ref.update({
        status: 'sent',
        results: results,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      console.error('❌ Error processing FCM message:', error);
    }
  }
);

export const sendScheduledEvaluationNotifications = onSchedule(
  'every 1 hours',
  async () => {
    try {
      console.log('🔄 Running scheduled evaluation notifications...');

      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      const oneHourFromNow = admin.firestore.Timestamp.fromMillis(
        now.toMillis() + (60 * 60 * 1000)
      );

      // 1시간 후에 평가가 마감되는 토너먼트 찾기
      const upcomingEvaluations = await db.collection('tournaments')
        .where('status', '==', 'completed')
        .where('evaluationDeadline', '>=', now)
        .where('evaluationDeadline', '<=', oneHourFromNow)
        .get();

      for (const tournamentDoc of upcomingEvaluations.docs) {
        const tournament = tournamentDoc.data();
        
        // 평가하지 않은 참가자들 찾기
        const evaluationsSnapshot = await db.collection('evaluations')
          .where('tournamentId', '==', tournamentDoc.id)
          .get();

        const evaluatedParticipants = new Set(
          evaluationsSnapshot.docs.map(doc => doc.data().evaluatorId)
        );

        const unevaluatedParticipants = tournament.participants.filter(
          (participantId: string) => !evaluatedParticipants.has(participantId)
        );

        if (unevaluatedParticipants.length > 0) {
          // FCM 토큰 가져오기
          const tokensQuery = await db.collection('users')
            .where(admin.firestore.FieldPath.documentId(), 'in', unevaluatedParticipants)
            .get();

          const tokens = tokensQuery.docs
            .map(doc => doc.data().fcmToken)
            .filter(token => token);

          if (tokens.length > 0) {
            // FCM 메시지 문서 생성
            await db.collection('fcm_messages').add({
              recipients: tokens,
              title: '⏰ 평가 마감 1시간 전!',
              body: `${tournament.name} 토너먼트의 평가 마감이 1시간 후입니다. 지금 평가를 완료해주세요!`,
              data: {
                type: 'evaluation_reminder',
                tournamentId: tournamentDoc.id,
                tournamentName: tournament.name,
              },
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              status: 'pending',
            });

            console.log(`📱 Scheduled evaluation reminder for tournament: ${tournament.name}`);
          }
        }
      }

      console.log('✅ Scheduled evaluation notifications completed');
    } catch (error) {
      console.error('❌ Error in scheduled evaluation notifications:', error);
    }
  }
);

export const processExpiredEvaluations = onSchedule(
  {
    schedule: 'every day 00:00',
    region: 'asia-northeast1'
  },
  async () => {
    try {
      console.log('🔄 Processing expired evaluations...');

      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();

      // 평가 기간이 만료된 토너먼트 찾기
      const expiredTournaments = await db.collection('tournaments')
        .where('status', '==', 'completed')
        .where('evaluationDeadline', '<', now)
        .where('evaluationsProcessed', '==', false)
        .get();

      for (const tournamentDoc of expiredTournaments.docs) {
        const tournament = tournamentDoc.data();

        // 해당 토너먼트의 모든 평가 가져오기
        const evaluationsSnapshot = await db.collection('evaluations')
          .where('tournamentId', '==', tournamentDoc.id)
          .get();

        // 평가하지 않은 참가자들에게 패널티 적용
        const evaluatedParticipants = new Set(
          evaluationsSnapshot.docs.map(doc => doc.data().evaluatorId)
        );

        const unevaluatedParticipants = tournament.participants.filter(
          (participantId: string) => !evaluatedParticipants.has(participantId)
        );

        // 패널티 적용 및 알림
        for (const participantId of unevaluatedParticipants) {
          try {
            // 사용자의 신뢰도 점수 감소
            const userRef = db.collection('users').doc(participantId);
            await db.runTransaction(async (transaction) => {
              const userDoc = await transaction.get(userRef);
              const userData = userDoc.data();
              
              if (userData) {
                const currentTrustScore = userData.trustScore || 100;
                const newTrustScore = Math.max(0, currentTrustScore - 10); // 10점 차감
                
                transaction.update(userRef, {
                  trustScore: newTrustScore,
                  lastPenaltyAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              }
            });

            console.log(`⚠️ Applied penalty to user ${participantId} for not evaluating`);
          } catch (error) {
            console.error(`❌ Error applying penalty to user ${participantId}:`, error);
          }
        }

        // 토너먼트를 처리 완료로 마킹
        await tournamentDoc.ref.update({
          evaluationsProcessed: true,
          evaluationsProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Processed expired evaluations for tournament: ${tournament.name}`);
      }

      console.log('✅ Expired evaluations processing completed');
    } catch (error) {
      console.error('❌ Error processing expired evaluations:', error);
    }
  }
);

export const updateFCMToken = onCall(async (request) => {
  try {
    // 인증 확인
    if (!request.auth) {
      throw new Error('Authentication required');
    }

    const { token } = request.data;
    const userId = request.auth.uid;

    if (!token) {
      throw new Error('FCM token is required');
    }

    // 사용자 문서에 FCM 토큰 업데이트
    const db = admin.firestore();
    await db.collection('users').doc(userId).update({
      fcmToken: token,
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ FCM token updated for user: ${userId}`);

    return {
      success: true,
      message: 'FCM token updated successfully',
    };
  } catch (error) {
    console.error('❌ Error updating FCM token:', error);
    throw error;
  }
}); 