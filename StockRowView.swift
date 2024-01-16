import SwiftUI

struct StockRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let coin: CryptoModel
    var body: some View {
        VStack(spacing: 0){
            HStack {
                VStack(alignment: .leading){
                    Text(coin.symbol.uppercased()).font(.system(size: 18))
                    Text(coin.name).frame(width: 95, alignment: .leading).font(.system(size: 15)).foregroundStyle(.gray).lineLimit(1).truncationMode(.tail)
                }
                Spacer()
                GraphView(coin: coin).frame(width: 100, height: 50).disabled(true)
                    .scaleEffect(y: 2.0)
                Spacer()
                RoundedRectangle(cornerRadius: 5)
                    .frame(width: 75, height: 32.5)
                    .foregroundStyle(coin.price_change > 0 ? .green : .red)
                    .overlay {
                        Text("\(coin.price_change > 0 ? "+" : "-")\(String(format: "%.2f", coin.price_change))%")
                            .font(.subheadline)
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                    }
            }
            Divider().overlay(colorScheme == .dark ? Color(UIColor.lightGray) : .gray).padding(.top, 5)
        }.padding(.horizontal)
    }
    @ViewBuilder
    func GraphView(coin: CryptoModel)->some View {
        let prices = coin.last_7days_price.price
        let final = prices.enumerated().compactMap { (index, element) in
            return index % 2 == 0 ? element : nil
        }
        LineGraph(data: final, profit: coin.price_change > 0, shouldAnim: false)
    }
}
