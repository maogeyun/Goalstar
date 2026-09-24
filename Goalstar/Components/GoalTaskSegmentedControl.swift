import SwiftUI

/// 1.0-style segmented control. The task segment can be disabled when there is no active goal.
struct GoalTaskSegmentedControl: UIViewRepresentable {
    @Binding var mode: CreateFormMode
    var taskEnabled: Bool
    var goalTitle: String
    var taskTitle: String

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: $mode)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: [goalTitle, taskTitle])
        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.mode = $mode
        control.setTitle(goalTitle, forSegmentAt: 0)
        control.setTitle(taskTitle, forSegmentAt: 1)
        let desired = mode == .goal ? 0 : 1
        if control.selectedSegmentIndex != desired {
            control.removeTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
            control.selectedSegmentIndex = desired
            control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        }
        control.setEnabled(true, forSegmentAt: 0)
        control.setEnabled(taskEnabled, forSegmentAt: 1)
        control.selectedSegmentTintColor = UIColor(GSColor.brand)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor(GSColor.textPrimary)], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor(GSColor.textSecondary)], for: .disabled)
    }

    final class Coordinator: NSObject {
        var mode: Binding<CreateFormMode>

        init(mode: Binding<CreateFormMode>) {
            self.mode = mode
        }

        @objc func changed(_ sender: UISegmentedControl) {
            let next: CreateFormMode = sender.selectedSegmentIndex == 0 ? .goal : .task
            guard next != mode.wrappedValue else { return }
            mode.wrappedValue = next
        }
    }
}
