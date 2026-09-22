/// Builds the set of sources the app runs with.
///
/// This is the one place that imports concrete site types. Everything else
/// resolves a source through `SourceRegistry` by its identifier, which is what
/// keeps site churn from leaking across the app.
///
/// Every source is handed the same `HTTPClient`, so they share one concurrency
/// budget per host rather than each building its own and doubling what a site
/// sees.
///
/// No plugin exists yet; the first one registers here.
public func liveSources(http: HTTPClient) -> [any Source] {
    []
}
