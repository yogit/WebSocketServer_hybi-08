##
# DataFrameクラス
#
# @param {string|object} data フレームを構成するのに必要な値
##
class DataFrame
  constructor: (data) ->
    if arguments.length is 0 then return false

    @converter = Cc['@mozilla.org/intl/scriptableunicodeconverter']
                .createInstance Ci.nsIScriptableUnicodeConverter
    @converter.charset = 'UTF-8'

    ##
    # FINビット
    #
    # @type boolean
    ##
    @FIN = false

    ##
    # RSV1ビット
    #
    # @type boolean
    ##
    @RSV1 = false

    ##
    # RSV2ビット
    #
    # @type boolean
    ##
    @RSV2 = false

    ##
    # RSV3ビット
    #
    # @type boolean
    ##
    @RSV3 = false

    ##
    # opcodeの値
    #
    # @type number
    ##
    @opcode = 0

    ##
    # MASKビット
    #
    # @type boolean
    ##
    @MASK = false

    ##
    # マスクのキー
    #
    # @type Array<number>
    ##
    @maskingKey = []

    ##
    # ペイロードデータの長さ
    #
    # @type number
    ##
    @payloadLen = 0

    ##
    # ペイロードデータ
    #
    # @type string
    ##
    @payloadData = ''

    switch typeof arguments[0]
      when 'string'  # 受信したバイト列を基にDataFrameのインスタンスを作成する
        @FIN  = if data.charCodeAt(0) & 0x80 then true else false
        @RSV1 = if data.charCodeAt(0) & 0x40 then true else false
        @RSV2 = if data.charCodeAt(0) & 0x20 then true else false
        @RSV3 = if data.charCodeAt(0) & 0x10 then true else false
        @opcode = data.charCodeAt(0) & 0x0f
        @MASK = if data.charCodeAt(1) & 0x80 then true else false
        @payloadLen = data.charCodeAt(1) & 0x7f
        maskingKeyPos = 2
        if @payloadLen > 125
          extendedPayloadLenPos = maskingKeyPos
          switch @payloadLen
            when 126 then maskingKeyPos += 2
            when 127 then maskingKeyPos += 8
          @payloadLen = @b2i data.substring(extendedPayloadLenPos, maskingKeyPos)
        payloadDataPos = maskingKeyPos
        if @MASK
          for i in [0..4]
            @maskingKey.push data.charCodeAt(maskingKeyPos + i)
          payloadDataPos += 4
        @payloadData = data.substring payloadDataPos, payloadDataPos + @payloadLen

      when 'object'  # 指定された条件でDataFrameのインスタンスを作成する
        @FIN  = data['FIN']  or true
        @RSV1 = data['RSV1'] or false
        @RSV2 = data['RSV2'] or false
        @RSV3 = data['RSV3'] or false
        @opcode = data['opcode']
        @MASK = false  # サーバから送信するフレームはマスクしなくても良い
        @maskingKey = []
        switch @opcode
          when DataFrame.TEXT, DataFrame.PING, DataFrame.PONG
            @payloadData = @converter.ConvertFromUnicode data['payloadData']

          when DataFrame.BINARY
            @payloadData = data['payloadData']

          when DataFrame.CLOSE
            [code, reson] = data['payloadData']
            @payloadData = @i2b(code) + @converter.ConvertFromUnicode(reson)
        @payloadLen = @payloadData.length

##
# バイト列を整数値に変換するメソッド。
#
# @param {string} bytes バイト列
# @returns {number} 整数値
##
DataFrame::b2i = (bytes) ->
  num = 0
  for b, i in bytes
    num <<= 8
    num |= bytes.charCodeAt i

  return num

##
# 整数値をバイト列に変換するメソッド。
#
# @param {number} arg 一つ以上の整数値
# @returns {string} バイト列
##
DataFrame::i2b = (arg) ->
  if arguments.length is 0 then return false

  list = []
  for num in arguments
    s = num.toString 16
    if s.length % 2 isnt 0 then s = '0' + s
    if s.length > 2
      for i in [0..s.length-2] by 2
        list.push '0x' + s.substring(i, i+2)
    else
      list.push '0x' + s

  return String.fromCharCode.apply null, list

##
# フレームに含まれているアプリケーションデータを取り出すメソッド。
#
# @returns {string|Array} アプリケーションデータ。
#                         Closeフレームの場合はステータスコードと接続閉鎖の理由。
##
DataFrame::getBody = ->
  body = ''
  if @MASK
   `for (var i=0, len=this.payloadLen; i<len; ++i) {
      body += String.fromCharCode(this.payloadData.charCodeAt(i) ^ this.maskingKey[i%4])
    }`
  else
    body = @payloadData

  switch @opcode
    when DataFrame.BINARY
      # 多分、何もしなくて良いと思うが...
      break

    when DataFrame.CLOSE
      code  = @b2i body.substring(0, 2)
      reson = @converter.ConvertToUnicode body.substring(2)
      body  = [code, reson]

    when DataFrame.CONTINUATION, DataFrame.TEXT, DataFrame.PING, DataFrame.PONG
      body = @converter.ConvertToUnicode body

  return body

##
# フレームをバイト列に変換するメソッド。
#
# @returns {string} バイト列
##
DataFrame::convert2bytes = ->
  byteList = []
  header = ''

  if @FIN  then header |= 0x8
  if @RSV1 then header |= 0x4
  if @RSV2 then header |= 0x2
  if @RSV3 then header |= 0x1
  header <<= 4
  header |= @opcode
  byteList.push header

  if @payloadLen >= 126
    if @payloadLen < 65536  # 2^16 == 65536
      byteList.push 126
      if @payloadLen < 256 then byteList.push 0
    else
      byteList.push 127
      digit = 8 - Math.ceil(@payloadLen.toString(2).length/8)
      while digit--
        byteList.push 0
  byteList.push @payloadLen

  return @i2b.apply(null, byteList) + @payloadData

##
# ペイロードデータが継続フレームであることを表したキー
#
# @@constant
##
DataFrame.CONTINUATION = 0x0

##
# ペイロードデータがテキストフレームであることを表したキー
#
# @constant
##
DataFrame.TEXT = 0x1

##
# ペイロードデータがバイナリフレームであることを表したキー
#
# @constant
##
DataFrame.BINARY = 0x2

##
# ペイロードデータがクローズフレームであることを表したキー
#
# @constant
##
DataFrame.CLOSE = 0x8

##
# ペイロードデータがPingフレームであることを表したキー
#
# @constant
##
DataFrame.PING = 0x9

##
# ペイロードデータがPongフレームであることを表したキー
#
# @constant
##
DataFrame.PONG = 0xa
