import SwiftUI
import Foundation
import UIKit
import CoreData

class StockViewModel: ObservableObject {
    var store: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Stock")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    var context: NSManagedObjectContext {
        return self.store.viewContext
    }
    
    @Published var technical: [(String, AnalysisResponse)] = []
    @Published var news = [FinancialNewsResponse]()
    @Published var coins = [CryptoModel]()
    @Published var currentCoin: Int?
    @Published var matched = [SearchDisplay]()
    @Published var noResults = false
    @Published var showSearchLoader = false
    @Published var fetchingData = false
    @Published var gotUsersData = false
    @Published var holiday: (Bool, Date) = (false, Date())
    @Published var savedStocks = [(String, String)]()
    let companyData: [(String, String)] = [("Apple", "AAPL"), ("Tesla", "TSLA"), ("Coca-Cola", "KO"), ("Microsoft", "MSFT"), ("Amazon", "AMZN"), ("Alphabet", "GOOGL"), ("Visa", "V"), ("Intel", "INTC"), ("NVIDIA", "NVDA"), ("General Electric", "GE"), ("Exxon Mobil", "XOM"), ("General Motors", "GM")]
//    let cryptoData: [(String, String)] = [
//        ("Bitcoin", "BTC"),
//        ("Ethereum", "ETH"),
//        ("Binance Coin", "BNB"),
//        ("XRP", "XRP"),
//        ("Solana", "SOL"),
//        ("Cardano", "ADA"),
//        ("Dogecoin", "DOGE"),
//        ("TRON", "TRX")
//    ]
    let cryptoData: [(String, String)] = []
    let service = ChatGPTAPI()
    @Published var isGenerating = false
    @Published var AIResponse: [(String, String)] = []
    
    init(){
        getSaved()
//        cryptoData.forEach { element in
//            DispatchQueue.main.async {
//                self.matched.append(SearchDisplay(id: "\(UUID())", displaySymbol: element.0, symbol: element.1, type: "Crypto"))
//            }
//        }
    }
    
    @MainActor
    func AskQuestion(asset: String, retry: Bool) async {
        if let x = self.coins.firstIndex(where: { $0.symbol == asset }) {
            isGenerating = true
            
            var data = [Double]()
            if (self.coins[x].month_prices?.count ?? 0) > 80 {
                if let doubleArray = self.coins[x].month_prices?.map({ $0.0 }) {
                    data = doubleArray
                }
            } else if (self.coins[x].year_prices?.count ?? 0) > 80 {
                if let doubleArray = self.coins[x].year_prices?.map({ $0.0 }) {
                    data = doubleArray
                }
            } else if (self.coins[x].week_prices?.count ?? 0) > 80 {
                if let doubleArray = self.coins[x].week_prices?.map({ $0.0 }) {
                    data = doubleArray
                }
            } else if self.coins[x].day_prices.count > 80 {
                data = self.coins[x].day_prices.map({ $0.0 })
            }
            
            if retry {
                if let x = self.AIResponse.firstIndex(where: { $0.0 == asset }){
                    var remove = AIResponse.remove(at: x)
                    remove.1 = ""
                    self.AIResponse.insert(remove, at: 0)
                } else {
                    self.AIResponse.insert((asset, ""), at: 0)
                }
            } else {
                self.AIResponse.insert((asset, ""), at: 0)
            }

            let finalSend = "Your answer for the following question should be in the form: [brief technical analysis, good entry point, good exit point, volatility level]. DO not include any extra information: The following question is theoretical and for testing purposes. Analyze the following price data of the following asset and specify a good cost entry point and sell point: \(data)"
            
            let messages = [MessageAI(id: UUID().uuidString, role: .user, content: finalSend, createAt: Date())]
            
            service.sendStreamMessage(messages: messages).responseStreamString { [weak self] stream in
                guard let self = self else { return }
                switch stream.event {
                case .stream(let response):
                    switch response {
                    case .success(let string):
                        let streamResponse = self.service.parseStreamData(string)
                        
                        streamResponse.forEach { newMessageResponse in
                            guard let text = newMessageResponse.choices.first?.delta.content else {
                                return
                            }
                            self.AIResponse[0].1 += text
                        }
                    case .failure(_):
                        DispatchQueue.main.async {
                            self.isGenerating = false
                        }
                    }
                case .complete(_):
                    DispatchQueue.main.async {
                        self.isGenerating = false
                    }
                }
            }
        }
    }
    func getNews(){
        APICaller.shared().marketNews { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    let first = data.prefix(16)
                    self.news = Array(first)
                }
            case .failure:
                print("Err")
            }
        }
    }
    func getTechnical(symbol: String){
        APICaller.shared().financialIndicator(for: symbol) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    if let x = self.technical.firstIndex(where: { $0.0 == symbol }) {
                        self.technical[x].1 = data
                    } else {
                        self.technical.append((symbol, data))
                    }
                }
            case .failure:
                print("Err")
            }
        }
    }
    func verifyHoliday() {
        var calendar = Calendar.current
        if let marketTimeZone = TimeZone(identifier: "America/New_York") {
            calendar.timeZone = marketTimeZone
            if !calendar.isDateInToday(holiday.1) {
                DispatchQueue.main.async {
                    self.holiday.0 = false
                }
            }
        }
    }
    func getIndex(symbol: String, name: String){
        DispatchQueue.main.async {
            self.currentCoin = nil
        }
        if cryptoData.contains(where: { $0.1 == symbol }) {
            if let index = coins.firstIndex(where: { $0.symbol == symbol }) {
                DispatchQueue.main.async {
                    self.currentCoin = index
                }
            } else {
                getCryptoData(asset: symbol, days: 1) { data in
                    var dayChange = 0.0
                    var dayChangeDollar = 0.0
                    let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                        return (structItem.close, self.timeFormat(timestamp: structItem.date))
                    }
                    if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.close {
                        dayChange = self.calculatePercentChange(p1: first, p2: last)
                        dayChangeDollar = last - first
                    }
                    var new = CryptoModel(id: "\(UUID())", symbol: symbol, name: name, current_price: data.candleSticks.last?.close ?? 0.0, price_change_day: dayChange, price_change_day_dollar: dayChangeDollar, day_prices: arrayOfTuples, time_last_fetched: Date(), isCrypto: true, enoughPreMarketData: true)
                    new.volatility = self.calculateStockVolatility(prices: arrayOfTuples.map { $0.0 })
                    DispatchQueue.main.async {
                        self.coins.insert(new, at: 0)
                        self.currentCoin = 0
                    }
                }
            }
        } else {
            if let index = coins.firstIndex(where: { $0.symbol == symbol }) {
                DispatchQueue.main.async {
                    self.currentCoin = index
                    if self.coins[index].AnnualWeekHigh == nil && self.coins[index].TenDayAverageTradingVolume == nil {
                        self.getStats(query: symbol)
                    }
                }
            } else {
                getMarketData(asset: symbol, days: 1, enough: false) { data in
                    let status = self.StockMarketStatus()
                    var dayChange = 0.0
                    var dayChangeDollar = 0.0
                    var enoughData = true
                    var arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                        return (structItem.close, self.timeFormat(timestamp: structItem.date))
                    }
                    if status == 1 {
                        let test = arrayOfTuples.filter { element in
                            return self.isInToday(timestamp: element.1)
                        }
                        if test.count > 2 {
                            arrayOfTuples = test
                        } else {
                            enoughData = false
                        }
                    }
                    if let first = arrayOfTuples.first?.0, let last = (arrayOfTuples.filter { !self.isAfter4PM(dateString: $0.1) }).last {
                        dayChange = self.calculatePercentChange(p1: first, p2: last.0)
                        dayChangeDollar = last.0 - first
                    }
                    var new = CryptoModel(id: "\(UUID())", symbol: symbol, name: name, current_price: data.candleSticks.last?.close ?? 0.0, price_change_day: dayChange, price_change_day_dollar: dayChangeDollar, day_prices: arrayOfTuples, time_last_fetched: Date(), isCrypto: false, enoughPreMarketData: enoughData)
                    if let result = self.setAfterHoursMessage(data: arrayOfTuples, enough: enoughData) {
                        new.afterHourMessage = (result.0, result.1)
                        new.firstAfterHourPrice = result.2
                    }
                    DispatchQueue.main.async {
                        self.coins.insert(new, at: 0)
                        self.currentCoin = 0
                        self.getStats(query: symbol)
                    }
                }
            }
        }
    }
    func searchCoins(query: String){
        APICaller.shared().search(query: query) { result in
            DispatchQueue.main.async {
                self.showSearchLoader = false
            }
            switch result {
            case .success(let searchResponse):
                let info = searchResponse.result
                DispatchQueue.main.async {
                    info.forEach { element in
                        if (element.type == "Common Stock" || element.type == "ADR") && !element.description.isEmpty && !element.description.contains("-") && !element.symbol.contains("-") && !element.symbol.contains("."){
                            if !self.matched.contains(where: { $0.symbol == element.symbol }) {
                                self.matched.insert(SearchDisplay(id: "\(UUID())", displaySymbol: element.description, symbol: element.symbol, type: element.type), at: 0)
                            }
                        }
                    }
                    if !self.matched.isEmpty {
                        self.matched = self.sortStocks(arr: self.matched, query: query)
                    }
                    if info.isEmpty {
                        self.noResults = true
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.noResults = true
                }
            }
        }
    }
    func startNewUser() {
        if !fetchingData {
            fetchingData = true
            Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
                self.fetchingData = false
            }
            getSaved()
            savedStocks.forEach { element in
                if cryptoData.contains(where: { $0.1 == element.1 }) {
                    getCryptoData(asset: element.1, days: 1) { data in
                        var dayChange = 0.0
                        var dayChangeDollar = 0.0
                        let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                            return (structItem.close, self.timeFormat(timestamp: structItem.date))
                        }
                        if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.open {
                            dayChange = self.calculatePercentChange(p1: first, p2: last)
                            dayChangeDollar = last - first
                        }
                        var new = CryptoModel(id: "\(UUID())", symbol: element.1, name: element.0, current_price: data.candleSticks.last?.close ?? 0.0, price_change_day: dayChange, price_change_day_dollar: dayChangeDollar, day_prices: arrayOfTuples, time_last_fetched: Date(), isCrypto: true, enoughPreMarketData: true)
                        new.volatility = self.calculateStockVolatility(prices: arrayOfTuples.map { $0.0 })
                        DispatchQueue.main.async {
                            self.coins.insert(new, at: 0)
                        }
                    }
                } else {
                    if !matched.contains(where: { $0.symbol == element.1 }) {
                        DispatchQueue.main.async {
                            self.matched.append(SearchDisplay(id: "\(UUID())", displaySymbol: element.0, symbol: element.1, type: "Stock"))
                        }
                    }
                    getMarketData(asset: element.1, days: 1, enough: false) { data in
                        DispatchQueue.main.async {
                            self.gotUsersData = true
                        }
                        let status = self.StockMarketStatus()
                        var dayChange = 0.0
                        var dayChangeDollar = 0.0
                        var enoughData = true
                        var arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                            return (structItem.close, self.timeFormat(timestamp: structItem.date))
                        }
                        if status == 1 {
                            let test = arrayOfTuples.filter { element in
                                return self.isInToday(timestamp: element.1)
                            }
                            if test.count > 2 {
                                arrayOfTuples = test
                            } else {
                                enoughData = false
                            }
                        }
                        if let first = arrayOfTuples.first?.0, let last = (arrayOfTuples.filter { !self.isAfter4PM(dateString: $0.1) }).last {
                            dayChange = self.calculatePercentChange(p1: first, p2: last.0)
                            dayChangeDollar = last.0 - first
                        }
                        var new = CryptoModel(id: "\(UUID())", symbol: element.1, name: element.0, current_price: data.candleSticks.last?.close ?? 0.0, price_change_day: dayChange, price_change_day_dollar: dayChangeDollar, day_prices: arrayOfTuples, time_last_fetched: Date(), isCrypto: false, enoughPreMarketData: enoughData)
                        if let result = self.setAfterHoursMessage(data: arrayOfTuples, enough: enoughData) {
                            new.afterHourMessage = (result.0, result.1)
                            new.firstAfterHourPrice = result.2
                        }
                        DispatchQueue.main.async {
                            self.coins.insert(new, at: 0)
                        }
                    }
                }
            }
        }
    }
    func startStocks(){
        if !fetchingData {
            fetchingData = true
            Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
                self.fetchingData = false
            }
            var finalFetch: [(String, String)] = []
            if savedStocks.count > 5 && savedStocks.count <= 12 {
                finalFetch = Array(companyData.prefix(upTo: 12 - savedStocks.count))
            } else {
                finalFetch = companyData
            }
            
            var overall = savedStocks
            finalFetch.forEach { element in
                if !overall.contains(where: { $0.1 == element.1 }) {
                    overall.append(element)
                }
            }
            
            overall.forEach { element in
                if cryptoData.contains(where: { $0.1 == element.1 }) {
                    getCryptoData(asset: element.1, days: 1) { data in
                        var dayChange = 0.0
                        var dayChangeDollar = 0.0
                        let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                            return (structItem.close, self.timeFormat(timestamp: structItem.date))
                        }
                        if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.open {
                            dayChange = self.calculatePercentChange(p1: first, p2: last)
                            dayChangeDollar = last - first
                        }
                        
                        var new = CryptoModel(id: "\(UUID())", symbol: element.1, name: element.0, current_price: data.candleSticks.last?.close ?? 0.0, price_change_day: dayChange, price_change_day_dollar: dayChangeDollar, day_prices: arrayOfTuples, time_last_fetched: Date(), isCrypto: true, enoughPreMarketData: true)
                        new.volatility = self.calculateStockVolatility(prices: arrayOfTuples.map { $0.0 })
                        DispatchQueue.main.async {
                            self.coins.insert(new, at: 0)
                        }
                    }
                } else {
                    if !matched.contains(where: { $0.symbol == element.1 }) {
                        DispatchQueue.main.async {
                            self.matched.append(SearchDisplay(id: "\(UUID())", displaySymbol: element.0, symbol: element.1, type: "Stock"))
                        }
                    }
                    getMarketData(asset: element.1, days: 1, enough: false) { data in
                        DispatchQueue.main.async {
                            self.gotUsersData = true
                        }
                        let status = self.StockMarketStatus()
                        var dayChange = 0.0
                        var dayChangeDollar = 0.0
                        var enoughData = true
                        var arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                            return (structItem.close, self.timeFormat(timestamp: structItem.date))
                        }
                        if status == 1 {
                            let test = arrayOfTuples.filter { element in
                                return self.isInToday(timestamp: element.1)
                            }
                            if test.count > 2 {
                                arrayOfTuples = test
                            } else {
                                enoughData = false
                            }
                        }
                        if let first = arrayOfTuples.first?.0, let last = (arrayOfTuples.filter { !self.isAfter4PM(dateString: $0.1) }).last {
                            dayChange = self.calculatePercentChange(p1: first, p2: last.0)
                            dayChangeDollar = last.0 - first
                        }
                        var new = CryptoModel(id: "\(UUID())", symbol: element.1, name: element.0, current_price: data.candleSticks.last?.close ?? 0.0, price_change_day: dayChange, price_change_day_dollar: dayChangeDollar, day_prices: arrayOfTuples, time_last_fetched: Date(), isCrypto: false, enoughPreMarketData: enoughData)
                        if let result = self.setAfterHoursMessage(data: arrayOfTuples, enough: enoughData) {
                            new.afterHourMessage = (result.0, result.1)
                            new.firstAfterHourPrice = result.2
                        }
                        DispatchQueue.main.async {
                            if self.savedStocks.contains(where: { $0.1 == element.1 }) {
                                self.coins.insert(new, at: 0)
                            } else {
                                self.coins.append(new)
                            }
                        }
                    }
                }
            }
        }
    }
    func getSaved(){
        let allStocks = fetchStocks()
        var stockArray: [String] = []
        for stock in allStocks {
            if let stockArr = stock.stockArr as? [String] {
                stockArray.append(contentsOf: stockArr)
            }
        }
        stockArray.forEach { element in
            let components = element.components(separatedBy: ",")
            if components.count == 2 {
                let beforeComma = components[0]
                let afterComma = components[1]
                if !savedStocks.contains(where: { $0.0 == beforeComma }) {
                    DispatchQueue.main.async {
                        self.savedStocks.append((beforeComma, afterComma))
                    }
                }
            }
        }
    }
    func getMarketData(asset: String, days: Int, enough: Bool, completion: @escaping (MarketDataResponse) -> Void){
        APICaller.shared().marketData(for: asset, numberOfDays: days, enough: enough) { result in
            switch result {
            case .success(let data):
                completion(data)
            case .failure:
                if days == 1 {
                    APICaller.shared().checkHoliday { bool in
                        if bool {
                            DispatchQueue.main.async {
                                self.holiday = (true, Date())
                            }
                            APICaller.shared().holidayMarketData(for: asset, enoughPre: enough) { result2 in
                                switch result2 {
                                case .success(let data):
                                    completion(data)
                                case .failure:
                                    print("E")
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.holiday = (false, Date())
                            }
                            APICaller.shared().exceptionMarketData(for: asset, enoughPre: enough) { result2 in
                                switch result2 {
                                case .success(let data):
                                    completion(data)
                                case .failure:
                                    print("E")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    func getCryptoData(asset: String, days: Int, completion: @escaping (MarketDataResponse) -> Void){
        APICaller.shared().cryptoMarketData(for: asset, numberOfDays: days) { result in
            switch result {
            case .success(let data):
                completion(data)
            case .failure:
                print("E")
            }
        }
    }
    func getWeekData(){
        if let index = currentCoin, coins[index].week_prices == nil {
            getMarketData(asset: coins[index].symbol, days: 7, enough: false) { data in
                DispatchQueue.main.async {
                    var weekChange = 0.0
                    if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.close {
                        weekChange = self.calculatePercentChange(p1: first, p2: last)
                    }
                    self.coins[index].price_change_week = weekChange
                    let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                        return (structItem.close, self.timeFormat(timestamp: structItem.date))
                    }
                    self.coins[index].week_prices = arrayOfTuples
                }
            }
        }
    }
    func getMonthData(){
        if let index = currentCoin, coins[index].month_prices == nil {
            getMarketData(asset: coins[index].symbol, days: 30, enough: false) { data in
                DispatchQueue.main.async {
                    var monthChange = 0.0
                    if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.close {
                        monthChange = self.calculatePercentChange(p1: first, p2: last)
                    }
                    self.coins[index].price_change_month = monthChange
                    let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                        return (structItem.close, self.timeFormat(timestamp: structItem.date))
                    }
                    self.coins[index].month_prices = arrayOfTuples
                }
            }
        }
    }
    func getYearData(){
        if let index = currentCoin, coins[index].year_prices == nil {
            getMarketData(asset: coins[index].symbol, days: 365, enough: false) { data in
                DispatchQueue.main.async {
                    var yearChange = 0.0
                    if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.close {
                        yearChange = self.calculatePercentChange(p1: first, p2: last)
                    }
                    self.coins[index].price_change_year = yearChange
                    let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                        return (structItem.close, self.timeFormat(timestamp: structItem.date))
                    }
                    self.coins[index].year_prices = arrayOfTuples
                }
            }
        }
    }
    func getWeekCryptoData(){
        if let index = currentCoin, coins[index].week_prices == nil {
            getCryptoData(asset: coins[index].symbol, days: 7) { data in
                DispatchQueue.main.async {
                    var weekChange = 0.0
                    if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.close {
                        weekChange = self.calculatePercentChange(p1: first, p2: last)
                    }
                    self.coins[index].price_change_week = weekChange
                    let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                        return (structItem.close, self.timeFormat(timestamp: structItem.date))
                    }
                    self.coins[index].week_prices = arrayOfTuples
                }
            }
        }
    }
    func getMonthCryptoData(){
        if let index = currentCoin, coins[index].month_prices == nil {
            getCryptoData(asset: coins[index].symbol, days: 30) { data in
                DispatchQueue.main.async {
                    var monthChange = 0.0
                    if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.close {
                        monthChange = self.calculatePercentChange(p1: first, p2: last)
                    }
                    self.coins[index].price_change_month = monthChange
                    let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                        return (structItem.close, self.timeFormat(timestamp: structItem.date))
                    }
                    self.coins[index].month_prices = arrayOfTuples
                }
            }
        }
    }
    func getYearCryptoData(){
        if let index = currentCoin, coins[index].year_prices == nil {
            getCryptoData(asset: coins[index].symbol, days: 365) { data in
                DispatchQueue.main.async {
                    var yearChange = 0.0
                    if let first = data.candleSticks.first?.open, let last = data.candleSticks.last?.close {
                        yearChange = self.calculatePercentChange(p1: first, p2: last)
                    }
                    self.coins[index].price_change_year = yearChange
                    let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                        return (structItem.close, self.timeFormat(timestamp: structItem.date))
                    }
                    self.coins[index].year_prices = arrayOfTuples
                }
            }
        }
    }
    func isMonday() -> Bool {
        var calendar = Calendar.current
        let today = Date()
        if let marketTimeZone = TimeZone(identifier: "America/New_York") {
            calendar.timeZone = marketTimeZone
            if calendar.component(.weekday, from: today) == 2 {
                return true
            }
        }
        return false
    }
    func getStats(query: String){
        if let index = currentCoin {
            APICaller.shared().financialMetrics(for: query) { result in
                switch result {
                case .success(let data):
                    let info = data.metric
                    DispatchQueue.main.async {
                        self.coins[index].AnnualWeekHigh = info.AnnualWeekHigh
                        self.coins[index].AnnualWeekLow = info.AnnualWeekLow
                        self.coins[index].AnnualWeekLowDate = info.AnnualWeekLowDate
                        self.coins[index].beta = info.beta
                        self.coins[index].TenDayAverageTradingVolume = info.TenDayAverageTradingVolume
                    }
                case .failure:
                    print("E")
                }
            }
        }
    }
    func timeFormat(timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, h:mm a"
        dateFormatter.locale = Locale(identifier: "en_US")
        
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    func isInToday(timestamp: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy MMM dd, h:mm a"
        let currentYear = Calendar.current.component(.year, from: Date())
        
        if let date = dateFormatter.date(from: "\(currentYear) \(timestamp)") {
            var calendar = Calendar.current

            if let marketTimeZone = TimeZone(identifier: "America/New_York") {
                calendar.timeZone = marketTimeZone
                return calendar.isDateInToday(date)
            }
        }
        return true
    }
    func calculatePercentChange(p1: Double, p2: Double) -> Double {
        let change = p2 - p1
        let percentChange = (change / p1) * 100
        return percentChange
    }
    func saveStock(name: String, symbol: String){
        let fullName = name + "," + symbol
        let allStocks = fetchStocks()
        var stockArray: [String] = []
        for stock in allStocks {
            if let stockArr = stock.stockArr as? [String] {
                stockArray.append(contentsOf: stockArr)
            }
        }
        deleteAllStockArr()
        stockArray.append(fullName)
        let finalArr = Array(Set(stockArray))
        createStock(stockArray: finalArr)
        if !savedStocks.contains(where: { $0.0 == name && $0.1 == symbol }){
            DispatchQueue.main.async {
                self.savedStocks.append((name, symbol))
            }
        }
    }
    func removeStock(name: String, symbol: String){
        let fullName = name + "," + symbol
        DispatchQueue.main.async {
            self.savedStocks.removeAll(where: { $0.0 == name })
        }
        let allStocks = fetchStocks()
        var stockArray: [String] = []
        for stock in allStocks {
            if let stockArr = stock.stockArr as? [String] {
                stockArray.append(contentsOf: stockArr)
            }
        }
        deleteAllStockArr()
        stockArray.removeAll(where: { $0 == fullName })
        let finalArr = Array(Set(stockArray))
        createStock(stockArray: finalArr)
    }
    func deleteAllStockArr() {
        let allStocks = self.fetchStocks()
        for stock in allStocks {
            stock.stockArr = nil
        }
        do {
            try self.context.save()
        } catch {
            print("E")
        }
    }
    func createStock(stockArray: [String]) {
        let newStock = Stock(context: self.context)
        newStock.stockArr = stockArray as NSObject
        
        do {
            try self.context.save()
        } catch {
            print("E")
        }
    }
    func fetchStocks() -> [Stock] {
        var stocks: [Stock] = []
        let fetchRequest: NSFetchRequest<Stock> = Stock.fetchRequest()

        do {
            stocks = try self.context.fetch(fetchRequest)
        } catch {
            print("E")
        }
        return stocks
    }
    func sortStocks(arr: [SearchDisplay], query: String) -> [SearchDisplay] {
        let validKeywords = ["cry", "cryp", "crypt", "crypto"]
        let lowercasedQuery = query.lowercased()
        let relevanceScore: (SearchDisplay) -> Int = { element in
            let lowercasedSymbol = element.symbol.lowercased()
            let lowercasedName = element.displaySymbol.lowercased()
            var score = 0
            if lowercasedSymbol.contains(lowercasedQuery) {
                score += 2
            }
            if lowercasedName.contains(lowercasedQuery) {
                score += 1
            }
            if element.type == "Crypto" {
                if validKeywords.contains(lowercasedQuery) {
                    score += 2
                }
            }
            return score
        }
        let sortedArray = arr.sorted { (element1, element2) -> Bool in
            let score1 = relevanceScore(element1)
            let score2 = relevanceScore(element2)
            
            if score1 != score2 {
                return score1 > score2
            } else {
                return element1.symbol < element2.symbol
            }
        }
        return sortedArray
    }
    func StockMarketStatus() -> Int {
        var calendar = Calendar.current
        let now = Date()
        if let marketTimeZone = TimeZone(identifier: "America/New_York") {
            calendar.timeZone = marketTimeZone
            if calendar.isDateInWeekend(now) {
                return -1
            }
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            let totalMinutes = currentHour * 60 + currentMinute
            let preMarketStartTime = 4 * 60  // 4:00 AM
            let marketOpenTime = 9 * 60 + 30  // 9:30 AM
            let marketCloseTime = 16 * 60  // 4:00 PM
            let afterHoursFinish = 20 * 60; // 8:00 PM

            if totalMinutes < preMarketStartTime {
                return 0
            } else if totalMinutes >= preMarketStartTime && totalMinutes < marketOpenTime {
                return 1
            } else if totalMinutes >= marketOpenTime && totalMinutes <= marketCloseTime {
                return 2
            } else if totalMinutes < afterHoursFinish {
                return 3
            } else {
                return 4
            }
        } else {
            return 2
        }
    }
    func MinutesUntilFinish(whichZone: Int) -> Int {
        var calendar = Calendar.current
        let now = Date()
        if let marketTimeZone = TimeZone(identifier: "America/New_York") {
            calendar.timeZone = marketTimeZone
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            let totalMinutes = currentHour * 60 + currentMinute
            let afterHoursFinish = 20 * 60
            let marketOpenTime = 9 * 60 + 30
            let marketCloseTime = 16 * 60
            
            if whichZone == 1 {
                if totalMinutes < marketOpenTime {
                    return marketOpenTime - totalMinutes
                } else {
                    return 0
                }
            } else if whichZone == 2 {
                if totalMinutes < marketCloseTime {
                    return marketCloseTime - totalMinutes
                } else {
                    return 0
                }
            } else {
                if totalMinutes < afterHoursFinish {
                    return afterHoursFinish - totalMinutes
                } else {
                    return 0
                }
            }
        } else { return 0 }
    }
    func setAfterHoursMessage(data: [(Double, String)], enough: Bool) -> (Double, Double, Double)? {
        let status = StockMarketStatus()
        if status >= 3 || status <= 0 || (status == 1 && !enough) {
            if let last = data.last, let first = (data.filter { isAfter4PM(dateString: $0.1) }).first {
                return((last.0 - first.0, calculatePercentChange(p1: first.0, p2: last.0), first.0))
            }
        }
        return nil
    }
    func isAfter4PM(dateString: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, h:mm a"
        if let date = dateFormatter.date(from: dateString) {
            var calendar = Calendar.current
            if let marketTimeZone = TimeZone(identifier: "America/New_York") {
                calendar.timeZone = marketTimeZone
                let components = calendar.dateComponents([.hour], from: date)
                if let hour = components.hour, hour >= 16 {
                    return true
                }
            }
        }
        return false
    }
    func isAfterPre(dateString: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, h:mm a"
        if let date = dateFormatter.date(from: dateString) {
            var calendar = Calendar.current
            if let marketTimeZone = TimeZone(identifier: "America/New_York") {
                calendar.timeZone = marketTimeZone
                let preMarketTime = calendar.date(bySettingHour: 9, minute: 29, second: 0, of: date)!
                return date > preMarketTime
            }
        }
        return false
    }
    func calculateStockVolatility(prices: [Double]) -> Double {
        let n = Double(prices.count)
        let meanPrice = prices.reduce(0, +) / n

        let sumOfSquaredDeviations = prices.reduce(0) { (result, price) in
            let deviation = meanPrice - price
            return result + (deviation * deviation)
        }

        let variance = sumOfSquaredDeviations / n
        let dailyVolatility = sqrt(variance)
        return dailyVolatility
    }
    func refreshStock(){
        let status = StockMarketStatus()
        if let i = currentCoin {
            let time_last_fetched = coins[i].time_last_fetched
            if let oneMinuteAfter = Calendar.current.date(byAdding: .minute, value: 1, to: time_last_fetched), Date() > oneMinuteAfter {
                if coins[i].isCrypto {
                    getCryptoData(asset: coins[i].symbol, days: 1) { data in
                        if !data.candleSticks.isEmpty {
                            var dayChange = 5000.0
                            var dayChangeDollar = 5000.0
                            let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                                return (structItem.close, self.timeFormat(timestamp: structItem.date))
                            }
                            if let last = data.candleSticks.last?.open, let first = data.candleSticks.first?.open {
                                dayChange = self.calculatePercentChange(p1: first, p2: last)
                                dayChangeDollar = last - first
                            }
                            DispatchQueue.main.async {
                                self.coins[i].day_prices = arrayOfTuples
                                if dayChange != 5000.0 {
                                    self.coins[i].price_change_day = dayChange
                                }
                                if dayChangeDollar != 5000.0 {
                                    self.coins[i].price_change_day_dollar = dayChangeDollar
                                }
                                if let curr = data.candleSticks.last?.close {
                                    self.coins[i].current_price = curr
                                }
                                self.coins[i].time_last_fetched = Date()
                                if let last = arrayOfTuples.last {
                                    if let first = self.coins[i].week_prices?.first {
                                        self.coins[i].price_change_week = self.calculatePercentChange(p1: first.0, p2: last.0)
                                    }
                                    if let first = self.coins[i].month_prices?.first {
                                        self.coins[i].price_change_month = self.calculatePercentChange(p1: first.0, p2: last.0)
                                    }
                                    if let first = self.coins[i].year_prices?.first {
                                        self.coins[i].price_change_year = self.calculatePercentChange(p1: first.0, p2: last.0)
                                    }
                                }
                                self.coins[i].volatility = self.calculateStockVolatility(prices: arrayOfTuples.map { $0.0 })
                            }
                        }
                    }
                } else if (status == 1 || status == 2 || status == 3) && !holiday.0 {
                    getMarketData(asset: coins[i].symbol, days: 1, enough: coins[i].enoughPreMarketData) { data in
                        if !data.candleSticks.isEmpty {
                            var dayChange = 5000.0
                            var dayChangeDollar = 5000.0
                            var arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                                return (structItem.close, self.timeFormat(timestamp: structItem.date))
                            }
                            var enoughData = true
                            if status == 1 {
                                let test = arrayOfTuples.filter { element in
                                    return self.isInToday(timestamp: element.1)
                                }
                                if test.count > 2 {
                                    arrayOfTuples = test
                                } else {
                                    enoughData = false
                                }
                            }
                            if let first = arrayOfTuples.first?.0, let last = (arrayOfTuples.filter { !self.isAfter4PM(dateString: $0.1) }).last {
                                dayChange = self.calculatePercentChange(p1: first, p2: last.0)
                                dayChangeDollar = last.0 - first
                            }
                            DispatchQueue.main.async {
                                self.coins[i].day_prices = arrayOfTuples
                                self.coins[i].enoughPreMarketData = enoughData
                                if dayChange != 5000.0 {
                                    self.coins[i].price_change_day = dayChange
                                }
                                if dayChangeDollar != 5000.0 {
                                    self.coins[i].price_change_day_dollar = dayChangeDollar
                                }
                                if let curr = data.candleSticks.last?.close {
                                    self.coins[i].current_price = curr
                                }
                                self.coins[i].time_last_fetched = Date()
                                if let mess = self.setAfterHoursMessage(data: arrayOfTuples, enough: enoughData) {
                                    self.coins[i].afterHourMessage = (mess.0, mess.1)
                                    self.coins[i].firstAfterHourPrice = mess.2
                                }
                                if let last = arrayOfTuples.last {
                                    if let first = self.coins[i].week_prices?.first {
                                        self.coins[i].price_change_week = self.calculatePercentChange(p1: first.0, p2: last.0)
                                    }
                                    if let first = self.coins[i].month_prices?.first {
                                        self.coins[i].price_change_month = self.calculatePercentChange(p1: first.0, p2: last.0)
                                    }
                                    if let first = self.coins[i].year_prices?.first {
                                        self.coins[i].price_change_year = self.calculatePercentChange(p1: first.0, p2: last.0)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    func refreshAllStock(){
        if currentCoin == nil {
            for i in 0..<coins.count {
                let time_last_fetched = coins[i].time_last_fetched
                if let oneMinuteAfter = Calendar.current.date(byAdding: .minute, value: 1, to: time_last_fetched), Date() > oneMinuteAfter {
                    let status = StockMarketStatus()
                    if coins[i].isCrypto {
                        getCryptoData(asset: coins[i].symbol, days: 1) { data in
                            if !data.candleSticks.isEmpty {
                                var dayChange = 5000.0
                                var dayChangeDollar = 5000.0
                                let arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                                    return (structItem.close, self.timeFormat(timestamp: structItem.date))
                                }
                                if let last = data.candleSticks.last?.open, let first = data.candleSticks.first?.open {
                                    dayChange = self.calculatePercentChange(p1: first, p2: last)
                                    dayChangeDollar = last - first
                                }
                                DispatchQueue.main.async {
                                    self.coins[i].day_prices = arrayOfTuples
                                    if dayChange != 5000.0 {
                                        self.coins[i].price_change_day = dayChange
                                    }
                                    if dayChangeDollar != 5000.0 {
                                        self.coins[i].price_change_day_dollar = dayChangeDollar
                                    }
                                    if let curr = data.candleSticks.last?.close {
                                        self.coins[i].current_price = curr
                                    }
                                    self.coins[i].time_last_fetched = Date()
                                    if let last = arrayOfTuples.last {
                                        if let first = self.coins[i].week_prices?.first {
                                            self.coins[i].price_change_week = self.calculatePercentChange(p1: first.0, p2: last.0)
                                        }
                                        if let first = self.coins[i].month_prices?.first {
                                            self.coins[i].price_change_month = self.calculatePercentChange(p1: first.0, p2: last.0)
                                        }
                                        if let first = self.coins[i].year_prices?.first {
                                            self.coins[i].price_change_year = self.calculatePercentChange(p1: first.0, p2: last.0)
                                        }
                                    }
                                    self.coins[i].volatility = self.calculateStockVolatility(prices: arrayOfTuples.map { $0.0 })
                                }
                            }
                        }
                    } else if (status == 1 || status == 2 || status == 3) && !holiday.0 {
                        getMarketData(asset: coins[i].symbol, days: 1, enough: coins[i].enoughPreMarketData) { data in
                            if !data.candleSticks.isEmpty {
                                var dayChange = 5000.0
                                var dayChangeDollar = 5000.0
                                var arrayOfTuples = data.candleSticks.map { (structItem) -> (Double, String) in
                                    return (structItem.close, self.timeFormat(timestamp: structItem.date))
                                }
                                var enoughData = true
                                if status == 1 {
                                    let test = arrayOfTuples.filter { element in
                                        return self.isInToday(timestamp: element.1)
                                    }
                                    if test.count > 2 {
                                        arrayOfTuples = test
                                    } else {
                                        enoughData = false
                                    }
                                }
                                if let first = arrayOfTuples.first?.0, let last = (arrayOfTuples.filter { !self.isAfter4PM(dateString: $0.1) }).last {
                                    dayChange = self.calculatePercentChange(p1: first, p2: last.0)
                                    dayChangeDollar = last.0 - first
                                }
                                DispatchQueue.main.async {
                                    self.coins[i].day_prices = arrayOfTuples
                                    self.coins[i].enoughPreMarketData = enoughData
                                    if dayChange != 5000.0 {
                                        self.coins[i].price_change_day = dayChange
                                    }
                                    if dayChangeDollar != 5000.0 {
                                        self.coins[i].price_change_day_dollar = dayChangeDollar
                                    }
                                    if let curr = data.candleSticks.last?.close {
                                        self.coins[i].current_price = curr
                                    }
                                    self.coins[i].time_last_fetched = Date()
                                    if let mess = self.setAfterHoursMessage(data: arrayOfTuples, enough: enoughData) {
                                        self.coins[i].afterHourMessage = (mess.0, mess.1)
                                        self.coins[i].firstAfterHourPrice = mess.2
                                    }
                                    if let last = arrayOfTuples.last {
                                        if let first = self.coins[i].week_prices?.first {
                                            self.coins[i].price_change_week = self.calculatePercentChange(p1: first.0, p2: last.0)
                                        }
                                        if let first = self.coins[i].month_prices?.first {
                                            self.coins[i].price_change_month = self.calculatePercentChange(p1: first.0, p2: last.0)
                                        }
                                        if let first = self.coins[i].year_prices?.first {
                                            self.coins[i].price_change_year = self.calculatePercentChange(p1: first.0, p2: last.0)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CryptoModel: Identifiable {
    var id: String
    var symbol: String
    var name: String
    var current_price: Double
    var price_change_day: Double
    var price_change_day_dollar: Double
    var price_change_week: Double?
    var price_change_month: Double?
    var price_change_year: Double?
    var day_prices: [(Double, String)]
    var week_prices: [(Double, String)]?
    var month_prices: [(Double, String)]?
    var year_prices: [(Double, String)]?
    var afterHourMessage: (Double, Double)?
    var time_last_fetched: Date
    var volatility: Double?
    var isCrypto: Bool
    var firstAfterHourPrice: Double?
    var enoughPreMarketData: Bool

    var TenDayAverageTradingVolume: Float?
    var AnnualWeekHigh: Double?
    var AnnualWeekLow: Double?
    var AnnualWeekLowDate: String?
    var beta: Float?
}

