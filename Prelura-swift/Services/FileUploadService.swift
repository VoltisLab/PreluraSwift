import Foundation

/// Uploads a single image via GraphQL UploadFile mutation (multipart request). Returns full URL and thumbnail URL for use in updateProfile(profilePicture:).
/// Matches Flutter FileUploadRepo + user_controller.updateProfilePicture (upload then updateProfile).
final class FileUploadService {
    private let graphQLURL: URL
    private let session: URLSession
    private var authToken: String?

    init(baseURL: String = Constants.graphQLBaseURL) {
        self.graphQLURL = URL(string: baseURL)!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.apiTimeout
        config.timeoutIntervalForResource = Constants.apiTimeout
        self.session = URLSession(configuration: config)
    }

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    /// Upload image data as PROFILE_PICTURE; returns (profilePictureUrl, thumbnailUrl) for updateProfile.
    func uploadProfileImage(_ imageData: Data) async throws -> (url: String, thumbnail: String) {
        let boundary = "----PreluraBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()

        let operations: [String: Any] = [
            "query": "mutation UploadFile($files: [Upload]!, $fileType: FileTypeEnum!) { upload(files: $files, filetype: $fileType) { baseUrl data } }",
            "variables": [
                "files": [NSNull()],
                "fileType": "PROFILE_PICTURE"
            ] as [String : Any]
        ]
        let operationsData = try JSONSerialization.data(withJSONObject: operations)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"operations\"\r\n\r\n".data(using: .utf8)!)
        body.append(operationsData)
        body.append("\r\n".data(using: .utf8)!)

        let map: [String: [String]] = ["0": ["variables.files.0"]]
        let mapData = try JSONSerialization.data(withJSONObject: map)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"map\"\r\n\r\n".data(using: .utf8)!)
        body.append(mapData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"0\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: graphQLURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "FileUploadService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed"])
        }

        struct UploadResponse: Decodable {
            let data: UploadData?
        }
        struct UploadData: Decodable {
            let upload: UploadResult?
        }
        struct UploadResult: Decodable {
            let baseUrl: String?
            let data: [String]?
        }

        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
        guard let upload = decoded.data?.upload,
              let baseUrl = upload.baseUrl, !baseUrl.isEmpty,
              let dataStrings = upload.data, !dataStrings.isEmpty,
              let first = dataStrings.first,
              let jsonData = first.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let imagePath = obj["image"] as? String,
              let thumbPath = obj["thumbnail"] as? String else {
            throw NSError(domain: "FileUploadService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid upload response"])
        }

        let fullUrl = baseUrl.hasSuffix("/") ? baseUrl + imagePath : baseUrl + "/" + imagePath
        let fullThumb = baseUrl.hasSuffix("/") ? baseUrl + thumbPath : baseUrl + "/" + thumbPath
        return (fullUrl, fullThumb)
    }
}
