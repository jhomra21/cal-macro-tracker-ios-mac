import SwiftUI

struct HistoryCalendarView: View {
    @Binding var selection: Date

    var body: some View {
        DatePicker(
            "Select Day",
            selection: normalizedSelection,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
    }

    private var normalizedSelection: Binding<Date> {
        Binding(
            get: {
                selection.startOfDayValue
            },
            set: { newValue in
                selection = newValue.startOfDayValue
            }
        )
    }
}
