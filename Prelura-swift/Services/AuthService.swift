import Foundation
import Combine

@MainActor
class AuthService: ObservableObject {
    private let client: GraphQLClient
    @Published var authToken: String?
    @Published var refreshToken: String?
    @Published var username: String?
    
    init(client: GraphQLClient = GraphQLClient()) {
        self.client = client
        loadStoredTokens()
    }
    
    private func loadStoredTokens() {
        // Load from UserDefaults
        authToken = UserDefaults.standard.string(forKey: "AUTH_TOKEN")
        refreshToken = UserDefaults.standard.string(forKey: "REFRESH_TOKEN")
        username = UserDefaults.standard.string(forKey: "USERNAME")
        
        if let token = authToken {
            client.setAuthToken(token)
        }
    }
    
    private func storeTokens(token: String, refreshToken: String, username: String) {
        UserDefaults.standard.set(token, forKey: "AUTH_TOKEN")
        UserDefaults.standard.set(refreshToken, forKey: "REFRESH_TOKEN")
        UserDefaults.standard.set(username, forKey: "USERNAME")
        self.authToken = token
        self.refreshToken = refreshToken
        self.username = username
        client.setAuthToken(token)
    }
    
    func login(username: String, password: String) async throws -> LoginResponse {
        let query = """
        mutation Login($username: String!, $password: String!) {
          login(username: $username, password: $password) {
            token
            refreshToken
            user {
              id
              username
              email
            }
          }
        }
        """
        
        let variables: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        let response: LoginGraphQLResponse = try await client.execute(
            query: query,
            variables: variables,
            responseType: LoginGraphQLResponse.self
        )
        
        guard let loginData = response.login else {
            throw AuthError.invalidResponse
        }
        
        guard let token = loginData.token,
              let refreshToken = loginData.refreshToken else {
            throw AuthError.invalidResponse
        }
        
        storeTokens(
            token: token,
            refreshToken: refreshToken,
            username: loginData.user?.username ?? username
        )
        
        // Update other services with new token
        objectWillChange.send()
        
        return loginData
    }
    
    func register(
        email: String,
        firstName: String,
        lastName: String,
        username: String,
        password1: String,
        password2: String
    ) async throws -> RegisterResponse {
        let query = """
        mutation Register($email: String!, $firstName: String!, $lastName: String!, $username: String!, $password1: String!, $password2: String!) {
          register(
            email: $email
            firstName: $firstName
            lastName: $lastName
            username: $username
            password1: $password1
            password2: $password2
          ) {
            success
            errors
          }
        }
        """
        
        let variables: [String: Any] = [
            "email": email,
            "firstName": firstName,
            "lastName": lastName,
            "username": username,
            "password1": password1,
            "password2": password2
        ]
        
        let response: RegisterGraphQLResponse = try await client.execute(
            query: query,
            variables: variables,
            responseType: RegisterGraphQLResponse.self
        )
        
        guard let registerData = response.register else {
            throw AuthError.invalidResponse
        }
        
        if let errors = registerData.errors, !errors.isEmpty {
            // Extract first error message
            for (_, messages) in errors {
                if let firstMessage = messages.first {
                    throw AuthError.registrationError(firstMessage)
                }
            }
            throw AuthError.registrationError("Registration failed")
        }
        
        return registerData
    }
    
    func logout() async throws {
        // Call logout mutation if needed
        clearTokens()
    }
    
    private func clearTokens() {
        UserDefaults.standard.removeObject(forKey: "AUTH_TOKEN")
        UserDefaults.standard.removeObject(forKey: "REFRESH_TOKEN")
        UserDefaults.standard.removeObject(forKey: "USERNAME")
        authToken = nil
        refreshToken = nil
        username = nil
        client.setAuthToken(nil)
    }
    
    var isAuthenticated: Bool {
        authToken != nil
    }
}

// Response Models
struct LoginGraphQLResponse: Decodable {
    let login: LoginResponse?
}

struct RegisterGraphQLResponse: Decodable {
    let register: RegisterResponse?
}

struct LoginResponse: Decodable {
    let token: String?
    let refreshToken: String?
    let user: UserResponse?
}

struct UserResponse: Decodable {
    let id: String?
    let username: String?
    let email: String?
}

struct RegisterResponse: Decodable {
    let success: Bool?
    let errors: [String: [String]]?
}

enum AuthError: Error, LocalizedError {
    case invalidResponse
    case registrationError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .registrationError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
