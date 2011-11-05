var WebSocketClient;
WebSocketClient = (function() {
  function WebSocketClient(socket, serverConfig, handler) {
    var PingTimer, binaryInputStream, checkHandshakeData, createHandshakeData, doBroadcast, doClose, inputStream, listener, onclose, onopen, outputStream, pump, readData, self, sendCloseFrame, sendDataFrame, sendFrame, sendPongFrame;
    self = this;
    inputStream = socket.openInputStream(0, 0, 0);
    binaryInputStream = Cc['@mozilla.org/binaryinputstream;1'].createInstance(Ci.nsIBinaryInputStream);
    binaryInputStream.setInputStream(inputStream);
    outputStream = socket.openOutputStream(0, 0, 0);
    pump = Cc['@mozilla.org/network/input-stream-pump;1'].createInstance(Ci.nsIInputStreamPump);
    this.host = socket.host;
    this.port = socket.port;
    this.readyState = WebSocketClient.CONNECTING;
    onopen = handler.onopen;
    doBroadcast = handler.doBroadcast;
    onclose = handler.onclose;
    this.send = function(data) {
      return sendDataFrame(data);
    };
    this.broadcast = function(data) {
      return doBroadcast(self, data);
    };
    this.close = function() {
      return doClose();
    };
    sendFrame = function(obj) {
      var frameObj, sendData;
      frameObj = new DataFrame(obj);
      sendData = frameObj.convert2bytes();
      browserWin.HOGE = frameObj;
      return outputStream.write(sendData, sendData.length);
    };
    sendDataFrame = function(data) {
      return sendFrame({
        FIN: true,
        opcode: DataFrame.TEXT,
        payloadData: data
      });
    };
    sendCloseFrame = function(code, reson) {
      return sendFrame({
        FIN: true,
        opcode: DataFrame.CLOSE,
        payloadData: [code, reson]
      });
    };
    sendPongFrame = function(msg) {
      return sendFrame({
        FIN: true,
        opcode: DataFrame.PONG,
        payloadData: msg
      });
    };
    PingTimer = (function() {
      var msec, sendPingFrame, timerId;
      timerId = null;
      msec = 0;
      function PingTimer() {
        if (serverConfig['pingInterval'] === 0) {
          return false;
        }
        msec = serverConfig['pingInterval'] * 1000;
        timerId = setInterval(sendPingFrame, msec);
      }
      sendPingFrame = function() {
        if (self.readyState !== WebSocketClient.OPEN) {
          return clearInterval(timerId);
        } else {
          sendFrame({
            FIN: true,
            opcode: DataFrame.PING,
            payloadData: serverConfig['pingMessage']
          });
          return console.log('sended ping');
        }
      };
      PingTimer.prototype.reset = function() {
        clearInterval(timerId);
        return timerId = setInterval(sendPingFrame, msec);
      };
      return PingTimer;
    })();
    checkHandshakeData = function(data) {
      var headerFields, i, k, lines, obj, v, _ref, _ref2;
      obj = {
        key: null
      };
      lines = data.split('\r\n');
      if (lines[0] !== ("GET " + serverConfig['resource'] + " HTTP/1.1")) {
        return false;
      }
      headerFields = {};
      for (i = 1, _ref = lines.length; 1 <= _ref ? i <= _ref : i >= _ref; 1 <= _ref ? i++ : i--) {
        if (!(lines[i] != null)) {
          continue;
        }
        _ref2 = lines[i].split(': '), k = _ref2[0], v = _ref2[1];
        headerFields[k] = v;
      }
      if (headerFields['Upgrade'] !== 'websocket') {
        return false;
      }
      if (headerFields['Connection'].indexOf('Upgrade') === -1) {
        return false;
      }
      if (atob(headerFields['Sec-WebSocket-Key']).length !== 16) {
        return false;
      }
      obj['key'] = headerFields['Sec-WebSocket-Key'];
      if (headerFields['Sec-WebSocket-Origin'] !== serverConfig['origin']) {
        return false;
      }
      if (headerFields['Sec-WebSocket-Version'] !== '8') {
        return false;
      }
      return obj;
    };
    createHandshakeData = function(obj) {
      var accept, ch, converter, data, sendData, tmp;
      converter = Cc['@mozilla.org/intl/scriptableunicodeconverter'].createInstance(Ci.nsIScriptableUnicodeConverter);
      converter.charset = 'UTF-8';
      tmp = "" + obj['key'] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
      data = converter.convertToByteArray(tmp, {});
      ch = Cc['@mozilla.org/security/hash;1'].createInstance(Ci.nsICryptoHash);
      ch.init(Ci.nsICryptoHash.SHA1);
      ch.update(data, data.length);
      accept = ch.finish(true);
      sendData = 'HTTP/1.1 101 Switching Protocols\r\n';
      sendData += 'Upgrade: websocket\r\n';
      sendData += 'Connection: Upgrade\r\n';
      sendData += "Sec-WebSocket-Accept: " + accept + "\r\n";
      sendData += '\r\n';
      return sendData;
    };
    doClose = function() {
      if (!socket.isAlive()) {
        return false;
      }
      switch (self.readyState) {
        case WebSocketClient.OPEN:
          self.readyState = WebSocketClient.CLOSING;
          sendCloseFrame(1000, '');
          return setTimeout(function() {
            if (self.readyState !== WebSocketClient.CLOSED) {
              console.error('close connection timeout');
              return socket.close(42);
            }
          }, 100);
        case WebSocketClient.CLOSING:
          return socket.close(42);
      }
    };
    readData = function() {
      var body, count, frame, handshakeData, result, timer, tmpData;
      frame = null;
      timer = null;
      while (self.readyState !== WebSocketClient.CLOSED) {
        count = yield;
        tmpData = binaryInputStream.readBytes(count);
        switch (self.readyState) {
          case WebSocketClient.CONNECTING:
            result = checkHandshakeData(tmpData);
            if (result) {
              handshakeData = createHandshakeData(result);
              outputStream.write(handshakeData, handshakeData.length);
              self.readyState = WebSocketClient.OPEN;
              if (serverConfig['pingInterval']) {
                timer = new PingTimer;
              }
              onopen(self);
            } else {
              console.error('handshake faild');
              socket.close(42);
            }
            break;
          case WebSocketClient.OPEN:
          case WebSocketClient.CLOSING:
            if (frame) {
              frame.payloadData += tmpData;
            } else {
              frame = new DataFrame(tmpData);
            }
            if (frame.payloadLen > frame.payloadData.length) {
              continue;
            }
            body = frame.getBody();
            switch (frame.opcode) {
              case DataFrame.CONNECTING:
                break;
              case DataFrame.CLOSE:
                console.log("recieved Close: " + body);
                doClose();
                break;
              case DataFrame.PING:
                console.log("recieved Ping: " + body);
                sendPongFrame(body);
                break;
              case DataFrame.PONG:
                console.log("recieved Pong: " + body);
                break;
              case DataFrame.TEXT:
              case DataFrame.BINARY:
                console.log("recieved: " + body);
                console.log("body size: " + body.length);
                if (typeof self.onmessage === 'function') {
                  self.onmessage(body);
                }
            }
            if (timer) {
              timer.reset();
            }
            frame = null;
        }
      }
    };
    listener = {
      generator: readData(),
      onStartRequest: function() {
        console.log('onStartRequest');
        return this.generator.next();
      },
      onStopRequest: function(request, context, statusCode) {
        console.log("onStopRequest: " + context + ", " + statusCode);
        if (socket.isAlive()) {
          console.error('input stream down');
          doClose();
        }
        self.readyState = WebSocketClient.CLOSED;
        return onclose(self);
      },
      onDataAvailable: function(request, context, inputStream, offset, count) {
        return this.generator.send(count);
      }
    };
    try {
      pump.init(inputStream, -1, -1, 0, 0, true);
      pump.asyncRead(listener, null);
    } catch (e) {
      console.error(e);
    }
  }
  return WebSocketClient;
})();
WebSocketClient.prototype.onmessage = function(msg) {};
WebSocketClient.CONNECTING = 0;
WebSocketClient.OPEN = 1;
WebSocketClient.CLOSING = 2;
WebSocketClient.CLOSED = 3;
WebSocketClient.prototype.CONNECTING = 0;
WebSocketClient.prototype.OPEN = 1;
WebSocketClient.prototype.CLOSING = 2;
WebSocketClient.prototype.CLOSED = 3;