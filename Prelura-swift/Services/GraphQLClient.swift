import Foundation

class GraphQLClient {
    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    
    init(baseURL: String = Constants.graphQLBaseURL) {
        self.baseURL = URL(string: baseURL)!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.apiTimeout
        config.timeoutIntervalForResource = Constants.apiTimeout
        self.session = URLSession(configuration: config)
    }
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    var hasAuthToken: Bool {
        authToken != nil
    }
    
    func execute<T: Decodable>(
        query: String,
        variables: [String: Any]? = nil,
        operationName: String? = nil,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = ["query": query]
        if let variables = variables {
            body["variables"] = variables
        }
        if let operationName = operationName {
            body["operationName"] = operationName
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GraphQLError.networkError("Invalid response")
        }
        
        // Decode body first so we can surface GraphQL errors even when status is 4xx (e.g. 400)
        let graphQLResponse: GraphQLResponse<T>
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            graphQLResponse = try decoder.decode(GraphQLResponse<T>.self, from: data)
        } catch {
            if !(200...299).contains(httpResponse.statusCode) {
                throw GraphQLError.httpError(httpResponse.statusCode)
            }
            throw GraphQLError.decodingError(error)
        }
        
        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GraphQLError.graphQLErrors(errors)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw GraphQLError.httpError(httpResponse.statusCode)
        }
        
        guard let responseData = graphQLResponse.data else {
            throw GraphQLError.noData
        }
        
        return responseData
    }
    
    /// Execute and decode with a custom decoder (e.g. for requests that need different key strategy).
    func execute<T: Decodable>(
        query: String,
        variables: [String: Any]? = nil,
        operationName: String? = nil,
        responseType: T.Type,
        decoder: JSONDecoder
    ) async throws -> T {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body: [String: Any] = ["query": query]
        if let variables = variables { body["variables"] = variables }
        if let operationName = operationName { body["operationName"] = operationName }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GraphQLError.networkError("Invalid response")
        }
        let graphQLResponse: GraphQLResponse<T>
        do {
            graphQLResponse = try decoder.decode(GraphQLResponse<T>.self, from: data)
        } catch {
            if !(200...299).contains(httpResponse.statusCode) {
                throw GraphQLError.httpError(httpResponse.statusCode)
            }
            throw GraphQLError.decodingError(error)
        }
        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GraphQLError.graphQLErrors(errors)
        }
        if !(200...299).contains(httpResponse.statusCode) {
            throw GraphQLError.httpError(httpResponse.statusCode)
        }
        guard let responseData = graphQLResponse.data else {
            throw GraphQLError.noData
        }
        return responseData
    }
}

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLErrorResponse]?
}

struct GraphQLErrorResponse: Decodable {
    let message: String
    let locations: [Location]?
    let path: [String]?
    
    struct Location: Decodable {
        let line: Int
        let column: Int
    }
}

enum GraphQLError: Error, LocalizedError {
    case networkError(String)
    case httpError(Int)
    case graphQLErrors([GraphQLErrorResponse])
    case noData
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .graphQLErrors(let errors):
            return errors.first?.message ?? "GraphQL error"
        case .noData:
            return "No data returned"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
