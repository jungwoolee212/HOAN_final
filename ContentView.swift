//
//  ContentView.swift
//  HOAN2.0
//
//  Created by Joshua Lee on 5/9/26.
// DO NOT CHANGE WITHOUT PERMISSION

import SwiftUI
import PhotosUI

extension Color {
    static let crimson = Color(red: 134 / 255, green: 38 / 255, blue: 51 / 255)
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var selectedItem: PhotosPickerItem?
    
    @State private var tag1: String = ""
    @State private var tag2: String = ""
    
    @State private var isLoading = false
    @State private var recommendation: MusicRecommendation?
    @State private var errorMessage: String?
    
    private let geminiService = GeminiService()
    @StateObject private var historyManager = HistoryManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 250)
                            .clipped()
                            .cornerRadius(15)
                    } else {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 250)
                            .overlay(Image(systemName: "camera.viewfinder").font(.largeTitle).foregroundColor(.gray))
                    }

                    HStack {
                        Button(action: { showingCamera = true }) {
                            Label("카메라", systemImage: "camera.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.crimson)
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("사진첩", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.crimson)
                    }

                    VStack(alignment: .leading) {
                        Text("무드 해시태그 입력")
                            .font(.caption).bold().foregroundColor(.secondary)
                        HStack {
                            TextField("#mood1", text: $tag1).textFieldStyle(.roundedBorder).autocapitalization(.none)
                            TextField("#mood2", text: $tag2).textFieldStyle(.roundedBorder).autocapitalization(.none)
                        }
                    }
                    .padding(.horizontal)

                    Button(action: analyze) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("음악찾기").bold().frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.crimson)
                    .disabled(selectedImage == nil || isLoading)

                    if let errorMessage {
                        Text(errorMessage).foregroundColor(.red).font(.caption).multilineTextAlignment(.center).padding()
                    }

                    if let recommendation {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(recommendation.mood)
                                .font(.subheadline).italic().padding().background(Color.crimson.opacity(0.1)).cornerRadius(10)

                            ForEach(recommendation.music) { song in
                                if let url = URL(string: song.appleMusicURL) {
                                    Link(destination: url) {
                                        HStack(spacing: 12) {
                                            // NEW: Album Artwork Display
                                            if let artURL = song.artworkURL {
                                                AsyncImage(url: artURL) { phase in
                                                    if let image = phase.image {
                                                        image.resizable().scaledToFill()
                                                    } else {
                                                        Color.secondary.opacity(0.2)
                                                    }
                                                }
                                                .frame(width: 50, height: 50)
                                                .cornerRadius(8)
                                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.secondary.opacity(0.2))
                                                    .frame(width: 50, height: 50)
                                                    .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                                            }
                                            
                                            VStack(alignment: .leading) {
                                                Text(song.title).bold().foregroundColor(.primary)
                                                Text(song.artist).font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "play.circle.fill").foregroundColor(.crimson).font(.title3)
                                        }
                                        .padding(10)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("HO:AN")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: HistoryCalendarView(historyManager: historyManager)) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundColor(.crimson)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
            }
            .onChange(of: selectedItem) { _ in
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        selectedImage = UIImage(data: data)
                    }
                }
            }
        }
        .accentColor(.crimson)
    }

    func analyze() {
        guard let img = selectedImage else { return }
        isLoading = true
        errorMessage = nil
        recommendation = nil
        
        Task {
            do {
                let tags = [tag1, tag2].filter { !$0.isEmpty }
                let result = try await geminiService.analyzeMoodAndGetSongs(from: img, hashtags: tags)
                await MainActor.run {
                    self.recommendation = result
                    self.historyManager.addRecord(recommendation: result, image: img, hashtags: tags)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - History Calendar View
struct HistoryCalendarView: View {
    @ObservedObject var historyManager: HistoryManager
    @State private var selectedDate = Date()
    @State private var isCalendarExpanded = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                DisclosureGroup(
                    isExpanded: $isCalendarExpanded,
                    content: {
                        CustomCalendarGrid(selectedDate: $selectedDate, historyManager: historyManager)
                            .padding(.vertical)
                    },
                    label: {
                        Text(selectedDate.formatted(date: .long, time: .omitted))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                )
                .tint(.crimson)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding()
                
                Divider()
                
                let dailyRecords = historyManager.records(for: selectedDate)
                
                if dailyRecords.isEmpty {
                    Text("해당 날짜에 검색된 음악이 없습니다.")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(dailyRecords, id: \.id) { record in
                            HistoryRecordRow(record: record, historyManager: historyManager)
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("검색 히스토리")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Individual History Row
struct HistoryRecordRow: View {
    let record: HistoryRecord
    @ObservedObject var historyManager: HistoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            HStack(alignment: .top, spacing: 16) {
                if let filename = record.imageFileName,
                   let uiImage = historyManager.loadImage(fileName: filename) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.recommendation.mood)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.primary)
                    
                    if !record.hashtags.isEmpty {
                        HStack {
                            ForEach(record.hashtags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.crimson)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.crimson.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Text(record.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(record.recommendation.music) { song in
                    if let url = URL(string: song.appleMusicURL) {
                        Link(destination: url) {
                            HStack(spacing: 12) {
                                // NEW: Album Artwork Display for History
                                if let artURL = song.artworkURL {
                                    AsyncImage(url: artURL) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            Color.secondary.opacity(0.2)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(6)
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                        .overlay(Image(systemName: "music.note").font(.caption).foregroundColor(.secondary))
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(song.title).bold().foregroundColor(.primary)
                                    Text(song.artist).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill").foregroundColor(.crimson).font(.title3)
                            }
                            .padding(10)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Custom Calendar Grid
struct CustomCalendarGrid: View {
    @Binding var selectedDate: Date
    @ObservedObject var historyManager: HistoryManager
    
    let daysOfWeek = ["일", "월", "화", "수", "목", "금", "토"]
    
    var body: some View {
        VStack {
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            
            let days = getDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        let records = historyManager.records(for: date)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        
                        ZStack {
                            if let firstRecord = records.first,
                               let filename = firstRecord.imageFileName,
                               let uiImage = historyManager.loadImage(fileName: filename) {
                                
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? Color.crimson : Color.clear, lineWidth: 3)
                                    )
                                    .overlay(
                                        Text("\(Calendar.current.component(.day, from: date))")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                                    )
                                
                            } else {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 16))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .frame(width: 40, height: 40)
                                    .background(isSelected ? Color.crimson : Color.clear)
                                    .clipShape(Circle())
                            }
                        }
                        .onTapGesture {
                            withAnimation {
                                selectedDate = date
                            }
                        }
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                }
            }
        }
    }
    
    private func getDaysInMonth() -> [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        
        let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        let start = monthFirstWeek?.start ?? monthInterval.start
        
        var dates: [Date?] = []
        var currentDate = start
        
        while currentDate < monthInterval.end {
            if calendar.isDate(currentDate, equalTo: Date(), toGranularity: .month) {
                dates.append(currentDate)
            } else {
                dates.append(nil)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        return dates
    }
}

// MARK: - Camera Integration Bridge
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
    }
}
