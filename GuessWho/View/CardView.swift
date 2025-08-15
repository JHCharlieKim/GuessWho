//
//  CardView.swift
//  GuessWho
//
//  Created by Charlie Kim on 8/15/25.
//

import SwiftUI

struct CardView: View {
    var imageName: String
    var title: String
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .clipped()
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        .scaleEffect(isPressed ? 0.97 : 1.0)
//        .onTapGesture {
//            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
//                isPressed = true
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
//                withAnimation(.spring()) {
//                    isPressed = false
//                }
//            }
//        }
    }
}

#Preview {
    CardView(imageName: "티니핑", title: "티니핑 맞추기")
}
