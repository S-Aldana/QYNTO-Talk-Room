const WebSocket = require('ws');
const http = require('http');
const { aiManager } = require('./AI_msg');
const { Lobby } = require('./lobby');
const {
    handleSendChatMessage,
    handleCreateLobby,
    handleJoinLobby,
    handleGetLobbies,
    handleUpdateLobby,
    handleStartGame,
    handleLeaveLobby,
    handleNextRound,
    handleTriggerEvent,
    sendError
} = require('./websocket-handlers');

const PORT = process.env.PORT || 8080;

const server = http.createServer();
const wss = new WebSocket.Server({ server });

const lobbies = new Map();
const players = new Map();

async function testAIResponse() {
    console.log("\n=== TESTING AI MANAGER ===");
    
    const { aiManager } = require('./AI_msg');
    
    try {
        console.log("Testing AI connection...");
        const connected = await aiManager.testAPIConnection();
        console.log("AI connection test result:", connected);
        
        if (connected) {
            console.log("Testing chat response generation...");
            const testResponse = await aiManager.generateChatResponse(
                "Hello everyone!", 
                "TestPlayer", 
                { name: "TestBot", id: "test_bot_1" }, 
                "test_lobby"
            );
            console.log("Test AI response:", testResponse);
        }
    } catch (error) {
        console.log("AI test error:", error);
    }
    
    console.log("=== END AI TEST ===\n");
}

wss.on('connection', (ws, req) => {
    let playerId = null;
    let currentLobbyId = null;
    
    ws.on('message', async (data) => {
        try {
            const message = JSON.parse(data.toString());

            switch (message.type) {
                case 'create_lobby':
                    const createResult = await handleCreateLobby(ws, message, lobbies, players, generatePlayerId, broadcastLobbyListUpdate, Lobby);
                    if (createResult) {
                        playerId = createResult.playerId;
                        currentLobbyId = createResult.currentLobbyId;
                    }
                    break;
                case 'join_lobby':
                    const joinResult = handleJoinLobby(ws, message, lobbies, players, generatePlayerId, broadcastLobbyListUpdate);
                    if (joinResult) {
                        playerId = joinResult.playerId;
                        currentLobbyId = joinResult.currentLobbyId;
                    }
                    break;
                case 'get_lobbies':
                    handleGetLobbies(ws, lobbies);
                    break;
                case 'update_lobby':
                    handleUpdateLobby(ws, message, lobbies, playerId, broadcastLobbyListUpdate);
                    break;
                case 'start_game':
                    handleStartGame(ws, message, lobbies, playerId, broadcastLobbyListUpdate);
                    break;
                case 'leave_lobby':
                    const leaveResult = handleLeaveLobby(ws, currentLobbyId, playerId, lobbies, players, broadcastLobbyListUpdate);
                    if (leaveResult) {
                        playerId = leaveResult.playerId;
                        currentLobbyId = leaveResult.currentLobbyId;
                    }
                    break;
                case 'send_chat_message':
                    await handleSendChatMessage(ws, message, lobbies, players);
                    break;
                case 'next_round':
                    handleNextRound(ws, message, lobbies, playerId);
                    break;
                case 'trigger_event':
                    handleTriggerEvent(ws, message, lobbies, playerId);
                    break;
            }
        } catch (error) {
            sendError(ws, 'Error processing message', error.message);
        }
    });

    ws.on('close', () => {
        if (currentLobbyId && playerId) {
            const lobby = lobbies.get(currentLobbyId);
            if (lobby) {
                const isCreator = lobby.creatorId === playerId;
                
                lobby.removePlayer(playerId);
                
                if (lobby.players.size === 0 || (isCreator && !lobby.gameStarted)) {
                    lobby.stopEventTimer();
                    lobbies.delete(currentLobbyId);
                    if (aiManager && aiManager.clearLobbyHistory) {
                        aiManager.clearLobbyHistory(currentLobbyId);
                    }
                    broadcastLobbyListUpdate();
                } else {
                    lobby.broadcastToLobby({
                        type: 'lobby_updated',
                        data: lobby.getLobbyData()
                    });
                    broadcastLobbyListUpdate();
                }
            }
        }
        if (playerId) {
            players.delete(playerId);
        }
    });
});

function generatePlayerId() {
    return 'player_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

function broadcastLobbyListUpdate() {
    const publicLobbies = Array.from(lobbies.values())
        .filter(lobby => lobby.config.is_public && !lobby.gameStarted)
        .map(lobby => lobby.getLobbyData());

    const updateMessage = JSON.stringify({
        type: 'lobbies_list',
        data: publicLobbies
    });

    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(updateMessage);
        }
    });
}

server.listen(PORT, '0.0.0.0', () => {
    console.log(`WebSocket server running on port ${PORT}`);
    console.log('Server ready for connections');
});