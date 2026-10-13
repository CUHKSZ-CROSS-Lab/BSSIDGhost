/*
 * BSSIDGhost - 真机调用栈抓取脚本（B 线 / BG-011）
 *
 * 目的：在目标 App 进程内一次性记录「它是通过哪些接口读到 Wi-Fi 信息（尤其是 BSSID）的」，
 *       为 docs/tech-chain.md 第 2 节的候选 Hook 点排序、以及第 5 节框架选型提供真凭实据。
 *
 * 用法（主机需已安装 frida；本机当前未安装，见 docs/device-setup.md）：
 *   frida -U -f com.ss.iphone.ugc.Lark -l tests/frida/capture-wifi-api.js \
 *         -o tests/evidence/$(date +%Y%m%d-%H%M%S)-capture.jsonl
 *
 *   已在运行的进程改用 -n <进程名>；只做只读观察，不修改任何返回值。
 *
 * 覆盖范围：
 *   1) ObjC 通道：CWFInterface / CWInterface / CWNetwork / CWWiFiClient / NEHotspotNetwork
 *      —— 记录选择器、返回值形态（NSString / NSData / 其他）、调用栈、以及同对象的 SSID。
 *   2) C 函数通道：CNCopyCurrentNetworkInfo（SystemConfiguration）。
 *   3) XPC 边界：com.apple.nehelper 的请求构造与应答读取
 *      —— 记录 interface-name / delegate-class-id / sdk-version，以及 result-data 里的 SSID/BSSID。
 *      这是判断「是否所有通道都汇入 nehelper」的关键证据（见 tech-chain.md §2.1）。
 *   4) getifaddrs：记录 en0 的接口 MAC，用于证明「接口 MAC ≠ AP 的 BSSID」。
 *
 * 输出：每行一个 JSON 对象（JSONL），字段：
 *   t      时间戳(ms)  src  来源分类  kind 事件类型
 *   ...    事件相关字段  bt   调用栈（最多 maxBacktrace 帧）
 *
 * ⚠️ 本脚本只读取与记录，不做任何替换；真机结论一律视为「待复验」，需写入 tests/evidence/。
 * ⚠️ 仅用于自有 / 已授权的测试设备与 App（见 README「用途与授权要求」）。
 */

'use strict';

var CONFIG = {
    // 记录调用栈的最大帧数（0 = 不记录，输出更小）
    maxBacktrace: 12,
    // 是否记录 ObjC 通道
    hookObjc: true,
    // 是否记录 CNCopyCurrentNetworkInfo
    hookCopyCurrentNetworkInfo: true,
    // 是否记录 nehelper XPC 请求/应答
    hookXpc: true,
    // 是否 hook xpc_dictionary_set_string/uint64（请求构造侧）。
    // 这两个函数在进程内调用极其频繁，会带来可感知开销；只关心应答侧时可关掉。
    hookXpcWrites: true,
    // 是否 hook xpc_dictionary_get_string（能确认谁在直接读 BSSID 键，但更啰嗦）
    hookXpcStringReads: true,
    // 是否记录 en0 接口 MAC（对照用）
    captureInterfaceMac: true,
    // 是否在日志里附带对象指针（便于跨事件关联同一个对象）
    logObjectPointer: true
};

// ---------------------------------------------------------------------------
// 基础设施
// ---------------------------------------------------------------------------

var START_MS = Date.now();

function logEvent(event) {
    event.t = Date.now() - START_MS;
    try {
        console.log(JSON.stringify(event));
    } catch (e) {
        console.log('{"kind":"log-error","message":"' + String(e) + '"}');
    }
}

function findGlobalExport(name) {
    var tries = [
        function () { return Module.getGlobalExportByName(name); },
        function () { return Module.findGlobalExportByName(name); },
        function () { return Module.getExportByName(null, name); },
        function () { return Module.findExportByName(null, name); }
    ];
    for (var i = 0; i < tries.length; i++) {
        try {
            var p = tries[i]();
            if (p && !p.isNull()) return p;
        } catch (e) { /* 该 API 在此 Frida 版本不存在 */ }
    }
    return null;
}

function findModuleExport(moduleName, name) {
    try {
        return Module.getExportByName(moduleName, name);
    } catch (e) { /* 继续尝试其它 API */ }
    try {
        return Module.findExportByName(moduleName, name);
    } catch (e) { /* 继续尝试其它 API */ }
    try {
        var mod = Process.getModuleByName(moduleName);
        if (mod) return mod.findExportByName(name);
    } catch (e) { /* 继续尝试其它 API */ }
    return null;
}

function readCString(ptr) {
    if (!ptr || ptr.isNull()) return null;
    try {
        return ptr.readUtf8String();
    } catch (e) {
        return null;
    }
}

function backtrace(context) {
    if (!CONFIG.maxBacktrace) return [];
    try {
        return Thread.backtrace(context, Backtracer.ACCURATE)
            .slice(0, CONFIG.maxBacktrace)
            .map(function (addr) {
                try {
                    return DebugSymbol.fromAddress(addr).toString();
                } catch (e) {
                    return addr.toString();
                }
            });
    } catch (e) {
        return [];
    }
}

function describeValue(value) {
    if (value === null || value === undefined) return null;
    try {
        if (value instanceof ObjC.Object) {
            var cls = value.$className;
            var out = { class: cls };
            if (cls === '__NSCFString' || cls === 'NSCFString' || cls === 'NSString' ||
                cls === '__NSCFConstantString' || cls === 'NSMutableString' ||
                cls === 'NSTaggedPointerString') {
                out.string = value.toString();
            } else if (cls === '__NSData' || cls === 'NSData' || cls === '__NSCFData' ||
                       cls === 'NSMutableData') {
                out.length = value.length().valueOf();
                try {
                    out.hex = hexDump(value.bytes(), Math.min(out.length, 32));
                } catch (e) { /* 取字节失败就算了 */ }
            } else {
                try {
                    out.description = value.description().toString();
                } catch (e) { /* 部分对象 description 会抛 */ }
            }
            return out;
        }
        return { primitive: String(value) };
    } catch (e) {
        return { error: String(e) };
    }
}

function hexDump(ptr, length) {
    if (!ptr || ptr.isNull() || length <= 0) return null;
    var bytes = new Uint8Array(ptr.readByteArray(length));
    var parts = [];
    for (var i = 0; i < bytes.length; i++) {
        parts.push(('0' + bytes[i].toString(16)).slice(-2));
    }
    return parts.join('');
}

function ptrString(ptr) {
    if (!CONFIG.logObjectPointer) return undefined;
    try {
        return ptr.toString();
    } catch (e) {
        return undefined;
    }
}

// ---------------------------------------------------------------------------
// 1) ObjC 通道
// ---------------------------------------------------------------------------

// 表驱动：类名 -> 需要观察的选择器（'+' 开头为类方法）。
var OBJC_TARGETS = [
    { cls: 'CWFInterface', sels: ['- bssid', '- interfaceState', '- ssid'] },
    { cls: 'CWInterface', sels: ['- bssid', '- ssid'] },
    { cls: 'CWNetwork', sels: ['- bssid', '- ssid'] },
    { cls: 'CWWiFiClient', sels: ['- interface', '- interfaceNames'] },
    { cls: 'NEHotspotNetwork', sels: ['- BSSID', '- SSID', '+ fetchCurrentWithCompletionHandler:'] },
    { cls: 'NEHotspotHelper', sels: ['+ supportedNetworkInterfaces'] },
    // 下面这个类在 nehelper 进程里（/usr/libexec/nehelper），不在 App 进程。
    // 要观察 entitlement 闸，需要对 nehelper 进程另开一次 attach，见 docs/tech-chain.md §2.2。
    { cls: 'NEHelperWiFiInfoManager', sels: ['- checkIfEntitled:', '- wifiInfoForInterface:'] }
];

var gObjcDepth = 0;

function attachObjcMethod(className, selector) {
    var cls = ObjC.classes[className];
    if (!cls) return false;

    var method = cls[selector];
    if (!method || !method.implementation) return false;

    Interceptor.attach(method.implementation, {
        onEnter: function (args) {
            this.depth = gObjcDepth;
            gObjcDepth++;
            // ObjC 实例方法的 receiver 就是第一个参数（onLeave 里拿不到 args）。
            this.receiver = args[0];
        },
        onLeave: function (retval) {
            gObjcDepth--;
            // 嵌套调用（例如被测实现内部又调了别的被 hook 方法）不再单独记录。
            if (this.depth > 0) return;

            var event = {
                src: 'objc',
                kind: 'method',
                cls: className,
                sel: selector,
                ret: describeValue(retval)
            };
            if (this.receiver && !this.receiver.isNull()) {
                try {
                    event.selfClass = new ObjC.Object(this.receiver).$className;
                    event.selfPtr = ptrString(this.receiver);
                } catch (e) { /* 忽略 */ }
            }
            event.bt = backtrace(this.context);
            logEvent(event);
        }
    });
    return true;
}

function installObjcHooks() {
    if (!CONFIG.hookObjc) return;
    if (typeof ObjC === 'undefined' || !ObjC.available) {
        logEvent({ src: 'objc', kind: 'unavailable', message: 'ObjC runtime 不可用，跳过 ObjC 通道' });
        return;
    }

    OBJC_TARGETS.forEach(function (target) {
        if (!ObjC.classes[target.cls]) {
            logEvent({ src: 'objc', kind: 'class-missing', cls: target.cls });
            return;
        }
        target.sels.forEach(function (sel) {
            var ok = false;
            try {
                ok = attachObjcMethod(target.cls, sel);
            } catch (e) {
                logEvent({ src: 'objc', kind: 'attach-error', cls: target.cls, sel: sel, message: String(e) });
                return;
            }
            logEvent({
                src: 'objc',
                kind: ok ? 'hooked' : 'selector-missing',
                cls: target.cls,
                sel: sel
            });
        });
    });
}

// ---------------------------------------------------------------------------
// 2) CNCopyCurrentNetworkInfo（C 函数）
// ---------------------------------------------------------------------------

function installCNCopyHook() {
    if (!CONFIG.hookCopyCurrentNetworkInfo) return;

    var addr = findModuleExport('SystemConfiguration', 'CNCopyCurrentNetworkInfo');
    if (!addr) {
        addr = findGlobalExport('CNCopyCurrentNetworkInfo');
    }
    if (!addr) {
        logEvent({ src: 'cfunc', kind: 'unavailable', symbol: 'CNCopyCurrentNetworkInfo' });
        return;
    }

    Interceptor.attach(addr, {
        onEnter: function (args) {
            this.ifaceName = readCString(args[0]);
        },
        onLeave: function (retval) {
            var event = {
                src: 'cfunc',
                kind: 'CNCopyCurrentNetworkInfo',
                iface: this.ifaceName,
                ret: null
            };
            try {
                if (!retval.isNull()) {
                    var dict = new ObjC.Object(retval);
                    var keys = dict.allKeys();
                    var count = keys.count().valueOf();
                    var values = {};
                    for (var i = 0; i < count; i++) {
                        var key = keys.objectAtIndex_(i).toString();
                        values[key] = dict.objectForKey_(keys.objectAtIndex_(i)).toString();
                    }
                    event.ret = { class: dict.$className, values: values };
                }
            } catch (e) {
                event.retError = String(e);
            }
            event.bt = backtrace(this.context);
            logEvent(event);
        }
    });
    logEvent({ src: 'cfunc', kind: 'hooked', symbol: 'CNCopyCurrentNetworkInfo' });
}

// ---------------------------------------------------------------------------
// 3) nehelper XPC 边界
// ---------------------------------------------------------------------------

var xpc = null;

function initXpcReaders() {
    function fn(symbol, retType, argTypes) {
        var addr = findGlobalExport(symbol);
        if (!addr) return null;
        try {
            return new NativeFunction(addr, retType, argTypes);
        } catch (e) {
            return null;
        }
    }

    xpc = {
        dictionaryGetUint64: fn('xpc_dictionary_get_uint64', 'uint64', ['pointer', 'pointer']),
        dictionaryGetString: fn('xpc_dictionary_get_string', 'pointer', ['pointer', 'pointer']),
        dictionaryGetValue: fn('xpc_dictionary_get_value', 'pointer', ['pointer', 'pointer']),
        dataGetLength: fn('xpc_data_get_length', 'size_t', ['pointer']),
        dataGetBytesPtr: fn('xpc_data_get_bytes_ptr', 'pointer', ['pointer']),
        type: fn('xpc_get_type', 'pointer', ['pointer']),
        copyDescription: fn('xpc_copy_description', 'pointer', ['pointer'])
    };
}

var gXpcGuard = false; // 防止读取器自身的调用再次进入 hook

function keyString(keyPtr) {
    return readCString(keyPtr);
}

function allocKey(str) {
    return Memory.allocUtf8String(str);
}

var KEYS = {};

function initKeys() {
    ['interface-name', 'delegate-class-id', 'sdk-version', 'result-data',
     'SSID', 'BSSID', 'SSIDDATA', 'type', 'interface'].forEach(function (k) {
        KEYS[k] = allocKey(k);
    });
}

function xpcDictString(dictPtr, key) {
    if (!xpc || !xpc.dictionaryGetString || !key) return null;
    try {
        return readCString(xpc.dictionaryGetString(dictPtr, key));
    } catch (e) {
        return null;
    }
}

function xpcDictUint(dictPtr, key) {
    if (!xpc || !xpc.dictionaryGetUint64 || !key) return null;
    try {
        var v = xpc.dictionaryGetUint64(dictPtr, key);
        return v.toString();
    } catch (e) {
        return null;
    }
}

function xpcDictDataHex(dictPtr, key) {
    if (!xpc || !xpc.dictionaryGetValue || !xpc.dataGetLength || !xpc.dataGetBytesPtr || !key) return null;
    try {
        var dataPtr = xpc.dictionaryGetValue(dictPtr, key);
        if (!dataPtr || dataPtr.isNull()) return null;
        var len = xpc.dataGetLength(dataPtr).valueOf();
        if (!len) return null;
        return hexDump(xpc.dataGetBytesPtr(dataPtr), Math.min(len, 32));
    } catch (e) {
        return null;
    }
}

/// 描述一个「看起来像 Wi-Fi 应答」的 xpc 字典。读取器本身在 hook 内调用，用 guard 防止递归。
function describeWifiReply(replyPtr) {
    if (!replyPtr || replyPtr.isNull()) return null;
    gXpcGuard = true;
    var result = null;
    try {
        var ssid = xpcDictString(replyPtr, KEYS.SSID);
        var bssid = xpcDictString(replyPtr, KEYS.BSSID);
        var ssiddata = xpcDictDataHex(replyPtr, KEYS.SSIDDATA);
        if (ssid !== null || bssid !== null || ssiddata !== null) {
            result = { ssid: ssid, bssid: bssid, ssiddataHex: ssiddata };
        }
    } catch (e) {
        result = { error: String(e) };
    }
    gXpcGuard = false;
    return result;
}

function installXpcHooks() {
    if (!CONFIG.hookXpc) return;

    initKeys();
    initXpcReaders();

    var attached = [];

    // 3a) 请求侧：App 构造请求字典时就能看到它要查哪个接口。
    //     同时也记录应答字典的构造（在 nehelper 进程里附加时就是这条在起作用）。
    var XPC_WRITE_KEYS = ['interface-name', 'sdk-version', 'delegate-class-id', 'type',
                          'result-data', 'SSID', 'BSSID', 'SSIDDATA'];
    var setString = CONFIG.hookXpcWrites ? findGlobalExport('xpc_dictionary_set_string') : null;
    if (setString) {
        Interceptor.attach(setString, {
            onEnter: function (args) {
                var key = keyString(args[1]);
                if (!key || XPC_WRITE_KEYS.indexOf(key) < 0) {
                    return;
                }
                logEvent({
                    src: 'xpc',
                    kind: 'request-set',
                    key: key,
                    value: readCString(args[2]),
                    bt: backtrace(this.context)
                });
            }
        });
        attached.push('xpc_dictionary_set_string');
    }

    var setUint = CONFIG.hookXpcWrites ? findGlobalExport('xpc_dictionary_set_uint64') : null;
    if (setUint) {
        Interceptor.attach(setUint, {
            onEnter: function (args) {
                var key = keyString(args[1]);
                if (key !== 'delegate-class-id' && key !== 'sdk-version') return;
                var value = null;
                try {
                    value = args[2].toUInt32().toString();
                } catch (e) { /* 忽略 */ }
                logEvent({
                    src: 'xpc',
                    kind: 'request-set',
                    key: key,
                    value: value,
                    bt: backtrace(this.context)
                });
            }
        });
        attached.push('xpc_dictionary_set_uint64');
    }

    // 3b) 应答侧（关键）：谁解析 result-data，谁就是真实的 BSSID 消费者。
    var getValue = findGlobalExport('xpc_dictionary_get_value');
    if (getValue) {
        Interceptor.attach(getValue, {
            onEnter: function (args) {
                if (gXpcGuard) return;
                var key = keyString(args[1]);
                if (key !== 'result-data') return;
                this.isResultData = true;
                this.dictPtr = args[0];
            },
            onLeave: function (retval) {
                if (!this.isResultData || gXpcGuard) return;
                logEvent({
                    src: 'xpc',
                    kind: 'reply-result-data',
                    reply: describeWifiReply(retval),
                    bt: backtrace(this.context)
                });
            }
        });
        attached.push('xpc_dictionary_get_value(result-data)');
    }

    // 3c) 直接按字符串键读 SSID/BSSID 的调用方（有些实现跳过 result-data 中间层）。
    if (CONFIG.hookXpcStringReads) {
        var getString = findGlobalExport('xpc_dictionary_get_string');
        if (getString) {
            Interceptor.attach(getString, {
                onEnter: function (args) {
                    if (gXpcGuard) return;
                    var key = keyString(args[1]);
                    if (key !== 'BSSID' && key !== 'SSID') return;
                    this.wifiKey = key;
                },
                onLeave: function (retval) {
                    if (!this.wifiKey || gXpcGuard) return;
                    logEvent({
                        src: 'xpc',
                        kind: 'reply-key-read',
                        key: this.wifiKey,
                        value: readCString(retval),
                        bt: backtrace(this.context)
                    });
                }
            });
            attached.push('xpc_dictionary_get_string(SSID/BSSID)');
        }
    }

    logEvent({
        src: 'xpc',
        kind: 'hooked',
        symbols: attached,
        note: '若这里没有输出，说明该 App 未走 nehelper XPC；请对照 objc 事件判断真实通道'
    });
}

// ---------------------------------------------------------------------------
// 4) getifaddrs：接口 MAC（对照「接口 MAC ≠ AP BSSID」）
// ---------------------------------------------------------------------------

var AF_LINK = 18;

function installGetifaddrsHook() {
    if (!CONFIG.captureInterfaceMac) return;

    var addr = findGlobalExport('getifaddrs');
    if (!addr) {
        logEvent({ src: 'cfunc', kind: 'unavailable', symbol: 'getifaddrs' });
        return;
    }

    var pointerSize = Process.pointerSize;

    Interceptor.attach(addr, {
        onEnter: function (args) {
            this.headOut = args[0];
        },
        onLeave: function (retval) {
            var rc = 0;
            try {
                rc = retval.toInt32();
            } catch (e) {
                return;
            }
            if (rc !== 0) return;

            var macs = {};
            try {
                var node = this.headOut.readPointer();
                var guard = 0;
                while (!node.isNull() && guard++ < 64) {
                    var next = node.readPointer();
                    var namePtr = node.add(pointerSize).readPointer();
                    var addrPtr = node.add(pointerSize * 2 + 8).readPointer();
                    var name = readCString(namePtr);

                    if (name && addrPtr && !addrPtr.isNull() && macs[name] === undefined) {
                        var family = addrPtr.add(1).readU8();
                        if (family === AF_LINK) {
                            var nlen = addrPtr.add(5).readU8();
                            var alen = addrPtr.add(6).readU8();
                            if (alen === 6) {
                                macs[name] = hexDump(addrPtr.add(8 + nlen), 6);
                            }
                        }
                    }
                    node = next;
                }
            } catch (e) {
                logEvent({ src: 'cfunc', kind: 'getifaddrs-error', message: String(e) });
                return;
            }

            if (macs.en0 || macs.en1) {
                logEvent({
                    src: 'cfunc',
                    kind: 'interface-macs',
                    macs: macs,
                    note: 'en0 是设备接口 MAC，不是 AP 的 BSSID；两者不一致是预期结果'
                });
            }
        }
    });
    logEvent({ src: 'cfunc', kind: 'hooked', symbol: 'getifaddrs(AF_LINK)' });
}

// ---------------------------------------------------------------------------
// 启动
// ---------------------------------------------------------------------------

function main() {
    logEvent({
        src: 'meta',
        kind: 'start',
        pid: Process.id,
        arch: Process.arch,
        platform: Process.platform,
        frida: Frida.version,
        objc: (typeof ObjC !== 'undefined' && ObjC.available) ? true : false,
        config: CONFIG
    });

    installObjcHooks();
    installCNCopyHook();
    installXpcHooks();
    installGetifaddrsHook();

    logEvent({ src: 'meta', kind: 'ready', note: '现在请在被测 App 内触发 Wi-Fi 信息读取' });
}

try {
    main();
} catch (e) {
    logEvent({ src: 'meta', kind: 'fatal', message: String(e), stack: e && e.stack ? String(e.stack) : null });
}
