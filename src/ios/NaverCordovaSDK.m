#import "NaverCordovaSDK.h"
#import <Cordova/CDVPlugin.h>
#import <NaverThirdPartyLogin/NaverThirdPartyLogin.h>
#import <objc/runtime.h>

@interface NaverCordovaSDK ()

@property(strong, nonatomic) NSString *loginCallbackId;
@end

@implementation NaverCordovaSDK

- (void)pluginInitialize {
    NSLog(@"Start Naver plugin");

    // Delegate 설정
    [NaverThirdPartyLoginConnection getSharedInstance].delegate = self;

    // 네이버 앱과, 인앱 브라우저 인증을 둘다 사용하도록 설정
    [[NaverThirdPartyLoginConnection getSharedInstance] setIsNaverAppOauthEnable:YES];
    [[NaverThirdPartyLoginConnection getSharedInstance] setIsInAppOauthEnable:YES];

    // 세로 화면 고정 설정
    [[NaverThirdPartyLoginConnection getSharedInstance] setOnlyPortraitSupportInIphone:YES];

    // 네이버 플러그인 데이터 설정
    NSString *serviceUrlScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NaverAppScheme"];
    NSString *consumerKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NaverClientID"];
    NSString *consumerSecret = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NaverClientSecret"];
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NaverClientName"];

    [[NaverThirdPartyLoginConnection getSharedInstance] setServiceUrlScheme:serviceUrlScheme]; // 콜백을 받을 URL Scheme 
    [[NaverThirdPartyLoginConnection getSharedInstance] setConsumerKey:consumerKey]; // 애플리케이션에서 사용하는 클라이언트 아이디 
    [[NaverThirdPartyLoginConnection getSharedInstance] setConsumerSecret:consumerSecret]; // 애플리케이션에서 사용하는 클라이언트 시크릿
    [[NaverThirdPartyLoginConnection getSharedInstance] setAppName:appName]; // 애플리케이션 이름
    

}


#pragma mark - Cordova commands

/**
 * 네이버 로그인을 요청합니다
 *
 * @param command
 */
- (void)login:(CDVInvokedUrlCommand *)command {

    // 로그인 콜백 아이디 설정
    self.loginCallbackId = command.callbackId;

    // 로그인 요청
    NaverThirdPartyLoginConnection *login = [NaverThirdPartyLoginConnection getSharedInstance];
    [login requestThirdPartyLogin];
}

/**
 * 토큰을 지워 로그아웃 처리 합니다.
 *
 * @param command
 */
- (void)logout:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"success"];
    [[NaverThirdPartyLoginConnection getSharedInstance] resetToken];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

 /**
  * 토큰을 지우고, 계정 연동을 해제합니다.
  *
  * @param command
  */
 - (void)unlinkApp:(CDVInvokedUrlCommand *)command {
     // 콜백 아이디 설정
     self.loginCallbackId = command.callbackId;

     // 로그아웃 요청
     NaverThirdPartyLoginConnection *loginConnection = [NaverThirdPartyLoginConnection getSharedInstance];
     [loginConnection requestDeleteToken];
 }


/**
 * mkkim : getAccessToken 추가
 * 토큰 정보를 조회 합니다.
 *
 * @param command
 */
- (void)getAccessToken:(CDVInvokedUrlCommand *)command {
    NSString *accessToken = [[NaverThirdPartyLoginConnection getSharedInstance] accessToken];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:accessToken];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


#pragma mark - NaverThirdPartyLoginConnectionDelegate
// 로그인 성공했을 때
- (void)oauth20ConnectionDidFinishRequestACTokenWithAuthCode {
    NSLog(@"oauth20ConnectionDidFinishRequestACTokenWithAuthCode");
    NSString *accessToken = [[NaverThirdPartyLoginConnection getSharedInstance] accessToken];
    NSString *refreshToken = [[NaverThirdPartyLoginConnection getSharedInstance] refreshToken];
    NSDate *expiresAt = [[NaverThirdPartyLoginConnection getSharedInstance] accessTokenExpireDate];
    NSString *tokenType = [[NaverThirdPartyLoginConnection getSharedInstance] tokenType];
    NSMutableDictionary *userSession =  [NSMutableDictionary new];
    
    NSDictionary *result = @{
                             @"accessToken" : accessToken,
                             @"refreshToken" : refreshToken,
                             @"expiresAt" : [NSString stringWithFormat:@"%f", [expiresAt timeIntervalSince1970]],
                             @"tokenType" : tokenType
                             };
    [userSession addEntriesFromDictionary: result];
    
    NSString *urlString = @"https://openapi.naver.com/v1/nid/me"; // 사용자 프로필 호출 API URL
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    NSString *authValue = [NSString stringWithFormat:@"Bearer %@", accessToken];
    NSString *contentType = @"text/json;charset=utf-8";
    [urlRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *serializationError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&serializationError];
        
        [userSession addEntriesFromDictionary: [json objectForKey:@"response"]];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userSession];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.loginCallbackId];
        self.loginCallbackId = nil;
    }] resume];
}

- (void)oauth20ConnectionDidFinishRequestACTokenWithRefreshToken {
    NSLog(@"oauth20ConnectionDidFinishRequestACTokenWithRefreshToken");
    NSString *accessToken = [[NaverThirdPartyLoginConnection getSharedInstance] accessToken];
    NSString *refreshToken = [[NaverThirdPartyLoginConnection getSharedInstance] refreshToken];
    NSDate *expiresAt = [[NaverThirdPartyLoginConnection getSharedInstance] accessTokenExpireDate];
    NSString *tokenType = [[NaverThirdPartyLoginConnection getSharedInstance] tokenType];

    NSMutableDictionary *userSession =  [NSMutableDictionary new];
    
    NSDictionary *result = @{
                             @"accessToken" : accessToken,
                             @"refreshToken" : refreshToken,
                             @"expiresAt" : [NSString stringWithFormat:@"%f", [expiresAt timeIntervalSince1970]],
                             @"tokenType" : tokenType
                             };
    [userSession addEntriesFromDictionary: result];
  
    NSString *urlString = @"https://openapi.naver.com/v1/nid/me"; // 사용자 프로필 호출 API URL
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    NSString *authValue = [NSString stringWithFormat:@"Bearer %@", accessToken];
    NSString *contentType = @"text/json;charset=utf-8";
    [urlRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *serializationError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&serializationError];
        
        [userSession addEntriesFromDictionary: [json objectForKey:@"response"]];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userSession];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.loginCallbackId];
        self.loginCallbackId = nil;
    }] resume];
}

- (void)oauth20ConnectionDidFinishDeleteToken {
    NSLog(@"oauth20ConnectionDidFinishDeleteToken");
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"success"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.loginCallbackId];

    self.loginCallbackId = nil;
}

// 로그인에 실패했을 때
- (void)oauth20Connection:(NaverThirdPartyLoginConnection *)oauthConnection didFailWithError:(NSError *)error {
    NSLog(@"oauth20Connection");
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.loginCallbackId];

    self.loginCallbackId = nil;
}

- (void)oauth20Connection:(NaverThirdPartyLoginConnection *)oauthConnection didFailAuthorizationWithRecieveType:(THIRDPARTYLOGIN_RECEIVE_TYPE)recieveType
{
    NSLog(@"NaverApp login fail handler");
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%u", (THIRDPARTYLOGIN_RECEIVE_TYPE)recieveType]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.loginCallbackId];

    self.loginCallbackId = nil;

}

- (void)oauth20Connection:(NaverThirdPartyLoginConnection *)oauthConnection didFinishAuthorizationWithResult:(THIRDPARTYLOGIN_RECEIVE_TYPE)recieveType
{
    NSLog(@"Getting auth code from NaverApp success!");
}




@end



// mkkim : 페이스북 SDK와 충돌로 사용 안한다.
// #pragma mark - AppDelegate Overrides

// @implementation AppDelegate (NaverCordovaSDK)

// void NMethodSwizzle(Class c, SEL originalSelector) {
//     NSString *selectorString = NSStringFromSelector(originalSelector);
//     SEL newSelector = NSSelectorFromString([@"swizzled_naver_" stringByAppendingString:selectorString]);
//     SEL noopSelector = NSSelectorFromString([@"noop_naver_" stringByAppendingString:selectorString]);
//     Method originalMethod, newMethod, noop;
//     originalMethod = class_getInstanceMethod(c, originalSelector);
//     newMethod = class_getInstanceMethod(c, newSelector);
//     noop = class_getInstanceMethod(c, noopSelector);
//     if (class_addMethod(c, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
//         class_replaceMethod(c, newSelector, method_getImplementation(originalMethod) ?: method_getImplementation(noop), method_getTypeEncoding(originalMethod));
//     } else {
//         method_exchangeImplementations(originalMethod, newMethod);
//     }
// }

// + (void)load
// {
//     NMethodSwizzle([self class], @selector(application:openURL:sourceApplication:annotation:));
// }

// // This method is a duplicate of the other openURL method below, except using the newer iOS (9) API.
// - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options {
//     if (!url) {
//         return NO;
//     }
//     [[NaverThirdPartyLoginConnection getSharedInstance] application:application openURL:url sourceApplication:[options valueForKey:@"UIApplicationOpenURLOptionsSourceApplicationKey"] annotation:0x0];
    
//     NSLog(@"Naver(ori) handle url: %@", url);


//     // Call existing method
//     return [self swizzled_naver_application:application openURL:url sourceApplication:[options valueForKey:@"UIApplicationOpenURLOptionsSourceApplicationKey"] annotation:0x0];
// }

// - (BOOL)noop_naver_application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
// {
//     return NO;
// }

// - (BOOL)swizzled_naver_application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
// {
//     if (!url) {
//         return NO;
//     }
    
    
//     [[NaverThirdPartyLoginConnection getSharedInstance] application:application openURL:url sourceApplication:sourceApplication annotation:annotation];


//     if ([url isKindOfClass:NSURL.class] && [sourceApplication isKindOfClass:NSString.class] && annotation) {
//     }
//     NSLog(@"Naver(swizzle) handle url: %@", url);
    
//     // Call existing method
//     return [self swizzled_naver_application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
// }
// @end
