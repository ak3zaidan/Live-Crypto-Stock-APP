import SwiftUI

struct AIStocks: View {
    @EnvironmentObject var appModel: StockViewModel
    @State var hide = false
    let asset: String
    let colors = [Color(#colorLiteral(red: 0.4156862745, green: 0.7098039216, blue: 0.9294117647, alpha: 1)), Color(#colorLiteral(red: 0.337254902, green: 0.1137254902, blue: 0.7490196078, alpha: 1))]

    var body: some View {
        VStack {
            VStack {
                HStack(spacing: 10){
                    if appModel.isGenerating {
                        LottieView(loopMode: .loop, name: "greenAnim").frame(width: 25, height: 25).scaleEffect(0.5)
                    } else {
                        Circle().foregroundStyle(.green).frame(width: 23, height: 23)
                    }
                    Text("AI Technical Analysis").font(.title2).foregroundStyle(.white).bold()
                    Spacer()
                    if !appModel.AIResponse.contains(where: { $0.0 == asset }){
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            Task {
                                await appModel.AskQuestion(asset: asset, retry: false)
                            }
                            hide = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0){
                                hide = false
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).foregroundStyle(.green).opacity(0.9)
                                Text("Generate").font(.system(size: 15))
                            }.frame(width: 98, height: 37)
                        }
                    } else if !hide {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            hide = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0){
                                hide = false
                            }
                            Task {
                                await appModel.AskQuestion(asset: asset, retry: true)
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14)).padding(8)
                                .background(.ultraThickMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
                if let x = appModel.AIResponse.firstIndex(where: { $0.0 == asset }){
                    HStack {
                        Text(appModel.AIResponse[x].1).font(.body).foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                        Spacer()
                    }
                }
            }
            .padding()
            .background {
                LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing).edgesIgnoringSafeArea(.all)
                    .mask(RoundedRectangle(cornerRadius: 20))
            }
        }.padding(.vertical, 15).padding(.horizontal)
    }
}
