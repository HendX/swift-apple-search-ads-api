import Foundation

/// The main object used to interface with the Apple Search Ads API.
public actor APIProvider {
    let configuration: APIConfiguration
    let accessTokenStore: AccessTokenStore
    let contextStore: ContextStore
    let provider: ProviderType

    /// Create an instance of `APIProvider`.
    ///
    /// - Parameters:
    ///     - configuration: API configuration parameters.
    ///     - backoffBehavior: Retry behavior for server errors (429, 500-599).
    ///                        Defaults to `.onRetryableError` (5 retries with exponential backoff).
    ///                        Use `.none` to disable retries, or `.onRetryableError(maxAttempts:)` to customize.
    public init(
        configuration: APIConfiguration,
        backoffBehavior: ExponentialBackoffBehavior = .onRetryableError
    ) {
        let accessTokenStore = AccessTokenStore(
            configuration: configuration,
            jwtAudience: "https://appleid.apple.com"
        )
        let contextStore = ContextStore(configuration: configuration) {
            try await accessTokenStore.token().model
        }
        let provider = Provider(
            baseURL: URL(string: "https://api.searchads.apple.com")!,
            session: configuration.session,
            plugins: [
                HostInjector(),
                AcceptHeadersInjector(),
                ContextInjector { try await contextStore.userACL().model },
                AuthorizationInjector { try await accessTokenStore.token().model }
            ],
            retryBehavior: .onUnauthorized(accessTokenStore),
            exponentialBackoffBehavior: backoffBehavior
        )
        self.configuration = configuration
        self.accessTokenStore = accessTokenStore
        self.contextStore = contextStore
        self.provider = provider
    }
}
