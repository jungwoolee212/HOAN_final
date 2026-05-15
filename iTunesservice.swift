//
//  iTunesservice.swift
//  HOAN2.0
//
//  Created by Joshua Lee on 5/9/26.
//
import Foundation

class iTunesService {
    
    static func fetchArtwork(for song: Song) async -> URL? {
        // Combine title and artist for a highly accurate search
        let searchTerm = "\(song.title) \(song.artist)"
        guard let encodedTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        
        let urlString = "https://itunes.apple.com/search?term=\(encodedTerm)&entity=song&limit=1"
        
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url) else {
            return nil
        }
        
        // Temporary structs just to decode Apple's JSON response
        struct ITunesResponse: Codable { let results: [ITunesTrack] }
        struct ITunesTrack: Codable { let artworkUrl100: String }
        
        guard let decoded = try? JSONDecoder().decode(ITunesResponse.self, from: data),
              let track = decoded.results.first else {
            return nil
        }
        
       
        let highResURLString = track.artworkUrl100.replacingOccurrences(of: "100x100bb", with: "600x600bb")
        
        return URL(string: highResURLString)
    }
}
