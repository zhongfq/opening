//
// $id: openaneWeChat.m openane $
//

#import "openaneWeChat.h"

#define ANE_FUNCTION(f) static FREObject (f)(FREContext ctx, void *data, uint32_t argc, FREObject argv[])
#define MAP_FUNCTION(fn, f, data) {(const uint8_t *)(fn), (data), &(f)}
#define FRESTR(s) ((const uint8_t *)(s))

#define FREPrint(s) FREDispatchStatusEventAsync(ctx, FRESTR("print"), FRESTR(s))
#define UNUSED(e) (void)(e)

static NSString *openaneObjectToString(FREObject obj)
{
    const uint8_t *value = nil;
    uint32_t len = 0;
    
    if (FREGetObjectAsUTF8(obj, &len, &value) == FRE_OK)
    {
        return [NSString stringWithUTF8String:(const char *)value];
    }
    else
    {
        return nil;
    }
}

static NSNumber *openaneObjectToNumber(FREObject obj)
{
    double value = 0;
    
    if (FREGetObjectAsDouble(obj, &value) == FRE_OK)
    {
        return [NSNumber numberWithDouble:value];
    }
    else
    {
        NSString *numstr = openaneObjectToString(obj);
        return [NSNumber numberWithDouble:numstr != NULL ? [numstr doubleValue] : 0];
    }
}

static NSString *openaneObjectToJSONString(NSObject *obj)
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@implementation WeChatConnector

- (id)initWithContext:(FREContext)ctx
{
    if ((self = [super init]) != nil)
    {
        _context = ctx;
    }
    
    return self;
}

- (void)onReq:(BaseReq*)req
{
    
}

- (void)onResp:(BaseResp*)resp
{
    @autoreleasepool {
        if ([resp isKindOfClass:[SendAuthResp class]])
        {
            SendAuthResp *authResp = (SendAuthResp *)resp;
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setValue:[NSNumber numberWithInt:authResp.errCode] forKey:@"errCode"];
            [dict setValue:authResp.code forKey:@"code"];
            [dict setValue:authResp.state forKey:@"state"];
            [dict setValue:authResp.lang forKey:@"lang"];
            [dict setValue:authResp.country forKey:@"country"];
            NSString *authInfo = openaneObjectToJSONString(dict);
            FREDispatchStatusEventAsync(self.context, FRESTR("authorize"), FRESTR([authInfo UTF8String]));
        }
        else if ([resp isKindOfClass:[PayResp class]])
        {
            PayResp *payResp = (PayResp *)resp;
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setValue:[NSNumber numberWithInt:payResp.errCode] forKey:@"errCode"];
            [dict setValue:payResp.returnKey forKey:@"returnKey"];
            NSString *payInfo = openaneObjectToJSONString(dict);
            FREDispatchStatusEventAsync(self.context, FRESTR("pay"), FRESTR([payInfo UTF8String]));
        }
    }
}

@end

static WeChatConnector *openaneWeChatContextNativeData(FREContext ctx)
{
    void *ptr = NULL;
    if (FREGetContextNativeData(ctx, &ptr) == FRE_OK)
    {
        return (__bridge WeChatConnector *)ptr;
    }
    else
    {
        FREPrint("native data is null");
        return NULL;
    }
}

ANE_FUNCTION(openaneWeChatFuncInit)
{
    @autoreleasepool {
        WeChatConnector *connector = openaneWeChatContextNativeData(ctx);
        connector.appID = openaneObjectToString(argv[0]);
        connector.appSecret = openaneObjectToString(argv[1]);
        [WXApi registerApp:connector.appID];
        
        NSString *msg = [NSString stringWithFormat:@"init wechat: appid=%@", connector.appID];
        FREPrint([msg UTF8String]);
        
        return NULL;
    }
}

ANE_FUNCTION(openaneWeChatFuncIsInstalled)
{
    @autoreleasepool {
        FREObject installed = NULL;
        FRENewObjectFromBool([WXApi isWXAppInstalled], &installed);
        return installed;
    }
}

ANE_FUNCTION(openaneWeChatFuncAuthorize)
{
    @autoreleasepool {
        WeChatConnector *connector = openaneWeChatContextNativeData(ctx);
        SendAuthReq *req = [[SendAuthReq alloc] init];
        req.scope = openaneObjectToString(argv[0]);
        req.state = openaneObjectToString(argv[1]);
        [WXApi sendAuthReq:req
            viewController:[[[UIApplication sharedApplication] keyWindow] rootViewController]
                  delegate:connector];
        
        FREPrint("send auth request");
        return NULL;
    }
}

ANE_FUNCTION(openaneWeChatFuncPay)
{
    @autoreleasepool {
        PayReq *req = [[PayReq alloc] init];
        req.partnerId = openaneObjectToString(argv[0]);
        req.prepayId = openaneObjectToString(argv[1]);
        req.nonceStr = openaneObjectToString(argv[2]);
        req.timeStamp = [openaneObjectToNumber(argv[3]) unsignedIntValue];
        req.package = openaneObjectToString(argv[4]);
        req.sign = openaneObjectToString(argv[5]);
        [WXApi sendReq:req];
        
        NSDictionary *dict = @{
                               @"partnerId": req.partnerId,
                               @"prepayId": req.prepayId,
                               @"nonceStr": req.nonceStr,
                               @"timeStamp": [NSNumber numberWithUnsignedInt:req.timeStamp],
                               @"package": req.package,
                               @"sign": req.sign,
                               };
        NSString *msg = [NSString stringWithFormat:@"pay: %@", openaneObjectToJSONString(dict)];
        FREPrint([msg UTF8String]);
        return NULL;
    }
}

ANE_FUNCTION(openaneWeChatFuncHandleOpenURL)
{
    @autoreleasepool {
        WeChatConnector *connector = openaneWeChatContextNativeData(ctx);
        
        //open url
        NSURL *url = [NSURL URLWithString:openaneObjectToString(argv[0])];
        [WXApi handleOpenURL:url delegate:connector];
        return NULL;
    }
}

static void openaneWeChatContextInitializer(void *extData, const uint8_t *ctxType, FREContext ctx, uint32_t *numFunctionsToSet, const FRENamedFunction **functionsToSet)
{
    @autoreleasepool {
        static FRENamedFunction funcs[] =
        {
            MAP_FUNCTION("init", openaneWeChatFuncInit, NULL),
            MAP_FUNCTION("isInstalled", openaneWeChatFuncIsInstalled, NULL),
            MAP_FUNCTION("authorize", openaneWeChatFuncAuthorize, NULL),
            MAP_FUNCTION("pay", openaneWeChatFuncPay, NULL),
            MAP_FUNCTION("handleOpenURL", openaneWeChatFuncHandleOpenURL, NULL),
        };
        
        *numFunctionsToSet = sizeof(funcs) / sizeof(FRENamedFunction);
        *functionsToSet = funcs;
        
        WeChatConnector *connector = [[WeChatConnector alloc] initWithContext:ctx];
        FRESetContextNativeData(ctx, (void *)CFBridgingRetain(connector));
    }
}

static void openaneWeChatContextFinalizer(FREContext ctx)
{
    @autoreleasepool {
        WeChatConnector *connector = openaneWeChatContextNativeData(ctx);
        if (connector != NULL)
        {
            CFBridgingRelease((__bridge CFTypeRef)connector);
            FRESetContextNativeData(ctx, NULL);
        }
    }
}

void openaneWeChatInitializer(void **extDataToSet, FREContextInitializer *ctxInitializerToSet, FREContextFinalizer *ctxFinalizerToSet)
{
    *extDataToSet = NULL;
    *ctxInitializerToSet = &openaneWeChatContextInitializer;
    *ctxFinalizerToSet = &openaneWeChatContextFinalizer;
}

void openaneWeChatFinalizer(void *extData)
{
    
}