/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#import "WXJSRuntimeBridge.h"
#import "WXUtility.h"
#import "WXCoreBridge.h"
#import "WXConvertUtility.h"

#include "core/bridge/script/script_side_in_simple.h"
#include "core/manager/weex_core_manager.h"

static WeexByteArray *generatorBytesArray(const char *str, size_t len) {
    auto *result = (WeexByteArray *)malloc(len + sizeof(WeexByteArray));
    do {
        if (!result) {
            break;
        }
        memset(result, 0, len + sizeof(WeexByteArray));
        result->length = static_cast<uint32_t>(len);
        memcpy(result->content, str, len);
        result->content[len] = '\0';
        
    } while (0);
    
    return result;
}

using WeexCore::bridge::script::ScriptSideInSimple;
@interface WXJSRuntimeBridge ()
{
    NSString * _weexInstanceId;
    ScriptBridge::ScriptSide* script_side_;
}

@end

@implementation WXJSRuntimeBridge

- (instancetype)init
{
    if (self = [super init]) {
        script_side_ = WeexCore::WeexCoreManager::Instance()->script_bridge()->script_side();
    }
    return self;
}

- (instancetype)initWithoutDefaultContext
{
    self = [self init];
    return self;
}

- (NSString *)weexInstanceId
{
    return _weexInstanceId;
}

- (void)setWeexInstanceId:(NSString *)weexInstanceId
{
    _weexInstanceId = weexInstanceId;
}

- (NSString *)exception
{
    return nil;
}

- (NSString *)callJSMethod:(nonnull NSString *)method args:(NSArray * _Nullable)args {

    std::vector<VALUE_WITH_TYPE*> params;

    for (id obj in args)
    {
        NSString *jsonString = @"";
        if ([obj isKindOfClass:[NSString class]])
        {
            jsonString = obj;
        }
        else
        {
            jsonString = [WXUtility JSONString:obj];
        }
        VALUE_WITH_TYPE* param = new VALUE_WITH_TYPE();
        param->type = ParamsType::BYTEARRAYJSONSTRING;
        param->value.byteArray = generatorBytesArray(jsonString.UTF8String, [jsonString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        params.push_back(param);
    }
    
    std::unique_ptr<WeexJSResult> ret = script_side_->ExecJSWithResult([_weexInstanceId UTF8String], "", [method UTF8String], params);
    if (ret && ret->data.get())
    {
        NSString *str = [[NSString alloc] initWithUTF8String:ret->data.get()];
        return str;
    }
    return nil;
}

- (void)executeJSFramework:(nonnull NSString *)frameworkScript
{
    NSDictionary *data = [WXUtility getEnvironment];
    std::vector<std::pair<std::string, std::string>>* params = new std::vector<std::pair<std::string, std::string>>();
    [data enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        ConvertToCString(obj, ^(const char * value) {
            if (value != nullptr) {
                params->emplace_back([key UTF8String], value);
            }
        });
    }];
    script_side_->InitFramework([frameworkScript UTF8String] ?: "", *params);
}

- (void)executeJavascript:(nonnull NSString *)script {
    [self executeJavascript:script withSourceURL:nil];
}

- (void)executeJavascript:(NSString *)script withSourceURL:(NSURL *)sourceURL
{
    script_side_->ExecJSOnInstance([self.weexInstanceId UTF8String], [script UTF8String], (int)[script lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0);
}

+ (NSString *)jsonStringFromObject:(id)object
{
    if ([NSJSONSerialization isValidJSONObject:object])
    {
        NSData *body = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
        NSString *string = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        return string;
    }
    return @"";
}

- (void)createInstance:(NSString *)instanceId
                script:(NSString *)script
                  opts:(NSDictionary *)opts
              initData:(NSArray *)initData
            extendsApi:(NSString *)extendsApi
                params:(NSDictionary *)params
{
    //int WeexRuntimeQJS::createInstance(const std::string &instanceId,
    //                                   const std::string &func,
    //                                   const char *script,
    //                                   const int script_size,
    //                                   const std::string &opts,
    //                                   const std::string &initData,
    //                                   const std::string &extendsApi,
    //                                   std::vector<std::pair<std::string, std::string>> params,
    //                                   unsigned int engine_type)
    NSString *optsString = [[self class] jsonStringFromObject:opts];
    NSString *initDataString = [[self class] jsonStringFromObject:initData];
    std::vector<std::pair<std::string, std::string>>* result = new std::vector<std::pair<std::string, std::string>>();
    [params enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        ConvertToCString(obj, ^(const char * value) {
            if (value != nullptr) {
                result->emplace_back([key UTF8String], value);
            }
        });
    }];
    script_side_->CreateInstance(instanceId.UTF8String,
                                 "",
                                 script.UTF8String,
                                 (int)[script lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                 optsString.UTF8String,
                                 initDataString.UTF8String,
                                 extendsApi.UTF8String,
                                 *result
                                 );
}

- (void)registerCallAddElement:(nonnull WXJSCallAddElement)callAddElement {
   
}

- (void)registerCallAddEvent:(nonnull WXJSCallAddEvent)callAddEvent {
    
}

- (void)registerCallCreateBody:(nonnull WXJSCallCreateBody)callCreateBody {
    
}

- (void)registerCallCreateFinish:(nonnull WXJSCallCreateFinish)callCreateFinish {
    
}

- (void)registerCallMoveElement:(nonnull WXJSCallMoveElement)callMoveElement {
    
}

- (void)registerCallNative:(nonnull WXJSCallNative)callNative {
    
}

- (void)registerCallNativeComponent:(nonnull WXJSCallNativeComponent)callNativeComponentBlock {
    
}

- (void)registerCallNativeModule:(nonnull WXJSCallNativeModule)callNativeModuleBlock {
    
}

- (void)registerCallRemoveElement:(nonnull WXJSCallRemoveElement)callRemoveElement {
    
}

- (void)registerCallRemoveEvent:(nonnull WXJSCallRemoveEvent)callRemoveEvent {
    
}

- (void)registerCallUpdateAttrs:(nonnull WXJSCallUpdateAttrs)callUpdateAttrs {
    
}

- (void)registerCallUpdateComponentData:(nonnull WXJSCallUpdateComponentData)callUpdateComponentData {

}

- (void)registerCallUpdateStyle:(nonnull WXJSCallUpdateStyle)callUpdateStyle {
    
}

- (void)resetEnvironment {
    
}

- (void)setObject:(nullable id)object forKeyedSubscript:(nonnull NSObject <NSCopying> *)key
{
    
}

- (void)copySandboxFromGlobalBridge:(id<WXBridgeProtocol>/*instanceType*/)globalBridge
{
    
}

/// quickjs 无需设置，保留空 impl 即可
/// @param name contextName
- (void)setContextName:(NSString *)name {}

@end
