##
# WebSocketClientクラスタ
#
# @param {nsISocketTransport} socket クライアントソケット
# @param {object} serverConfig サーバの各種設定
# @param {object} handler WebSocketサーバと連携するための関数群
# @see WebSocketServer
# @see DataFrame
##
class WebSocketClient
  constructor: (socket, serverConfig, handler) ->
    self = this
    inputStream = socket.openInputStream 0, 0, 0
    binaryInputStream = Cc['@mozilla.org/binaryinputstream;1']
                         .createInstance Ci.nsIBinaryInputStream
    binaryInputStream.setInputStream inputStream
    outputStream = socket.openOutputStream 0, 0, 0
    pump = Cc['@mozilla.org/network/input-stream-pump;1']
            .createInstance Ci.nsIInputStreamPump
    @host = socket.host
    @port = socket.port
    @readyState = WebSocketClient.CONNECTING

    ##
    # ハンドシェイクに成功したことをWebSocketサーバに伝えるメソッド。
    #
    # @private
    # @function
    # @param {WebSocketClient} 接続できたクライアントのオブジェクト
    ##
    onopen = handler.onopen

    ##
    # broadcast()メソッドが呼び出されたことをWebSocketサーバに伝えるメソッド。
    #
    # @private
    # @function
    # @param {string} ブロードキャストしたいメッセージ
    ##
    doBroadcast = handler.doBroadcast

    ##
    # 接続が閉じられたことをWebSocketサーバに伝えるメソッド。
    #
    # @private
    # @function
    # @param {WebSocketClient} 接続してたクライアントのオブジェクト
    ##
    onclose = handler.onclose

    ##
    # 接続先のクライアントにメッセージを送信するメソッド。
    #
    # @param {string} data メッセージ
    ##
    @send = (data) ->
      sendDataFrame data

    ##
    # 自身を除くすべてのクライアントにメッセージを送信するメソッド。
    #
    # @param {string} data メッセージ
    ##
    @broadcast = (data) ->
      doBroadcast self, data

    ##
    # クライアントとの接続を閉じるメソッド。
    ##
    @close = ->
      doClose()

    ##
    # フレームを送信するメソッド。
    #
    # @private
    # @param {DataFrame} obj DataFrameのオブジェクト
    ##
    sendFrame = (obj) ->
      frameObj = new DataFrame obj
      sendData = frameObj.convert2bytes()
      browserWin.HOGE = frameObj
      outputStream.write sendData, sendData.length

    ##
    # テキストフレームを送信するメソッド。
    #
    # @private
    # @param {string} data メッセージ
    ##
    sendDataFrame = (data) ->
      sendFrame {
        FIN: true
        opcode: DataFrame.TEXT
        payloadData: data
      }

    ##
    # Closeフレームを送信するメソッド。
    #
    # @private
    # @param {number} code 接続閉鎖の理由を表す整数値
    # @param {string} reson 接続閉鎖の理由を表す文字列
    ##
    sendCloseFrame = (code, reson) ->
      sendFrame {
        FIN: true
        opcode: DataFrame.CLOSE
        payloadData: [code, reson]
      }

    ##
    # Pongフレームを送信するメソッド。
    #
    # @private
    # @param {string} msg メッセージ
    ##
    sendPongFrame = (msg) ->
      sendFrame {
        FIN: true
        opcode: DataFrame.PONG
        payloadData: msg
      }

    ##
    # 定期的にPingフレームを送信するタイマークラス
    #
    # @private
    # @class
    ##
    class PingTimer
      timerId = null
      msec = 0

      constructor: ->
        if serverConfig['pingInterval'] is 0 then return false
        msec = serverConfig['pingInterval'] * 1000
        timerId = setInterval sendPingFrame, msec

      ##
      # Pingフレームを送信するメソッド。
      #
      # @private
      ##
      sendPingFrame = ->
        if self.readyState isnt WebSocketClient.OPEN
          clearInterval timerId
        else
          sendFrame {
            FIN: true
            opcode: DataFrame.PING
            payloadData: serverConfig['pingMessage']
          }
          console.log 'sended ping'

      ##
      # 送信タイマーをリセットするメソッド。
      #
      # @memberOf WebSocketClient-PingTimer
      ##
      PingTimer::reset = ->
        clearInterval timerId
        timerId = setInterval sendPingFrame, msec

    ##
    # クライアントからのハンドシェイクデータが適切か調べるメソッド。
    #
    # @private
    # @param {string} data クライアントからのハンドシェイクデータ
    # @returns {object|boolean} 適切なら応答に必要なオブジェクトを、不適切ならfalseを返す
    ##
    checkHandshakeData = (data) ->
      obj =
        key: null
      lines = data.split '\r\n'
      if lines[0] isnt "GET #{serverConfig['resource']} HTTP/1.1" then return false
      headerFields = {}
      for i in [1..lines.length]
        if !lines[i]? then continue
        [k, v] = lines[i].split ': '
        headerFields[k] = v
      # Upgradeヘッダの確認
      if headerFields['Upgrade'] isnt 'websocket' then return false
      # Connectionヘッダの確認
      if headerFields['Connection'].indexOf('Upgrade') is -1 then return false
      # Sec-WebSocket-Keyヘッダの確認
      if atob(headerFields['Sec-WebSocket-Key']).length isnt 16 then return false
      obj['key'] = headerFields['Sec-WebSocket-Key']
      # Sec-WebSocket-Originヘッダの確認
      if headerFields['Sec-WebSocket-Origin'] isnt serverConfig['origin']
        return false
      # Sec-WebSocket-Versionヘッダの確認
      if headerFields['Sec-WebSocket-Version'] isnt '8' then return false
      # TODO: Sec-WebSocket-Protocolヘッダの確認
      # TODO: Sec-WebSocket-Extensionsヘッダの確認

      return obj

    ##
    # クライアントに送信するハンドシェイクデータを作成するメソッド。
    #
    # @private
    # @param {object} obj クライアントのハンドシェイクデータから得た値
    # @returns {string} サーバのハンドシェイクデータ
    ##
    createHandshakeData = (obj) ->
      converter = Cc['@mozilla.org/intl/scriptableunicodeconverter']
                   .createInstance Ci.nsIScriptableUnicodeConverter
      converter.charset = 'UTF-8'
      tmp = "#{obj['key']}258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
      data = converter.convertToByteArray tmp, {}
      ch = Cc['@mozilla.org/security/hash;1'].createInstance Ci.nsICryptoHash
      ch.init Ci.nsICryptoHash.SHA1
      ch.update data, data.length
      accept = ch.finish true
      sendData  = 'HTTP/1.1 101 Switching Protocols\r\n'
      sendData += 'Upgrade: websocket\r\n'
      sendData += 'Connection: Upgrade\r\n'
      sendData += "Sec-WebSocket-Accept: #{accept}\r\n"
      sendData += '\r\n'

      return sendData

    ##
    # クライアントとの接続を閉じようとするメソッド。
    #
    # @private
    ##
    doClose = ->
      if !socket.isAlive() then return false

      switch self.readyState
        when WebSocketClient.OPEN  # Closeフレームを送信する必要がある場合
          self.readyState = WebSocketClient.CLOSING
          # TODO: 仕様に沿ったステータスコードと切断理由の値の実装をする
          sendCloseFrame 1000, ''
          # 一定時間経過してもCloseフレームを受信出来なければソケットを閉じる
          setTimeout ->
            if self.readyState isnt WebSocketClient.CLOSED
              console.error 'close connection timeout'
              socket.close 42
          , 100

        when WebSocketClient.CLOSING
          socket.close 42
    
    ##
    # TCP接続後に入力ストリームからデータを受信し続けるメソッド。
    #
    # @private
    ##
    readData = ->
      frame = null
      timer = null

      while self.readyState isnt WebSocketClient.CLOSED
        count = yield
        tmpData = binaryInputStream.readBytes count

        switch self.readyState
          when WebSocketClient.CONNECTING
            result = checkHandshakeData tmpData
            if result
              handshakeData = createHandshakeData result
              outputStream.write handshakeData, handshakeData.length
              self.readyState = WebSocketClient.OPEN
              if serverConfig['pingInterval'] then timer = new PingTimer
              onopen self  # WebSocketServerで定義されたメソッドを実行
            else
              console.error 'handshake faild'
              socket.close 42

          when WebSocketClient.OPEN, WebSocketClient.CLOSING
            if frame
              frame.payloadData += tmpData
            else
              frame = new DataFrame tmpData
            if frame.payloadLen > frame.payloadData.length then continue

            body = frame.getBody()
            switch frame.opcode
              when DataFrame.CONNECTING
                # TODO: 断片化されたフレームを受信したときの処理の実装
                break

              when DataFrame.CLOSE
                console.log "recieved Close: #{body}"
                doClose()

              when DataFrame.PING
                console.log "recieved Ping: #{body}"
                sendPongFrame body

              when DataFrame.PONG
                console.log "recieved Pong: #{body}"

              when DataFrame.TEXT, DataFrame.BINARY
                console.log "recieved: #{body}"
                console.log "body size: #{body.length}"
                if typeof self.onmessage is 'function' then self.onmessage body
            if timer then timer.reset()
            frame = null
            
      return

    ##
    # asyncRead()メソッドに渡すコールバック関数群。
    #
    # @private
    ##
    listener =
      generator: readData()

      ##
      # クライアントとのストリームが開いたときに呼び出されるメソッド。
      #
      # @private
      ##
      onStartRequest: ->
        console.log 'onStartRequest'
        @generator.next()
      
      ##
      # クライアントとのストリームが閉じられたときに呼び出されるメソッド。
      #
      # @private
      # @parame {nsIRequest} request
      # @parame {nsISupports} context
      # @parame {nsresult} statusCode
      onStopRequest: (request, context, statusCode) ->
        console.log "onStopRequest: #{context}, #{statusCode}"
        if socket.isAlive()  # ソケットは生きているが入力ストリームが閉じられた場合の処理
          console.error 'input stream down'
          doClose()
        self.readyState = WebSocketClient.CLOSED
        onclose self  # WebSocketServerで定義されたメソッドの実行

      ##
      # 読み込み可能なデータを受信したときに呼び出されるメソッド。
      #
      # @parame {nsIRequest} request
      # @parame {nsISupports} context
      # @parame {nsIInputStream} inputStream
      # @parame {unsigned} offset
      # @parame {unsigned} count 読み込み可能なデータのバイト数
      ##
      onDataAvailable: (request, context, inputStream, offset, count) ->
        @generator.send count

    
    try
      pump.init inputStream, -1, -1, 0, 0, true
      pump.asyncRead listener, null
    catch e
      console.error e

##
# クライアントからメッセージを受信したときに呼び出されるメソッド。ユーザによって上書きされる。
#
# @param {string} msg 受信したメッセージ
##
WebSocketClient::onmessage = (msg) ->

##
# クライアントと接続中を表すキー
#
# @constant
##
WebSocketClient.CONNECTING = 0

##
# クライアントと接続済みを表すキー
#
# @constant
##
WebSocketClient.OPEN = 1

##
# クライアントとの接続を閉じようとしている状態を表すキー
#
# @constant
##
WebSocketClient.CLOSING = 2

##
# クライアントとの接続が閉じられたことを表すキー
#
# @constant
##
WebSocketClient.CLOSED = 3

# Webアプリ側からクラス変数が参照できないのでprototypeを使う。
# memo: new WebSocketServer()が出来ないことと関係がある？
WebSocketClient::CONNECTING = 0
WebSocketClient::OPEN = 1
WebSocketClient::CLOSING = 2
WebSocketClient::CLOSED = 3
