import Foundation

struct SearchResponse: Codable {
    let count: Int
    let result: [SearchResult]
}

struct SearchResult: Codable {
    let description: String
    let displaySymbol: String
    let symbol: String
    let type: String
}

struct SearchDisplay: Identifiable, Hashable {
    let id: String
    let displaySymbol: String
    let symbol: String
    let type: String
}

struct FinancialNewsResponse: Codable, Hashable {
    let category: String
    let datetime: TimeInterval
    let headline: String
    let id: Int
    let image: String
    let related: String
    let source: String
    let summary: String
    let url: String
}

struct AnalysisResponse: Codable {
    struct TechnicalAnalysis: Codable {
        struct Count: Codable {
            let buy: Int
            let neutral: Int
            let sell: Int
        }
        
        let count: Count
        let signal: String
    }
    
    struct Trend: Codable {
        let adx: Double
        let trending: Bool
    }
    
    let technicalAnalysis: TechnicalAnalysis
    let trend: Trend
}

struct MarketDataResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case close = "c"
        case high = "h"
        case low = "l"
        case open = "o"
        case status = "s"
        case timestamps = "t"
    }
    
    let close: [Double]
    let high: [Double]
    let low: [Double]
    let open: [Double]
    let status: String
    let timestamps: [TimeInterval]
    
    var candleSticks: [CandleStick] {
        var result = [CandleStick]()
        
        for index in 0 ..< open.count {
            result.append(.init(
                date: timestamps[index],
                high: high[index],
                low: low[index],
                open: open[index],
                close: close[index]
            ))
        }
        
        let sortedData = result.sorted { $0.date < $1.date }
        
        return sortedData
    }
}

struct CandleStick {
    let date: Double
    let high: Double
    let low: Double
    let open: Double
    let close: Double
}

struct FinancialMetricsResponse: Codable {
    let metric: Metrics
}

struct Metrics: Codable {
    let TenDayAverageTradingVolume: Float
    let AnnualWeekHigh: Double
    let AnnualWeekLow: Double
    let AnnualWeekLowDate: String
    let AnnualWeekPriceReturnDaily: Float
    let beta: Float
    
    enum CodingKeys: String, CodingKey {
        case TenDayAverageTradingVolume = "10DayAverageTradingVolume"
        case AnnualWeekHigh = "52WeekHigh"
        case AnnualWeekLow = "52WeekLow"
        case AnnualWeekLowDate = "52WeekLowDate"
        case AnnualWeekPriceReturnDaily = "52WeekPriceReturnDaily"
        case beta = "beta"
    }
}

struct MarketStatus: Codable {
    let exchange: String
    let holiday: String?
    let isOpen: Bool
    let session: String?
    let t: Int
    let timezone: String
}
