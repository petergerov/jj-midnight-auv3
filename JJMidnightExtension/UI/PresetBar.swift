import AudioToolbox
import SwiftUI

/// The header's preset control: one selector that opens a dropdown holding
/// the whole preset workflow — factory list, user list (swipe a row left to
/// delete or rename it) and a "Save As…" entry — so the panel header needs
/// no separate save/manage/step buttons beside it.
struct PresetBar: View {
    let audioUnit: JJMidnightAudioUnit?

    @State private var title = "Default"
    @State private var currentNumber: Int?
    @State private var userPresets: [AUAudioUnitPreset] = []
    @State private var showPicker = false
    @State private var showSave = false
    @State private var saveName = ""
    @State private var renameTarget: AUAudioUnitPreset?
    @State private var renameText = ""
    // A sheet can't be raised while the dropdown is still up, so "Save As…"
    // and Rename only mark what to do and close the popover; the actual
    // sheet is presented from the popover's onDismiss below.
    @State private var pendingSave = false
    @State private var pendingRename: AUAudioUnitPreset?
    @State private var errorMessage: String?

    var body: some View {
        Button {
            reload()
            showPicker = true
        } label: {
            selectorLabel
        }
        .buttonStyle(.plain)
        .disabled(audioUnit == nil)
        .accessibilityLabel("Preset")
        .accessibilityValue(title)
        .popover(isPresented: $showPicker) {
            presetList
                .frame(idealWidth: 300, idealHeight: 380)
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: showPicker) { _, isShown in
            guard !isShown, pendingSave || pendingRename != nil else { return }
            Task {
                // Let the popover finish dismissing first — UIKit drops a
                // sheet presented while another dismissal is still running.
                try? await Task.sleep(for: .milliseconds(350))
                presentPendingSheet()
            }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .jjMidnightPresetChanged)) { _ in
            reload()
        }
        .sheet(isPresented: $showSave) {
            PresetNameSheet(
                title: "Save Preset",
                caption: "Saves the current knobs. A preset with the same name is replaced.",
                name: $saveName,
                confirmTitle: "Save",
                onCancel: { showSave = false },
                onConfirm: { save() }
            )
        }
        .sheet(isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            PresetNameSheet(
                title: "Rename Preset",
                caption: "The new name replaces this user preset.",
                name: $renameText,
                confirmTitle: "Rename",
                onCancel: { renameTarget = nil },
                onConfirm: {
                    if let preset = renameTarget {
                        rename(preset, to: renameText)
                    }
                    renameTarget = nil
                }
            )
        }
        .alert("Preset", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Selector

    // The preset name reads out of a smoked-glass window, like the echo
    // time display on the reference unit.
    private var selectorLabel: some View {
        HStack(spacing: 6) {
            DirtyDot(audioUnit: audioUnit)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .shadow(color: GearTheme.ledText.opacity(0.7), radius: 4)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .black))
                .opacity(0.75)
        }
        .foregroundStyle(GearTheme.ledText)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(LedWindow(cornerRadius: 3))
        // The whole window is the button, not just the letters in it. A
        // plain-styled Button hit-tests its drawn content only: the Spacer
        // between the title and the chevron and the LedWindow background are
        // both invisible to touch, which left most of this control dead and
        // only the chevron working.
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    // MARK: - Dropdown

    private var presetList: some View {
        List {
            Section {
                Button {
                    pendingSave = true
                    showPicker = false
                } label: {
                    Label("Save As…", systemImage: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(GearTheme.accent)
                }
                .disabled(audioUnit == nil)
                .listRowBackground(GearTheme.chassisBottom)
            }

            Section("Factory") {
                ForEach(FactoryPresets.all, id: \.number) { preset in
                    presetRow(name: preset.name, isCurrent: currentNumber == preset.number) {
                        selectFactory(preset.number)
                    }
                }
            }

            Section {
                if userPresets.isEmpty {
                    Text("No user presets yet. Turn the knobs, then tap Save As…")
                        .font(.system(size: 13))
                        .foregroundStyle(GearTheme.textMuted)
                        .listRowBackground(GearTheme.chassisBottom)
                } else {
                    ForEach(userPresets, id: \.number) { preset in
                        presetRow(name: preset.name, isCurrent: currentNumber == preset.number) {
                            select(preset)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                delete(preset)
                            }
                            Button("Rename") {
                                pendingRename = preset
                                showPicker = false
                            }
                            .tint(GearTheme.accent)
                        }
                    }
                }
            } header: {
                Text("User")
            } footer: {
                Text("Swipe a user preset left to rename or delete it. Factory presets cannot be changed.")
                    .font(.system(size: 11))
            }

        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 34)
        .scrollContentBackground(.hidden)
        .background(GearTheme.chassisBottom)
        .tint(GearTheme.accent)
    }

    private func presetRow(name: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(.system(size: 15))
                    .foregroundStyle(GearTheme.textLight)
                Spacer(minLength: 8)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(GearTheme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .listRowBackground(GearTheme.chassisBottom)
    }

    private func presentPendingSheet() {
        if pendingSave {
            pendingSave = false
            saveName = suggestedSaveName
            showSave = true
        } else if let preset = pendingRename {
            pendingRename = nil
            renameText = preset.name
            renameTarget = preset
        }
    }

    // MARK: - Model

    private var suggestedSaveName: String {
        if let current = audioUnit?.currentPreset, current.number < 0 {
            return current.name
        }
        return ""
    }

    private func reload() {
        userPresets = (audioUnit?.userPresets ?? []).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        title = audioUnit?.currentPreset?.name ?? "Default"
        currentNumber = audioUnit?.currentPreset?.number
    }

    private func selectFactory(_ number: Int) {
        audioUnit?.currentPreset = audioUnit?.factoryPresets?.first { $0.number == number }
        reload()
        showPicker = false
    }

    private func select(_ preset: AUAudioUnitPreset) {
        audioUnit?.currentPreset = preset
        reload()
        showPicker = false
    }

    private func save() {
        guard let audioUnit else {
            errorMessage = "Effect is not loaded."
            return
        }
        do {
            try audioUnit.saveCurrentStateAsUserPreset(name: saveName)
            showSave = false
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rename(_ preset: AUAudioUnitPreset, to name: String) {
        do {
            try audioUnit?.renameUserPreset(preset, to: name)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ preset: AUAudioUnitPreset) {
        do {
            try audioUnit?.removeUserPreset(preset)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PresetNameSheet: View {
    let title: String
    let caption: String
    @Binding var name: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundStyle(GearTheme.textMuted)
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(10)
                    .background(GearTheme.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(GearTheme.metalDark, lineWidth: 1)
                    )
                    .foregroundStyle(GearTheme.textLight)
                Spacer()
            }
            .padding(16)
            .background(GearTheme.chassisBottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(GearTheme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle, action: onConfirm)
                        .foregroundStyle(GearTheme.accent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(220), .medium])
        .tint(GearTheme.accent)
    }
}

private struct DirtyDot: View {
    let audioUnit: JJMidnightAudioUnit?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            Circle()
                .fill((audioUnit?.isPresetDirty() ?? false) ? GearTheme.lampRed : Color.white.opacity(0.06))
                .shadow(color: (audioUnit?.isPresetDirty() ?? false) ? GearTheme.lampRed.opacity(0.8) : .clear, radius: 3)
                .frame(width: 6, height: 6)
        }
    }
}
