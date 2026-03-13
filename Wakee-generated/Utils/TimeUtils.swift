import Foundation

enum TimeUtils {
    /// "07:30" -> "午前7:30"
    static func formatAlarmTime(_ time: String) -> String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        let h = parts[0], m = parts[1]
        let period = h < 12 ? "午前" : "午後"
        let hour = h % 12 == 0 ? 12 : h % 12
        return "\(period)\(hour):\(String(format: "%02d", m))"
    }

    /// Date -> "今日" / "昨日" / "M月d日"
    static func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今日" }
        if calendar.isDateInYesterday(date) { return "昨日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    /// Date -> "たった今" / "5分前" / "3時間前" / "2日前"
    static func timeAgo(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "たった今" }
        let mins = diff / 60
        if mins < 60 { return "\(mins)分前" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)時間前" }
        let days = hours / 24
        return "\(days)日前"
    }

    /// "07:30" -> next Date for that time (today or tomorrow)
    static func nextAlarmDate(time: String, from: Date = Date()) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return from }
        let h = parts[0], m = parts[1]
        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day], from: from)
        components.hour = h
        components.minute = m
        components.second = 0
        guard let candidate = calendar.date(from: components) else { return from }
        return candidate <= from ? calendar.date(byAdding: .day, value: 1, to: candidate)! : candidate
    }

    /// HH:mm format from Date
    static func formatHHmm(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// Streak calculation from sorted (desc) dates
    static func calculateStreak(dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: dates[0])
        let daysSinceLast = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if daysSinceLast > 1 { return 0 }
        var streak = 1
        for i in 1..<dates.count {
            let prev = calendar.startOfDay(for: dates[i - 1])
            let curr = calendar.startOfDay(for: dates[i])
            let diff = calendar.dateComponents([.day], from: curr, to: prev).day ?? 0
            if diff == 1 { streak += 1 } else { break }
        }
        return streak
    }
}
