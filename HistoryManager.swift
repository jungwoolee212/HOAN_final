//
//  HistoryManager.swift
//  HOAN2.0
//
//  Created by Joshua Lee on 5/9/26.
//
import Foundation
import Combine
import UIKit

class HistoryManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    @Published var history: [HistoryRecord] = [] {
        didSet {
            saveHistory()
        }
    }
    
    private let defaultsKey = "MoodMusicHistoryData"
    
    init() {
        loadHistory()
    }
    
    // NEW: Now accepts the image and hashtags alongside the recommendation
    func addRecord(recommendation: MusicRecommendation, image: UIImage?, hashtags: [String]) {
        var filename: String? = nil
        if let img = image {
            filename = saveImageLocally(image: img)
        }
        
        let newRecord = HistoryRecord(date: Date(), recommendation: recommendation, imageFileName: filename, hashtags: hashtags)
        history.insert(newRecord, at: 0)
    }
    
    func records(for date: Date) -> [HistoryRecord] {
        return history.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    // MARK: - Image File Management
    private func saveImageLocally(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.6) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("🚨 Failed to save image: \(error.localizedDescription)")
            return nil
        }
    }
    
    func loadImage(fileName: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Data Persistence
    private func saveHistory() {
        do {
            let encoded = try JSONEncoder().encode(history)
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        } catch {
            print("🚨 Failed to save history: \(error.localizedDescription)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([HistoryRecord].self, from: data)
            self.history = decoded
        } catch {
            print("🚨 Failed to load history: \(error.localizedDescription)")
        }
    }
}
