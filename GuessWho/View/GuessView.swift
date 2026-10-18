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
    var pool: [String]
    var mode: GameMode
    var onFinish: () -> Void = {}

    @State private var currentIndex = 0
    @State private var answer = ""
    @State private var options: [String] = []
    @State private var isWrongAnswer = false
    @State private var wrongOptions: Set<String> = []

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

            switch mode {
            case .hard:
                HStack {
                    TextField("이름을 입력하세요", text: $answer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                        .focused($isTextFieldFocused)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.red, lineWidth: isWrongAnswer ? 2 : 0)
                        )
                        .onSubmit {
                            handleSubmit()
                        }
                        .onChange(of: answer) {
                            isWrongAnswer = false
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
            case .easy:
                VStack(spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            handleSelect(option)
                        } label: {
                            Text(option)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.bordered)
                        .tint(wrongOptions.contains(option) ? .red : nil)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .padding()
        .onAppear {
            options = makeOptions()
        }
    }

    private func handleSubmit() {
        isTextFieldFocused = false
        if answer == items[currentIndex] {
            goToNextItem()
        } else {
            isWrongAnswer = true
        }
    }

    private func handleSelect(_ option: String) {
        if option == items[currentIndex] {
            goToNextItem()
        } else {
            wrongOptions.insert(option)
        }
    }

    private func makeOptions() -> [String] {
        let correct = items[currentIndex]
        let wrongs = Set(pool).subtracting([correct]).shuffled().prefix(2)
        return ([correct] + wrongs).shuffled()
    }

    private func goToNextItem() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
            answer = ""
            isWrongAnswer = false
            wrongOptions = []
            options = makeOptions()
        } else {
            onFinish()
            dismiss()
        }
    }
}

#Preview {
    GuessView(items: ["삐뽀핑", "퐁당핑", "뜨거핑", "꼼딱핑", "간호핑", "나나핑", "행운핑", "아아핑", "고쳐핑", "패션핑"],
              pool: gameData["열쇠 티니핑"] ?? [],
              mode: .easy)
}
