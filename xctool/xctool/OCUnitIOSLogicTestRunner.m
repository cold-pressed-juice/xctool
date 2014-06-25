//
// Copyright 2013 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "OCUnitIOSLogicTestRunner.h"

#import "NSConcreteTask.h"
#import "SimulatorInfo.h"
#import "TaskUtil.h"
#import "TestingFramework.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@implementation OCUnitIOSLogicTestRunner

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath
{
  NSString *launchPath = [NSString stringWithFormat:@"%@/Developer/%@",
                          _buildSettings[Xcode_SDKROOT],
                          _framework[kTestingFrameworkIOSTestrunnerName]];
  NSArray *args = [[self testArguments] arrayByAddingObject:testBundlePath];
  NSDictionary *env = [self otestEnvironmentWithOverrides:
                       @{
                         @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"],
                         @"DYLD_FRAMEWORK_PATH" : _buildSettings[Xcode_BUILT_PRODUCTS_DIR],
                         @"DYLD_LIBRARY_PATH" : _buildSettings[Xcode_BUILT_PRODUCTS_DIR],
                         @"NSUnbufferedIO" : @"YES",
                         }];

  return [CreateTaskForSimulatorExecutable([self cpuType],
                                           [SimulatorInfo baseVersionForSDKShortVersion:[self.simulatorInfo simulatedSdkVersion]],
                                           launchPath,
                                           args,
                                           env) autorelease];
}

- (void)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors
{
  NSString *sdkName = _buildSettings[Xcode_SDK_NAME];
  NSAssert([sdkName hasPrefix:@"iphonesimulator"], @"Unexpected SDK name: %@", sdkName);

  [self updateSimulatorInfo];

  NSString *testBundlePath = [self testBundlePath];
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if (IsRunningUnderTest()) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    NSPipe *outputPipe = [NSPipe pipe];
    @autoreleasepool {
      NSTask *task = [self otestTaskWithTestBundle:testBundlePath];

      // Don't let STDERR pass through.  This silences the warning message that
      // comes from the 'sim' launcher when the iOS Simulator isn't running:
      // "Simulator does not seem to be running, or may be running an old SDK."
      [task setStandardError:outputPipe];

      LaunchTaskAndFeedOuputLinesToBlock(task,
                                         @"running otest/xctest on test bundle",
                                         outputLineBlock);
    }
    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    *otherErrors = [[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease];
  } else {
    *startupError = [NSString stringWithFormat:@"Test bundle not found at: %@", testBundlePath];
  }
}

@end
