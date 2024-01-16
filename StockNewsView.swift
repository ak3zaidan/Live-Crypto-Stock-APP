import SwiftUI
import Kingfisher

struct StockNewsView: View {
    @State var dateFinal: String = ""
    var news: FinancialNewsResponse
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2){
            ZStack(alignment: .topLeading){
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.gray).opacity(colorScheme == .dark ? 0.35 : 0.2)
                    .frame(height: 150)
                HStack(alignment: .top){
                    VStack(alignment: .leading, spacing: 8){
                        HStack(spacing: 4){
                            Text(news.source).bold()
                            Text(dateFinal)
                                .foregroundColor(.gray)
                                .font(.caption)
                                .onAppear {
                                    let dateFormatter = DateFormatter()
                                    let dateString = Date(timeIntervalSince1970: TimeInterval(news.datetime)).formatted(.dateTime.month().day().year().hour().minute())
                                    
                                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                                    dateFormatter.dateFormat = "MMMM dd, yyyy 'at' h:mm a"
                                    if let date = dateFormatter.date(from: dateString){
                                        if Calendar.current.isDateInToday(date) {
                                            let hourDifference = Calendar.current.component(.hour, from: Date()) - Calendar.current.component(.hour, from: date)
                                            if hourDifference == 0 {
                                                let minuteDifference = Calendar.current.dateComponents([.minute], from: date, to: Date()).minute ?? 0
                                                dateFinal = "\(minuteDifference)m ago"
                                            } else {
                                                dateFinal = "\(hourDifference)h ago"
                                            }
                                        } else if Calendar.current.isDateInYesterday(date) {
                                            dateFinal = "Yesterday"
                                        } else {
                                            let dayDifference = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                                            dateFinal = "\(dayDifference)d ago"
                                        }
                                    }
                                }
                        }
                        Text(news.headline).multilineTextAlignment(.leading).bold()
                            .lineLimit(4).minimumScaleFactor(0.8).truncationMode(.tail)
                    }
                    .padding(.top, 5)
                    .padding(.leading, 5)
                    
                    Spacer()
                    
                    KFImage(URL(string: news.image))
                        .resizable()
                        .scaledToFill()
                        .frame(width:100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .padding(.top, 20)
                        .padding(.trailing, 8)
                }
            }.padding(.horizontal, 10)
        }
    }
}
