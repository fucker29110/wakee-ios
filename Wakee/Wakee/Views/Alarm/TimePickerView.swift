import SwiftUI

struct TimePickerView: View {
    @Binding var time: String

    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @Environment(LanguageManager.self) private var lang

    init(time: Binding<String>) {
        self._time = time
        let parts = time.wrappedValue.split(separator: ":").compactMap { Int($0) }
        self._selectedHour = State(initialValue: parts.first ?? 7)
        self._selectedMinute = State(initialValue: parts.count > 1 ? parts[1] : 0)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.lg) {
                // Hour picker
                Picker(lang.l("time.hour"), selection: $selectedHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h))
                            .foregroundColor(AppTheme.Colors.primary)
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 120)
                .clipped()

                Text(":")
                    .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)

                // Minute picker
                Picker(lang.l("time.minute"), selection: $selectedMinute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .foregroundColor(AppTheme.Colors.primary)
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 120)
                .clipped()
            }

            // Display selected time
            Text(TimeUtils.formatAlarmTime(time))
                .font(.system(size: AppTheme.FontSize.lg, weight: .semibold))
                .foregroundColor(AppTheme.Colors.accent)

            // Ring-in countdown
            let alarmDate = TimeUtils.nextAlarmDate(time: time)
            let diff = alarmDate.timeIntervalSince(Date())
            if diff > 0 {
                let hours = Int(diff) / 3600
                let mins = (Int(diff) % 3600) / 60
                Text(lang.l("time.rings_in", args: hours, mins))
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.md)
        .onChange(of: selectedHour) { _, _ in updateTime() }
        .onChange(of: selectedMinute) { _, _ in updateTime() }
    }

    private func updateTime() {
        time = String(format: "%02d:%02d", selectedHour, selectedMinute)
    }
}
