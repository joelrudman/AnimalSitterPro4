import Foundation
import PDFKit
import UniformTypeIdentifiers

enum CVTextExtractor {

    struct ExtractionResult {
        var text: String?
        /// Set when the file type is supported for storage but not for text extraction
        /// (e.g. .doc/.docx), so matching will rely on manually-entered skills instead.
        var limitedExtractionNotice: String?
    }

    static func extractText(fromFileAt url: URL) -> ExtractionResult {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "pdf":
            guard let document = PDFDocument(url: url) else {
                return ExtractionResult(text: nil, limitedExtractionNotice: "Couldn't open this PDF for text extraction.")
            }
            var fullText = ""
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                if let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
            let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return ExtractionResult(text: nil, limitedExtractionNotice: "This PDF appears to be scanned/image-based, so no text could be extracted. Matching will use the skills you enter manually.")
            }
            return ExtractionResult(text: trimmed, limitedExtractionNotice: nil)

        case "txt":
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return ExtractionResult(text: text, limitedExtractionNotice: nil)
            }
            return ExtractionResult(text: nil, limitedExtractionNotice: "Couldn't read this text file.")

        case "rtf":
            if let data = try? Data(contentsOf: url),
               let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                return ExtractionResult(text: attributed.string, limitedExtractionNotice: nil)
            }
            return ExtractionResult(text: nil, limitedExtractionNotice: "Couldn't read this RTF file.")

        case "doc", "docx", "pages":
            return ExtractionResult(
                text: nil,
                limitedExtractionNotice: "Automatic text extraction isn't supported for .\(ext) files yet. The file will still be stored with the profile — for best match results, also add the candidate's key skills manually below, or upload a PDF/plain-text version of the CV."
            )

        default:
            return ExtractionResult(
                text: nil,
                limitedExtractionNotice: "Unrecognized file type for text extraction. The file will still be stored with the profile."
            )
        }
    }

    static var supportedContentTypes: [UTType] {
        [.pdf, .plainText, .rtf, UTType(filenameExtension: "docx") ?? .data, UTType(filenameExtension: "doc") ?? .data]
    }
}
