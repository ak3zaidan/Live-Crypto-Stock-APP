import SwiftUI
import Charts

struct Votes: Identifiable {
    let id = UUID()
    let title: String
    let revenue: Double
}

struct TechnicalView: View {
    let products: [Votes]
    let adx: Double
    let trending: Bool
    let buy: Int
    let sell: Int
    let hold: Int
    
    var body: some View {
        VStack {
            if #available(iOS 17.0, *) {
                HStack {
                    VStack {
                        Text("Analyst ratings").font(.title2).bold()
                        Spacer()
                        HStack(spacing: 6){
                            Circle().foregroundStyle(trending ? .green : .red).frame(width: 9, height: 9)
                            Text("trending").font(.subheadline).bold()
                            Spacer()
                        }.padding(.leading).padding(.bottom)
                        HStack(spacing: 6){
                            Text("ADX: \(String(format: "%.3f", adx))").font(.subheadline).bold()
                            Spacer()
                        }.padding(.leading).padding(.bottom)
                    }.padding(.leading, 8).padding(.vertical, 8)
                    
                    Spacer()
                    
                    Chart(products) { product in
                        SectorMark(
                            angle: .value(
                                Text(verbatim: product.title),
                                product.revenue
                            ),
                            innerRadius: .ratio(0.6),
                            angularInset: 2.0
                        )
                        .foregroundStyle(
                            by: .value(
                                Text(verbatim: product.title),
                                product.title
                            )
                        )
                        .annotation(position: .overlay) {
                            Text("\(Int(product.revenue))")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .cornerRadius(10.0)
                    }.frame(width: 140, height: 140).padding(.trailing, 18)
                }
                .background(.blue.opacity(0.3))
                .cornerRadius(15, corners: .allCorners)
                .padding(.horizontal).padding(.vertical)
                .frame(height: 200)
            } else {
                HStack {
                    VStack(spacing: 10){
                        HStack {
                            Text("Analysis").font(.title2).bold()
                            Spacer()
                            HStack(spacing: 6){
                                Circle().foregroundStyle(trending ? .green : .red).frame(width: 9, height: 9)
                                Text("trending").font(.subheadline).bold()
                            }
                        }
                        HStack {
                            HStack(spacing: 6){
                                Text("buy").font(.subheadline).bold()
                                Circle().foregroundStyle(.green).frame(width: 9, height: 9)
                                Text("\(buy)").font(.subheadline).bold()
                            }
                            Spacer()
                            HStack(spacing: 6){
                                Text("sell").font(.subheadline).bold()
                                Circle().foregroundStyle(.red).frame(width: 9, height: 9)
                                Text("\(sell)").font(.subheadline).bold()
                            }
                            Spacer()
                            HStack(spacing: 6){
                                Text("hold").font(.subheadline).bold()
                                Circle().foregroundStyle(.gray).frame(width: 9, height: 9)
                                Text("\(hold)").font(.subheadline).bold()
                            }
                        }
                        HStack {
                            Text("Adx: \(String(format: "%.3f", adx))").font(.subheadline).bold().foregroundStyle(.gray)
                            Spacer()
                        }
                    }.padding()
                }
                .background(.blue.opacity(0.3))
                .cornerRadius(15, corners: .allCorners)
                .padding(.horizontal).padding(.vertical)
                .frame(height: 120)
            }
        }.padding(.bottom, 15)
    }
}
