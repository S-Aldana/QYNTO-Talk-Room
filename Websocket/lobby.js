const WebSocket = require('ws');
const { aiManager } = require('./AI_msg');
const { EVENT_TYPES, GameEvent } = require('./events');
const { EventManager } = require('./EventManager');

class Lobby {
    constructor(config) {
        this.id = config.lobby_id;
        this.name = config.lobby_name;
        this.config = config;
        this.players = new Map();
        this.ai_players = new Map();
        this.host_bot = null;
        this.createdAt = new Date();
        this.gameStarted = false;
        this.assigned_seats = [];
        this.player_seat_assignments = new Map();
        this.creatorId = config.creator ? config.creator.id : null;
        
        this.current_round = 1;
        this.max_rounds = config.rounds || 10;
        this.events_history = [];
        this.host_type = config.host_type || "auto";
        this.chat_messages = [];
        this.last_event_time = Date.now();
        
        this.eventManager = new EventManager(this);
        
        this.initializeHostBot();
        this.initializeAIPlayers().then(() => {
            console.log(`Lobby ${this.id} fully initialized with ${this.ai_players.size} AI players`);
            
            if (!this.config.event_by_messages) {
                console.log(`Starting timer for lobby ${this.id} - ${this.config.seconds_interval} seconds`);
                setTimeout(() => {
                    if (!this.gameStarted) {
                        this.eventManager.startTimer();
                    }
                }, 3000);
            }
        });
    }

    generatePlayerSeatAssignment(playerId) {
        const availableSeats = [1, 2, 3, 4, 5, 6, 7].filter(seat => 
            !Array.from(this.player_seat_assignments.values()).some(assignment => assignment.seat === seat)
        );
        
        if (availableSeats.length === 0) return null;
        
        const randomSeat = availableSeats[Math.floor(Math.random() * availableSeats.length)];
        const randomVariant = Math.floor(Math.random() * 2) + 1;
        
        const assignment = {
            seat: randomSeat,
            variant: randomVariant
        };
        
        this.player_seat_assignments.set(playerId, assignment);
        return assignment;
    }

    addPlayer(playerId, playerData, ws) {
        this.players.set(playerId, {
            ...playerData,
            ws: ws,
            joinedAt: new Date(),
            points: playerData.points || 0
        });

        this.generatePlayerSeatAssignment(playerId);
        this.updateSeats();

        this.broadcastToLobby({
            type: 'player_joined',
            player_name: playerData.name,
            player_id: playerId,
            lobby_data: this.getLobbyData()
        });
    }

    removePlayer(playerId) {
        const player = this.players.get(playerId);
        if (player) {
            this.players.delete(playerId);
            this.player_seat_assignments.delete(playerId);
            this.updateSeats();

            this.broadcastToLobby({
                type: 'player_left',
                player_name: player.name,
                player_id: playerId,
                lobby_data: this.getLobbyData()
            });
        }
    }

    updateSeats() {
        const totalPlayers = this.players.size + this.ai_players.size;
        console.log("=== UPDATE SEATS SERVER ===");
        console.log("Total human players:", this.players.size);
        console.log("Total AI players:", this.ai_players.size);
        console.log("Total players for seats:", totalPlayers);
        
        for (const [aiId, aiPlayer] of this.ai_players) {
            if (!this.player_seat_assignments.has(aiId)) {
                this.generatePlayerSeatAssignment(aiId);
            }
        }
        
        this.assigned_seats = Array.from(this.player_seat_assignments.values()).map(assignment => assignment.seat);
        console.log("Generated seats:", this.assigned_seats);
        console.log("Seat assignments:", Object.fromEntries(this.player_seat_assignments));
        console.log("=== END UPDATE SEATS SERVER ===");
    }

    async initializeAIPlayers() {
        const maxAI = this.config.max_ai_players || 0;
        const currentAI = this.config.current_ai_players || 0;
        
        console.log(`=== INITIALIZING AI PLAYERS ===`);
        console.log(`Lobby: ${this.id}`);
        console.log(`Max AI: ${maxAI}, Current AI to create: ${currentAI}`);
        
        try {
            for (let i = 0; i < currentAI && i < maxAI; i++) {
                const aiPlayer = await aiManager.createAIPlayer(i, this.id);
                this.ai_players.set(aiPlayer.id, aiPlayer);
                this.generatePlayerSeatAssignment(aiPlayer.id);
                console.log(`Created AI player: ${aiPlayer.name} (ID: ${aiPlayer.id})`);
            }
            
            console.log(`Total AI players created: ${this.ai_players.size}`);
            this.updateSeats();
            
            if (this.ai_players.size > 0) {
                setTimeout(() => {
                    aiManager.startLobbyActivity(this.id, this);
                }, 2000);
            }
        } catch (error) {
            console.error(`Error initializing AI players for lobby ${this.id}:`, error);
        }
        
        console.log(`=== END AI INITIALIZATION ===`);
    }

    getLobbyData() {
        const human_players = Array.from(this.players.values()).map(player => ({
            id: player.id,
            name: player.name,
            avatar: player.avatar,
            points: player.points || 0,
            joined_at: player.joinedAt,
            is_ai: false
        }));

        const ai_players_list = Array.from(this.ai_players.values()).map(ai => ({
            id: ai.id,
            name: ai.name,
            avatar: ai.avatar,
            points: ai.points || 0,
            joined_at: ai.joinedAt,
            is_ai: true
        }));

        const all_players = [...human_players, ...ai_players_list];
        const nextEventInfo = this.eventManager.getNextEventInfo();

        const seat_assignments = {};
        for (const [playerId, assignment] of this.player_seat_assignments) {
            seat_assignments[playerId] = assignment;
        }

        console.log("=== GET LOBBY DATA ===");
        console.log("Human players:", human_players.length);
        console.log("AI players:", ai_players_list.length);
        console.log("Total players in list:", all_players.length);
        console.log("Assigned seats:", this.assigned_seats);
        console.log("Seat assignments:", seat_assignments);

        return {
            ...this.config,
            lobby_id: this.id,
            lobby_name: this.name,
            current_players: this.players.size,
            current_ai_players: this.ai_players.size,
            total_players: all_players.length,
            human_players: human_players,
            ai_players: ai_players_list,
            players_list: all_players,
            created_at: this.createdAt,
            game_started: this.gameStarted,
            assigned_seats: this.assigned_seats,
            seat_assignments: seat_assignments,
            current_round: this.current_round,
            max_rounds: this.max_rounds,
            events_history: this.events_history,
            next_event_in: nextEventInfo.remaining,
            next_event_type: nextEventInfo.type,
            next_event_total: nextEventInfo.total,
            host_type: this.host_type,
            chat_messages: this.chat_messages,
            last_event_time: this.last_event_time,
            message_count_since_event: nextEventInfo.current,
            current_event: this.eventManager.currentEvent ? {
                id: this.eventManager.currentEvent.id,
                type: this.eventManager.currentEvent.type,
                resolved: this.eventManager.currentEvent.resolved
            } : null,
            host_bot: this.host_bot,
            event_active: nextEventInfo.eventActive
        };
    }

    // Rest of the methods remain the same...
    startBotActivity() {
        console.log(`=== STARTING BOT ACTIVITY ===`);
        console.log(`Lobby: ${this.id}`);
        console.log(`AI Players: ${this.ai_players.size}`);
        console.log(`Event by messages: ${this.config.event_by_messages}`);
        console.log(`Messages interval: ${this.config.messages_interval}`);
        console.log(`Seconds interval: ${this.config.seconds_interval}`);
        console.log(`=== END BOT ACTIVITY ===`);
        
        if (this.ai_players.size > 0) {
            aiManager.startLobbyActivity(this.id, this);
            
            setTimeout(() => {
                aiManager.triggerBotConversation(this.id);
            }, 5000);
        }
        
        if (!this.config.event_by_messages) {
            console.log(`Starting timer-based events every ${this.config.seconds_interval} seconds`);
            this.eventManager.startTimer();
        }
    }

    stopEventTimer() {
        this.eventManager.stopTimer();
    }

    initializeHostBot() {
        if (this.host_type === "auto") {
            this.host_bot = {
                id: `host_${Date.now()}`,
                name: "GameMaster",
                avatar: "ai_player",
                points: 0,
                is_ai: true,
                is_host_bot: true,
                joinedAt: new Date()
            };
        }
    }

    getHostBot() {
        return this.host_bot;
    }

    eliminatePlayer(playerId) {
        const humanPlayer = this.players.get(playerId);
        const aiPlayer = this.ai_players.get(playerId);
        
        if (humanPlayer) {
            this.addChatMessage("system", `${humanPlayer.name} has been eliminated from the game!`, true, "GameMaster", "ai_player");
            
            humanPlayer.ws.send(JSON.stringify({
                type: 'player_eliminated',
                message: 'You have been eliminated from the game!'
            }));
            
            setTimeout(() => {
                humanPlayer.ws.send(JSON.stringify({
                    type: 'force_leave',
                    redirect_to_main: true
                }));
            }, 3000);
            
            this.players.delete(playerId);
        } else if (aiPlayer) {
            this.addChatMessage("system", `${aiPlayer.name} has been eliminated!`, true, "GameMaster", "ai_player");
            this.ai_players.delete(playerId);
        }
        
        this.player_seat_assignments.delete(playerId);
        this.updateSeats();
        this.broadcastToLobby({
            type: 'player_eliminated',
            eliminated_player: playerId,
            lobby_data: this.getLobbyData()
        });
    }

    awardPoints(playerId, points) {
        const humanPlayer = this.players.get(playerId);
        const aiPlayer = this.ai_players.get(playerId);
        
        if (humanPlayer) {
            humanPlayer.points = (humanPlayer.points || 0) + points;
        } else if (aiPlayer) {
            aiPlayer.points = (aiPlayer.points || 0) + points;
        }
        
        this.broadcastToLobby({
            type: 'points_awarded',
            player_id: playerId,
            points: points,
            lobby_data: this.getLobbyData()
        });
    }

    generateRandomSeats(playerCount) {
        console.log("Generating seats for", playerCount, "players");
        const seats = [1, 2, 3, 4, 5, 6, 7];
        const selectedSeats = seats.sort(() => Math.random() - 0.5).slice(0, playerCount);
        console.log("Selected seats:", selectedSeats);
        return selectedSeats;
    }

    async addEvent(eventText, eventType = "system") {
        const event = {
            id: Date.now(),
            text: eventText,
            type: eventType,
            timestamp: new Date(),
            round: this.current_round,
            player_name: "System",
            player_avatar: "system_avatar"
        };
        
        this.events_history.push(event);
        this.last_event_time = Date.now();
        
        if (this.events_history.length > 50) {
            this.events_history = this.events_history.slice(-50);
        }
        
        this.addChatMessage("system", eventText, true, "GameMaster", "ai_player", false, true);
        
        this.broadcastToLobby({
            type: 'new_event',
            event: event,
            lobby_data: this.getLobbyData()
        });
    }

    async triggerRandomEvent() {
        if (this.eventManager.currentEvent && !this.eventManager.currentEvent.resolved) {
            console.log(`Event already active in lobby ${this.id}, skipping`);
            return false;
        }

        const randomEventData = EVENT_TYPES[Math.floor(Math.random() * EVENT_TYPES.length)];
        const gameEvent = new GameEvent(randomEventData, this);
        this.eventManager.onEventStarted(gameEvent);

        console.log(`=== TRIGGERING EVENT ===`);
        console.log(`Event: ${randomEventData.text}`);
        console.log(`Lobby: ${this.id}`);
        console.log(`Event type: ${randomEventData.type}`);
        console.log(`=== END TRIGGER ===`);

        await this.addEvent(randomEventData.text, "game_event");

        setTimeout(() => {
            this.triggerAIResponsesToEvent(randomEventData);
        }, 2000);

        return true;
    }

    async triggerAIResponsesToEvent(eventData) {
        if (this.ai_players.size === 0) return;

        const aiArray = Array.from(this.ai_players.values());
        const respondingAIs = aiArray.filter(() => Math.random() > 0.2);
        const allPlayers = [...this.players.values(), ...this.ai_players.values()];
        
        for (const ai of respondingAIs) {
            const delay = Math.random() * 3000 + 1000;
            
            setTimeout(async () => {
                try {
                    const response = await aiManager.generateEventResponse(eventData, ai, allPlayers, this.id);
                    
                    this.addChatMessage(ai.id, response, false, null, null, true, false);
                    if (this.eventManager.currentEvent && !this.eventManager.currentEvent.resolved) {
                        this.eventManager.currentEvent.addResponse(ai.id, response);
                    }
                } catch (error) {
                    console.error('Error getting AI event response:', error);
                }
            }, delay);
        }
    }

    async addChatMessage(playerId, message, isSystemMessage = false, systemName = null, systemAvatar = null, isEventResponse = false, isEventMessage = false) {
        let chatMessage;

        if (isSystemMessage || playerId === "system") {
            chatMessage = {
                id: Date.now(),
                player_id: isSystemMessage ? "system" : playerId,
                player_name: systemName || "GameMaster",
                player_avatar: systemAvatar || "ai_player",
                message: message,
                timestamp: new Date(),
                is_ai: false,
                is_system: true 
            };
        } else {
            const player = this.players.get(playerId) || this.ai_players.get(playerId) || this.host_bot;
            if (!player) return;

            chatMessage = {
                id: Date.now(),
                player_id: playerId,
                player_name: player.name,
                player_avatar: player.avatar,
                message: message,
                timestamp: new Date(),
                is_ai: player.is_ai || false,
                is_system: false
            };

            if (this.eventManager.currentEvent && !this.eventManager.currentEvent.resolved && !player.is_ai) {
                this.eventManager.currentEvent.addResponse(playerId, message);
            }
        }

        this.chat_messages.push(chatMessage);
        
        if (!isSystemMessage && playerId !== "system" && !isEventMessage) {
            aiManager.updateConversationHistory(
                this.id, 
                chatMessage.player_name, 
                message, 
                chatMessage.is_ai
            );
        }

        if (this.chat_messages.length > 100) {
            this.chat_messages = this.chat_messages.slice(-100);
        }

        this.broadcastToLobby({
            type: 'new_chat_message',
            message: chatMessage,
            lobby_data: this.getLobbyData()
        });

        if (!isSystemMessage && playerId !== "system" && !isEventResponse && !isEventMessage) {
            if (chatMessage.is_ai) {
                this.eventManager.onBotMessageSent();
            } else {
                this.eventManager.onHumanMessageSent();
                await aiManager.processHumanMessage(message, chatMessage.player_name, this.id);
            }
        }
    }

    nextRound() {
        if (this.current_round < this.max_rounds) {
            this.current_round++;
            this.addEvent(`Round ${this.current_round} started!`, "round_start");
            
            this.broadcastToLobby({
                type: 'round_changed',
                current_round: this.current_round,
                lobby_data: this.getLobbyData()
            });
        } else {
            this.endGame();
        }
    }

    endGame() {
        this.gameStarted = false;
        this.stopEventTimer();
        const allPlayers = [...this.players.values(), ...this.ai_players.values()];
        const sortedPlayers = allPlayers.sort((a, b) => (b.points || 0) - (a.points || 0));
        
        let endMessage = "Game ended! Final scores:\n";
        sortedPlayers.slice(0, 3).forEach((player, index) => {
            const position = ["🥇", "🥈", "🥉"][index] || `${index + 1}.`;
            endMessage += `${position} ${player.name}: ${player.points || 0} points\n`;
        });
        
        this.addEvent(endMessage, "game_end");
        
        this.broadcastToLobby({
            type: 'game_ended',
            final_scores: sortedPlayers,
            lobby_data: this.getLobbyData()
        });

        aiManager.clearLobbyHistory(this.id);
    }

    broadcastToLobby(message, excludePlayerId = null) {
        this.players.forEach((player, playerId) => {
            if (playerId !== excludePlayerId && player.ws && player.ws.readyState === WebSocket.OPEN) {
                player.ws.send(JSON.stringify(message));
            }
        });
    }

    canJoin() {
        if (this.gameStarted) return false;
        if (this.config.infinite_participants) return true;
        return (this.players.size + this.ai_players.size) < this.config.max_participants;
    }
}

module.exports = { Lobby };