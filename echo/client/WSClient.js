$(function () {
if (!window.WebSocket) window.WebSocket = MozWebSocket

function log (msg) {
    var logObj = $("#log");
    var old = logObj.html();
    var now = new Date().toTimeString().split(' ')[0];
    logObj.html('[' + now + '] ' + msg + "<br>" + old);
}

$("#connectBtn").click(function () {
    var host = $("#host").val();
    var port = $("#port").val();
    var resource = $("#resource").val();
    var url = "ws://" + host;
    if (port) url += ":" + port;
    if (resource) url += resource;

    ws = new WebSocket(url);
    ws.onopen = function () {
      $("#connectBtn").hide();
      $("#disconnectBtn").show();
      log("connected");
    };
    ws.onmessage = function (e) {
      log('received "' + e.data + '"');
    };
    ws.onclose = function () {
      log("disconnected");
      $("#disconnectBtn").hide();
      $("#connectBtn").show();
    };
});

$("#disconnectBtn").click(function () {
    ws.close();
});

$("#sendBtn").click(function () {
    var msg = $("#msg").val();
    if (msg == "") return false;
    if (ws.readyState != WebSocket.OPEN) return false
    ws.send(msg);
    $("#msg").val("");
});

})
