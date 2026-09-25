import Foundation
import Nuke

/// Adds the site's required referer to image requests from its observed CDN.
/// This loader sits under the shared pipeline, covering covers and prefetches.
struct ImageRequestPolicy: DataLoading {
    let base: any DataLoading

    static func prepared(_ request: URLRequest) -> URLRequest {
        guard request.url?.host()?.lowercased() == "cdn.readdetectiveconan.com" else {
            return request
        }
        var request = request
        request.setValue("https://mangapill.com/", forHTTPHeaderField: "Referer")
        return request
    }

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) -> any Cancellable {
        base.loadData(
            with: Self.prepared(request),
            didReceiveData: didReceiveData,
            completion: completion)
    }
}

func configureImagePipeline() {
    var configuration = ImagePipeline.Configuration.withURLCache
    configuration.dataLoader = ImageRequestPolicy(base: configuration.dataLoader)
    ImagePipeline.shared = ImagePipeline(configuration: configuration)
}
