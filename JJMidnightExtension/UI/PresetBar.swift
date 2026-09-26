import AudioToolbox
import Foundation
import SwiftUI

/// The header's preset control: one selector that opens a dropdown holding
/// the whole preset workflow — factory list, user list (swipe a row left to
/// delete or rename it) and a "Save As…" entry — so the panel header needs
/// no separate save/manage/step buttons beside it.
struct PresetBar: View {
    let model: PresetBarViewModel

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

    var body: some View {
        Button {
            model.reload()
            showPicker = true
        } label: {
            selectorLabel
        }
        .buttonStyle(.plain)
        .disabled(!model.isAvailable)
        .accessibilityLabel("Preset")
        .accessibilityValue(model.title)
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
        .sheet(isPresented: $showSave) {
            PresetNameSheet(
                title: "Save Preset",
                caption: "Saves the current knobs. A preset with the same name is replaced.",
                name: $saveName,
                confirmTitle: "Save",
                onCancel: { showSave = false },
                onConfirm: {
                    if model.save(name: saveName) {
                        showSave = false
                    }
                }
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
                        model.rename(preset, to: renameText)
                    }
                    renameTarget = nil
                }
            )
        }
        .alert("Preset", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: - Selector

    // The preset name reads out of a smoked-glass window, like the echo
    // time display on the reference unit.
    private var selectorLabel: some View {
        HStack(spacing: 6) {
            DirtyDot(model: model)
            Text(model.title.uppercased())
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
                .disabled(!model.isAvailable)
                .listRowBackground(GearTheme.chassisBottom)
            }

            Section("Factory") {
                ForEach(FactoryPresets.all, id: \.number) { preset in
                    presetRow(name: preset.name, isCurrent: model.currentNumber == preset.number) {
                        model.selectFactory(preset.number)
                        showPicker = false
                    }
                }
            }

            Section {
                if model.userPresets.isEmpty {
                    Text("No user presets yet. Turn the knobs, then tap Save As…")
                        .font(.system(size: 13))
                        .foregroundStyle(GearTheme.textMuted)
                        .listRowBackground(GearTheme.chassisBottom)
                } else {
                    ForEach(model.userPresets, id: \.number) { preset in
                        presetRow(name: preset.name, isCurrent: model.currentNumber == preset.number) {
                            model.select(preset)
                            showPicker = false
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                model.delete(preset)
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
            saveName = model.suggestedSaveName
            showSave = true
        } else if let preset = pendingRename {
            pendingRename = nil
            renameText = preset.name
            renameTarget = preset
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
    let model: PresetBarViewModel

    var body: some View {
        Circle()
            .fill(model.isDirty ? GearTheme.lampRed : Color.white.opacity(0.06))
            .shadow(color: model.isDirty ? GearTheme.lampRed.opacity(0.8) : .clear, radius: 3)
            .frame(width: 6, height: 6)
    }
}
