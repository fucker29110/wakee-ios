import Foundation

enum TimeUtils {
    /// "07:30" -> "午前7:30" or "7:30 AM"
    static func formatAlarmTime(_ time: String) -> String {
        let lang = LanguageManager.shared
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        let h = parts[0], m = parts[1]
        if lang.currentLanguage == .ja {
            let period = h < 12 ? lang.l("time.am") : lang.l("time.pm")
            let hour = h % 12 == 0 ? 12 : h % 12
            return "\(period)\(hour):\(String(format: "%02d", m))"
        } else {
            let period = h < 12 ? lang.l("time.am") : lang.l("time.pm")
            let hour = h % 12 == 0 ? 12 : h % 12
            return "\(hour):\(String(format: "%02d", m)) \(period)"
        }
    }

    /// Date -> "たった今" / "5分前" / "3時間前" / "2日前"
    static func timeAgo(from date: Date) -> String {
        let lang = LanguageManager.shared
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return lang.l("time.just_now") }
        let mins = diff / 60
        if mins < 60 { return lang.l("time.mins_ago", args: mins) }
        let hours = mins / 60
        if hours < 24 { return lang.l("time.hours_ago", args: hours) }
        let days = hours / 24
        return lang.l("time.days_ago", args: days)
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
        if candidate <= from {
            return calendar.date(byAdding: .day, value: 1, to: candidate) ?? from
        }
        return candidate
    }

    /// HH:mm format from Date
    static func formatHHmm(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

}
