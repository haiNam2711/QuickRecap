# Quick Recap  

**Quick Recap** is an iOS app that integrates a **Large Language Model (LLM)** to process audio recordings for transcription and summarization. The app is designed to help users record meetings, lectures, or podcasts and extract meaningful summaries from their recordings.

This project demonstrates how to integrate cutting-edge AI models, including OpenAI's **Whisper** for speech-to-text transcription and Google's **T5 Small** for text summarization, using tools like **Core ML** and **Hugging Face's Swift Transformers library**.

---

## Features  
- **Audio Transcription**: Converts audio recordings into text using Whisper.cpp.  
- **Text Summarization**: Summarizes transcribed text using the T5 Small model converted to Core ML.  
- **Efficient Design**: Optimized for mobile devices with on-demand recording and processing.

---

## Tools and Libraries  

### Core  
- **[Core ML](https://developer.apple.com/documentation/coreml/)**: Apple's framework for machine learning on iOS.  
- **[Hugging Face Exporters](https://github.com/huggingface/exporters/)**: Simplifies exporting Transformer models to Core ML.  

### Transcription  
- **[Whisper.cpp](https://github.com/ggerganov/whisper.cpp)**: Efficient implementation of OpenAI's Whisper for speech-to-text tasks.  

### Summarization  
- **[T5 Small](https://huggingface.co/google/t5-small)**: Pre-trained Transformer model by Google for text-to-text tasks.  

---

## How to run project
You must download the whisper model and coreml model in the link below,
Then unzip and move to the folder: /QuickRecap/QuickRecap/Resources/Models
https://drive.google.com/file/d/1xQAKPjHLlfF9a3iUn3TTzO4SHDeIaO0C/view