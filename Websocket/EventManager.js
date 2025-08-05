class EventManager {
    constructor(lobby) {
        this.lobby = lobby;
        this.messageCountSinceEvent = 0;
        this.timeUntilNextEvent = 0;
        this.lastCountdownUpdate = Date.now();
        this.eventTimer = null;
        this.countdownTimer = null;
        this.currentEvent = null;
        this.eventActive = false;
        this.resetCounters();
    }

    resetCounters() {
        console.log(`EVENT MANAGER - Resetting counters for lobby ${this.lobby.id}`);
        console.log(`EVENT MANAGER - Event by messages: ${this.lobby.config.event_by_messages}`);
        
        if (this.lobby.config.event_by_messages) {
            this.messageCountSinceEvent = 0;
            const targetMessages = this.lobby.config.messages_interval || 5;
            console.log(`EVENT MANAGER - Reset message counter. Target: ${targetMessages} messages`);
        } else {
            this.timeUntilNextEvent = this.lobby.config.seconds_interval || 120;
            this.lastCountdownUpdate = Date.now();
            console.log(`EVENT MANAGER - Reset time counter. Target: ${this.timeUntilNextEvent} seconds`);
        }
        
        this.eventActive = false;
        
        this.broadcastLobbyUpdate();
    }

    onMessageSent(isHumanMessage = false) {
        if (!this.lobby.config.event_by_messages) return;
        if (this.eventActive) {
            console.log(`EVENT MANAGER - Message ignored, event is active in lobby ${this.lobby.id}`);
            return;
        }

        this.messageCountSinceEvent++;
        const targetMessages = this.lobby.config.messages_interval || 5;
        
        console.log(`EVENT MANAGER - Message counted. Count: ${this.messageCountSinceEvent}/${targetMessages}`);
        console.log(`EVENT MANAGER - Lobby: ${this.lobby.id}`);
        console.log(`EVENT MANAGER - Is human message: ${isHumanMessage}`);
        console.log(`EVENT MANAGER - Event active: ${this.eventActive}`);
        
        this.broadcastLobbyUpdate();
        
        if (this.messageCountSinceEvent >= targetMessages) {
            console.log(`EVENT MANAGER - Triggering event after ${this.messageCountSinceEvent} messages`);
            this.eventActive = true;
            setTimeout(() => {
                this.lobby.triggerRandomEvent();
            }, 2000);
        }
    }

    onHumanMessageSent() {
        this.onMessageSent(true);
    }

    onBotMessageSent() {
        this.onMessageSent(false);
    }

    onEventStarted(gameEvent) {
        this.currentEvent = gameEvent;
        this.eventActive = true;
        console.log(`EVENT MANAGER - Event started: ${gameEvent.type}`);
        console.log(`EVENT MANAGER - Message count when started: ${this.messageCountSinceEvent}`);
        console.log(`EVENT MANAGER - Event now active, pausing counting`);
        
        this.broadcastLobbyUpdate();
    }

    onEventResolved() {
        console.log(`EVENT MANAGER - Event resolved in lobby ${this.lobby.id}`);
        console.log(`EVENT MANAGER - Final message count: ${this.messageCountSinceEvent}`);
        
        this.currentEvent = null;
        this.eventActive = false;
        this.resetCounters();
        
        if (!this.lobby.config.event_by_messages) {
            this.startTimer();
        }
        
        console.log(`EVENT MANAGER - Counting resumed, counter reset`);
        
        this.lobby.broadcastToLobby({
            type: 'event_resolved',
            lobby_data: this.lobby.getLobbyData()
        });
    }

    broadcastLobbyUpdate() {
        setTimeout(() => {
            this.lobby.broadcastToLobby({
                type: 'lobby_updated',
                data: this.lobby.getLobbyData()
            });
        }, 100);
    }

    startTimer() {
        if (this.lobby.config.event_by_messages) return;
        
        this.stopTimer();
        const intervalSeconds = this.lobby.config.seconds_interval || 120;
        const intervalMs = intervalSeconds * 1000;
        
        console.log(`EVENT MANAGER - Starting timer for lobby ${this.lobby.id}: ${intervalSeconds} seconds`);
        
        this.timeUntilNextEvent = intervalSeconds;
        this.lastCountdownUpdate = Date.now();
        
        this.countdownTimer = setInterval(() => {
            this.updateCountdown();
        }, 1000);
        
        this.eventTimer = setTimeout(() => {
            if (!this.eventActive) {
                console.log(`EVENT MANAGER - Time-based event triggered for lobby ${this.lobby.id}`);
                this.eventActive = true;
                this.lobby.triggerRandomEvent();
            } else {
                console.log(`EVENT MANAGER - Timer skipped, event already active in lobby ${this.lobby.id}`);
            }
        }, intervalMs);
    }

    updateCountdown() {
        if (this.lobby.config.event_by_messages || this.eventActive) return;
        
        const now = Date.now();
        const elapsed = Math.floor((now - this.lastCountdownUpdate) / 1000);
        
        if (elapsed >= 1) {
            this.timeUntilNextEvent = Math.max(0, this.timeUntilNextEvent - elapsed);
            this.lastCountdownUpdate = now;
            
            if (this.timeUntilNextEvent % 5 === 0 || this.timeUntilNextEvent <= 10) {
                this.broadcastLobbyUpdate();
            }
            
            if (this.timeUntilNextEvent <= 0 && !this.eventActive) {
                console.log(`EVENT MANAGER - Countdown reached zero, triggering event`);
                this.eventActive = true;
                clearTimeout(this.eventTimer);
                clearInterval(this.countdownTimer);
                setTimeout(() => {
                    this.lobby.triggerRandomEvent();
                }, 1000);
            }
        }
    }

    stopTimer() {
        if (this.eventTimer) {
            clearTimeout(this.eventTimer);
            this.eventTimer = null;
        }
        if (this.countdownTimer) {
            clearInterval(this.countdownTimer);
            this.countdownTimer = null;
        }
    }

    getNextEventInfo() {
        if (this.eventActive) {
            return {
                type: this.lobby.config.event_by_messages ? "messages" : "seconds",
                remaining: 0,
                total: this.lobby.config.event_by_messages ? 
                    (this.lobby.config.messages_interval || 5) : 
                    (this.lobby.config.seconds_interval || 120),
                current: this.messageCountSinceEvent,
                eventActive: true
            };
        }

        if (this.lobby.config.event_by_messages) {
            const target = this.lobby.config.messages_interval || 5;
            return {
                type: "messages",
                remaining: Math.max(0, target - this.messageCountSinceEvent),
                total: target,
                current: this.messageCountSinceEvent,
                eventActive: false
            };
        } else {
            return {
                type: "seconds",
                remaining: this.timeUntilNextEvent,
                total: this.lobby.config.seconds_interval || 120,
                current: 0,
                eventActive: false
            };
        }
    }
}

module.exports = { EventManager };