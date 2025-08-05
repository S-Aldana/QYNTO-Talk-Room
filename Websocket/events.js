class GameEvent {
    constructor(eventData, lobby) {
        this.id = Date.now();
        this.type = eventData.type;
        this.text = eventData.text;
        this.timeout = eventData.timeout || 30000;
        this.correctAnswer = eventData.correctAnswer;
        this.lobby = lobby;
        this.responses = new Map();
        this.resolved = false;
        this.startTime = Date.now();
        
        this.setupAutoResolve();
    }

    setupAutoResolve() {
        setTimeout(() => {
            if (!this.resolved) {
                console.log(`Auto-resolving event ${this.id} after timeout`);
                this.resolveEvent();
            }
        }, this.timeout);
    }

    addResponse(playerId, response) {
        if (this.resolved) return;
        
        this.responses.set(playerId, {
            response: response,
            timestamp: Date.now()
        });
        
        console.log(`Event ${this.id} received response from ${playerId}: ${response}`);
        this.checkForResolution();
    }

    checkForResolution() {
        if (this.resolved) return;
        
        const totalPlayers = this.lobby.players.size + this.lobby.ai_players.size;
        const responseCount = this.responses.size;
        
        if (this.type === "speed_challenge" && responseCount > 0) {
            this.resolveEvent();
        } else if (responseCount >= Math.ceil(totalPlayers * 0.8)) {
            this.resolveEvent();
        }
    }

    resolveEvent() {
        if (this.resolved) return;
        
        this.resolved = true;
        console.log(`Resolving event ${this.id} of type ${this.type}`);
        
        this.processEventResults();
        this.lobby.eventManager.onEventResolved();
    }

    processEventResults() {
        switch (this.type) {
            case "speed_challenge":
                this.processSpeedChallenge();
                break;
            case "vote_bonus":
                this.processVoteBonus();
                break;
            case "vote_eliminate":
                this.processVoteEliminate();
                break;
            case "trivia":
                this.processTrivia();
                break;
            default:
                this.processGenericEvent();
        }
    }

    processSpeedChallenge() {
        if (this.responses.size === 0) {
            this.lobby.addChatMessage("system", "No one responded in time!", true, "GameMaster", "ai_player");
            return;
        }

        const sortedResponses = Array.from(this.responses.entries())
            .sort((a, b) => a[1].timestamp - b[1].timestamp);

        const winnerId = sortedResponses[0][0];
        const winner = this.lobby.players.get(winnerId) || this.lobby.ai_players.get(winnerId);

        if (winner) {
            this.lobby.awardPoints(winnerId, 10);
            this.lobby.addChatMessage("system", `${winner.name} won the speed challenge! +10 points`, true, "GameMaster", "ai_player");
        }
    }

    processVoteBonus() {
        const votes = new Map();
        
        this.responses.forEach((responseData, voterId) => {
            const vote = responseData.response.trim();
            votes.set(vote, (votes.get(vote) || 0) + 1);
        });

        if (votes.size === 0) {
            this.lobby.addChatMessage("system", "No votes received!", true, "GameMaster", "ai_player");
            return;
        }

        const sortedVotes = Array.from(votes.entries()).sort((a, b) => b[1] - a[1]);
        const winnerName = sortedVotes[0][0];
        const voteCount = sortedVotes[0][1];

        const allPlayers = [...this.lobby.players.values(), ...this.lobby.ai_players.values()];
        const winner = allPlayers.find(p => p.name.toLowerCase() === winnerName.toLowerCase());

        if (winner) {
            this.lobby.awardPoints(winner.id, 5);
            this.lobby.addChatMessage("system", `${winner.name} received the most votes (${voteCount}) and gets +5 points!`, true, "GameMaster", "ai_player");
        }
    }

    processVoteEliminate() {
        let yesVotes = 0;
        let noVotes = 0;

        this.responses.forEach((responseData) => {
            const vote = responseData.response.trim().toUpperCase();
            if (vote === "YES" || vote === "Y") yesVotes++;
            else if (vote === "NO" || vote === "N") noVotes++;
        });

        if (yesVotes > noVotes) {
            const allPlayers = [...this.lobby.players.values(), ...this.lobby.ai_players.values()];
            if (allPlayers.length > 0) {
                const randomPlayer = allPlayers[Math.floor(Math.random() * allPlayers.length)];
                this.lobby.eliminatePlayer(randomPlayer.id);
                this.lobby.addChatMessage("system", `Vote passed (${yesVotes} vs ${noVotes}). ${randomPlayer.name} was eliminated!`, true, "GameMaster", "ai_player");
            }
        } else {
            this.lobby.addChatMessage("system", `Vote failed (${yesVotes} vs ${noVotes}). No one was eliminated.`, true, "GameMaster", "ai_player");
        }
    }

    processTrivia() {
        let correctAnswers = 0;
        const winners = [];

        this.responses.forEach((responseData, playerId) => {
            const answer = responseData.response.trim().toLowerCase();
            const correctAnswer = this.correctAnswer.toLowerCase();
            
            if (answer === correctAnswer) {
                correctAnswers++;
                const player = this.lobby.players.get(playerId) || this.lobby.ai_players.get(playerId);
                if (player) {
                    winners.push(player);
                    this.lobby.awardPoints(playerId, 5);
                }
            }
        });

        if (winners.length > 0) {
            const winnerNames = winners.map(w => w.name).join(", ");
            this.lobby.addChatMessage("system", `Correct answer: ${this.correctAnswer}. Winners: ${winnerNames} (+5 points each)`, true, "GameMaster", "ai_player");
        } else {
            this.lobby.addChatMessage("system", `Correct answer: ${this.correctAnswer}. No one got it right!`, true, "GameMaster", "ai_player");
        }
    }

    processGenericEvent() {
        this.lobby.addChatMessage("system", "Event concluded. Thanks for participating!", true, "GameMaster", "ai_player");
    }
}

const EVENT_TYPES = [
    {
        type: "speed_challenge",
        text: "Speed Challenge! First to type 'FAST' wins 10 points!",
        timeout: 15000,
        correctAnswer: "FAST"
    },
    {
        type: "vote_bonus",
        text: "Vote for who deserves bonus points! Type their name.",
        timeout: 30000
    },
    {
        type: "vote_eliminate", 
        text: "Should we eliminate a random player? Vote YES or NO!",
        timeout: 25000
    },
    {
        type: "trivia",
        text: "Trivia: What is the capital of France?",
        timeout: 20000,
        correctAnswer: "Paris"
    },
    {
        type: "confession",
        text: "Share your most embarrassing moment!",
        timeout: 45000
    },
    {
        type: "story_time",
        text: "Tell us a short story about your childhood!",
        timeout: 60000
    },
    {
        type: "debate",
        text: "Debate: Pineapple on pizza - yes or no? Defend your position!",
        timeout: 40000
    },
    {
        type: "would_rather",
        text: "Would you rather have the ability to fly or be invisible? Why?",
        timeout: 30000
    },
    {
        type: "talent_show",
        text: "Talent show time! What's your hidden talent?",
        timeout: 35000
    }
];

module.exports = { GameEvent, EVENT_TYPES };