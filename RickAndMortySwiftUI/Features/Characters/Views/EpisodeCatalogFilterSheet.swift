//
//  EpisodeCatalogFilterSheet.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct EpisodeCatalogFilterSheet: View {
    @Binding var episodeCodeDraft: String
    let onCancel: () -> Void
    let onApply: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Filters") {
                    TextField("Episode code (e.g. S01)", text: $episodeCodeDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Episode Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: onApply)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
