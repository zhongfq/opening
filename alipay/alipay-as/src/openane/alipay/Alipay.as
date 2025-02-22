package openane.alipay {

import flash.desktop.NativeApplication;
import flash.events.EventDispatcher;
import flash.events.InvokeEvent;
import flash.events.StatusEvent;
import flash.external.ExtensionContext;
import flash.system.Capabilities;
import flash.utils.getQualifiedClassName;

[Event(name="purchaseSuccess", type="openane.alipay.AlipayEvent")]
[Event(name="purchaseCancel", type="openane.alipay.AlipayEvent")]
[Event(name="purchaseFail", type="openane.alipay.AlipayEvent")]
[Event(name="purchaseSignedInfoComplete", type="openane.alipay.AlipayEvent")]
public class Alipay extends EventDispatcher {
    private static var _alipay:Alipay;

    public static function get alipay():Alipay {
        return _alipay ||= new Alipay();
    }

    private var _context:ExtensionContext;
    private var _urlScheme:String;

    public function Alipay() {
        if (_alipay) {
            throw new Error(format("use %s.alipay", getQualifiedClassName(Alipay)));
        }

        if (Capabilities.os.search(/Linux|iPhone/) >= 0) {
            _context = ExtensionContext.createExtensionContext("openane.Alipay", "");
            _context.addEventListener(StatusEvent.STATUS, statusHandler);
            NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, invokeHandler);
        } else {
            print("unsupported platform '%s'", Capabilities.os);
        }
    }

    private function print(...args):void {
        trace("[Alipay] " + format.apply(null, args));
    }

    private function invokeHandler(event:InvokeEvent):void {
        var url:String = event.arguments.length > 0 ? event.arguments[0] : null;
        if (url && _urlScheme && url.indexOf(_urlScheme) >= 0) {
            _context.call("handleOpenURL", event.arguments[0]);
        }
    }

    private function statusHandler(event:StatusEvent):void {
        switch (event.code) {
            case "print":
                print("%s", event.level);
                break;
            case "pay":
            case "payWithSignedInfo":
                var info:Object = JSON.parse(event.level);
                var type:String;
                var verifyStatus:Boolean = info.verifyStatus == "true";

                if ((info.resultStatus == "9000" || info.resultStatus == "8000")
                        && (verifyStatus || event.code == "payWithSignedInfo")) {
                    type = event.code == "payWithSignedInfo" ?
                            AlipayEvent.PURCHASE_SIGNED_INFO_COMPLETE :
                            AlipayEvent.PURCHASE_SUCCESS;
                } else if (info.resultStatus == "6001") {
                    type = AlipayEvent.PURCHASE_CANCEL;
                } else {
                    type = AlipayEvent.PURCHASE_FAIL;
                }

                dispatchEvent(new AlipayEvent(type, verifyStatus, info.resultStatus, info.result));
                break;
        }
    }

    private function trim(content:String, prefix:String, suffix:String):String {
        return content.substring(content.indexOf(prefix) + prefix.length,
                content.lastIndexOf(suffix));
    }

    public function init(appKey:String, publicKey:String = null, privateKey:String = null):void {
        if (_context) {
            if (appKey) {
                _urlScheme = format("al%s://", appKey);
                _context.call("init", appKey, publicKey, privateKey);
            } else {
                print("arguments error: appKey=%s", appKey);
            }
        }
    }

    public function pay(order:AlipayOrder):void {
        if (_context) {
            if (order) {
                _context.call("pay", order.toString());
            } else {
                print("arguments error: info=%s", order);
            }
        }
    }

    public function payWithSignedInfo(signedInfo:String):void {
        if (_context) {
            if (signedInfo) {
                _context.call("payWithSignedInfo", signedInfo);
            } else {
                print("arguments error: signedInfo=%s", signedInfo);
            }
        }
    }
}
}

internal function format(fmt:String, ...args):String {
    var buffer:Vector.<String> = new Vector.<String>();

    var len:int = fmt.length;
    var start:int = 0;
    while (true) {
        var idx:int = fmt.indexOf("%", start);
        if (idx >= 0) {
            buffer.push(fmt.substring(start, idx));
            if (idx < len - 1) {
                var f:String = fmt.charAt(idx + 1);
                if (f == '%') {
                    buffer.push('%');
                } else if (f == 's') {
                    if (args.length > 0) {
                        buffer.push(String(args.shift()));
                    } else {
                        trace("more '%' conversions than data arguments: " + fmt);
                        break;
                    }
                } else {
                    trace("incomplete format specifier: " + fmt);
                }

                start = idx + 2;
            } else {
                trace("incomplete format specifier: " + fmt);
                break;
            }
        } else {
            buffer.push(fmt.substring(start, len));
            break;
        }
    }

    if (args.length > 0) {
        trace(args.length + " data arguments not used: " + fmt);
    }

    return buffer.join("");
}