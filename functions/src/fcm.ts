import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * FCM 메시지 전송을 처리하는 함수
 * fcm_messages 컬렉션에 문서가 추가되면 자동으로 실행됨
 */
export const sendFCMMessage = functions.firestore
  .document('fcm_messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    
    if (!messageData.token) {
      console.error('❌ FCM 토큰이 없습니다');
      return;
    }
    
    try {
      const message: admin.messaging.Message = {
        token: messageData.token,
        notification: messageData.notification,
        data: messageData.data || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              badge: messageData.badge || 0,
              sound: 'default',
            },
          },
        },
      };
      
      const response = await messaging.send(message);
      console.log('✅ FCM 메시지 전송 성공:', response);
      
      // 전송 완료 표시
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        response: response,
      });
    } catch (error) {
      console.error('❌ FCM 메시지 전송 실패:', error);
      
      // 에러 기록
      await snap.ref.update({
        sent: false,
        error: error.toString(),
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * 예약된 평가 알림을 전송하는 스케줄 함수
 * 매 시간마다 실행됨
 */
export const sendScheduledEvaluationNotifications = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    console.log('🔔 예약된 평가 알림 확인 시작');
    
    const now = admin.firestore.Timestamp.now();
    
    try {
      // 예약 시간이 지난 미전송 알림 조회
      const notifications = await db
        .collection('scheduled_notifications')
        .where('sent', '==', false)
        .where('scheduledAt', '<=', now)
        .limit(100)
        .get();
      
      if (notifications.empty) {
        console.log('📭 전송할 예약 알림이 없습니다');
        return;
      }
      
      console.log(`📬 ${notifications.size}개의 알림을 전송합니다`);
      
      const batch = db.batch();
      const promises: Promise<any>[] = [];
      
      for (const doc of notifications.docs) {
        const data = doc.data();
        
        // 사용자의 FCM 토큰 가져오기
        const userPromise = db
          .collection('users')
          .doc(data.userId)
          .get()
          .then(async (userDoc) => {
            if (!userDoc.exists) return;
            
            const userData = userDoc.data();
            const fcmToken = userData?.fcmToken;
            
            if (!fcmToken) {
              console.log(`⚠️ 사용자 ${data.userId}의 FCM 토큰이 없습니다`);
              return;
            }
            
            // FCM 메시지 생성
            await db.collection('fcm_messages').add({
              token: fcmToken,
              notification: {
                title: '평가를 남겨주세요 📝',
                body: `${data.tournamentName} 경기에 대한 평가를 남겨주세요!`,
              },
              data: {
                type: 'evaluation_reminder',
                tournamentId: data.tournamentId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
              },
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            
            // 전송 완료 표시
            batch.update(doc.ref, { sent: true });
          });
        
        promises.push(userPromise);
      }
      
      await Promise.all(promises);
      await batch.commit();
      
      console.log('✅ 예약 알림 전송 완료');
    } catch (error) {
      console.error('❌ 예약 알림 전송 실패:', error);
    }
  });

/**
 * 24시간 경과한 미평가 토너먼트 처리
 * 매일 자정에 실행
 */
export const processExpiredEvaluations = functions.pubsub
  .schedule('every day 00:00')
  .timeZone('Asia/Seoul')
  .onRun(async (context) => {
    console.log('⏰ 만료된 평가 처리 시작');
    
    const cutoffTime = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000) // 24시간 전
    );
    
    try {
      // 24시간 이상 경과한 완료된 토너먼트 조회
      const expiredTournaments = await db
        .collection('tournaments')
        .where('status', '==', 'completed')
        .where('completedAt', '<=', cutoffTime)
        .where('evaluationProcessed', '==', false)
        .limit(50)
        .get();
      
      if (expiredTournaments.empty) {
        console.log('📭 처리할 만료된 토너먼트가 없습니다');
        return;
      }
      
      console.log(`📋 ${expiredTournaments.size}개의 토너먼트를 처리합니다`);
      
      for (const tournamentDoc of expiredTournaments.docs) {
        await processTournamentEvaluations(tournamentDoc);
      }
      
      console.log('✅ 만료된 평가 처리 완료');
    } catch (error) {
      console.error('❌ 만료된 평가 처리 실패:', error);
    }
  });

/**
 * 특정 토너먼트의 평가 처리
 */
async function processTournamentEvaluations(
  tournamentDoc: admin.firestore.DocumentSnapshot
): Promise<void> {
  const tournamentData = tournamentDoc.data();
  if (!tournamentData) return;
  
  const tournamentId = tournamentDoc.id;
  
  try {
    // 참가자 목록
    const participants = tournamentData.participants || [];
    const hostId = tournamentData.hostId;
    
    // 모든 관련 사용자
    const allUsers = [...participants, hostId];
    
    // 평가 완료 여부 확인
    const evaluations = await tournamentDoc.ref
      .collection('evaluations')
      .get();
    
    const evaluatedBy = new Set(
      evaluations.docs.map(e => e.data().fromUserId)
    );
    
    // 평가율 계산
    const evaluationRate = evaluatedBy.size / allUsers.length;
    
    // 평가율이 30% 미만인 경우 점수 반영 비율 감소
    const scoreMultiplier = evaluationRate < 0.3 ? 0.5 : 1.0;
    
    // 미평가 사용자들의 평가 참여율 감소
    const batch = db.batch();
    
    for (const userId of allUsers) {
      if (!evaluatedBy.has(userId)) {
        const userRef = db.collection('users').doc(userId);
        
        // 평가 미참여로 인한 평가율 감소
        batch.update(userRef, {
          evaluationRate: admin.firestore.FieldValue.increment(-0.05),
        });
      }
    }
    
    // 토너먼트를 평가 처리 완료로 표시
    batch.update(tournamentDoc.ref, {
      evaluationProcessed: true,
      evaluationRate: evaluationRate,
      scoreMultiplier: scoreMultiplier,
    });
    
    await batch.commit();
    
    console.log(`✅ 토너먼트 ${tournamentId} 평가 처리 완료`);
  } catch (error) {
    console.error(`❌ 토너먼트 ${tournamentId} 평가 처리 실패:`, error);
  }
}

/**
 * 사용자의 FCM 토큰 업데이트
 */
export const updateFCMToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      '인증이 필요합니다.'
    );
  }
  
  const { token } = data;
  const userId = context.auth.uid;
  
  if (!token) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'FCM 토큰이 필요합니다.'
    );
  }
  
  try {
    await db.collection('users').doc(userId).update({
      fcmToken: token,
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return { success: true };
  } catch (error) {
    console.error('FCM 토큰 업데이트 실패:', error);
    throw new functions.https.HttpsError(
      'internal',
      'FCM 토큰 업데이트에 실패했습니다.'
    );
  }
}); 