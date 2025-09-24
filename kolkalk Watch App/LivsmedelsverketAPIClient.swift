import Foundation

struct LivsmedelsverketAPIClient {
    struct APIError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // Valfri API-nyckel om din prenumeration kräver det (Ocp-Apim-Subscription-Key)
    var subscriptionKey: String? = nil

    // MARK: - DTOs
    struct SearchResponse: Decodable {
        let livsmedel: [FoodSummaryDTO]?
        let _meta: MetaDTO?
        let _links: [LinkDTO]?
    }

    struct MetaDTO: Decodable {
        let totalRecords: Int?
        let offset: Int?
        let limit: Int?
        let count: Int?
    }

    struct FoodSummaryDTO: Decodable {
        let nummer: Int?
        let namn: String?
        let links: [LinkDTO]?
    }

    struct LinkDTO: Decodable {
        let href: String?
        let rel: String?
        let method: String?
    }

    // Närings-svar kan vara top-level array eller wrapper-objekt
    struct NutrientsResponse: Decodable {
        let naringsvarden: [NutrientDTO]

        enum CodingKeys: String, CodingKey {
            case naringsvarden
            case naringsvarde
        }

        init(from decoder: Decoder) throws {
            if let arr = try? decoder.singleValueContainer().decode([NutrientDTO].self) {
                naringsvarden = arr
                return
            }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let arr = try c.decodeIfPresent([NutrientDTO].self, forKey: .naringsvarden) {
                naringsvarden = arr
            } else if let arr = try c.decodeIfPresent([NutrientDTO].self, forKey: .naringsvarde) {
                naringsvarden = arr
            } else {
                naringsvarden = []
            }
        }
    }

    struct NutrientDTO: Decodable {
        let namn: String?
        let varde: Double?
        let enhet: String?

        enum CodingKeys: String, CodingKey {
            case namn
            case varde
            case enhet
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            namn = try c.decodeIfPresent(String.self, forKey: .namn)
            enhet = try c.decodeIfPresent(String.self, forKey: .enhet)

            if let number = try? c.decodeIfPresent(Double.self, forKey: .varde) {
                varde = number
            } else if let str = try? c.decodeIfPresent(String.self, forKey: .varde) {
                varde = Double(str.replacingOccurrences(of: ",", with: "."))
            } else {
                varde = nil
            }
        }
    }

    // MARK: - Hjälpfunktioner
    private func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    // Poäng: 0=ingen träff, 1=substr i ord, 2=ord==query, 3=ord börjar med query, 4=hela namnet börjar med query
    private func relevanceScore(name: String, query: String) -> Int {
        let nName = normalize(name)
        let nQuery = normalize(query)
        guard !nQuery.isEmpty else { return 0 }
        guard nName.contains(nQuery) else { return 0 }

        let separators = CharacterSet.letters.inverted
        let tokens = nName.components(separatedBy: separators).filter { !$0.isEmpty }

        var score = 1
        var foundExact = false
        var foundPrefix = false

        for t in tokens {
            if t == nQuery { foundExact = true }
            if t.hasPrefix(nQuery) { foundPrefix = true }
        }

        if foundExact { score = max(score, 2) }
        if foundPrefix { score = max(score, 3) }
        if nName.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(nQuery) {
            score = max(score, 4)
        }

        return score
    }

    // MARK: - Publik sök
    // Skannar igenom fler sidor (offset/limit) tills vi har gott om matchningar, rankar och kompletterar med kolhydrater/100 g.
    func searchFoods(query: String, limit: Int = 25, page: Int = 0) async throws -> [FoodItem] {
        let debug = true

        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }

        // Vi vill gärna ha 150–250 matchningar att ranka på för att efterlikna webbens upplevda resultatordning.
        let targetMatches = max(150, limit * 6)
        let perPage = 100 // prova 100 per sida för färre anrop (servern verkar defaulta till 20 men accepterar ofta 100)
        var offset = 0
        var totalRecords: Int? = nil

        var seenNumbers = Set<Int>()
        var seenNames = Set<String>()
        var collected: [FoodSummaryDTO] = []

        var lastPageFingerprint: String? = nil
        var pageCounter = 0
        let maxPagesHardCap = 200 // säkerhetsgräns (200 * 100 = 20k, långt över 2569)

        while (collected.count < targetMatches) && (pageCounter < maxPagesHardCap) {
            let page = try await fetchSearchPage(offset: offset, limit: perPage)

            if totalRecords == nil { totalRecords = page.totalRecords }
            if debug {
                let examples = page.items.prefix(8).compactMap { $0.namn }.joined(separator: " | ")
                print("SLV Search offset \(offset): \(page.items.count) items. Examples: \(examples)")
            }

            // Fingerprint för att bryta om identiska sidor (defensivt)
            let fp = page.items.map { "\($0.nummer ?? -1)|\($0.namn ?? "")" }.joined(separator: "#")
            if let last = lastPageFingerprint, last == fp {
                if debug { print("SLV: Page at offset \(offset) identical to previous page. Stopping pagination.") }
                break
            }
            lastPageFingerprint = fp

            // Klientfilter: behåll bara poster som matchar query (score > 0)
            for s in page.items {
                let name = (s.namn ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                let score = relevanceScore(name: name, query: term)
                guard score > 0 else { continue }

                if let n = s.nummer {
                    if seenNumbers.contains(n) { continue }
                    seenNumbers.insert(n)
                    collected.append(s)
                } else {
                    let key = normalize(name)
                    if key.isEmpty || seenNames.contains(key) { continue }
                    seenNames.insert(key)
                    collected.append(s)
                }

                if collected.count >= targetMatches { break }
            }

            // Avsluta om vi nått slutet
            let metaOffset = page.meta.offset ?? offset
            let metaLimit = page.meta.limit ?? perPage
            let metaCount = page.meta.count ?? page.items.count
            let metaTotal = page.meta.totalRecords ?? totalRecords ?? 0

            offset = metaOffset + metaLimit
            pageCounter += 1

            if metaCount == 0 || offset >= metaTotal {
                if debug { print("SLV: Reached end of dataset at offset \(offset) / total \(metaTotal).") }
                break
            }
        }

        if debug {
            print("SLV Collected matches: \(collected.count) (target \(targetMatches)).")
        }

        // Ranka och ta bort svaga substring-träffar om starka finns
        let rankedTuples: [(FoodSummaryDTO, Int)] = collected
            .compactMap { s -> (FoodSummaryDTO, Int)? in
                let name = (s.namn ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                let score = relevanceScore(name: name, query: term)
                return score > 0 ? (s, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                let ln = (lhs.0.namn ?? "")
                let rn = (rhs.0.namn ?? "")
                return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending
            }

        let hasStrong = rankedTuples.contains(where: { $0.1 >= 2 })
        let filteredRanked = hasStrong ? rankedTuples.filter { $0.1 >= 2 } : rankedTuples

        if debug {
            let topNames = filteredRanked.prefix(10).compactMap { $0.0.namn }
            print("SLV Ranked top 10: \(topNames)")
        }

        let topSummaries = filteredRanked.prefix(limit).map { $0.0 }

        // Hämta kolhydrater för topplistan parallellt
        var results: [FoodItem] = []
        results.reserveCapacity(topSummaries.count)

        await withTaskGroup(of: FoodItem?.self) { group in
            for summary in topSummaries {
                group.addTask {
                    let name = (summary.namn ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return nil }

                    var carbs: Double? = nil
                    if let nummer = summary.nummer {
                        carbs = try? await fetchCarbsPer100g(for: nummer, language: 1)
                    }

                    return FoodItem(
                        name: name,
                        carbsPer100g: carbs,
                        grams: 0,
                        gramsPerDl: nil,
                        styckPerGram: nil,
                        inputUnit: nil,
                        isDefault: false,
                        hasBeenLogged: false,
                        isFavorite: false,
                        isCalculatorItem: false
                    )
                }
            }

            for await item in group {
                if let item { results.append(item) }
            }
        }

        // Slutlig sortering i samma relevansordning som topSummaries
        var orderMap: [String: Int] = [:]
        for (idx, s) in topSummaries.enumerated() {
            let key = (s.namn ?? "").lowercased()
            if orderMap[key] == nil { orderMap[key] = idx }
        }

        return results.sorted {
            let i0 = orderMap[$0.name.lowercased()] ?? Int.max
            let i1 = orderMap[$1.name.lowercased()] ?? Int.max
            if i0 != i1 { return i0 < i1 }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - En sida (offset/limit) + meta
    private struct SearchPage {
        let items: [FoodSummaryDTO]
        let meta: MetaDTO
        let totalRecords: Int
    }

    // Servern använder offset/limit. Parametern "namn" verkar inte påverka, men vi skickar med sprak=1.
    private func fetchSearchPage(offset: Int, limit: Int) async throws -> SearchPage {
        let base = "https://dataportal.livsmedelsverket.se/livsmedel/api/v1/livsmedel"
        var components = URLComponents(string: base)!
        components.queryItems = [
            URLQueryItem(name: "sprak", value: "1"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components.url else { throw APIError(message: "Ogiltig URL.") }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let subscriptionKey {
            request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        }

        #if DEBUG
        print("SLV fetchSearchPage URL: \(url.absoluteString)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "Inget giltigt HTTP-svar.") }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(800) ?? "<binär data>"
            throw APIError(message: "HTTP \(http.statusCode) för \(url.absoluteString)\nSvar: \(snippet)")
        }

        #if DEBUG
        if let snippet = String(data: data, encoding: .utf8)?.prefix(300) {
            print("SLV fetchSearchPage response snippet: \(snippet)")
        }
        #endif

        let decoder = JSONDecoder()
        let wrapped = try decoder.decode(SearchResponse.self, from: data)
        let items = wrapped.livsmedel ?? []
        let meta = wrapped._meta ?? MetaDTO(totalRecords: nil, offset: nil, limit: nil, count: nil)
        let total = meta.totalRecords ?? items.count
        return SearchPage(items: items, meta: meta, totalRecords: total)
    }

    // MARK: - Hämta kolhydrater per 100 g för ett visst livsmedelsnummer
    func fetchCarbsPer100g(for nummer: Int, language: Int = 1) async throws -> Double? {
        let base = "https://dataportal.livsmedelsverket.se/livsmedel/api/v1/livsmedel/\(nummer)/naringsvarden"
        var components = URLComponents(string: base)!
        components.queryItems = [
            URLQueryItem(name: "sprak", value: String(language))
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let subscriptionKey {
            request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)?.prefix(500) ?? "<binär>"
            print("fetchCarbsPer100g HTTP \(http.statusCode) for \(url.absoluteString). Body: \(body)")
            return nil
        }

        let decoder = JSONDecoder()
        let nutrients = try? decoder.decode(NutrientsResponse.self, from: data)

        let carbNameCandidates = [
            "kolhydrat",
            "kolhydrater",
            "kolhydrater, tillgängliga",
            "kolhydrater totalt",
            "kolhydrat (g)",
            "kolhydrater (g)",
            "kolhydrat, totalt",
            "kolhydrater totalt (g/100g)"
        ]

        let carbValue = nutrients?.naringsvarden
            .first(where: { nutrient in
                let n = (nutrient.namn ?? "")
                return carbNameCandidates.contains(where: { cand in
                    n.localizedCaseInsensitiveContains(cand)
                })
            })?
            .varde

        return carbValue
    }

    // Hjälpmetod för felsökning – hämta ett kort textutdrag av närings-JSON
    private func fetchNutrientsRawSnippet(for nummer: Int, language: Int = 1) async throws -> String {
        let base = "https://dataportal.livsmedelsverket.se/livsmedel/api/v1/livsmedel/\(nummer)/naringsvarden"
        var components = URLComponents(string: base)!
        components.queryItems = [
            URLQueryItem(name: "sprak", value: String(language))
        ]
        guard let url = components.url else { return "<invalid url>" }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let subscriptionKey {
            request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            return "<no http response>"
        }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8)?.prefix(800) ?? "<binär>"
            return "<http \(http.statusCode)> \(url.absoluteString)\n\(body)"
        }
        return String(data: data, encoding: .utf8)?.prefix(1000).description ?? "<binary>"
    }
}
