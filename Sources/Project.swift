import Foundation
import AVFoundation
import Combine

struct Clip: Identifiable, Codable, Equatable {
    var id = UUID()
    var filename: String
    var duration: Double
    var start: Double = 0
    var end: Double
    var muted = false
    var length: Double { max(0, end - start) }
    var url: URL { Library.media.appendingPathComponent(filename) }
}
struct EditProject: Identifiable, Codable {
    var id = UUID()
    var name = "Meu projeto"
    var clips: [Clip] = []
    var title = ""
    var updated = Date()
    var duration: Double { clips.reduce(0) { $0 + $1.length } }
}
enum Library {
    static let root = URL.documentsDirectory.appendingPathComponent("FrameCut", isDirectory: true)
    static let media = root.appendingPathComponent("Media", isDirectory: true)
    static let projects = root.appendingPathComponent("projects.json")
    static func prepare() throws { try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true) }
    static func importMovie(_ url: URL) async throws -> Clip {
        try prepare()
        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        let filename = UUID().uuidString + "." + ext
        let target = media.appendingPathComponent(filename)
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: url, to: target)
            let asset = AVURLAsset(url: target)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let duration = try await asset.load(.duration).seconds
            guard let track = tracks.first, duration.isFinite, duration > 0.05 else { throw EditorError.invalidMedia }
            let range = try await track.load(.timeRange)
            let start = max(0, range.start.seconds)
            let end = min(duration, CMTimeRangeGetEnd(range).seconds)
            guard start.isFinite, end.isFinite, end - start >= 0.05 else { throw EditorError.invalidMedia }
            return Clip(filename: filename, duration: end, start: start, end: end)
        } catch { try? FileManager.default.removeItem(at: target); throw error }
    }
}
enum EditorError: LocalizedError {
    case invalidMedia, emptyProject, exportFailed
    var errorDescription: String? {
        switch self {
        case .invalidMedia: return "Não foi possível ler o vídeo. Escolha um arquivo de vídeo válido."
        case .emptyProject: return "Adicione pelo menos um clipe."
        case .exportFailed: return "A exportação não pôde ser concluída."
        }
    }
}
@MainActor final class ProjectStore: ObservableObject {
    @Published var projects: [EditProject] = []
    @Published var error: String?
    init() {
        do {
            try Library.prepare()
            if FileManager.default.fileExists(atPath: Library.projects.path) {
                projects = try JSONDecoder().decode([EditProject].self, from: Data(contentsOf: Library.projects))
            }
        } catch { self.error = error.localizedDescription }
    }
    func save(_ project: EditProject) {
        var updated = project; updated.updated = Date()
        if let index = projects.firstIndex(where: { $0.id == project.id }) { projects[index] = updated }
        else { projects.insert(updated, at: 0) }
        persist()
    }
    func delete(_ project: EditProject) {
        // Retain imported media so deleting a project cannot break another project.
        projects.removeAll { $0.id == project.id }; persist()
    }
    private func persist() {
        do { try JSONEncoder().encode(projects).write(to: Library.projects, options: .atomic) }
        catch { self.error = error.localizedDescription }
    }
}
