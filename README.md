# Cloud-Transcription-Machine

The core functionality of [Ton-Texter](https://ton-texter.de) is to transcribe audio and video files. Therefore we use models based on OpenAIs [Whisper](https://github.com/openai/whisper). Additionally we perform a speaker diarization with [Pyannote](https://huggingface.co/pyannote). That way we can deliver state of the art transcription performance.

This repository represents the setup of our AWS Cloud infrastructure via Terraform. The following chart gives an overview over our complete application architecture:

![SystemEngineering_complete_architecture](https://github.com/user-attachments/assets/162d6746-d412-43e4-9e58-3d80d37d0da6)

We implemented the setup of our Auto Scaling group and our general AWS infrastructure in the Repository: [Cloud-Transcription-Service]([https://github.com/ns144/Cloud-Transcription-Machine](https://github.com/ns144/Cloud-Transcription-Service)). The transcription application that the EC2 uses for the transcription can be found in the Repository: [Transcription-Application](https://github.com/ns144/Transcription-Application). The related NEXT.js in the Repository: [Ton-Texter](https://github.com/hanneskoksch/ton-texter).

This repository is used to setup the Launch Template for our Auto Scaling group:

![SystemEngineering_Launch_Template](https://github.com/user-attachments/assets/e657a328-1e17-4d30-abac-494d39425d82)


## Usage

If you want to test our application, proceed as follows:

1. Visit the [Ton-Texter](https://ton-texter.de) application in your browser.

2. Create an account with invitation key "cct2024".

3. Go to "Dashboard".

4. Click on the "Datei hochladen" button to select and upload your audio file.

5. Wait for the transcription process to complete.

6. Download your transcriptions in DOCX, SRT, and TXT formats.

| Service                                                      | Description                                                  | Scope                 |
| ------------------------------------------------------------ | ------------------------------------------------------------ | --------------------- |
| [Ton-Texter](https://github.com/ns144/Cloud-Transcription-Service) | The Next.js application.          | Next.js |
| [Cloud-Transcription-Service](https://github.com/ns144/Cloud-Transcription-Service) | AWS cloud infrastructure via Terraform and Lambdas.          | Transcription Service |
| [Transcription-Application](https://github.com/ns144/Transcription-Application) | The python application that does the transcription and the speaker diarization. | Transcription Service |
| [Cloud-Transcription-Machine](https://github.com/ns144/Cloud-Transcription-Machine) | The EC2 machine setup.                                       | Transcription Service |
| [Ton-Texter-JMeter-Tests](https://github.com/hanneskoksch/Ton-Texter-JMeter-Tests) | JMeter load and quick tests of the Ton-Texter application.   | End-to-end            |
