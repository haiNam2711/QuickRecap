//
//  ViewController.swift
//  QuickRecap
//
//  Created by haiNam2711 on 3/11/24.
//

import UIKit
import RxCocoa
import RxSwift
import ProgressHUD

final class ViewController: UIViewController {
    
    @IBOutlet weak var logTextView: UITextView!
    @IBOutlet weak var recordButton: UIButton!
    
    private var whisperState = WhisperState()
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        whisperState.canTranscribe.subscribe(onNext: { [weak self] canTranscribe in
            DispatchQueue.main.async {
                self?.recordButton.isEnabled = canTranscribe
            }
        }).disposed(by: disposeBag)
        whisperState.messageLog.subscribe(onNext: { [weak self] message in
            DispatchQueue.main.async {
                self?.logTextView.text = message
            }
        }).disposed(by: disposeBag)
        whisperState.isRecording.subscribe(onNext: { [weak self] isRecording in
            DispatchQueue.main.async {
                ProgressHUD.dismiss()
                self?.recordButton.setTitle(isRecording ? "Stop" : "Record", for: .normal)
            }
        }).disposed(by: disposeBag)
        whisperState.nearestTranscription.subscribe(onNext: { [weak self] transcription in
            DispatchQueue.main.async {
                guard let transcription = transcription else { return }
                let alert = UIAlertController(title: "Transcription", message: transcription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Summarize", style: .default, handler: { _ in
                    DispatchQueue.global().async {
                        DispatchQueue.main.async {
                            ProgressHUD.animate("Summarizing...")
                        }
                        let output = SummarizationService.shared.summarize(transcription)
                        DispatchQueue.main.async {
                            ProgressHUD.dismiss()
                            let alert = UIAlertController(title: "Summary", message: output, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self?.present(alert, animated: true, completion: nil)
                            self?.logTextView.text.append("\nSummary:\n")
                            self?.logTextView.text.append(output)
                        }
                    }
                }))
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            }
        }).disposed(by: disposeBag)
        do {
            let testEncoder = try GoogleT5Encoder()
            print("Test encoder: \(testEncoder)")
        } catch {
            print("Error: \(error)")
        }
    }
    
    
    @IBAction func recordTapped(_ sender: UIButton) {
        ProgressHUD.animate("Loading Recorder")
        whisperState.toggleRecord()
    }
    
    @IBAction func testEncoder(_ sender: UIButton) {
        let inputText = """
summarize: Hugging Face: Revolutionizing Natural Language Processing
Introduction
In the rapidly evolving field of Natural Language Processing (NLP), Hugging Face has emerged as a prominent and innovative force. This article will explore the story and significance of Hugging Face, a company that has made remarkable contributions to NLP and AI as a whole. From its inception to its role in democratizing AI, Hugging Face has left an indelible mark on the industry.
The Birth of Hugging Face
Hugging Face was founded in 2016 by Clément Delangue, Julien Chaumond, and Thomas Wolf. The name "Hugging Face" was chosen to reflect the company's mission of making AI models more accessible and friendly to humans, much like a comforting hug. Initially, they began as a chatbot company but later shifted their focus to NLP, driven by their belief in the transformative potential of this technology.
Transformative Innovations
Hugging Face is best known for its open-source contributions, particularly the "Transformers" library. This library has become the de facto standard for NLP and enables researchers, developers, and organizations to easily access and utilize state-of-the-art pre-trained language models, such as BERT, GPT-3, and more. These models have countless applications, from chatbots and virtual assistants to language translation and sentiment analysis.
Key Contributions:
1. *Transformers Library:* The Transformers library provides a unified interface for more than 50 pre-trained models, simplifying the development of NLP applications. It allows users to fine-tune these models for specific tasks, making it accessible to a wider audience.
2. *Model Hub:* Hugging Face's Model Hub is a treasure trove of pre-trained models, making it simple for anyone to access, experiment with, and fine-tune models. Researchers and developers around the world can collaborate and share their models through this platform.
3. *Hugging Face Transformers Community:* Hugging Face has fostered a vibrant online community where developers, researchers, and AI enthusiasts can share their knowledge, code, and insights. This collaborative spirit has accelerated the growth of NLP.
Democratizing AI
Hugging Face's most significant impact has been the democratization of AI and NLP. Their commitment to open-source development has made powerful AI models accessible to individuals, startups, and established organizations. This approach contrasts with the traditional proprietary AI model market, which often limits access to those with substantial resources.
By providing open-source models and tools, Hugging Face has empowered a diverse array of users to innovate and create their own NLP applications. This shift has fostered inclusivity, allowing a broader range of voices to contribute to AI research and development.
Industry Adoption
The success and impact of Hugging Face are evident in its widespread adoption. Numerous companies and institutions, from startups to tech giants, leverage Hugging Face's technology for their AI applications. This includes industries as varied as healthcare, finance, and entertainment, showcasing the versatility of NLP and Hugging Face's contributions.
Future Directions
Hugging Face's journey is far from over. As of my last knowledge update in September 2021, the company was actively pursuing research into ethical AI, bias reduction in models, and more. Given their track record of innovation and commitment to the AI community, it is likely that they will continue to lead in ethical AI development and promote responsible use of NLP technologies.
"""
        DispatchQueue.global().async {
            let output = SummarizationService.shared.summarize(inputText)
            DispatchQueue.main.async {
                self.logTextView.text.append(output)
            }
        }
    }
}

