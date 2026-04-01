//
//  CharactersSpeciesTypeFilterSheet.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct CharactersSpeciesTypeFilterSheet: View {
    @Binding var speciesDraft: String
    @Binding var typeDraft: String
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Text Filters") {
                    TextField("Species (e.g. Human)", text: $speciesDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Type (e.g. Parasite)", text: $typeDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Species & Type")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
