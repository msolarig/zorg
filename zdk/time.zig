/// Time utilities for working with timestamps

pub const Time = struct {
    /// Time of day representation (hours, minutes, seconds)
    pub const TimeOfDay = struct {
        hour: u8,
        minute: u8,
        second: u8,

        /// Create TimeOfDay from hours, minutes, seconds
        pub fn init(hour: u8, minute: u8, second: u8) TimeOfDay {
            return .{ .hour = hour, .minute = minute, .second = second };
        }

        /// Convert to total seconds since midnight
        pub fn toSeconds(self: TimeOfDay) u32 {
            return @as(u32, self.hour) * 3600 + @as(u32, self.minute) * 60 + @as(u32, self.second);
        }

        /// Check if this time is between start and end (inclusive)
        pub fn isBetween(self: TimeOfDay, start: TimeOfDay, end: TimeOfDay) bool {
            const self_secs = self.toSeconds();
            const start_secs = start.toSeconds();
            const end_secs = end.toSeconds();
            return self_secs >= start_secs and self_secs <= end_secs;
        }

        /// Check if this time is after another time
        pub fn isAfter(self: TimeOfDay, other: TimeOfDay) bool {
            return self.toSeconds() > other.toSeconds();
        }

        /// Check if this time is before another time
        pub fn isBefore(self: TimeOfDay, other: TimeOfDay) bool {
            return self.toSeconds() < other.toSeconds();
        }
    };

    /// Date representation
    pub const Date = struct {
        year: u16,
        month: u8,
        day: u8,
    };

    /// DateTime representation
    pub const DateTime = struct {
        date: Date,
        time: TimeOfDay,
    };

    /// Extract time of day from Unix timestamp (UTC)
    pub fn getTimeOfDay(timestamp: u64) TimeOfDay {
        const seconds_in_day = timestamp % 86400;
        const hour: u8 = @intCast(seconds_in_day / 3600);
        const minute: u8 = @intCast((seconds_in_day % 3600) / 60);
        const second: u8 = @intCast(seconds_in_day % 60);
        return TimeOfDay.init(hour, minute, second);
    }

    /// Extract date from Unix timestamp (UTC)
    pub fn getDate(timestamp: u64) Date {
        const days_since_epoch = timestamp / 86400;
        var year: u16 = 1970;
        var remaining_days = days_since_epoch;

        // Calculate year
        while (true) {
            const days_in_year: u64 = if (isLeapYear(year)) 366 else 365;
            if (remaining_days < days_in_year) break;
            remaining_days -= days_in_year;
            year += 1;
        }

        // Calculate month and day
        const days_in_months = if (isLeapYear(year))
            [_]u8{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
        else
            [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

        var month: u8 = 1;
        for (days_in_months) |days| {
            if (remaining_days < days) break;
            remaining_days -= days;
            month += 1;
        }

        const day: u8 = @intCast(remaining_days + 1);
        return .{ .year = year, .month = month, .day = day };
    }

    /// Get full DateTime from Unix timestamp (UTC)
    pub fn getDateTime(timestamp: u64) DateTime {
        return .{
            .date = getDate(timestamp),
            .time = getTimeOfDay(timestamp),
        };
    }

    /// Check if day changed between two timestamps
    pub fn isDayChange(prev_timestamp: u64, curr_timestamp: u64) bool {
        const prev_day = prev_timestamp / 86400;
        const curr_day = curr_timestamp / 86400;
        return curr_day != prev_day;
    }

    /// Check if it's a new week
    pub fn isWeekChange(prev_timestamp: u64, curr_timestamp: u64) bool {
        const prev_week = prev_timestamp / (86400 * 7);
        const curr_week = curr_timestamp / (86400 * 7);
        return curr_week != prev_week;
    }

    /// Helper: Check if year is leap year
    fn isLeapYear(year: u16) bool {
        return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
    }

    /// Get day of week (0 = Thursday, 1 = Friday, ..., 6 = Wednesday)
    /// Unix epoch started on Thursday, Jan 1, 1970
    pub fn getDayOfWeek(timestamp: u64) u8 {
        const days_since_epoch = timestamp / 86400;
        return @intCast((days_since_epoch + 4) % 7);
    }
};

