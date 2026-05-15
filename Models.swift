//
//  Models.swift
//  HOAN2.0
//
//  Created by Joshua Lee on 5/9/26.
//
import Foundation

struct HistoryRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let recommendation: MusicRecommendation
    let imageFileName: String?
    let hashtags: [String]
    
    init(id: UUID = UUID(), date: Date, recommendation: MusicRecommendation, imageFileName: String? = nil, hashtags: [String] = []) {
        self.id = id
        self.date = date
        self.recommendation = recommendation
        self.imageFileName = imageFileName
        self.hashtags = hashtags
    }
}

struct MusicRecommendation: Codable {
    let mood: String
    var music: [Song] // Changed to var so we can inject the album art later
}

struct Song: Codable, Identifiable {
    var id: String { title + artist }
    let title: String
    let artist: String
    let appleMusicURL: String
    var artworkURL: URL? // NEW: Holds the Apple Music album cover link
}
