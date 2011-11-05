var Cc, Ci, browserWin, console;
Cc = Components.classes;
Ci = Components.interfaces;
browserWin = null;
console = null;
window.addEventListener('DOMContentLoaded', function() {
  browserWin = window.content.window.wrappedJSObject;
  console = browserWin.console;
  return browserWin.WebSocketServer = WebSocketServer;
}, false);