//
//  GeminiService.swift
//  HOAN2.0
//
//  Created by Joshua Lee on 5/9/26.
// 집인데집가고싶다
import Foundation
import UIKit
import GoogleGenerativeAI

class GeminiService {
    private let model = GenerativeModel(name: "gemini-2.5-flash", apiKey: "AIzaSyDaBz68QG-8SuFnzdRdbsVk2ckiv0vqaoc")
    
    func analyzeMoodAndGetSongs(from image: UIImage, hashtags: [String]) async throws -> MusicRecommendation {
        let tagsString = hashtags.filter { !$0.isEmpty }.joined(separator: ", ")
        
        let prompt = """
        Analyze the mood of this photo. 
        User-provided context: The user tagged this with: \(tagsString.isEmpty ? "No tags provided" : tagsString).
        
        Task:
        1. Determine the overall emotional mood based on the visual data and the user's tags.
        2. Pick exactly three famous songs that match this specific intersection of visual mood and tags.
        Translate the description into Korean before giving it to the user. Do not give the description in English to the user. Minimalize the Description. For example, '따스한 햇살의 산골짜기'
        Mix Korean songs and English songs in the recommendation, if relevant.
        Format: 
        You must reply ONLY with a valid JSON object. Do not include markdown blocks.
        {
          "mood": "Brief description of the combined mood...",
          "music": [
            {
              "title": "Song Title",
              "artist": "Artist Name",
              "appleMusicURL": "https://music.apple.com/search?term=encoded+song+title+artist"
            }
          ]
        }
        """
        
        let response = try await model.generateContent(prompt, image)
        
        guard let textResponse = response.text else {
            throw NSError(domain: "GeminiError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response"])
        }
        
        let cleanedJSON = cleanJSONString(textResponse)
        let data = Data(cleanedJSON.utf8)
        
        // Decode Gemini's response
        var recommendation = try JSONDecoder().decode(MusicRecommendation.self, from: data)
        
        // NEW: Fetch album artwork for each song from Apple's iTunes API concurrently
        for i in 0..<recommendation.music.count {
            if let artURL = await iTunesService.fetchArtwork(for: recommendation.music[i]) {
                recommendation.music[i].artworkURL = artURL
            }
        }
        
        return recommendation
    }
    
    private func cleanJSONString(_ string: String) -> String {
        var result = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonFence = "`" + "`" + "`json"
        let plainFence = "`" + "`" + "`"
        
        if result.hasPrefix(jsonFence) {
            result = result.replacingOccurrences(of: jsonFence, with: "")
            result = result.replacingOccurrences(of: plainFence, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
