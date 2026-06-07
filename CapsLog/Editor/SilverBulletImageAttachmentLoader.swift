import Foundation
import ImageIO
import Textual

struct SilverBulletImageAttachmentLoader: AttachmentLoader {
    let client: SilverBulletClient
    let pagePath: String

    func attachment(
        for url: URL,
        text: String,
        environment: ColorEnvironmentValues
    ) async throws -> SilverBulletImageAttachment {
        let data: Data

        if url.scheme == "http" || url.scheme == "https" {
            (data, _) = try await URLSession.shared.data(from: url)
        } else {
            let isAbsolute = url.scheme == "capslog"
            let reference = isAbsolute
                ? SilverBulletMarkdownRenderer.pageReference(from: url)
                : url.relativeString

            guard let reference,
                  let path = SilverBulletMarkdownRenderer.resolveDocumentPath(
                    reference: reference,
                    from: pagePath,
                    isAbsolute: isAbsolute
                  ) else {
                throw SilverBulletImageError.invalidReference
            }

            data = try await client.read(path: path).data
        }

        guard let imageSize = imageSize(from: data) else {
            throw SilverBulletImageError.invalidImage
        }

        return SilverBulletImageAttachment(
            data: data,
            text: text,
            imageSize: imageSize
        )
    }

    private func imageSize(from data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                nil
              ) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        return CGSize(width: width, height: height)
    }
}
