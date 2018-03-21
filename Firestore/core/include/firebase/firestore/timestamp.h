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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_TIMESTAMP_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_TIMESTAMP_H_

#if !defined(_STLPORT_VERSION)
#include <chrono>
#endif  // !defined(_STLPORT_VERSION)
#include <stdint.h>
#include <time.h>

namespace firebase {

/**
 * A Timestamp represents a point in time independent of any time zone or
 * calendar, represented as seconds and fractions of seconds at nanosecond
 * resolution in UTC Epoch time. It is encoded using the Proleptic Gregorian
 * Calendar which extends the Gregorian calendar backwards to year one. It is
 * encoded assuming all minutes are 60 seconds long, i.e. leap seconds are
 * "smeared" so that no leap second table is needed for interpretation. Range is
 * from 0001-01-01T00:00:00Z to 9999-12-31T23:59:59.999999999Z.
 *
 * @see
 * https://github.com/google/protobuf/blob/master/src/google/protobuf/timestamp.proto
 */
class Timestamp {
 public:
  /**
   * Creates a new timestamp representing the epoch (with seconds and
   * nanoseconds set to 0).
   */
  Timestamp();

  /**
   * Creates a new timestamp.
   *
   * @param seconds The number of seconds of UTC time since Unix epoch
   *     1970-01-01T00:00:00Z. Must be from 0001-01-01T00:00:00Z to
   *     9999-12-31T23:59:59Z inclusive; otherwise, assertion failure will be
   *     triggered.
   * @param nanoseconds The non-negative fractions of a second at nanosecond
   *     resolution. Negative second values with fractions must still have
   *     non-negative nanoseconds values that count forward in time. Must be
   *     from 0 to 999,999,999 inclusive; otherwise, assertion failure will be
   *     triggered.
   */
  Timestamp(int64_t seconds, int32_t nanoseconds);

  /**
   * Creates a new timestamp with the current date.
   *
   * The precision is up to nanoseconds, depending on the system clock.
   *
   * @return a new timestamp representing the current date.
   */
  static Timestamp Now();

  /**
   * The number of seconds of UTC time since Unix epoch 1970-01-01T00:00:00Z.
   */
  int64_t seconds() const {
    return seconds_;
  }

  /**
   * The non-negative fractions of a second at nanosecond resolution. Negative
   * second values with fractions still have non-negative nanoseconds values
   * that count forward in time.
   */
  int32_t nanoseconds() const {
    return nanoseconds_;
  }

  /**
   * Converts `time_t` to a `Timestamp`.
   *
   * @param seconds_since_unix_epoch
   *     @parblock
   *     The number of seconds of UTC time since Unix epoch
   *     1970-01-01T00:00:00Z. Can be negative to represent dates before the
   *     epoch. Must be from 0001-01-01T00:00:00Z to 9999-12-31T23:59:59Z
   *     inclusive; otherwise, assertion failure will be triggered.
   *
   *     Note that while the epoch of `time_t` is unspecified, it's usually Unix
   *     epoch. If this assumption is broken, this function will produce
   *     incorrect results.
   *     @endparblock
   *
   * @return a new timestamp with the given number of seconds and zero
   *     nanoseconds.
   */
  static Timestamp FromTime(time_t seconds_since_unix_epoch);

#if !defined(_STLPORT_VERSION)
  /**
   * Converts `std::chrono::time_point` to a `Timestamp`.
   *
   * @param time_point
   *     @parblock
   *     The time point with system clock's epoch, which is
   *     presumed to be Unix epoch 1970-01-01T00:00:00Z. Can be negative to
   *     represent dates before the epoch. Must be from 0001-01-01T00:00:00Z to
   *     9999-12-31T23:59:59Z inclusive; otherwise, assertion failure will be
   *     triggered.
   *
   *     Note that while the epoch of `std::chrono::system_clock` is
   *     unspecified, it's usually Unix epoch. If this assumption is broken,
   *     this constructor will produce incorrect results.
   *     @endparblock
   */
  explicit Timestamp(
      std::chrono::time_point<std::chrono::system_clock> time_point);
#endif  // !defined(_STLPORT_VERSION)

 private:
  // Checks that the number of seconds is within the supported date range, and
  // that nanoseconds satisfy 0 <= ns <= 1second.
  void ValidateBounds();

  int64_t seconds_ = 0;
  int32_t nanoseconds_ = 0;
};

inline bool operator<(const Timestamp& lhs, const Timestamp& rhs) {
  return lhs.seconds() < rhs.seconds() ||
         (lhs.seconds() == rhs.seconds() &&
          lhs.nanoseconds() < rhs.nanoseconds());
}

inline bool operator>(const Timestamp& lhs, const Timestamp& rhs) {
  return rhs < lhs;
}

inline bool operator>=(const Timestamp& lhs, const Timestamp& rhs) {
  return !(lhs < rhs);
}

inline bool operator<=(const Timestamp& lhs, const Timestamp& rhs) {
  return !(lhs > rhs);
}

inline bool operator!=(const Timestamp& lhs, const Timestamp& rhs) {
  return lhs < rhs || lhs > rhs;
}

inline bool operator==(const Timestamp& lhs, const Timestamp& rhs) {
  return !(lhs != rhs);
}

}  // namespace firebase

namespace std {
template <>
struct hash<firebase::Timestamp> {
  size_t operator()(const firebase::Timestamp& timestamp) const {
    int32_t result = 1;
    const auto consume = [&result](const int32_t value) {
      const int prime = 37;
      result = prime * result + value;
    };
    consume(static_cast<int32_t>(timestamp.seconds()));
    consume(static_cast<int32_t>(timestamp.seconds() >> 32));
    consume(static_cast<int32_t>(timestamp.nanoseconds()));
    return result;
  }
};
}  // namespace std

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_TIMESTAMP_H_