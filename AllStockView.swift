import SwiftUI

struct AllStockView: View {
    @Environment(\.colorScheme) var colorScheme
    @Namespace var animation
    @EnvironmentObject var appModel: StockViewModel
    @State var timeFrame = 1
    @State var showHeader = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) var scenePhase
    @State private var viewTop = false
    @EnvironmentObject var popRoot: PopToRoot
    let symbol: String
    let name: String
    @State var PriceChanged: Double = 0.0
    @State var barTranslation: CGFloat = 0.0
    @State var changingPrice = false
    @State var showPlot = false
    @GestureState var isDrag: Bool = false
    @State var currentPlot = ""
    @State var isNormalOrPre: Bool = false
    
    @State var dollarChanged: Double = 0.0
    @State var percentChanged: Double = 0.0
    @State var dollarChangedAfter: Double = 0.0
    @State var percentChangedAfter: Double = 0.0

    var body: some View {
        VStack(spacing: 5){
            ZStack(alignment: .bottom){
                HStack {
                    Button {
                        viewTop = false
                        presentationMode.wrappedValue.dismiss()
                        appModel.currentCoin = nil
                    } label: {
                        Image(systemName: "chevron.backward").foregroundStyle(.green).font(.system(size: 28))
                    }
                    Spacer()
                    if appModel.currentCoin != nil {
                        Button {
                            if appModel.savedStocks.contains(where: { $0.1 == symbol }) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                appModel.removeStock(name: name, symbol: symbol)
                                if let x = appModel.savedStocks.firstIndex(where: { $0.1 == symbol }) {
                                    appModel.savedStocks.remove(at: x)
                                }
                                withAnimation { popRoot.stockAddedRemoved = 2 }
                            } else {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                appModel.saveStock(name: name, symbol: symbol)
                                appModel.savedStocks.append((name, symbol))
                                withAnimation { popRoot.stockAddedRemoved = 1 }
                            }
                        } label: {
                            if appModel.savedStocks.contains(where: { $0.1 == symbol }) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 28))
                            } else {
                                Image(systemName: "plus.circle").font(.system(size: 28))
                            }
                        }
                    }
                }.padding(.horizontal, 15).padding(.bottom, 8)
                HStack(alignment: .bottom){
                    Spacer()
                    if let index = appModel.currentCoin {
                        VStack(spacing: 5){
                            Text(appModel.coins[index].current_price.convertToCurrency(num: appModel.coins[index].current_price)).font(.system(size: 15))
                            Text(appModel.coins[index].symbol.uppercased()).font(.system(size: 15))
                        }
                    }
                    Spacer()
                }.opacity(showHeader ? 1.0 : 0.0)
            }.padding(.top, 60)
            if let index = appModel.currentCoin, index < appModel.coins.count {
                ScrollView {
                    VStack {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(appModel.coins[index].symbol.uppercased()).font(.subheadline)
                            
                            Text(appModel.coins[index].name).font(.largeTitle.bold())
                            
                            Text(changingPrice ? PriceChanged.convertToCurrency(num: PriceChanged) : appModel.coins[index].current_price.convertToCurrency(num: appModel.coins[index].current_price)).font(.largeTitle.bold())
                            
                            VStack {
                                if timeFrame == 1 {
                                    VStack(alignment: .leading, spacing: 6) {
                                        let stat = appModel.StockMarketStatus()
                                        HStack(spacing: 3){
                                            if changingPrice {
                                                Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(dollarChanged >= 0 ? .green : .red).rotationEffect(.degrees(dollarChanged >= 0 ? 0 : 180))
                                                Text("\(abs(dollarChanged).convertToCurrency(num: dollarChanged)) (\(String(format: "%.2f", percentChanged))%)").font(.subheadline).foregroundStyle(dollarChanged >= 0 ? .green : .red)
                                            } else {
                                                Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(appModel.coins[index].price_change_day >= 0 ? .green : .red).rotationEffect(.degrees(appModel.coins[index].price_change_day >= 0 ? 0 : 180))
                                                Text("\(abs(appModel.coins[index].price_change_day_dollar).convertToCurrency(num: appModel.coins[index].price_change_day_dollar)) (\(String(format: "%.2f", appModel.coins[index].price_change_day))%)").font(.subheadline).foregroundStyle(appModel.coins[index].price_change_day >= 0 ? .green : .red)
                                            }
                                            if appModel.coins[index].isCrypto {
                                                Text("Today").font(.subheadline)
                                            } else {
                                                if stat <= 0 {
                                                    if appModel.isMonday() {
                                                        if changingPrice {
                                                            Text(isNormalOrPre ? "Last Friday" : "Pre-Market").font(.subheadline)
                                                        } else {
                                                            Text("Last Friday").font(.subheadline)
                                                        }
                                                    } else {
                                                        if changingPrice {
                                                            Text(isNormalOrPre ? "Yesterday" : "Pre-Market").font(.subheadline)
                                                        } else {
                                                            Text("Yesterday").font(.subheadline)
                                                        }
                                                    }
                                                } else if stat == 1 {
                                                    if appModel.coins[index].enoughPreMarketData {
                                                        Text("Pre-Market").font(.subheadline)
                                                    } else {
                                                        if appModel.isMonday() {
                                                            if changingPrice {
                                                                Text(isNormalOrPre ? "Last Friday" : "Pre-Market").font(.subheadline)
                                                            } else {
                                                                Text("Last Friday").font(.subheadline)
                                                            }
                                                        } else {
                                                            if changingPrice {
                                                                Text(isNormalOrPre ? "Yesterday" : "Pre-Market").font(.subheadline)
                                                            } else {
                                                                Text("Yesterday").font(.subheadline)
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    if changingPrice {
                                                        Text(isNormalOrPre ? "Today" : "Pre-Market").font(.subheadline)
                                                    } else {
                                                        Text("Today").font(.subheadline)
                                                    }
                                                }
                                            }
                                            Spacer()
                                        }
                                        if !appModel.coins[index].isCrypto {
                                            HStack(spacing: 3){
                                                if let message = appModel.coins[index].afterHourMessage, stat >= 3 || stat <= 0 || (stat == 1 && !appModel.coins[index].enoughPreMarketData){
                                                    if changingPrice {
                                                        Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(dollarChangedAfter >= 0 ? .green : .red).rotationEffect(.degrees(dollarChangedAfter >= 0 ? 0 : 180))
                                                        Text("\(abs(dollarChangedAfter).convertToCurrency(num: dollarChangedAfter)) (\(String(format: "%.2f", percentChangedAfter))%)").font(.subheadline).foregroundStyle(dollarChangedAfter >= 0 ? .green : .red)
                                                    } else {
                                                        Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(message.0 >= 0 ? .green : .red).rotationEffect(.degrees(message.0 >= 0 ? 0 : 180))
                                                        Text("\(abs(message.0).convertToCurrency(num: message.0)) (\(String(format: "%.2f", message.1))%)").font(.subheadline).foregroundStyle(message.1 >= 0 ? .green : .red)
                                                    }
                                                    Text("After-Hours").font(.subheadline)
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                } else if timeFrame == 2 {
                                    HStack(spacing: 3){
                                        if changingPrice {
                                            Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(dollarChanged >= 0 ? .green : .red).rotationEffect(.degrees(dollarChanged >= 0 ? 0 : 180))
                                            Text("\(abs(dollarChanged).convertToCurrency(num: dollarChanged)) (\(String(format: "%.2f", percentChanged))%)").font(.subheadline).foregroundStyle(dollarChanged >= 0 ? .green : .red)
                                        } else {
                                            Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(appModel.coins[index].price_change_week ?? 0 >= 0 ? .green : .red).rotationEffect(.degrees(appModel.coins[index].price_change_week ?? 0 >= 0 ? 0 : 180))
                                            let change = (appModel.coins[index].week_prices?.last?.0 ?? 0) - (appModel.coins[index].week_prices?.first?.0 ?? 0)
                                            Text("\(abs(change).convertToCurrency(num: change)) (\(String(format: "%.2f", appModel.coins[index].price_change_week ?? 0))%)").font(.subheadline).foregroundStyle(appModel.coins[index].price_change_week ?? 0 >= 0 ? .green : .red)
                                        }
                                        Text("Past Week").font(.subheadline)
                                        Spacer()
                                    }
                                } else if timeFrame == 3 {
                                    HStack(spacing: 3){
                                        if changingPrice {
                                            Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(dollarChanged >= 0 ? .green : .red).rotationEffect(.degrees(dollarChanged >= 0 ? 0 : 180))
                                            Text("\(abs(dollarChanged).convertToCurrency(num: dollarChanged)) (\(String(format: "%.2f", percentChanged))%)").font(.subheadline).foregroundStyle(dollarChanged >= 0 ? .green : .red)
                                        } else {
                                            Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(appModel.coins[index].price_change_month ?? 0 >= 0 ? .green : .red).rotationEffect(.degrees(appModel.coins[index].price_change_month ?? 0 >= 0 ? 0 : 180))
                                            let change = (appModel.coins[index].month_prices?.last?.0 ?? 0) - (appModel.coins[index].month_prices?.first?.0 ?? 0)
                                            Text("\(abs(change).convertToCurrency(num: change)) (\(String(format: "%.2f", appModel.coins[index].price_change_month ?? 0))%)").font(.subheadline).foregroundStyle(appModel.coins[index].price_change_month ?? 0 >= 0 ? .green : .red)
                                        }
                                        Text("Past Month").font(.subheadline)
                                        Spacer()
                                    }
                                } else {
                                    HStack(spacing: 3){
                                        if changingPrice {
                                            Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(dollarChanged >= 0 ? .green : .red).rotationEffect(.degrees(dollarChanged >= 0 ? 0 : 180))
                                            Text("\(abs(dollarChanged).convertToCurrency(num: dollarChanged)) (\(String(format: "%.2f", percentChanged))%)").font(.subheadline).foregroundStyle(dollarChanged >= 0 ? .green : .red)
                                        } else {
                                            Image(systemName: "triangle.fill").font(.subheadline).scaleEffect(0.8).foregroundStyle(appModel.coins[index].price_change_year ?? 0 >= 0 ? .green : .red).rotationEffect(.degrees(appModel.coins[index].price_change_year ?? 0 >= 0 ? 0 : 180))
                                            let change = (appModel.coins[index].year_prices?.last?.0 ?? 0) - (appModel.coins[index].year_prices?.first?.0 ?? 0)
                                            Text("\(abs(change).convertToCurrency(num: change)) (\(String(format: "%.2f", appModel.coins[index].price_change_year ?? 0))%)").font(.subheadline).foregroundStyle(appModel.coins[index].price_change_year ?? 0 >= 0 ? .green : .red)
                                        }
                                        Text("Past Year").font(.subheadline)
                                        Spacer()
                                    }
                                }
                            }.id(timeFrame)
                        }
                        .padding(.leading).padding(.top, 5)
                        .frame(maxWidth: .infinity,alignment: .leading)
                        
                        GraphView(coin: appModel.coins[index], i: index).frame(height: widthOrHeight(width: false) * 0.44)
                            .gesture(DragGesture().onChanged({ value in
                                if abs(value.translation.width) > abs(value.translation.height) {
                                    withAnimation { showPlot = true }
                                    changingPrice = true
                                    barTranslation = value.location.x
                                }
                            }).onEnded({ value in
                                withAnimation { showPlot = false }
                                changingPrice = false
                            }).updating($isDrag, body: { value, out, _ in
                                out = true
                            }))
                            .onChange(of: isDrag) { _ in
                                if !isDrag {
                                    showPlot = false
                                } else {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            }
                            .overlay(alignment: .bottomLeading) {
                                VStack(spacing: 0){
                                    let fWidth = widthOrHeight(width: true)
                                    Text(currentPlot)
                                        .font(.caption.bold())
                                        .foregroundStyle(colorScheme == .dark ? Color(UIColor.lightGray) : .gray)
                                        .padding(.bottom, 35)
                                        .position(x: (barTranslation > 53 && barTranslation < fWidth - 53) ? barTranslation : barTranslation <= 53 ? 53 : barTranslation > fWidth - 53 ? fWidth - 53 : barTranslation)
                                    Rectangle()
                                        .fill(colorScheme == .dark ? Color(UIColor.lightGray) : .gray)
                                        .frame(width: 1, height: widthOrHeight(width: false) * 0.42)
                                        .position(x: barTranslation)
                                    Spacer()
                                }
                                .offset(y: 25)
                                .opacity(showPlot ? 1 : 0)
                            }

                        CustomControl(index: index)
                        
                        if appModel.holiday.0 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).foregroundStyle(.ultraThinMaterial)
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 18))
                                    Text("Holiday Market Closure.").font(.system(size: 18))
                                    Spacer()
                                }.padding(.leading, 8)
                            }.frame(height: 45).padding(.horizontal).padding(.vertical)
                        }
                        
                        stats(index: index).padding(.bottom, 100)
                    }
                    .background(GeometryReader {
                        Color.clear.preference(key: ViewOffsetKey.self,
                                               value: -$0.frame(in: .named("scrollXX")).origin.y)
                    })
                    .onPreferenceChange(ViewOffsetKey.self) { value in
                        if value > 60 {
                            withAnimation { showHeader = true }
                        } else {
                            withAnimation { showHeader = false }
                        }
                    }
                }
                .coordinateSpace(name: "scrollXX")
                .frame(maxWidth: .infinity, maxHeight: .infinity).scrollIndicators(.hidden)
            } else {
                LoadingStocksMain()
            }
        }
        .ignoresSafeArea(edges: .horizontal)
        .onAppear {
            if appModel.holiday.0 {
                appModel.verifyHoliday()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if appModel.news.isEmpty {
                    appModel.getNews()
                }
                if !appModel.technical.contains(where: { $0.0 == symbol }){
                    appModel.getTechnical(symbol: symbol)
                }
            }
            viewTop = true
            appModel.getIndex(symbol: symbol, name: name)
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                if scenePhase == .active {
                    appModel.refreshStock()
                }
            }
        }
        .onDisappear {
            viewTop = false
            appModel.currentCoin = nil
        }
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(edges: .top)
        .onChange(of: popRoot.tap) { _ in
            if popRoot.tap == 3 && popRoot.Explore_or_Video && viewTop {
                presentationMode.wrappedValue.dismiss()
                popRoot.tap = 0
            }
        }
        .onChange(of: PriceChanged) { _ in
            changeAllPrices()
        }
    }
    func changeAllPrices(){
        if let index = appModel.currentCoin {
            if timeFrame == 1 {
                if appModel.coins[index].isCrypto {
                    if let firstPrice = appModel.coins[index].day_prices.first?.0 {
                        dollarChanged = PriceChanged - firstPrice
                        percentChanged = appModel.calculatePercentChange(p1: firstPrice, p2: PriceChanged)
                    }
                } else {
                    if appModel.isAfter4PM(dateString: currentPlot) {
                        if let firstPrice = appModel.coins[index].firstAfterHourPrice {
                            dollarChangedAfter = PriceChanged - firstPrice
                            percentChangedAfter = appModel.calculatePercentChange(p1: firstPrice, p2: PriceChanged)
                        }
                        dollarChanged = appModel.coins[index].price_change_day_dollar
                        percentChanged = appModel.coins[index].price_change_day
                    } else if appModel.isAfterPre(dateString: currentPlot) {
                        isNormalOrPre = true
                        if let firstPrice = appModel.coins[index].day_prices.first?.0 {
                            dollarChanged = PriceChanged - firstPrice
                            percentChanged = appModel.calculatePercentChange(p1: firstPrice, p2: PriceChanged)
                        }
                        if let mess = appModel.coins[index].afterHourMessage {
                            dollarChangedAfter = mess.0
                            percentChangedAfter = mess.1
                        }
                    } else {
                        isNormalOrPre = false
                        if let firstPrice = appModel.coins[index].day_prices.first?.0 {
                            dollarChanged = PriceChanged - firstPrice
                            percentChanged = appModel.calculatePercentChange(p1: firstPrice, p2: PriceChanged)
                        }
                        if let mess = appModel.coins[index].afterHourMessage {
                            dollarChangedAfter = mess.0
                            percentChangedAfter = mess.1
                        }
                    }
                }
            } else if timeFrame == 2 {
                if let firstPrice = appModel.coins[index].week_prices?.first?.0 {
                    dollarChanged = PriceChanged - firstPrice
                    percentChanged = appModel.calculatePercentChange(p1: firstPrice, p2: PriceChanged)
                }
            } else if timeFrame == 3 {
                if let firstPrice = appModel.coins[index].month_prices?.first?.0 {
                    dollarChanged = PriceChanged - firstPrice
                    percentChanged = appModel.calculatePercentChange(p1: firstPrice, p2: PriceChanged)
                }
            } else {
                if let firstPrice = appModel.coins[index].year_prices?.first?.0 {
                    dollarChanged = PriceChanged - firstPrice
                    percentChanged = appModel.calculatePercentChange(p1: firstPrice, p2: PriceChanged)
                }
            }
        }
    }
    func getGraphWidth(index: Int) -> CGFloat {
        let fullSize = widthOrHeight(width: true)
        if timeFrame != 1 || appModel.holiday.0 { return fullSize }
        if appModel.coins[index].isCrypto {
            let currentDate = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute, .second], from: currentDate)
            let totalSecondsInADay: Double = 24 * 60 * 60
            let currentSeconds = Double(components.hour! * 3600 + components.minute! * 60 + components.second!)
            let percentageOfDay = currentSeconds / totalSecondsInADay
            return (percentageOfDay * fullSize)
        } else {
            let status = appModel.StockMarketStatus()
            if status >= 1 && status <= 3 {
                if status == 1 {
                    if !appModel.coins[index].enoughPreMarketData {
                        return fullSize
                    } else {
                        let untilDone = appModel.MinutesUntilFinish(whichZone: 1)
                        let elapsedRatio = (330.0 - Double(untilDone)) / 330.0
                        let preMarketWidth = elapsedRatio * (0.3 * fullSize)
                        return preMarketWidth
                    }
                } else if status == 2 {
                    let untilDone = appModel.MinutesUntilFinish(whichZone: 2)
                    let elapsedRatio = (390.0 - Double(untilDone)) / 390.0
                    let toAdd = (0.3 * fullSize)
                    let normalHoursWidth = elapsedRatio * (0.45 * fullSize)
                    return (normalHoursWidth + toAdd)
                } else {
                    let untilDone = appModel.MinutesUntilFinish(whichZone: 3)
                    let elapsedRatio = (240.0 - Double(untilDone)) / 240.0
                    let toAdd = (0.725 * fullSize)
                    let afterHoursWidth = elapsedRatio * (0.275 * fullSize)
                    return (afterHoursWidth + toAdd)
                }
            } else {
                return fullSize
            }
        }
    }
    func reduceDataPoints(index: Int) -> ([Double], [String]){
        if timeFrame == 1 {
            if appModel.coins[index].day_prices.count > 200 {
                let final = appModel.coins[index].day_prices.enumerated().compactMap { (index, element) in
                    return index % 2 == 0 ? element : nil
                }
                let prices = final.map { $0.0 }
                let times = final.map { $0.1 }
                return (prices, times)
            } else {
                let prices = appModel.coins[index].day_prices.map { $0.0 }
                let times = appModel.coins[index].day_prices.map { $0.1 }
                return (prices, times)
            }
        } else if timeFrame == 2 {
            let prices = (appModel.coins[index].week_prices ?? []).map { $0.0 }
            let times = (appModel.coins[index].week_prices ?? []).map { $0.1 }
            return (prices, times)
        } else if timeFrame == 3 {
            let prices = (appModel.coins[index].month_prices ?? []).map { $0.0 }
            let times = (appModel.coins[index].month_prices ?? []).map { $0.1 }
            return (prices, times)
        } else {
            let prices = (appModel.coins[index].year_prices ?? []).map { $0.0 }
            let times = (appModel.coins[index].year_prices ?? []).map { $0.1 }
            return (prices, times)
        }
    }
    @ViewBuilder
    func GraphView(coin: CryptoModel, i: Int)->some View {
        let resultData = reduceDataPoints(index: i)
        HStack {
            if resultData.0.isEmpty {
                LoaderLine(restart: false, data: generateStockPrices()).shimmering().frame(width: widthOrHeight(width: true), height: widthOrHeight(width: false) * 0.5)
            } else {
                LineGraph(data: resultData.0, times: resultData.1, profit: timeFrame == 1 ? appModel.coins[i].price_change_day >= 0 : timeFrame == 2 ? appModel.coins[i].price_change_week ?? 0 >= 0 : timeFrame == 3 ? appModel.coins[i].price_change_month ?? 0 >= 0 : appModel.coins[i].price_change_year ?? 0 >= 0, isDay: timeFrame == 1, isCrypto: appModel.coins[i].isCrypto, enough: appModel.coins[i].enoughPreMarketData, currentPlot: $currentPlot, showPlot: $showPlot, priceToShow: $PriceChanged, isChangingPrice: $changingPrice, barTranslation: $barTranslation)
                    .frame(width: getGraphWidth(index: i))
            }
            Spacer()
        }.padding(.bottom, 20)
    }
    @ViewBuilder
    func stats(index: Int)->some View{
        VStack(spacing: 10){
            VStack(alignment: .leading, spacing: 15){
                Text("Stats").font(.title2).bold()
                HStack {
                    VStack(alignment: .leading, spacing: 15){
                        VStack(alignment: .leading, spacing: 3){
                            Text("Open").font(.subheadline).foregroundStyle(.gray)
                            if let val = appModel.coins[index].day_prices.first?.0 {
                                Text(val.convertToCurrency(num: val)).font(.subheadline).bold()
                            } else {
                                Text("---").font(.subheadline).bold()
                            }
                        }
                        VStack(alignment: .leading, spacing: 3){
                            Text("Today's High").font(.subheadline).foregroundStyle(.gray)
                            if let val = (appModel.coins[index].day_prices.max(by: { $0.0 < $1.0 }))?.0 {
                                Text(val.convertToCurrency(num: val)).font(.subheadline).bold()
                            } else {
                                Text("---").font(.subheadline).bold()
                            }
                        }
                        VStack(alignment: .leading, spacing: 3){
                            Text("Today's Low").font(.subheadline).foregroundStyle(.gray)
                            if let val = (appModel.coins[index].day_prices.min(by: { $0.0 < $1.0 }))?.0 {
                                Text(val.convertToCurrency(num: val)).font(.subheadline).bold()
                            } else {
                                Text("---").font(.subheadline).bold()
                            }
                        }
                        VStack(alignment: .leading, spacing: 3){
                            if appModel.coins[index].isCrypto {
                                Text("Today's Volatility").font(.subheadline).foregroundStyle(.gray)
                                let num = appModel.coins[index].volatility ?? 0.0
                                Text(num.convertToCurrency(num: num)).font(.subheadline).bold()
                            } else {
                                Text("Avg Volume").font(.subheadline).foregroundStyle(.gray)
                                Text(String(format: "%.1fM", appModel.coins[index].TenDayAverageTradingVolume ?? 0.0)).font(.subheadline).bold()
                            }
                        }
                    }.frame(width: widthOrHeight(width: true) * 0.36)
                    if !appModel.coins[index].isCrypto {
                        VStack(alignment: .leading, spacing: 15){
                            VStack(alignment: .leading, spacing: 3){
                                Text("Beta").font(.subheadline).foregroundStyle(.gray)
                                let num = appModel.coins[index].beta ?? 0.0
                                let ix = num < 0.1 ? 6 : num <= 1 ? 4 : 2
                                Text(String(format: "%.\(ix)f", num)).font(.subheadline).bold()
                            }
                            VStack(alignment: .leading, spacing: 3){
                                Text("52 Wk High").font(.subheadline).foregroundStyle(.gray)
                                if let val = appModel.coins[index].AnnualWeekHigh {
                                    Text(val.convertToCurrency(num: val)).font(.subheadline).bold()
                                } else {
                                    Text("---").font(.subheadline).bold()
                                }
                            }
                            VStack(alignment: .leading, spacing: 3){
                                Text("52 Wk Low").font(.subheadline).foregroundStyle(.gray)
                                if let val = appModel.coins[index].AnnualWeekLow {
                                    Text(val.convertToCurrency(num: val)).font(.subheadline).bold()
                                } else {
                                    Text("---").font(.subheadline).bold()
                                }
                            }
                            VStack(alignment: .leading, spacing: 3){
                                Text("Low Date").font(.subheadline).foregroundStyle(.gray)
                                Text(appModel.coins[index].AnnualWeekLowDate ?? "---").font(.subheadline).bold()
                            }
                        }.frame(width: widthOrHeight(width: true) * 0.36)
                    }
                    Spacer()
                }
            }.padding()
            
            AIStocks(asset: symbol)
            
            if let element = appModel.technical.first(where: { $0.0 == symbol }) {
                TechnicalView(products: [Votes(title: "buy", revenue: Double(element.1.technicalAnalysis.count.buy)), Votes(title: "sell", revenue: Double(element.1.technicalAnalysis.count.sell)), Votes(title: "hold", revenue: Double(element.1.technicalAnalysis.count.neutral))], adx: element.1.trend.adx, trending: element.1.trend.trending, buy: element.1.technicalAnalysis.count.buy, sell: element.1.technicalAnalysis.count.sell, hold: element.1.technicalAnalysis.count.neutral)
            }
            if appModel.news.isEmpty {
                Button {
                    if let url = URL(string: "https://www.google.com/search?q=\(appModel.coins[index].name)+news") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("See News for \(appModel.coins[index].symbol.uppercased())").font(.title2).bold().foregroundStyle(.blue)
                }.padding(.top)
            } else {
                LazyVStack {
                    ForEach(appModel.news, id: \.self) { news in
                        HStack {
                            Spacer()
                            if let url = URL(string: news.url), UIApplication.shared.canOpenURL(url) {
                                Link(destination: url, label: {
                                    StockNewsView(news: news)
                                })
                            } else {
                                StockNewsView(news: news)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func CustomControl(index: Int)->some View{
        HStack(spacing: 0){
            HStack {
                Spacer()
                Text("1D")
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 65, height: 25)
                    .contentShape(Rectangle())
                    .background {
                        if timeFrame == 1 {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                                .matchedGeometryEffect(id: "SEGMENTEDTAB", in: animation)
                        }
                    }
                Spacer()
            }
            .frame(width: 65)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    timeFrame = 1
                }
            }
            HStack {
                Spacer()
                Text("1W")
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 65, height: 25)
                    .contentShape(Rectangle())
                    .background {
                        if timeFrame == 2{
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                                .matchedGeometryEffect(id: "SEGMENTEDTAB", in: animation)
                        }
                    }
                Spacer()
            }
            .frame(width: 65)
            .onTapGesture {
                if appModel.coins[index].week_prices == nil {
                    if appModel.coins[index].isCrypto {
                        appModel.getWeekCryptoData()
                    } else {
                        appModel.getWeekData()
                    }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    timeFrame = 2
                }
            }
            HStack {
                Spacer()
                Text("1M")
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 65, height: 25)
                    .contentShape(Rectangle())
                    .background {
                        if timeFrame == 3 {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                                .matchedGeometryEffect(id: "SEGMENTEDTAB", in: animation)
                        }
                    }
                Spacer()
            }
            .frame(width: 65)
            .onTapGesture {
                if appModel.coins[index].month_prices == nil {
                    if appModel.coins[index].isCrypto {
                        appModel.getMonthCryptoData()
                    } else {
                        appModel.getMonthData()
                    }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    timeFrame = 3
                }
            }
            HStack {
                Spacer()
                Text("1Y")
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 65, height: 25)
                    .contentShape(Rectangle())
                    .background {
                        if timeFrame == 4 {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                                .matchedGeometryEffect(id: "SEGMENTEDTAB", in: animation)
                        }
                    }
                Spacer()
            }
            .frame(width: 65)
            .onTapGesture {
                if appModel.coins[index].year_prices == nil {
                    if appModel.coins[index].isCrypto {
                        appModel.getYearCryptoData()
                    } else {
                        appModel.getYearData()
                    }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    timeFrame = 4
                }
            }
        }
        .frame(width: 260)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1)
        }
        .padding(.vertical)
        .frame(width: 130)
    }
}

extension Double{
    func convertToCurrency(num: Double)->String{
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if num != 0 {
            if num < 0.1 {
                formatter.maximumFractionDigits = 6
            } else if num <= 1.0 {
                formatter.maximumFractionDigits = 4
            }
        }
        
        return formatter.string(from: .init(value: self)) ?? ""
    }
}

struct LineGraph: View {
    @EnvironmentObject var appModel: StockViewModel
    @Environment(\.colorScheme) var colorScheme
    var data: [Double]
    var times: [String]
    var profit: Bool
    let isDay: Bool
    let isCrypto: Bool
    let enough: Bool
    @Binding var currentPlot: String
    @Binding var showPlot: Bool
    @State var graphProgress: CGFloat = 0
    @State var show = false
    @Binding var priceToShow: Double
    @Binding var isChangingPrice: Bool
    @Binding var barTranslation: CGFloat
    
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = (proxy.size.width) / CGFloat(data.count - 1)
            
            let maxPoint = data.max() ?? 0
            let minPoint = data.min() ?? 0
            
            let points = data.enumerated().compactMap { item -> CGPoint in

                let progress = (item.element - minPoint) / (maxPoint - minPoint)
                
                let pathHeight = progress * (height - 50)

                let pathWidth = width * CGFloat(item.offset)

                return CGPoint(x: pathWidth, y: -pathHeight + height)
            }
            ZStack {
                AnimatedGraphPath(progress: graphProgress, points: points)
                    .fill(
                        LinearGradient(colors: [
                            profit ? .green : .red,
                            profit ? .green : .red,
                        ], startPoint: .leading, endPoint: .trailing)
                    )
                FillBG()
                    .clipShape (
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            
                            path.addLines(points)
                            
                            path.addLine(to: CGPoint(x: proxy.size.width, y: height))
                            
                            path.addLine(to: CGPoint(x: 0, y: height))
                        }
                    )
                    .opacity(graphProgress)
            }
            .onChange(of: barTranslation) { newValue in
                let index = max(min(Int((barTranslation / width).rounded() + 1), data.count - 1), 0)

                if index < times.count {
                    currentPlot = times[index]
                }
                priceToShow = data[index]
            }
            .overlay (
                ZStack {
                    if show && isDay {
                        let stat = appModel.StockMarketStatus()
                        if (stat >= 1 && stat <= 3 && !appModel.holiday.0 && ((stat == 1 && enough) || stat != 1)) || isCrypto {
                            PulsingView(size1: 8.5, size2: 55, green: profit).position(x: points[data.count - 1].x, y: points[data.count - 1].y).offset(x: 3, y: checkDirection(data: data.suffix(6)))
                        }
                    }
                }, alignment: .bottomLeading
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.8)){
                    graphProgress = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                show = true
            }
        }
        .onDisappear {
            show = false
        }
    }

    @ViewBuilder
    func FillBG()->some View {
        let color: Color = profit ? .green : .red
        LinearGradient(colors: [
            color
                .opacity(0.3),
            color
                .opacity(0.2),
            color
                .opacity(0.1)]
            + Array(repeating: color
                .opacity(0.1), count: 4)
            + Array(repeating:                     Color.clear, count: 2)
            , startPoint: .top, endPoint: .bottom)
    }
    func checkDirection(data: [Double]) -> CGFloat {
        guard data.count >= 3 else { return 0.0 }
        var upCount = 0
        var downCount = 0
        for i in 1..<data.count - 1 {
            if data[i] > data[i - 1] {
                upCount += 1
            } else if data[i] < data[i - 1] {
                downCount += 1
            }
        }
        if upCount > downCount {
            return -4.0
        } else if upCount < downCount {
            return 4.0
        } else {
            return 0.0
        }
    }
}

struct AnimatedGraphPath: Shape{
    var progress: CGFloat
    var points: [CGPoint]
    var animatableData: CGFloat{
        get{return progress}
        set{progress = newValue}
    }
    func path(in rect: CGRect) -> Path {
        Path { path in

            path.move(to: CGPoint(x: 0, y: 0))
            
            path.addLines(points)
        }
        .trimmedPath(from: 0, to: progress)
        .strokedPath(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
}
