import {onCall} from "firebase-functions/v2/https";
import {cancelMatchmakingHandler, joinMatchmakingHandler} from "./matchmaking.js";
import {createRoomHandler, joinRoomHandler, leaveRoomHandler, setReadyHandler, startRoomHandler} from "./roomService.js";
import {fetchCheckpointHandler, submitGameActionHandler} from "./gameReducer.js";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {advanceDueRooms} from "./dayAdvance.js";
import {reconnectPrompt, registerNotificationTokenHandler} from "./notifications.js";
import {onValueDeleted} from "firebase-functions/v2/database";

const options = {region: "asia-south1", enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"};
export const createRoom = onCall(options, createRoomHandler);
export const joinRoom = onCall(options, joinRoomHandler);
export const leaveRoom = onCall(options, leaveRoomHandler);
export const setLobbyReady = onCall(options, setReadyHandler);
export const startRoom = onCall(options, startRoomHandler);
export const joinMatchmaking = onCall(options, joinMatchmakingHandler);
export const cancelMatchmaking = onCall(options, cancelMatchmakingHandler);
export const submitGameAction = onCall(options, submitGameActionHandler);
export const fetchCheckpoint = onCall(options, fetchCheckpointHandler);
export const registerNotificationToken = onCall(options, registerNotificationTokenHandler);
export const presenceDisconnected = onValueDeleted(
  {region: "asia-south1", ref: "/presence/{roomID}/{uid}/connections/{connectionID}"},
  event => reconnectPrompt(event.params.roomID, event.params.uid)
);
export const advanceDays = onSchedule({region: "asia-south1", schedule: "every 1 minutes"}, advanceDueRooms);
