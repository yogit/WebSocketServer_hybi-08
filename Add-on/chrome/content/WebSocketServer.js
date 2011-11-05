var WebSocketServer;
WebSocketServer = (function() {
  WebSocketServer.STOP = 0;
  WebSocketServer.RUNNING = 1;
  WebSocketServer.prototype.STOP = 0;
  WebSocketServer.prototype.RUNNING = 1;
  function WebSocketServer(opt_config) {
    var clientHandler, clientNum, clientPool, config, doStart, doStop, onconnectClient, self, socket;
    if (!(this instanceof WebSocketServer)) {
      return new WebSocketServer(opt_config);
    }
    if (!(opt_config != null)) {
      opt_config = {};
    }
    if (typeof opt_config !== 'object') {
      throw new Error('Invalid Argument');
    }
    config = {
      port: opt_config.port || 8080,
      resource: opt_config.resource || '/',
      origin: "" + browserWin.location.protocol + "//" + browserWin.location.host,
      pingInterval: opt_config.pingInterval || 0,
      pingMessage: opt_config.pingMessage || 'PING'
    };
    self = this;
    clientPool = {};
    clientNum = 0;
    socket = Cc['@mozilla.org/network/server-socket;1'].createInstance(Ci.nsIServerSocket);
    clientHandler = {
      onopen: function(client) {
        clientPool[client.host + ':' + client.port] = client;
        ++clientNum;
        return self.onconnect(client);
      },
      doBroadcast: function(client, data) {
        var id, myId, _results;
        myId = client.host + ':' + client.port;
        _results = [];
        for (id in clientPool) {
          _results.push(id !== myId ? clientPool[id].send(data) : void 0);
        }
        return _results;
      },
      onclose: function(client) {
        delete clientPool[client.host + ':' + client.port];
        --clientNum;
        return self.ondisconnect(client);
      }
    };
    onconnectClient = {
      handler: clientHandler,
      onSocketAccepted: function(serverSocket, clientSocket) {
        var wsc;
        console.log('onSocketAccepted');
        return wsc = new WebSocketClient(clientSocket, config, this.handler);
      },
      onStopListening: function(serverSocket, reson) {
        console.log("onStopListening: " + reson);
        self.readyState = WebSocketServer.STOP;
        return self.onstop();
      }
    };
    doStart = function() {
      try {
        socket.init(config.port, false, -1);
        return socket.asyncListen(onconnectClient);
      } finally {
        self.readyState = WebSocketServer.RUNNING;
        self.onstart();
      }
    };
    doStop = function() {
      var i;
      if (clientNum) {
        for (i in clientPool) {
          clientPool[i].close();
          console.log("" + clientPool[i].host + ":" + clientPool[i].port + " close()");
        }
      }
      return socket.close();
    };
    this.readyState = WebSocketServer.STOP;
    this.getConfig = function() {
      return config;
    };
    this.start = function() {
      return doStart();
    };
    this.stop = function() {
      if (this.readyState === WebSocketServer.RUNNING) {
        return doStop();
      }
    };
  }
  WebSocketServer.prototype.onstart = function() {};
  WebSocketServer.prototype.onstop = function() {};
  WebSocketServer.prototype.onconnect = function(clientObj) {};
  WebSocketServer.prototype.ondisconnect = function(clientObj) {};
  return WebSocketServer;
})();