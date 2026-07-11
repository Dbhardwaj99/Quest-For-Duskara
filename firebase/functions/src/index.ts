import {onCall} from "firebase-functions/v2/https";
import {cancelMatchmakingHandler, joinMatchmakingHandler} from "./matchmaking.js";
import {createRoomHandler, joinRoomHandler, leaveRoomHandler, setReadyHandler, startRoomHandler} from "./roomService.js";

const options = {region: "asia-south1", enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"};
export const createRoom = onCall(options, createRoomHandler);
export const joinRoom = onCall(options, joinRoomHandler);
export const leaveRoom = onCall(options, leaveRoomHandler);
export const setLobbyReady = onCall(options, setReadyHandler);
export const startRoom = onCall(options, startRoomHandler);
export const joinMatchmaking = onCall(options, joinMatchmakingHandler);
export const cancelMatchmaking = onCall(options, cancelMatchmakingHandler);
