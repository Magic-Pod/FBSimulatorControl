/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBSimulatorApplicationDataCommands.h"

#import "FBSimulator.h"
#import "FBSimulatorError.h"

@interface FBSimulatorApplicationDataCommands ()

@property (nonatomic, strong, readonly) FBSimulator *simulator;

@end

@implementation FBSimulatorApplicationDataCommands

#pragma mark Initializers

+ (instancetype)commandsWithTarget:(FBSimulator *)target
{
  return [[self alloc] initWithSimulator:target];
}

- (instancetype)initWithSimulator:(FBSimulator *)simulator
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _simulator = simulator;
  return self;
}

#pragma mark FBApplicationDataCommands

- (FBFuture<NSNull *> *)copyDataAtPath:(NSString *)source toContainerOfApplication:(NSString *)bundleID atContainerPath:(NSString *)containerPath
{
  NSURL *url = [NSURL fileURLWithPath:source];
  return [self copyItemsAtURLs:@[url] toContainerPath:containerPath inBundleID:bundleID];
}

- (FBFuture<NSNull *> *)copyItemsAtURLs:(NSArray<NSURL *> *)paths toContainerPath:(NSString *)containerPath inBundleID:(NSString *)bundleID
{
  return [[self
    dataContainerOfApplicationWithBundleID:bundleID]
    onQueue:self.simulator.asyncQueue fmap:^ FBFuture<NSNull *> * (NSString *dataContainer) {
      NSError *error;
      NSURL *basePathURL =  [NSURL fileURLWithPathComponents:@[dataContainer, containerPath]];
      NSFileManager *fileManager = NSFileManager.defaultManager;
      for (NSURL *url in paths) {
        NSURL *destURL = [basePathURL URLByAppendingPathComponent:url.lastPathComponent];
        if (![fileManager copyItemAtURL:url toURL:destURL error:&error]) {
          return [[[FBSimulatorError
            describeFormat:@"Could not copy from %@ to %@", url, destURL]
            causedBy:error]
            failFuture];
        }
      }
      return FBFuture.empty;
    }];
}

- (FBFuture<NSString *> *)copyDataFromContainerOfApplication:(NSString *)bundleID atContainerPath:(NSString *)containerPath toDestinationPath:(NSString *)destinationPath
{
  __block NSString *dstPath = destinationPath;
  return [[self
    dataContainerOfApplicationWithBundleID:bundleID]
    onQueue:self.simulator.asyncQueue fmap:^ FBFuture<NSString *> * (NSString *dataContainer) {
      NSString *source = [dataContainer stringByAppendingPathComponent:containerPath];
      BOOL srcIsDirecory = NO;
      if ([NSFileManager.defaultManager fileExistsAtPath:source isDirectory:&srcIsDirecory] && !srcIsDirecory) {
        NSError *createDirectoryError;
        if (![NSFileManager.defaultManager createDirectoryAtPath:dstPath withIntermediateDirectories:YES attributes:nil error:&createDirectoryError]) {
          return [[[FBSimulatorError
            describeFormat:@"Could not create temporary directory"]
            causedBy:createDirectoryError]
            failFuture];
        }
        dstPath = [dstPath stringByAppendingPathComponent:[source lastPathComponent]];
      }
      // if it already exists at the destination path we should remove it before copying again
      if ([NSFileManager.defaultManager fileExistsAtPath:dstPath]) {
        NSError *removeError;
        if (![NSFileManager.defaultManager removeItemAtPath:dstPath error:&removeError]) {
          return [[[FBSimulatorError
            describeFormat:@"Could not remove %@", dstPath]
            causedBy:removeError]
            failFuture];
        }
      }

      NSError *copyError;
      if (![NSFileManager.defaultManager copyItemAtPath:source toPath:dstPath error:&copyError]) {
        return [[[FBSimulatorError
          describeFormat:@"Could not copy from %@ to %@", source, dstPath]
          causedBy:copyError]
          failFuture];
      }
      return [FBFuture futureWithResult:destinationPath];
    }];
}

- (FBFuture<NSNull *> *)createDirectory:(NSString *)directoryPath inContainerOfApplication:(NSString *)bundleID
{
  return [[self
    dataContainerOfApplicationWithBundleID:bundleID]
    onQueue:self.simulator.asyncQueue fmap:^ FBFuture<NSNull *> * (NSString *dataContainer) {
      NSError *error;
      NSString *fullPath = [dataContainer stringByAppendingPathComponent:directoryPath];
      if (![NSFileManager.defaultManager createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        return [[[FBSimulatorError
          describeFormat:@"Could not create directory %@ in container %@", directoryPath, dataContainer]
          causedBy:error]
          failFuture];
      }
      return FBFuture.empty;
    }];
}

- (FBFuture<NSNull *> *)movePaths:(NSArray<NSString *> *)originPaths toPath:(NSString *)destinationPath inContainerOfApplication:(NSString *)bundleID
{
  return [[self
    dataContainerOfApplicationWithBundleID:bundleID]
    onQueue:self.simulator.asyncQueue fmap:^ FBFuture<NSNull *> * (NSString *dataContainer) {
      NSError *error;
      NSString *fullDestinationPath = [dataContainer stringByAppendingPathComponent:destinationPath];
      for (NSString *originPath in originPaths) {
        NSString *fullOriginPath = [dataContainer stringByAppendingPathComponent:originPath];
        if (![NSFileManager.defaultManager moveItemAtPath:fullOriginPath toPath:fullDestinationPath error:&error]) {
          return [[[FBSimulatorError
            describeFormat:@"Could not move item at %@ to %@", fullOriginPath, fullDestinationPath]
            causedBy:error]
            failFuture];
        }
      }
      return FBFuture.empty;
    }];
}

- (FBFuture<NSNull *> *)removePaths:(NSArray<NSString *> *)paths inContainerOfApplication:(NSString *)bundleID
{
  return [[self
    dataContainerOfApplicationWithBundleID:bundleID]
    onQueue:self.simulator.asyncQueue fmap:^ FBFuture<NSNull *> * (NSString *dataContainer) {
      NSError *error;
      for (NSString *path in paths) {
        NSString *fullPath = [dataContainer stringByAppendingPathComponent:path];
        if (![NSFileManager.defaultManager removeItemAtPath:fullPath error:&error]) {
          return [[[FBSimulatorError
            describeFormat:@"Could not remove item at path %@", fullPath]
            causedBy:error]
            failFuture];
        }
      }
      return FBFuture.empty;
    }];
}

- (FBFuture<NSArray<NSString *> *> *)contentsOfDirectory:(NSString *)path inContainerOfApplication:(NSString *)bundleID
{
  return [[self
    dataContainerOfApplicationWithBundleID:bundleID]
    onQueue:self.simulator.asyncQueue fmap:^(NSString *dataContainer) {
      NSString *fullPath = [dataContainer stringByAppendingPathComponent:path];
      NSError *error;
      NSArray<NSString *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:fullPath error:&error];
      if (!contents) {
        return [FBFuture futureWithError:error];
      }
      return [FBFuture futureWithResult:contents];
    }];
}

#pragma mark Private

- (FBFuture<NSString *> *)dataContainerOfApplicationWithBundleID:(NSString *)bundleID
{
  NSParameterAssert(bundleID);
  return [[self.simulator
    installedApplicationWithBundleID:bundleID]
    onQueue:self.simulator.asyncQueue chain:^FBFuture<NSString *> *(FBFuture<FBInstalledApplication *> *future) {
      NSString *container = future.result.dataContainer;
      if (container) {
        return [FBFuture futureWithResult:container];
      }
      return [self fallbackDataContainerForBundleID:bundleID];
    }];
}

- (FBFuture<NSString *> *)fallbackDataContainerForBundleID:(NSString *)bundleID
{
  return [[self.simulator
    runningApplicationWithBundleID:bundleID]
    onQueue:self.simulator.asyncQueue fmap:^(FBProcessInfo *runningApplication) {
      NSString *homeDirectory = runningApplication.environment[@"HOME"];
      if (![NSFileManager.defaultManager fileExistsAtPath:homeDirectory]) {
        return [[FBSimulatorError
          describeFormat:@"App Home Directory does not exist at path %@", homeDirectory]
          failFuture];
      }
      return [FBFuture futureWithResult:homeDirectory];
    }];
}

@end
