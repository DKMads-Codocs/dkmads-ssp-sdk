import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct APIHTTPResponse {
    let statusCode: Int
    let json: [String: Any]
    let rawBody: String
    let platformUid: String?
}

enum APIClientError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .httpError(let statusCode, let message): return "HTTP \(statusCode): \(message)"
        case .invalidResponse: return "Invalid server response"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    func request(
        endpoint: String,
        method: HTTPMethod,
        integrationKey: String,
        timeout: TimeInterval,
        debug: Bool,
        body: [String: Any],
        completion: @escaping (Result<APIHTTPResponse, Error>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(APIClientError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(integrationKey, forHTTPHeaderField: "X-Integration-Key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        if debug {
            let bodyPreview = (request.httpBody.flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"
            print("[DKMads SSP] POST \(url.absoluteString)")
            print("[DKMads SSP] Request body: \(bodyPreview)")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                if debug { print("[DKMads SSP] Network error: \(error.localizedDescription)") }
                completion(.failure(error))
                return
            }

            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? 0
            let rawBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            if debug {
                print("[DKMads SSP] Response HTTP \(statusCode): \(rawBody.prefix(2000))")
            }

            let trimmedBody = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
            let parsedObject = data.flatMap { try? JSONSerialization.jsonObject(with: $0, options: []) }
            let json = parsedObject as? [String: Any]

            if json == nil {
                let looksLikeHtml = trimmedBody.hasPrefix("<")
                    || trimmedBody.lowercased().hasPrefix("<!doctype")
                if looksLikeHtml {
                    let isVast = trimmedBody.lowercased().contains("<vast")
                    let hint = isVast
                        ? "Server returned VAST XML. Set response_format=json on the bid request (native SDKs require JSON)."
                        : "Server returned HTML, not JSON. Use API base URL https://ssp.dkmads.com (POST /api/public/v1/bid)."
                    completion(.failure(APIClientError.httpError(statusCode: statusCode, message: hint)))
                    return
                }
                completion(.failure(APIClientError.invalidResponse))
                return
            }

            if statusCode >= 400 {
                let message = (json?["error"] as? String)
                    ?? (json?["message"] as? String)
                    ?? rawBody
                completion(.failure(APIClientError.httpError(statusCode: statusCode, message: message)))
                return
            }

            let platformUid = http?.value(forHTTPHeaderField: "X-DKMads-Platform-Uid")
            PlatformIdentity.saveFromHeader(platformUid)
            completion(.success(APIHTTPResponse(
                statusCode: statusCode,
                json: json ?? [:],
                rawBody: rawBody,
                platformUid: platformUid
            )))
        }.resume()
    }
}
