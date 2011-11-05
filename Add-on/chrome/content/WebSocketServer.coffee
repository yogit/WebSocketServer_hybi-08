##
# WebSocketServerクラス
#
# @param {object} [opt_config] サーバの各種設定を指定するオブジェクト
# @see WebSocketClient
##
class WebSocketServer
  ##
  # サーバの停止状態を表すキー。
  #
  # @constant
  ##
  @STOP = 0

  ##
  # サーバの起動状態を表すキー。
  #
  # @constant
  ##
  @RUNNING = 1

  # なぜかWebアプリ側からクラス変数が見えないのでprototypeでも宣言しておく
  # MEMO: WebSocketServerクラスをnew出来ないことと関係がある？
  STOP: 0
  RUNNING: 1

  constructor: (opt_config) ->
    # 関数として呼び出されたらWebSocketServerのインスタンスを返す
    if !(this instanceof WebSocketServer)
      return new WebSocketServer opt_config

    # 引数のチェック
    if !opt_config? then opt_config = {}
    if typeof opt_config isnt 'object' then throw new Error 'Invalid Argument'

    config =
      port: opt_config.port or 8080         # 使用するポート番号。指定がなければ8080番ポートを使う
      resource: opt_config.resource or '/'  # ハンドシェイクデータのresourceの値判定に使うオプション
      origin: "#{browserWin.location.protocol}//#{browserWin.location.host}"
      pingInterval: opt_config.pingInterval or 0     # PINGフレームを送信する間隔(単位:秒)。0なら送信しない
      pingMessage: opt_config.pingMessage or 'PING'  # PINGフレーム内のメッセージ
    self = this
    clientPool = {}  # 接続済みクライアントのオブジェクトを保持する
    clientNum = 0    # 接続済みクライアントの総数
    socket = Cc['@mozilla.org/network/server-socket;1'].createInstance Ci.nsIServerSocket

    ##
    # WebSocketClientのコンストラクタに渡すコールバック関数群。
    #
    # @private
    ##
    clientHandler =
      ##
      # クライアントとのハンドシェイクに成功すると呼び出される関数。
      #
      # @private
      # @param {WebSocketClient} client ハンドシェイクに成功したクライアントのオブジェクト
      ##
      onopen: (client) ->
        clientPool[client.host + ':' + client.port] = client
        ++clientNum
        self.onconnect client  # ユーザ定義のメソッドを呼び出す

      ##
      # WebSocketClientのbroadcast()メソッド内で呼び出される関数。
      #
      # @private
      # @param {WebSocketClient} client ブロードキャストを要求したクライアントのオブジェクト
      # @param {string} data ブロードキャストするメッセージ
      # @see WebSocketClient-doBroadcast
      ##
      doBroadcast: (client, data) ->
        myId = client.host + ':' + client.port
        for id of clientPool
          if id isnt myId then clientPool[id].send(data)
          #return

      ##
      # クライアントとの接続が閉じられたとき呼び出される関数。
      #
      # @private
      # @param {WebSocketClient} client 接続していたクライアントのオブジェクト
      # @see WebSocketClient-onclose
      ##
      onclose: (client) ->
        delete clientPool[client.host + ':' + client.port]
        --clientNum
        self.ondisconnect client  # ユーザ定義のメソッドを呼び出す

    ##
    # サーバソケットのasyncListen()メソッドに渡すコールバック関数群。
    # 
    # @private
    ##
    onconnectClient =
      handler: clientHandler

      ##
      # クライアントとTCP接続すると呼び出されるメソッド。
      #
      # @private
      # @param {nsIServerSocket} serverSocket サーバソケット
      # @param {nsISocketTransport} clientSocket クライアントソケット
      onSocketAccepted: (serverSocket, clientSocket) ->
        console.log 'onSocketAccepted'
        wsc = new WebSocketClient clientSocket, config, @handler

      ##
      # サーバソケットが閉じられるときに呼び出されるメソッド。
      #
      # @private
      # @param {nsIServerSocket} serverSocket サーバソケット
      # @param {nsresult} reson サーバソケットが閉じられる理由を表す値
      onStopListening: (serverSocket, reson) ->
        console.log "onStopListening: #{reson}"
        self.readyState = WebSocketServer.STOP
        self.onstop()  # ユーザ定義のメソッドを呼び出す

    ##
    # サーバソケットを初期化しリッスン状態にする
    #
    # @private
    ##
    doStart = ->
      try
        socket.init config.port, false, -1
        socket.asyncListen onconnectClient
      finally
        self.readyState = WebSocketServer.RUNNING
        self.onstart()  # ユーザ定義のメソッドを呼び出す

    ##
    # クライアントとの接続をすべて閉じ、自身のサーバソケットも閉じる。
    #
    # @private
    ##
    doStop = () ->
      if clientNum
        for i of clientPool
          clientPool[i].close()
          console.log "#{clientPool[i].host}:#{clientPool[i].port} close()"
      socket.close()  # onStopListeningイベントが発生する

    ##
    # サーバの状態を表す変数
    ##
    @readyState = WebSocketServer.STOP

    ##
    # サーバの設定の内容を返すメソッド。
    #
    # @returns {object} 各種設定
    ##
    @getConfig = ->
      config

    ##
    # WebSocketサーバを起動するメソッド。
    ##
    @start = ->
      doStart()

    ##
    # WebSocketServerを停止するメソッド。
    ##
    @stop = ->
      if @readyState is WebSocketServer.RUNNING then doStop()

  ##
  # サーバが起動するときに呼び出されるメソッド。ユーザによって上書きされる。
  ##
  WebSocketServer::onstart = ->

  ##
  # サーバが停止するときに呼び出されるメソッド。ユーザによって上書きされる。
  ##
  WebSocketServer::onstop = ->

  ##
  # クライアントとのハンドシェイクに成功すると呼び出されるメソッド。ユーザによって上書きされる。
  #
  # @param {WebSocketClient} clientObj ハンドシェイクしたクライアントのオブジェクト
  ##
  WebSocketServer::onconnect = (clientObj) ->

  ##
  # クライアントとの接続が閉じられると呼び出されるメソッド。ユーザによって上書きされる。
  #
  # @param {WebSocketClient} clientObj 接続していたクライアントのオブジェクト
  ##
  WebSocketServer::ondisconnect = (clientObj) ->
