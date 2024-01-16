import SwiftUI

struct LoadingStocksMain: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 15){
                Capsule().frame(width: 70, height: 20)
                Capsule().frame(width: 110, height: 30)
                Capsule().frame(width: 110, height: 30)
            }.padding(.leading).foregroundStyle(.gray).shimmering()
            LoaderLine(restart: false, data: generateStockPrices()).shimmering().frame(width: widthOrHeight(width: true), height: widthOrHeight(width: false) * 0.55)
            Spacer()
        }
    }
}

func generateStockPrices() -> [Double] {
    var prices: [Double] = []
    var currentValue: Double = 1500.0
    let volatility: Double = 2.0

    for _ in 1...100 {
        let randomChange = Double.random(in: -volatility...volatility)
        currentValue += randomChange
        prices.append(currentValue)
    }

    return prices
}

struct LoadingStocks: View {
    var body: some View {
        VStack {
            ForEach(0..<7){ _ in
                ZStack {
                    RoundedRectangle(cornerRadius: 10).foregroundStyle(.ultraThinMaterial).offset(y: 30)
                    LoaderLine(restart: true, data: (0..<60).map { _ in Double.random(in: 0...550) }).shimmering()
                }.frame(height: 100)
            }
            Color.clear.frame(height: 20)
        }.padding().offset(y: -30)
    }
}

struct LoaderLine: View {
    let restart: Bool
    var data: [Double]
    @State var graphProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = (proxy.size.width) / CGFloat(data.count - 1)
            
            let maxPoint = (data.max() ?? 0)
            let minPoint = data.min() ?? 0
            
            let points = data.enumerated().compactMap { item -> CGPoint in

                let progress = (item.element - minPoint) / (maxPoint - minPoint)
                
                let pathHeight = progress * (height - 50)

                let pathWidth = width * CGFloat(item.offset)

                return CGPoint(x: pathWidth, y: -pathHeight + height)
            }
            AnimatedGraphPath(progress: graphProgress, points: points)   .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                withAnimation(.easeInOut(duration: 4.0)){
                    graphProgress = 1
                }
            }
            if restart {
                Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 4.0)){
                        if graphProgress == 1 {
                            graphProgress = 0
                        } else {
                            graphProgress = 1
                        }
                    }
                }
            }
        }
    }
}
