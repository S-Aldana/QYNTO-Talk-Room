const Anthropic = require('@anthropic-ai/sdk');

require('dotenv').config();

const anthropic = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY
});

const AI_AVATARS = [
    "simple_1", "simple_2", "simple_3", "simple_4", 
    "simple_5", "simple_6", "simple_7"
];

const COMMON_NAMES = [
    "Alex", "Sam", "Jordan", "Casey", "Riley", "Morgan", "Taylor", "Avery",
    "Blake", "Quinn", "Jamie", "Dakota", "Sage", "River", "Phoenix", "Rowan",
    "Charlie", "Emery", "Finley", "Hayden", "Indigo", "Kai", "Lane", "Marley"
];

class AIManager {
    constructor() {
        this.conversationHistory = new Map();
        this.botProfiles = new Map();
        this.lobbyBots = new Map();
        this.lastBotResponse = new Map();
        this.lobbyTimers = new Map();
        this.activeLobby = null;
        this.conversationThreads = new Map();
        this.pendingResponses = new Map();
        this.messageProcessingTimers = new Map();
    }

    async createAIPlayer(index, lobbyId = null) {
        const aiId = `ai_${Date.now()}_${index}`;
        const name = COMMON_NAMES[Math.floor(Math.random() * COMMON_NAMES.length)];
        
        const personalities = [
            { trait: "curious and analytical", topics: ["science", "space", "psychology"], responseStyle: "asks thoughtful questions" },
            { trait: "creative and artistic", topics: ["movies", "music", "design"], responseStyle: "shares imaginative perspectives" },
            { trait: "logical and practical", topics: ["technology", "efficiency", "problem-solving"], responseStyle: "provides clear reasoning" },
            { trait: "adventurous and energetic", topics: ["travel", "culture", "experiences"], responseStyle: "tells engaging stories" },
            { trait: "philosophical and deep", topics: ["existence", "meaning", "society"], responseStyle: "explores deeper meanings" },
            { trait: "witty and observational", topics: ["humor", "daily life", "human behavior"], responseStyle: "makes clever observations" }
        ];

        const personality = personalities[Math.floor(Math.random() * personalities.length)];

        const profile = {
            name: name,
            personality: personality.trait,
            favoriteTopics: personality.topics,
            responseStyle: personality.responseStyle,
            chattiness: Math.random() * 0.3 + 0.4,
            memorySpan: 10,
            questionProbability: 0.4,
            storyProbability: 0.3
        };

        const aiPlayer = {
            id: aiId,
            name: name,
            avatar: AI_AVATARS[index % AI_AVATARS.length],
            points: 0,
            is_ai: true,
            joinedAt: new Date(),
            profile: profile
        };

        this.botProfiles.set(aiId, profile);

        if (lobbyId) {
            if (!this.lobbyBots.has(lobbyId)) {
                this.lobbyBots.set(lobbyId, new Map());
            }
            this.lobbyBots.get(lobbyId).set(aiId, aiPlayer);
            
            if (!this.conversationThreads.has(lobbyId)) {
                this.conversationThreads.set(lobbyId, []);
            }
        }

        console.log(`AI Player created: ${name} (${profile.personality})`);
        return aiPlayer;
    }

    startLobbyActivity(lobbyId, lobby) {
        this.activeLobby = lobby;
        
        console.log(`=== STARTING LOBBY ACTIVITY ===`);
        console.log(`Lobby ID: ${lobbyId}`);
        console.log(`AI Players: ${lobby.ai_players ? lobby.ai_players.size : 0}`);
        
        if (this.lobbyTimers.has(lobbyId)) {
            this.stopLobbyActivity(lobbyId);
        }

        const conversationTimer = setInterval(() => {
            this.triggerBotConversation(lobbyId);
        }, 15000);

        this.lobbyTimers.set(lobbyId, {
            conversation: conversationTimer
        });

        setTimeout(() => {
            this.triggerInitialConversation(lobbyId);
        }, 4000);
    }

    stopLobbyActivity(lobbyId) {
        const timers = this.lobbyTimers.get(lobbyId);
        if (timers) {
            clearInterval(timers.conversation);
            this.lobbyTimers.delete(lobbyId);
        }
        
        if (this.pendingResponses.has(lobbyId)) {
            this.pendingResponses.delete(lobbyId);
        }
        
        if (this.messageProcessingTimers.has(lobbyId)) {
            const timerIds = this.messageProcessingTimers.get(lobbyId);
            timerIds.forEach(timerId => clearTimeout(timerId));
            this.messageProcessingTimers.delete(lobbyId);
        }
    }

    async triggerInitialConversation(lobbyId) {
        const lobbyBots = this.lobbyBots.get(lobbyId);
        if (!lobbyBots || lobbyBots.size === 0) return;

        const botsArray = Array.from(lobbyBots.values());
        if (botsArray.length >= 2) {
            const bot1 = botsArray[0];
            const bot2 = botsArray[1];

            setTimeout(async () => {
                const message1 = await this.generateConversationStarter(bot1, lobbyId);
                if (this.activeLobby && message1) {
                    this.activeLobby.addChatMessage(bot1.id, message1);

                    setTimeout(async () => {
                        const message2 = await this.generateConversationResponse(bot2, message1, bot1.name, lobbyId);
                        if (this.activeLobby && message2) {
                            this.activeLobby.addChatMessage(bot2.id, message2);
                        }
                    }, 1500);
                }
            }, 1000);
        }
    }

    async triggerBotConversation(lobbyId) {
        if (!this.activeLobby) return;

        const lobbyBots = this.lobbyBots.get(lobbyId);
        if (!lobbyBots || lobbyBots.size < 2) return;

        const history = this.conversationHistory.get(lobbyId) || [];
        const timeSinceLastMessage = Date.now() - (history[history.length - 1]?.timestamp || 0);

        if (timeSinceLastMessage < 10000) return;

        const availableBots = Array.from(lobbyBots.values()).filter(bot => {
            const lastTime = this.lastBotResponse.get(bot.id) || 0;
            return (Date.now() - lastTime) > 4000;
        });

        if (availableBots.length < 2) return;

        const shouldStartConversation = Math.random() < 0.4;
        if (!shouldStartConversation) return;

        try {
            const shuffledBots = availableBots.sort(() => Math.random() - 0.5);
            const bot1 = shuffledBots[0];
            const bot2 = shuffledBots[1];

            const message1 = await this.generateConversationStarter(bot1, lobbyId);
            if (!message1) return;

            setTimeout(() => {
                if (this.activeLobby) {
                    this.activeLobby.addChatMessage(bot1.id, message1);

                    setTimeout(async () => {
                        const message2 = await this.generateConversationResponse(bot2, message1, bot1.name, lobbyId);
                        if (this.activeLobby && message2) {
                            this.activeLobby.addChatMessage(bot2.id, message2);
                        }
                    }, 1500);
                }
            }, 500);

        } catch (error) {
            console.log("Bot conversation error:", error.message);
        }
    }

    async processHumanMessage(humanMessage, humanName, lobbyId) {
        const lobbyBots = this.lobbyBots.get(lobbyId);
        if (!lobbyBots || lobbyBots.size === 0) return;

        const messageId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        const availableBots = Array.from(lobbyBots.values()).filter(bot => {
            const lastTime = this.lastBotResponse.get(bot.id) || 0;
            return (Date.now() - lastTime) > 1500;
        });

        if (availableBots.length === 0) return;

        const botsToRespond = availableBots.filter(bot => {
            const shouldRespond = this.shouldBotRespond({
                message: humanMessage,
                speaker: humanName,
                timestamp: Date.now()
            }, bot, this.conversationHistory.get(lobbyId) || [], 1.0);
            return shouldRespond;
        });

        if (botsToRespond.length === 0) return;

        const selectedBot = botsToRespond[Math.floor(Math.random() * Math.min(botsToRespond.length, 2))];
        const responseDelay = Math.random() * 1500 + 800;

        if (!this.messageProcessingTimers.has(lobbyId)) {
            this.messageProcessingTimers.set(lobbyId, []);
        }

        const timerId = setTimeout(async () => {
            try {
                if (!this.activeLobby) return;
                
                const aiResponse = await this.generateConversationResponse(selectedBot, humanMessage, humanName, lobbyId);
                if (aiResponse && this.activeLobby) {
                    this.activeLobby.addChatMessage(selectedBot.id, aiResponse, false, null, null, false);
                }
            } catch (error) {
                console.error('Error generating bot response:', error);
            }
        }, responseDelay);

        this.messageProcessingTimers.get(lobbyId).push(timerId);

        setTimeout(() => {
            const timers = this.messageProcessingTimers.get(lobbyId);
            if (timers) {
                const index = timers.indexOf(timerId);
                if (index > -1) {
                    timers.splice(index, 1);
                }
            }
        }, responseDelay + 100);
    }

    async generateConversationStarter(aiPlayer, lobbyId) {
        try {
            const profile = aiPlayer.profile;
            const recentHistory = this.getRecentHistory(lobbyId, 8);
            
            const prompt = `You are ${profile.name}, ${profile.personality}. Start an engaging conversation about one of your interests: ${profile.favoriteTopics.join(', ')}.

            Recent chat to avoid repeating:
            ${recentHistory}

            Write something specific, interesting, and conversational. No greetings or introductions. Be natural and engaging. Under 25 words.
            
            Examples of good starters:
            - "Did you know octopuses have three hearts but still get tired easily?"
            - "Just realized that color blue doesn't actually exist in nature the way we think"
            - "The way our brain processes music is basically pattern recognition on steroids"
            
            Avoid generic phrases like "hey", "anyone else", "what do you think".`;

            const response = await anthropic.messages.create({
                model: 'claude-3-haiku-20240307',
                max_tokens: 60,
                temperature: 0.9,
                messages: [{
                    role: 'user',
                    content: prompt
                }]
            });

            let aiResponse = response.content[0].text.trim();
            aiResponse = this.cleanResponse(aiResponse, aiPlayer.name);
            
            this.updateConversationHistory(lobbyId, aiPlayer.name, aiResponse, true);
            return aiResponse;

        } catch (error) {
            console.log("Conversation starter error:", error.message);
            return this.getFallbackStarter(aiPlayer);
        }
    }

    async generateConversationResponse(aiPlayer, previousMessage, previousSpeaker, lobbyId) {
        try {
            const profile = aiPlayer.profile;
            const recentHistory = this.getRecentHistory(lobbyId, 6);
            
            const prompt = `You are ${profile.name}, ${profile.personality}. 
            Your response style: ${profile.responseStyle}.
            Your interests: ${profile.favoriteTopics.join(', ')}.

            ${previousSpeaker} just said: "${previousMessage}"

            Respond naturally and conversationally. Build on what they said, add your perspective, or share related knowledge. Be specific and engaging. Under 30 words.
            
            Recent conversation context:
            ${recentHistory}

            Examples of good responses:
            - "That's wild! It reminds me of how dolphins sleep with half their brain awake"
            - "Actually, that connects to something I read about fractals in nature"
            - "Makes sense when you think about it from an evolutionary perspective"
            
            Avoid generic responses like "interesting", "totally", "I agree".`;

            const response = await anthropic.messages.create({
                model: 'claude-3-haiku-20240307',
                max_tokens: 70,
                temperature: 0.8,
                messages: [{
                    role: 'user',
                    content: prompt
                }]
            });

            let aiResponse = response.content[0].text.trim();
            aiResponse = this.cleanResponse(aiResponse, aiPlayer.name);
            
            if (this.isGenericResponse(aiResponse)) {
                return this.generateSpecificResponse(previousMessage, aiPlayer);
            }
            
            this.updateConversationHistory(lobbyId, aiPlayer.name, aiResponse, true);
            return aiResponse;

        } catch (error) {
            console.log("Conversation response error:", error.message);
            return this.generateSpecificResponse(previousMessage, aiPlayer);
        }
    }

    async generateChatResponse(humanMessage, humanName, aiPlayer, lobbyId) {
        await this.processHumanMessage(humanMessage, humanName, lobbyId);
        return null;
    }

    shouldBotRespond(lastMessage, bot, history, multiplier = 1.0) {
        const profile = bot.profile;
        
        if (lastMessage.speaker === bot.name || lastMessage.speaker === bot.id) {
            return false;
        }
        
        if (lastMessage.message.toLowerCase().includes(bot.name.toLowerCase())) {
            return Math.random() < (0.8 * multiplier);
        }
        
        const messageTopics = this.extractTopics(lastMessage.message);
        const sharedTopics = messageTopics.filter(topic => 
            profile.favoriteTopics.some(favTopic => 
                topic.includes(favTopic) || favTopic.includes(topic)
            )
        );
        
        if (sharedTopics.length > 0) {
            return Math.random() < (0.7 * multiplier);
        }
        
        if (lastMessage.message.includes('?')) {
            return Math.random() < (0.6 * multiplier);
        }
        
        const recentBotMessages = history.slice(-3).filter(msg => msg.isAI).length;
        if (recentBotMessages >= 2) {
            return Math.random() < (0.2 * multiplier);
        }
        
        return Math.random() < (profile.chattiness * multiplier);
    }

    extractTopics(message) {
        const topicWords = [
            'music', 'movie', 'film', 'book', 'game', 'sport', 'food', 'travel',
            'work', 'school', 'family', 'friend', 'weather', 'technology', 'art',
            'science', 'politics', 'news', 'hobby', 'pet', 'car', 'house', 'money',
            'love', 'relationship', 'adventure', 'creative', 'design', 'space',
            'quantum', 'brain', 'psychology', 'philosophy', 'nature', 'ocean'
        ];
        
        const lowerMessage = message.toLowerCase();
        return topicWords.filter(word => lowerMessage.includes(word));
    }

    isGenericResponse(response) {
        const genericPhrases = [
            'totally', 'you right', 'exactly', 'true that', 'for sure',
            'nice', 'cool', 'awesome', 'yeah', 'definitely', 'agreed',
            'same here', 'makes sense', 'good point', 'i agree',
            'that\'s interesting', 'sounds good', 'absolutely', 'right on'
        ];
        
        const lowerResponse = response.toLowerCase();
        return genericPhrases.some(phrase => lowerResponse.includes(phrase)) && response.length < 25;
    }

    generateSpecificResponse(lastMessage, aiPlayer) {
        const profile = aiPlayer.profile;
        const responses = [
            `That connects to something I read about ${profile.favoriteTopics[0]}`,
            `Interesting perspective on ${profile.favoriteTopics[1]}`,
            `Makes me think of this study I saw recently`,
            `The ${profile.favoriteTopics[0]} angle is fascinating here`,
            `Never thought about it from that direction`,
            `That's like the opposite of what happens in ${profile.favoriteTopics[2]}`,
            `Reminds me of this counterintuitive fact I learned`
        ];
        
        return responses[Math.floor(Math.random() * responses.length)];
    }

    getFallbackStarter(aiPlayer) {
        const profile = aiPlayer.profile;
        const starters = [
            `Just discovered this weird connection between ${profile.favoriteTopics[0]} and mathematics`,
            `The way ${profile.favoriteTopics[1]} evolved is actually mind-bending`,
            `Found this counterintuitive fact about ${profile.favoriteTopics[2]} today`,
            `Been thinking about how ${profile.favoriteTopics[0]} defies common sense`,
            `Stumbled upon something that completely changed my view on ${profile.favoriteTopics[1]}`,
            `The science behind ${profile.favoriteTopics[2]} is way weirder than expected`
        ];
        
        return starters[Math.floor(Math.random() * starters.length)];
    }

    async generateEventResponse(eventData, aiPlayer, allPlayers, lobbyId) {
        console.log(`AI ${aiPlayer.name} responding to event: ${eventData.type}`);
        
        let response = "";
        
        switch (eventData.type) {
            case "speed_challenge":
                response = eventData.text.match(/'([^']+)'/)?.[1] || "CHAMPION";
                break;
                
            case "vote_bonus":
                const eligiblePlayers = allPlayers.filter(p => p.id !== aiPlayer.id);
                if (eligiblePlayers.length > 0) {
                    const chosen = eligiblePlayers[Math.floor(Math.random() * eligiblePlayers.length)];
                    response = chosen.name;
                }
                break;
                
            case "vote_eliminate":
                response = Math.random() > 0.6 ? "YES" : "NO";
                break;
                
            case "trivia":
                if (Math.random() > 0.3) {
                    response = eventData.correctAnswer;
                } else {
                    const wrongAnswers = ["London", "Berlin", "Madrid", "1944", "1946", "Rome", "Saturn"];
                    response = wrongAnswers[Math.floor(Math.random() * wrongAnswers.length)];
                }
                break;
                
            case "confession":
            case "story_time":
            case "debate":
            case "would_rather":
            case "talent_show":
                try {
                    const profile = aiPlayer.profile;
                    const prompt = `Event: "${eventData.text}". 
                    
                    You are ${profile.name} (${profile.personality}). Respond naturally to this event as if you're in a casual game with friends. Be specific and authentic. Under 25 words.
                    
                    Examples:
                    - For embarrassing moment: "Once tried to impress someone by doing a backflip, landed flat on my face instead"
                    - For talent: "I can solve Rubik's cubes blindfolded, learned it during lockdown"
                    - For debate: "Team pineapple! Sweet and savory combinations are chef's kiss"`;
                    
                    const aiResponse = await anthropic.messages.create({
                        model: 'claude-3-haiku-20240307',
                        max_tokens: 50,
                        temperature: 0.8,
                        messages: [{
                            role: 'user',
                            content: prompt
                        }]
                    });
                    
                    response = this.cleanResponse(aiResponse.content[0].text.trim(), aiPlayer.name);
                } catch (error) {
                    response = "That's a tough one to answer!";
                }
                break;
                
            default:
                response = "Interesting challenge!";
        }
        
        this.updateConversationHistory(lobbyId, aiPlayer.name, response, true);
        return response;
    }

    getRecentHistory(lobbyId, count = 5) {
        const history = this.conversationHistory.get(lobbyId) || [];
        const recent = history.slice(-count);
        
        if (recent.length === 0) return "No recent messages";
        
        return recent.map(msg => `${msg.speaker}: ${msg.message}`).join('\n');
    }

    updateConversationHistory(lobbyId, speaker, message, isAI = false) {
        if (!this.conversationHistory.has(lobbyId)) {
            this.conversationHistory.set(lobbyId, []);
        }

        const history = this.conversationHistory.get(lobbyId);
        history.push({
            speaker,
            message,
            timestamp: Date.now(),
            isAI
        });

        if (history.length > 40) {
            this.conversationHistory.set(lobbyId, history.slice(-40));
        }

        if (isAI) {
            this.lastBotResponse.set(speaker, Date.now());
        }

        console.log(`Updated conversation history for lobby ${lobbyId}. Messages: ${history.length}`);
    }

    cleanResponse(response, botName) {
        response = response.replace(/^\*[^*]*\*\s*/, '');
        response = response.replace(/\*[^*]*\*/g, '');
        response = response.replace(new RegExp(`^${botName}:\\s*`, 'i'), '');
        response = response.replace(/^(AI|Bot|Assistant):\\s*/i, '');
        response = response.replace(/^["']|["']$/g, '');
        response = response.replace(/^(As |Being |I'm |I am )/i, '');
        
        if (response.length > 120) {
            const sentences = response.split(/[.!?]+/);
            response = sentences[0] + (sentences[0].match(/[.!?]$/) ? '' : '.');
        }
        
        return response.trim();
    }

    clearLobbyHistory(lobbyId) {
        this.stopLobbyActivity(lobbyId);
        this.conversationHistory.delete(lobbyId);
        this.lobbyBots.delete(lobbyId);
        this.conversationThreads.delete(lobbyId);
        
        const botsToClean = [];
        this.lastBotResponse.forEach((timestamp, botId) => {
            if (botId.includes('ai_') && !Array.from(this.lobbyBots.values()).some(lobby => 
                Array.from(lobby.values()).some(bot => bot.id === botId)
            )) {
                botsToClean.push(botId);
            }
        });
        
        botsToClean.forEach(botId => {
            this.lastBotResponse.delete(botId);
            this.botProfiles.delete(botId);
        });

        console.log(`Cleared lobby history for ${lobbyId}`);
    }

    async testAPIConnection() {
        try {
            const testResponse = await anthropic.messages.create({
                model: 'claude-3-haiku-20240307',
                max_tokens: 20,
                messages: [{
                    role: 'user',
                    content: 'Respond with "API Working"'
                }]
            });
            console.log("Claude API Test Success:", testResponse.content[0].text);
            return true;
        } catch (error) {
            console.log("Claude API Test Failed:", error.message);
            return false;
        }
    }
}

const aiManager = new AIManager();

module.exports = {
    AIManager,
    aiManager,
    AI_AVATARS
};