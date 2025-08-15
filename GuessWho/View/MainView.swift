//
//  MainView.swift
//  GuessWho
//
//  Created by Charlie Kim on 8/15/25.
//

import SwiftUI

struct MainView: View {
    let items = [
        ("티니핑", "티니핑 이름 맞추기")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(items, id: \.1) { imageName, title in
                        NavigationLink {
                            DetailView(imageName: imageName, title: title)
                        } label: {
                            CardView(imageName: imageName, title: title)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    MainView()
}
