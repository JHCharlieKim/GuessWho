//
//  GuessView.swift
//  GuessWho
//
//  Created by Charlie Kim on 8/15/25.
//

import SwiftUI

struct GuessView: View {
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var items: [String]
    
    @State private var currentIndex = 0
    @State private var answer = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("이름을 맞춰보세요")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Image(items[currentIndex])
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5)
            
            HStack {
                TextField("이름을 입력하세요", text: $answer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        handleSubmit()
                    }
                
                Button(action: handleSubmit) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                        .padding(.leading, 5)
                }
                .disabled(answer.isEmpty)
                .opacity(answer.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
    
    private func handleSubmit() {
        isTextFieldFocused = false
        if answer == items[currentIndex] {
            goToNextItem()
        }
    }
    
    private func goToNextItem() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
            answer = ""
        } else {
            dismiss()
        }
    }
}

#Preview {
    GuessView(items: ["삐뽀핑", "퐁당핑", "뜨거핑", "꼼딱핑", "간호핑", "나나핑", "행운핑", "아아핑", "고쳐핑", "패션핑"])
}
