//
//  OCRService.swift
//  WXL
//
//  OCR text recognition service using Vision framework
//

import Vision
import AppKit
import Combine
import os.log

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// 识别图片中的文字
    /// - Parameter imageData: 图片数据
    /// - Returns: 识别出的文字
    @discardableResult
    func recognizeText(in imageData: Data, completion: @escaping (String?) -> Void) -> String? {
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return nil
        }

        return recognizeText(in: cgImage, completion: completion)
    }

    /// 识别图片中的文字
    /// - Parameter cgImage: CGImage
    /// - Returns: 识别出的文字
    @discardableResult
    func recognizeText(in cgImage: CGImage, completion: @escaping (String?) -> Void) -> String? {
        var recognizedText: String?

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(nil)
                return
            }

            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            recognizedText = text.isEmpty ? nil : text
            completion(recognizedText)
        }

        // 配置识别参数
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en", "ja", "ko"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            Logger.error("OCR error: \(error)", category: .general)
            completion(nil)
            return nil
        }

        return recognizedText
    }

    /// 异步识别图片中的文字
    func recognizeTextAsync(in imageData: Data) async -> String? {
        return await withCheckedContinuation { continuation in
            recognizeText(in: imageData) { text in
                continuation.resume(returning: text)
            }
        }
    }

    /// 检测图片中是否包含特定文字
    func containsText(_ searchText: String, in imageData: Data) -> Bool {
        guard let text = recognizeText(in: imageData, completion: { _ in }) else {
            return false
        }
        return text.localizedCaseInsensitiveContains(searchText)
    }
}

// MARK: - OCR Result Cache
class OCRCache {
    static let shared = OCRCache()
    private var cache = NSCache<NSString, NSString>()

    private init() {
        cache.countLimit = 100
    }

    func get(for id: UUID) -> String? {
        return cache.object(forKey: id.uuidString as NSString) as String?
    }

    func set(_ text: String, for id: UUID) {
        cache.setObject(text as NSString, forKey: id.uuidString as NSString)
    }

    func remove(for id: UUID) {
        cache.removeObject(forKey: id.uuidString as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}
