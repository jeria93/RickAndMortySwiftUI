//
//  CharactersFiltersMenu.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct CharactersFiltersMenu: View {
    let statusFilter: CharacterStatusFilter
    let genderFilter: CharacterGenderFilter
    let hasActiveQuery: Bool
    let hasSpeciesOrTypeFilter: Bool
    let onStatusChange: (CharacterStatusFilter) -> Void
    let onGenderChange: (CharacterGenderFilter) -> Void
    let onEditSpeciesType: () -> Void
    let onClearSpeciesType: () -> Void
    let onClearAll: () -> Void
    
    var body: some View {
        Menu {
            Menu("Status") {
                ForEach(CharacterStatusFilter.allCases, id: \.self) { status in
                    Button {
                        onStatusChange(status)
                    } label: {
                        selectionLabel(
                            title: status.title,
                            isSelected: statusFilter == status
                        )
                    }
                }
            }
            
            Menu("Gender") {
                ForEach(CharacterGenderFilter.allCases, id: \.self) { gender in
                    Button {
                        onGenderChange(gender)
                    } label: {
                        selectionLabel(
                            title: gender.title,
                            isSelected: genderFilter == gender
                        )
                    }
                }
            }
            
            Divider()
            Button {
                onEditSpeciesType()
            } label: {
                selectionLabel(
                    title: "Species & Type",
                    isSelected: hasSpeciesOrTypeFilter
                )
            }
            
            if hasSpeciesOrTypeFilter {
                Button("Clear Species & Type") {
                    onClearSpeciesType()
                }
            }
            
            if hasActiveQuery {
                Divider()
                Button("Clear Search & Filters") {
                    onClearAll()
                }
            }
        } label: {
            Label(
                "Filters",
                systemImage: hasActiveQuery
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle"
            )
        }
    }
    
    @ViewBuilder
    private func selectionLabel(title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
