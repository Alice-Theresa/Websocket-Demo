/**
 * Created by sc on 2017/8/8.
 */

const WebSocket = require('ws')

const wss = new WebSocket.Server({ port: 8089 })

wss.on('connection', ws => {
    ws.on('message', message => {
        console.log('received: %s', message)
        ws.send(message)
    })
})
