$(function () {

function log (msg) {
  var logObj = $("#log");
  var old = logObj.html();
  var now = new Date().toTimeString().split(' ')[0];
  logObj.html('[' + now + '] ' + msg + "<br>" + old);
}

$("#startBtn").click(function () {
  if (!("WebSocketServer" in window)) {
      log("'WebSocketServer'が未定義です");
      return false;
  }

  var options = {
    // 以下の値はデフォルト値が指定されているので省略しても問題ない
    // port: 8080,
    // resource: '/',
    // pingInterval: 0,
    // pingMessage: 'PING'
  };

  server = new WebSocketServer(options) || WebSocketServer(options);
  server.onstart = function () {
    $('#startBtn').hide();
    $('#stopBtn').show();
    addEventListener("beforeunload", function (e) {
      if (server.readyState == server.RUNNING) {
        server.stop();
      }
    }, true);
    log('server start');
  };
  server.onstop = function () {
    $('#startBtn').show();
    $('#stopBtn').hide();
    log('server stop');
  };
  server.onconnect = function (client) {
    log('[' + client.host + ':' + client.port + '] connected');
    client.onmessage = function (data) {
      log('[' + client.host + ':' + client.port + '] recieved(' + data.length + '): ' + data);
      client.send(data);      // 受信したデータをそのまま送り返す
      //client.broadcast(data); // 他の接続済みクライアントにも送信
    };
  };
  server.ondisconnect = function (client) {
    log('[' + client.host + ':' + client.port + '] disconnected');
  };

  server.start();
});

$('#stopBtn').click(function () {
  server.stop()
});

})
