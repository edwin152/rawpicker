//
//  rawpickerApp.swift
//  rawpicker
//
//  Created by edwin on 2026/4/21.
//
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
@MainActor
struct RawPickerApp: App {
    @StateObject private var viewer = ViewerModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewer)
                .preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.ui("Open...")) {
                    viewer.open()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(L10n.ui("Close Project")) {
                    viewer.closeProject()
                }
                .disabled(!viewer.hasProject)

                Divider()

                if viewer.canExportFavorites {
                    Menu(L10n.ui("Export favorites")) {
                        Button(L10n.ui("Copy favorites")) {
                            viewer.exportFavorites(mode: .copy)
                        }

                        Button(L10n.ui("Move favorites")) {
                            viewer.exportFavorites(mode: .move)
                        }
                    }
                } else {
                    Button(L10n.ui("Export favorites")) {
                    }
                    .disabled(true)
                }
            }

            CommandMenu(L10n.ui("Viewer")) {
                Button(L10n.ui("Previous")) {
                    viewer.goPrevious(isRepeat: false)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!viewer.canGoPrevious)

                Button(L10n.ui("Next")) {
                    viewer.goNext(isRepeat: false)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!viewer.canGoNext)

                Button(L10n.ui("Set 5 Stars / Reset Rating")) {
                    viewer.toggleFavoriteCurrent()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!viewer.hasCurrentAsset)

                Button(L10n.ui("Fit / 100%")) {
                    viewer.toggleFit()
                }
                .keyboardShortcut("f", modifiers: [])
                .disabled(!viewer.hasCurrentAsset)

                Divider()

                Button(L10n.ui("Zoom In")) {
                    viewer.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!viewer.hasCurrentAsset)

                Button(L10n.ui("Zoom Out")) {
                    viewer.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!viewer.hasCurrentAsset)

                Button(L10n.ui("Toggle EXIF")) {
                    viewer.showExif.toggle()
                }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(!viewer.hasCurrentAsset)
            }
        }
    }
}
