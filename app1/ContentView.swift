//
//  ContentView.swift
//  app1
//
//  Created by Steven Edward Harrington on 3/29/26.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation
import UIKit

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let content: String
}

struct SavedBook: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let rawText: String
    let importedAt: Date

    init(id: UUID = UUID(), title: String, rawText: String, importedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.rawText = rawText
        self.importedAt = importedAt
    }
}

struct ReaderPage: Identifiable, Hashable {
    let id = UUID()
    let chapterTitle: String
    let content: String
    let pageIndex: Int
    let pageCount: Int
}

private enum ReaderTheme: Int, CaseIterable, Identifiable {
    case paper
    case sepia
    case dark
    case forest
    case nightBlue

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .paper: return "纸张"
        case .sepia: return "护眼"
        case .dark: return "夜间"
        case .forest: return "森林"
        case .nightBlue: return "深蓝"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .paper: return Color(.systemBackground)
        case .sepia: return Color(red: 0.96, green: 0.91, blue: 0.82)
        case .dark: return Color.black
        case .forest: return Color(red: 0.90, green: 0.96, blue: 0.90)
        case .nightBlue: return Color(red: 0.08, green: 0.12, blue: 0.20)
        }
    }

    var textColor: Color {
        switch self {
        case .paper, .sepia, .forest: return Color.primary
        case .dark, .nightBlue: return Color.white
        }
    }

    var chromeColor: Color {
        switch self {
        case .paper: return Color(.secondarySystemBackground)
        case .sepia: return Color(red: 0.90, green: 0.84, blue: 0.73)
        case .dark: return Color(.secondarySystemBackground)
        case .forest: return Color(red: 0.82, green: 0.91, blue: 0.82)
        case .nightBlue: return Color(red: 0.12, green: 0.17, blue: 0.28)
        }
    }
}

private enum ReaderFont: String, CaseIterable, Identifiable {
    case system = "系统"
    case rounded = "圆润"
    case serif = "衬线"
    case monospaced = "等宽"
    case songti = "宋体"
    case kaiti = "楷体"

    var id: String { rawValue }

    var title: String { rawValue }

    func font(size: Double, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: weight)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .monospaced:
            return .system(size: size, weight: weight, design: .monospaced)
        case .songti:
            return .custom("Songti SC", size: size)
        case .kaiti:
            return .custom("Kaiti SC", size: size)
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("reader.fontSize") private var fontSize: Double = 20
    @AppStorage("reader.lineSpacing") private var lineSpacing: Double = 10
    @AppStorage("reader.horizontalPadding") private var horizontalPadding: Double = 20
    @AppStorage("reader.theme") private var themeRawValue: Int = ReaderTheme.paper.rawValue
    @AppStorage("reader.fontName") private var fontName: String = ReaderFont.system.rawValue
    @AppStorage("reader.useBackgroundTexture") private var useBackgroundTexture: Bool = true
    @AppStorage("reader.savedBooks") private var savedBooksData: Data = Data()
    @AppStorage("reader.lastBookID") private var lastBookID: String = ""
    @AppStorage("reader.isPagingMode") private var isPagingMode: Bool = true
    @AppStorage("reader.isImmersiveMode") private var isImmersiveMode: Bool = true
    @AppStorage("reader.totalReadingSeconds") private var totalReadingSeconds: Double = 0
    @AppStorage("reader.lastReadingDate") private var lastReadingDateText: String = ""
    @AppStorage("reader.currentBookReadingSeconds") private var currentBookReadingSeconds: Double = 0

    @State private var rawText: String = "请选择一个 TXT 小说文件"
    @State private var chapters: [Chapter] = []
    @State private var pages: [ReaderPage] = []
    @State private var selectedChapterIndex: Int = 0
    @State private var selectedPageIndex: Int = 0
    @State private var showImporter = false
    @State private var showChapterSheet = false
    @State private var showSettingsSheet = false
    @State private var showBookshelfSheet = false
    @State private var errorMessage: String?
    @State private var currentBookTitle: String = "未打开书籍"
    @State private var currentBookKey: String = "default"
    @State private var savedBooks: [SavedBook] = []
    @State private var showReaderControls: Bool = false
    @State private var bookshelfSearchText: String = ""
    @State private var isShowingLaunchScreen: Bool = true
    @State private var launchScreenOpacity: Double = 1
    @State private var readingTimer: Timer?
    @State private var currentSessionSeconds: Double = 0

    private var currentReaderFont: ReaderFont {
        ReaderFont(rawValue: fontName) ?? .system
    }

    private var currentTheme: ReaderTheme {
        ReaderTheme(rawValue: themeRawValue) ?? .paper
    }

    private var currentChapter: Chapter? {
        guard chapters.indices.contains(selectedChapterIndex) else { return nil }
        return chapters[selectedChapterIndex]
    }

    private var currentPage: ReaderPage? {
        guard pages.indices.contains(selectedPageIndex) else { return nil }
        return pages[selectedPageIndex]
    }

    private var filteredBooks: [SavedBook] {
        if bookshelfSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedBooks
        }
        return savedBooks.filter {
            $0.title.localizedCaseInsensitiveContains(bookshelfSearchText)
                || $0.rawText.localizedCaseInsensitiveContains(bookshelfSearchText)
        }
    }

    private var chapterProgressText: String {
        if isPagingMode {
            guard !pages.isEmpty else { return "未分页" }
            return "第 \(selectedPageIndex + 1) / \(pages.count) 页"
        }
        guard !chapters.isEmpty else { return "未分章" }
        return "第 \(selectedChapterIndex + 1) / \(chapters.count) 章"
    }

    private var progressPercentText: String {
        if isPagingMode {
            guard !pages.isEmpty else { return "0%" }
            let percent = Int((Double(selectedPageIndex + 1) / Double(pages.count)) * 100)
            return "已读 \(percent)%"
        }
        guard !chapters.isEmpty else { return "0%" }
        let percent = Int((Double(selectedChapterIndex + 1) / Double(chapters.count)) * 100)
        return "已读 \(percent)%"
    }

    private var sceneIsReadable: Bool {
        !chapters.isEmpty || !pages.isEmpty
    }

    private var totalReadingTimeText: String {
        formatDuration(totalReadingSeconds + currentSessionSeconds)
    }

    private var currentBookReadingTimeText: String {
        let bookSeconds = currentBookKey == "default"
            ? currentSessionSeconds
            : currentBookReadingSeconds + currentSessionSeconds
        return formatDuration(bookSeconds)
    }

    private var lastReadingDateDisplayText: String {
        lastReadingDateText.isEmpty ? "暂无" : lastReadingDateText
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    if !isImmersiveMode || showReaderControls {
                        headerBar
                        Divider()
                    }

                    if isPagingMode {
                        pagedReadingArea
                    } else {
                        scrollingReadingArea
                    }

                    if !isImmersiveMode || showReaderControls {
                        Divider()
                        bottomToolbar
                    }
                }
                .background(backgroundLayer.ignoresSafeArea())
                .navigationTitle(currentBookTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: [UTType.plainText]
                ) { result in
                    switch result {
                    case .success(let url):
                        loadText(from: url)
                    case .failure(let error):
                        errorMessage = "读取失败：\(error.localizedDescription)"
                    }
                }
                .sheet(isPresented: $showChapterSheet) {
                    chapterListSheet
                        .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showSettingsSheet) {
                    settingsSheet
                        .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showBookshelfSheet) {
                    bookshelfSheet
                        .presentationDetents([.medium, .large])
                }
                .alert("提示", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("确定", role: .cancel) { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
                .onAppear {
                    loadSavedBooks()
                    restoreLastBookIfNeeded()
                    showReaderControls = !isImmersiveMode
                    startReadingTimerIfNeeded()

                    guard isShowingLaunchScreen else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        withAnimation(.easeOut(duration: 0.35)) {
                            launchScreenOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            isShowingLaunchScreen = false
                        }
                    }
                }
                .onChange(of: fontSize) { _ in
                    rebuildPagesKeepingProgress()
                }
                .onChange(of: lineSpacing) { _ in
                    rebuildPagesKeepingProgress()
                }
                .onChange(of: horizontalPadding) { _ in
                    rebuildPagesKeepingProgress()
                }
                .onChange(of: fontName) { _ in
                    rebuildPagesKeepingProgress()
                }
                .onChange(of: isImmersiveMode) { value in
                    showReaderControls = !value
                }
                .onDisappear {
                    stopReadingTimer()
                    saveReadingProgress()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        startReadingTimerIfNeeded()
                    } else {
                        stopReadingTimer()
                        saveReadingProgress()
                    }
                }
            }

            if isShowingLaunchScreen {
                launchScreenView
                    .opacity(launchScreenOpacity)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(currentTheme == .dark || currentTheme == .nightBlue ? .dark : .light)
    }

    private var launchScreenView: some View {
        ZStack {
            LinearGradient(
                colors: [currentTheme.backgroundColor, currentTheme.chromeColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(currentTheme.textColor.opacity(0.12))
                    .frame(width: 92, height: 92)
                    .overlay(
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(currentTheme.textColor)
                    )

                VStack(spacing: 8) {
                    Text("TXT Reader")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(currentTheme.textColor)

                    Text("本地阅读 · 自动分章 · 沉浸体验")
                        .font(.system(size: 15))
                        .foregroundStyle(currentTheme.textColor.opacity(0.75))
                }

                ProgressView()
                    .tint(currentTheme == .dark || currentTheme == .nightBlue ? .white : .accentColor)
                    .padding(.top, 6)
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [currentTheme.backgroundColor, currentTheme.chromeColor.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if useBackgroundTexture {
                VStack(spacing: 18) {
                    ForEach(0..<18, id: \.self) { row in
                        HStack(spacing: 18) {
                            ForEach(0..<10, id: \.self) { column in
                                Circle()
                                    .fill(currentTheme.textColor.opacity(((row + column).isMultiple(of: 2)) ? 0.025 : 0.012))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
            }
        }
    }

    private var headerBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentBookTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(currentTheme.textColor)

                    Text(currentPage?.chapterTitle ?? currentChapter?.title ?? "等待打开书籍")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(currentTheme.textColor.opacity(0.7))
                }

                Spacer()

                Button {
                    showBookshelfSheet = true
                } label: {
                    Image(systemName: "books.vertical")
                        .font(.title3)
                }

                Button {
                    showChapterSheet = true
                } label: {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.title3)
                }
                .disabled(chapters.isEmpty)

                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.title3)
                }

                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "folder")
                        .font(.title3)
                }
            }
            .foregroundStyle(currentTheme.textColor)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(chapterProgressText)
                    Spacer()
                    Text(progressPercentText)
                }
                .font(.caption)
                .foregroundStyle(currentTheme.textColor.opacity(0.72))

                ProgressView(value: progressValue, total: progressTotal)
                    .tint(currentTheme == .dark || currentTheme == .nightBlue ? .white : .accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(currentTheme.chromeColor)
    }

    private var pagedReadingArea: some View {
        Group {
            if pages.isEmpty {
                emptyStateView
            } else {
                GeometryReader { geometry in
                    TabView(selection: $selectedPageIndex) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            VStack(alignment: .leading, spacing: 18) {
                                Text(page.chapterTitle)
                                    .font(currentReaderFont.font(size: max(fontSize + 4, 22), weight: .bold))
                                    .foregroundStyle(currentTheme.textColor)
                                    .lineLimit(1)

                                Text(page.content)
                                    .font(currentReaderFont.font(size: fontSize))
                                    .foregroundStyle(currentTheme.textColor)
                                    .lineSpacing(lineSpacing)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                                HStack {
                                    Text("第 \(page.pageIndex + 1) / \(page.pageCount) 页")
                                    Spacer()
                                    Text(progressPercentText)
                                }
                                .font(.caption)
                                .foregroundStyle(currentTheme.textColor.opacity(0.7))
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, showReaderControls || !isImmersiveMode ? 24 : geometry.safeAreaInsets.top + 16)
                            .padding(.bottom, showReaderControls || !isImmersiveMode ? 20 : max(34, geometry.safeAreaInsets.bottom + 12))
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let width = geometry.size.width
                                let leftZone = width * 0.3
                                let rightZone = width * 0.7

                                if location.x < leftZone {
                                    goPrevious()
                                } else if location.x > rightZone {
                                    goNext()
                                } else {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showReaderControls.toggle()
                                    }
                                }
                            }
                            .background(currentTheme.backgroundColor)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .background(currentTheme.backgroundColor)
                    .onChange(of: selectedPageIndex) { _ in
                        syncChapterIndexWithPage()
                        saveReadingProgress()
                    }
                }
            }
        }
    }

    private var scrollingReadingArea: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear
                            .frame(height: 1)
                            .id("topAnchor")

                        if let currentChapter {
                            Text(currentChapter.title)
                                .font(currentReaderFont.font(size: max(fontSize + 5, 22), weight: .bold))
                                .foregroundStyle(currentTheme.textColor)

                            Text(formattedContent(currentChapter.content))
                                .font(currentReaderFont.font(size: fontSize))
                                .foregroundStyle(currentTheme.textColor)
                                .lineSpacing(lineSpacing)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        } else {
                            emptyStateView
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, showReaderControls || !isImmersiveMode ? 20 : geometry.safeAreaInsets.top + 16)
                    .padding(.bottom, showReaderControls || !isImmersiveMode ? 20 : max(34, geometry.safeAreaInsets.bottom + 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showReaderControls.toggle()
                    }
                }
                .background(currentTheme.backgroundColor)
                .onChange(of: selectedChapterIndex) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo("topAnchor", anchor: .top)
                    }
                    saveReadingProgress()
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("导入你的第一本小说")
                .font(currentReaderFont.font(size: 30, weight: .bold))
                .foregroundStyle(currentTheme.textColor)

            Text("支持 TXT 文件 · 自动分章 · 本地阅读")
                .font(currentReaderFont.font(size: max(fontSize - 1, 16)))
                .foregroundStyle(currentTheme.textColor.opacity(0.8))

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "folder", title: "导入本地 TXT", subtitle: "从“文件”App中选择你的小说文件")
                featureRow(icon: "list.bullet.rectangle.portrait", title: "自动分章", subtitle: "识别常见章节标题，快速跳转阅读")
                featureRow(icon: "books.vertical", title: "书架管理", subtitle: "自动保存导入记录和阅读进度")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 24)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(currentTheme.textColor.opacity(0.10))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(currentTheme.textColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(currentReaderFont.font(size: 17, weight: .semibold))
                    .foregroundStyle(currentTheme.textColor)
                Text(subtitle)
                    .font(currentReaderFont.font(size: 14))
                    .foregroundStyle(currentTheme.textColor.opacity(0.72))
                    .lineSpacing(3)
            }

            Spacer()
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 10) {
            Button {
                goPrevious()
            } label: {
                Label(isPagingMode ? "上一页" : "上一章", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canGoPrevious)

            Button {
                showChapterSheet = true
            } label: {
                Label("目录", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(chapters.isEmpty)

            Button {
                showBookshelfSheet = true
            } label: {
                Label("书架", systemImage: "books.vertical")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                goNext()
            } label: {
                Label(isPagingMode ? "下一页" : "下一章", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canGoNext)
        }
        .padding(16)
        .background(currentTheme.chromeColor)
    }

    private var chapterListSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                    Button {
                        selectedChapterIndex = index
                        if isPagingMode {
                            selectedPageIndex = firstPageIndex(forChapterAt: index)
                        }
                        saveReadingProgress()
                        showChapterSheet = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .foregroundStyle(.primary)
                                Text(chapterPreview(for: chapter.content))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if index == selectedChapterIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("章节目录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var bookshelfSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索书名或正文", text: $bookshelfSearchText)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

                if filteredBooks.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(savedBooks.isEmpty ? "书架还是空的，先导入一本 TXT 小说吧。" : "没有找到匹配的书。")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredBooks) { book in
                                Button {
                                    openSavedBook(book)
                                    showBookshelfSheet = false
                                } label: {
                                    HStack(spacing: 14) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(LinearGradient(colors: [currentTheme.chromeColor, currentTheme.backgroundColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 56, height: 76)
                                            .overlay(
                                                Text(String(book.title.prefix(2)))
                                                    .font(.headline)
                                                    .foregroundColor(currentTheme.textColor)
                                            )

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(book.title)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(bookPreview(for: book.rawText))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }

                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteSavedBook(book)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("我的书架")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("阅读外观")) {
                    Picker("主题", selection: $themeRawValue) {
                        ForEach(ReaderTheme.allCases) { theme in
                            Text(theme.title).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("字体", selection: $fontName) {
                        ForEach(ReaderFont.allCases) { font in
                            Text(font.title).tag(font.rawValue)
                        }
                    }

                    Toggle("背景纹理", isOn: $useBackgroundTexture)
                    Toggle("真翻页模式", isOn: $isPagingMode)
                    Toggle("沉浸模式", isOn: $isImmersiveMode)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("字体大小")
                            Spacer()
                            Text("\(Int(fontSize))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $fontSize, in: 14...34, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("行距")
                            Spacer()
                            Text("\(Int(lineSpacing))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $lineSpacing, in: 4...22, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("页边距")
                            Spacer()
                            Text("\(Int(horizontalPadding))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $horizontalPadding, in: 12...36, step: 1)
                    }
                }

                Section(header: Text("当前书籍")) {
                    HStack {
                        Text("书名")
                        Spacer()
                        Text(currentBookTitle)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack {
                        Text("阅读进度")
                        Spacer()
                        Text(chapterProgressText)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("完成度")
                        Spacer()
                        Text(progressPercentText)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("本书阅读时长")
                        Spacer()
                        Text(currentBookReadingTimeText)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("累计阅读时长")
                        Spacer()
                        Text(totalReadingTimeText)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("上次阅读")
                        Spacer()
                        Text(lastReadingDateDisplayText)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func startReadingTimerIfNeeded() {
        guard readingTimer == nil, sceneIsReadable else { return }
        readingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            currentSessionSeconds += 1
        }
    }

    private func stopReadingTimer() {
        readingTimer?.invalidate()
        readingTimer = nil

        guard currentSessionSeconds > 0 else { return }

        totalReadingSeconds += currentSessionSeconds
        if currentBookKey != "default" {
            currentBookReadingSeconds += currentSessionSeconds
        }
        lastReadingDateText = Self.readingDateFormatter.string(from: Date())
        currentSessionSeconds = 0

        if currentBookKey != "default" {
            UserDefaults.standard.set(currentBookReadingSeconds, forKey: "reader.book.seconds.\(currentBookKey)")
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainingSeconds = total % 60

        if hours > 0 {
            return String(format: "%d小时%02d分", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d分%02d秒", minutes, remainingSeconds)
        } else {
            return "\(remainingSeconds)秒"
        }
    }

    private static let readingDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private var progressValue: Double {
        if isPagingMode {
            return pages.isEmpty ? 0 : Double(selectedPageIndex + 1)
        }
        return chapters.isEmpty ? 0 : Double(selectedChapterIndex + 1)
    }

    private var progressTotal: Double {
        if isPagingMode {
            return pages.isEmpty ? 1 : Double(pages.count)
        }
        return chapters.isEmpty ? 1 : Double(chapters.count)
    }

    private var canGoPrevious: Bool {
        if isPagingMode {
            return selectedPageIndex > 0
        }
        return selectedChapterIndex > 0
    }

    private var canGoNext: Bool {
        if isPagingMode {
            return selectedPageIndex < pages.count - 1
        }
        return selectedChapterIndex < chapters.count - 1
    }

    private func goPrevious() {
        if isPagingMode {
            guard selectedPageIndex > 0 else { return }
            selectedPageIndex -= 1
        } else {
            guard selectedChapterIndex > 0 else { return }
            selectedChapterIndex -= 1
        }
    }

    private func goNext() {
        if isPagingMode {
            guard selectedPageIndex < pages.count - 1 else { return }
            selectedPageIndex += 1
        } else {
            guard selectedChapterIndex < chapters.count - 1 else { return }
            selectedChapterIndex += 1
        }
    }

    private func loadText(from url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            var coordinatedError: NSError?
            var fileData: Data?

            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatedError) { readableURL in
                fileData = try? Data(contentsOf: readableURL)
            }

            if let coordinatedError {
                throw coordinatedError
            }

            guard let data = fileData else {
                throw NSError(
                    domain: "TXTReader",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "无法读取所选文件，请先把文件下载到“文件”App中的本地位置后再试。"]
                )
            }

            let decodedText =
                String(data: data, encoding: .utf8) ??
                String(data: data, encoding: .unicode) ??
                String(data: data, encoding: .ascii)

            guard let decodedText else {
                errorMessage = "无法识别这个 TXT 文件的编码。先试试 UTF-8 编码的小说文件。"
                return
            }

            let bookTitle = url.deletingPathExtension().lastPathComponent
            openBook(title: bookTitle, rawText: decodedText, saveIntoShelf: true)
        } catch {
            errorMessage = "读取文件出错：\(error.localizedDescription)"
        }
    }

    private func openBook(title: String, rawText: String, saveIntoShelf: Bool) {
        stopReadingTimer()
        saveReadingProgress()
        currentBookTitle = title
        currentBookKey = sanitizedKey(for: title)
        currentBookReadingSeconds = UserDefaults.standard.double(forKey: "reader.book.seconds.\(currentBookKey)")
        self.rawText = rawText
        chapters = parseChapters(from: rawText)
        pages = buildPages(from: chapters)

        let savedPageIndex = UserDefaults.standard.integer(forKey: "reader.progress.page.\(currentBookKey)")
        let savedChapterIndex = UserDefaults.standard.integer(forKey: "reader.progress.chapter.\(currentBookKey)")

        if pages.indices.contains(savedPageIndex) {
            selectedPageIndex = savedPageIndex
            syncChapterIndexWithPage()
        } else if chapters.indices.contains(savedChapterIndex) {
            selectedChapterIndex = savedChapterIndex
            selectedPageIndex = firstPageIndex(forChapterAt: savedChapterIndex)
        } else {
            selectedChapterIndex = 0
            selectedPageIndex = 0
        }

        lastBookID = currentBookKey
        if saveIntoShelf {
            saveBookToShelf(title: title, rawText: rawText)
        }
        saveReadingProgress()
        startReadingTimerIfNeeded()
    }

    private func parseChapters(from text: String) -> [Chapter] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let pattern = "(?m)^(第[0-9零一二三四五六七八九十百千两]+[章回节卷部篇].*)$"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [Chapter(title: "全文", content: normalized)]
        }

        let nsText = normalized as NSString
        let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else {
            return [Chapter(title: "全文", content: normalized)]
        }

        var result: [Chapter] = []

        for index in matches.indices {
            let titleRange = matches[index].range(at: 1)
            let title = nsText.substring(with: titleRange).trimmingCharacters(in: .whitespacesAndNewlines)

            let contentStart = titleRange.location
            let contentEnd: Int = index + 1 < matches.count ? matches[index + 1].range.location : nsText.length
            let chapterRange = NSRange(location: contentStart, length: contentEnd - contentStart)
            let chapterContent = nsText.substring(with: chapterRange).trimmingCharacters(in: .whitespacesAndNewlines)

            result.append(Chapter(title: title, content: chapterContent))
        }

        return result.isEmpty ? [Chapter(title: "全文", content: normalized)] : result
    }

    private func buildPages(from chapters: [Chapter]) -> [ReaderPage] {
        let estimatedCapacity = max(
            140,
            Int((7200 / max(fontSize, 14)) + (horizontalPadding * 1.2) - (lineSpacing * 14))
        )
        var result: [ReaderPage] = []

        for chapter in chapters {
            let chunks = splitIntoPages(text: formattedContent(chapter.content), pageSize: estimatedCapacity)
            for (index, chunk) in chunks.enumerated() {
                result.append(
                    ReaderPage(
                        chapterTitle: chapter.title,
                        content: chunk,
                        pageIndex: index,
                        pageCount: chunks.count
                    )
                )
            }
        }

        return result
    }

    private func splitIntoPages(text: String, pageSize: Int) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.count > pageSize else {
            return [normalized]
        }

        var pages: [String] = []
        var currentIndex = normalized.startIndex

        while currentIndex < normalized.endIndex {
            let tentativeEnd = normalized.index(currentIndex, offsetBy: pageSize, limitedBy: normalized.endIndex) ?? normalized.endIndex
            var pageEnd = tentativeEnd

            if tentativeEnd < normalized.endIndex {
                let searchRange = currentIndex..<tentativeEnd
                if let lastBreak = normalized[searchRange].lastIndex(where: { $0 == "\n" || $0 == "。" || $0 == "！" || $0 == "？" || $0 == "；" }) {
                    pageEnd = normalized.index(after: lastBreak)
                }
            }

            let pageText = String(normalized[currentIndex..<pageEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !pageText.isEmpty {
                pages.append(pageText)
            }
            currentIndex = pageEnd
        }

        return pages.isEmpty ? [normalized] : pages
    }

    private func formattedContent(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    private func chapterPreview(for content: String) -> String {
        let compact = content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? "暂无内容预览" : String(compact.prefix(30))
    }

    private func bookPreview(for content: String) -> String {
        let compact = content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? "暂无内容预览" : String(compact.prefix(60))
    }

    private func sanitizedKey(for text: String) -> String {
        text.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
    }

    private func saveReadingProgress() {
        UserDefaults.standard.set(selectedChapterIndex, forKey: "reader.progress.chapter.\(currentBookKey)")
        UserDefaults.standard.set(selectedPageIndex, forKey: "reader.progress.page.\(currentBookKey)")
        UserDefaults.standard.set(currentBookReadingSeconds + currentSessionSeconds, forKey: "reader.book.seconds.\(currentBookKey)")
        lastBookID = currentBookKey
    }

    private func syncChapterIndexWithPage() {
        guard pages.indices.contains(selectedPageIndex) else { return }
        let title = pages[selectedPageIndex].chapterTitle
        if let index = chapters.firstIndex(where: { $0.title == title }) {
            selectedChapterIndex = index
        }
    }

    private func firstPageIndex(forChapterAt chapterIndex: Int) -> Int {
        guard chapters.indices.contains(chapterIndex) else { return 0 }
        let title = chapters[chapterIndex].title
        return pages.firstIndex(where: { $0.chapterTitle == title }) ?? 0
    }

    private func rebuildPagesKeepingProgress() {
        guard !chapters.isEmpty else { return }
        let currentTitle = currentPage?.chapterTitle ?? currentChapter?.title
        pages = buildPages(from: chapters)
        if let currentTitle, let newIndex = pages.firstIndex(where: { $0.chapterTitle == currentTitle }) {
            selectedPageIndex = newIndex
        } else {
            selectedPageIndex = 0
        }
        syncChapterIndexWithPage()
        saveReadingProgress()
    }

    private func saveBookToShelf(title: String, rawText: String) {
        let newBook = SavedBook(title: title, rawText: rawText)
        savedBooks.removeAll { $0.title == title }
        savedBooks.insert(newBook, at: 0)
        persistBookshelf()
    }

    private func openSavedBook(_ book: SavedBook) {
        openBook(title: book.title, rawText: book.rawText, saveIntoShelf: false)
    }

    private func deleteSavedBook(_ book: SavedBook) {
        savedBooks.removeAll { $0.id == book.id }
        UserDefaults.standard.removeObject(forKey: "reader.book.seconds.\(sanitizedKey(for: book.title))")
        persistBookshelf()
        if currentBookTitle == book.title {
            rawText = "请选择一个 TXT 小说文件"
            chapters = []
            pages = []
            selectedChapterIndex = 0
            selectedPageIndex = 0
            currentBookTitle = "未打开书籍"
            currentBookKey = "default"
            currentBookReadingSeconds = 0
        }
    }

    private func persistBookshelf() {
        if let encoded = try? JSONEncoder().encode(savedBooks) {
            savedBooksData = encoded
        }
    }

    private func loadSavedBooks() {
        guard !savedBooksData.isEmpty,
              let decoded = try? JSONDecoder().decode([SavedBook].self, from: savedBooksData) else {
            savedBooks = []
            return
        }
        savedBooks = decoded.sorted { $0.importedAt > $1.importedAt }
    }

    private func restoreLastBookIfNeeded() {
        guard currentBookTitle == "未打开书籍", !savedBooks.isEmpty else { return }
        if let matched = savedBooks.first(where: { sanitizedKey(for: $0.title) == lastBookID }) ?? savedBooks.first {
            openSavedBook(matched)
        }
    }
}

#Preview {
    ContentView()
}
