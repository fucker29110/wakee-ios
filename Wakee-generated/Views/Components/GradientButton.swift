import SwiftUI

struct GradientButton: View {
    let title: String
    var icon: String?
    var isLoading: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                    }
                    Text(title)
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if disabled {
                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                            .fill(AppTheme.Colors.button)
                    } else {
                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                            .fill(AppTheme.accentGradient)
                    }
                }
            )
        }
        .disabled(disabled || isLoading)
        .opacity(disabled ? 0.4 : 1)
    }
}
