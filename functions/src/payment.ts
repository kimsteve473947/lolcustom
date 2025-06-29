import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';
import { v4 as uuidv4 } from 'uuid';

const db = admin.firestore();

// 토스페이먼츠 API 설정
const TOSS_API_BASE_URL = 'https://api.tosspayments.com/v1';

// 환경변수에서 토스 시크릿 키 가져오기
function getTossSecretKey(): string {
  const secretKey = process.env.TOSS_SECRET_KEY;
  
  if (!secretKey) {
    throw new Error('토스페이먼츠 시크릿 키가 설정되지 않았습니다. TOSS_SECRET_KEY 환경변수를 설정하세요.');
  }
  
  return secretKey;
}

// 토스페이먼츠 API 헤더 생성
function getTossApiHeaders(): Record<string, string> {
  const secretKey = getTossSecretKey();
  const encodedKey = Buffer.from(`${secretKey}:`).toString('base64');
  
  return {
    'Authorization': `Basic ${encodedKey}`,
    'Content-Type': 'application/json',
  };
}

// 인증 토큰 검증 함수
async function verifyAuthToken(authHeader: string): Promise<string> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new functions.https.HttpsError('unauthenticated', '인증 토큰이 없습니다.');
  }

  const token = authHeader.substring(7); // 'Bearer ' 제거
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    return decodedToken.uid;
  } catch (error) {
    console.error('Token verification failed:', error);
    throw new functions.https.HttpsError('unauthenticated', '유효하지 않은 인증 토큰입니다.');
  }
}

// 결제 생성 함수 - onRequest 방식
export const createPayment = functions.https.onRequest(async (req: any, res: any) => {
  try {
    // CORS 설정
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    console.log('✅ createPayment called via onRequest');
    console.log('Request headers:', req.headers);
    console.log('Request body:', req.body);
    
    // 인증 토큰 검증
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      res.status(401).json({ error: '인증 토큰이 필요합니다.' });
      return;
    }

    const userId = await verifyAuthToken(authHeader);
    console.log(`✅ User authenticated: ${userId}`);

    const { amount, creditAmount } = req.body;
    
    console.log(`Creating payment for user: ${userId}, amount: ${amount}, creditAmount: ${creditAmount}`);

    // 입력값 검증
    if (!amount || !creditAmount || amount <= 0 || creditAmount <= 0) {
      res.status(400).json({ error: '올바른 금액을 입력해주세요.' });
      return;
    }

    if (amount !== creditAmount) {
      res.status(400).json({ error: '결제 금액과 크레딧 금액이 일치하지 않습니다.' });
      return;
    }

    // 주문 ID 생성 (고유한 값)
    const orderId = `payment_${userId}_${Date.now()}_${uuidv4().substring(0, 8)}`;

    // 결제 정보를 Firestore에 저장
    const paymentDoc = {
      userId,
      amount,
      creditAmount,
      orderId,
      status: 0, // PaymentStatus.initiated
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      provider: 'toss_payments',
    };

    await db.collection('payments').doc(orderId).set(paymentDoc);

    console.log(`✅ Payment created successfully: ${orderId} for user: ${userId}, amount: ${amount}`);

    res.status(200).json({
      success: true,
      orderId,
      message: '결제 정보가 생성되었습니다.',
    });

  } catch (error) {
    console.error('❌ Error in createPayment:', error);
    
    if (error instanceof functions.https.HttpsError) {
      res.status(error.httpErrorCode.status).json({ error: error.message });
    } else {
      res.status(500).json({ error: '결제 생성 중 오류가 발생했습니다.' });
    }
  }
});

// 결제 승인 함수 - 간단한 v2 방식
export const approvePayment = functions.https.onCall(async (data: any, context: any) => {
  try {
    console.log('approvePayment called with data:', data);
    
    // 인증 확인
    if (!context.auth || !context.auth.uid) {
      throw new functions.https.HttpsError('unauthenticated', '로그인이 필요합니다.');
    }

    const userId = context.auth.uid;
    const { orderId, paymentKey, amount } = data;

    console.log(`🔄 Approving payment for user: ${userId}, orderId: ${orderId}`);

    // 입력값 검증
    if (!orderId || !paymentKey || !amount) {
      throw new functions.https.HttpsError('invalid-argument', '필수 파라미터가 누락되었습니다.');
    }

    // Firestore에서 결제 정보 확인
    const paymentDoc = await db.collection('payments').doc(orderId).get();
    
    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', '결제 정보를 찾을 수 없습니다.');
    }

    const paymentData = paymentDoc.data()!;

    // 결제 정보 검증
    if (paymentData.userId !== userId) {
      throw new functions.https.HttpsError('permission-denied', '결제 권한이 없습니다.');
    }

    if (paymentData.amount !== amount) {
      throw new functions.https.HttpsError('invalid-argument', '결제 금액이 일치하지 않습니다.');
    }

    if (paymentData.status !== 0) { // PaymentStatus.initiated
      throw new functions.https.HttpsError('failed-precondition', '이미 처리된 결제입니다.');
    }

    try {
      // 토스페이먼츠 결제 승인 API 호출
      const tossResponse = await axios.post(
        `${TOSS_API_BASE_URL}/payments/confirm`,
        {
          paymentKey,
          orderId,
          amount,
        },
        {
          headers: getTossApiHeaders(),
        }
      );

      console.log('✅ Toss payment approval response:', tossResponse.data);

      // 트랜잭션으로 결제 완료 처리 및 크레딧 지급
      await db.runTransaction(async (transaction) => {
        // 결제 상태 업데이트
        const paymentRef = db.collection('payments').doc(orderId);
        transaction.update(paymentRef, {
          status: 1, // PaymentStatus.completed
          paymentKey,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 사용자 크레딧 업데이트
        const userRef = db.collection('users').doc(userId);
        const userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw new Error('사용자 정보를 찾을 수 없습니다.');
        }

        const userData = userDoc.data()!;
        const currentCredits = userData.credits || 0;
        const newCredits = currentCredits + paymentData.creditAmount;

        transaction.update(userRef, {
          credits: newCredits,
        });

        console.log(`💰 Credits updated for user ${userId}: ${currentCredits} -> ${newCredits}`);
      });

      return {
        success: true,
        message: '결제가 성공적으로 완료되었습니다.',
        paymentKey,
        orderId,
      };

    } catch (tossError: any) {
      console.error('❌ Toss payment approval failed:', tossError.response?.data || tossError.message);

      // 결제 실패 상태로 업데이트
      await db.collection('payments').doc(orderId).update({
        status: 2, // PaymentStatus.failed
        errorCode: tossError.response?.data?.code,
        errorMessage: tossError.response?.data?.message || tossError.message,
      });

      throw new functions.https.HttpsError(
        'internal',
        `결제 승인에 실패했습니다: ${tossError.response?.data?.message || tossError.message}`
      );
    }

  } catch (error) {
    console.error('❌ Error in approvePayment:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', '결제 승인 중 오류가 발생했습니다.');
  }
});

// 토스페이먼츠 웹훅 처리 함수 (선택사항)
export const handleTossWebhook = functions.https.onRequest(async (req: any, res: any) => {
  try {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const { eventType, data } = req.body;

    console.log('Toss webhook received:', { eventType, data });

    // 결제 상태 변경 웹훅 처리
    if (eventType === 'PAYMENT_STATUS_CHANGED') {
      const { orderId, paymentKey, status } = data;

      if (orderId && paymentKey) {
        const paymentRef = db.collection('payments').doc(orderId);
        const paymentDoc = await paymentRef.get();

        if (paymentDoc.exists) {
          const updateData: any = {
            paymentKey,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // 토스 상태에 따른 내부 상태 매핑
          switch (status) {
            case 'DONE':
              updateData.status = 1; // PaymentStatus.completed
              break;
            case 'CANCELED':
              updateData.status = 3; // PaymentStatus.cancelled
              break;
            case 'FAILED':
              updateData.status = 2; // PaymentStatus.failed
              break;
          }

          await paymentRef.update(updateData);
          console.log(`Payment status updated via webhook: ${orderId} -> ${status}`);
        }
      }
    }

    res.status(200).send('OK');

  } catch (error) {
    console.error('Error in handleTossWebhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

// 결제 상태 조회 함수
export const getPaymentStatus = functions.https.onCall(async (data: any, context: any) => {
  try {
    // 인증 확인
    if (!context.auth || !context.auth.uid) {
      throw new functions.https.HttpsError('unauthenticated', '로그인이 필요합니다.');
    }

    const userId = context.auth.uid;
    const { orderId } = data;

    if (!orderId) {
      throw new functions.https.HttpsError('invalid-argument', '주문 ID가 필요합니다.');
    }

    // Firestore에서 결제 정보 조회
    const paymentDoc = await db.collection('payments').doc(orderId).get();
    
    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', '결제 정보를 찾을 수 없습니다.');
    }

    const paymentData = paymentDoc.data()!;

    // 권한 확인
    if (paymentData.userId !== userId) {
      throw new functions.https.HttpsError('permission-denied', '결제 조회 권한이 없습니다.');
    }

    return {
      success: true,
      payment: paymentData,
    };

  } catch (error) {
    console.error('Error in getPaymentStatus:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', '결제 상태 조회 중 오류가 발생했습니다.');
  }
}); 
