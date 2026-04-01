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
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
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
                @unknown default:
                    Color.clear
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(name)
                .font(.headline)
        }
        .padding(.vertical, 4)
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
