import * as admin from "firebase-admin";

admin.initializeApp();

export {
  sendFCMMessage,
  sendScheduledEvaluationNotifications,
  processExpiredEvaluations,
  updateFCMToken
} from './fcm';

export {
  testDiscordFix
} from './test-discord-fix';

// Discord Bot 관련 함수들 export
export {
  onTournamentParticipantChange,
  onTournamentEnd,
  createDiscordChannelsManually,
  cleanupExpiredDiscordChannels
} from './tournament-discord-handler';
