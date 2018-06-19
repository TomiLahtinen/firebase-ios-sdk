/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"

#include <queue>

#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;

const FSTListenSequenceNumber kFSTListenSequenceNumberInvalid = -1;

/**
 * RollingSequenceNumberBuffer tracks the nth sequence number in a series. Sequence numbers may be
 * added out of order.
 */
class RollingSequenceNumberBuffer {
 public:
  explicit RollingSequenceNumberBuffer(NSUInteger max_elements)
      : max_elements_(max_elements), queue_(std::priority_queue<FSTListenSequenceNumber>()) {
  }

  RollingSequenceNumberBuffer(const RollingSequenceNumberBuffer &other) = delete;

  RollingSequenceNumberBuffer &operator=(const RollingSequenceNumberBuffer &other) = delete;

  void AddElement(FSTListenSequenceNumber sequence_number) {
    if (queue_.size() < max_elements_) {
      queue_.push(sequence_number);
    } else {
      FSTListenSequenceNumber highestValue = queue_.top();
      if (sequence_number < highestValue) {
        queue_.pop();
        queue_.push(sequence_number);
      }
    }
  }

  FSTListenSequenceNumber max_value() const {
    return queue_.top();
  }

  std::size_t size() const {
    return queue_.size();
  }

 private:
  std::priority_queue<FSTListenSequenceNumber> queue_;
  const NSUInteger max_elements_;
};

@interface FSTLRUGarbageCollector ()

@property(nonatomic, strong, readonly) id<FSTQueryCache> queryCache;

@end

@implementation FSTLRUGarbageCollector {
  id<FSTLRUDelegate> _delegate;
}

- (instancetype)initWithQueryCache:(id<FSTQueryCache>)queryCache
                          delegate:(id<FSTLRUDelegate>)delegate {
  self = [super init];
  if (self) {
    _queryCache = queryCache;
    _delegate = delegate;
  }
  return self;
}

- (NSUInteger)queryCountForPercentile:(NSUInteger)percentile {
  NSUInteger totalCount = (NSUInteger)[self.queryCache count];
  NSUInteger setSize = (NSUInteger)((percentile / 100.0f) * totalCount);
  return setSize;
}

- (FSTListenSequenceNumber)sequenceNumberForQueryCount:(NSUInteger)queryCount {
  if (queryCount == 0) {
    return kFSTListenSequenceNumberInvalid;
  }
  RollingSequenceNumberBuffer buffer(queryCount);
  // Pointer is necessary to access stack-allocated buffer from a block.
  RollingSequenceNumberBuffer *ptr_to_buffer = &buffer;
  [_delegate enumerateTargetsUsingBlock:^(FSTQueryData *queryData, BOOL *stop) {
    ptr_to_buffer->AddElement(queryData.sequenceNumber);
  }];
  [_delegate enumerateMutationsUsingBlock:^(const DocumentKey &docKey,
                                            FSTListenSequenceNumber sequenceNumber, BOOL *stop) {
    ptr_to_buffer->AddElement(sequenceNumber);
  }];
  return buffer.max_value();
}

- (NSUInteger)removeQueriesUpThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                                       liveQueries:
                                           (NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  return [_delegate removeTargetsThroughSequenceNumber:sequenceNumber liveQueries:liveQueries];
}

- (NSUInteger)removeOrphanedDocumentsThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber {
  return [_delegate removeOrphanedDocumentsThroughSequenceNumber:sequenceNumber];
}

@end