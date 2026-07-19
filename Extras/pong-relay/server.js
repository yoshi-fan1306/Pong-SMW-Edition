const WebSocket = require('ws');
const port = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: port });

console.log(`Relay server started on port ${port}`);

wss.on('connection', (ws) => {
    console.log('New client connected');
    ws.lobbyId = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            
            if (data.type === 'join_lobby' && data.lobby) {
                ws.lobbyId = data.lobby.toString();
                console.log(`Client assigned to room: ${ws.lobbyId}`);
                ws.send(JSON.stringify({ type: 'lobby_joined' }));
                return;
            }

            if (data.type === 'ping') {
                return;
            }

            if (ws.lobbyId) {
                wss.clients.forEach((client) => {
                    if (client !== ws && client.lobbyId === ws.lobbyId && client.readyState === WebSocket.OPEN) {
                        client.send(message);
                    }
                });
            }
        } catch (e) {
            if (ws.lobbyId) {
                wss.clients.forEach((client) => {
                    if (client !== ws && client.lobbyId === ws.lobbyId && client.readyState === WebSocket.OPEN) {
                        client.send(message);
                    }
                });
            }
        }
    });

    ws.on('close', () => {
        console.log(`Client left room: ${ws.lobbyId}`);
    });
});

