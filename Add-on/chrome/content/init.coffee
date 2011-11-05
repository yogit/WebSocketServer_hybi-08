##
# XPCOMのコンポーネントを使うときに簡略化するための変数。
##
Cc = Components.classes

##
# XPCOMのコンポーネントを使うときに簡略化するための変数。
##
Ci = Components.interfaces

##
# Firefox上のJavaScriptのwindowオブジェクトにアクセスするための変数。
##
browserWin = null

##
# FirefoxのWeb Consoleに情報を吐くためのもの(デバッグ用)。
# debug, error, info, log, trace, warnメソッドが使えるようにする。
##
console = null

window.addEventListener 'DOMContentLoaded',
  ->
    browserWin = window.content.window.wrappedJSObject
    console = browserWin.console
    # WebSocketServerクラスを追加する
    browserWin.WebSocketServer = WebSocketServer
  , false
