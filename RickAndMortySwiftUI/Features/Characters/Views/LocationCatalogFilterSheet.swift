//
//  LocationCatalogFilterSheet.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct LocationCatalogFilterSheet: View {
    @Binding var typeDraft: String
    @Binding var dimensionDraft: String
    let onCancel: () -> Void
    let onApply: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Filters") {
                    TextField("Type (e.g. Space station)", text: $typeDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Dimension (e.g. C-137)", text: $dimensionDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Location Filters")
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
