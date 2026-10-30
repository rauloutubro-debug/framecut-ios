import SwiftUI
import AVKit
import UniformTypeIdentifiers
import Photos

@main struct FrameCutApp: App {
    @StateObject private var store = ProjectStore()
    var body: some Scene {
        WindowGroup { HomeView().environmentObject(store).preferredColorScheme(.dark).tint(.cyan) }
    }
}
struct HomeView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var editor: EditProject?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Sua próxima história começa aqui.").font(.largeTitle.bold())
                    Button { editor = EditProject() } label: {
                        HStack { Image(systemName: "plus.square.fill").font(.largeTitle); VStack(alignment: .leading) { Text("Novo projeto").font(.title2.bold()); Text("Importe vídeos e comece a criar").font(.subheadline) }; Spacer(); Image(systemName: "arrow.up.right") }
                            .foregroundStyle(.black).padding(24).background(.cyan.gradient, in: RoundedRectangle(cornerRadius: 24))
                    }
                    HStack { Text("Seus projetos").font(.title2.bold()); Spacer(); Text("\(store.projects.count)").foregroundStyle(.secondary) }
                    if store.projects.isEmpty { ContentUnavailableView("Tudo pronto para criar", systemImage: "film.stack", description: Text("Os projetos são salvos neste dispositivo.")) }
                    ForEach(store.projects) { project in
                        HStack {
                            Button { editor = project } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "film").font(.title).frame(width: 64, height: 72).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading) { Text(project.name).font(.headline); Text("\(project.clips.count) clipes · \(project.duration, specifier: "%.1f") s").font(.caption).foregroundStyle(.secondary); Text(project.updated, style: .date).font(.caption2).foregroundStyle(.secondary) }
                                    Spacer()
                                }
                            }.buttonStyle(.plain)
                            Menu { Button("Excluir projeto", role: .destructive) { store.delete(project) } } label: { Image(systemName: "ellipsis").padding() }
                        }
                    }
                }.padding(24)
            }.navigationTitle("FrameCut")
        }
        .sheet(item: $editor) { EditorView(project: $0).environmentObject(store) }
        .alert("Biblioteca", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
    }
}
struct EditorView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) var dismiss
    @State var project: EditProject
    @State private var importer = false
    @State private var busy = false
    @State private var message: String?
    @State private var player = AVPlayer()
    @State private var output: URL?
    @State private var selected: UUID?
    @State private var previewTask: Task<Void, Never>?
    private var selectedIndex: Int? { project.clips.firstIndex { $0.id == selected } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    GeometryReader { geometry in
                        let scale = geometry.size.width / 1080
                        ZStack(alignment: .topLeading) {
                            VideoPlayer(player: player).frame(width: geometry.size.width, height: geometry.size.height)
                            if !project.title.isEmpty {
                                Text(project.title).font(.system(size: 60 * scale)).multilineTextAlignment(.center)
                                    .frame(width: 960 * scale, height: 220 * scale, alignment: .top)
                                    .background(.black.opacity(0.65))
                                    .position(x: 540 * scale, y: 1590 * scale).allowsHitTesting(false)
                            }
                        }
                    }.aspectRatio(9.0 / 16, contentMode: .fit).frame(maxWidth: 240).clipShape(RoundedRectangle(cornerRadius: 16))
                    HStack {
                        Label("\(project.duration, specifier: "%.1f") s", systemImage: "clock")
                        Spacer(); Text("9:16 · 1080p · 30 fps").foregroundStyle(.secondary)
                    }.font(.caption)
                    HStack {
                        Text("Linha do tempo").font(.headline); Spacer()
                        Button { importer = true } label: { Label("Adicionar", systemImage: "plus") }.disabled(busy)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(project.clips) { clip in
                                Button { selected = clip.id } label: {
                                    VStack { Image(systemName: clip.muted ? "speaker.slash.fill" : "film.fill"); Text("\(clip.length, specifier: "%.1f") s").font(.caption.monospacedDigit()) }
                                        .frame(width: 86, height: 68).background(selected == clip.id ? Color.cyan.opacity(0.25) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected == clip.id ? .cyan : .clear, lineWidth: 2))
                                }.buttonStyle(.plain)
                            }
                        }.padding(3)
                    }
                    if let i = selectedIndex {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cortar clipe").font(.headline)
                            Text("Início: \(project.clips[i].start, specifier: "%.2f") s").font(.caption)
                            Slider(value: $project.clips[i].start, in: 0...max(0.001, project.clips[i].end - 0.05), onEditingChanged: { if !$0 { refresh() } })
                            Text("Fim: \(project.clips[i].end, specifier: "%.2f") s").font(.caption)
                            Slider(value: $project.clips[i].end, in: min(project.clips[i].duration, project.clips[i].start + 0.05)...project.clips[i].duration, onEditingChanged: { if !$0 { refresh() } })
                            Toggle("Silenciar áudio original", isOn: $project.clips[i].muted).onChange(of: project.clips[i].muted) { refresh() }
                            HStack {
                                Button { move(i, by: -1) } label: { Image(systemName: "arrow.left") }.disabled(i == 0)
                                Button { move(i, by: 1) } label: { Image(systemName: "arrow.right") }.disabled(i == project.clips.count - 1)
                                Spacer()
                                Button("Dividir") { split(i) }
                                Button("Remover", role: .destructive) { project.clips.remove(at: i); selected = project.clips.first?.id; refresh() }
                            }
                        }.padding().background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16)).disabled(busy)
                    }
                    TextField("Nome do projeto", text: $project.name).textFieldStyle(.roundedBorder).disabled(busy)
                    TextField("Texto sobre o vídeo (até 120 caracteres)", text: $project.title, axis: .vertical).textFieldStyle(.roundedBorder)
                        .onChange(of: project.title) { project.title = String(project.title.prefix(120)); output = nil; store.save(project) }.disabled(busy)
                    if busy { ProgressView("Processando vídeo…") }
                    if let output {
                        ShareLink(item: output) { Label("Compartilhar MP4", systemImage: "square.and.arrow.up") }
                        Button("Salvar em Fotos") { Task { await saveToPhotos(output) } }.disabled(busy)
                    }
                }.padding()
            }
            .navigationTitle("Editar projeto").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Concluir") { store.save(project); dismiss() }.disabled(busy) }
                ToolbarItem(placement: .primaryAction) { Button("Exportar") { Task { await export() } }.disabled(project.clips.isEmpty || busy) }
            }
            .fileImporter(isPresented: $importer, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
                Task {
                    busy = true; defer { busy = false }
                    do {
                        for url in try result.get() { let clip = try await Library.importMovie(url); project.clips.append(clip); selected = clip.id }
                    } catch { message = error.localizedDescription }
                    refresh()
                }
            }
            .alert("FrameCut", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
            .onAppear { selected = project.clips.first?.id; refresh() }
            .onDisappear { previewTask?.cancel(); player.pause(); store.save(project) }
            .interactiveDismissDisabled(busy)
        }
    }
    private func split(_ index: Int) {
        let original = project.clips[index]
        guard original.length >= 0.1 else { return }
        let midpoint = (original.start + original.end) / 2
        var second = original; second.id = UUID(); second.start = midpoint
        project.clips[index].end = midpoint
        project.clips.insert(second, at: index + 1); selected = second.id; refresh()
    }
    private func move(_ index: Int, by offset: Int) { project.clips.swapAt(index, index + offset); refresh() }
    private func refresh() {
        store.save(project); output = nil; previewTask?.cancel()
        let snapshot = project
        previewTask = Task {
            do {
                if snapshot.clips.isEmpty { player.replaceCurrentItem(with: nil); return }
                let result = try await RenderEngine.assemble(snapshot, burnTitle: false)
                try Task.checkCancellation()
                let item = AVPlayerItem(asset: result.composition); item.videoComposition = result.video
                player.replaceCurrentItem(with: item)
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }
    private func export() async {
        busy = true; player.pause(); store.save(project); defer { busy = false }
        do { output = try await RenderEngine.export(project) } catch { message = error.localizedDescription }
    }
    private func saveToPhotos(_ url: URL) async {
        busy = true; defer { busy = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { message = "Autorize o acesso a Fotos nos Ajustes para salvar o vídeo."; return }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }
            message = "Vídeo salvo em Fotos."
        } catch { message = error.localizedDescription }
    }
}
