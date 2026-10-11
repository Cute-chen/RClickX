//
//  FolderPermissionsSheetView.swift
//  RClick
//
//  Created by Claude on 2026/07/12.
//

import AppKit
import SwiftUI

struct FolderPermissionsSheetView: View {
    @ObservedObject var bookmarkManager: BookmarkManager
    @Environment(\.dismiss) private var dismiss

    @State private var mountedExternalVolumes: [URL] = []

    private let startupDiskURL = URL(fileURLWithPath: "/", isDirectory: true)

    var body: some View {
        VStack(spacing: 0) {
            Text(AppLocalization.localized("Folder Permissions"))
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            List {
                Section(AppLocalization.localized("Access Presets")) {
                    presetRow(
                        icon: "internaldrive",
                        title: AppLocalization.localized("Entire startup disk"),
                        subtitle: AppLocalization.localized("Authorize / and all folders on the startup disk"),
                        url: startupDiskURL
                    )

                    HStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppLocalization.localized("Choose a folder"))
                            Text(AppLocalization.localized("Authorize this folder and its subfolders"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(AppLocalization.localized("Choose…")) {
                            addDirectory()
                        }
                        .controlSize(.small)
                    }
                }

                Section(AppLocalization.localized("Authorized folders")) {
                    if bookmarkManager.authorizedDirectories.isEmpty {
                        Text(AppLocalization.localized("No folders authorized"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bookmarkManager.authorizedDirectories, id: \.path) { url in
                            authorizedFolderRow(url)
                        }
                    }
                }

                Section(AppLocalization.localized("External disks")) {
                    if mountedExternalVolumes.isEmpty {
                        Text(AppLocalization.localized("No external disks are currently mounted"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(mountedExternalVolumes, id: \.path) { volume in
                            presetRow(
                                icon: "externaldrive",
                                title: volume.lastPathComponent,
                                subtitle: volume.path,
                                url: volume
                            )
                        }

                        Text(AppLocalization.localized("Each external disk needs one confirmation. Future disks must be authorized when first connected."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 360)

            Divider()

            HStack {
                Spacer()

                Button(AppLocalization.localized("Done")) {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 560, height: 560)
        .onAppear {
            refreshMountedExternalVolumes()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in
            refreshMountedExternalVolumes()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            refreshMountedExternalVolumes()
        }
    }

    @ViewBuilder
    private func presetRow(icon: String, title: String, subtitle: String, url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if hasAccessRecord(for: url) {
                Label(AppLocalization.localized("Authorized"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button(AppLocalization.localized("Authorize…")) {
                    addDirectory(startingAt: url)
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func authorizedFolderRow(_ url: URL) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: url.path == "/" ? "internaldrive.fill" : "folder.fill")
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.path == "/" ? AppLocalization.localized("Entire startup disk") : url.lastPathComponent)
                    .lineLimit(1)
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(AppLocalization.localized("Authorizes this folder and all its subfolders"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                bookmarkManager.removeDirectory(url)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help(AppLocalization.localized("Remove folder permission"))
        }
        .padding(.vertical, 2)
    }

    private func hasAccessRecord(for url: URL) -> Bool {
        let target = url.resolvingSymlinksInPath()
        return bookmarkManager.authorizedDirectories.contains { directory in
            BookmarkManager.covers(directory, target)
        }
    }

    private func addDirectory(startingAt url: URL? = nil) {
        Task { @MainActor in
            _ = await bookmarkManager.addDirectory(startingAt: url)
        }
    }

    private func refreshMountedExternalVolumes() {
        let keys: Set<URLResourceKey> = [
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey
        ]

        mountedExternalVolumes = (FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []).filter { volume in
            guard volume.path != "/",
                  let values = try? volume.resourceValues(forKeys: keys) else {
                return false
            }

            return volume.path.hasPrefix("/Volumes/")
                || values.volumeIsInternal == false
                || values.volumeIsRemovable == true
                || values.volumeIsEjectable == true
        }
    }
}
