//
//  CharacterRowView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-27.
//

import SwiftUI

struct CharacterRowView: View {
    let name: String
    let imageURL: URL?
    
    var body: some View {
        HStack(spacing: 12) {
            RemoteImageView(url: imageURL, maxRetryCount: 1) { phase in
                switch phase {
                case .empty, .loading:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "person.crop.square")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.portalCyan)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            
            Text(name)
                .font(.headline.weight(.semibold))

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#if DEBUG
struct CharacterRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            CharacterRowView(
                name: "Rick Sanchez",
                imageURL: URL(
                    string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
                )
            )
            CharacterRowView(
                name: "Morty Smith",
                imageURL: nil
            )
        }
        .listStyle(.plain)
    }
}
#endif
