import AVFoundation
import UIKit

struct RenderResult { let composition: AVMutableComposition; let video: AVMutableVideoComposition }
enum RenderEngine {
    static func assemble(_ project: EditProject, burnTitle: Bool) async throws -> RenderResult {
        guard !project.clips.isEmpty else { throw EditorError.emptyProject }
        let composition = AVMutableComposition()
        let canvas = CGSize(width: 1080, height: 1920)
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var cursor = CMTime.zero
        for clip in project.clips {
            guard clip.start >= 0, clip.end <= clip.duration, clip.length > 0.01 else { throw EditorError.invalidMedia }
            let asset = AVURLAsset(url: clip.url)
            guard let source = try await asset.loadTracks(withMediaType: .video).first,
                  let destination = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw EditorError.invalidMedia }
            let range = CMTimeRange(start: CMTime(seconds: clip.start, preferredTimescale: 600), duration: CMTime(seconds: clip.length, preferredTimescale: 600))
            try destination.insertTimeRange(range, of: source, at: cursor)
            if !clip.muted, let audioSource = try await asset.loadTracks(withMediaType: .audio).first,
               let audioDestination = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let audioRange = try await audioSource.load(.timeRange)
                let intersection = CMTimeRangeGetIntersection(range, otherRange: audioRange)
                if intersection.duration.seconds > 0 {
                    try audioDestination.insertTimeRange(intersection, of: audioSource, at: cursor + intersection.start - range.start)
                }
            }
            let size = try await source.load(.naturalSize)
            let preferred = try await source.load(.preferredTransform)
            let rect = CGRect(origin: .zero, size: size).applying(preferred)
            guard rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0 else { throw EditorError.invalidMedia }
            let scale = min(canvas.width / rect.width, canvas.height / rect.height)
            var transform = preferred.concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
            transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
            transform = transform.concatenating(CGAffineTransform(translationX: (canvas.width - rect.width * scale) / 2, y: (canvas.height - rect.height * scale) / 2))
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: destination)
            layer.setTransform(transform, at: cursor)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: range.duration)
            instruction.layerInstructions = [layer]
            instruction.backgroundColor = UIColor.black.cgColor
            instructions.append(instruction)
            cursor = cursor + range.duration
        }
        let video = AVMutableVideoComposition()
        video.renderSize = canvas; video.frameDuration = CMTime(value: 1, timescale: 30)
        video.instructions = instructions
        if burnTitle && !project.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: canvas)
            let videoLayer = CALayer(); videoLayer.frame = parent.bounds; parent.addSublayer(videoLayer)
            let text = CATextLayer()
            text.string = project.title; text.fontSize = 60; text.alignmentMode = .center
            text.foregroundColor = UIColor.white.cgColor; text.backgroundColor = UIColor.black.withAlphaComponent(0.65).cgColor
            text.isWrapped = true; text.contentsScale = 2
            text.frame = CGRect(x: 60, y: 220, width: 960, height: 220)
            parent.addSublayer(text)
            video.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
        }
        return RenderResult(composition: composition, video: video)
    }
    static func export(_ project: EditProject) async throws -> URL {
        let result = try await assemble(project, burnTitle: true)
        guard let session = AVAssetExportSession(asset: result.composition, presetName: AVAssetExportPresetHighestQuality) else { throw EditorError.exportFailed }
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        session.outputURL = output; session.outputFileType = .mp4
        session.videoComposition = result.video; session.shouldOptimizeForNetworkUse = true
        await session.export()
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: output)
            throw session.error ?? EditorError.exportFailed
        }
        return output
    }
}
