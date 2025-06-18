import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";
import { v4 as uuidv4 } from "uuid";

admin.initializeApp();
const db = admin.firestore();

// Toss Payments Secret Key - Firebase 환경 변수에 저장해야 합니다.
// ex) firebase functions:config:set toss.secret_key="YOUR_SECRET_KEY"
const TOSS_SECRET_KEY = functions.config().toss.secret_key;

// 1. 결제 생성 (Callable Function)
export const createPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const userId = context.auth.uid;
  const amount = data.amount; // ex: 5000
  const creditAmount = data.creditAmount; // ex: 5000

  if (!amount || !creditAmount || amount <= 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a valid 'amount' and 'creditAmount'."
    );
  }

  const orderId = `credit_${uuidv4()}`;

  try {
    await db.collection("payments").doc(orderId).set({
      userId,
      amount,
      creditAmount,
      orderId,
      status: "initiated",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      provider: "toss_payments",
    });

    return { orderId };
  } catch (error) {
    console.error("Payment creation failed", error);
    throw new functions.https.HttpsError(
      "internal",
      "Could not create payment."
    );
  }
});

// 2. 결제 승인 (Callable Function)
export const approvePayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const { orderId, paymentKey } = data;

  if (!orderId || !paymentKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing 'orderId' or 'paymentKey'."
    );
  }

  try {
    const paymentDocRef = db.collection("payments").doc(orderId);
    const paymentDoc = await paymentDocRef.get();

    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Payment not found.");
    }

    const paymentData = paymentDoc.data()!;

    if (paymentData.status !== "initiated") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Payment has already been processed."
      );
    }

    // Toss Payments 결제 승인 API 호출
    const response = await axios.post(
      `https://api.tosspayments.com/v1/payments/${paymentKey}`,
      {
        orderId: orderId,
        amount: paymentData.amount,
      },
      {
        headers: {
          Authorization: `Basic ${Buffer.from(TOSS_SECRET_KEY + ":").toString("base64")}`,
          "Content-Type": "application/json",
        },
      }
    );

    if (response.data.status === "DONE") {
      // 결제 성공, 트랜잭션으로 크레딧 지급 및 상태 업데이트
      await db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(paymentData.userId);
        transaction.update(userRef, {
          credits: admin.firestore.FieldValue.increment(paymentData.creditAmount),
        });
        transaction.update(paymentDocRef, {
          status: "completed",
          paymentKey: paymentKey,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      return { success: true, message: "Payment approved and credits added." };
    } else {
      // 결제 실패
      await paymentDocRef.update({
        status: "failed",
        errorCode: response.data.code,
        errorMessage: response.data.message,
      });
      throw new functions.https.HttpsError("aborted", "Payment approval failed.");
    }
  } catch (error) {
    console.error("Approve payment failed", error);
    // 실패 상태 업데이트
    await db.collection("payments").doc(orderId).update({
        status: "failed",
        errorMessage: (error as Error).message,
      }).catch();
    throw new functions.https.HttpsError(
      "internal",
      "An error occurred while approving the payment."
    );
  }
});

// 3. 토스페이먼츠 웹훅 처리 (HTTP-triggered Function)
export const handleTossWebhook = functions.https.onRequest(async (req, res) => {
    // TODO: Implement Toss Payments webhook signature verification for security
    // const signature = req.headers["tosspayments-signature"];
    // ... verification logic ...

    const event = req.body;

    if (event.eventType === "PAYMENT_STATUS_CHANGED") {
        const { orderId, status } = event.data;

        if (status === "DONE") {
            try {
                const paymentDocRef = db.collection("payments").doc(orderId);
                
                await db.runTransaction(async (transaction) => {
                    const paymentDoc = await transaction.get(paymentDocRef);
                    if (!paymentDoc.exists || paymentDoc.data()!.status !== 'initiated') {
                        // 이미 처리되었거나 존재하지 않는 결제
                        return;
                    }
                    
                    const paymentData = paymentDoc.data()!;
                    const userRef = db.collection("users").doc(paymentData.userId);

                    // 크레딧 지급 및 상태 업데이트
                    transaction.update(userRef, {
                        credits: admin.firestore.FieldValue.increment(paymentData.creditAmount),
                    });
                    transaction.update(paymentDocRef, {
                        status: "completed",
                        paymentKey: event.data.paymentKey, // 웹훅에서 받은 paymentKey 사용
                        completedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                });
                console.log(`Webhook: Payment ${orderId} processed successfully.`);
            } catch (error) {
                console.error(`Webhook: Error processing payment ${orderId}`, error);
                res.status(500).send("Internal Server Error");
                return;
            }
        }
    }

    res.status(200).send("Webhook received");
});