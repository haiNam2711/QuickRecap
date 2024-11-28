//
//  SummarizationService.swift
//  QuickRecap
//
//  Created by haiNam2711 on 4/11/24.
//

import Foundation
import CoreML
import Tokenizers
import RxSwift
import RxCocoa

class SummarizationService {
    static let shared = SummarizationService()
    
    var tokenizer: Tokenizer!
    private var encoderModel: GoogleT5Encoder!
    private var decoderModel: GoogleT5Decoder!
    private let maxSequenceLength = 512
    private let chunkSize = 512
    private var isModelLoaded = BehaviorRelay<Bool>(value: false)
    
    init() {
        Task {
            do {
                tokenizer = try await AutoTokenizer.from(pretrained: "google/flan-t5-small")
                encoderModel = try GoogleT5Encoder(configuration: .init())
                decoderModel = try GoogleT5Decoder(configuration: .init())
                isModelLoaded.accept(true)
                print("Models loaded")
            } catch {
                print("Error loading T5 models")
            }
        }
    }
    
    func summarize(_ inputText: String) -> String {
        var returnText = ""
        
        let inputIds = tokenizer(inputText)
        let inputChunks = chunks(inputIds)
        for chunk in inputChunks {
            if chunk.count < 128 {
                continue
            }
            let encoderResult = encoderFunction(inputIds: chunk)
            returnText += decoderFunction(lastHiddenState: encoderResult.0, attentionMask: encoderResult.1)
            returnText += "\n"
        }
        return returnText
    }
    
    private func encoderFunction(inputIds: [Int]) -> (MLMultiArray, MLMultiArray) {
        guard inputIds.count > 0 && inputIds.count <= maxSequenceLength else {
            fatalError("Input length must be between 1 and \(maxSequenceLength)")
        }
        let input = createInput(inputIds: inputIds)
        let attentionMask = createAttentionMask(inputIds: inputIds)
        let modelInput = GoogleT5EncoderInput(input_ids: input, attention_mask: attentionMask)
        // Generate encoder output
        let output = try? encoderModel.prediction(input: modelInput)
        guard let output = output else {
            fatalError("Error")
        }
        let lastHiddenState = output.last_hidden_state
        //        printMLMultiArr(inp: lastHiddenState)
        return (lastHiddenState, attentionMask)
    }
    
    private func decoderFunction(lastHiddenState: MLMultiArray, attentionMask: MLMultiArray) -> String {
        // Create decoder input
        let decoderInputIds = createInput(inputIds: [0])
        let decoderAttentionMask = createAttentionMask(inputIds: [0])
        var lastToken = 0
        var currentTokenIndex = 0
        var outputTensor = [Int]()
        
        // Generate decoder output
        while lastToken != 1 {
            let decoderInput = GoogleT5DecoderInput(
                decoder_input_ids: decoderInputIds,
                decoder_attention_mask: decoderAttentionMask,
                encoder_last_hidden_state: lastHiddenState,
                encoder_attention_mask: attentionMask
            )
            let decoderOutput = try? decoderModel.prediction(input: decoderInput)
            guard let decoderOutput = decoderOutput else {
                fatalError("Error")
            }
            lastToken = getMaxIndex(inpArr: decoderOutput.logits, tokenIndex: currentTokenIndex)
            outputTensor.append(lastToken)
            currentTokenIndex += 1
            decoderInputIds[currentTokenIndex] = NSNumber(floatLiteral: Double(lastToken))
            decoderAttentionMask[currentTokenIndex] = NSNumber(floatLiteral: 1.0)
        }
        
        return tokenizer.decode(tokens: outputTensor.dropLast())
    }
    
    private func createAttentionMask(inputIds: [Int]) -> MLMultiArray {
        guard inputIds.count > 0 && inputIds.count <= maxSequenceLength else {
            fatalError("Input length must be between 1 and \(maxSequenceLength)")
        }
        let attentionMasks = try! MLMultiArray(shape: [1, NSNumber(integerLiteral: maxSequenceLength)], dataType: .int32)
        
        for i in 0..<inputIds.count {
            attentionMasks[i] = NSNumber(floatLiteral: 1.0)
        }
        
        for i in inputIds.count..<maxSequenceLength {
            attentionMasks[i] = NSNumber(floatLiteral: 0.0)
        }
        
        return attentionMasks
    }
    
    private func createInput(inputIds: [Int]) -> MLMultiArray {
        guard inputIds.count > 0 && inputIds.count <= maxSequenceLength else {
            fatalError("Input length must be between 1 and \(maxSequenceLength)")
        }
        let input = try! MLMultiArray(shape: [1, NSNumber(integerLiteral: maxSequenceLength)], dataType: .int32)
        
        for i in 0..<inputIds.count {
            input[i] = NSNumber(floatLiteral: Double(inputIds[i]))
        }
        
        for i in inputIds.count..<maxSequenceLength {
            input[i] = NSNumber(floatLiteral: 0.0)
        }
        
        return input
    }
    
    private func chunks(_ input: [Int]) -> [[Int]] {
        return stride(from: 0, to: input.count, by: chunkSize).map {
            Array(input[$0..<min($0 + chunkSize, input.count)])
        }
    }
    
    private func getMaxIndex(inpArr: MLMultiArray, tokenIndex: Int) -> Int {
        let dim0 = inpArr.shape[0].intValue
        let dim1 = inpArr.shape[1].intValue
        let dim2 = inpArr.shape[2].intValue
        print(tokenIndex)

        var maxVal: Float = inpArr[tokenIndex * dim2].floatValue
        var maxIndex = 0
        for i in 1..<dim2 {
            let index = tokenIndex * dim2 + i
            let value = inpArr[index].floatValue
            if value > maxVal {
                maxVal = value
                maxIndex = i
            }
        }
        return maxIndex
    }
}
