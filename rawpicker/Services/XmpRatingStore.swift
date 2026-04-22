import Foundation

enum XmpRatingStore {
    static let defaultRating = 0
    static let favoriteRating = 5
    private static let xmlOptions: XMLNode.Options = [.nodeLoadExternalEntitiesNever]

    static func rating(for asset: RawAsset) -> Int {
        guard let document = try? XMLDocument(contentsOf: sidecarURL(for: asset), options: xmlOptions) else {
            return defaultRating
        }

        if let attributeValue = try? document.nodes(forXPath: "//*[local-name()='Description']/@*[local-name()='Rating']").first?.stringValue,
           let rating = normalizedRating(attributeValue) {
            return rating
        }

        if let elementValue = try? document.nodes(forXPath: "//*[local-name()='Rating']").first?.stringValue,
           let rating = normalizedRating(elementValue) {
            return rating
        }

        return defaultRating
    }

    static func setRating(_ rating: Int, for asset: RawAsset) throws {
        let clampedRating = min(max(rating, 0), favoriteRating)
        let sidecar = sidecarURL(for: asset)
        let document = try documentForWriting(sidecarURL: sidecar)
        let description = try descriptionElement(in: document)

        description.removeAttribute(forName: "xmp:Rating")
        description.addAttribute(XMLNode.attribute(withName: "xmp:Rating", stringValue: "\(clampedRating)") as! XMLNode)

        let data = document.xmlData(options: [.nodePrettyPrint])
        try data.write(to: sidecar, options: .atomic)
    }

    private static func sidecarURL(for asset: RawAsset) -> URL {
        asset.url.deletingPathExtension().appendingPathExtension("xmp")
    }

    private static func normalizedRating(_ value: String?) -> Int? {
        guard let value,
              let rating = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              (0...favoriteRating).contains(rating)
        else { return nil }

        return rating
    }

    private static func documentForWriting(sidecarURL: URL) throws -> XMLDocument {
        if FileManager.default.fileExists(atPath: sidecarURL.path) {
            return try XMLDocument(contentsOf: sidecarURL, options: xmlOptions)
        }

        let xml = """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/"/>
          </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """

        return try XMLDocument(xmlString: xml, options: xmlOptions)
    }

    private static func descriptionElement(in document: XMLDocument) throws -> XMLElement {
        if let existing = try document.nodes(forXPath: "//*[local-name()='Description']").first as? XMLElement {
            ensureXmpNamespace(on: existing)
            return existing
        }

        let root = document.rootElement() ?? XMLElement(name: "x:xmpmeta")
        if document.rootElement() == nil {
            root.addNamespace(XMLNode.namespace(withName: "x", stringValue: "adobe:ns:meta/") as! XMLNode)
            document.setRootElement(root)
        }

        let rdf = XMLElement(name: "rdf:RDF")
        rdf.addNamespace(XMLNode.namespace(withName: "rdf", stringValue: "http://www.w3.org/1999/02/22-rdf-syntax-ns#") as! XMLNode)
        root.addChild(rdf)

        let description = XMLElement(name: "rdf:Description")
        description.addAttribute(XMLNode.attribute(withName: "rdf:about", stringValue: "") as! XMLNode)
        ensureXmpNamespace(on: description)
        rdf.addChild(description)
        return description
    }

    private static func ensureXmpNamespace(on element: XMLElement) {
        guard element.namespaces?.contains(where: { $0.name == "xmp" }) != true else { return }
        element.addNamespace(XMLNode.namespace(withName: "xmp", stringValue: "http://ns.adobe.com/xap/1.0/") as! XMLNode)
    }
}
