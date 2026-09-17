// 录音服务 - 封装录音和语音识别逻辑
import { speechRecognizer } from '@kit.CoreSpeechKit'
import { AudioRecorder } from '../utils/AudioRecorder'
import * as DiaryUtils from '../utils/DiaryUtils'
import { RecordingItem } from '../../diary/model/RecordingItem'

// 识别结果回调
export interface ASRCallbacks {
  onStart?: () => void
  onResult?: (text: string, isFinal: boolean) => void
  onComplete?: (finalText: string) => void
  onError?: (code: number, message: string) => void
  onVolumeChange?: (volume: number) => void
}

// 录音状态
export interface RecordingState {
  isRecording: boolean
  isRecognizing: boolean
  duration: number
  recognizedText: string
}

export class RecordingService {
  private static instance: RecordingService | null = null
  
  private audioRecorder: AudioRecorder = new AudioRecorder()
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null
  private asrSessionId: string = ''
  private accumulatedText: string = ''
  private lastAsrResult: string = ''
  private callbacks: ASRCallbacks = {}
  private recordingTimer: number = 0
  private duration: number = 0
  private isRecording: boolean = false
  private isRecognizing: boolean = false
  private asrResultResolver: ((text: string) => void) | null = null

  private constructor() {}

  // 单例模式
  static getInstance(): RecordingService {
    if (!RecordingService.instance) {
      RecordingService.instance = new RecordingService()
    }
    return RecordingService.instance!
  }

  // 初始化服务
  async init(): Promise<void> {
    try {
      await this.audioRecorder.init()
    } catch (e) {
      console.warn('[RecordingService] AudioRecorder init failed:', e)
    }
    try {
      await this.initASREngine()
    } catch (e) {
      console.warn('[RecordingService] ASR engine init failed:', e)
    }
  }

  // 初始化语音识别引擎
  private async initASREngine(): Promise<void> {
    try {
      const extraParam: Record<string, Object> = {
        'locate': 'CN',
        'recognizerMode': 'long'
      }
      const params: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: extraParam
      }
      this.asrEngine = await speechRecognizer.createEngine(params)

      if (this.asrEngine) {
        this.asrEngine.setListener({
          onStart: (sessionId: string, eventMessage: string) => {
            console.log('[ASR] 识别启动:', sessionId)
            this.isRecognizing = true
            this.accumulatedText = ''
            this.lastAsrResult = ''
            this.callbacks.onStart?.()
          },
          onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
            console.log('[ASR] Event:', eventCode)
          },
          onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
            const newText = DiaryUtils.pickBestRecognizedText(result)
            const isFinal = result.isFinal

            if (isFinal) {
              if (newText.length > 0) {
                this.addTextWithPunctuation(newText, '。')
              }
              this.lastAsrResult = ''
              this.callbacks.onResult?.(this.accumulatedText, true)
              return
            }

            // 中间结果处理
            this.lastAsrResult = newText
            const displayText = this.accumulatedText + newText
            this.callbacks.onResult?.(displayText, false)
          },
          onComplete: (sessionId: string, eventMessage: string) => {
            console.log('[ASR] 识别完成')
            if (this.lastAsrResult.length > 0) {
              this.addTextWithPunctuation(this.lastAsrResult, '。')
            }
            this.isRecognizing = false
            this.asrSessionId = ''
            this.callbacks.onComplete?.(this.accumulatedText)
            this.resolveAsrResult(this.accumulatedText)
          },
          onError: (sessionId: string, errorCode: number, errorMessage: string) => {
            if (errorCode === 1002200004) {
              console.info('[ASR] 识别正常结束')
            } else {
              console.error('[ASR] 错误:', errorCode, errorMessage)
              this.callbacks.onError?.(errorCode, errorMessage)
            }
            if (this.lastAsrResult.length > 0) {
              this.addTextWithPunctuation(this.lastAsrResult, '。')
            }
            this.isRecognizing = false
            this.asrSessionId = ''
            this.resolveAsrResult(this.accumulatedText)
          }
        })
      }
      console.log('[ASR] 引擎初始化成功')
    } catch (e) {
      console.warn('ASR引擎初始化失败:', e)
    }
  }

  // 添加文本并自动加标点
  private addTextWithPunctuation(text: string, punctuation: string): void {
    const trimmed = text.trim()
    if (!trimmed) return

    if (this.accumulatedText.length > 0) {
      const lastChar = this.accumulatedText[this.accumulatedText.length - 1]
      if (!['。', '，', '、', '！', '？', '；'].includes(lastChar)) {
        this.accumulatedText += punctuation
      }
    }
    this.accumulatedText += trimmed
  }

  // 解析ASR结果
  private resolveAsrResult(text: string): void {
    if (this.asrResultResolver) {
      this.asrResultResolver(text)
      this.asrResultResolver = null
    }
  }

  // 开始录音（带语音识别）
  async startRecording(callbacks: ASRCallbacks): Promise<void> {
    if (this.isRecording) return

    this.callbacks = callbacks
    this.isRecording = true
    this.duration = 0
    this.accumulatedText = ''
    this.lastAsrResult = ''

    // 启动语音识别
    await this.startASR()

    // 开始录音
    await this.audioRecorder.startRecording(
      (buffer: ArrayBuffer) => {
        this.writeAudioToASR(buffer)
      },
      (volume: number) => {
        callbacks.onVolumeChange?.(volume)
      }
    )

    // 计时器
    this.recordingTimer = setInterval(() => {
      this.duration += 0.1
    }, 100)

    console.log('[RecordingService] 录音开始')
  }

  // 启动语音识别
  private async startASR(): Promise<void> {
    if (!this.asrEngine) {
      await this.initASREngine()
    }

    if (this.asrEngine) {
      try {
        this.asrSessionId = `session_${Date.now()}`
        this.isRecognizing = true

        const recognitionParams: speechRecognizer.StartParams = {
          sessionId: this.asrSessionId,
          audioInfo: {
            audioType: 'pcm',
            sampleRate: 16000,
            soundChannel: 1,
            sampleBit: 16
          }
        }
        await this.asrEngine.startListening(recognitionParams)
      } catch (e) {
        console.error('启动语音识别失败:', e)
        this.isRecognizing = false
      }
    }
  }

  // 写入音频数据到ASR
  private writeAudioToASR(buffer: ArrayBuffer): void {
    if (this.asrEngine && this.isRecognizing && this.asrSessionId) {
      try {
        const uint8Array = new Uint8Array(buffer)
        this.asrEngine.writeAudio(this.asrSessionId, uint8Array)
      } catch (e) {
        console.error('写入音频失败:', e)
      }
    }
  }

  // 停止录音
  async stopRecording(): Promise<RecordingItem> {
    if (!this.isRecording) {
      return this.createEmptyRecording()
    }

    clearInterval(this.recordingTimer)
    this.isRecording = false

    // 停止ASR并获取结果
    const recognizedText = await this.stopASR()

    // 停止录音并获取文件路径
    const audioPath = await this.audioRecorder.stopRecording()

    // 创建录音项
    const recording = new RecordingItem()
    recording.id = `rec_${Date.now()}`
    recording.name = `录音 ${new Date().toLocaleTimeString()}`
    recording.audioPath = audioPath
    recording.audioDuration = Math.floor(this.duration)
    recording.transcription = recognizedText
    recording.createTime = Date.now()

    console.log('[RecordingService] 录音完成:', recording.audioDuration, '秒')
    return recording
  }

  // 停止语音识别
  private async stopASR(): Promise<string> {
    if (this.asrEngine && this.asrSessionId) {
      const engine = this.asrEngine
      const sessionId = this.asrSessionId
      this.isRecognizing = false

      return new Promise<string>((resolve) => {
        this.asrResultResolver = resolve

        // 超时保护
        const timeoutId = setTimeout(() => {
          console.log('[ASR] 超时，强制返回结果')
          if (this.asrResultResolver) {
            let finalResult = this.accumulatedText.trim()
            if (finalResult.endsWith('、') || finalResult.endsWith(',')) {
              finalResult = finalResult.slice(0, -1) + '。'
            }
            this.asrResultResolver(finalResult)
            this.asrResultResolver = null
          }
        }, 3000)

        try {
          engine.finish(sessionId)
        } catch (e) {
          console.error('停止语音识别失败:', e)
          clearTimeout(timeoutId)
          this.asrSessionId = ''
          this.asrResultResolver = null
          resolve(this.accumulatedText)
        }
      })
    }
    this.isRecognizing = false
    return this.accumulatedText
  }

  // 取消录音
  async cancelRecording(): Promise<void> {
    clearInterval(this.recordingTimer)
    this.isRecording = false
    this.isRecognizing = false
    
    try {
      if (this.asrEngine && this.asrSessionId) {
        this.asrEngine.cancel(this.asrSessionId)
      }
    } catch (e) {
      console.warn('取消ASR失败:', e)
    }
    
    await this.audioRecorder.stopRecording()
    this.asrSessionId = ''
    this.accumulatedText = ''
    console.log('[RecordingService] 录音取消')
  }

  // 创建空录音项
  private createEmptyRecording(): RecordingItem {
    const recording = new RecordingItem()
    recording.id = `rec_${Date.now()}`
    recording.name = '空录音'
    recording.audioPath = ''
    recording.audioDuration = 0
    recording.transcription = ''
    recording.createTime = Date.now()
    return recording
  }

  // 获取当前状态
  getState(): RecordingState {
    return {
      isRecording: this.isRecording,
      isRecognizing: this.isRecognizing,
      duration: this.duration,
      recognizedText: this.accumulatedText
    }
  }

  // 释放资源
  async release(): Promise<void> {
    clearInterval(this.recordingTimer)
    
    if (this.asrEngine) {
      try {
        await this.asrEngine.finish('')
        await this.asrEngine.shutdown()
      } catch (e) {
        console.warn('释放ASR引擎失败:', e)
      }
      this.asrEngine = null
    }
    
    await this.audioRecorder.release()
    console.log('[RecordingService] 资源已释放')
  }
}
