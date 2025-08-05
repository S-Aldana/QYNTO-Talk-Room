const { aiManager } = require('./AI_msg');

async function handleSendChatMessage(ws, message, lobbies, players) {
    console.log("\n=== CHAT MESSAGE DEBUG ===");
    console.log("Received message:", JSON.stringify(message, null, 2));
    
    try {
        const lobbyId = message.lobby_id;
        const playerId = message.player_id;
        const messageText = message.message;

        console.log("Lobby ID:", lobbyId);
        console.log("Player ID:", playerId);
        console.log("Message Text:", messageText);

        const lobby = lobbies.get(lobbyId);
        if (!lobby) {
            console.log("ERROR: Lobby not found for ID:", lobbyId);
            console.log("Available lobbies:", Array.from(lobbies.keys()));
            sendError(ws, 'Lobby not found');
            return;
        }

        console.log("Lobby found successfully");
        console.log("Lobby players:", Array.from(lobby.players.keys()));

        if (!lobby.players.has(playerId)) {
            console.log("ERROR: Player not in lobby");
            console.log("Player ID:", playerId);
            console.log("Players in lobby:", Array.from(lobby.players.keys()));
            sendError(ws, 'Player not in lobby');
            return;
        }

        const player = lobby.players.get(playerId);
        console.log("Player found in lobby, adding chat message...");
        console.log("Player is AI:", player.is_ai || false);
        console.log("Is human player:", !player.is_ai);

        await lobby.addChatMessage(playerId, messageText, false, null, null, false, false);
        
        console.log("Chat message added successfully");
        console.log("Current chat messages count:", lobby.chat_messages.length);
        console.log("Game started:", lobby.gameStarted);
        console.log("Event by messages:", lobby.config.event_by_messages);
        console.log("Messages interval:", lobby.config.messages_interval);
        
        if (lobby.eventManager) {
            const eventInfo = lobby.eventManager.getNextEventInfo();
            console.log("Current message count:", eventInfo.current);
            console.log("Messages until next event:", eventInfo.remaining);
            console.log("Event active:", eventInfo.eventActive);
            console.log("Has active event:", lobby.eventManager.currentEvent && !lobby.eventManager.currentEvent.resolved);
        }
        
        console.log("=== END CHAT MESSAGE DEBUG ===\n");

    } catch (error) {
        console.log("ERROR in handleSendChatMessage:", error);
        console.log("Error stack:", error.stack);
        sendError(ws, 'Error sending chat message', error.message);
    }
}

async function handleCreateLobby(ws, message, lobbies, players, generatePlayerId, broadcastLobbyListUpdate, Lobby) {
    try {
        console.log("=== CREATING LOBBY ===");
        const lobbyConfig = message.data;
        console.log("Lobby config received:", lobbyConfig);
        
        const lobby = new Lobby(lobbyConfig);
        console.log("Lobby created with ID:", lobby.id);

        lobbies.set(lobby.id, lobby);

        const playerId = generatePlayerId();
        const currentLobbyId = lobby.id;

        let playerData = lobbyConfig.creator || {
            name: 'Host',
            id: playerId,
            avatar: 'simple_1',
            points: 0,
            isHost: true
        };
        playerData.id = playerId;

        players.set(playerId, { ws, lobbyId: lobby.id });
        lobby.addPlayer(playerId, playerData, ws);

        console.log("Total players in lobby:", lobby.players.size);
        console.log("Total AI players in lobby:", lobby.ai_players.size);
        console.log("Players list size:", lobby.getLobbyData().players_list.length);

        await new Promise(resolve => setTimeout(resolve, 1500));

        const lobbyData = lobby.getLobbyData();
        console.log("Sending lobby data with players:", lobbyData.players_list.length);

        ws.send(JSON.stringify({
            type: 'lobby_created',
            lobby_data: lobbyData,
            player_id: playerId
        }));

        broadcastLobbyListUpdate();
        console.log("=== LOBBY CREATION COMPLETE ===");

        return { playerId, currentLobbyId };

    } catch (error) {
        console.log("Error creating lobby:", error);
        sendError(ws, 'Error creating lobby', error.message);
    }
}

function handleJoinLobby(ws, message, lobbies, players, generatePlayerId, broadcastLobbyListUpdate) {
    try {
        const lobbyId = message.lobby_id;
        const playerData = message.player_data;

        const lobby = lobbies.get(lobbyId);
        if (!lobby) {
            ws.send(JSON.stringify({
                type: 'lobby_join_failed',
                error: 'Lobby not found'
            }));
            return;
        }

        if (!lobby.canJoin()) {
            ws.send(JSON.stringify({
                type: 'lobby_join_failed',
                error: 'Lobby full or game started'
            }));
            return;
        }

        const playerId = playerData.id || generatePlayerId();
        const currentLobbyId = lobbyId;

        players.set(playerId, { ws, lobbyId });
        lobby.addPlayer(playerId, playerData, ws);

        const lobbyData = lobby.getLobbyData();

        ws.send(JSON.stringify({
            type: 'lobby_joined',
            lobby_data: lobbyData,
            player_id: playerId
        }));

        lobby.broadcastToLobby({
            type: 'lobby_updated',
            data: lobbyData
        }, playerId);

        broadcastLobbyListUpdate();

        return { playerId, currentLobbyId };

    } catch (error) {
        sendError(ws, 'Error joining lobby', error.message);
    }
}

function handleGetLobbies(ws, lobbies) {
    try {
        const publicLobbies = Array.from(lobbies.values())
            .filter(lobby => lobby.config.is_public && !lobby.gameStarted)
            .map(lobby => lobby.getLobbyData());

        ws.send(JSON.stringify({
            type: 'lobbies_list',
            data: publicLobbies
        }));

    } catch (error) {
        sendError(ws, 'Error getting lobbies', error.message);
    }
}

function handleUpdateLobby(ws, message, lobbies, playerId, broadcastLobbyListUpdate) {
    try {
        const lobbyId = message.lobby_id;
        const newConfig = message.data;

        const lobby = lobbies.get(lobbyId);
        if (!lobby) {
            sendError(ws, 'Lobby not found');
            return;
        }

        const player = lobby.players.get(playerId);
        if (!player || !player.isHost) {
            sendError(ws, 'Only the host can update the lobby');
            return;
        }

        lobby.config = { ...lobby.config, ...newConfig };

        if (newConfig.event_by_messages !== undefined || newConfig.messages_interval !== undefined || newConfig.seconds_interval !== undefined) {
            lobby.stopEventTimer();
            if (lobby.eventManager) {
                lobby.eventManager.resetCounters();
                if (!lobby.config.event_by_messages) {
                    lobby.eventManager.startTimer();
                }
            }
        }

        lobby.broadcastToLobby({
            type: 'lobby_updated',
            data: lobby.getLobbyData()
        });

        broadcastLobbyListUpdate();

    } catch (error) {
        sendError(ws, 'Error updating lobby', error.message);
    }
}

function handleStartGame(ws, message, lobbies, playerId, broadcastLobbyListUpdate) {
    try {
        const lobbyId = message.lobby_id;
        const lobby = lobbies.get(lobbyId);

        if (!lobby) {
            sendError(ws, 'Lobby not found');
            return;
        }

        const player = lobby.players.get(playerId);
        if (!player || !player.isHost) {
            sendError(ws, 'Only the host can start the game');
            return;
        }

        if ((lobby.players.size + lobby.ai_players.size) < 2) {
            sendError(ws, 'At least 2 players required');
            return;
        }

        lobby.gameStarted = true;
        
        if (lobby.eventManager) {
            lobby.eventManager.resetCounters();
            if (!lobby.config.event_by_messages) {
                console.log(`Starting timer-based events for lobby ${lobbyId}`);
                lobby.eventManager.startTimer();
            }
        }
        
        const hostBot = lobby.getHostBot();
        if (hostBot) {
            lobby.addChatMessage(hostBot.id, `Game started! Round ${lobby.current_round} of ${lobby.config.rounds}. Good luck everyone!`, false, null, null, false, true);
        }

        lobby.broadcastToLobby({
            type: 'game_started',
            data: lobby.getLobbyData()
        });

        broadcastLobbyListUpdate();

    } catch (error) {
        sendError(ws, 'Error starting game', error.message);
    }
}

function handleLeaveLobby(ws, currentLobbyId, playerId, lobbies, players, broadcastLobbyListUpdate) {
    try {
        console.log("=== HANDLING LEAVE LOBBY ===");
        console.log("Current Lobby ID:", currentLobbyId);
        console.log("Player ID:", playerId);
        
        if (!currentLobbyId || !playerId) {
            ws.send(JSON.stringify({
                type: 'lobby_left'
            }));
            return { playerId: null, currentLobbyId: null };
        }

        const lobby = lobbies.get(currentLobbyId);
        if (lobby) {
            console.log("Lobby found, removing player...");
            console.log("Players before removal:", lobby.players.size);
            console.log("Creator ID:", lobby.creatorId);
            console.log("Is creator leaving?", lobby.creatorId === playerId);
            
            const player = lobby.players.get(playerId);
            const isCreator = lobby.creatorId === playerId;
            
            lobby.removePlayer(playerId);
            console.log("Players after removal:", lobby.players.size);
            
            if (lobby.players.size === 0 || isCreator) {
                console.log("Deleting lobby - no players left or creator left");
                lobby.stopEventTimer();
                
                if (lobby.lobbyBots && lobby.lobbyBots.has(currentLobbyId)) {
                    lobby.lobbyBots.delete(currentLobbyId);
                }
                
                lobbies.delete(currentLobbyId);
                
                if (typeof aiManager !== 'undefined' && aiManager.clearLobbyHistory) {
                    aiManager.clearLobbyHistory(currentLobbyId);
                }
                
                console.log("Lobby deleted successfully");
                broadcastLobbyListUpdate();
            } else {
                console.log("Lobby kept - other players remain");
                lobby.broadcastToLobby({
                    type: 'lobby_updated',
                    data: lobby.getLobbyData()
                });
                
                broadcastLobbyListUpdate();
            }
        } else {
            console.log("Lobby not found for ID:", currentLobbyId);
        }

        players.delete(playerId);
        console.log("Player removed from players map");

        ws.send(JSON.stringify({
            type: 'lobby_left'
        }));

        console.log("=== LEAVE LOBBY COMPLETE ===");
        return { playerId: null, currentLobbyId: null };

    } catch (error) {
        console.log("Error in handleLeaveLobby:", error);
        ws.send(JSON.stringify({
            type: 'lobby_left'
        }));
        return { playerId: null, currentLobbyId: null };
    }
}

function handleNextRound(ws, message, lobbies, playerId) {
    try {
        const lobbyId = message.lobby_id;
        const lobby = lobbies.get(lobbyId);

        if (!lobby) {
            sendError(ws, 'Lobby not found');
            return;
        }

        const player = lobby.players.get(playerId);
        if (!player || !player.isHost) {
            sendError(ws, 'Only the host can advance rounds');
            return;
        }

        lobby.nextRound();

    } catch (error) {
        sendError(ws, 'Error advancing round', error.message);
    }
}

function handleTriggerEvent(ws, message, lobbies, playerId) {
    try {
        const lobbyId = message.lobby_id;
        const lobby = lobbies.get(lobbyId);

        if (!lobby) {
            sendError(ws, 'Lobby not found');
            return;
        }

        const player = lobby.players.get(playerId);
        if (!player || !player.isHost) {
            sendError(ws, 'Only the host can trigger events');
            return;
        }

        const triggered = lobby.triggerRandomEvent();
        if (!triggered) {
            sendError(ws, 'Cannot trigger event while another is active');
        }

    } catch (error) {
        sendError(ws, 'Error triggering event', error.message);
    }
}

function sendError(ws, message, error) {
    ws.send(JSON.stringify({
        type: 'error',
        message: message,
        error: error
    }));
}

module.exports = {
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
};