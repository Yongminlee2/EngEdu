// 세로 녹화 영상(1206×2622)을 폭 600 으로 줄인다 — 심사 회신 첨부용. ffmpeg 이 없어 AVFoundation 으로.
//   swift resize-video.swift <입력.mp4> <출력.mp4> [폭=600]
import AVFoundation

let args = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let out = URL(fileURLWithPath: args[2])
let targetW = args.count > 3 ? Double(args[3])! : 600
try? FileManager.default.removeItem(at: out)
let sem = DispatchSemaphore(value: 0)
Task {
    let track = try await asset.loadTracks(withMediaType: .video)[0]
    let size = try await track.load(.naturalSize)
    let duration = try await asset.load(.duration)
    let scale = targetW / size.width
    let render = CGSize(width: (size.width * scale).rounded(.down) / 2 * 2, height: (size.height * scale).rounded(.down) / 2 * 2)
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    layer.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: .zero)
    let inst = AVMutableVideoCompositionInstruction()
    inst.timeRange = CMTimeRange(start: .zero, duration: duration)
    inst.layerInstructions = [layer]
    let comp = AVMutableVideoComposition()
    comp.renderSize = render
    comp.frameDuration = CMTime(value: 1, timescale: 30)
    comp.instructions = [inst]
    let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality)!
    ex.videoComposition = comp
    ex.outputURL = out
    ex.outputFileType = .mp4
    await ex.export()
    print(ex.status == .completed ? "ok \(render) \(duration.seconds)s" : "fail \(String(describing: ex.error))")
    sem.signal()
}
sem.wait()
