/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onCall, onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
const {v4: uuidv4} = require("uuid");

admin.initializeApp();

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Toss Payments 관련 인터페이스 정의
interface PaymentData {
  orderId: string;
  userId: string;
  amount: number;
  creditAmount: number;
  status: "pending" | "completed" | "failed";
  createdAt: admin.firestore.Timestamp;
  paymentKey?: string;
  errorCode?: string;
  errorMessage?: string;
}

// 결제 정보 생성 함수
export const createPayment = onCall(async (request) => {
  try {
    const {amount, creditAmount} = request.data;
    const userId = request.auth?.uid;

    if (!userId) {
      throw new Error("인증되지 않은 사용자입니다.");
    }

    if (!amount || !creditAmount || amount <= 0 || creditAmount <= 0) {
      throw new Error("유효하지 않은 금액입니다.");
    }

    const orderId = uuidv4();
    const paymentData: PaymentData = {
      orderId,
      userId,
      amount,
      creditAmount,
      status: "pending",
      createdAt: admin.firestore.Timestamp.now(),
    };

    // Firestore에 결제 정보 저장
    await admin.firestore()
      .collection("payments")
      .doc(orderId)
      .set(paymentData);

    logger.info("Payment created", {orderId, userId, amount, creditAmount});

    return {
      success: true,
      orderId,
    };
  } catch (error) {
    logger.error("Error creating payment", error);
    throw new Error(`결제 정보 생성 실패: ${error instanceof Error ? error.message : "알 수 없는 오류"}`);
  }
});

// 결제 승인 함수
export const approvePayment = onCall(async (request) => {
  try {
    const {orderId, paymentKey, amount} = request.data;
    const userId = request.auth?.uid;

    if (!userId) {
      throw new Error("인증되지 않은 사용자입니다.");
    }

    if (!orderId || !paymentKey || !amount) {
      throw new Error("필수 결제 정보가 누락되었습니다.");
    }

    // Firestore에서 결제 정보 조회
    const paymentDoc = await admin.firestore()
      .collection("payments")
      .doc(orderId)
      .get();

    if (!paymentDoc.exists) {
      throw new Error("결제 정보를 찾을 수 없습니다.");
    }

    const paymentData = paymentDoc.data() as PaymentData;

    if (paymentData.userId !== userId) {
      throw new Error("권한이 없습니다.");
    }

    if (paymentData.status !== "pending") {
      throw new Error("이미 처리된 결제입니다.");
    }

    if (paymentData.amount !== amount) {
      throw new Error("결제 금액이 일치하지 않습니다.");
    }

    // Toss Payments API 호출 (실제 결제 승인)
    const tossSecretKey = "test_sk_zXLkKEypNArWmo50nX3lmeaxYG5R"; // 테스트 키
    const authHeader = Buffer.from(`${tossSecretKey}:`).toString("base64");

    const tossResponse = await fetch("https://api.tosspayments.com/v1/payments/confirm", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${authHeader}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        paymentKey,
        orderId,
        amount,
      }),
    });

    const tossResult = await tossResponse.json();

    if (!tossResponse.ok) {
      logger.error("Toss payment approval failed", tossResult);
      
      // 결제 실패 정보 업데이트
              await admin.firestore()
          .collection("payments")
          .doc(orderId)
          .update({
            status: "failed",
            errorCode: tossResult.code,
            errorMessage: tossResult.message,
            paymentKey,
            updatedAt: admin.firestore.Timestamp.now(),
          });

      throw new Error(`결제 승인 실패: ${tossResult.message}`);
    }

    // 결제 성공 처리
    await admin.firestore().runTransaction(async (transaction) => {
      // 사용자 정보 조회
      const userRef = admin.firestore().collection("users").doc(userId);
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw new Error("사용자 정보를 찾을 수 없습니다.");
      }

      const userData = userDoc.data();
      const currentCredits = userData?.credits || 0;
      const newCredits = currentCredits + paymentData.creditAmount;

      // 사용자 크레딧 업데이트
      transaction.update(userRef, {
        credits: newCredits,
        updatedAt: admin.firestore.Timestamp.now(),
      });

      // 결제 정보 업데이트
      transaction.update(paymentDoc.ref, {
        status: "completed",
        paymentKey,
        updatedAt: admin.firestore.Timestamp.now(),
      });
    });

    logger.info("Payment approved successfully", {orderId, userId, amount, paymentKey});

    return {
      success: true,
      message: "결제가 성공적으로 완료되었습니다.",
    };
  } catch (error) {
    logger.error("Error approving payment", error);
    throw new Error(`결제 승인 실패: ${error instanceof Error ? error.message : "알 수 없는 오류"}`);
  }
});

// Toss Payments 웹훅 처리 함수
export const handleTossWebhook = onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const webhookData = req.body;
    logger.info("Toss webhook received", webhookData);

    // 웹훅 데이터 검증 및 처리 로직
    if (webhookData.eventType === "PAYMENT_STATUS_CHANGED") {
      const {orderId, status, paymentKey} = webhookData.data;

      if (status === "DONE") {
        // 결제 완료 처리 (이미 approvePayment에서 처리되므로 로그만 남김)
        logger.info("Payment completed via webhook", {orderId, paymentKey});
      } else if (status === "CANCELED" || status === "PARTIAL_CANCELED") {
        // 결제 취소 처리
        await admin.firestore()
          .collection("payments")
          .doc(orderId)
          .update({
            status: "failed",
            errorCode: "CANCELED",
            errorMessage: "결제가 취소되었습니다.",
            updatedAt: admin.firestore.Timestamp.now(),
          });

        logger.info("Payment canceled via webhook", {orderId, paymentKey});
      }
    }

    res.status(200).send("OK");
  } catch (error) {
    logger.error("Error handling Toss webhook", error);
    res.status(500).send("Internal Server Error");
  }
});

export {
  sendFCMMessage,
  sendScheduledEvaluationNotifications,
  processExpiredEvaluations,
  updateFCMToken
} from './fcm';
