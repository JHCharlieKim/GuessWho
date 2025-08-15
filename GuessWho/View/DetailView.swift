//
//  DetailView.swift
//  GuessWho
//
//  Created by Charlie Kim on 8/15/25.
//

import SwiftUI

let menuData: [String: [String]] = [
    "티니핑 이름 맞추기": [
        "캐치 티니핑", "보석 티니핑", "열쇠 티니핑", "새콤달콤 티니핑", "슈팅스타 티니핑", "전체 티니핑"
    ],
    "포켓몬스터 이름 맞추기": [
        "성도지방 포켓몬 맞추기"
    ]
]

struct DetailView: View {
    var imageName: String
    var title: String
    
    let menu: [String: [String]] = menuData
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding(.top)
                
                ForEach(menu.keys.sorted(), id: \.self) { category in
                    if category == title {
                        VStack(alignment: .leading, spacing: 10) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(menu[category] ?? [], id: \.self) { item in
                                    NavigationLink {
                                        GameView(title: title, subTitle: item)
                                    } label: {
                                        MenuCard(title: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

struct MenuCard: View {
    var title: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        }
    }
}

#Preview {
    DetailView(imageName: "티니핑", title: "티니핑 이름 맞추기")
}
