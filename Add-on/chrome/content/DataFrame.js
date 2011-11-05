var DataFrame;
DataFrame = (function() {
  function DataFrame(data) {
    var code, extendedPayloadLenPos, i, maskingKeyPos, payloadDataPos, reson, _ref;
    if (arguments.length === 0) {
      return false;
    }
    this.converter = Cc['@mozilla.org/intl/scriptableunicodeconverter'].createInstance(Ci.nsIScriptableUnicodeConverter);
    this.converter.charset = 'UTF-8';
    this.FIN = false;
    this.RSV1 = false;
    this.RSV2 = false;
    this.RSV3 = false;
    this.opcode = 0;
    this.MASK = false;
    this.maskingKey = [];
    this.payloadLen = 0;
    this.payloadData = '';
    switch (typeof arguments[0]) {
      case 'string':
        this.FIN = data.charCodeAt(0) & 0x80 ? true : false;
        this.RSV1 = data.charCodeAt(0) & 0x40 ? true : false;
        this.RSV2 = data.charCodeAt(0) & 0x20 ? true : false;
        this.RSV3 = data.charCodeAt(0) & 0x10 ? true : false;
        this.opcode = data.charCodeAt(0) & 0x0f;
        this.MASK = data.charCodeAt(1) & 0x80 ? true : false;
        this.payloadLen = data.charCodeAt(1) & 0x7f;
        maskingKeyPos = 2;
        if (this.payloadLen > 125) {
          extendedPayloadLenPos = maskingKeyPos;
          switch (this.payloadLen) {
            case 126:
              maskingKeyPos += 2;
              break;
            case 127:
              maskingKeyPos += 8;
          }
          this.payloadLen = this.b2i(data.substring(extendedPayloadLenPos, maskingKeyPos));
        }
        payloadDataPos = maskingKeyPos;
        if (this.MASK) {
          for (i = 0; i <= 4; i++) {
            this.maskingKey.push(data.charCodeAt(maskingKeyPos + i));
          }
          payloadDataPos += 4;
        }
        this.payloadData = data.substring(payloadDataPos, payloadDataPos + this.payloadLen);
        break;
      case 'object':
        this.FIN = data['FIN'] || true;
        this.RSV1 = data['RSV1'] || false;
        this.RSV2 = data['RSV2'] || false;
        this.RSV3 = data['RSV3'] || false;
        this.opcode = data['opcode'];
        this.MASK = false;
        this.maskingKey = [];
        switch (this.opcode) {
          case DataFrame.TEXT:
          case DataFrame.PING:
          case DataFrame.PONG:
            this.payloadData = this.converter.ConvertFromUnicode(data['payloadData']);
            break;
          case DataFrame.BINARY:
            this.payloadData = data['payloadData'];
            break;
          case DataFrame.CLOSE:
            _ref = data['payloadData'], code = _ref[0], reson = _ref[1];
            this.payloadData = this.i2b(code) + this.converter.ConvertFromUnicode(reson);
        }
        this.payloadLen = this.payloadData.length;
    }
  }
  return DataFrame;
})();
DataFrame.prototype.b2i = function(bytes) {
  var b, i, num, _len;
  num = 0;
  for (i = 0, _len = bytes.length; i < _len; i++) {
    b = bytes[i];
    num <<= 8;
    num |= bytes.charCodeAt(i);
  }
  return num;
};
DataFrame.prototype.i2b = function(arg) {
  var i, list, num, s, _i, _len, _ref, _step;
  if (arguments.length === 0) {
    return false;
  }
  list = [];
  for (_i = 0, _len = arguments.length; _i < _len; _i++) {
    num = arguments[_i];
    s = num.toString(16);
    if (s.length % 2 !== 0) {
      s = '0' + s;
    }
    if (s.length > 2) {
      for (i = 0, _ref = s.length - 2, _step = 2; 0 <= _ref ? i <= _ref : i >= _ref; i += _step) {
        list.push('0x' + s.substring(i, i + 2));
      }
    } else {
      list.push('0x' + s);
    }
  }
  return String.fromCharCode.apply(null, list);
};
DataFrame.prototype.getBody = function() {
  var body, code, reson;
  body = '';
  if (this.MASK) {
    for (var i=0, len=this.payloadLen; i<len; ++i) {
      body += String.fromCharCode(this.payloadData.charCodeAt(i) ^ this.maskingKey[i%4])
    };
  } else {
    body = this.payloadData;
  }
  switch (this.opcode) {
    case DataFrame.BINARY:
      break;
    case DataFrame.CLOSE:
      code = this.b2i(body.substring(0, 2));
      reson = this.converter.ConvertToUnicode(body.substring(2));
      body = [code, reson];
      break;
    case DataFrame.CONTINUATION:
    case DataFrame.TEXT:
    case DataFrame.PING:
    case DataFrame.PONG:
      body = this.converter.ConvertToUnicode(body);
  }
  return body;
};
DataFrame.prototype.convert2bytes = function() {
  var byteList, digit, header;
  byteList = [];
  header = '';
  if (this.FIN) {
    header |= 0x8;
  }
  if (this.RSV1) {
    header |= 0x4;
  }
  if (this.RSV2) {
    header |= 0x2;
  }
  if (this.RSV3) {
    header |= 0x1;
  }
  header <<= 4;
  header |= this.opcode;
  byteList.push(header);
  if (this.payloadLen >= 126) {
    if (this.payloadLen < 65536) {
      byteList.push(126);
      if (this.payloadLen < 256) {
        byteList.push(0);
      }
    } else {
      byteList.push(127);
      digit = 8 - Math.ceil(this.payloadLen.toString(2).length / 8);
      while (digit--) {
        byteList.push(0);
      }
    }
  }
  byteList.push(this.payloadLen);
  return this.i2b.apply(null, byteList) + this.payloadData;
};
DataFrame.CONTINUATION = 0x0;
DataFrame.TEXT = 0x1;
DataFrame.BINARY = 0x2;
DataFrame.CLOSE = 0x8;
DataFrame.PING = 0x9;
DataFrame.PONG = 0xa;